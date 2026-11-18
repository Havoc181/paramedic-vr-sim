// Patterned rug: border bands and a soft central field.
shader_type spatial;
#include "res://shaders/noise.gdshaderinc"

uniform vec3 field_colour : source_color = vec3(0.55, 0.2, 0.18);
uniform vec3 border_colour : source_color = vec3(0.85, 0.75, 0.55);
uniform vec3 band_colour : source_color = vec3(0.2, 0.22, 0.3);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	// Distance to the rug edge in metres (rug mesh is a flat box centred on its origin).
	vec2 half_size = vec2(1.2, 0.85);
	vec2 d = half_size - abs(local_pos.xz);
	float edge = min(d.x, d.y);
	vec3 c = field_colour;
	c = mix(c, band_colour, step(edge, 0.22) * step(0.16, edge));
	c = mix(c, border_colour, step(edge, 0.12));
	float pile = pvr_noise(local_pos.xz * 120.0);
	ALBEDO = c * (0.85 + 0.2 * pile);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
