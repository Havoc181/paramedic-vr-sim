// Procedural oak floorboards, laid along world Z. No textures needed.
shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_colour : source_color = vec3(0.56, 0.39, 0.25);
uniform float plank_width = 0.16;
uniform float plank_length = 1.4;
uniform float roughness_value = 0.6;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float row = floor(p.x / plank_width);
	float offset = pvr_hash(vec2(row, 3.7)) * plank_length;
	float col = floor((p.y + offset) / plank_length);
	vec2 id = vec2(row, col);

	vec2 g = vec2(fract(p.x / plank_width), fract((p.y + offset) / plank_length));
	vec2 aa = max(fwidth(g) * 1.5, vec2(0.004));
	float seam = smoothstep(0.0, aa.x * 2.0, g.x) * smoothstep(1.0, 1.0 - aa.x * 2.0, g.x)
			* smoothstep(0.0, aa.y, g.y) * smoothstep(1.0, 1.0 - aa.y, g.y);

	float tint = 0.82 + 0.3 * pvr_hash(id);
	float grain = pvr_noise(vec2(p.x * 45.0, p.y * 3.0) + id * 13.0) * 0.6
			+ pvr_noise(vec2(p.x * 110.0, p.y * 7.0) + id * 5.0) * 0.4;
	vec3 c = base_colour * tint * (0.82 + 0.3 * grain);
	ALBEDO = c * mix(0.6, 1.0, seam);
	ROUGHNESS = roughness_value + 0.2 * (1.0 - seam);
}
