shader_type spatial;
// Skin that can show clinical signs. Masks are baked per vertex at load by
// scripts/patient/signs.gd (see there for the channel layout); strengths come
// from the scenario / instructor (0..1). Kept cheap for Quest: no extra
// textures, a little maths per vertex and pixel.
render_mode cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float base_roughness = 0.62;
uniform float model_scale = 1.0;

// Colour signs.
uniform float cyanosis : hint_range(0.0, 1.0) = 0.0;       // lips
uniform float nail_cyanosis : hint_range(0.0, 1.0) = 0.0;  // fingertips
uniform float clammy : hint_range(0.0, 1.0) = 0.0;
uniform float pallor : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float flushing : hint_range(0.0, 1.0) = 0.0;
uniform float mottling : hint_range(0.0, 1.0) = 0.0;
uniform float blanch : hint_range(0.0, 1.0) = 0.0;         // capillary refill press
uniform vec3 dusky = vec3(0.47, 0.47, 0.62);

// Movement signs (already multiplied by the breath / heartbeat on the CPU).
uniform float belly = 0.0;          // -1..1, negative = drawn in
uniform float belly_depth = 0.035;
uniform float recess_ss = 0.0;      // suprasternal
uniform float recess_ic = 0.0;      // intercostal
uniform float recess_sc = 0.0;      // subcostal
uniform float hoover = 0.0;
uniform float jvp_height = 0.0;     // 0..1 up the neck
uniform float jvp_pulse = 0.0;      // 0..1 within each heartbeat
uniform float oedema = 0.0;

// Layered characters (21 Nov): skin under a worn garment is hidden, and shows
// again when the garment comes off or is cut away (lifted top, rolled trousers).
// UV2.x = bits 1 top, 2 lower, 4 shoes, 8 torso; UV2.y = 1 - rest height.
// Modes: 0 off (skin shows), 1 worn, 2 cut below the cut height.
uniform int top_mode = 0;
uniform float top_cut = -10.0;
uniform int lower_mode = 0;
uniform float lower_cut = -10.0;
uniform bool shoes_on = false;
varying flat float cover_bits;
varying float rest_z;

varying vec4 mask;      // r lips, g face, b belly, a fingertips
varying vec2 legs;      // x knees, y ankles
varying vec3 mpos;      // model-space position (for the mottling pattern)
varying float ic_band;  // intercostal region
varying float ss_dip;   // suprasternal dip, already scaled by the breath
varying float jvp_vis;  // visible JVP column, already scaled by the pulse

void vertex() {
	cover_bits = UV2.x;
	rest_z = 1.0 - UV2.y;
	mask = COLOR;
	legs = CUSTOM1.yz;
	float s = model_scale;
	// All moves are along fixed model axes (or a baked direction), never the
	// per-vertex normal, so vertices split at UV seams move together.
	VERTEX.z += belly * belly_depth * COLOR.b;
	VERTEX.z -= recess_ss * 0.016 * s * CUSTOM0.x;
	VERTEX.y -= recess_ss * 0.005 * s * CUSTOM0.x;
	ss_dip = recess_ss * CUSTOM0.x + recess_sc * CUSTOM0.z * 0.8 + hoover * CUSTOM0.w * 0.4;
	jvp_vis = 0.0;
	ic_band = CUSTOM0.y;
	VERTEX.x -= sign(VERTEX.x) * recess_ic * 0.004 * s * CUSTOM0.y;
	VERTEX.z -= recess_sc * 0.010 * s * CUSTOM0.z;
	VERTEX.x -= sign(VERTEX.x) * hoover * 0.015 * s * CUSTOM0.w;
	// JVP: the column shows up to jvp_height along the neck line, pulsing.
	float j = CUSTOM1.x;
	if (j > 0.0) {
		float on = 1.0 - smoothstep(jvp_height - 0.08, jvp_height + 0.02, j);
		float shown = on * step(0.01, jvp_height);
		VERTEX.x += sign(VERTEX.x) * shown * (0.0015 + 0.0045 * jvp_pulse) * s;
		jvp_vis = shown * (0.35 + 0.65 * jvp_pulse);
	}
	VERTEX += CUSTOM2.xyz * oedema * 0.012 * s * CUSTOM1.z;
	mpos = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void fragment() {
	int cb = int(cover_bits + 0.5);
	if ((cb & 1) != 0 && top_mode > 0 && !(top_mode == 2 && (cb & 8) != 0 && rest_z < top_cut)) {
		discard;
	}
	if ((cb & 2) != 0 && lower_mode > 0 && !(lower_mode == 2 && rest_z < lower_cut)) {
		discard;
	}
	if ((cb & 4) != 0 && shoes_on) {
		discard;
	}
	vec3 a = texture(albedo_texture, UV).rgb;
	float l = dot(a, vec3(0.299, 0.587, 0.114));
	vec3 lum_dusky = l * dusky / dot(dusky, vec3(0.299, 0.587, 0.114));
	// Whole-skin tone: relative to the skin's own lightness, so it also reads
	// on darker skin (pallor = less red, slightly lighter / ashen; grey = cooler, flatter).
	a = mix(a, vec3(l) * vec3(1.03, 1.0, 0.96) * 1.06, pallor * 0.55);
	a = mix(a, vec3(l) * vec3(0.9, 0.93, 0.97) * 0.9, grey * 0.6);
	a = mix(a, a * vec3(1.1, 0.9, 0.9), flushing * smoothstep(0.0, 0.6, mask.g) * 0.7);
	// Lips and fingertips: dusky blue-grey, keeping their texture.
	// Darker as it gets more marked (marked cyanosis is dusky, not pale lilac).
	a = mix(a, (0.82 - 0.2 * cyanosis) * lum_dusky, clamp(mask.r * cyanosis, 0.0, 1.0) * 0.75);
	a = mix(a, 0.85 * lum_dusky, clamp(mask.a * nail_cyanosis, 0.0, 1.0) * 0.7);
	// Capillary refill: pressed fingertip goes pale yellow-white.
	a = mix(a, vec3(0.93, 0.88, 0.80) * max(l, 0.6) * 1.15, mask.a * blanch * 0.85);
	// Mottling: lacy purple network over the knees.
	if (legs.x * mottling > 0.001) {
		float n = vnoise(mpos * 55.0 / model_scale) * 0.65 + vnoise(mpos * 130.0 / model_scale) * 0.35;
		float lace = 1.0 - smoothstep(0.04, 0.16, abs(n - 0.5));
		a = mix(a, a * vec3(0.72, 0.55, 0.78), lace * legs.x * mottling * 0.85);
	}
	// The mesh is coarse here, so add the shadow that the dip / vein would cast.
	a *= 1.0 - ss_dip * 0.35;
	a = mix(a, a * vec3(0.86, 0.85, 0.92), clamp(jvp_vis, 0.0, 1.0) * 0.45);
	// Intercostal recession: shadowed grooves between the ribs on each breath in.
	if (ic_band * recess_ic > 0.001) {
		float rib = pow(0.5 + 0.5 * cos(6.2832 * mpos.y / (0.024 * model_scale)), 4.0);
		a *= 1.0 - rib * ic_band * recess_ic * 0.35;
	}
	ALBEDO = a;
	float sheen = clammy * mix(0.25, 1.0, mask.g);
	ROUGHNESS = mix(base_roughness, 0.3, sheen);
	SPECULAR = mix(0.5, 0.7, sheen);
}
