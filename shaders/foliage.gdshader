shader_type spatial;
// Grass, flowers, ferns and wheat: flat low-poly colour, wind sway that grows with
// height, and a push away from Ayxan (global player_position) so grass parts as he walks.

render_mode cull_disabled, depth_draw_opaque;

global uniform vec3 player_position;
global uniform float wind_strength;
global uniform float foliage_density;   // < 1 thins grass on low quality

uniform vec4 albedo : source_color = vec4(0.4, 0.6, 0.25, 1.0);
uniform float mesh_height = 1.0;
uniform float push_radius = 1.4;
uniform float push_strength = 0.55;

varying float v_tip;

void vertex() {
	if (fract(float(INSTANCE_ID) * 0.6180339) > foliage_density) {
		VERTEX = vec3(0.0);   // collapsed: no fragments for thinned instances
	}
	float tip = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	tip *= tip;
	v_tip = tip;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = MODEL_MATRIX[3].xyz;
	// Wind: two slow waves rolling across the valley plus a quick flutter
	float t = TIME;
	float wave = sin(root.x * 0.09 + t * 1.3) + sin(root.z * 0.07 + t * 0.9) * 0.6;
	float flutter = sin(t * 5.3 + root.x * 1.7 + root.z * 1.3) * 0.25;
	vec3 sway = vec3(wave + flutter, 0.0, (wave - flutter) * 0.5) * 0.08 * (0.4 + wind_strength);
	// Push away from the player
	vec3 away = world - player_position;
	away.y = 0.0;
	float d = length(away);
	float push = clamp(1.0 - d / push_radius, 0.0, 1.0) * step(abs(world.y - player_position.y), 2.0);
	vec3 bend = (d > 0.001 ? away / d : vec3(0.0)) * push * push_strength;
	vec3 offset_world = (sway + bend) * tip;
	offset_world.y -= push * push_strength * 0.4 * tip;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(offset_world, 0.0)).xyz;
}

void fragment() {
	// Darker at the root for depth, lighter tips
	ALBEDO = albedo.rgb * mix(0.62, 1.08, v_tip);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = albedo.rgb * 0.35;
}
