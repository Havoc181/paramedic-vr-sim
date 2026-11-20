extends RefCounted
## The clinical signs the simulator can show. Each sign has a strength 0..1 in
## the scenario (presentation.signs), can be changed live by the instructor, and
## is shown one at a time in demo mode. How each is built and tuned is in
## docs/clinical-signs.md (keep both in step).
##
## seen: L look, H hear, F feel, I interactive. exposure: what must be exposed to
## see it ("" = visible dressed). mild: the strength that reads as "mild".

const SIGNS := {
	# --- General appearance -------------------------------------------------
	"pallor": {"label": "Pallor", "system": "general", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Pale skin: less pink, especially lips and face."},
	"grey": {"label": "Grey / ashen skin", "system": "general", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Grey, ashen colour of shock or a peri-arrest patient."},
	"flushing": {"label": "Flushing", "system": "general", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Flushed face and neck (sepsis, CO2 retention)."},
	"clammy": {"label": "Clammy / sweaty", "system": "general", "seen": "L", "exposure": "", "mild": 0.45,
		"demo": "A sheen of sweat, strongest on the face."},
	"drowsy": {"label": "Drowsy (heavy eyelids, head nodding)", "system": "general", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Eyelids heavy, head drifting down and jerking back: tiring or CO2 retention."},
	# --- Respiratory ----------------------------------------------------------
	"cyanosis_lips": {"label": "Central cyanosis (lips)", "system": "respiratory", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Dusky blue-grey lips."},
	"cyanosis_tongue": {"label": "Central cyanosis (tongue)", "system": "respiratory", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Dusky tongue, seen when she talks. Reliable on darker skin."},
	"cyanosis_peripheral": {"label": "Peripheral cyanosis (fingertips, nail beds)", "system": "cardiovascular", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Blue-grey fingertips and nail beds."},
	"pursed_lips": {"label": "Pursed-lip breathing", "system": "respiratory", "seen": "L", "exposure": "", "mild": 0.5,
		"demo": "Lips pursed on each breath out (COPD)."},
	"prolonged_expiration": {"label": "Prolonged expiration", "system": "respiratory", "seen": "LH", "exposure": "", "mild": 0.5,
		"demo": "Breathing out takes much longer than breathing in."},
	"recession_suprasternal": {"label": "Suprasternal recession / tracheal tug", "system": "respiratory", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "The notch above the breastbone sucks in on each breath in."},
	"recession_intercostal": {"label": "Intercostal recession", "system": "respiratory", "seen": "L", "exposure": "chest", "mild": 0.4,
		"demo": "Skin between the ribs at the sides sucks in on each breath in."},
	"recession_subcostal": {"label": "Subcostal recession", "system": "respiratory", "seen": "L", "exposure": "chest", "mild": 0.4,
		"demo": "Skin under the rib margin draws in on each breath in."},
	"hoovers_sign": {"label": "Hoover's sign", "system": "respiratory", "seen": "L", "exposure": "chest", "mild": 0.5,
		"demo": "Lower ribs at the sides move in, not out, on each breath in (hyperinflated COPD)."},
	"abdominal_paradox": {"label": "Paradoxical abdominal movement", "system": "respiratory", "seen": "L", "exposure": "abdomen", "mild": 0.6,
		"demo": "Belly draws in as the chest rises: tiring diaphragm."},
	# --- Cardiovascular -------------------------------------------------------
	"jvp": {"label": "Raised JVP", "system": "cardiovascular", "seen": "L", "exposure": "", "mild": 0.4,
		"demo": "Pulsation in the right side of the neck; higher up the neck = higher JVP."},
	"capillary_refill": {"label": "Capillary refill (slow)", "system": "cardiovascular", "seen": "I", "exposure": "", "mild": 0.5,
		"demo": "Press a fingertip: it blanches, and colour comes back slowly."},
	"mottling": {"label": "Mottling", "system": "cardiovascular", "seen": "L", "exposure": "legs", "mild": 0.4,
		"demo": "Lacy purple pattern over the knees."},
	"oedema_ankle": {"label": "Ankle oedema", "system": "cardiovascular", "seen": "L", "exposure": "legs", "mild": 0.4,
		"demo": "Swollen ankles."},
}

const ORDER := ["pallor", "grey", "flushing", "clammy", "drowsy",
	"cyanosis_lips", "cyanosis_tongue", "cyanosis_peripheral", "pursed_lips", "prolonged_expiration",
	"recession_suprasternal", "recession_intercostal", "recession_subcostal", "hoovers_sign",
	"abdominal_paradox", "jvp", "capillary_refill", "mottling", "oedema_ankle"]


## Older scenario keys mapped onto signs, so existing scenarios keep working.
static func from_presentation(p: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var skin: Dictionary = p.get("skin", {})
	if skin.has("cyanosis"):
		out["cyanosis_lips"] = float(skin["cyanosis"])
	if skin.has("clammy_level"):
		out["clammy"] = float(skin["clammy_level"])
	elif skin.get("clammy", false):
		out["clammy"] = 0.6
	if p.get("abdominal_paradox", false):
		out["abdominal_paradox"] = 1.0
	for k in p.get("signs", {}):
		if not String(k).begins_with("_"):
			out[k] = float(p["signs"][k])
	return out
