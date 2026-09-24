// Multiplicative overlay that scorches clean prop textures: world-space soot patches
// and smoke-blackened upper edges, so every ruin piece looks like it survived the fire.
shader_type spatial;
render_mode blend_mul, unshaded, depth_draw_never, fog_disabled, shadows_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform float amount = 0.8;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float patches = smoothstep(0.38, 0.72, fbm3(wpos * 0.45 + vec3(3.0)));
	float tops = smoothstep(2.0, 6.0, wpos.y) * 0.35;
	float d = clamp(patches * amount + tops, 0.0, 0.82);
	ALBEDO = vec3(1.0 - d);
}
