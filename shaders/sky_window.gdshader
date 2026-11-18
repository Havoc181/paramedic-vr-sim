// The view out of the window: a simple daytime sky gradient.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec3 horizon : source_color = vec3(0.86, 0.9, 0.95);
uniform vec3 zenith : source_color = vec3(0.45, 0.65, 0.92);

void fragment() {
	ALBEDO = mix(horizon, zenith, smoothstep(0.0, 1.0, 1.0 - UV.y));
}
