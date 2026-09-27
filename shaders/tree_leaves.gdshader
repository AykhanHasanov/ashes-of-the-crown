// Leaf cards of generated trees: photographed leaf clusters (alpha-tested), crown-shaped
// normals so the canopy shades as one soft volume, light through the leaves (backlight),
// per-tree and per-card colour variation, inner cards darkened (COLOR.r = occlusion).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

#include "res://shaders/tree_wind.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float hue_variation = 0.08;
uniform float alpha_cut = 0.45;
uniform float translucency = 0.55;

varying float v_ao;
varying float v_rand;
varying float v_tree;

void vertex() {
	v_tree = tree_hash(MODEL_MATRIX);
	v_ao = COLOR.r;
	v_rand = COLOR.g;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(tree_sway(VERTEX, MODEL_MATRIX, COLOR.b, TIME), 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(leaf_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 col = tex.rgb * tint.rgb;
	// Per tree: a slightly different green; per card: a little lighter or darker
	float t = (v_tree - 0.5) * hue_variation;
	col *= vec3(1.0 + t * 1.5, 1.0 + t * 0.4, 1.0 - t * 1.2);
	col *= 0.86 + v_rand * 0.28;
	col *= mix(0.5, 1.0, v_ao);
	ALBEDO = col;
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
	BACKLIGHT = col * translucency * v_ao;
	// Back faces see the same crown normal (no black undersides)
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
