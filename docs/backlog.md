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

## Future thinking (logged 2026-11-18, nothing scheduled)

### Scenes and situations
- More environments reusing the patient system: bedroom, bathroom floor
  (fall), care home, street, inside the ambulance. Night-time lighting with
  a torch; clutter, trip hazards, pets; scene safety cues.
- **Mixed reality:** Quest 3 passthrough could put the patient in the
  learner's real room. Very cheap "environment", strong sense of presence.
- Paperwork in the scene: medication lists, care plans, ReSPECT/DNACPR
  forms on the fridge, as clues and as capacity/end-of-life teaching.

### People and communication
- Patient responds to the learner's manner (reassurance lowers anxiety).
- Interruptions and human factors: Ken talking over, phone ringing,
  time pressure.
- End-of-scenario handover practice (e.g. ATMIST/SBAR), pre-alert call.
- Voice input (offline speech recognition) instead of menus: deferred with
  the other AI ideas.
- Later scope: paediatrics, maternity, mental health, frailty, learning
  disability, safeguarding, capacity.

### Learning and teaching
- **Instructor/facilitator mode:** a tablet or PC view to watch the learner
  and change things live (observations, deterioration, Ken's behaviour).
  Likely the strongest feature for universities and trusts.
- **Two-person crew:** two headsets in one scene, practising teamwork.
- Session replay for the debrief (where the learner went, what they
  checked and when). Quest 3 has no eye tracking, so head direction only.
- Desktop (non-VR) mode for classrooms, accessibility and people who get
  motion sick.
- Later: treatment and its effects, drug calculations, conveyance and
  referral decisions, PPE/infection control, moving the patient.

### Safety and comfort in the real room
- Play-space guidance (enough space to kneel safely), reminders to check
  the boundary, suggested session length, simulator-sickness check.

### Platforms and content
- Quest 3 first; later Quest 3S, other OpenXR headsets, PC VR.
- Guideline tracking: note which JRCALC/NICE version each scenario uses,
  review when they change. JRCALC is UK-specific; other countries would
  need their own guideline sets.

### Evidence and business
- Evaluation: content/face validity with clinicians, usability (e.g. SUS),
  simulator sickness questionnaire; publishable if ethics approval obtained.
- Endorsement or CPD accreditation (e.g. College of Paramedics).
- Pricing and licensing model for individuals vs. institutions.

## Decisions on future thinking (2026-11-18)
- **Agreed:** instructor/facilitator mode, mixed reality, paperwork in the
  scene.
- **The whole job, start to finish** (long-term shape of the product):
  mobilising, arrival, attending and treating, extrication (to a degree),
  transport, handover. Handover is one stage of this, not a stand-alone.
- **Annoying problems to sort** (project lead's idea): small real-world
  obstacles such as a loud TV to turn down, poor lighting, a dog in the way,
  furniture to move. First candidate: the TV already in the living room is
  on and loud until the learner turns it down.
- **CPD:** a simple acknowledgement of the user and what they did in the
  session is enough for a qualified audience (no formal accreditation
  needed at first).
- **College of Paramedics endorsement:** possible route via the project
  lead's thesis supervisor (Professor Julia Williams, College of
  Paramedics). Approach once there is something solid to show.
- **Audience range:** from student paramedics who have never used a VR
  headset to experienced paramedics comfortable in VR.
  - A **tutorial**: wearing and using the headset, then the sim's own
    controls (moving, pointing, menus, assessing), in a calm practice room.
  - **Difficulty levels** like a game, easy to hard. Easy: clearer cues,
    fewer distractions, more prompts. Hard: subtler signs, interruptions,
    annoying problems, a less helpful bystander.
  - No claim that it is "real": present it as practice and learning.

## Headset test results, 2026-11-18 (v0.03-dev2)
- Grey screen on Quest: caused by foveated rendering and/or the 90 Hz switch
  (fixed by removing both). Re-test each separately before re-adding.
- Breathing sound: good; a bit loud at full volume. Re-balance once other
  sounds (voices, room) exist. Fade with distance works.
- Turning: smooth preferred; snap felt clunky. Smooth is now the default.
- Teleport: works but not intuitive to the project lead. Keep as an option;
  explain in the tutorial; consider simpler alternatives later.
- Vignette: not noticed (not tested deliberately) - check next time.
- Seated mode: right height when seated; standing in seated mode also OK.
  Crouch/kneel added on right thumbstick click (v0.03-dev3).
- Right controller: fine. Quit from menu: fine.
- Medicines box: could be read from across the room. Now only readable
  within ~0.9 m ("get closer to read"), and Ken hands it over when asked
  about medications. Box still on the side table too.
- Fixed in dev3: panel smaller and further aside; subtitles draw on top of
  panels (black rectangle); bigger medicines text; wrist button and hand dots
  only for real hand tracking (not hands faked from held controllers).

## Support routes (raised 2026-11-18)
- Research paramedic suggested logging it as a **QI programme with EEAST**
  for financial and practical support.
- Testing best via the clinical/education side: local university contacts,
  and the local clinical manager for more immediate support.
- **Before formally logging or accepting funding:** agree IP ownership in
  writing. NHS trusts usually have IP policies that can claim a share of
  innovations developed with trust time, funding or support. Ask the trust's
  R&D/innovation lead how their policy applies.
- Prepare first: a short project brief (problem, what exists, demo, plan,
  asks) and a demo-ready build with one complete scenario and debrief.

## Characters and posing (2026-11-19)

- Joan and Ken are MakeHuman (MPFB 2, CC0 assets), built by `C:\ClaudeDevP1\SourceAssets\make_humans.py` run in Blender. Rig: MPFB `default_no_toes` (137 bones; upper arm and forearm each split in two so twist spreads along the limb).
- Joan wears the elegant-suit blouse with the casual-suit jeans (skirt clipped badly when seated). Clothes pushed 8 mm off the skin.
- Posing is done in code (`scripts/patient/rig_driver.gd`): limb directions, trunk lean, shrug, hinge-aware two-joint reach for hands on knees, palm-down twist spread across forearm bones and wrist.
- **Next step (agreed in principle):** author postures as short animation clips in Blender (script-generated, editable by eye), exported in the .glb and played in Godot with breathing layered on top. Needed once there are more postures (lying, pacing Ken, etc.).
- Known: Joan's fringe falls over one eye (pack has few hairstyles); cushions are plain blocks.

## Exposure and skin layers (agreed for later integration, 2026-11-19)

Idea (Tom): clothes layer drawn normally; the skin underneath is only drawn where a garment is opened or moved. Agreed approach:

- **Body split into skin regions** in the Blender build (front chest, back, each upper arm, forearm, lower leg, foot, etc.). Each garment *state* lists the regions it covers; Godot shows only uncovered regions. Region edges sit just inside garment edges so no gaps show. Separate mesh pieces (not a pixel-discard shader, which is slow on Quest tile GPUs).
- **Benefits:** no skin/clothes clipping; less overdraw and fewer triangles on Quest; skin regions can carry findings (sweating, mottling, cyanosis, accessory muscle use, ankle oedema) independently of clothing.
- **Realistic garment states** (swapped meshes made in Blender, short fade + fabric sound, no cloth simulation):
  - Blouse/shirt: on; unbuttoned/opened at front (chest, later ECG); lifted at back (posterior chest); sleeve rolled up (BP, cannula, cap refill).
  - Trousers: on; legs rolled up to shin; shoes and socks off (ankle oedema; relevant to Joan).
  - Later (trauma): cut with shears.
  - All reversible; "cover up again" is recorded.
- **Links:** consent before exposing/touching (asked first, stored); hands-on assessment; debrief can comment on dignity (expose only what's needed, re-cover).
- **First slice when scheduled:** skin regions for Joan; blouse on/opened-front; jeans normal/rolled-up with shoes and socks off; panel options "Expose chest", "Check ankles", "Cover up again" with consent.

## Voices and interpreters (2026-11-19)

- **Working now (build-time, offline):** Kokoro-82M (Apache-2.0) via ONNX + espeak-ng (built from source, tool only). `tools/voice/setup.sh` rebuilds it; `say.py` makes a line; `sampler.py` made the auditions. British voices: bf_alice, bf_emma, bf_isabella, bf_lily, bm_daniel, bm_fable, bm_george, bm_lewis. Joan: slower, pitch down ~5%, breath clips between phrases. Awaiting Tom's voice picks.
- **Breathless speech model (`tools/voice/breathless.py`):** speech in breath groups of varying length set by a severity value; breaks preferred at sentence/comma boundaries, mid-phrase breaks allowed with severity but not straight after linking words, no stranded last word; in-breaths lengthen and get louder after longer groups. In-breath timbre comes from each speaker's own vocal-tract resonances (LPC of a neutral vowel in their voice). Sources: Werner et al. 2021 (Interspeech) and 2023 (JSLHR) on inhalation acoustics (close to schwa with a more open jaw; louder/brighter with faster inhalation); Trouvain & Truong 2015 (speech after treadmill running: longer pauses and breaths, louder in-breaths, higher F0); Wang et al. 2010 / Winkworth et al. 1994 (in-breaths mostly at syntactic boundaries). The earlier `gasp.py` "voiced catch" caused a buzz on some gasps; it is not used by breathless.py.
- **Planned pipeline:** per-character `voice` block in scenario JSON (voice, speed, age pitch, language, breathless); build tool generates only new/changed lines (hash of text + settings) into `assets/audio/generated/voice/<scenario>/`, with a manifest of durations for subtitle timing; characters speak from the head via AudioStreamPlayer3D; subtitles stay.
- **Interpreter scenarios (later):** patient speaks own language, subtitle shows "(speaks Portuguese)"; options: telephone interpreter (works, realistic time cost, relays), family member (quicker, debrief discusses problems with family interpreting), or struggle on. Kokoro covers English, Spanish, French, Italian, Brazilian Portuguese, Hindi, Mandarin, Japanese. Not Polish, Romanian, Urdu, Punjabi, Bengali, Arabic; offline voices for those are mostly non-commercial licences, so native-speaker recordings later.
- **Tom's verdict (2026-11-19):** breath-group version (v3) "really good"; park until we integrate voices with the character models. Voice picks for Joan and Ken still to choose from the v3 auditions (bf_isabella / bf_emma / bf_alice / bf_lily; bm_george / bm_lewis / bm_daniel / bm_fable).
- **Integration notes for when we do it:**
  - Scenario JSON per character: `voice` (id, speed, pitch factor, language), `breathless` (severity 0..1, wet 0..1), so severity can differ between characters and scenario versions.
  - Build tool also writes, per line, the times of each in-breath; the game uses them to (a) pause the idle breathing loop while she speaks and (b) trigger the chest/shoulder breath animation exactly on each in-breath, so what you see and hear match.
  - Simple jaw movement driven by speech loudness (mouth opens on loud segments, closes in gaps) as a cheap stand-in for lip sync.
  - Voice and breath audio come from one AudioStreamPlayer3D at the head, same distance fall-off as the breathing; subtitles stay.
  - Optional later upgrade: Tom's own recorded breaths, or a higher-quality commercial TTS at build time; both drop into the same pipeline.

## Organisational interest and IP (update 2026-11-19)

- **Jay (local auditor, policy compliance):** keen for Tom to establish IP ownership now.
- **John Perry (Area Manager):** impressed, wants it to go further; linking Tom with two people working on operational training through VR; suggested NHS QI routes to get it off the ground.
- **Tom's position:** learn from them, but check what any route means for IP before agreeing to anything.
- **To prepare (not legal advice; get an IP solicitor's view before signing anything):**
  - Evidence of independent creation: the GitHub history (dates, own equipment, own time), the Claude conversation history, design docs. Keep working on personal kit and outside paid hours.
  - Read the employment contract and the trust's IP policy (NHS trusts usually claim IP made in the course of employment or with trust time/resources). UK law: employer owns copyright in works made by an employee "in the course of employment" (CDPA 1988 s11(2)) and inventions made in normal duties (Patents Act 1977 s39). Building a training simulator isn't part of a paramedic's normal duties, which helps, but the contract/policy wording matters.
  - Before any QI project uses trust time, data or equipment: get written agreement that pre-existing IP stays with Tom (or agree terms, e.g. trust gets a licence, Tom keeps ownership).
  - Clinical content: JRCALC/NICE are referenced, not copied; anything a trust or College of Paramedics contributes should come with an agreed licence.
- **Business infrastructure wanted:** company set-up, name/trademark check, domain and simple landing page, contact email, pitch deck, demo video, in-headset screenshots.
- **Reminder:** take real in-headset screenshots and a short video once the dev10 build works (also in the test checklist).

## Decisions and notes (2026-11-19, afternoon)

- **Scenario 02: COPD exacerbation** (agreed). Reuses the breathing, breathless-speech and tripod systems; contrasts with APO (wheeze/prolonged expiration vs crackles, pursed lips, history, inhalers/home oxygen, management differences). Debrief should help tell the two apart.
- **Brand:** the project sits under Tom's existing **Havoc** brand (umbrella over Havoc Aviation); Havoc can also be the company name.
- **Showing it works, two settings:**
  - University: lecturer watches what the student does (needs a **supervisor view**: mirror of the headset view on a laptop/screen, later an instructor panel), then talks it through.
  - Work/CPD: someone simply experiences the program; screenshots and a short video are enough for now.
- **Project brief (Claude Doc):** https://claude.ai/artifact/DkNJsFgvXhK8QG4GFZ83su (screenshots and contact details to add).
- **Questions for the VR training contacts:** Tom will ask for a prompt list when the meeting is arranged.

## Debrief v1 (2026-11-19)

- Built from Tom's notes: first impression via the assessment triangle (appearance: alert, complexion, clammy; work of breathing: tripod, noise, rate, speech; circulation to skin). Biggest miss to avoid: work of breathing. Key: WOB and position, meds (missed furosemide), PMHx; nice to spot: oedema findings, pertinent negatives. Differentials: MI, PE, LRTI, ECOPD. Next steps: ABCDE and treat life threats first; close to hospital O2 for low SpO2, GTN, pre-alert, blue lights; longer runs per JRCALC plus cannulate and IV furosemide (no doses in app).
- Flow: panel **Finish** tab -> "say out loud what you think" -> pick impression -> pick urgency -> debrief pages (found vs available, why each matters, comparison table of causes, what next, obs for reference, counts, references) -> Run again / Close.
- Tone: **objective** at this early stage (`debrief.tone = "objective"`). Later, the **easy** difficulty uses a supportive tone (`closing_supportive` text kept ready); the feedback style for each difficulty must be stated clearly when choosing it. First impression framework confirmed: Patient Assessment Triangle (PAT).
- Lung sounds and observations will complete it (marked "coming later" in the debrief, obs shown for reference).
- **Reporting, not judging (Tom, 2026-11-19):** what's expected in assessment is often grey, so the debrief reports what was available and what was checked ("[Checked]" / "[Available, not checked]"), with why each finding matters, and avoids "you should have". Expectations, required items and pass criteria belong in a future **course profile** (e.g. one per university), layered on top of the same scenario.
- Tom (evening): wording "still a bit bossy" but leave as is for now; useful as a discussion point in testing.

## Equipment reference photos (shot list agreed 2026-11-19)

Generic designs only in the app (no logos, brand names or exact copies); photos are for proportions, layout, colours and how things are used.
- **Priority:** 1 monitor/defib (corpuls3: screen layouts, buttons, ports, cable set) - needs Tom's photos; 2 stethoscope - online fine, Tom's photo for the type crews carry; 3 SpO2 probe, BP cuff, ECG electrodes and leads - Tom's photos (cables, connectors, lengths); 4 PEFR meter, tympanic thermometer, glucometer - online fine, Tom's photos if easy.
- **For each item:** front, back, both sides, top, roughly straight on; plain background; something for scale (tape measure or A4 sheet); close-ups of controls and connectors.
- **Monitor screens:** the main obs screen, 12-lead screen, NIBP/SpO2 in progress, alarms, using a colleague or yourself or the demo/simulator mode - never real patient data.
- **Cables:** laid flat beside a tape measure, plus close-ups of each connector end.
- **In use (on a volunteer, no faces needed):** probe on finger, cuff on arm, electrode positions, thermometer in the ear, finger-prick, PEFR blow.
- **Timings and behaviour from Tom:** e.g. how long NIBP, SpO2, tympanic temp and CBG take to give a reading, what the monitor shows and sounds like while doing it.
- **Avoid in photos:** patient details, faces, vehicle or trust identifiers.

## Supervisor / instructor view (agreed direction 2026-11-19)

Tom: a laptop view with some in-scenario customisability, plus casting at least.
- **Phase 1, casting (no development):** mirror the headset on a laptop over USB with scrcpy (free, open source, works offline with developer mode); or Meta's own casting to phone/browser/TV (needs Wi-Fi with internet and the Meta app). Fine for demos now.
- **Phase 2, instructor app on a laptop (same Godot project, desktop build):** connects to the headset over local Wi-Fi or the laptop's own hotspot, no internet. Sends small events, not video, so it stays smooth and the headset barely notices.
  - Live log of what the student asks, checks and says, time-stamped.
  - Before the run: choose scenario, difficulty, patient variant (severity, age, skin tone), distractions on/off.
  - During: pause/resume, deteriorate or improve the patient, trigger events (Ken interrupts, loud TV, phone rings), show a hint, reveal observations, end the scenario.
  - After: debrief shown on both, instructor notes added, session log saved locally (no student data leaves the laptop).
- **Phase 3:** a free-moving 3D spectator camera on the laptop (rebuilt from the same events), several headsets in one session, course profiles applied by the instructor.

### Phase 2 built (v0.04-dev1)
- Headset: `scripts/session_link.gd` (UDP beacon on 47801 every second; TCP 47800, one instructor, JSON lines; sends log, learner pose 4 Hz, state; receives commands). Android export now has INTERNET + ACCESS_WIFI_STATE permissions (local network only).
- Laptop: `scenes/instructor.tscn` (run with F6 in the editor, or the "Instructor (Windows)" export, or `--instructor`): headset discovery + manual address, room map with learner position/facing/kneeling, colour-coded time-stamped log, pause/resume, patient better/worse slider, Ken interrupts, phone rings (generated UK ring), hint text, show observations, end scenario (learner asked for impression), notes, save log locally.
- Networking notes: works on any network where both devices can see each other: phone hotspot (most allow device-to-device; some Android hotspots isolate clients, then use the laptop's own hotspot or a travel router), laptop hotspot, home/office Wi-Fi. If discovery is blocked, type the address shown in the headset menu. Windows firewall must allow the app.
- Next for the instructor app: pre-run choices (scenario, difficulty, patient variant, distractions) once scenario 02 exists; debrief shown on the laptop; mirror via scrcpy button.

## Business decisions and contacts (late 2026-11-19)

- **Tiers:** standalone app on the Meta store first (personal, low price). Instructor link behind an extra paid tier, which also brings customisation. User agreement: personal licence = individual use, not institutional teaching; also enforce technically (institutional features unlock only with an institutional licence key; personal app has no instructor link).
- **EEAST:** Tom spoke with Callum again and emailed the EEAST innovation team asking for help integrating with EEAST, stating he wants to keep the IP.
- **Desktop accessibility version (after VR is functional):** same project, flat-screen camera and mouse/keyboard controls, reusing scenarios, characters, panel, debrief and instructor link. For people with VR sickness (Callum gets nausea in VR) or no headset; also demos, revision, lecture display.
- Full overview, business model and licence check: claude.ai Project "Paramedic VR Sim", `claude/project-overview.md`.
- **Brand (Tom, 2026-11-19):** sub-brand **Havoc Education**, alongside Havoc Aviation under the Havoc umbrella. Use this name on the store listing, licences, brief and company materials; trademark check to cover "Havoc Education".

## Headset test 20 Nov 2026 (v0.04-dev1) - results in docs/test-results/2026-11-20_v0.04-dev1.md

- Passed: start-up; characters (tripod pose, hands, sleeves, no skin through clothes, faces, breathing); crouch; medicines box readability; click-outside closes panel; debrief flow incl. Run again / Close; 72 fps throughout (2.7-6.0 ms, 160-400 draw calls); 90 Hz works.
- **Foveation: gave the grey screen (tested at 72 Hz; not tried at 90 Hz) - removed from the menu.** Revisit after a Godot/vendor-plugin update; 90 Hz on its own is fine.
- Vignette still not noticed (fine).
- Tom: Ken answering questions put to Joan felt "meh" -> fixed in dev2: panel shows "Talking to: <name>"; each person answers questions put to them (Joan short breathless answers; Ken fuller), falling back to whoever can answer.
- Tom: panel is big; long-term move more of the assessment into other inputs (speech, gestures, hands-on) rather than menus.
- Tom: Finish = impression only for now (no urgency: we aren't doing treatment yet) -> done in dev2.
- Tom: debrief is readable but a lot of pages and text -> to discuss (options: summary page first with drill-down; fewer "why it matters" lines; let the instructor/course profile choose depth).
- Instructor link: headset menu showed no link line and the PC found no headset -> dev2 shows link status/errors in the menu for diagnosis.
- Pitch screenshots taken (in-headset).

## Website (planned 20 Nov 2026, later today)
- Havoc Education site in the same branded style as Tom's Havoc Aviation site (flyhavoc.com, made with ChatGPT). One page: what it is, in-headset screenshots, who it's for, contact; plus a privacy policy page (the app collects nothing; instructor logs stay on the laptop). Needed for the Meta store listing and for EEAST / universities.
- Hosting: GitHub Pages (free), custom domain later. Draft for Tom's review before anything is public.

## Voices v1 in the app (20 Nov 2026, v0.05-dev1)
- Joan: Kokoro bf_lily, WORLD-vocoder ageing (old_woman, strength 0.9), breathless 0.6 (weakening + breathier through each phrase), in-breaths at the script's "..." marks, breath gain 0.45. Ken: bm_lewis, gentle ageing (no jitter/shimmer/tremor; Tom heard "voice breaking" and tone changes on long sounds).
- `tools/voice/build_voices.py scenarios/apo_01.json` builds every line (37 clips, ~1.1 MB) into assets/audio/generated/voice/apo_01/ with manifest (length, in-breath times, mouth envelope); only changed lines rebuild.
- In app: voice from the head (3D), subtitles timed to the clip, breathing sound pauses while speaking, chest lifts on in-breaths, jaw opens up to 6 degrees with loudness.
- Tom's view: "good effort, not natural"; expect flak in testing. **Get wider input** (what specifically sounds wrong, not just "unnatural") before more tuning. Upgrade route: paid TTS with genuinely older voices, or recorded voices. Script lines should stay short (as the scenario already does).
- Later: MakeHuman teeth/tongue and dark mouth interior (jaw opening shows pink inner lips).

## To fix: tripod hands drift with breathing (Tom, 20 Nov)
- In the tripod, the hands slide slightly sideways as the shoulders lift with each breath. The rest of the movement is right; the hands should stay planted on the knees/thighs.
- Cause: `rig_driver.apply_breath()` lifts the clavicles every breath, and the whole arm chain hangs off them, so the wrists move.
- Fix plan: after the clavicle lift each frame, re-run the two-joint arm IK to the stored wrist targets (cheap: two bones per arm), so the elbows absorb the movement and the hands stay fixed. Same for the sit-back hands on the seat.

## Next PC session: follow-up actions (saved 20 Nov, 21:57; updated 21 Nov)
Done 21 Nov: 1 (Maureen + legs built), 2 (checked; cuff hoop and mottling-on-dark-skin noted), 5 (hands planted).
Do these next time Claude has the PC (Tom not gaming; approve Blender when asked):
1. **Run `make_humans.py` in Blender** (SourceAssets). Builds Joan + Ken + **Maureen** (81, Black British, old_african_female skin, short grey hair, plain muted-purple long-sleeved top via `clothes_colour`, dark jogging bottoms, shoes04) and the **legs exposure** layers (skin_legs patch, trousers rolled above the knees, shoes off) for Joan and Maureen. Confirm the look of Maureen with Tom first if he has preferences.
2. **Check the build:** stage the new glbs, run `tests/sign_sheet.gd` for Joan and `WHO=maureen`, `tests/exposure_shot.gd`; fix any clipping (top lifted/off, legs rolled). Check darker-skin readings of pallor / cyanosis / clamminess on Maureen and adjust (relative to skin; tongue and inner lips most reliable).
3. **Tom commits** `joan.glb`, `ken.glb`, `maureen.glb` in GitHub Desktop (LFS; never from the cloud).
4. **Voices for Maureen:** voice tools (Kokoro, WORLD) are no longer in the cloud workspace and package installs are blocked on the account. Either Tom allows package installs in settings (new chat picks it up), or set the tools up on the PC. Then `build_voices.py scenarios/copd_02.json` and pick a different voice from Joan's.
5. **Tripod hands drift** with breathing (see above): re-solve arm IK after the clavicle lift.
6. **Clinical review by Tom:** draft sign strengths in apo_01 / copd_02 (`presentation.signs`), heart rates, capillary refill times; copd_02 history answers and debrief.
7. Real props for scenario 02 (sputum pot, tissues, inhalers, rescue pack, dog bed) to replace the labelled boxes.
8. Retake the instructor-app screenshot for the website when convenient (now has the signs sliders).

## Decision: production app and future split (Tom, 20 Nov)
- What exists now is the **production app** (Quest app + instructor laptop app from one Godot project).
- We'll later split development across separate applications (for example: production headset app, a development/sandbox build for trying signs and characters, the instructor app, and the character/asset pipeline). Not yet: choose the right opportunity, e.g. a natural break such as the v0.05 milestone, before scenario authoring by others, or before a first external pilot.

## Main menu, exposure replies, random patients (2026-11-21)
- **Main menu** (dev11): the headset opens on a call list showing dispatch text only. Scenarios
  are listed in `scenario_runner.gd` `SCENARIOS`; each scenario has a `menu` block (label, draft).
  Desktop runs/tests skip it unless `MENU=1`.
- **Exposure replies:** each patient has `reactions` in the scenario (lifted, off, on, legs_off,
  legs_on, sit_forward list). A tripod patient left sat back asks to sit forward after 12 s, then
  every 25 s; logged for the instructor and mentioned in the debrief (not as a fault).
- **Voices:** Maureen set to `bf_emma` (Joan is `bf_lily`). Lines to generate: Maureen's 20 answers
  plus 7 replies each for Joan and Maureen. `build_voices.py` now includes the replies. Blocked:
  the voice tools (espeak-ng, Kokoro model, WORLD) come from GitHub, which neither the cloud nor
  the PC workspace can reach. Fix: allow GitHub/package installs in network settings (new chat),
  or download the files into C:\ClaudeDevP1\tts and I build from there.
- **Scenario 02 clinical set-up:** reviewed and approved by Tom, 21 Nov.
- **Random patients (later, Tom's idea):** scenario sets limits (sex, age range, build, height,
  demographic where relevant); app picks a patient matching them; signs added on top. Realistic
  route on Quest: a **pool of pre-built bodies** (MakeHuman can't build at run time on the
  headset), all on the underwear base so clothing layers and signs fit any of them. Cost to
  plan for: each voice needs its own lines per scenario, so the pool has a few voices per
  sex/age band. Depends on the character pipeline (docs/character-pipeline.md) being in place.
