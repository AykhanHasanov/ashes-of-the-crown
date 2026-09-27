// Shared wind for generated trees (tools/gen_trees.gd): the whole tree leans with slow
// gusts that roll across the valley, growing with height², so bark and leaf cards move
// together. Leaves add a quick flutter weighted by COLOR.b (0 at a card's stem, 1 at its tip).

global uniform float wind_strength;

uniform float tree_height = 12.0;

vec3 tree_sway(vec3 vertex, mat4 model, float flutter_weight, float time) {
	vec3 root = model[3].xyz;
	float h = clamp(vertex.y / tree_height, 0.0, 1.2);
	float bend = h * h;
	float gust = sin(root.x * 0.05 + time * 0.8) * 0.6 + sin(root.z * 0.04 + time * 0.53) * 0.4;
	float sway = (0.25 + gust * 0.75) * (0.3 + wind_strength);
	vec3 offset = vec3(sway, 0.0, sway * 0.4) * bend * 0.35;
	float phase = dot(vertex, vec3(1.3, 0.7, 1.1)) + root.x * 0.3;
	offset += vec3(sin(time * 6.1 + phase), sin(time * 4.7 + phase * 1.3) * 0.6, cos(time * 5.3 + phase)) * 0.045 * flutter_weight * (0.3 + wind_strength);
	return offset;
}

// A stable 0..1 random per tree instance
float tree_hash(mat4 model) {
	vec2 p = model[3].xz;
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
