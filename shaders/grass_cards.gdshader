shader_type spatial;
// Photographed grass and flower cards (tools/make_foliage_cards.py, crossed quads baked by
// tools/bake_foliage.gd): alpha-tested blades, wind that rolls across the valley, a push
// away from Ayxan (global player_position) so grass parts as he walks, root darkening,
// light through the blades, and per-clump colour variation so meadows are not uniform.

render_mode cull_disabled, depth_draw_opaque;

global uniform vec3 player_position;
global uniform float wind_strength;
global uniform float foliage_density;   // < 1 thins grass on low quality

uniform sampler2D card_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 dry_tint : source_color = vec4(0.85, 0.78, 0.5, 1.0);
uniform float dryness = 0.25;          // share of clumps that turn straw-coloured
uniform float mesh_height = 0.6;
uniform float push_radius = 1.3;
uniform float push_strength = 0.5;
uniform float alpha_cut = 0.4;

varying float v_tip;
varying float v_var;

void vertex() {
	if (fract(float(INSTANCE_ID) * 0.6180339) > foliage_density) {
		VERTEX = vec3(0.0);
	}
	float tip = clamp(VERTEX.y / mesh_height, 0.0, 1.0);
	v_tip = tip;
	tip *= tip;
	vec3 root = MODEL_MATRIX[3].xyz;
	v_var = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;
	float wave = sin(root.x * 0.09 + t * 1.3) + sin(root.z * 0.07 + t * 0.9) * 0.6;
	float flutter = sin(t * 5.3 + root.x * 1.7 + root.z * 1.3) * 0.25;
	vec3 sway = vec3(wave + flutter, 0.0, (wave - flutter) * 0.5) * 0.09 * (0.4 + wind_strength);
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
	vec4 tex = texture(card_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 col = tex.rgb * tint.rgb;
	// Some clumps dry toward straw, the rest vary a little in green
	float dry = smoothstep(1.0 - dryness, 1.0 - dryness + 0.15, v_var);
	col = mix(col, col * dry_tint.rgb * 1.25, dry * 0.8);
	col *= 0.88 + v_var * 0.24;
	col *= mix(0.55, 1.05, v_tip);
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.45;
}
