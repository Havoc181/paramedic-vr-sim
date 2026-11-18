// Small value-noise helpers shared by the procedural materials.
float pvr_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float pvr_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(pvr_hash(i), pvr_hash(i + vec2(1.0, 0.0)), u.x),
			mix(pvr_hash(i + vec2(0.0, 1.0)), pvr_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
