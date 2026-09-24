// Kül Kölgəsi body: near-black ash with crawling ember cracks, a hot rim,
// a hit flash and a noise dissolve used for rising and dying.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.035, 0.03, 0.03, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float crack_strength = 3.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash = 0.0;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float d = vnoise3(obj_pos * 4.0);
	if (d < dissolve) {
		discard;
	}
	float edge = (1.0 - smoothstep(dissolve, dissolve + 0.08, d)) * step(0.001, dissolve);

	float n = vnoise3(obj_pos * 6.0 + vec3(0.0, -TIME * 0.6, 0.0));
	float n2 = vnoise3(obj_pos * 13.0 + vec3(TIME * 0.2));
	float cracks = smoothstep(0.62, 0.7, n) * (0.6 + 0.4 * sin(TIME * 3.0 + obj_pos.y * 8.0));
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	ALBEDO = base_color.rgb * (0.6 + 0.4 * n2);
	ROUGHNESS = 0.9;
	EMISSION = ember_color.rgb * (cracks * crack_strength + fres * 2.6 + edge * 6.0) + vec3(hit_flash * 3.0);
}
