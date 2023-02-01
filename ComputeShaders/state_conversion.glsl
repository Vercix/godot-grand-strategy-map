#[compute]
#version 450

//TODO This is ugly. Should probably use defines to give shader the dimensions
//It needs to be as const as they are used to set the output buffer dimensions
//So cant use uniforms or buffer
//Dimensions of the province image
const int m = 128;
const int n = 64;
//Dimensions of the color look up image
const int DIM = 255;

// Invocations in the (x, y, z) dimension
layout(local_size_x = 4, local_size_y = 4, local_size_z = 1) in;

// State IDs
layout(set = 0, binding = 0, std430) restrict buffer DataBuffer {
	int data[];
}data_buffer;

//The output image
layout(set = 0, binding = 1, std430) buffer OutputBuffer {
	float data[n][m][3];
}output_buffer;

// The province image
layout(set = 0, binding = 2) uniform sampler2D province_texture;

int to_int(float x){
	return int(x * 254.0);
}

//This function should be the same as the convert_to_index in Root.gd
int convert_to_index(vec3 color){
	return (to_int(color.b) * 255 * 255) + (to_int(color.g) * 255) + to_int(color.r);
}

void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y);
   vec4 color = texture(province_texture, vec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y));
   int index = convert_to_index(color.rgb);

   float u = ( float( data_buffer.data[index] % DIM) / (DIM - 1));
   float v = ( floor( data_buffer.data[index] / DIM) / (DIM - 1));

   vec2 state_uv = vec2( u, v);

   output_buffer.data[coord.y][coord.x][0] = u;
   output_buffer.data[coord.y][coord.x][1] = v;
   //TODO This is technically not needed. But will need to adjust the cpu side of parsing the output
   //Although it is another channel that could be used for other kind of data...
   output_buffer.data[coord.y][coord.x][2] = 0.0;
}
