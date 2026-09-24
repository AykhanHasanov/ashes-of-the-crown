// Recolors a KayKit texture atlas: pixels whose hue falls in [from_min, from_max]
// are shifted to `to_hue` (e.g. the Rogue's green cloth becomes crimson) while skin
// and leather stay untouched. `ash` fades everything toward grey (burned memories).
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float from_min = 0.18;
uniform float from_max = 0.55;
uniform float to_hue = 0.0;
uniform float sat_scale = 1.0;
uniform float val_scale = 0.8;
uniform vec4 tint : source_color = vec4(1.0);
uniform float ash = 0.0;
uniform float roughness = 0.8;

vec3 rgb2hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 h = rgb2hsv(c);
	if (h.x > from_min && h.x < from_max && h.y > 0.15) {
		h.x = to_hue;
		h.y = clamp(h.y * sat_scale, 0.0, 1.0);
		h.z *= val_scale;
	}
	c = hsv2rgb(h) * tint.rgb;
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))) * 0.8, ash);
	ALBEDO = c;
	ROUGHNESS = roughness;
}
