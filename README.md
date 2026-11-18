# Paramedic VR Sim

Offline VR clinical-presentation simulator for Meta Quest 3, built in Godot 4 (GDScript).

## Current version: V0.02 – comfortable, better-looking living room

- Furnished UK living room (procedural materials, no bought assets), sunlight through the window
- Comfort: stick movement with tunnel vignette, snap or smooth turning, teleport (right stick forward), fade on teleport
- In-VR menu (left controller menu button, or left-wrist button with hand tracking): movement, turning, vignette, seated mode, Quit
- 90 Hz and foveated rendering on Quest 3

Headless check (no headset needed): `godot --headless -s res://tests/smoke_test.gd`

## Running it over Link
1. Open Godot, Import, select this folder's `project.godot`.
2. Connect the Quest via Link cable, start Quest Link, and make sure the Meta Quest Link app on the PC is the active OpenXR runtime (Settings → General).
3. Press F5. Put the headset on.

Controls: left stick to move, right stick to snap-turn, right trigger to use what you're pointing at.

## Layout
- `scenes/` – Godot scenes
- `scripts/` – GDScript
- Large assets (Blender, audio, textures) are tracked with Git LFS (see `.gitattributes`).
