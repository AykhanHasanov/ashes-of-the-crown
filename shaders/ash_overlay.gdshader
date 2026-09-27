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
	// Thin glowing veins (ridged noise: bright where the noise crosses its midline), two
	// octaves so they branch, drifting slowly upward like heat through charred skin.
	vec3 p = lpos * scale + vec3(0.0, -TIME * 0.25, 0.0);
	float r1 = 1.0 - abs(vnoise3(p) - 0.5) * 2.0;
	float r2 = 1.0 - abs(vnoise3(p * 2.3 + 7.1) - 0.5) * 2.0;
	float veins = max(smoothstep(0.93, 0.98, r1), smoothstep(0.95, 0.99, r2) * 0.6);
	float pulse = 0.65 + 0.35 * sin(TIME * 2.2 + lpos.y * 5.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = ember_color.rgb * (veins * 2.4 * pulse + fres * 0.7) * intensity + flash_color.rgb * hit_flash * 1.5;
}
