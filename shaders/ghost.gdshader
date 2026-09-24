// Ember-echo apparition: a hollow, flickering silhouette of glowing ash.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform float alpha = 1.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float flicker = 0.8 + 0.2 * sin(TIME * 13.0 + FRAGCOORD.y * 0.08);
	ALBEDO = color.rgb * (0.12 + fres * 1.5) * alpha * flicker;
}
