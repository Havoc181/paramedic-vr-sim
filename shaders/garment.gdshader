shader_type spatial;
// Clothes on the layered characters (21 Nov rebuild). The garment can be cut
// away below a height without any extra mesh:
//   mode 1 = worn; 2 = cut below cut_z (a lifted top: torso only; rolled
//   trousers: everything). Hiding a garment completely is done by visibility.
// UV2 (from Blender's "cover" map): x = 8 on torso vertices, y = 1 - rest height.
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = true;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool use_normal = false;
uniform float roughness = 0.85;
uniform int mode = 1;
uniform float cut_z = -10.0;
uniform bool torso_only = false;

varying float rest_z;
varying flat float flags;

void vertex() {
	rest_z = 1.0 - UV2.y;
	flags = UV2.x;
}

void fragment() {
	if (mode == 2 && rest_z < cut_z && (!torso_only || flags > 7.5)) {
		discard;
	}
	vec4 c = albedo_color;
	if (use_texture) {
		c *= texture(albedo_texture, UV);
	}
	// Inside of the fabric (seen at a cut edge or up a sleeve): darker.
	ALBEDO = FRONT_FACING ? c.rgb : c.rgb * 0.4;
	ROUGHNESS = roughness;
	if (use_normal && FRONT_FACING) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
	}
}
