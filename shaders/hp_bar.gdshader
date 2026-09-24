// Camera-facing health bar: fill, a trailing "lost health" segment, dark back and border.
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;

uniform float ratio = 1.0;
uniform float lag = 1.0;
uniform float alpha = 1.0;
uniform vec4 fill_color : source_color = vec4(0.86, 0.22, 0.08, 1.0);
uniform vec4 lag_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform vec4 back_color : source_color = vec4(0.06, 0.03, 0.03, 0.85);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = back_color;
	if (UV.x < lag) {
		c = lag_color;
	}
	if (UV.x < ratio) {
		c = fill_color;
	}
	float border = step(UV.x, 0.015) + step(0.985, UV.x) + step(UV.y, 0.14) + step(0.86, UV.y);
	if (border > 0.0) {
		c = vec4(0.0, 0.0, 0.0, 0.9);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a * alpha;
}
