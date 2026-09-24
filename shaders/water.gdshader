shader_type spatial;
// Lake and river water (spec V3 §6.1): depth-based colour, shore foam, flow along the
// river (UV.y runs downstream), small animated ripples and refraction of the bed.

render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.22, 0.46, 0.5, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.14, 0.24, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.93, 0.92, 1.0);
uniform float depth_scale = 2.5;
uniform float flow_speed = 0.0;       // 0 for lakes
uniform float ripple_scale = 0.18;
uniform float foam_width = 0.45;
uniform float clarity = 1.0;          // lower in rain

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float ripples(vec2 p, float t) {
	return vnoise(p * 1.3 + vec2(t * 0.35, t * 0.2)) * 0.6 + vnoise(p * 3.1 - vec2(t * 0.5, -t * 0.4)) * 0.4;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.6 + TIME * 1.2) * 0.02 + cos(world_pos.z * 0.5 + TIME) * 0.02;
}

void fragment() {
	float t = TIME;
	// Rivers flow along UV.y, lakes drift slowly
	vec2 p = world_pos.xz * ripple_scale;
	if (flow_speed > 0.0) {
		p = vec2(UV.x * 3.0, UV.y * ripple_scale - t * flow_speed);
	}
	float e = 0.08;
	float h0 = ripples(p, t);
	float hx = ripples(p + vec2(e, 0.0), t);
	float hz = ripples(p + vec2(0.0, e), t);
	float calm = clamp(-VERTEX.z / 60.0, 0.0, 1.0);
	float amp = mix(0.35, 0.06, calm);
	vec3 n = normalize(vec3((h0 - hx) * amp, e, (h0 - hz) * amp));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	// Depth of the water column under this pixel
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = max(-view.z - (-VERTEX.z), 0.0);
	float depth_t = clamp(water_depth / depth_scale, 0.0, 1.0);

	vec2 refr_uv = SCREEN_UV + n.xz * 0.02 * depth_t;
	vec3 bed = textureLod(screen_tex, refr_uv, 1.0).rgb;
	vec3 water = mix(shallow_color.rgb, deep_color.rgb, depth_t);
	vec3 col = mix(bed * shallow_color.rgb * 1.6, water, clamp(depth_t * 1.4 / clarity, 0.0, 1.0));

	// Shore foam
	float foam_line = 1.0 - smoothstep(0.0, foam_width, water_depth);
	float foam_n = vnoise(world_pos.xz * 2.2 + vec2(t * 0.3, 0.0));
	float foam = foam_line * smoothstep(0.35, 0.7, foam_n + foam_line * 0.4);
	if (flow_speed > 0.0) {
		foam += smoothstep(0.78, 0.95, vnoise(vec2(UV.x * 6.0, UV.y * 0.8 - t * flow_speed * 1.5))) * 0.25;
	}
	col = mix(col, foam_color.rgb, clamp(foam, 0.0, 1.0));

	ALBEDO = col;
	ROUGHNESS = mix(0.1, 0.3, calm);
	METALLIC = 0.0;
	SPECULAR = 0.45;
	ALPHA = clamp(0.55 + depth_t * 0.45 + foam, 0.0, 1.0);
}
