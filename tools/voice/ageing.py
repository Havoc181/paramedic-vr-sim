"""Voice ageing and breathless weakness, done in the voice source itself.

The speech is split by the WORLD vocoder into pitch (F0), vocal-tract
envelope and aperiodicity, changed there, and resynthesised. This gives a
clean, natural result, unlike adding noise or effects on top (which sounded
like a rattle). Changes follow the ageing-voice literature:
- F0: older women's voices drop in pitch; older men's change little or rise
  slightly. More F0 variability.
- Jitter and shimmer (cycle-to-cycle pitch and loudness instability) rise
  with age, especially past 80; a slight slow tremor.
- Breathiness: more aperiodic (airy) energy, i.e. incomplete vocal fold
  closure; done by raising aperiodicity, so it stays part of the voice.
- Slightly longer vocal tract: formants a little lower.
- Breathless speech: the voice weakens and gets breathier towards the end of
  each breath group as air runs out.
"""
import numpy as np
from scipy.ndimage import gaussian_filter1d
import world

SR = 24000
FP = 5.0  # ms per frame

PRESETS = {
    # f0 scale, jitter (fraction), shimmer (dB), tremor (fraction, Hz), breathy (0-1), formant scale
    "old_woman": dict(f0=0.86, jitter=0.008, shimmer=0.7, tremor=(0.0, 5.0), drift=0.008, breathy=0.30, formant=0.96),
    "old_man":   dict(f0=0.97, jitter=0.006, shimmer=0.6, tremor=(0.0, 5.0), drift=0.0, breathy=0.15, formant=0.97),
}


def _warp(sp, scale):
    """Scale formant frequencies by resampling the envelope along frequency."""
    n = sp.shape[1]
    src = np.clip(np.arange(n) / scale, 0, n - 1)
    lo = np.floor(src).astype(int); hi = np.minimum(lo + 1, n - 1); w = src - lo
    return sp[:, lo] * (1 - w) + sp[:, hi] * w


def age(x, preset="old_woman", rng=None, strength=1.0, breathless=0.0):
    """x: float audio at 24 kHz. breathless 0..1: weaken/breathier towards the end."""
    rng = rng or np.random.default_rng(0)
    p = PRESETS[preset]
    f0, sp, ap, fft = world.analyse(x, SR, FP)
    n = len(f0)
    voiced = f0 > 0
    t = np.linspace(0, 1, n)

    # pitch: lower/raise, add slow drift, jitter and tremor
    scale = 1 + (p["f0"] - 1) * strength
    jit = gaussian_filter1d(rng.standard_normal(n), 1.0) * p["jitter"] * strength
    drift = gaussian_filter1d(rng.standard_normal(n), 25) * p.get("drift", 0.0) * strength
    trem = p["tremor"][0] * strength * np.sin(2 * np.pi * p["tremor"][1] * np.arange(n) * FP / 1000.0)
    f0 = np.where(voiced, f0 * scale * (1 + jit + drift + trem), 0)
    if breathless > 0:   # pitch sags slightly as air runs out
        f0 = np.where(voiced, f0 * (1 - 0.05 * breathless * t), 0)

    # vocal tract: slightly lower formants
    sp = _warp(sp, 1 + (p["formant"] - 1) * strength)

    # shimmer and running out of air (loudness)
    shim_db = gaussian_filter1d(rng.standard_normal(n), 1.0) * p["shimmer"] * strength
    fade_db = -7.0 * breathless * t ** 1.4
    sp = sp * (10 ** ((shim_db + fade_db) / 10.0))[:, None]

    # breathiness: raise aperiodicity, more in upper bands and towards the end
    freqs = np.linspace(0, 1, ap.shape[1])[None, :]
    amount = (p["breathy"] * strength + 0.45 * breathless * t[:, None] ** 1.2) * (0.35 + 0.65 * freqs)
    ap = ap + (1 - ap) * np.clip(amount, 0, 0.9)

    y = world.synthesise(f0, sp, ap, fft, SR, FP)
    peak = np.max(np.abs(y)) + 1e-9
    return (y / peak * min(0.9, np.max(np.abs(x)) * 1.1)).astype(np.float32)
