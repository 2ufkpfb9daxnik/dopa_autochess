shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 aura_color : source_color = vec4(0.42, 0.95, 0.72, 0.62);
uniform float flow_speed = 0.7;
uniform float patch_scale = 2.6;
uniform float threshold_low = 0.32;
uniform float threshold_high = 0.68;
uniform float rim_boost = 0.7;
uniform float density = 1.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.11, 0.17, 0.23));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash(i);
	float n100 = hash(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	float nxy0 = mix(nx00, nx10, f.y);
	float nxy1 = mix(nx01, nx11, f.y);
	return mix(nxy0, nxy1, f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += a * value_noise(p);
		p = p * 2.03 + vec3(1.7, 3.1, 2.3);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec3 flow_a = vec3(TIME * flow_speed, TIME * flow_speed * 0.61, TIME * flow_speed * 0.37);
	vec3 flow_b = vec3(-TIME * flow_speed * 0.82, TIME * flow_speed * 0.44, -TIME * flow_speed * 0.29);
	vec3 sample_pos = NORMAL * patch_scale;
	float field = fbm(sample_pos + flow_a) * 0.62 + fbm(sample_pos * 1.65 - flow_b) * 0.38;
	float wind = smoothstep(threshold_low, threshold_high, field);
	float clearings = smoothstep(0.18, 0.58, fbm(sample_pos * 0.9 + flow_b.yzx));
	wind *= mix(0.15, 1.0, clearings);
	float view_dot = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - view_dot, 1.4);
	float alpha = aura_color.a * density * wind * mix(0.45, 1.0, rim * rim_boost);
	if (alpha < 0.025) {
		discard;
	}
	ALBEDO = aura_color.rgb;
	ALPHA = clamp(alpha, 0.0, 0.92);
}
