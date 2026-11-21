# Free release: what still has to be done (agreed 21 Nov 2026)

The baseline app will be free (see `project-overview.md`). Being free removes payments,
VAT, refunds, licence keys and paid-level support expectations. These still need doing
before a first public release. None of it changes how the app is built.

## Must do before a public release
- [ ] **Distribution route.** Choose: a free listing on Meta's store (developer account,
      store review, store listing text and images) or sideloading for people we send it to.
      Check Meta's current requirements when we get there; they change.
- [ ] **Privacy policy.** Short and simple: the app works offline, collects no personal
      data, sends nothing anywhere; instructor logs stay on the instructor's own laptop.
      Host on havoceducation.co.uk.
- [ ] **Age rating.** Needed for a store listing (questionnaire). Content includes
      unwell patients and partial undress for clinical exposure.
- [ ] **Disclaimer, in the app and on the listing.** Educational tool only; not for
      patient care; not a substitute for clinical training, guidelines or supervision.
- [ ] **Licence notices shipped with the app.** Godot (MIT), OpenXR plugin/loader
      (MIT/Apache-2.0), Kokoro (Apache-2.0); credits screen or a notices file. Build-only
      tools (MPFB, espeak-ng, WORLD) don't ship, so nothing extra for those.
- [ ] **Support route.** Where people report bugs and ask questions (hello@havoceducation.co.uk
      is receive-only at the moment), and how much time Tom is willing to give it.

## Still applies, free or not
- **IP stays Tom's.** Free is not giving it away. Written terms before any trust,
  university or NHS QI involvement; check any submission form's IP terms first.
- **No real patient data.** Scenarios are fictionalised; strip identifiers.
- **JRCALC:** reference and paraphrase only; no reproduced doses or text without permission.
- **Claims stay educational.** No claims of clinical accuracy or outcomes beyond what's tested.
- **"Havoc Education" name** is unregistered: check UK trademark availability.
- **Repo is public:** make it private once GitHub two-factor access is recovered
  (otherwise the source is free too).

## Later
- Instructor side: free as well, or the part institutions pay for (to discuss).
