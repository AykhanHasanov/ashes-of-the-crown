// Shell fur for animals (scripts/characters/fur.gd). The body is drawn once solid
// (shell = 0), then again in thin shells pushed out along the smoothed normals; each
// shell keeps only the strands that reach that high (cell noise in the rest pose, so
// the pattern rides on the animal instead of sliding over it). Roots dark, tips light,
// a soft sheen at grazing angles, and optional leopard rosettes. Shells fade out with
// distance and never cast shadows.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(0.42, 0.42, 0.4, 1.0);
uniform vec4 belly : source_color = vec4(0.58, 0.58, 0.55, 1.0);
uniform float shell = 0.0;            // 0 = skin, (0, 1] = shell height
uniform float fur_length = 0.03;      // mesh units
uniform float density = 300.0;        // strands per mesh unit
uniform float droop = 0.01;           // mesh units at the tips
uniform float rosettes = 0.0;         // 1 = leopard spots
uniform float spot_scale = 14.0;
uniform float fade_distance = 26.0;

varying vec3 rest;
varying float cam_dist;

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float cells(vec3 p) {
	// distance to the nearest random point: 0 at a strand's centre
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d = 1.0;
	for (int x = -1; x <= 1; x++) for (int y = -1; y <= 1; y++) for (int z = -1; z <= 1; z++) {
		vec3 g = vec3(float(x), float(y), float(z));
		vec3 o = vec3(hash3(i + g), hash3(i + g + 19.1), hash3(i + g + 47.3));
		d = min(d, length(g + o - f));
	}
	return d;
}

void vertex() {
	rest = vec3(UV.x, UV2.x, UV.y);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cam_dist = distance(world, CAMERA_POSITION_WORLD);
	if (shell > 0.0) {
		if (IN_SHADOW_PASS || cam_dist > fade_distance) {
			VERTEX = vec3(0.0);
		} else {
			VERTEX += NORMAL * fur_length * shell;
			VERTEX.y -= droop * shell * shell;
		}
	}
}

void fragment() {
	vec3 base = albedo.rgb;
	if (rosettes > 0.0) {
		// Leopard rosettes: dark rings with a slightly darker centre
		float c = cells(rest * spot_scale);
		float ring = smoothstep(0.34, 0.28, c) - smoothstep(0.2, 0.14, c) * 0.55;
		base = mix(base, base * vec3(0.18, 0.15, 0.12), clamp(ring, 0.0, 1.0) * rosettes);
	}
	float strand = 1.0 - cells(rest * density);          // 1 at a strand centre
	float len = 0.55 + 0.45 * hash3(floor(rest * density));
	if (shell > 0.0) {
		// Thin strands: the higher the shell, the closer to the strand centre
		float need = shell / len;
		ALPHA = step(need, strand * 1.35 - 0.2) * clamp(1.0 - (cam_dist - fade_distance * 0.7) / (fade_distance * 0.3), 0.0, 1.0);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	float h = shell;
	vec3 col = base * mix(0.5, 1.12, h) * (0.9 + 0.2 * hash3(floor(rest * density * 0.25)));
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col + base * sheen * 0.25 * h;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	BACKLIGHT = base * 0.2 * h;
}
