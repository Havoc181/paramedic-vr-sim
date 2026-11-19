"""Breathless speech: speech in short breath groups with audible in-breaths
whose timbre is taken from the speaker's own voice.

Basis (sources in docs/backlog.md, voices section):
- Speech is produced in breath groups; in calm read speech nearly all
  in-breaths fall at syntactic boundaries, in spontaneous speech less strictly.
  Under physical load breath groups shorten, pauses and in-breaths lengthen,
  in-breaths get louder and the voice rises slightly in pitch.
- Inhalation noise is closest in spectrum to the speaker's own neutral vowel
  (schwa) with a more open jaw, and resembles /k/ aspiration in its centre of
  gravity; faster in-breaths are louder and brighter. So each speaker's gasp
  is made by passing noise through that speaker's own vocal-tract resonances
  (measured from a neutral vowel in their synthetic voice).

severity 0..1: 0 = full sentences; ~0.5 = short phrases; ~0.9 = a few words.
"""
import re
import numpy as np
from scipy.linalg import solve_toeplitz
from scipy.signal import lfilter, butter, sosfilt

SR = 24000


# --- speaker-matched in-breath -------------------------------------------------

def _lpc(x, order=18):
    x = x * np.hanning(len(x))
    r = np.correlate(x, x, "full")[len(x) - 1:len(x) + order]
    a = solve_toeplitz(r[:-1], -r[1:])
    return np.concatenate([[1.0], a])


def speaker_envelope(synth, voice):
    """Vocal-tract filter for this voice, from a sustained neutral vowel."""
    audio, _ = synth("uh, uh, uh", voice, 0.8)
    idx = np.where(np.abs(audio) > 0.05 * np.max(np.abs(audio)))[0]
    seg = audio[idx[0]:idx[-1]] if len(idx) > 1000 else audio
    mid = seg[len(seg) // 4: 3 * len(seg) // 4]
    return _lpc(mid.astype(np.float64))


def in_breath(env_a, rng, dur, loud, wet=0.0):
    n = int(SR * dur)
    t = np.linspace(0, 1, n)
    w = rng.standard_normal(n)
    # speaker's resonances, broadened a little (open jaw, turbulent source)
    a = env_a * (0.94 ** np.arange(len(env_a)))
    out = lfilter([1.0], a, w)
    # aspiration-like brightness, more for faster/louder gasps
    out += (0.15 + 0.25 * loud) * sosfilt(butter(2, [2000, 5000], "band", fs=SR, output="sos"), w)
    out = sosfilt(butter(4, 6000, "low", fs=SR, output="sos"), out)
    out = sosfilt(butter(2, 150, "high", fs=SR, output="sos"), out)
    peak = rng.uniform(0.3, 0.45)
    rise = np.clip(t / peak, 0, 1)
    fall = np.clip((t - peak) / (1 - peak), 0, 1)
    env = np.where(t < peak, np.sin(0.5 * np.pi * rise) ** 1.3, np.cos(0.5 * np.pi * fall) ** 1.6)
    out *= env
    if wet > 0:   # fluid in the larger airways: a few low, soft pops
        for _ in range(rng.integers(2, 6)):
            i = int(rng.uniform(0.15, 0.85) * n)
            m = int(SR * 0.01)
            if i + m < n:
                tt = np.arange(m) / SR
                out[i:i + m] += np.sin(2 * np.pi * rng.uniform(180, 300) * tt) * np.exp(-tt * 400) \
                    * wet * 0.5 * env[i] * np.std(out) * 6
    out /= np.max(np.abs(out)) + 1e-9
    return (out * (0.12 + 0.22 * loud)).astype(np.float32)


# --- breath groups -------------------------------------------------------------

FUNCTION_WORDS = {"a", "an", "the", "and", "or", "but", "of", "to", "in", "on", "at", "for",
                  "my", "your", "his", "her", "this", "that", "i", "it's", "is", "was", "be",
                  "been", "with", "had", "have", "has", "if", "so", "up"}


def breath_groups(text, severity, rng):
    """Split text into breath groups. Prefer sentence and comma boundaries;
    with more severe breathlessness also break mid-phrase, but not straight
    after a little linking word ("the", "and", "of"...) and never leaving a
    single word stranded at the end."""
    words = re.findall(r"\S+", text)
    mean = np.interp(severity, [0, 0.5, 0.9, 1], [14, 6, 3.5, 2.5])
    groups, cur = [], []
    target = max(2, int(round(rng.normal(mean, mean * 0.3))))
    for i, w in enumerate(words):
        cur.append(w)
        left = len(words) - i - 1
        bare = w.lower().strip(".,;:!?")
        strong = w[-1] in ".!?"
        medium = w[-1] in ",;:"
        if left == 0:
            groups.append(" ".join(cur)); break
        if left == 1 and not strong:
            continue
        ok_mid = bare not in FUNCTION_WORDS and len(cur) >= target and rng.random() < 0.25 + 0.5 * severity
        forced = (len(cur) >= target + 2 and bare not in FUNCTION_WORDS) or len(cur) >= target + 4
        if strong or (medium and len(cur) >= target - 1) or ok_mid or forced:
            groups.append(" ".join(cur))
            cur = []
            target = max(2, int(round(rng.normal(mean, mean * 0.3))))
    return groups


def breathless_line(synth, voice, text, severity=0.7, wet=0.4, speed=0.92, seed=1, env_a=None):
    rng = np.random.default_rng(seed)
    env_a = env_a if env_a is not None else speaker_envelope(synth, voice)
    groups = breath_groups(text, severity, rng)
    out = []
    for i, g in enumerate(groups):
        a, _ = synth(g, voice, speed)
        idx = np.where(np.abs(a) > 0.01)[0]
        if len(idx):
            a = a[max(0, idx[0] - 240): idx[-1] + 480]
        out.append(a.astype(np.float32))
        if i < len(groups) - 1:
            words = len(g.split())
            # recovery: longer, louder in-breath after a longer group
            dur = rng.uniform(0.28, 0.42) + 0.04 * min(words, 5) * severity
            loud = np.clip(0.4 + 0.5 * severity + rng.normal(0, 0.1), 0, 1)
            gap = rng.uniform(0.03, 0.09)
            out += [np.zeros(int(SR * gap), np.float32), in_breath(env_a, rng, dur, loud, wet),
                    np.zeros(int(SR * rng.uniform(0.02, 0.06)), np.float32)]
    return np.concatenate(out), groups
