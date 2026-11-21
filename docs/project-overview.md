# Paramedic VR Sim – project overview

Last updated: 21 Nov 2026. Owner: Tom. Brand: **Havoc Education** (sub-brand alongside Havoc Aviation). Living summary so nothing is lost between chats.

## Where things live
- **Code:** GitHub `Havoc181/paramedic-vr-sim`; `main` = v0.04 milestone (20 Nov 2026), work continues on branch `v0.02-comfort-room` (now v0.05-dev14). PC copy: `C:\ClaudeDevP1\paramedic-vr-sim\paramedic-vr-sim`. Detailed decisions and plans: `docs/backlog.md`; character rebuild plan: `docs/character-pipeline.md` (copy here as `claude/character-pipeline.md`); headset test list: `docs/test-checklist.md`; results: `docs/test-results/`; clinical signs: `docs/clinical-signs.md` (copy in this project as `claude/clinical-signs.md`).
- **Note:** the simulator repo is currently **public**; make it private once GitHub two-factor access is recovered.
- **Website:** https://havoceducation.co.uk (GitHub Pages from `Havoc181/havoc-education-site`, Cloudflare DNS). Done 20 Nov: HTTPS, havoceducation.com redirects (301) to .co.uk, Google Search Console verified + sitemap, DMARC (p=none on .co.uk; .com locked: SPF -all, DMARC reject). Layout reworked for clinical education (demo CTA, "how a session works"). Contact: hello@havoceducation.co.uk (Cloudflare Email Routing; receive only).
- **Pitch material:** `C:\ClaudeDevP1\SourceAssets\pitch\v0.04\` and `...\pitch\for-amy\` (website PDF, screenshot pack).
- **Character source:** `C:\ClaudeDevP1\SourceAssets\make_humans.py` (Blender + MPFB 2, `default_no_toes` rig). Builds Joan, Ken and Maureen; exposure layers (top lifted / off with bra; trousers rolled to mid-calf + shoes off). To be replaced by the character rebuild.
- **Voice tools:** rebuilt 21 Nov in the cloud workspace from files downloaded through the PC's built-in browser (originals in Tom's Downloads). Adding a line = edit the scenario, rerun `tools/voice/build_voices.py`.
- **Docs (claude.ai):** Scenario 01 clinical source (https://claude.ai/artifact/FStiWuGnoLjKktmFzqGEsx); Project brief (https://claude.ai/artifact/DkNJsFgvXhK8QG4GFZ83su); Summary for Alex (https://claude.ai/artifact/4CE5AspPsC2bVTjMctEyXW).

## Decision: production app (20 Nov)
What exists now is the **production app** (Quest app + instructor laptop app, one Godot project). Development will later be split across separate applications (e.g. production headset app, a development/sandbox build for signs and characters, the instructor app, the character/asset pipeline). Choose the right moment: a natural break such as the v0.05 milestone, before others author scenarios, or before a first external pilot.

## Where we are: v0.05-dev14 (21 Nov 2026)
- v0.04 milestone headset-tested: standalone Quest 3, offline, 72 fps; scenario 01 APO (Joan, Ken); objective debrief; instructor link over Wi-Fi/hotspot.
- dev1–dev8: voices in the app; menu paging; teeth and tongue; exposure; clinical signs system (19 signs, instructor sliders, demo mode); hands-on pulse and capillary refill; scenario 02 draft.
- dev9–dev14 (21 Nov): Maureen (81, darker skin) built and fully voiced; scenario 02 clinical set-up approved by Tom; main menu (dispatch-only call list); exposure replies and sit-forward requests (voiced, two versions each); look in the mouth (tongue); demo mode panel (pick a sign, mild/full); tripod level per patient (upright/mild/full); legs exposure; hands planted on thighs; prop cards and wall text fixed.
- Headset-tested OK: dev11 (menu, replies, Maureen, signs, demo). dev13/dev14 not yet.

## Immediate next goals
1. Headset test of dev13/dev14 (demo panel, mouth, tripod levels, voices).
2. Character rebuild: underwear base body, clothes as layers with shader body masks, weight transfer, automatic clipping check (Tom gathering exposure information).
3. Stethoscope and a shared non-verbal sound library (coughs, wheeze, breath sounds).
4. Tom's clinical review of draft sign strengths, reply lines and tongue findings.
5. Debrief editions (minimal / supportive / objective) built on the same log; obs kit; real props for scenario 02.
6. IP groundwork: trust IP policy; written agreement before any NHS QI route. EEAST innovation (Amy Nicholls) contacted 20 Nov.

## People and conversations
- **Julia Williams** (thesis supervisor, College of Paramedics): possible endorsement route.
- **John Perry** (area manager): linking Tom with two people running operational VR training; suggested NHS QI.
- **Jay** (local auditor): advised establishing IP now.
- **Callum** (EEAST): gets VR nausea (desktop accessibility idea).
- **Amy Nicholls** (EEAST innovation): asked if self-developed, similar products, costs.
- **Alex:** sent the project summary.

## Long-term goals
Hands-on assessment with consent; full equipment; more scenarios (distractions, interpreters, deterioration, whole job); paediatrics as its own track; character library selectable by instructors, later random patients within scenario limits (pool of pre-built bodies on the underwear base); tutorial and difficulty levels; course profiles; fuller instructor app; evaluation pilots; CPD acknowledgement; instructor live voice through the patient.
- **Desktop accessibility version** (after VR is functional): same scenarios with mouse and keyboard.

## Business model (decision 21 Nov 2026)
**The baseline app will be free.** Selling and supporting a paid app, or organising a team to do it, isn't realistic for Tom at the moment. The instructor side is to be discussed later.
- Superseded: the 19 Nov plan (low-price personal app on the Meta store, paid instructor tier, professional/university licences). Details remain in `docs/backlog.md` if things change.
- Free still needs: see the release checklist `claude/free-release.md` (docs/free-release.md): distribution route, privacy policy, age rating, disclaimer, licence notices, support route.
- Free doesn't change: IP stays Tom's (written terms before any trust or university involvement), licence notices (Godot MIT etc.), educational-only claims and a disclaimer, no patient data, JRCALC reproduction limits.

## Licence and compatibility check (19 Nov 2026; not legal advice)
| Component | Licence | Commercial use |
| --- | --- | --- |
| Godot engine | MIT | Yes; keep the notice |
| OpenXR Vendors plugin / loader | MIT / Apache-2.0 | Yes |
| MakeHuman system assets | CC0 | Yes |
| MPFB 2 | GPL-3.0 | Build tool only, not shipped |
| Kokoro-82M / kokoro-onnx | Apache-2.0 / MIT | Yes |
| WORLD vocoder | Modified BSD | Yes (build tool) |
| espeak-ng | GPL-3.0 | Build tool only; don't ship |
| Breathing sounds, phone ring | Our own synthesis | Ours |
| Scenarios, debrief text, code | Ours | Ours |
| NICE guidance | NICE UK Open Content Licence | UK reuse free; self-assessment form |
| JRCALC | Copyright AACE / Class Professional | Reference/paraphrase fine; reproduction (doses etc.) needs permission |
| Equipment designs | Generic, no logos | Avoid trade dress |
| "Havoc Education" name | Unregistered | Check UK trademark availability |

Training tool, not used in patient care: keep claims educational. Everything offline; logs stay on the laptop.
