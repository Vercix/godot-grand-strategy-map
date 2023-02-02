extends Node2D

const DIM = 255

@onready var map = %Map
@onready var label = %Label

#
var state_uvs : Dictionary;

#Store image so that we can query the color when we move the mouse over it
var look_up_image : Image

func _ready():
	# we need an array of states. Where each index corresponds to the color of the state. 
	# And each value is its id
	var states := [];

	#Maximum amount of states with this method is ~16 million. Should be enough...
	#If more is needed then the alpha channel could be used too.
	states.resize(255*255*255)
	#the image that will hold the color of the states
	var owner_map : Image = Image.create(
		DIM,
		DIM,
		false,
		Image.FORMAT_RGBAF
	)
	
	if FileAccess.file_exists("res://Assets/Data/states_cache.json"):
		var file = FileAccess.open("res://Assets/Data/states_cache.json", FileAccess.READ)
		var file_contents = file.get_as_text();
		var result : Dictionary = JSON.parse_string(file_contents)
		
		#return false if we fail to parse JSON
		if result == null: return;
		
		for color_string in result:
			var array = color_string.split_floats(',')
			#We want to convert the color to its index representation. i.e. convert 3D value to 1D value
			#And then set the value to the state ID
			states[convert_to_index(Color(array[0], array[1], array[2], array[3]))] = result[color_string].id;
			#Set the color at the uv coord that corresponds to the id
			#little bit hacky for hackathon 
			var owner_colour = Color(result[color_string].owner_colour)
			var uv = Vector2(float(int(result[color_string].id) % DIM), floor(result[color_string].id / DIM))
			state_uvs[Color(float(int(result[color_string].id) % DIM) / (DIM - 1), floor(result[color_string].id / DIM) / (DIM - 1), 0.0)] =  result[color_string].id
			owner_map.set_pixel(uv.x, uv.y, owner_colour)
	else:
		#No file so return
		return;
	
	var image_texture = ImageTexture.create_from_image(owner_map)
	map.material.set_shader_parameter('color_texture', image_texture)
	
	#The image we are going to be working on
	if !FileAccess.file_exists("res://Assets/states.bmp"): return false;
	
	var image := preload("res://Assets/states.bmp").get_image();
	var image_data := image.get_data()
	var image_dimensions := image.get_size()

	#We now have the array, so feed it into the compute shader
	var result = compute_convert_states(states, image_data, image_dimensions)
	look_up_image = create_image_from_vec(result, image_dimensions)
	map.material.set_shader_parameter('lookup_texture', ImageTexture.create_from_image(look_up_image))

func compute_convert_states(data : PackedInt32Array, image_data : PackedByteArray, dimensions : Vector2i) -> PackedVector2Array:
	# Create a local rendering device.
	var rendering_device := RenderingServer.create_local_rendering_device()
	# Load GLSL shader
	var shader_file := load("res://ComputeShaders/state_conversion.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rendering_device.shader_create_from_spirv(shader_spirv)

	##################################################################
	# STATE ID INPUT
	var input := data
	var input_bytes := input.to_byte_array()
	var buffer := rendering_device.storage_buffer_create(input_bytes.size(), input_bytes)
	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(buffer)
	
	##################################################################
	# OUTPUT BUFFER
	var output = PackedVector2Array()
	output.resize(dimensions.x * dimensions.y)
	var output_bytes := output.to_byte_array()
	var output_buffer := rendering_device.storage_buffer_create(output_bytes.size(), output_bytes)
	# Create a uniform to assign the buffer to the rendering device
	var output_uniform := RDUniform.new()
	output_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	output_uniform.binding = 1 # this needs to match the "binding" in our shader file
	output_uniform.add_id(output_buffer)
	
	##################################################################
	# TEXTURE
	var format = RDTextureFormat.new()
	format.width = dimensions.x #128
	format.height = dimensions.y #64
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM          

	var v_tex = rendering_device.texture_create(format, RDTextureView.new(), [image_data])
	var samp_state = RDSamplerState.new()
	samp_state.unnormalized_uvw = true
	var samp = rendering_device.sampler_create(samp_state)

	var tex_uniform = RDUniform.new()
	tex_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	tex_uniform.binding = 2
	tex_uniform.add_id(samp)
	tex_uniform.add_id(v_tex)
	
	#set uniforms
	var uniform_set := rendering_device.uniform_set_create(
		[
			uniform,
			output_uniform,
			tex_uniform
		],
		shader,
		0
	) # the last parameter (the 0) needs to match the "set" in our shader file
	
	var pipeline := rendering_device.compute_pipeline_create(shader)
	var compute_list := rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	
	#NOTE: the 2nd and 3rd parameters products with the invocation x and y should be the dimensions of the resulting image  
	#See note in the shader, this will probably be best to be set through defines. 
	rendering_device.compute_list_dispatch(compute_list, 32, 16, 1)
	rendering_device.compute_list_end()
	
	# Submit to GPU and wait for sync
	rendering_device.submit()
	rendering_device.sync()
	
	# Read back the data from the buffer
	var result_buffer := rendering_device.buffer_get_data(output_buffer);
	var result : PackedVector2Array = to_vec2_array(result_buffer);
	
	#clean up
	rendering_device.free_rid(uniform_set)
	rendering_device.free_rid(pipeline)
	rendering_device.free_rid(v_tex)
	rendering_device.free_rid(buffer)
	rendering_device.free_rid(output_buffer)
	rendering_device.free_rid(samp)
	rendering_device.free_rid(shader)
	rendering_device.free()
	
	return result;


func to_vec2_array(data : PackedByteArray) -> PackedVector2Array:
	#The shader outputs 32bit floats
	var floats = data.to_float32_array();
	var output = PackedVector2Array();
	
	for x in range(0, floats.size(), 2):
		output.append(Vector2(floats[x], floats[x + 1]));
		
	return output;


func create_image_png(data : PackedFloat64Array, data_size : int, image_dimensions : Vector2i ):
	var image_data := PackedFloat32Array()
	for x in range(data_size):
		var value = 1 * data[x]/255
		image_data.append(value);
		image_data.append(value);
		image_data.append(value);
		image_data.append(255);
		
	var new_image : Image = Image.create_from_data(
		image_dimensions.x,
		image_dimensions.y,
		false,
		Image.FORMAT_RGBAF,
		image_data.to_byte_array()
	);
	
	new_image.save_png('result.png')


func create_image_from_vec(data : PackedVector2Array,  image_dimensions : Vector2i ) -> Image:
	var image_data := PackedFloat32Array()

	for i in range(data.size()):
		var value : Vector2 = Vector2(data[i].x, data[i].y);
		image_data.append(value.x);
		image_data.append(value.y);
		
	var new_image : Image = Image.create_from_data(
		image_dimensions.x,
		image_dimensions.y,
		false,
		Image.FORMAT_RGF,
		image_data.to_byte_array()
	);
	
	return new_image;


func to_int(x):
	return int(floor(x * 254.0))


func convert_to_index(color : Color):
	return (to_int(color.b) * 255 * 255) + (to_int(color.g) * 255) + to_int(color.r)


func _on_control_gui_input(event):
	if event is InputEventMouseMotion:
		var mouse_motion_event = event as InputEventMouseMotion
		
		#assume that the image is not centered
		if mouse_motion_event.position.x < map.global_position.x or \
		mouse_motion_event.position.y < map.global_position.x or \
		mouse_motion_event.position.x > map.global_position.x + map.get_rect().size.x - 1 or \
		mouse_motion_event.position.y > map.global_position.y + map.get_rect().size.y - 1:
			return   
		var state_id  = state_uvs.get(look_up_image.get_pixelv(mouse_motion_event.position - map.global_position))
		if state_id:
			label.set_text(str( state_id))
