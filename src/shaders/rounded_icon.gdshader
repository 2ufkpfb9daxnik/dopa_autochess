shader_type canvas_item;

uniform float radius = 0.18;

void fragment() {
	vec2 box = vec2(0.5 - radius);
	vec2 delta = abs(UV - vec2(0.5)) - box;
	float dist = length(max(delta, vec2(0.0))) + min(max(delta.x, delta.y), 0.0) - radius;
	float edge = fwidth(dist);
	COLOR.a *= 1.0 - smoothstep(-edge, edge, dist);
}
