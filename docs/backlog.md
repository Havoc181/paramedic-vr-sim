# Ideas backlog

Agreed ideas not yet scheduled. Newest first.

## Hands-on assessment (agreed in principle, 2026-11-18)
- Findings are revealed by doing the assessment physically, not from a menu.
- Feel: hold fingers on the radial pulse / forehead / ankle for a couple of seconds.
  - No haptic "buzz" for skin temperature, and vibration is not used as a pulse
    simulation (doesn't feel like one). Show the finding as words instead;
    possibly test a very short, soft "tap" later as an option.
- Look: exposure (nightdress hem over the ankles), viewing angle and distance
  for neck veins, counting respiratory rate by watching the chest.
- Listen: wet breathing audible only within ~50 cm of the patient.
- Debrief shows "what you found" against "what was there to find" (agreed):
  each assessment zone records whether it was used. Explains, doesn't score.
- Build order: pulse, listening distance, counting breaths, exposure and pitting.

## Consent before exposing or touching (stored, not yet)
- Learner asks permission before exposing or touching; patient responds.
- Deferred: unclear how to assess it, and adds complexity too early.

## Seated / standing play
- Standing and kneeling need nothing special (floor is tracked).
- Seated players: seated mode (exists) plus a crouch toggle to get down to the
  patient's level.
- Auto-detection: measure head height at start; if clearly seated, offer seated
  mode with a confirmation rather than switching silently.

## Wider considerations (raised 2026-11-18, not yet decided)

### Clinical and educational
- **Differential scenarios:** same room, same "breathless older person"
  opening, different causes (APO, pneumonia, COPD, PE), so learners must
  discriminate rather than pattern-match one case.
- **Variation within a scenario:** observations within realistic ranges,
  different bystander behaviour, so repeat runs can't be memorised.
- **Patient demographics:** different ages, sexes and skin tones. Pallor and
  cyanosis look different on darker skin and are under-taught; good for
  teaching and inclusion.
- **Dynamic physiology (later):** deterioration over time; response to
  treatment once equipment and interventions exist.
- **Scene realism (later):** dispatch info, arrival at the door, scene safety,
  a virtual crewmate.
- **Scenario authoring:** keep scenarios as data files; later a simple
  authoring tool or spreadsheet so cases can be written without code.
- **Clinical governance:** each scenario has a version, references, reviewer(s)
  and a review date; second clinical reviewer before release; "educational
  use only, not clinical guidance" statement.
- **CPD evidence:** export a short reflection or summary after a session that
  can go in a CPD portfolio (useful selling point).

### Accessibility and comfort
- Subtitles (done), adjustable text size, left-handed option (pointer on
  either hand), seated play, colour choices that don't rely on red/green.
- Voices: recorded voice acting vs. offline text-to-speech; subtitles stay.

### Technical
- **Performance budget:** hold 90 Hz on Quest 3; check every version on the
  headset (shadows are the first thing to cut).
- **Large-file storage plan (agreed 2026-11-18):** GitHub Free includes
  10 GiB LFS storage and 10 GiB/month LFS bandwidth; every committed version
  of a large file counts, not just the latest.
  - Commit only game-ready exports (.glb, compressed textures, .ogg audio).
  - Keep working source files (.blend, raw .wav, high-res textures) outside
    the repo in a cloud-synced folder, e.g. C:\ClaudeDevP1\SourceAssets.
  - Compress: textures 1-2k, mesh compression on export, OGG audio.
  - Don't commit every small tweak of a large file; commit when it's settled.
  - Check usage in GitHub Settings > Billing occasionally; optionally set a
    small spending limit later instead of the default hard stop.
  - If it's outgrown: compare other hosts or paid LFS at that point.
- **Version number in the app** (menu) so testers can say what they ran.
- **One-click build and install** to the headset.
- **Logging:** write a log file on the headset to help diagnose problems.
- **Test checklist** per version.

### Legal and commercial
- **IP:** project lead's own idea and work; no third parties involved so far
  (others have only offered help). Keep it that way in writing if anyone
  contributes later (simple contributor agreement). Worth a one-off glance at
  employment/university terms for side-project clauses before selling.
- **Licences:** keep a third-party licences file (Godot MIT, OpenXR vendors
  plugin, MakeHuman/MPFB assets, any sounds). Check each asset's licence
  before use.
- **Regulation:** a training tool not used in patient care is unlikely to be
  a medical device; keep all claims educational.
- **Data protection:** no personal data now; if accounts or analytics are
  added later, GDPR applies.
- **Distribution:** sideload for pilots; later Meta Horizon store or direct
  sales to universities/trusts. Product name needed eventually.
- **Evidence:** a pilot evaluation with students/clinicians (ethics approval
  if it's going to be published).

## Audio plan (agreed 2026-11-18)
- **Framework first:** every spoken line and breathing state in the scenario
  file has a sound slot; empty slot = subtitle only. Subtitles always on.
- **Voices:** Kokoro TTS (Apache 2.0 weights, trained on permissive data,
  British voices e.g. bf_emma, bf_isabella, bm_george, bm_lewis), run offline
  on the PC. Generate lines phrase by phrase, age them in post-processing
  (pitch, tremor, pace) and join phrases with synthesised breaths for
  breathlessness. Avoid Piper (most voices non-commercial).
- **Breathing:** `tools/breath_synth.py` builds sounds from physiology
  (rate, I:E, effort, airway noise, fine/medium/coarse crackles, wheeze);
  no licensing issues. v2 rebuilt on published acoustics:
  - Vesicular sound: soft, low-pitched (<200 Hz), power falling with
    frequency; inspiration max ~450 Hz, expiration ~290 Hz
    (J Appl Physiol 1981;50:307; Crit Care 2023, PMC10543330).
  - Crackles by CORSA time-domain features: fine IDW ~0.7 ms / 2CD ~5 ms,
    coarse IDW ~1.5 ms / 2CD ~10 ms (Southampton crackle detection paper;
    Munakata, Thorax 1991;46:651). Heart-failure crackles between the two.
  - Two listeners kept separate (agreed 2026-11-18): **external** (through
    the air near the face: nose/mouth airflow plus only the coarse rattle
    that carries out of the airways; no vesicular sound) and **chest**
    (stethoscope: vesicular sound and crackles, per zone: bases, mid-zones,
    apices). External plays from the patient's mouth in 3D and fades with
    distance; chest sounds only play when a stethoscope is placed on a zone.
  - Presets: normal_external, apo_external, normal (chest), apo_chest_mid,
    apo_chest_bases. Project lead's feedback on v2: chest sounds "bang on".
- **Other sounds (cough etc.):** Freesound.org filtered to CC0; log each in
  THIRD_PARTY_LICENSES.md.

## Equipment roadmap (agreed 2026-11-18)
- First piece of equipment: **stethoscope**, which unlocks the chest
  (auscultation) sounds per zone.
- Later: **corpuls3** monitor/defibrillator, **Braun ThermoScan** tympanic
  thermometer, capillary blood glucose meter.
- Wait for the project lead's reference photos before modelling any of them.
- Branding: real brand names, logos and distinctive designs are trademarks.
  For a commercial release, either get permission or model generic
  look-alikes without logos (decide before release).

## External breathing loudness (agreed 2026-11-18)
- Louder close to the patient, barely audible from across the room:
  inverse-square fall-off from the mouth, tuned per character in the
  scenario file (volume_db, unit_size_m, max_distance_m).
- One clip per breath, triggered with the chest animation so sound and
  movement stay in sync.
