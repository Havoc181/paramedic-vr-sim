"""Offline British TTS: espeak-ng (phonemes) + Kokoro-82M ONNX (voice). Apache-2.0 model."""
import json, subprocess, sys, wave, numpy as np, onnxruntime as rt
import os
HERE = os.environ.get("VOICE_TOOLS", os.path.expanduser("~/tts"))
VOCAB = json.load(open(f"{HERE}/kokoro-onnx/src/kokoro_onnx/config.json"))["vocab"]
VOICES = np.load(f"{HERE}/voices-v1.0.bin")
sess = rt.InferenceSession(f"{HERE}/kokoro-v1.0.onnx", providers=["CPUExecutionProvider"])
names = [i.name for i in sess.get_inputs()]
def phon(text, lang="en-gb"):
    out = subprocess.run([f"{HERE}/espeak/bin/espeak-ng", "-q", "--ipa", "-v", lang, text],
        capture_output=True, text=True, env={"ESPEAK_DATA_PATH": f"{HERE}/espeak/share/espeak-ng-data"}).stdout
    return " ".join(l.strip() for l in out.splitlines() if l.strip())
def synth(text, voice, speed=1.0, lang="en-gb"):
    p = phon(text, lang)
    toks = [VOCAB[c] for c in p if c in VOCAB][:510]
    style = VOICES[voice][len(toks) - 1]
    feeds = {names[0]: np.array([[0, *toks, 0]], dtype=np.int64), "style": style.astype(np.float32),
             "speed": np.array([speed], dtype=np.float32)}
    return sess.run(None, feeds)[0].ravel(), p
def save(path, audio):
    a = np.clip(audio, -1, 1); w = wave.open(path, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000)
    w.writeframes((a * 32767).astype(np.int16).tobytes()); w.close()
if __name__ == "__main__":
    print([v for v in VOICES.files if v.startswith(("bf_", "bm_"))])
    a, p = synth(sys.argv[2], sys.argv[1], float(sys.argv[3]) if len(sys.argv) > 3 else 1.0)
    print(p); save(sys.argv[4] if len(sys.argv) > 4 else "/tmp/out.wav", a)
