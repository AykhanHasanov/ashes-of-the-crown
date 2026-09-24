// Additive overlay for ash-risen enemies: crawling ember cracks, a hot rim light
// and a white hit flash. Applied as material_overlay on top of the model's texture.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 ember_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float intensity = 1.0;
uniform float hit_flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float scale = 7.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float n = vnoise3(lpos * scale + vec3(0.0, -TIME * 0.6, 0.0));
	float cracks = smoothstep(0.66, 0.72, n) * (0.6 + 0.4 * sin(TIME * 3.0 + lpos.y * 8.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = ember_color.rgb * (cracks * 1.8 + fres * 1.1) * intensity + flash_color.rgb * hit_flash * 1.5;
}
