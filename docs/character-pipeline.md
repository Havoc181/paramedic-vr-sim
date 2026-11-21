# Character pipeline (agreed 21 Nov; built for Joan and Maureen 21 Nov, v0.06-dev1)

## As built (21 Nov)
- **make_humans.py** (`layers=` in a character spec): clothing masks are removed so the body
  keeps all its skin; plain grey bra and briefs are copied from the body's own skin
  (`<name>_bra`, `<name>_briefs`); a second UV map **"cover"** (Godot UV2) on every mesh:
  body `u` = bits 1 top, 2 trousers, 4 shoes, 8 torso; all meshes `v` = 1 - rest height.
  Skin counts as covered only if a ray along its normal hits the garment within 9 cm, at
  least 1.5 cm from any garment edge and 7 cm from the top's bottom hem / 5 cm from the
  trousers' waistband (the edges that move when she sits; otherwise you'd see through her).
- **Godot**: `rig_driver._setup_layers()` finds top (higher suit), trousers, shoes, underwear;
  garments use `shaders/garment.gdshader` (cut below a height: lifted top = torso only,
  just under the bust; rolled trousers = mid-calf; inside of fabric drawn darker);
  `skin_signs.gdshader` discards covered skin while that garment is worn and not cut there.
  Briefs are hidden while trousers are worn (trousers only roll up).
- Checks: `tests/layer_shots.gd` (every exposure state, front/side/close) and the sign sheet.
- Not yet: Ken (still the old build), automatic penetration report, garment weight transfer
  (not needed so far: MakeHuman's own clothes follow the body well once we stopped cutting
  and gathering copies of them).
- Replaces: lifted/bra/rolled garment copies and skin patches (old code path kept for Ken).


This replaces the approach of cutting clothes and skin apart for each exposure.

## The rule
Every patient starts as a **complete body in underwear**. Each garment is a separate layer
on top. Exposure means hiding a garment: the body underneath is already whole, so the
change is instant and shows exactly what the student asked to see. Nothing in assessment
needs more exposure than underwear. Over-exposing a patient in the sim is a learning point,
not a failure.

## How games do it (and what we'll copy)
1. **Body masks rather than deleted skin.** The body keeps all its skin. Each garment
   carries a list of body regions it covers. While a garment is on, the skin shader discards
   those regions; when it comes off, they show again. This is the standard technique
   (Reallusion CC4 "hide body mesh", inZOI region masks, MetaHuman culling masks).
   For us: region bits are baked into a vertex attribute, and `skin_signs.gdshader` discards
   covered fragments using a `covered_mask` uniform. This retires the `_skin_*` patch copies
   and the `_lifted`/`_bra` duplicates.
2. **Garment weights from the body.** Skin weights are copied from the body to the clothing
   (closest point, then weights filled in where there's no confident match: Epic's "robust
   weight transfer", available free as a Blender add-on). Tight areas follow the body exactly
   and loose areas blend smoothly. This removes the flapping and stretched cuffs.
3. **Small safety gap.** Garments are pushed 3–5 mm out along the body normal at build,
   plus a tiny depth bias in the cloth shader. This hides what weights can't fix.
4. **Posture-specific states, only where needed.** For example, a rolled sleeve or a lifted
   top is its own garment layer, built with the same weight transfer. These are not cut
   from the original.

## Contact (hands on thighs, tripod)
- Hand height is measured **in the posed state** (after sitting), not the build pose.
- Planted fingers get a light curl, so fingertips drape onto the surface.
- The automatic check (below) fails the build if any fingertip is inside the clothing.

## Checking every build (my job, every time)
- `tests/clip_check.gd`: six views of each patient in every scenario posture, dressed and
  in each exposure state.
- **Penetration test (to add):** in Blender, pose the model in each scenario posture and use
  a BVH to report any body or finger vertex inside a garment. The report lists the vertex
  and its depth in mm, and anything over 2 mm fails the build.
- **Compare with reference photos** of real people in the same posture (tripod, sitting back,
  top lifted) before Tom sees anything.

## Order of work
1. Underwear base body (Joan first), with region bits baked.
2. Shader masking. Garments then become layers you can switch on and off.
3. Weight transfer and the safety gap in make_humans.py. Re-dress Joan and Maureen.
4. Penetration test in the build.
5. Remove the old exposure duplicates.
