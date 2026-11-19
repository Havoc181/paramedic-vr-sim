import numpy as np, subprocess, sys
sys.path.insert(0, __import__("os").path.dirname(__file__))
from say import synth, save
SR = 24000
def breath(path):
    out = subprocess.run(["ffmpeg","-v","quiet","-i",path,"-ac","1","-ar","24000","-f","f32le","-"],capture_output=True).stdout
    return np.frombuffer(out, dtype=np.float32) * 0.6
B = [breath(f"/home/claude/paramedic-vr-sim/assets/audio/generated/joan_breath_ext_{i}.ogg") for i in (1,2,3)]
def sil(s): return np.zeros(int(SR*s), np.float32)
def line(voice, parts, speed, lang="en-gb", breaths=False):
    seq = []
    for i, t in enumerate(parts):
        a, _ = synth(t, voice, speed, lang); seq += [a, sil(0.12)]
        if breaths and i < len(parts) - 1: seq += [B[i % 3], sil(0.05)]
        elif i < len(parts) - 1: seq += [sil(0.25)]
    return np.concatenate(seq)
def age(src, dst, factor):
    # lower pitch slightly (older voice) keeping duration
    subprocess.run(["ffmpeg","-v","quiet","-y","-i",src,"-af",f"asetrate=24000*{factor},aresample=24000,atempo={1/factor:.4f}","-c:a","libvorbis","-q:a","5",dst])
joan = ["I can't get my breath.", "It woke me up", "in the night.", "I had to sit up."]
ken = ["She's been like this since about three.", "She wouldn't let me ring you.", "She's got heart failure, you know."]
for v in ["bf_emma","bf_isabella","bf_alice","bf_lily"]:
    save("/tmp/vs/t.wav", line(v, joan, 0.9, breaths=True)); age("/tmp/vs/t.wav", f"/tmp/vs/joan_{v}.ogg", 0.95)
for v in ["bm_george","bm_lewis","bm_daniel","bm_fable"]:
    save("/tmp/vs/t.wav", line(v, ken, 0.92)); age("/tmp/vs/t.wav", f"/tmp/vs/ken_{v}.ogg", 0.94)
save("/tmp/vs/t.wav", line("pf_dora", ["Não consigo respirar.", "Começou durante a noite."], 0.9, "pt-br", True)); age("/tmp/vs/t.wav","/tmp/vs/interpreter_test_portuguese_pf_dora.ogg",0.96)
save("/tmp/vs/t.wav", line("hf_alpha", ["मुझे साँस नहीं आ रही है।", "रात में शुरू हुआ।"], 0.9, "hi", True)); age("/tmp/vs/t.wav","/tmp/vs/interpreter_test_hindi_hf_alpha.ogg",0.96)
