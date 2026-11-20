shader_type spatial;
// Skin with two clinical signs driven by per-vertex masks (built at load in
// rig_driver.gd): COLOR.r = lips and just around them, COLOR.g = face (forehead,
// nose, upper lip, cheeks) where sweat shows first.
//   cyanosis 0..1: lips lose their pink and go dusky blue-grey (subtle by design).
//   clammy   0..1: a fine sheen, strongest on the face, faint elsewhere.
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float base_roughness = 0.62;
uniform float cyanosis : hint_range(0.0, 1.0) = 0.0;
uniform float clammy : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dusky = vec3(0.47, 0.47, 0.62);

varying vec2 mask;

void vertex() {
	mask = COLOR.rg;
}

void fragment() {
	vec3 a = texture(albedo_texture, UV).rgb;
	float lip = clamp(mask.x * cyanosis, 0.0, 1.0);
	// Keep the lip's own lightness and texture, swap its hue towards dusky violet-grey.
	float l = dot(a, vec3(0.299, 0.587, 0.114));
	// Slightly darker than the lip was: cyanosed lips look dusky, not pale lilac.
	vec3 blue = 0.82 * l * dusky / dot(dusky, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(a, blue, lip * 0.75);
	float sheen = clammy * mix(0.25, 1.0, mask.y);
	ROUGHNESS = mix(base_roughness, 0.3, sheen);
	SPECULAR = mix(0.5, 0.7, sheen);
}
