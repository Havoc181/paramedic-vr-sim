"""Synthesise breathing sounds from physiology settings. No recordings are used,
so there are no licensing issues. Produces a seamless loop as WAV; convert to
OGG with ffmpeg for Godot.

Acoustic basis (see docs/backlog.md, audio plan, for sources):
- Normal vesicular sound: soft, low-pitched (dominant energy below ~200 Hz),
  power falling steeply with frequency; inspiration reaches ~450 Hz,
  expiration ~290 Hz and is quieter and shorter.
- Crackles: a sharp initial deflection followed by a damped wave whose
  half-cycles get longer. Fine: initial deflection width (IDW) ~0.7 ms,
  two-cycle duration (2CD) ~5 ms, softer and higher. Coarse: IDW ~1.5 ms,
  2CD ~10 ms, louder and lower. Heart-failure crackles sit in between and
  are mainly late inspiratory.

Presets:
    python tools/breath_synth.py --preset normal --out normal.wav
    python tools/breath_synth.py --preset apo_bedside --out apo_bedside.wav
    python tools/breath_synth.py --preset apo_chest --out apo_chest.wav
"""
import argparse
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 44100

PRESETS = {
    # Quiet breathing heard close to a healthy person.
    "normal": dict(rate=14, ie=0.42, effort=0.1, airway=0.15, fine=0, medium=0, coarse=0, wheeze=0),
    # Joan heard at close range without a stethoscope: effortful airway noise,
    # coarse "rattly" crackles through both phases, faint expiratory wheeze.
    "apo_bedside": dict(rate=32, ie=0.45, effort=0.85, airway=0.6, fine=0.2, medium=0.5, coarse=0.7, wheeze=0.15),
    # Joan through a stethoscope at the bases (for later versions): late
    # inspiratory heart-failure crackles over harsh breath sounds.
    "apo_chest": dict(rate=32, ie=0.45, effort=0.7, airway=0.0, fine=0.6, medium=0.8, coarse=0.2, wheeze=0.1),
}

# Crackle families: (IDW ms, growth of each half-cycle, half-cycles, loudness)
CRACKLE_TYPES = {
    "fine": (0.7, 1.5, 6, 0.45),
    "medium": (1.1, 1.42, 6, 0.7),   # typical of heart failure
    "coarse": (1.5, 1.42, 6, 1.0),
}


def lowpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="low", fs=SR, output="sos"), x)


def highpass(x, f, order=2):
    return sosfilt(butter(order, f, btype="high", fs=SR, output="sos"), x)


def vesicular_noise(n, rng, top_hz):
    """Noise with most energy below ~200 Hz and a steep roll-off above,
    stretching to `top_hz`."""
    x = rng.standard_normal(n)
    x = highpass(x, 60)
    x = lowpass(x, 180, order=2)          # ~12 dB/oct above the knee
    x = lowpass(x, top_hz, order=2)       # extra fall towards the maximum
    return x


def crackle(kind, rng):
    """One crackle waveform per the CORSA time-domain description."""
    idw, growth, cycles, loud = CRACKLE_TYPES[kind]
    idw *= rng.uniform(0.85, 1.15)
    parts = []
    half = idw / 1000.0
    amp = 1.0
    for i in range(cycles):
        m = max(int(half * SR), 2)
        seg = np.sin(np.linspace(0, np.pi, m, endpoint=False))
        # Largest deflection comes just after the initial one, then decays.
        a = amp * (0.7 if i == 0 else (1.0 if i == 1 else 0.75 ** (i - 1)))
        parts.append(seg * a * (1 if i % 2 == 0 else -1))
        half *= growth
    w = np.concatenate(parts)
    return w * loud * rng.uniform(0.5, 1.0)


def breath_masks(n, rate, ie, effort, rng):
    insp = np.zeros(n)
    exp = np.zeros(n)
    phase = np.zeros(n)  # 0..1 within inspiration, 1..2 within expiration
    pos = 0
    while pos < n:
        period = 60.0 / rate * rng.uniform(0.94, 1.06)
        n_b = int(period * SR)
        n_in = int(n_b * ie)
        # Pause at the end of expiration shrinks as breathing gets harder.
        n_ex = int((n_b - n_in) * (1.0 - 0.18 * (1.0 - effort)))
        t_in = np.linspace(0, 1, n_in, endpoint=False)
        t_ex = np.linspace(0, 1, n_ex, endpoint=False)
        a = np.sin(np.pi * t_in) ** 0.7
        b = (np.sin(np.pi * np.sqrt(t_ex)) ** 1.3) * (0.55 + 0.3 * effort)
        for arr, seg, off in ((insp, a, 0), (exp, b, n_in)):
            s = pos + off
            e = min(s + len(seg), n)
            if s < n:
                arr[s:e] = seg[: e - s]
        s, e = pos, min(pos + n_in, n)
        phase[s:e] = t_in[: e - s]
        s, e = pos + n_in, min(pos + n_in + n_ex, n)
        if s < n:
            phase[s:e] = 1 + t_ex[: e - s]
        pos += n_b
    return insp, exp, phase


def synth(rate, ie, effort, airway, fine, medium, coarse, wheeze, seconds, seed):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    insp, exp, phase = breath_masks(n, rate, ie, effort, rng)

    # Lung (vesicular) component: inspiration brighter than expiration.
    insp_top = 450 + 500 * effort
    exp_top = 290 + 250 * effort
    out = vesicular_noise(n, rng, insp_top) * insp * (0.6 + 0.6 * effort)
    out += vesicular_noise(n, rng, exp_top) * exp * 0.7

    # Airway/mouth component heard near the face when breathing hard: broader,
    # cut off around 1 kHz like tracheal sound, still soft.
    if airway > 0:
        a = rng.standard_normal(n)
        a = lowpass(highpass(a, 150), 900, order=4)
        out += a * (insp * 0.9 + exp * 0.6) * airway * 0.35

    # Crackles, timed by type: fine/medium mostly late inspiration,
    # coarse in early inspiration and through expiration.
    cr = np.zeros(n)
    plan = (("fine", fine, (0.55, 1.0), 26),
            ("medium", medium, (0.4, 1.0), 22),
            ("coarse", coarse, (0.0, 0.5), 12))
    for kind, amount, (p0, p1), per_breath in plan:
        if amount <= 0:
            continue
        idx = np.where((phase >= p0) & (phase < p1))[0]
        if kind == "coarse":
            idx = np.concatenate([idx, np.where((phase >= 1.0) & (phase < 1.7))[0]])
        count = int(per_breath * amount * seconds * rate / 60.0)
        for t0 in rng.choice(idx, count):
            w = crackle(kind, rng)
            if t0 + len(w) < n:
                cr[t0:t0 + len(w)] += w
    # Chest wall and air soften crackles a little.
    out += lowpass(cr, 1500, order=2) * 0.28

    # Wheeze: faint musical tone on expiration with slight pitch wander.
    if wheeze > 0:
        t = np.arange(n) / SR
        f = 380 + 30 * np.sin(2 * np.pi * 0.3 * t)
        ph = 2 * np.pi * np.cumsum(f) / SR
        tone = np.sin(ph) + 0.25 * np.sin(2 * ph)
        out += tone * (exp / (0.55 + 0.3 * effort)) ** 2 * wheeze * 0.05

    # Seamless loop: crossfade the end into the start.
    xf = int(0.25 * SR)
    ramp = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * ramp + out[-xf:] * (1 - ramp)
    out = out[:-xf]
    out /= np.max(np.abs(out)) + 1e-9
    return out


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--preset", choices=sorted(PRESETS), default="normal")
    p.add_argument("--seconds", type=float, default=20)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--gain", type=float, default=0.8, help="peak level 0-1")
    p.add_argument("--out", default="breath.wav")
    for k in ("rate", "ie", "effort", "airway", "fine", "medium", "coarse", "wheeze"):
        p.add_argument("--" + k, type=float)
    a = p.parse_args()
    params = dict(PRESETS[a.preset])
    for k in params:
        if getattr(a, k) is not None:
            params[k] = getattr(a, k)
    x = synth(seconds=a.seconds, seed=a.seed, **params)
    wavfile.write(a.out, SR, (x * a.gain * 32767).astype(np.int16))
    print("wrote", a.out, params)
