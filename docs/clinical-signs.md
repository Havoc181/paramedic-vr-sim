# Clinical signs library

How each patient sign is made, where the code is, and the settings that worked.
Add an entry every time a new sign is built, and note anything that didn't work.
Scenario values live in the scenario JSON under `characters.<id>.presentation`.

| Sign | Status | Scenario setting |
|---|---|---|
| Tripod posture | done | `posture: "tripod"` |
| Work of breathing (rate, depth, accessory muscles) | done | `respiratory_rate`, `breath_depth`, `work_of_breathing`, `accessory_muscles` |
| Breath sounds heard from the room | done | `sounds.breathing_external` |
| Breathless speech (words per breath) | done | `voice.breathless`, `speech`, `words_per_breath` |
| Mouth moving with speech, teeth and tongue | done | automatic from voice clips |
| Lip cyanosis | done | `skin.cyanosis` 0..1 |
| Clammy / sweaty skin | done | `skin.clammy_level` 0..1 (or `clammy: true` = 0.6) |
| Paradoxical abdominal movement | done (needs exposure) | `abdominal_paradox: true` |
| Exposure: top lifted / top off (bra) | done (Joan) | `make_humans.py` spec `exposure` |
| Wince and hold side on coughing | planned | `cough_wince: true` |

---

## Tripod posture
- **Code:** `scripts/patient/rig_driver.gd`, `POSTURES["tripod"]`, `_hand_on_knee()`.
- **How:** lean 42°, shoulders shrugged 12°, hands placed on the knees by two-joint IK with the elbow hinge measured from the rig, forearm twist spread along the split forearm bones, palm direction from the knuckles.
- **Lessons:** the 53-bone game rig twisted sleeves; use MakeHuman `default_no_toes` (137 bones). Skeleton global poses lag after `set_bone_pose_rotation`, so use `_gpose()`.

## Work of breathing
- **Code:** `rig_driver.apply_breath()`, `character.gd`, `scripts/patient/breathing.gd`.
- **How:** chest bone pitch and clavicle lift per breath; accessory muscle use = extra shoulder/clavicle lift; rate and inspiratory fraction from the scenario. During speech the chest follows the in-breath times from the voice manifest.

## Breathless speech
- **Code:** `tools/voice/` (Kokoro TTS + WORLD vocoder ageing + `breathless.py`).
- **How:** speech split into breath groups at natural boundaries, with in-breaths shaped from the speaker's own vowel. `...` in the scenario text marks breath points. See backlog "Voices" for sources.

## Mouth, teeth and tongue
- **Code:** `make_humans.py` adds MakeHuman `teeth_base` and `tongue01`; `rig_driver.set_jaw()` (up to 8°) driven by the 20 Hz mouth envelope from the voice manifest.
- **Look:** teeth multiplied by (0.86, 0.81, 0.72) for aged off-white, tongue by (0.6, 0.5, 0.5). Inside the mouth there is no ambient occlusion, so untinted teeth glow.
- **Check:** `tests/mouth_shot.gd` renders close-ups closed/open.

## Lip cyanosis
- **Code:** `shaders/skin_signs.gdshader`, `rig_driver._setup_skin_signs()`, `set_cyanosis()`.
- **How:** MakeHuman lips aren't a separate part, so they're found by position at load: body vertices just in front of the teeth, inside an ellipse 3 cm wide by 1.4 cm tall centred at 60% of the teeth height. The weight (soft edge) is baked into vertex colour R. The shader keeps the lip's own lightness and texture and swaps the hue to dusky blue-grey, slightly darker than the original.
- **Settings:** dusky colour (0.47, 0.47, 0.62), darkening 0.82, max blend 0.75. **Mild = 0.4** (notice it when you look at the mouth), marked = 0.7–0.75.
- **Didn't work:** first version (0.55, 0.52, 0.66) without darkening looked pale lilac, not cyanosed. A taller ellipse (1.7 cm) tinted the skin under the nose.
- **Future:** darker skin tones show cyanosis differently (check tongue/inner lip, nail beds); add nail beds and tongue tint when hands/mouth exams exist.

## Clammy / sweaty skin
- **Code:** same shader, `set_clammy()`; face mask baked into vertex colour G (forehead, nose, upper lip, cheeks: front of face from just below the mouth to 13 cm above it, 7.5 cm either side).
- **How:** a sheen rather than a colour: roughness falls from 0.62 towards 0.3 and specular rises 0.5 → 0.7, full strength on the face mask and 25% elsewhere. It shows as the light catches it when you move your head, like real mild sweat.
- **Settings:** **mild = 0.45**, moderate = 0.6 (Joan, APO), marked = 0.8+; 1.0 looks plastic.
- **Check:** `tests/skin_signs_shot.gd`; headset: pause menu "Test: patient skin".

## Hands on the thighs, clothing fit (21 Nov)
- Wrist height above the thigh is measured per model (front of thigh or trousers 9 cm above the knee, in the build pose) + 2.2 cm; the fixed 11.5 cm suited Joan but fingers sank into Maureen's fuller thighs.
- `tests/clip_check.gd`: six views of the patient in her scenario posture (standing, kneeling, each side, close on the hand, above), dressed or legs exposed. Run for every new character/outfit.
- Maureen's long top hung into a point between her thighs when seated: `top_trim` in make_humans.py cuts it 7 cm above the hip joint and unmasks the body below. Leggings read as tights: dark trousers instead (jeans with a `*#5a5e66` tint keeping the fabric texture).

## Tripod hands planted while breathing (21 Nov)
- `rig_driver._keep_hands()`: after the clavicles lift each breath, a two-joint IK (keeping the current bend plane) bends the elbows so the wrists stay where the posture put them. Wrist drift per breath 35 mm -> 0.7 mm. Also holds the hands on the seat in the sit-back posture.
- `_gpose()` now includes bone scale (the chest scales with breathing, which moves the shoulders).

## Legs exposure (21 Nov)
- Blender `expose_legs()`: copy of the skin under trousers and shoes below mid-calf (`<name>_skin_legs`); trousers copy cut cleanly at **mid-calf (knee - 15 cm)** with a turned-up cuff (copy of the band above the cut, 7 mm out, 8 mm down) (`_rolled`).
- **Didn't work:** gathering the cloth up above the knee (ragged shorts, cuff swung out as flaps when the knee bent, even with thigh weights copied); cutting just below the knee (cloth there blends thigh/shin weights, so it stretched into sheets). Mid-calf is clear of the knee joint and is where you look for ankle oedema anyway. Mottling therefore shows on the lower legs; knees need patients in shorts or a nightie.
- Godot: `set_legs_state("on"|"off")` swaps trousers/shoes for the rolled trousers and leg skin. Panel: "Roll up her trousers and take her shoes off" / "Cover her legs and put her shoes back on"; findings with `requires_exposure: "legs"`.

## Exposure: top on / lifted / off (bra on)
- **Why:** some signs (paradoxical abdominal movement, later chest signs) are only obvious when exposed, as in real practice.
- **Blender (`SourceAssets/make_humans.py`, `expose_layers`):** the body keeps its clothing mask (skin under the top stays hidden when dressed). The skin under the top is *copied* into two hidden patches, `<name>_skin_abdomen` (front two-thirds, below the underbust) and `<name>_skin_upper` (chest, back, arms), each grown by one face ring so they also cover the faces the body's mask removed along the edge, with the clothing masks removed from the copies. Also taken: the top 3.5 cm of skin the trousers' mask removes, because sitting pulls the waistband down and otherwise leaves a gap. Landmarks: bust apex = most forward point of the upper torso, underbust = 6 cm below. `<top>_lifted` = a copy of the top with the front below the underbust gathered up (to 14% of its depth) into soft folds; sides lift less, the back stays down. `<name>_bra` = a bandeau made from the body skin in the band underbust−1.5 cm to bust+5.5 cm, edges snapped straight, pushed out 4.5 mm, muted grey-mauve.
- **Godot (`rig_driver`):** `set_top_state("on"|"lifted"|"off")` swaps which meshes are visible; `character.set_exposure()` also moves her to the `sit_back` posture (hands on the seat beside her hips, smooth 1.4 s blend) and back to her own posture when covered. Panel: "Lift her top…", "Ask her to take her top off (bra on)", "Cover her up again"; findings with `requires_exposure: "abdomen"|"chest"` only appear once exposed. Debrief "The scene" reports what was exposed and whether she was covered again.
- **Lessons:** only gather the *torso* of the top when lifting it (|x| < 0.16–0.2 m): the sleeves hang below the chest in the build pose and were pulled up too, so the hands looked out of the sleeves (headset test 20 Nov). Draw the lifted top double-sided, or you see through the folds from inside at the sides. MPFB MASK modifiers delete any vertex with weight > 0 (use > 0.0001 when testing group membership, not 0.5). `bpy.ops.mesh.separate` loses the faces along the cut, so copy with a grown selection instead. Some nipple verts aren't in the top's mask, so build the bra from all skin in the band.
- **Check:** `tests/exposure_shot.gd` (front and side, each state, belly in/out).

## Paradoxical abdominal movement
- **Code:** `skin_signs.gdshader` (`belly`, `belly_depth`, default 3.5 cm; scenario `abdominal_movement_cm`), `rig_driver.apply_breath()`, scenario `abdominal_paradox: true`.
- **How:** the belly region (from just above the front of the trousers' waistband to the top of the abdomen patch; starting lower made it move through the jeans) is baked into vertex colour B on *all* skin meshes with the same function of position, so the body's lower belly and the patch move together. It moves straight forward/back (+Z), not along each normal, so nothing cracks. Paradoxical: drawn in on the in-breath, in time with the chest rising. Normal: out a little (35%).
- **Didn't work:** weighting by normal opened cracks at UV seams; only moving the patch opened a seam against the body's lower belly.
- **Tom (20 Nov):** first version (2.2 cm) good but mild for a real one; it varies with belly size, age and frailty, so it's per scenario: mild ~2.5 cm, marked 4–5 cm (Maureen 4).
- **Preview:** pause menu "Test: patient skin" > "Belly paradoxical", then lift her top.

---

---

# The signs system (v0.05-dev8, 20 Nov)

- **Registry:** `scripts/patient/sign_library.gd` lists every sign (id, label, system, how it's seen, exposure needed, "mild" strength, demo caption). Scenarios set them in `presentation.signs` (0..1); old keys (`skin.cyanosis`, `clammy_level`, `abdominal_paradox`) still work.
- **Controller:** `scripts/patient/signs.gd`, one per character. Landmarks come from the model's own bones (mouth from the oris bones, notch from the clavicles, fingertips from finger bones, knees/ankles from leg bones, JVP line from the right clavicle to the jaw) and sizes scale with the model's height (`_s`, 1 = Joan). Masks are baked once into vertex data (COLOR, CUSTOM0-2; layout at the top of signs.gd).
- **Shader:** `shaders/skin_signs.gdshader`. Movement is along fixed model axes or a baked direction, never per-vertex normals (no seams). Where the mesh is too coarse to show a dip (notch, subcostal, intercostal ribs, JVP) a little shading is added.
- **Live control:** instructor app "Clinical signs (live)" sliders (`cmd: sign`); headset state sends current strengths back.
- **Demo mode:** pause menu "Demo sign" cycles through every sign on its own with a caption, exposing her as needed.
- **Check:** `tests/sign_sheet.gd` renders every sign (moving ones breath-out | breath-in) to /tmp/signs; run it for every new character (`WHO=<id>`).

| Sign | Settings that worked (Joan) | Notes |
|---|---|---|
| Pallor | mix to own luminance x (1.03,1,0.96)x1.06, up to 55% | relative to skin, so works on darker skin |
| Grey / ashen | own luminance x (0.9,0.93,0.97)x0.9, up to 60% | |
| Flushing | x(1.1,0.9,0.9) on face mask, up to 70% | first try (1.16,0.86,0.86, hard edge) looked orange |
| Lip cyanosis | target darkens with strength (0.82-0.2s) | marked was pale lilac before |
| Tongue cyanosis | tongue material towards (0.55,0.52,0.72) | seen when she talks |
| Peripheral cyanosis | fingertip spheres 0.8-1.6 cm from tip | |
| Capillary refill | pressed tip goes (0.93,0.88,0.80); colour back over `capillary_refill_s` | hands-on: grip near the fingertip |
| Pulse | haptic per beat, amplitude from `pulse_volume`; irregular if `pulse_rhythm: irregular` | hands-on: grip near the wrist 4 s |
| Pursed lips | oris07 (lower lip sides) 9.6 mm, oris03 (upper) 4.8 mm to midline; oris04/06 5 mm forward; on the out-breath only | >6 mm on oris03 creases the philtrum |
| Drowsy | upper lids (orbicularis03) 24 deg x strength; head drifts 16 deg over ~6 s then jerks up | |
| Prolonged expiration | inhale share 0.4 -> 0.22 | |
| Suprasternal recession | 1.6 cm in, 3.8 cm radius, + shading | 2.4 cm radius only caught 6 vertices |
| Intercostal | 4 mm in at the sides + rib-spaced shadow lines (2.4 cm) | mesh too coarse for real grooves |
| Subcostal | 1 cm in, band just under the rib margin + shading | needs top off (lifted top covers it) |
| Hoover's sign | lower lateral ribs 1.5 cm in on inspiration | torso only, arms excluded |
| JVP | right neck line, shows up to `jvp` of its length; a and v waves per beat (no a wave in AF) | subtle by nature; check in headset |
| Mottling, ankle oedema | knees / ankles; shown with legs exposed (trousers rolled above the knees, shoes off) | |

**Darker skin (Maureen, sign sheet 21 Nov):** pallor and grey read as ashen; lip cyanosis reads grey-black at marked levels (tongue and inner lips are the reliable places clinically; tongue tint is in); fingertip cyanosis and capillary-refill blanching show well; clamminess shows clearly as sheen. **Mottling barely shows on dark skin** with the current darken-only pattern; needs a greyer, slightly lighter lace for darker skin (to do, with Tom's view of how it presents). Flushing is less visible on dark skin, as in life.


# Signs shopping list and roadmap (20 Nov, for Tom's review)

Legend: **★ = early priority**. Seen by: L look, H hear, F feel (controller), I interactive.
X = needs exposure. Effort: E easy (reuses existing shader/rig work), M medium, H hard.

## General appearance
| Sign | Seen | Effort | Notes |
|---|---|---|---|
| ★ Pallor / grey, ashen skin | L | E | whole-skin tone in skin shader; strength 0..1 |
| Flushing (sepsis, CO2 retention) | L | E | face/neck mask |
| Jaundice (skin and sclera) | L | E | sclera tint is the reliable one |
| ★ Peripheral cyanosis (nail beds, fingertips) | L | E | position mask from hand bones |
| ★ Central cyanosis of tongue | L | E | tongue tint (visible when talking) |
| Mottling (knees, legs) | L X | M | needs legs exposure; noise pattern masked to knees |
| Rigors / shivering | L | M | fast low-amplitude whole-body tremor |
| Distress / anxiety, frightened face | L | M | brow and eye shape (face bones) |
| ★ Drowsy / exhausted (eyelids heavy, head nodding) | L | M | eyelid bones; ties to CO2 retention |
| Dehydration (dry cracked lips, sunken eyes) | L | M | |
| Body build: cachexia, obesity, barrel chest | L | E–M | MakeHuman targets at build time |

## Respiratory
| Sign | Seen | Effort | Notes |
|---|---|---|---|
| Rate, depth, tripod, accessory muscles, speech | L H | done | |
| Paradoxical abdominal movement | L X | done | |
| ★ Hoover's sign (lower lateral ribs in on inspiration) | L X | E | same technique as belly, sides of costal margin |
| ★ Recession: suprasternal / tracheal tug, intercostal, subcostal | L (X) | E–M | suprasternal visible dressed |
| ★ Pursed-lip breathing, prolonged expiration | L H | E | lip shape + breath timing |
| Asymmetrical chest movement / splinting one side | L X | E | per-side chest movement |
| Nasal flaring | L | M | mainly paeds, still useful |
| Neck muscles standing out (SCM) | L | M | |
| Abnormal patterns: Kussmaul, Cheyne-Stokes, agonal, gasping | L H | E | breath timing presets |
| Cough types (dry, wet, productive, with wince) | L H | M | animation + sound |
| Sputum / haemoptysis / pink frothy sputum (props) | L | E | props |
| Sounds from the room: wheeze, stridor, grunting, gurgling | H | E–M | audio |
| Finger clubbing, nicotine staining | L | M | fingertip shape / tint |
| Tracheal deviation | L | M | late sign; subtle |
| Home oxygen, nebuliser, inhalers, rescue pack (props) | L | E | |

## Cardiovascular
| Sign | Seen | Effort | Notes |
|---|---|---|---|
| ★ Capillary refill (press nail: blanch, refill time) | I | M | high training value |
| ★ Pulse: rate, rhythm, volume (haptic) | F | M | irregular for AF |
| ★ Raised JVP (visible neck pulsation) | L | M | APO / right heart failure |
| ★ Peripheral oedema, pitting (press and dent stays) | L I X | M–H | needs legs exposure |
| Cool / warm peripheries | F | E | feel result by temperature |
| Clutching chest (Levine's sign), guarding | L | E | posture/hand pose |
| Orthopnoea (won't lie back) | L H | E | behaviour + line |
| Unilateral calf swelling (DVT) | L X | M | |
| Scars: sternotomy, pacemaker / ICD bulge | L X | E | texture decal |
| Sacral oedema | L X | H | needs repositioning |
| Splinter haemorrhages, xanthelasma, corneal arcus | L | E | close-up only |
| Varicose veins, leg ulcers | L X | M | |
| GTN spray, anticoagulant card (props) | L | E | |

## Early priority (proposed build order)
1. Foundation: sign registry, landmark-based regions, sign sheet test (see below).
2. Pallor/grey, peripheral + tongue cyanosis (cheap, reuse skin shader).
3. Recession + Hoover's sign (reuse belly technique).
4. Pursed lips + prolonged expiration.
5. Drowsy/CO2 retention look.
6. Capillary refill and pulse (first interactive "feel" signs).
7. JVP.
8. Legs exposure, then oedema and mottling.

## Reproducibility across human models
- **Signs are data:** a scenario lists sign ids with a strength 0..1. Nothing about a sign is tied to Joan.
- **Regions from landmarks, not fixed numbers:** lips from the teeth; belly from the trousers and the abdomen patch; neck, hands and chest from skeleton bones; distances scaled by the model's own measurements (e.g. head height, shoulder width). Audit needed: current hard-coded sizes (lip ellipse 3 x 1.4 cm, Blender torso |x| < 0.18 m, bra band) to be made proportional.
- **One build pipeline:** every character goes through `make_humans.py` and gets the same parts (teeth, tongue, exposure layers, later legs exposure) so new patients get every sign automatically. Ken still needs his own exposure version (top off, no bra).
- **Sign sheet test:** one automated render of every sign, at mild and marked, on every character, producing a contact sheet. Validates a new model in one run and doubles as demo-mode material.
- **Skin tone awareness:** pallor, cyanosis and jaundice look different on darker skin (check tongue, inner lips, conjunctivae, nail beds); build signs relative to the base skin, and include a darker-skinned patient early.
- **Each sign entry records:** clinical description, reference, Tom's sign-off, implementation, settings that worked, and per-model notes.

## Combining signs, tongue (21 Nov)
- Demo mode now combines signs (select to add/remove). Skin colours are exclusive: pallor, grey and flushing replace each other.
- Tongue cyanosis: tint applied with sqrt(strength) towards (0.38, 0.40, 0.85) on top of the darkened mouth colour; the earlier linear tint read as pink in the headset at 0.4.
