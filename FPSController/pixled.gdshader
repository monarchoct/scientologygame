shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 20.0, 0.1) = 2.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 0.5);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(screen_texture, 0));
	float safe_pixel_size = max(pixel_size, 1.0);
	vec2 pixel_count = tex_size / safe_pixel_size;
	vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;
	vec4 color = texture(screen_texture, pixelated_uv);
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
