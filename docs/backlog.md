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
- **Git LFS storage:** GitHub's free LFS quota is limited; models and audio
  will grow. Check the current limits and plan (compress, or paid storage).
- **Version number in the app** (menu) so testers can say what they ran.
- **One-click build and install** to the headset.
- **Logging:** write a log file on the headset to help diagnose problems.
- **Test checklist** per version.

### Legal and commercial
- **Employment / university IP:** check employment contract and any
  university terms (thesis overlap) about side projects and who owns IP,
  before anything is sold.
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
