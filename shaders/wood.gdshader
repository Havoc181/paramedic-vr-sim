// Procedural wood grain for furniture.
shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_colour : source_color = vec3(0.32, 0.21, 0.13);
uniform float roughness_value = 0.55;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = world_pos.x + world_pos.z;
	float grain = pvr_noise(vec2(along * 4.0, world_pos.y * 60.0 + along * 2.0)) * 0.6
			+ pvr_noise(vec2(along * 12.0, world_pos.y * 140.0)) * 0.4;
	ALBEDO = base_colour * (0.8 + 0.35 * grain);
	ROUGHNESS = roughness_value;
}
