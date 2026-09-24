"""Synthesizes every sound in the game (SFX + music) into assets/audio as 16-bit mono WAV.

Standard library only. Run from the project root:  python tools/gen_audio.py

The music is inspired by Azerbaijani mugham: tar-like plucks (Karplus-Strong) in the
Shur mode (with its half-flat second), a bowed kamancha-like voice, a low drone and
nağara / qaval drums in 6/8. Everything is seeded, so the output is reproducible.
"""
import math
import os
import random
import struct
import sys
import wave

SR = 44100
ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(ROOT, "..", "assets", "audio"))
rng = random.Random(7)
TAU = 2.0 * math.pi


# --- Primitives ---------------------------------------------------------------

def silence(sec):
    return [0.0] * int(sec * SR)


def noise(sec):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(sec * SR))]


def add(dst, src, at=0.0, gain=1.0):
    o = int(at * SR)
    n = min(len(src), len(dst) - o)
    for i in range(max(0, n)):
        dst[o + i] += src[i] * gain
    return dst


def scale(s, g):
    return [x * g for x in s]


def lowpass(s, cutoff):
    """One-pole lowpass; cutoff is Hz or a function of time in seconds."""
    out = [0.0] * len(s)
    y = 0.0
    fn = cutoff if callable(cutoff) else None
    a = 0.0 if fn else 1.0 - math.exp(-TAU * cutoff / SR)
    for i, x in enumerate(s):
        if fn:
            a = 1.0 - math.exp(-TAU * max(20.0, fn(i / SR)) / SR)
        y += a * (x - y)
        out[i] = y
    return out


def highpass(s, cutoff):
    lp = lowpass(s, cutoff)
    return [x - l for x, l in zip(s, lp)]


def bandpass(s, lo, hi):
    return highpass(lowpass(s, hi), lo)


def shape(s, attack, release, hold=0.0):
    """Linear attack, optional hold, exponential release (time constant in seconds)."""
    a = int(attack * SR)
    h = int(hold * SR)
    for i in range(len(s)):
        if i < a:
            g = i / a
        elif i < a + h:
            g = 1.0
        else:
            g = math.exp(-(i - a - h) / (release * SR))
        s[i] *= g
    return s


def fade(s, fin=0.005, fout=0.02):
    n = len(s)
    fi = max(1, int(fin * SR))
    fo = max(1, int(fout * SR))
    for i in range(min(fi, n)):
        s[i] *= i / fi
    for i in range(min(fo, n)):
        s[n - 1 - i] *= i / fo
    return s


def tone(sec, f0, f1=None, kind="sine", vib_rate=0.0, vib_depth=0.0):
    """Oscillator with optional exponential glide f0->f1 and vibrato (depth as ratio)."""
    n = int(sec * SR)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / max(1, n)
        f = f0 if f1 is None else f0 * (f1 / f0) ** t
        if vib_depth:
            f *= 1.0 + vib_depth * math.sin(TAU * vib_rate * i / SR)
        ph += f / SR
        p = ph % 1.0
        if kind == "sine":
            v = math.sin(TAU * ph)
        elif kind == "saw":
            v = 2.0 * p - 1.0
        elif kind == "tri":
            v = 4.0 * abs(p - 0.5) - 1.0
        else:  # square
            v = 1.0 if p < 0.5 else -1.0
        out[i] = v
    return out


def pluck(freq, sec, damp=0.995, bright=0.5):
    """Karplus-Strong plucked string (tar-like)."""
    n = int(sec * SR)
    p = max(2, int(round(SR / freq)))
    buf = [rng.uniform(-1.0, 1.0) for _ in range(p)]
    # Darken the excitation a little for a warmer attack
    for _ in range(int((1.0 - bright) * 3)):
        buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(p)]
    out = [0.0] * n
    idx = 0
    for i in range(n):
        cur = buf[idx]
        nxt = buf[(idx + 1) % p]
        buf[idx] = damp * 0.5 * (cur + nxt)
        out[i] = cur
        idx = (idx + 1) % p
    return out


def tar(freq, sec, gain=1.0, tremolo=False):
    """Tar voice: bright pluck + octave shimmer; `tremolo` repeats the stroke (riz)."""
    out = silence(sec)
    strokes = [0.0]
    if tremolo:
        strokes = [k / 13.0 for k in range(int(sec * 13.0))]
    for k, t in enumerate(strokes):
        g = gain * (1.0 if k == 0 else 0.55 * (1.0 - t / sec) + 0.2)
        body = pluck(freq, min(sec - t, 1.6), damp=0.996, bright=0.8)
        shimmer = pluck(freq * 2.0, min(sec - t, 0.8), damp=0.993, bright=0.9)
        add(out, body, t, g)
        add(out, shimmer, t, g * 0.25)
    return fade(out, 0.001, 0.05)


def kamancha(freq, sec, gain=1.0):
    """Bowed voice: saw with vibrato, formant-ish filtering and slow bow attack."""
    s = tone(sec, freq, kind="saw", vib_rate=5.5, vib_depth=0.009)
    s = bandpass(s, 250.0, 2200.0)
    bow = scale(bandpass(noise(sec), 1500.0, 4000.0), 0.04)
    s = [a + b for a, b in zip(s, bow)]
    return scale(fade(shape(s, min(0.35, sec * 0.3), sec * 0.5, hold=sec * 0.4), 0.01, 0.15), gain)


def reverb(s, mix=0.3, size=1.0, feedback=0.8, damp=0.35):
    """Small Schroeder reverb (4 damped combs + 2 allpasses)."""
    wet = [0.0] * len(s)
    for base in (0.0297, 0.0371, 0.0411, 0.0437):
        d = int(base * SR * size)
        line = [0.0] * d
        j = 0
        lp = 0.0
        for i, x in enumerate(s):
            y = line[j]
            lp += (1.0 - damp) * (y - lp)
            line[j] = x + lp * feedback
            wet[i] += y
            j = (j + 1) % d
    for base, g in ((0.005, 0.7), (0.0017, 0.7)):
        d = int(base * SR * size)
        line = [0.0] * d
        j = 0
        for i, x in enumerate(wet):
            y = line[j]
            v = x + y * g
            line[j] = v
            wet[i] = y - g * v
            j = (j + 1) % d
    return [a * (1.0 - mix) + b * mix * 0.3 for a, b in zip(s, wet)]


def make_loop(s, tail_sec):
    """Fold the last `tail_sec` (reverb tail) back onto the start for a seamless loop."""
    t = int(tail_sec * SR)
    body = s[:-t]
    for i in range(t):
        body[i] += s[len(s) - t + i]
    return body


def save(name, s, peak=0.9):
    m = max((abs(x) for x in s), default=0.0) or 1.0
    g = peak / m
    frames = struct.pack("<%dh" % len(s), *(int(max(-1.0, min(1.0, x * g)) * 32767) for x in s))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print("%-22s %6.2fs" % (name + ".wav", len(s) / SR))


# --- Sound effects -------------------------------------------------------------

def resonant(s, center, q=6.0):
    """State-variable band-pass; `center` is Hz or a function of time. Higher q = narrower."""
    out = [0.0] * len(s)
    low = band = 0.0
    fn = center if callable(center) else (lambda t: center)
    damp = 1.0 / q
    for i, x in enumerate(s):
        f = 2.0 * math.sin(math.pi * min(fn(i / SR), SR / 6.0) / SR)
        low += f * band
        high = x - low - damp * band
        band += f * high
        out[i] = band
    return out


def sfx_swing(variant):
    """Sword swing: a fast, narrow 'shhk' that sweeps up and back down (the blade
    passing by) plus a faint steel shimmer — short and sharp, not windy."""
    dur = 0.22
    peak = [0.075, 0.065, 0.085][variant]
    top = [4200.0, 3600.0, 5000.0][variant]

    def sweep(t):
        k = min(1.0, t / peak) if t < peak else max(0.0, 1.0 - (t - peak) / (dur - peak))
        return 900.0 + (top - 900.0) * k * k

    whoosh = resonant(noise(dur), sweep, q=5.0)
    # Envelope peaks exactly when the blade passes the ear
    env = [math.exp(-((i / SR - peak) / 0.035) ** 2) for i in range(len(whoosh))]
    out = [w * e for w, e in zip(whoosh, env)]
    for f, g in ((3150.0, 0.18), (4710.0, 0.12), (6230.0, 0.07)):
        ring = tone(dur, f * (1.0 + 0.01 * variant), f * 0.97)
        add(out, [r * g * math.exp(-max(0.0, i / SR - peak * 0.8) / 0.05) * min(1.0, i / SR / (peak * 0.8))
                  for i, r in enumerate(ring)])
    return fade(out, 0.001, 0.03)


def sfx_hit(variant, heavy=False):
    dur = 0.55 if heavy else 0.35
    out = silence(dur)
    thump = shape(tone(dur, 110.0 if heavy else 150.0, 38.0), 0.002, 0.12 if heavy else 0.07)
    add(out, thump, 0.0, 1.0)
    crack = shape(highpass(noise(0.08), 1200.0), 0.001, 0.018)
    add(out, crack, 0.0, 0.9)
    # Bone crunch: a few quick grains
    for k in range(5 if heavy else 3):
        grain = shape(bandpass(noise(0.03), 900.0, 3500.0), 0.001, 0.006)
        add(out, grain, 0.004 + k * rng.uniform(0.008, 0.02), 0.6)
    # Metallic ring of the blade
    for f in ([1180, 1870, 2650], [1320, 2010, 2890], [1050, 1760, 2480])[variant]:
        add(out, shape(tone(dur, f * (0.9 if heavy else 1.0)), 0.001, 0.09), 0.0, 0.12)
    if heavy:
        add(out, shape(lowpass(noise(dur), 400.0), 0.002, 0.15), 0.0, 1.2)
    return fade(out, 0.0005, 0.03)


def sfx_dash():
    s = highpass(lowpass(noise(0.25), lambda t: 900.0 + 5000.0 * math.sin(math.pi * min(1.0, t / 0.25))), 600.0)
    return fade(shape(s, 0.04, 0.06), 0.001, 0.04)


def sfx_nova():
    dur = 1.8
    out = silence(dur)
    inhale = noise(0.3)
    inhale = lowpass(inhale, lambda t: 300.0 + 3000.0 * (t / 0.3) ** 2)
    add(out, [x * (i / len(inhale)) ** 2 for i, x in enumerate(inhale)], 0.0, 0.8)
    roar = lowpass(noise(dur - 0.28), lambda t: 6000.0 * math.exp(-t * 2.2) + 250.0)
    add(out, shape(roar, 0.01, 0.45), 0.28, 1.2)
    boom = shape(tone(1.2, 90.0, 28.0), 0.003, 0.35)
    add(out, boom, 0.28, 1.4)
    for _ in range(40):
        t = 0.3 + rng.random() * 1.3
        c = shape(highpass(noise(0.02), 2000.0), 0.0005, 0.004)
        add(out, c, t, rng.uniform(0.15, 0.5))
    return fade(out, 0.002, 0.2)


def sfx_memory_burn():
    dur = 2.4
    out = silence(dur)
    for f, g in ((523.25, 1.0), (659.25, 0.7), (783.99, 0.6), (1046.5, 0.35)):
        s = tone(dur, f * 1.003, f * 0.94, vib_rate=4.0, vib_depth=0.004)
        # Reversed swell then fade: the memory flares up and slips away
        s = [x * math.sin(math.pi * min(1.0, (i / SR) / dur)) ** 1.5 for i, x in enumerate(s)]
        add(out, s, 0.0, g * 0.3)
    breath = bandpass(noise(dur), 1500.0, 5000.0)
    add(out, shape(breath, 0.9, 0.5), 0.0, 0.15)
    return reverb(fade(out, 0.01, 0.3), mix=0.5, size=2.2, feedback=0.84)


def sfx_echo():
    """Ember echo: the past bleeds through — a reversed swell of fire, a low
    choir-like drone and glassy shimmer, ending in a soft exhale."""
    dur = 3.2
    out = silence(dur)
    swell = lowpass(noise(1.2), lambda t: 200.0 + 2500.0 * (t / 1.2) ** 2)
    add(out, [x * (i / len(swell)) ** 3 for i, x in enumerate(swell)], 0.0, 0.9)
    for f, g in ((73.42, 0.6), (110.0, 0.4), (146.83, 0.3), (220.0, 0.15)):
        v = lowpass(tone(dur - 1.0, f, f * 1.01, kind="saw", vib_rate=0.3, vib_depth=0.003), 700.0)
        add(out, fade(shape(v, 0.5, 0.9, hold=0.6), 0.02, 0.4), 1.0, g)
    for f in (1318.5, 1760.0, 2349.3):
        add(out, fade(shape(tone(dur - 1.1, f, f * 0.985), 0.3, 0.6), 0.01, 0.3), 1.1, 0.06)
    add(out, shape(bandpass(noise(0.9), 400.0, 2400.0), 0.3, 0.3), dur - 0.9, 0.35)
    return reverb(fade(out, 0.01, 0.4), mix=0.5, size=2.6, feedback=0.85)


def sfx_parry():
    """Parry: a bright steel-on-steel ring — sharp transient, inharmonic partials
    that decay slowly, and a short shimmer tail."""
    dur = 1.1
    out = silence(dur)
    add(out, shape(highpass(noise(0.03), 3000.0), 0.0005, 0.006), 0.0, 1.0)
    for f, g, d in ((1480.0, 0.5, 0.35), (2210.0, 0.4, 0.3), (3170.0, 0.35, 0.22), (4630.0, 0.25, 0.16), (6020.0, 0.15, 0.1)):
        add(out, shape(tone(dur, f, f * 0.995), 0.0005, d), 0.0, g)
    add(out, shape(tone(0.25, 180.0, 90.0), 0.001, 0.05), 0.0, 0.5)
    return reverb(fade(out, 0.0005, 0.2), mix=0.25, size=1.2)


def sfx_block():
    """Block: a dull, damped metal thud — the shield takes it."""
    dur = 0.45
    out = silence(dur)
    add(out, shape(tone(dur, 140.0, 70.0), 0.001, 0.08), 0.0, 1.0)
    add(out, shape(bandpass(noise(0.12), 300.0, 2200.0), 0.0005, 0.03), 0.0, 0.8)
    for f in (620.0, 910.0, 1340.0):
        add(out, shape(tone(dur, f), 0.0005, 0.05), 0.0, 0.12)
    return fade(out, 0.0005, 0.05)


def sfx_execute():
    """Köz İnfazı: a reversed rush of fire into a crushing, ringing blow."""
    dur = 1.6
    out = silence(dur)
    rush = lowpass(noise(0.35), lambda t: 300.0 + 5000.0 * (t / 0.35) ** 2)
    add(out, [x * (i / len(rush)) ** 2 for i, x in enumerate(rush)], 0.0, 0.8)
    add(out, sfx_hit(0, heavy=True), 0.35, 1.3)
    add(out, shape(tone(1.0, 70.0, 30.0), 0.002, 0.35), 0.35, 1.2)
    for f in (1180.0, 1760.0):
        add(out, shape(tone(1.0, f, f * 0.97), 0.001, 0.3), 0.35, 0.12)
    return reverb(fade(out, 0.002, 0.2), mix=0.3, size=1.8)


def sfx_drink():
    """Nar şərbəti: three gulps and a breath."""
    dur = 0.9
    out = silence(dur)
    for k, t in enumerate((0.05, 0.28, 0.5)):
        g = bandpass(noise(0.14), 250.0, 900.0)
        g = [x * math.sin(math.pi * min(1.0, i / len(g))) for i, x in enumerate(g)]
        add(out, g, t, 0.8)
        add(out, shape(tone(0.12, 260.0 - k * 20, 180.0), 0.005, 0.04), t + 0.02, 0.3)
    add(out, shape(bandpass(noise(0.25), 800.0, 3000.0), 0.08, 0.1), 0.65, 0.25)
    return fade(out, 0.005, 0.05)


def sfx_perfect_dodge():
    """Perfect dodge: time bends — a pitch-dropping whoosh with a glassy chime."""
    dur = 0.9
    out = silence(dur)
    w = resonant(noise(0.5), lambda t: 3000.0 * math.exp(-t * 5.0) + 300.0, q=4.0)
    add(out, shape(w, 0.02, 0.15), 0.0, 1.0)
    for f in (1760.0, 2637.0):
        add(out, shape(tone(dur, f, f * 0.94), 0.005, 0.25), 0.02, 0.15)
    return reverb(fade(out, 0.002, 0.2), mix=0.4, size=1.6)


def sfx_whisper():
    dur = 2.2
    out = silence(dur)
    t = 0.05
    while t < dur - 0.25:
        syl = rng.uniform(0.07, 0.18)
        lo = rng.uniform(900, 1600)
        s = bandpass(noise(syl), lo, lo * 2.6)
        add(out, fade(shape(s, syl * 0.3, syl * 0.4), 0.005, 0.02), t, rng.uniform(0.5, 1.0))
        t += syl + rng.uniform(0.02, 0.12)
    return reverb(out, mix=0.55, size=2.5, feedback=0.85)


def sfx_shade_spawn():
    dur = 1.1
    out = silence(dur)
    add(out, shape(lowpass(noise(dur), 180.0), 0.25, 0.3), 0.0, 1.6)
    add(out, shape(tone(dur, 48.0, 62.0, kind="saw"), 0.3, 0.3), 0.0, 0.25)
    for k in range(10):
        g = shape(bandpass(noise(0.03), 700.0, 2500.0), 0.001, 0.008)
        add(out, g, 0.2 + k * 0.07 + rng.uniform(0, 0.04), 0.35)
    return fade(out, 0.05, 0.2)


def sfx_shade_windup():
    dur = 0.6
    out = silence(dur)
    hiss = lowpass(noise(dur), lambda t: 800.0 + 4000.0 * t / dur)
    add(out, shape(highpass(hiss, 500.0), 0.4, 0.08), 0.0, 0.6)
    growl = lowpass(tone(dur, 70.0, 95.0, kind="saw", vib_rate=23.0, vib_depth=0.05), 700.0)
    add(out, shape(growl, 0.3, 0.1), 0.0, 0.5)
    return fade(out, 0.01, 0.05)


def sfx_shade_death():
    dur = 1.0
    out = silence(dur)
    for k in range(22):
        t = 0.02 + (k / 22.0) ** 1.4 * 0.7 + rng.uniform(0, 0.03)
        lo = rng.uniform(800, 2000)
        g = shape(bandpass(noise(0.04), lo, lo * 3.0), 0.0005, rng.uniform(0.006, 0.015))
        add(out, g, t, rng.uniform(0.3, 0.8))
    add(out, shape(lowpass(noise(dur), 900.0), 0.05, 0.25), 0.0, 0.6)
    return fade(out, 0.002, 0.1)


def sfx_player_hurt():
    dur = 0.4
    out = silence(dur)
    add(out, shape(tone(dur, 120.0, 55.0), 0.002, 0.1), 0.0, 1.0)
    add(out, shape(lowpass(noise(0.15), 1500.0), 0.001, 0.03), 0.0, 0.7)
    add(out, shape(tone(dur, 880.0, 820.0), 0.001, 0.12), 0.0, 0.08)
    return fade(out, 0.001, 0.05)


def sfx_footstep(variant):
    dur = 0.12
    s = bandpass(noise(dur), 150.0 + variant * 40.0, 1400.0 + variant * 200.0)
    return fade(shape(s, 0.002, 0.025), 0.001, 0.02)


def sfx_boss_roar():
    dur = 2.0
    out = silence(dur)
    for f in (55.0, 82.4, 110.0):
        v = lowpass(tone(dur, f, f * 0.8, kind="saw", vib_rate=7.0, vib_depth=0.03), 900.0)
        add(out, shape(v, 0.25, 0.7), 0.0, 0.5)
    add(out, shape(bandpass(noise(dur), 300.0, 1400.0), 0.3, 0.6), 0.0, 0.6)
    return reverb(fade(out, 0.02, 0.3), mix=0.35, size=2.0)


def sfx_horn():
    dur = 3.0
    out = silence(dur)
    for f, g in ((73.42, 1.0), (110.0, 0.5), (146.83, 0.3)):
        v = lowpass(tone(dur, f * 0.97, f, kind="saw", vib_rate=4.5, vib_depth=0.004), 600.0)
        add(out, shape(v, 0.6, 0.9, hold=0.8), 0.0, g)
    return reverb(fade(out, 0.05, 0.4), mix=0.4, size=2.5, feedback=0.84)


def sfx_ui(click=True):
    dur = 0.08 if click else 0.25
    s = shape(tone(dur, 1400.0 if click else 880.0, 1200.0 if click else 1320.0), 0.001, 0.015 if click else 0.08)
    return fade(s, 0.001, 0.02)


def loop_fire():
    dur = 8.0
    out = silence(dur + 1.0)
    add(out, lowpass(noise(dur + 1.0), 350.0), 0.0, 0.8)
    for _ in range(170):
        t = rng.random() * dur
        c = shape(highpass(noise(0.03), rng.uniform(1500, 4000)), 0.0005, rng.uniform(0.002, 0.008))
        add(out, c, t, rng.uniform(0.1, 0.6))
    return make_loop(out, 1.0)


def loop_wind():
    dur = 12.0
    out = silence(dur + 2.0)
    w = noise(dur + 2.0)
    w = lowpass(w, lambda t: 350.0 + 250.0 * math.sin(TAU * t / 6.0) + 120.0 * math.sin(TAU * t / 2.3))
    add(out, w, 0.0, 1.0)
    add(out, lowpass(bandpass(noise(dur + 2.0), 900.0, 1800.0), 1200.0), 0.0, 0.08)
    return make_loop(out, 2.0)


# --- Music ----------------------------------------------------------------------

D3 = 146.83
# Shur mode on D: D, E-half-flat, F, G, A, Bb, C (semitones from D)
SHUR = [0.0, 1.5, 3.0, 5.0, 7.0, 8.0, 10.0]


def shur(degree, base=D3):
    octave, idx = divmod(degree, 7)
    return base * 2.0 ** ((SHUR[idx] + 12.0 * octave) / 12.0)


def drone(sec, gain=1.0):
    out = silence(sec)
    for f, g in ((73.42, 1.0), (110.0, 0.45), (146.83, 0.25)):
        v = lowpass(tone(sec, f, kind="saw", vib_rate=0.13, vib_depth=0.002), 320.0)
        add(out, v, 0.0, g)
    # Slow breathing swell whose period divides the loop length
    period = sec / 4.0
    return [x * gain * (0.65 + 0.35 * math.sin(TAU * i / SR / period)) for i, x in enumerate(out)]


def gong(sec, f=55.0):
    out = silence(sec)
    for ratio, g, dec in ((1.0, 1.0, 1.8), (2.76, 0.5, 1.2), (5.4, 0.25, 0.7), (8.9, 0.12, 0.4)):
        add(out, shape(tone(sec, f * ratio), 0.004, dec), 0.0, g)
    return out


def play_phrase(dst, start, notes, beat, gain=1.0, voice="tar"):
    """notes: (degree, beats[, tremolo]) with degree None for a rest."""
    t = start
    for n in notes:
        deg, beats = n[0], n[1]
        trem = len(n) > 2 and n[2]
        dur = beats * beat
        if deg is not None:
            if voice == "tar":
                add(dst, tar(shur(deg), dur + 0.9, tremolo=trem), t, gain)
            else:
                add(dst, kamancha(shur(deg, D3 * 2.0), dur + 0.25), t, gain)
        t += dur
    return t


def music_ambient():
    """Exploration: sparse tar improvisation over a drone, a kamancha answer and a distant gong."""
    length = 64.0
    tail = 4.0
    out = silence(length + tail)
    add(out, drone(length + tail), 0.0, 0.32)
    add(out, gong(8.0, 55.0), 0.0, 0.35)
    add(out, gong(8.0, 49.0), 32.0, 0.3)
    beat = 0.5
    # Mugham-like phrases: open on the tonic, climb, ornament the half-flat second, fall back
    p1 = [(0, 2), (1, 1), (2, 1), (1, 1), (0, 3, True), (None, 2), (-1, 1), (0, 1), (2, 2), (3, 1), (2, 1), (1, 2), (0, 4, True)]
    p2 = [(4, 2), (3, 1), (4, 1), (5, 2, True), (4, 1), (3, 1), (2, 2), (1, 1), (2, 1), (1, 1), (0, 4, True)]
    k1 = [(0, 6), (1, 4), (2, 6), (1, 4), (0, 8)]
    p3 = [(7, 2, True), (6, 1), (5, 1), (4, 2), (3, 1), (2, 1), (1, 2), (2, 1), (1, 1), (0, 6, True)]
    play_phrase(out, 2.0, p1, beat, 0.55)
    play_phrase(out, 17.0, p2, beat, 0.55)
    play_phrase(out, 31.0, k1, beat, 0.35, voice="kamancha")
    play_phrase(out, 47.0, p3, beat, 0.55)
    wind = lowpass(noise(length + tail), 500.0)
    add(out, wind, 0.0, 0.05)
    return make_loop(reverb(out, mix=0.4, size=2.4, feedback=0.83), tail)


def drum_dum():
    s = shape(tone(0.4, 95.0, 42.0), 0.001, 0.12)
    return add(s, shape(lowpass(noise(0.05), 2500.0), 0.0005, 0.01), 0.0, 0.5)


def drum_tek():
    return fade(shape(bandpass(noise(0.09), 1800.0, 5000.0), 0.0005, 0.018), 0.0005, 0.01)


def drum_jingle():
    s = highpass(noise(0.12), 6000.0)
    return shape(s, 0.001, 0.035)


def music_battle():
    """Combat: nağara and qaval in 6/8, driving tar ostinato, kamancha cries in the second half."""
    eighth = 0.21
    bar = eighth * 6.0
    bars = 24
    length = bar * bars
    tail = 3.0
    out = silence(length + tail)
    add(out, drone(length + tail), 0.0, 0.4)

    dum, tek, jingle = drum_dum(), drum_tek(), drum_jingle()
    groove = ["D", "", "T", "D", "T", "T"]
    fill = ["T", "T", "T", "D", "T", "D"]
    ostinato = [0, 1, 2, 1, 0, -1]
    for b in range(bars):
        start = b * bar
        pattern = fill if b % 4 == 3 else groove
        for k, hit in enumerate(pattern):
            t = start + k * eighth
            if hit == "D":
                add(out, dum, t, 1.0)
            elif hit == "T":
                add(out, tek, t, 0.55 + (0.2 if k == 0 else 0.0))
            add(out, jingle, t + eighth * 0.5, 0.12)
        for k, deg in enumerate(ostinato):
            accent = 1.0 if k in (0, 3) else 0.7
            add(out, tar(shur(deg), eighth + 0.35), start + k * eighth, 0.28 * accent)
            if b >= 16:
                add(out, tar(shur(deg + 7), eighth + 0.25), start + k * eighth, 0.12 * accent)
    cries = [(4, 6), (5, 3), (4, 3), (2, 6), (1, 3), (0, 3), (1, 6), (2, 3), (1, 3), (0, 12)]
    play_phrase(out, 8 * bar, cries, eighth, 0.3, voice="kamancha")
    return make_loop(reverb(out, mix=0.22, size=1.6, feedback=0.78), tail)


def sting_victory():
    out = silence(5.0)
    add(out, drone(5.0), 0.0, 0.25)
    play_phrase(out, 0.1, [(0, 1), (2, 1), (4, 1), (7, 5, True)], 0.3, 0.6)
    add(out, gong(5.0, 73.42), 0.0, 0.3)
    return reverb(fade(out, 0.01, 1.0), mix=0.4, size=2.2)


def sting_defeat():
    out = silence(6.0)
    add(out, gong(6.0, 41.2), 0.0, 0.8)
    play_phrase(out, 0.6, [(2, 4), (1, 4), (0, 8)], 0.3, 0.35, voice="kamancha")
    return reverb(fade(out, 0.01, 1.2), mix=0.45, size=2.5, feedback=0.84)


# --- Open world (V3 Faza B) -------------------------------------------------------

def loop_rain():
    """Rain: dense filtered hiss with scattered drops on leaves and puddles."""
    dur = 8.0
    out = silence(dur + 2.0)
    add(out, lowpass(highpass(noise(dur + 2.0), 400.0), 5200.0), 0.0, 0.55)
    add(out, lowpass(noise(dur + 2.0), 260.0), 0.0, 0.35)
    for _ in range(420):
        t = rng.uniform(0.0, dur + 1.8)
        f = rng.uniform(1800.0, 5200.0)
        add(out, shape(tone(0.03, f, f * 0.7), 0.0005, 0.006), t, rng.uniform(0.05, 0.18))
    return make_loop(out, 2.0)


def loop_river():
    """River: low churning rush with bubbling mid tones."""
    dur = 10.0
    out = silence(dur + 2.0)
    add(out, lowpass(noise(dur + 2.0), lambda t: 500.0 + 140.0 * math.sin(TAU * t / 3.1)), 0.0, 0.9)
    add(out, bandpass(noise(dur + 2.0), 700.0, 2400.0), 0.0, 0.12)
    for _ in range(160):
        t = rng.uniform(0.0, dur + 1.8)
        f = rng.uniform(300.0, 900.0)
        add(out, shape(tone(0.06, f, f * 1.8), 0.002, 0.02), t, rng.uniform(0.04, 0.12))
    return make_loop(out, 2.0)


def loop_birds():
    """Daytime: a soft wind bed with scattered birdsong chirps and trills."""
    dur = 14.0
    out = silence(dur + 2.0)
    add(out, lowpass(noise(dur + 2.0), 300.0), 0.0, 0.12)
    t = 0.3
    while t < dur + 1.0:
        kind = rng.random()
        base = rng.uniform(2200.0, 4200.0)
        if kind < 0.5:
            for k in range(rng.randint(2, 5)):
                add(out, shape(tone(0.07, base * 1.15, base), 0.004, 0.025), t + k * 0.09, 0.22)
        elif kind < 0.8:
            add(out, shape(tone(0.35, base, base, vib_rate=28.0, vib_depth=0.05), 0.01, 0.12), t, 0.16)
        else:
            add(out, shape(tone(0.18, base * 0.8, base * 1.3), 0.01, 0.05), t, 0.2)
        t += rng.uniform(0.5, 1.8)
    return make_loop(reverb(out, mix=0.25, size=1.4), 2.0)


def loop_crickets():
    """Night: cricket chorus pulsing at slightly different rates."""
    dur = 12.0
    out = silence(dur + 2.0)
    for c in range(5):
        f = rng.uniform(4200.0, 5600.0)
        rate = rng.uniform(2.5, 4.5)
        off = rng.uniform(0.0, 1.0)
        n = int((dur + 2.0) * SR)
        ch = [0.0] * n
        for i in range(n):
            tt = i / SR
            burst = max(0.0, math.sin(TAU * rate * tt + off * TAU)) ** 8
            ch[i] = math.sin(TAU * f * tt) * burst * (0.5 + 0.5 * math.sin(TAU * 40.0 * tt))
        add(out, ch, 0.0, 0.08)
    add(out, lowpass(noise(dur + 2.0), 200.0), 0.0, 0.08)
    return make_loop(out, 2.0)


def sfx_splash():
    """Falling into water."""
    dur = 1.0
    out = silence(dur)
    add(out, shape(lowpass(noise(0.6), lambda t: 4000.0 * math.exp(-t * 4.0) + 300.0), 0.002, 0.18), 0.0, 1.0)
    add(out, shape(tone(0.3, 220.0, 90.0), 0.002, 0.08), 0.0, 0.4)
    for _ in range(18):
        t = rng.uniform(0.05, 0.7)
        f = rng.uniform(600.0, 1600.0)
        add(out, shape(tone(0.05, f, f * 1.6), 0.001, 0.015), t, 0.15)
    return fade(out, 0.001, 0.1)


def sfx_swim_stroke():
    """One swimming stroke: a soft push of water."""
    dur = 0.5
    out = silence(dur)
    add(out, shape(bandpass(noise(0.4), 200.0, 1400.0), 0.08, 0.1), 0.0, 1.0)
    return fade(out, 0.01, 0.05)


def _save_world():
    save("rain_loop", loop_rain(), peak=0.55)
    save("river_loop", loop_river(), peak=0.55)
    save("birds_loop", loop_birds(), peak=0.45)
    save("crickets_loop", loop_crickets(), peak=0.4)
    save("splash", sfx_splash(), peak=0.8)
    save("swim_stroke", sfx_swim_stroke(), peak=0.5)


def _save_combat():
    """V3 combat sounds: parry, block, execution, drinking, perfect dodge."""
    save("parry", sfx_parry(), peak=0.85)
    save("block", sfx_block(), peak=0.75)
    save("execute", sfx_execute(), peak=0.9)
    save("drink", sfx_drink(), peak=0.6)
    save("perfect_dodge", sfx_perfect_dodge(), peak=0.7)


def main():
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    if only:
        # Regenerate just the named groups, e.g.:  python tools/gen_audio.py swing
        if "swing" in only:
            for v in range(3):
                save("swing_%d" % v, sfx_swing(v), peak=0.85)
        if "echo" in only:
            save("echo", sfx_echo(), peak=0.7)
        if "combat" in only:
            _save_combat()
        if "world" in only:
            _save_world()
        return
    _save_combat()
    _save_world()
    for v in range(3):
        save("swing_%d" % v, sfx_swing(v), peak=0.85)
        save("hit_%d" % v, sfx_hit(v))
        save("footstep_%d" % v, sfx_footstep(v), peak=0.5)
    save("hit_heavy", sfx_hit(0, heavy=True))
    save("dash", sfx_dash(), peak=0.7)
    save("nova", sfx_nova())
    save("memory_burn", sfx_memory_burn(), peak=0.7)
    save("whisper", sfx_whisper(), peak=0.6)
    save("echo", sfx_echo(), peak=0.7)
    save("shade_spawn", sfx_shade_spawn(), peak=0.7)
    save("shade_windup", sfx_shade_windup(), peak=0.6)
    save("shade_death", sfx_shade_death(), peak=0.7)
    save("player_hurt", sfx_player_hurt())
    save("boss_roar", sfx_boss_roar())
    save("horn", sfx_horn(), peak=0.8)
    save("ui_click", sfx_ui(True), peak=0.4)
    save("ui_select", sfx_ui(False), peak=0.4)
    save("loop_fire", loop_fire(), peak=0.5)
    save("loop_wind", loop_wind(), peak=0.5)
    save("sting_victory", sting_victory(), peak=0.8)
    save("sting_defeat", sting_defeat(), peak=0.8)
    save("music_ambient", music_ambient(), peak=0.75)
    save("music_battle", music_battle(), peak=0.8)


if __name__ == "__main__":
    main()
