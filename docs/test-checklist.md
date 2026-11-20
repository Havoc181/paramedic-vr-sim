# Headset test checklist

Run on the Quest (standalone build). Note the version shown in the menu title
(this round: **v0.04-dev2**). Anything that fails: a photo or a few words.
Previous results: `docs/test-results/`.

## 1. Fixes from the 20 Nov test (5 min)
- [ ] Point at Joan: the panel says "Talking to: Joan" and Joan answers for herself (short, breathless answers)
- [ ] Point at Ken: "Talking to: Ken" and Ken answers
- [ ] Ask Joan about her medicines: she asks Ken to get the box, and you're handed it
- [ ] Finish tab: choose your impression only (no urgency question), then the debrief opens
- [ ] Menu: the foveation option has gone; the refresh rate option is still there

## 2. Instructor link (10 min) - retest
Headset and PC on the same network (home Wi-Fi, or both on your phone hotspot).
- [ ] Headset menu, bottom line: what does it say exactly? ("waiting on <address>", "not running", or an error in brackets) - a photo please
- [ ] On the PC: in Godot, open `scenes/instructor.tscn` and press F6. Allow it through the Windows firewall if asked
- [ ] PC: does the headset appear under "Headsets found"? If not, type the address from the headset menu and press Connect
- [ ] If connected: walk about (dot moves), kneel (says kneeling), ask a question and check something (both in the log)
- [ ] Try each control: Pause/Resume, Worse / Much worse, Better, Ken interrupts, Phone rings, Show observations, a typed hint, End scenario
- [ ] Save log and notes, then Open saved logs

## Always
- [ ] Both controllers track throughout; Quit app works
