// Screen vignette with a red pulse when Ayxan is hurt.
shader_type canvas_item;

uniform float strength = 0.6;
uniform float damage = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.35, 0.85, length(uv * vec2(1.25, 1.0)));
	vec3 tint = mix(vec3(0.0), vec3(0.45, 0.02, 0.0), damage);
	COLOR = vec4(tint, v * (strength + damage * 0.35));
}
