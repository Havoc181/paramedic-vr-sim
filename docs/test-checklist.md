# Test checklist — v0.05-dev14 (voices) + dev13

## Voices (new in dev14)
- [ ] Maureen speaks all her answers (voice bf_emma, more breathless than Joan); judge whether she sounds right for 81
- [ ] Both patients speak their exposure replies; ask the same thing twice and you get a different version
- [ ] Joan and Maureen ask to sit forward out loud when left sat back
- [ ] Maureen's dog lines and "Leave it... it'll be... my neighbour" (instructor events) are voiced

Your dev11 notes are saved in `docs/test-results/2026-11-21_v0.05-dev11.md`.

## Looking in the mouth (new)
- [ ] Look, listen, feel: "Ask her to open her mouth (look at her tongue)"; she opens wide for about 5 s
- [ ] "Look at tongue" then appears. Maureen: dusky blue-grey tongue (central cyanosis). Joan: pink (draft wording, please review both)

## Prop cards
- [ ] Only one card open at a time (opening another closes the last), so they no longer overlap
- [ ] Cards wrap and grow upwards from just above the object; all text readable leaning in
- [ ] Wall instructions all visible on the wall

## Demo mode (new panel)
- [ ] Pause menu > "Demo mode: show clinical signs" opens a panel to the right of where you're looking; you can still move
- [ ] Pick any sign; Mild / Full; the selected sign is highlighted; caption above the patient
- [ ] Central cyanosis (tongue) opens her mouth so you can see it
- [ ] Tripod: Upright / Mild / Full: she moves smoothly, hands stay on her thighs at each level
- [ ] "Back to scenario signs" returns her to the scenario's own signs; Close

## Tripod level in scenarios
- [ ] Both scenarios are still full tripod. Tell me if either should be Mild (set per patient as `tripod_level` in the scenario, 0 to 1)

## Known, left for the character rebuild
- Rolled trousers' cuff looks rough close up
- Sat-back hands hover slightly above the seat
