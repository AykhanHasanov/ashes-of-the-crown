// Window glass of the village houses: dark, glossy glass by day; after dusk most windows
// glow with warm, flickering hearth light (global window_light, set by DayNight). Which
// windows stay dark is decided per window from its position, so every house differs.
shader_type spatial;

global uniform float window_light;

uniform vec4 glass : source_color = vec4(0.12, 0.14, 0.16, 1.0);
uniform vec4 lamp : source_color = vec4(1.0, 0.62, 0.28, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cell = floor(wpos / 1.5);
	float r = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float lit = step(0.35, r) * window_light;
	float flicker = 0.85 + 0.15 * sin(TIME * (3.0 + r * 4.0) + r * 20.0) * sin(TIME * 1.7 + r * 9.0);
	ALBEDO = glass.rgb;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	EMISSION = lamp.rgb * lit * flicker * (1.6 + r);
}
