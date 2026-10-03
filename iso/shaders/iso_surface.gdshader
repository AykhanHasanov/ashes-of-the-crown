// The one surface every built thing in the iso world wears (iso/scripts/world/iso_palette.gd):
// stone, plaster, wood and roofs are this shader with different numbers, which is what keeps
// the whole place in one style. It draws masonry courses in world space (so a wall needs no
// UVs and every block is a different stone), lets ash settle on whatever faces up, darkens
// the foot of every wall where grime collects, and can dissolve itself in a screen-space
// dither when the camera needs to see through it (instance uniform `fade`, set per mesh by
// iso/scripts/iso_camera.gd) — so the player is never hidden behind a wall or a roof.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.42, 0.41, 0.40);
uniform float color_noise = 0.10;        // how different one stone is from the next
uniform float block_height = 0.0;        // > 0: masonry courses this tall (metres)
uniform float block_length = 0.9;
uniform float mortar = 0.06;             // mortar line width, as a fraction of a course
uniform float mortar_dark = 0.55;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float ash_amount : hint_range(0.0, 1.0) = 0.65;
uniform vec3 ash_color : source_color = vec3(0.46, 0.455, 0.465);
uniform float grime = 0.35;              // dark at the foot of walls
uniform float plank = 0.0;               // > 0: vertical wood planks this wide (doors)
instance uniform float fade = 0.0;       // 0 solid … 1 gone
instance uniform float cut_height = 1000.0;   // above this (world y) the piece is cut away

varying vec3 wpos;
varying vec3 wnorm;

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

// 4x4 ordered dither: a pixel survives only above its threshold
float bayer4(vec2 frag) {
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	int i = x + y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (fade > 0.002 && bayer4(FRAGCOORD.xy) < fade) {
		discard;
	}
	if (wpos.y > cut_height) {
		discard;
	}
	vec3 n = abs(wnorm);
	// the face's own horizontal axis: x for faces looking along z, z for faces along x
	float along = n.x > n.z ? wpos.z : wpos.x;
	vec3 col = base_color;
	float rough = roughness_value;
	bool up = wnorm.y > 0.6;
	if (block_height > 0.0 && !up) {
		float row = floor(wpos.y / block_height);
		float shift = mod(row, 2.0) * 0.5;
		float col_i = floor(along / block_length + shift);
		float h = hash21(vec2(col_i, row));
		col *= 1.0 + (h - 0.5) * 2.0 * color_noise;
		vec2 cell = vec2(fract(along / block_length + shift), fract(wpos.y / block_height));
		float edge = min(min(cell.x, 1.0 - cell.x) * block_length / block_height, min(cell.y, 1.0 - cell.y));
		float line = 1.0 - smoothstep(mortar * 0.5, mortar, edge);
		col = mix(col, col * mortar_dark, line);
	} else if (plank > 0.0 && !up) {
		float p = floor(along / plank);
		col *= 1.0 + (hash21(vec2(p, 7.0)) - 0.5) * 2.0 * color_noise;
		float seam = 1.0 - smoothstep(0.0, 0.05, min(fract(along / plank), 1.0 - fract(along / plank)));
		col = mix(col, col * 0.45, seam);
		col *= 0.85 + 0.15 * vnoise(vec2(along * 3.0, wpos.y * 28.0));   // grain
	} else {
		col *= 1.0 + (vnoise(wpos.xz * 1.7) - 0.5) * 2.0 * color_noise;
	}
	// surface breakup at two scales, so no face is ever flat
	col *= 0.86 + 0.28 * vnoise(vec2(along, wpos.y) * 2.3 + wpos.xz * 0.4);
	// grime where a wall meets the ground
	col *= 1.0 - grime * (1.0 - smoothstep(0.0, 0.9, wpos.y));
	// ash settles on whatever faces up, thicker in the hollows of the noise
	float settle = smoothstep(0.55, 0.92, wnorm.y);
	float drift = smoothstep(0.25, 0.75, vnoise(wpos.xz * 0.9) * 0.7 + vnoise(wpos.xz * 4.0) * 0.3);
	float ash = settle * ash_amount * (0.55 + 0.45 * drift);
	col = mix(col, ash_color, ash);
	rough = mix(rough, 1.0, ash);
	// a face seen from behind is the inside of a cut wall: a dark, flat cap
	if (!FRONT_FACING) {
		col = vec3(0.035, 0.032, 0.03);
		rough = 1.0;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = FRONT_FACING ? 0.35 : 0.0;
}
