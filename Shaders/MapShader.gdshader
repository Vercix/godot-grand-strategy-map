shader_type canvas_item;

uniform sampler2D lookup_texture : filter_nearest;
uniform sampler2D color_texture : filter_nearest;
uniform vec4 selected_area;

bool is_same_color(vec3 a, vec3 b){
	vec3 diff = abs(a - b); 
	return  diff.r < 0.005 &&  diff.g < 0.005 &&  diff.b < 0.005;
}

void fragment() {
	vec4 lookup_uv = texture(lookup_texture, UV);
	COLOR = texture(color_texture, vec2(lookup_uv.x, lookup_uv.y));
	
	//Naive way to implement borders. 
	for(int i = -1; i < 2; i++){
		for(int j = -1; j < 2; j++){
			vec4 check_color = texture(lookup_texture, vec2(UV.x + (TEXTURE_PIXEL_SIZE.x * float(i)), UV.y  + (TEXTURE_PIXEL_SIZE.y * float(j))));
			if( !is_same_color(check_color.rgb, lookup_uv.rgb)){
				COLOR = vec4(0.0,1.0,0.0,1.0);
			}
		}
	}
//	//For selected area
//	if(is_same_color(lookup_uv.rgb, selected_area.rgb)){
//		color = vec4(1.0,1.0,1.0,1.0);
//	}
}