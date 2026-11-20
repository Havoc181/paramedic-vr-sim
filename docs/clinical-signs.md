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

## Exposure: top on / lifted / off (bra on)
- **Why:** some signs (paradoxical abdominal movement, later chest signs) are only obvious when exposed, as in real practice.
- **Blender (`SourceAssets/make_humans.py`, `expose_layers`):** the body keeps its clothing mask (skin under the top stays hidden when dressed). The skin under the top is *copied* into two hidden patches, `<name>_skin_abdomen` (front two-thirds, below the underbust) and `<name>_skin_upper` (chest, back, arms), each grown by one face ring so they also cover the faces the body's mask removed along the edge, with the clothing masks removed from the copies. Also taken: the top 3.5 cm of skin the trousers' mask removes, because sitting pulls the waistband down and otherwise leaves a gap. Landmarks: bust apex = most forward point of the upper torso, underbust = 6 cm below. `<top>_lifted` = a copy of the top with the front below the underbust gathered up (to 14% of its depth) into soft folds; sides lift less, the back stays down. `<name>_bra` = a bandeau made from the body skin in the band underbust−1.5 cm to bust+5.5 cm, edges snapped straight, pushed out 4.5 mm, muted grey-mauve.
- **Godot (`rig_driver`):** `set_top_state("on"|"lifted"|"off")` swaps which meshes are visible; `character.set_exposure()` also moves her to the `sit_back` posture (hands on the seat beside her hips, smooth 1.4 s blend) and back to her own posture when covered. Panel: "Lift her top…", "Ask her to take her top off (bra on)", "Cover her up again"; findings with `requires_exposure: "abdomen"|"chest"` only appear once exposed. Debrief "The scene" reports what was exposed and whether she was covered again.
- **Lessons:** MPFB MASK modifiers delete any vertex with weight > 0 (use > 0.0001 when testing group membership, not 0.5). `bpy.ops.mesh.separate` loses the faces along the cut, so copy with a grown selection instead. Some nipple verts aren't in the top's mask, so build the bra from all skin in the band.
- **Check:** `tests/exposure_shot.gd` (front and side, each state, belly in/out).

## Paradoxical abdominal movement
- **Code:** `skin_signs.gdshader` (`belly`, `belly_depth` 2.2 cm), `rig_driver.apply_breath()`, scenario `abdominal_paradox: true`.
- **How:** the belly region (from 5 cm under the trousers' waistband to the top of the abdomen patch) is baked into vertex colour B on *all* skin meshes with the same function of position, so the body's lower belly and the patch move together. It moves straight forward/back (+Z), not along each normal, so nothing cracks. Paradoxical: drawn in on the in-breath, in time with the chest rising. Normal: out a little (35%).
- **Didn't work:** weighting by normal opened cracks at UV seams; only moving the patch opened a seam against the body's lower belly.
- **Preview:** pause menu "Test: patient skin" > "Belly paradoxical", then lift her top.
