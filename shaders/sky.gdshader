shader_type sky;
// Open-world sky: day/night gradient, sun and moon discs, stars, drifting clouds and
// the ember of Kül Şahı — a smouldering red star over Közqala, visible from anywhere
// in the valley (a landmark, spec V3 §6.3). Driven by scripts/world/day_night.gd.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 ember_dir = vec3(-0.95, 0.18, 0.0);
uniform vec4 top_color : source_color = vec4(0.25, 0.45, 0.75, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.75, 0.8, 0.85, 1.0);
uniform vec4 ground_color : source_color = vec4(0.25, 0.23, 0.2, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float night = 0.0;          // 0 day … 1 deep night
uniform float cloud_cover = 0.2;
uniform float cloud_darkness = 0.0; // rain clouds
uniform float ember_pulse = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	// Base gradient
	float h = pow(clamp(up, 0.0, 1.0), 0.45);
	vec3 col = mix(horizon_color.rgb, top_color.rgb, h);
	col = mix(col, ground_color.rgb, smoothstep(0.0, -0.12, up));

	// Warm glow around the sun near the horizon
	float sd = max(dot(d, sun_dir), 0.0);
	col += sun_color.rgb * pow(sd, 8.0) * 0.35 * (1.0 - night);
	// Sun disc
	col += sun_color.rgb * smoothstep(0.9993, 0.9997, sd) * 6.0 * step(-0.05, sun_dir.y);

	// Moon and stars at night
	float md = max(dot(d, moon_dir), 0.0);
	col += vec3(0.8, 0.85, 1.0) * smoothstep(0.9990, 0.9994, md) * 1.6 * night;
	col += vec3(0.4, 0.45, 0.6) * pow(md, 60.0) * 0.25 * night;
	if (up > 0.0) {
		vec3 cell = floor(d * 160.0);
		float h1 = hash(cell.xy + cell.z * 17.13);
		vec3 centre = (cell + 0.5) / 160.0;
		float point = smoothstep(0.0026, 0.0, length(d - normalize(centre)));
		float star = step(0.9965, h1) * point * (0.4 + 0.6 * fract(h1 * 91.7));
		float twinkle = 0.6 + 0.4 * sin(TIME * 3.0 + h1 * 40.0);
		col += vec3(star * twinkle) * night * smoothstep(0.05, 0.35, up) * 1.8;
	}

	// Clouds on a flat layer
	if (up > 0.0) {
		vec2 cp = d.xz / (up + 0.08) * 1.6 + vec2(TIME * 0.006, TIME * 0.002);
		float c = fbm(cp);
		float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.35, c);
		vec3 lit = mix(vec3(1.0), sun_color.rgb, 0.35) * (1.0 - night * 0.85);
		vec3 cloud_col = mix(lit, vec3(0.25, 0.26, 0.3) * (1.0 - night * 0.7), cloud_darkness);
		cloud_col = mix(cloud_col, horizon_color.rgb, 1.0 - smoothstep(0.0, 0.3, up));
		col = mix(col, cloud_col, cover * smoothstep(0.0, 0.08, up));
	}

	// The ember of Kül Şahı: always there, brighter at night, pulsing like a coal
	float ed = max(dot(d, normalize(ember_dir)), 0.0);
	float glow = pow(ed, 400.0) * 3.5 + pow(ed, 40.0) * 0.35;
	col += vec3(1.0, 0.32, 0.08) * glow * ember_pulse * mix(0.55, 1.4, night);
	col += vec3(1.0, 0.9, 0.6) * smoothstep(0.99985, 0.99995, ed) * 4.0;

	COLOR = col;
}
