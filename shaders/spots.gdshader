// Leopard rosettes: a multiply pass that darkens noise spots on the model
// (used as next_pass of the enemy overlay; `scale` fits the model's mesh units).
shader_type spatial;
render_mode blend_mul, unshaded, depth_draw_never, cull_back;

#include "res://shaders/noise.gdshaderinc"

uniform float scale = 14.0;
uniform vec4 spot_color : source_color = vec4(0.22, 0.15, 0.08, 1.0);

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	float n = vnoise3(lpos * scale);
	float ring = smoothstep(0.6, 0.66, n) * (1.0 - smoothstep(0.74, 0.8, n) * 0.6);
	ALBEDO = mix(vec3(1.0), spot_color.rgb, ring);
}
