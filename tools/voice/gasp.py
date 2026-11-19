"""Short breathless in-breaths ("gasps") to put between bursts of speech.

Acoustic model of a mouth in-breath (rather than the low, filtered noise of the
v1 breathing loops, which sounded artificial close up):
- turbulent airflow noise shaped by the vocal tract: open-mouth resonances
  (formants) around 700, 1200 and 2600 Hz that drift as the jaw closes;
- a fast rise and slower fall, 0.3-0.6 s, each gasp slightly different;
- often a faint voiced catch at the end (glottis closing to speak again);
- optional wet rattle (coarse crackles) for fluid in the airways (APO).
No recordings are used.
"""
import numpy as np
from scipy.signal import butter, sosfilt, lfilter

SR = 24000
rng = np.random.default_rng(7)


def _bp(x, f, q):
    w = 2 * np.pi * f / SR
    r = np.exp(-w / (2 * q))
    a = [1, -2 * r * np.cos(w), r * r]
    return lfilter([1 - r], a, x)


def _pink(n):
    w = rng.standard_normal(n)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
    a = [1, -2.494956002, 2.017265875, -0.522189400]
    return lfilter(b, a, w)


def gasp(strength=1.0, wet=0.0, dur=None, seed=None):
    g = np.random.default_rng(seed) if seed is not None else rng
    dur = dur or g.uniform(0.32, 0.55)
    n = int(SR * dur)
    t = np.linspace(0, 1, n)
    noise = _pink(n)
    out = np.zeros(n)
    # formants drift down slightly as the mouth closes towards the next word
    k = g.uniform(0.9, 1.1)
    for f, q, gain in ((720 * k, 4.0, 1.0), (1250 * k, 5.0, 0.7), (2600 * k, 6.0, 0.45), (3800, 4.0, 0.2)):
        seg = 4
        part = np.zeros(n)
        for s in range(seg):
            a, b = s * n // seg, (s + 1) * n // seg
            drift = 1.0 - 0.12 * (s / seg)
            part[a:b] = _bp(noise[a:b], f * drift, q)[: b - a]
        out += gain * part
    # high hiss through the teeth/lips
    out += 0.08 * sosfilt(butter(2, [3500, 6000], "band", fs=SR, output="sos"), noise)
    # real in-breaths roll off steeply above a few kHz
    out = sosfilt(butter(4, 5000, "low", fs=SR, output="sos"), out)
    # envelope: quick rise, longer fall
    env = np.where(t < 0.25, (t / 0.25) ** 1.5, np.exp(-3.2 * (t - 0.25)))
    out *= env
    # faint voiced catch at the end, on some gasps
    if g.random() < 0.6:
        m = int(SR * 0.07)
        tt = np.arange(m) / SR
        f0 = g.uniform(150, 190) * (1 + 0.02 * g.standard_normal(m)).cumsum() / np.arange(1, m + 1)
        voice = np.sign(np.sin(2 * np.pi * f0 * tt)) * 0.5 + np.sin(2 * np.pi * f0 * tt)
        voice = _bp(voice, 650, 3) * np.hanning(m) * 0.35
        out[-m:] += voice
    # wet rattle: sparse coarse crackle-like pops, low-pitched
    if wet > 0:
        for _ in range(int(g.uniform(3, 8) * wet)):
            i = int(g.uniform(0.1, 0.9) * n)
            m = int(SR * 0.012)
            if i + m >= n:
                continue
            tt = np.arange(m) / SR
            pop = np.sin(2 * np.pi * g.uniform(180, 320) * tt) * np.exp(-tt * 350)
            out[i:i + m] += pop * 0.6 * wet * env[i]
    out /= np.max(np.abs(out)) + 1e-9
    return (out * 0.4 * strength).astype(np.float32)
