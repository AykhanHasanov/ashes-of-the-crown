// A thin cool rim on every character, drawn as an overlay (material_overlay) over whatever
// the model's own materials are. It keeps a body readable against a dark ground at any time
// of day, and it is the same rim on Aras, Rüfət and every enemy, which is part of what makes
// models from different sources look like they belong to one game.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

uniform vec3 rim_color : source_color = vec3(0.62, 0.7, 0.92);
uniform float rim_power = 3.5;
uniform float rim_strength = 0.3;
instance uniform float hit_flash = 0.0;

void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = rim_color * fres * rim_strength + vec3(1.0) * hit_flash * 0.8;
}
