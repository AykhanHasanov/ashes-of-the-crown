// Burned masonry: brick courses in world space, soot patches and optional
// embers smouldering inside the cracks.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 color_a : source_color = vec4(0.26, 0.22, 0.18, 1.0);
uniform vec4 color_b : source_color = vec4(0.13, 0.11, 0.10, 1.0);
uniform vec4 soot : source_color = vec4(0.025, 0.022, 0.02, 1.0);
uniform vec4 ember : source_color = vec4(1.0, 0.35, 0.06, 1.0);
uniform float ember_amount = 0.0;
uniform bool bricks = true;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float h = abs(wnrm.x) > 0.5 ? wpos.z : wpos.x;
	float row = floor(wpos.y / 0.55);
	float course = h / 1.1 + row * 0.5;
	float bx = fract(course);
	float by = fract(wpos.y / 0.55);
	float mortar = smoothstep(0.0, 0.06, min(min(bx, 1.0 - bx), min(by, 1.0 - by)));
	if (!bricks || abs(wnrm.y) > 0.5) {
		mortar = 1.0;
	}

	float n = fbm3(wpos * 0.9);
	float bid = hash21(vec2(floor(course), row));
	vec3 col = mix(color_b.rgb, color_a.rgb, clamp(n * 0.7 + bid * 0.4, 0.0, 1.0));
	col *= mix(0.45, 1.0, mortar);

	float soot_m = smoothstep(0.42, 0.72, fbm3(wpos * 0.35 + vec3(5.0)));
	soot_m = max(soot_m, (1.0 - smoothstep(0.0, 2.5, wpos.y)) * 0.45);
	col = mix(col, soot.rgb, soot_m * 0.85);

	ALBEDO = col;
	ROUGHNESS = 0.92;
	float glow = smoothstep(0.7, 0.78, fbm3(wpos * 2.2)) * soot_m;
	EMISSION = ember.rgb * glow * ember_amount * (0.7 + 0.3 * sin(TIME * 2.0 + wpos.y));
}
