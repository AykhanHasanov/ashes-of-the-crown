// The ground of the whole iso map: frozen earth under a skin of ash that lies like snow.
// Three things push the ash back: the road (trodden into dark mud along a polyline), a living
// fire (the ash melts in a circle around it and leaves a dark wet ring at the edge), and —
// through decals, not here — footprints. Fires and road points are uploaded by
// iso/scripts/world/iso_world.gd; a fire that goes out stops melting its circle.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform vec3 earth : source_color = vec3(0.17, 0.155, 0.15);
uniform vec3 mud : source_color = vec3(0.105, 0.094, 0.085);
uniform vec3 ash : source_color = vec3(0.43, 0.425, 0.435);
uniform vec3 wet : source_color = vec3(0.07, 0.065, 0.065);
uniform float ash_cover : hint_range(0.0, 1.0) = 0.85;
uniform vec4 fires[12];                 // xyz = position, w = melt radius
uniform int fire_count = 0;
uniform vec4 road[24];                  // xz = point
uniform int road_count = 0;
uniform float road_width = 2.2;
uniform vec4 paved_rect = vec4(0.0);    // x/z min, x/z max: flagstones (the courtyard)
uniform vec3 paving : source_color = vec3(0.25, 0.24, 0.235);

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
		mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * 0.12);
	float fine = fbm(p * 2.7);
	float mid = fbm(p * 0.9);
	vec3 col = earth * (0.8 + 0.4 * fine);
	float rough = 0.95;
	// the courtyard is flagged: big worn stones with dark joints
	bool paved = p.x > paved_rect.x && p.y > paved_rect.y && p.x < paved_rect.z && p.y < paved_rect.w;
	if (paved) {
		vec2 cell = p / vec2(1.3, 0.9);
		cell.x += mod(floor(cell.y), 2.0) * 0.5;
		vec2 f = fract(cell);
		float joint = 1.0 - smoothstep(0.0, 0.05, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		col = paving * (0.82 + 0.3 * hash21(floor(cell))) * (0.9 + 0.2 * fine);
		col = mix(col, col * 0.35, joint);
	}
	// ash cover: everywhere, thinner where the noise dips
	// thick almost everywhere, thinning in long low drifts and in small bare patches
	float cover = ash_cover * smoothstep(0.18, 0.48, n * 0.55 + mid * 0.3 + fine * 0.15);
	// the road: trodden mud, ash only at its ragged edges
	if (road_count > 1) {
		float d = 1e5;
		for (int i = 0; i < road_count - 1; i++) {
			d = min(d, seg_dist(p, road[i].xz, road[i + 1].xz));
		}
		float edge = road_width * (0.75 + 0.5 * fbm(p * 0.5)) + (fine - 0.5) * 0.6;
		float on_road = 1.0 - smoothstep(edge * 0.45, edge * 1.05, d);
		on_road *= 0.75 + 0.25 * smoothstep(0.3, 0.7, fine);   // patches of ash left on the road
		col = mix(col, mud * (0.8 + 0.4 * fine), on_road);
		cover *= 1.0 - on_road * 0.92;
		// wheel ruts: two darker lines along the middle of the road
		float rut = (1.0 - smoothstep(0.05, 0.16, abs(d - 0.55))) * on_road;
		col *= 1.0 - rut * 0.35;
	}
	if (paved) {
		cover *= 0.45;      // swept, but the ash still gathers in the joints and corners
	}
	// living fire: the ash melts in a circle, and the edge of the circle is wet and dark
	float wetness = 0.0;
	for (int i = 0; i < fire_count; i++) {
		float d = length(p - fires[i].xz);
		float r = fires[i].w * (0.9 + 0.2 * fbm(p * 1.3 + float(i)));
		cover *= smoothstep(r * 0.55, r, d);
		wetness = max(wetness, 1.0 - smoothstep(0.0, r * 0.35, abs(d - r * 0.8)));
	}
	if (paved) {
		wetness *= 0.15;    // swept stone: the ash never lay thick enough to leave a wet ring
	}
	col = mix(col, wet, wetness * 0.35);
	rough = mix(rough, 0.55, wetness);
	col = mix(col, ash * (0.92 + 0.12 * fine), cover);
	rough = mix(rough, 1.0, cover);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3 + wetness * 0.3;
}
