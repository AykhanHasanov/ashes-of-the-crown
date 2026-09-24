// Molten pool where the crown melted: slow churning noise, hot and cool crust.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 hot : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 cool : source_color = vec4(0.25, 0.03, 0.0, 1.0);
uniform float energy = 4.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * 0.9;
	float n = fbm2(p + vec2(TIME * 0.15, -TIME * 0.1));
	float n2 = fbm2(p * 2.3 - vec2(TIME * 0.2, TIME * 0.05));
	float heat = smoothstep(0.3, 0.8, n * 0.6 + n2 * 0.5);
	vec3 c = mix(cool.rgb, hot.rgb, heat);
	ALBEDO = vec3(0.02);
	ROUGHNESS = 0.3;
	EMISSION = c * energy * (0.6 + heat);
}
