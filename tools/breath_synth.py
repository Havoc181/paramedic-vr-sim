"""Synthesise breathing sounds from physiology settings (no recordings needed,
so no licensing issues). Produces a seamless loop as WAV, convert to OGG with
ffmpeg for Godot.

    python tools/breath_synth.py --rate 32 --ie 0.45 --effort 0.85 \
        --wet 0.7 --wheeze 0.25 --seconds 30 --out apo_bedside.wav

Components:
  breath noise  band-filtered noise shaped by the inspiratory/expiratory cycle
  effort        louder, harsher inspiration (more high-frequency energy)
  wet           bubbling/gurgling from fluid in the airways (damped low tones)
  crackles      short pops late in inspiration (fine crackles)
  wheeze        faint musical tone on expiration ("cardiac asthma")
"""
import argparse
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 44100


def band(x, lo, hi):
    sos = butter(4, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x)


def envelope(n_in, n_ex, rng):
    """One breath: smooth rise over inspiration, faster-then-tailing fall."""
    t_in = np.linspace(0, 1, n_in, endpoint=False)
    t_ex = np.linspace(0, 1, n_ex, endpoint=False)
    insp = np.sin(np.pi * t_in) ** 0.8
    exp = np.sin(np.pi * np.sqrt(t_ex)) ** 1.2 * 0.75
    return insp, exp


def synth(rate, ie, effort, wet, crackles, wheeze, seconds, seed):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    out = np.zeros(n)
    insp_mask = np.zeros(n)
    exp_mask = np.zeros(n)
    pos = 0
    while pos < n:
        period = 60.0 / rate * rng.uniform(0.93, 1.07)
        n_b = int(period * SR)
        n_in = int(n_b * ie)
        n_ex = n_b - n_in
        a, b = envelope(n_in, n_ex, rng)
        seg = np.concatenate([a, np.zeros(n_ex)]), np.concatenate([np.zeros(n_in), b])
        end = min(pos + n_b, n)
        insp_mask[pos:end] = seg[0][: end - pos]
        exp_mask[pos:end] = seg[1][: end - pos]
        pos += n_b

    noise = rng.standard_normal(n)
    # Breath noise: inspiration brighter than expiration; effort adds harshness.
    insp_noise = band(noise, 250, 1400) + effort * 0.6 * band(noise, 1400, 3500)
    exp_noise = band(noise, 180, 900)
    out += insp_noise * insp_mask * (0.5 + 0.5 * effort)
    out += exp_noise * exp_mask * 0.55

    # Wet bubbling: random damped low tones, through both phases.
    if wet > 0:
        bubble = np.zeros(n)
        count = int(seconds * 55 * wet)
        for _ in range(count):
            t0 = rng.integers(0, n - 4000)
            phase_weight = 0.4 + insp_mask[t0] + 0.7 * exp_mask[t0]
            if rng.random() > phase_weight:
                continue
            f = rng.uniform(140, 420)
            dur = int(rng.uniform(0.012, 0.05) * SR)
            tt = np.arange(dur) / SR
            pop = np.sin(2 * np.pi * f * tt * (1 + 0.6 * tt / tt[-1])) * np.exp(-tt * rng.uniform(60, 160))
            bubble[t0:t0 + dur] += pop * rng.uniform(0.3, 1.0)
        out += band(bubble, 90, 1200) * wet * 1.4

    # Fine crackles: brief pops in the later part of inspiration.
    if crackles > 0:
        cr = np.zeros(n)
        late_insp = np.where((insp_mask > 0.3) & (np.gradient(insp_mask) < 0.0005))[0]
        if len(late_insp):
            for t0 in rng.choice(late_insp, int(seconds * 40 * crackles)):
                d = int(SR * 0.003)
                if t0 + d >= n:
                    continue
                tt = np.arange(d) / SR
                cr[t0:t0 + d] += np.sin(2 * np.pi * 700 * tt) * np.exp(-tt * 1500) * rng.uniform(0.4, 1.0)
        out += cr * crackles * 0.8

    # Wheeze: faint tone on expiration with slight pitch wander.
    if wheeze > 0:
        t = np.arange(n) / SR
        f = 420 + 40 * np.sin(2 * np.pi * 0.37 * t)
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
        out += tone * exp_mask ** 1.5 * wheeze * 0.12

    # Seamless loop: crossfade the last 0.3 s into the start.
    xf = int(0.3 * SR)
    ramp = np.linspace(0, 1, xf)
    out[:xf] = out[:xf] * ramp + out[-xf:] * (1 - ramp)
    out = out[:-xf]
    out /= np.max(np.abs(out)) + 1e-9
    return (out * 0.8 * 32767).astype(np.int16)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--rate", type=float, default=16)
    p.add_argument("--ie", type=float, default=0.4)
    p.add_argument("--effort", type=float, default=0.3)
    p.add_argument("--wet", type=float, default=0.0)
    p.add_argument("--crackles", type=float, default=0.0)
    p.add_argument("--wheeze", type=float, default=0.0)
    p.add_argument("--seconds", type=float, default=30)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--out", default="breath.wav")
    a = p.parse_args()
    wavfile.write(a.out, SR, synth(a.rate, a.ie, a.effort, a.wet, a.crackles, a.wheeze, a.seconds, a.seed))
    print("wrote", a.out)
