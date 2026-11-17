# Paramedic VR Sim

Offline VR clinical-presentation simulator for Meta Quest 3, built in Godot 4 (GDScript).

## V0.01 – running it
1. Open Godot, Import, select this folder's `project.godot`.
2. Connect the Quest via Link cable, start Quest Link, and make sure the Meta Quest Link app on the PC is the active OpenXR runtime (Settings → General).
3. Press F5. Put the headset on.

Controls: left stick to move, right stick to snap-turn, right trigger to use what you're pointing at.

## Layout
- `scenes/` – Godot scenes
- `scripts/` – GDScript
- Large assets (Blender, audio, textures) are tracked with Git LFS (see `.gitattributes`).
