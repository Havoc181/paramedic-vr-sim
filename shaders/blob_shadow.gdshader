// Cheap soft contact shadow under furniture (stands in for baked ambient occlusion).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	ALBEDO = vec3(0.0);
	ALPHA = (1.0 - smoothstep(0.35, 1.0, r)) * strength;
}
