# Scenario 02 — COPD with haemoptysis and pleuritic pain (draft)

Source: a real case from the project lead's portfolio, fictionalised (name, age,
pet details, timings, observation values all changed). No doses in app.

## Teaching points
1. Severe distress in COPD and signs of tiring (tripod, accessory muscles,
   paradoxical abdominal movement, cyanosis).
2. Anchoring: the exacerbation explains most of the picture, but not the fresh
   haemoptysis or new pleuritic pain. Pneumonia and PE remain open.
Scope: assessment only. Treatment, response to treatment and refusal/capacity
are deliberately left for a separate, later piece of work (project lead, 20 Nov).

## Build plan (one focus per build)
- v1 (this file): assessment, history, scene clues, impression, debrief.
  Engine already loads it (21 questions, 12 look/listen/feel items).
- Engine needs before it's playable:
  - Scenario chooser at start (apo_01 / copd_02).
  - Props: sputum pot, tissues, inhalers, sealed rescue pack, dog bed/bowl/lead.
  - Paradoxical abdominal movement in the breathing animation.
  - Dusky lip tint: DONE (skin_signs shader, cyanosis 0.4 = mild).
  - Mild clamminess sheen: DONE (clammy_level 0.45).
  - Wince-and-hold-back cough.
  - Dog whine instructor event (replaces the bystander interrupt).
  - Distinct patient model and voice (not Joan).
- Later: observations, auscultation, treatment response (no doses until
  JRCALC permission).
