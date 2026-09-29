"""Builds every enemy voice line and animal cry into assets/audio/voice/.

Speech: edge-tts (Microsoft neural Turkish voices) → decode → trim → per-profile
character chain (numpy DSP): the ash whisper through an STFT phase-randomised layer and
a long reversed-swell reverb, bandits get grit and a room, the giant an octave-down
distortion. Animals (wolf, leopard) are synthesised: formant-shaped howls with vibrato,
pulsed growls, snarls, yelps and the leopard's sawing roar.

Writes data/voices/manifest.json (profile → event → [{file, text}]), used at runtime by
scripts/systems/barks.gd. Cached: a line is only re-synthesised when its text or
profile changes.

Needs: pip install edge-tts numpy miniaudio.
Usage: python tools/gen_voices.py [profile ...]
"""
import asyncio, csv, hashlib, json, os, sys, wave
import numpy as np
import edge_tts
import miniaudio

SR = 24000  # the neural voices are 24 kHz; more would only add bytes
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "audio", "voice")
DATA = os.path.join(ROOT, "data", "voices", "voices.json")
MANIFEST = os.path.join(ROOT, "data", "voices", "manifest.json")
CACHE = os.path.join(OUT, ".cache.json")
rng = np.random.default_rng(11)


# --- Basic DSP ---------------------------------------------------------------------------

def save_wav(path, x, peak=0.9):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    f = min(len(x), int(0.02 * SR))
    x[:f] *= np.linspace(0, 1, f)
    x[len(x) - f:] *= np.linspace(1, 0, f)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def trim(x, thresh=0.015, pad=0.04):
    env = np.abs(x)
    idx = np.where(env > thresh * np.max(env))[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(pad * SR))
    b = min(len(x), idx[-1] + int(pad * 2 * SR))
    return x[a:b]


def onepole_lp(x, fc):
    a = 1.0 - np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s += a * (v - s)
        y[i] = s
    return y


def fft_filter(x, lo=None, hi=None, gains=None):
    """Zero-phase band filter in the frequency domain; gains = [(f, dB), ...] shelf points."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / (1 + (lo / np.maximum(f, 1)) ** 4)
    if hi:
        g *= 1 / (1 + (f / hi) ** 4)
    if gains:
        pts = sorted(gains)
        db = np.interp(f, [p[0] for p in pts], [p[1] for p in pts])
        g *= 10 ** (db / 20)
    return np.fft.irfft(X * g, n)


def resample(x, factor):
    """factor < 1 lowers pitch and slows down (tape style)."""
    n = int(len(x) / factor)
    t = np.linspace(0, len(x) - 1, n)
    return np.interp(t, np.arange(len(x)), x)


def drive(x, amount):
    return np.tanh(x * amount) / np.tanh(amount)


def impulse(seconds, decay, bright=4000.0, predelay=0.0):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal(n) * np.exp(-t / decay)
    ir = fft_filter(ir, hi=bright)
    pre = np.zeros(int(predelay * SR))
    ir = np.concatenate([pre, ir])
    ir[0] = 1.0
    return ir / np.max(np.abs(ir))


def reverb(x, mix, seconds=1.6, decay=0.45, bright=4000.0):
    ir = impulse(seconds, decay, bright, 0.012)
    n = len(x) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    wet = wet / (np.max(np.abs(wet)) or 1) * np.max(np.abs(x))
    dry = np.concatenate([x, np.zeros(len(ir))])
    return dry * (1 - mix) + wet * mix


def echo(x, delay, fb, mix):
    d = int(delay * SR)
    y = np.concatenate([x, np.zeros(d * 6)])
    out = y.copy()
    tap = y.copy()
    for k in range(1, 6):
        tap = np.concatenate([np.zeros(d), tap[:-d]]) * fb
        out += tap * mix
    return out


def whisper(x, frame=1024, hop=256):
    """Keeps the spectral envelope, throws away pitch: breathy, voiceless speech."""
    win = np.hanning(frame)
    pad = np.concatenate([np.zeros(frame), x, np.zeros(frame)])
    out = np.zeros(len(pad) + frame)
    for i in range(0, len(pad) - frame, hop):
        seg = pad[i:i + frame] * win
        S = np.fft.rfft(seg)
        mag = np.abs(S)
        # smooth the magnitude so harmonics blur into noise bands
        mag = np.convolve(mag, np.ones(9) / 9, mode="same")
        ph = rng.uniform(-np.pi, np.pi, len(S))
        out[i:i + frame] += np.fft.irfft(mag * np.exp(1j * ph), frame) * win
    return out[frame:frame + len(x)]


def reverse_swell(x, seconds=0.5):
    """A reversed reverb tail that swells into the first word (ghostly)."""
    head = x[: int(0.6 * SR)]
    wet = reverb(head, 1.0, 1.2, 0.35, 3000)[::-1]
    lead = wet[-int(seconds * SR):] * 0.5
    return np.concatenate([lead, x])


def chorus(x, cents=(-14, 9, 17)):
    out = x.copy()
    for c in cents:
        f = 2 ** (c / 1200)
        y = resample(x, f)
        y = y[: len(x)] if len(y) >= len(x) else np.concatenate([y, np.zeros(len(x) - len(y))])
        out += y * 0.45
    return out


def normalise(x, peak=0.95):
    return x / (np.max(np.abs(x)) or 1) * peak


# --- Character chains ----------------------------------------------------------------------

def fx(x, name):
    if name == "bandit":
        y = fft_filter(x, lo=90, gains=[(0, 0), (250, 1.5), (2500, 3), (6000, 1), (12000, -4)])
        y = drive(y, 1.8)
        return reverb(y, 0.12, 0.8, 0.18, 5000)
    if name == "villager":
        # Plain folk outdoors: a little warmth and presence, a short open-air slap-back
        y = fft_filter(x, lo=85, gains=[(0, 0), (220, 1.0), (3000, 1.5), (11000, -3)])
        return reverb(y, 0.08, 0.5, 0.1, 6500)
    if name == "bandit_old":
        y = fft_filter(x, lo=80, hi=7000, gains=[(0, 0), (180, 2.5), (2000, 2)])
        y = drive(y, 2.4)
        return reverb(y, 0.14, 0.8, 0.2, 4000)
    if name == "ataman":
        y = resample(x, 0.94)
        y = fft_filter(y, lo=60, gains=[(0, 0), (120, 4), (1800, 2), (9000, -2)])
        y = drive(y, 2.0)
        return reverb(y, 0.22, 1.4, 0.35, 4500)
    if name in ("ash", "ash_hot"):
        low = resample(x, 0.86)
        wh = whisper(low)
        low = fft_filter(low, lo=70, hi=5000)
        y = low * 0.75 + normalise(wh) * np.max(np.abs(low)) * 0.55
        if name == "ash_hot":
            crackle = (rng.random(len(y)) > 0.9985) * rng.uniform(-1, 1, len(y))
            y = drive(y, 2.2) + fft_filter(crackle, lo=1500) * 0.35
        y = reverse_swell(y, 0.45)
        return reverb(y, 0.42, 2.6, 0.9, 3200)
    if name == "shaman":
        y = chorus(x)
        y = fft_filter(y, lo=120, gains=[(0, 0), (3000, 2)])
        y = echo(y, 0.19, 0.45, 0.35)
        return reverb(y, 0.35, 2.0, 0.6, 5000)
    if name == "giant":
        y = resample(x, 0.72)
        sub = resample(x, 0.36)[: len(y)]
        sub = np.concatenate([sub, np.zeros(max(0, len(y) - len(sub)))])
        y = fft_filter(y, lo=40, hi=4500, gains=[(0, 0), (90, 6), (700, 1)]) + fft_filter(sub, hi=500) * 0.35
        y = drive(y, 3.0)
        return reverb(y, 0.35, 2.4, 0.7, 2500)
    return x


# --- Animals -------------------------------------------------------------------------------

def harmonic_voice(f0, formants, noise=0.05, jitter=0.0, rolloff=1.1, harmonics=27):
    """f0: array of Hz per sample. formants: [(freq, bandwidth, gain)]."""
    n = len(f0)
    f = f0 * (1 + jitter * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
    phase = 2 * np.pi * np.cumsum(f) / SR
    src = np.zeros(n)
    for h in range(1, harmonics + 1):
        amp = 1.0 / h ** rolloff
        src += amp * np.sin(h * phase) * (h * np.mean(f0) < SR / 2.2)
    src += rng.standard_normal(n) * noise
    X = np.fft.rfft(src)
    fr = np.fft.rfftfreq(n, 1 / SR)
    g = np.zeros_like(fr)
    for fc, bw, gain in formants:
        g += gain / (1 + ((fr - fc) / bw) ** 2)
    return np.fft.irfft(X * (0.08 + g), n)


def envelope(n, a, r, hold=None):
    t = np.arange(n) / SR
    e = np.minimum(1, t / max(a, 1e-3))
    tail = (n / SR) - r
    e *= np.where(t > tail, np.exp(-(t - tail) / (r * 0.35)), 1)
    fade = min(n, int(0.03 * SR))
    e[n - fade:] *= np.linspace(1, 0, fade)   # land on silence: no click
    return e


def wolf_howl(i):
    dur = 2.8 + 0.6 * i
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = [390, 430, 360][i % 3]
    top = base * 1.55
    f0 = base + (top - base) * np.clip(t / 0.55, 0, 1) ** 0.6
    f0 -= (top - base * 1.1) * np.clip((t - dur * 0.62) / (dur * 0.38), 0, 1) ** 1.4
    f0 *= 1 + 0.018 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.8, 0, 1)
    # A howl is almost a pure tone: a few soft harmonics and a little breath
    v = harmonic_voice(f0, [(650, 260, 1.0), (1300, 400, 0.25)], 0.012, 0.0005, 2.6, 5)
    breath = fft_filter(rng.standard_normal(n), lo=500, hi=2500) * 0.015
    v = (v / (np.max(np.abs(v)) or 1) + breath) * envelope(n, 0.3, 1.1)
    return reverb(v, 0.45, 3.0, 1.2, 3000)


def growl(dur, f_lo, f_hi, rate, rough=0.6):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = np.linspace(f_lo, f_hi, n) * (1 + 0.08 * np.sin(2 * np.pi * rate * 0.5 * t))
    v = harmonic_voice(f0, [(420, 180, 1.0), (900, 300, 0.6), (1800, 400, 0.25)], 0.3, 0.002)
    pulses = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * rate * t + rng.uniform(0, 6))) * rough
    noise = fft_filter(rng.standard_normal(n), lo=200, hi=2200) * 0.5
    y = (v + noise * np.max(np.abs(v))) * pulses * envelope(n, 0.08, 0.3)
    return reverb(drive(y / (np.max(np.abs(y)) or 1), 1.8), 0.15, 0.9, 0.25, 3000)


def yelp(i):
    n = int((0.28 + 0.06 * i) * SR)
    t = np.arange(n) / SR
    f0 = 980 - 520 * (t / t[-1]) ** 0.7
    v = harmonic_voice(f0, [(1200, 400, 1.0), (2600, 500, 0.4)], 0.05)
    return reverb(v * envelope(n, 0.01, 0.12), 0.18, 0.9, 0.3, 4000)


def whimper(i):
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    f0 = 720 - 380 * (t / t[-1]) + 30 * np.sin(2 * np.pi * 9 * t)
    v = harmonic_voice(f0, [(900, 300, 1.0), (2000, 400, 0.3)], 0.12)
    return reverb(v * envelope(n, 0.05, 0.9), 0.25, 1.2, 0.4, 3500)


def leopard_roar(i):
    """The leopard's call: a rasping saw — breathy grunts in a slowing series."""
    parts = []
    gap = 0.16
    for k in range(7 + i):
        dur = 0.2 + 0.03 * k
        n = int(dur * SR)
        t = np.arange(n) / SR
        f0 = (95 - 3 * k) * (1 + 0.1 * np.sin(2 * np.pi * 30 * t))
        v = harmonic_voice(f0, [(380, 140, 1.0), (850, 250, 0.7), (1700, 350, 0.3)], 0.6, 0.004)
        v = drive(v / (np.max(np.abs(v)) or 1), 2.5) * envelope(n, 0.03, 0.12) * (1 - k * 0.07)
        parts.append(v)
        parts.append(np.zeros(int((gap + 0.02 * k) * SR)))
    return reverb(np.concatenate(parts), 0.3, 1.8, 0.6, 3000)


def hiss(i):
    n = int((0.6 + 0.2 * i) * SR)
    x = fft_filter(rng.standard_normal(n), lo=2500, hi=9000) * envelope(n, 0.02, 0.35)
    return reverb(x, 0.15, 0.6, 0.2, 7000)


ANIMALS = {
    "wolf": {
        "howl": [lambda i=i: wolf_howl(i) for i in range(3)],
        "growl": [lambda i=i: growl(1.2 + 0.3 * i, 85 + 10 * i, 70, 22 + 4 * i) for i in range(3)],
        "snarl": [lambda i=i: growl(0.55, 210 + 30 * i, 170, 34, 0.9) for i in range(3)],
        "yelp": [lambda i=i: yelp(i) for i in range(3)],
        "death": [lambda i=i: whimper(i) for i in range(2)],
    },
    "leopard": {
        "roar": [lambda i=i: leopard_roar(i) for i in range(2)],
        "growl": [lambda i=i: growl(1.6 + 0.4 * i, 62 + 8 * i, 52, 18 + 3 * i, 0.8) for i in range(3)],
        "snarl": [lambda i=i: growl(0.7, 150 + 20 * i, 120, 30, 1.0) for i in range(3)],
        "hiss": [lambda i=i: hiss(i) for i in range(2)],
        "death": [lambda i=i: growl(2.2, 90, 40, 12, 0.5) for i in range(1)],
    },
}
# What an animal "says" for each game event
ANIMAL_EVENTS = {
    "wolf": {"spot": "growl", "warn": "growl", "suspicious": "growl", "attack": "snarl", "hurt": "yelp", "death": "death",
             "call_help": "howl", "idle": "howl", "flee": "yelp", "victory": "howl", "search": "growl"},
    "leopard": {"spot": "growl", "warn": "growl", "attack": "snarl", "hurt": "hiss", "death": "death", "phase": "roar",
                "idle": "roar", "taunt": "growl", "victory": "roar"},
}


# --- Speech --------------------------------------------------------------------------------

def protagonist_name():
    """The spoken name comes from the translation table; lines keep the {PROTAGONIST} token."""
    import csv
    with open(os.path.join(ROOT, "localization", "strings.csv"), encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row["keys"] == "PROTAGONIST_NAME":
                return row["tr"]
    raise SystemExit("PROTAGONIST_NAME missing from localization/strings.csv")


_STRINGS = None


def strings():
    """localization/strings.csv as {key: text} (lines may come by key)."""
    global _STRINGS
    if _STRINGS is None:
        with open(os.path.join(ROOT, "localization", "strings.csv"), encoding="utf-8") as f:
            _STRINGS = {row["keys"]: row["tr"] for row in csv.DictReader(f)}
    return _STRINGS


def spoken_text(text):
    """What the voice says: real names for every token (the voice knows them all)."""
    text = text.replace("{PROTAGONIST}", protagonist_name())
    for key, value in strings().items():
        if key.startswith("NPC_") and key.endswith("_NAME"):
            text = text.replace("{NPC:%s}" % key[4:-5].lower(), value)
    return text.replace("(…)", "…")


async def tts(text, prof, path):
    text = spoken_text(text)
    c = edge_tts.Communicate(text, prof["voice"], rate=prof["rate"], pitch=prof["pitch"])
    await c.save(path)


def decode(path):
    d = miniaudio.decode_file(path, output_format=miniaudio.SampleFormat.SIGNED16, nchannels=1, sample_rate=SR)
    return np.frombuffer(d.samples, dtype=np.int16).astype(np.float64) / 32768.0


def main():
    cfg = json.load(open(DATA, encoding="utf-8"))
    only = set(sys.argv[1:])
    cache = json.load(open(CACHE, encoding="utf-8")) if os.path.exists(CACHE) else {}
    manifest = {"enemies": cfg["enemies"], "profiles": {}}
    tmp = os.path.join(OUT, "_tmp.mp3")
    os.makedirs(OUT, exist_ok=True)
    for pname, prof in cfg["profiles"].items():
        events = {}
        if "synth" in prof:
            kind = prof["synth"]
            files = {}
            for sound, makers in ANIMALS[kind].items():
                files[sound] = []
                for i, make in enumerate(makers):
                    rel = f"{pname}/{sound}_{i}.wav"
                    path = os.path.join(OUT, rel)
                    if not os.path.exists(path) or (only and pname in only):
                        save_wav(path, make(), 0.85)
                    files[sound].append({"file": "res://assets/audio/voice/" + rel, "text": ""})
            for ev, sound in ANIMAL_EVENTS[kind].items():
                events[ev] = files[sound]
            manifest["profiles"][pname] = events
            print(f"{pname}: synthesised {sum(len(v) for v in files.values())} cries")
            continue
        lines = cfg["lines"][prof["lines"]]
        made = 0
        for ev, texts in lines.items():
            events[ev] = []
            for i, entry in enumerate(texts):
                # A line is plain text, or {key, if}: the text from strings.csv, a condition to play
                extra = {}
                if isinstance(entry, dict):
                    text = strings()[entry["key"]]
                    extra = {k: entry[k] for k in ("key", "if") if k in entry}
                else:
                    text = entry
                rel = f"{pname}/{ev}_{i}.wav"
                path = os.path.join(OUT, rel)
                spoken = spoken_text(text)   # a new name re-synthesises
                key = hashlib.sha1(json.dumps([spoken, prof], sort_keys=True).encode()).hexdigest()
                if cache.get(rel) != key or not os.path.exists(path) or (only and pname in only):
                    for attempt in range(3):
                        try:
                            asyncio.run(tts(text, prof, tmp))
                            break
                        except Exception as e:
                            print("  retry", rel, e)
                    x = trim(decode(tmp))
                    x = fx(x, prof["fx"])
                    x = trim(x, 0.004, 0.02)
                    save_wav(path, x, 0.92)
                    cache[rel] = key
                    made += 1
                events[ev].append(dict({"file": "res://assets/audio/voice/" + rel, "text": text}, **extra))
        manifest["profiles"][pname] = events
        print(f"{pname}: {sum(len(v) for v in events.values())} lines ({made} new)")
        json.dump(cache, open(CACHE, "w", encoding="utf-8"), indent=0)
    if os.path.exists(tmp):
        os.remove(tmp)
    json.dump(manifest, open(MANIFEST, "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent="\t")
    print("manifest:", MANIFEST)


if __name__ == "__main__":
    main()
