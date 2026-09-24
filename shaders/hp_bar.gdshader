// Camera-facing health bar: fill, a trailing "lost health" segment, dark back and
// border. With `with_stance` a thin golden stance bar runs underneath.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float ratio = 1.0;
uniform float lag = 1.0;
uniform float alpha = 1.0;
uniform bool with_stance = false;
uniform float stance = 0.0;
uniform vec4 fill_color : source_color = vec4(0.86, 0.22, 0.08, 1.0);
uniform vec4 lag_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform vec4 back_color : source_color = vec4(0.06, 0.03, 0.03, 0.85);
uniform vec4 stance_color : source_color = vec4(1.0, 0.78, 0.3, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	// UV.y: 0 = top. Health takes the top part, stance the thin strip below it.
	float split = with_stance ? 0.66 : 1.0;
	vec4 c = vec4(0.0);
	if (UV.y < split) {
		float y = UV.y / split;
		c = back_color;
		if (UV.x < lag) {
			c = lag_color;
		}
		if (UV.x < ratio) {
			c = fill_color;
		}
		if (UV.x < 0.015 || UV.x > 0.985 || y < 0.14 || y > 0.86) {
			c = vec4(0.0, 0.0, 0.0, 0.9);
		}
	} else if (UV.y > split + 0.08) {
		// Stance fills toward the break; it flashes white when nearly full
		c = vec4(0.05, 0.04, 0.02, 0.7);
		if (UV.x < stance) {
			c = stance > 0.85 ? mix(stance_color, vec4(1.0), 0.5 + 0.5 * sin(TIME * 18.0)) : stance_color;
		}
	}
	ALBEDO = c.rgb;
	ALPHA = c.a * alpha;
}
