"""Generate every spoken line of a scenario as an audio file (offline).

  python3 tools/voice/build_voices.py scenarios/apo_01.json

Reads each character's "voice" block from the scenario, writes
assets/audio/generated/voice/<scenario>/<question>_<speaker>.ogg, sets each
answer's "audio" field, and writes a manifest with each clip's length, its
in-breath times (for the chest movement) and a mouth-opening envelope
(20 per second, for the jaw). Only lines whose text or settings changed are
rebuilt. Swapping in another voice engine later only changes this tool.
"""
import hashlib, json, os, subprocess, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from say import synth, save
from ageing import age, SR
from breathless import speaker_envelope, in_breath

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def sil(s):
    return np.zeros(int(SR * s), np.float32)


def trim(a):
    idx = np.where(np.abs(a) > 0.01)[0]
    return a[max(0, idx[0] - 240): idx[-1] + 480] if len(idx) else a


def render(text, v, rng, env_cache):
    """Returns audio and in-breath start times (s)."""
    voice = v["voice"]
    speed = float(v.get("speed", 0.9))
    preset = v.get("age")
    strength = float(v.get("age_strength", 0.9))
    if not v.get("breathless"):
        a = trim(synth(text, voice, speed)[0])
        return (age(a, preset, rng, strength) if preset else a), []
    if voice not in env_cache:
        env_cache[voice] = speaker_envelope(synth, voice)
    parts = [p.strip() for p in text.split("...") if p.strip()]
    out, breaths, t = [], [], 0.0
    for i, g in enumerate(parts):
        a = trim(synth(g, voice, speed)[0])
        a = age(a, preset, rng, strength, breathless=float(v.get("breathless", 0.6))) if preset else a
        out.append(a); t += len(a) / SR
        if i < len(parts) - 1:
            gap = sil(rng.uniform(0.05, 0.1)); out.append(gap); t += len(gap) / SR
            breaths.append(round(t, 2))
            b = in_breath(env_cache[voice], rng, rng.uniform(0.3, 0.45), 0.7, 0.0) * float(v.get("breath_gain", 0.45))
            out += [b, sil(0.05)]; t += len(b) / SR + 0.05
    return np.concatenate(out), breaths


def mouth_envelope(a):
    hop = SR // 20
    n = len(a) // hop
    e = np.array([np.sqrt(np.mean(a[i * hop:(i + 1) * hop] ** 2)) for i in range(n)])
    return [round(float(x), 2) for x in np.clip(e / (e.max() + 1e-9) * 1.2, 0, 1)]


def main(path):
    sc = json.load(open(path))
    sid = sc["id"]
    out_dir = f"assets/audio/generated/voice/{sid}"
    os.makedirs(os.path.join(ROOT, out_dir), exist_ok=True)
    man_path = os.path.join(ROOT, out_dir, "manifest.json")
    manifest = json.load(open(man_path)) if os.path.exists(man_path) else {}
    voices = {cid: c.get("voice") for cid, c in sc["characters"].items() if c.get("voice")}
    env_cache, built = {}, 0
    lines = []
    for q in sc.get("questions", []):
        for a in q.get("answers", []):
            lines.append((f"{q['id']}_{a['by']}", a))
    for key, l in sc.get("instructor_events", {}).items():
        if not isinstance(l, dict):
            continue
        for i, text in enumerate(l.get("lines", [])):
            lines.append((f"event_{key}_{i}", {"by": l.get("by", ""), "text": text}))
        if "after_line" in l:
            lines.append((f"event_{key}_after", l["after_line"]))
    for name, a in lines:
        v = voices.get(a.get("by", ""))
        if not v:
            continue
        rel = f"{out_dir}/{name}.ogg"
        h = hashlib.sha1((a["text"] + json.dumps(v, sort_keys=True) + "v1").encode()).hexdigest()[:12]
        if manifest.get(rel, {}).get("hash") != h or not os.path.exists(os.path.join(ROOT, rel)):
            rng = np.random.default_rng(int(h[:8], 16))
            audio, breaths = render(a["text"], v, rng, env_cache)
            audio = audio / (np.max(np.abs(audio)) + 1e-9) * 0.85
            save("/tmp/_line.wav", audio.astype(np.float32))
            subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-i", "/tmp/_line.wav", "-c:a", "libvorbis",
                            "-q:a", "4", os.path.join(ROOT, rel)], check=True)
            manifest[rel] = {"hash": h, "length": round(len(audio) / SR, 2), "breaths": breaths,
                             "mouth": mouth_envelope(audio), "text": a["text"]}
            built += 1
            print("built", rel)
        a["audio"] = "res://" + rel
    json.dump(manifest, open(man_path, "w"), indent=0)
    json.dump(sc, open(path, "w"), indent=1, ensure_ascii=False)
    print(f"{built} built, {len(lines)} lines")


if __name__ == "__main__":
    main(sys.argv[1])
