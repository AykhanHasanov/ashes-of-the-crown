// Scorched flagstones of Közqala: ash drifts, soot and glowing cracks that
// intensify toward the crater where the crown melted.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec4 stone_a : source_color = vec4(0.10, 0.085, 0.075, 1.0);
uniform vec4 stone_b : source_color = vec4(0.20, 0.17, 0.14, 1.0);
uniform vec4 ash_color : source_color = vec4(0.36, 0.34, 0.32, 1.0);
uniform vec4 ember_color : source_color = vec4(1.0, 0.33, 0.05, 1.0);
uniform vec3 crater_pos = vec3(0.0, 0.0, -9.0);
uniform float crack_glow = 1.6;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;

	// Offset flagstone courses
	vec2 tile = p / vec2(2.4, 1.6);
	tile.x += step(1.0, mod(floor(tile.y), 2.0)) * 0.5;
	vec2 ti = floor(tile);
	vec2 tf = fract(tile);
	float edge = min(min(tf.x, 1.0 - tf.x) * 2.4, min(tf.y, 1.0 - tf.y) * 1.6);
	float grout = smoothstep(0.02, 0.09, edge);

	float f = fbm2(p * 0.45);
	float jitter = hash21(ti);
	vec3 col = mix(stone_a.rgb, stone_b.rgb, clamp(jitter * 0.6 + f * 0.5, 0.0, 1.0));
	col *= mix(0.35, 1.0, grout);

	// Heat around the crater, soot and ash drifts
	float heat = 1.0 - smoothstep(3.0, 10.0, distance(p, crater_pos.xz));
	float scorch = smoothstep(0.35, 0.7, fbm2(p * 0.18 + 7.3));
	col = mix(col, col * 0.25, max(scorch * 0.8, heat * 0.7));
	float ashm = smoothstep(0.5, 0.78, fbm2(p * 0.11 + 3.1)) * (1.0 - heat);
	col = mix(col, ash_color.rgb * (0.75 + 0.25 * f), ashm * 0.9);

	// Glowing cracks along noise ridges plus hot grout near the crater
	float ridge = abs(fbm2(p * 0.22 + 11.0) - 0.5);
	float crack_zone = max(smoothstep(0.5, 0.68, fbm2(p * 0.07 + 20.0)), heat);
	float crack = (1.0 - smoothstep(0.0, 0.012 + heat * 0.02, ridge)) * (1.0 - ashm) * crack_zone;
	float grout_glow = (1.0 - grout) * heat * heat * 0.5 * (0.4 + 0.6 * vnoise2(p * 0.8));
	float pulse = 0.65 + 0.35 * sin(TIME * 1.7 + p.x * 0.35 + p.y * 0.25);

	ALBEDO = col;
	ROUGHNESS = mix(0.8, 1.0, ashm);
	EMISSION = ember_color.rgb * (crack * (0.6 + heat * 1.6) + grout_glow * 1.5) * crack_glow * pulse;
}
