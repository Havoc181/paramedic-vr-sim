// Head-locked sphere drawn around the eyes: tunnel vignette while moving,
// plus a full fade to black for teleports.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, blend_mix, shadows_disabled, fog_disabled;

uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float inner_angle = 0.55;
uniform float outer_angle = 1.05;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

varying vec3 local_dir;

void vertex() {
	local_dir = VERTEX;
}

void fragment() {
	vec3 d = normalize(local_dir);
	float angle = acos(clamp(-d.z, -1.0, 1.0));
	float v = smoothstep(inner_angle, outer_angle, angle) * vignette;
	ALBEDO = vec3(0.0);
	ALPHA = clamp(max(v, fade), 0.0, 1.0);
}
