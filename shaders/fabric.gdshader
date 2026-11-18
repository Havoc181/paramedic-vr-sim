// Soft fabric with a faint weave so flat colours don't look like plastic.
shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_colour : source_color = vec3(0.3, 0.36, 0.38);
uniform float weave_scale = 90.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz + world_pos.yy * 0.7;
	float weave = pvr_noise(p * weave_scale) * 0.5 + pvr_noise(p * weave_scale * 0.25) * 0.5;
	ALBEDO = base_colour * (0.88 + 0.16 * weave);
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
