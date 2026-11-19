shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Greys a coloured MakeHuman hair texture (keeps its strand detail and alpha).

uniform sampler2D hair_texture : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.78, 0.76, 0.74, 1.0);

void fragment() {
	vec4 t = texture(hair_texture, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	// Lift and flatten luminance so dark hair reads as grey/white.
	float g = clamp(0.35 + l * 1.4, 0.0, 1.0);
	ALBEDO = tint.rgb * g;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.7;
}
