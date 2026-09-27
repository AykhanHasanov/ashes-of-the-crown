// Bark of generated trees: tiled photo bark with its normal and roughness maps, darker
// near the roots and inside the crown (COLOR.r), swaying with the leaves.
shader_type spatial;

#include "res://shaders/tree_wind.gdshaderinc"

uniform sampler2D bark_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D bark_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D bark_rough : hint_default_white, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float char_amount = 0.0;   // burnt trees: 1 = charcoal with a few glowing cracks

varying float v_ao;

void vertex() {
	v_ao = COLOR.r;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(tree_sway(VERTEX, MODEL_MATRIX, 0.0, TIME), 0.0)).xyz;
}

void fragment() {
	vec3 col = texture(bark_albedo, UV).rgb * tint.rgb;
	col *= mix(0.55, 1.0, v_ao);
	float lum = dot(col, vec3(0.33));
	col = mix(col, vec3(lum * 0.25), char_amount);
	ALBEDO = col;
	NORMAL_MAP = texture(bark_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = texture(bark_rough, UV).r;
	SPECULAR = 0.25;
	if (char_amount > 0.0) {
		float crack = smoothstep(0.32, 0.18, texture(bark_rough, UV * 0.5).r);
		EMISSION = vec3(1.0, 0.32, 0.06) * crack * char_amount * 0.6;
	}
}
