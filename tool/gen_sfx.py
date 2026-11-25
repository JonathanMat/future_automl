"""Synthesizes the spell and emote sound effects in assets/sounds/.

Every sound is generated from noise and oscillators, so there are no
licensing questions. Tweak a function and re-run:

    python tool/gen_sfx.py

Needs numpy and scipy. Output: 44.1 kHz, mono, 16-bit WAV.
"""

from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, sosfiltfilt

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(7)


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def brown(dur):
    b = np.cumsum(noise(dur))
    b -= np.convolve(b, np.ones(2000) / 2000, mode="same")  # remove drift
    return b / (np.max(np.abs(b)) + 1e-9)


def lp(x, f, order=4):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), x)


def hp(x, f, order=4):
    return sosfilt(butter(order, f, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=3):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def sweep_bp(x, f_from, f_to, width=0.6, steps=48):
    """Band-pass whose centre glides from f_from to f_to (log), in blocks."""
    out = np.zeros_like(x)
    n = len(x)
    edges = np.linspace(0, n, steps + 1).astype(int)
    win = np.hanning(2 * (edges[1] - edges[0]) + 2)
    for i in range(steps):
        a, b = edges[i], edges[i + 1]
        f = f_from * (f_to / f_from) ** (i / max(1, steps - 1))
        lo, hi = f * (1 - width / 2), min(f * (1 + width / 2), SR / 2 - 100)
        # Filter a padded window, overlap-add with a Hann window.
        pa, pb = max(0, a - (b - a)), min(n, b + (b - a))
        seg = sosfiltfilt(butter(2, [lo, hi], "band", fs=SR, output="sos"), x[pa:pb])
        w = np.hanning(pb - pa)
        out[pa:pb] += seg * w * 0.5
    return out


def env_adsr(n, a, d, s_level, r, dur):
    """Attack/decay/sustain/release envelope, times in seconds."""
    t = np.arange(n) / SR
    e = np.ones(n) * s_level
    e[t < a] = t[t < a] / max(a, 1e-6)
    m = (t >= a) & (t < a + d)
    e[m] = 1 - (1 - s_level) * (t[m] - a) / max(d, 1e-6)
    rel = t > dur - r
    e[rel] *= np.clip((dur - t[rel]) / max(r, 1e-6), 0, 1)
    return e


def exp_decay(n, tau, delay=0.0):
    t = np.arange(n) / SR - delay
    e = np.exp(-np.clip(t, 0, None) / tau)
    e[t < 0] = 0
    return e


def fade(x, fin=0.005, fout=0.04):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[n - b :] *= np.linspace(1, 0, b)
    return x


def crackles(dur, rate, lo=1500, hi=7000, decay=0.002, amp_jitter=True):
    """Random short clicks, like burning wood or cracking ice."""
    n = int(dur * SR)
    x = np.zeros(n)
    count = int(dur * rate)
    for pos in rng.integers(0, n, count):
        ln = int(rng.uniform(0.6, 2.5) * decay * SR)
        ln = min(ln, n - pos)
        if ln <= 4:
            continue
        burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 4))
        x[pos : pos + ln] += burst * (rng.uniform(0.2, 1) if amp_jitter else 1)
    return bp(x, lo, hi)


def partials(dur, freqs, taus, amps=None, detune=0.0):
    """Sum of decaying sines (bells, glass, metal)."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    amps = amps or [1] * len(freqs)
    for f, tau, a in zip(freqs, taus, amps):
        f2 = f * (1 + rng.uniform(-detune, detune))
        out += a * np.sin(2 * np.pi * f2 * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    return out


def place(dst, src, at):
    i = int(at * SR)
    j = min(len(dst), i + len(src))
    dst[i:j] += src[: j - i]
    return dst


def norm(x, peak=0.89):
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def save(name, x, peak=0.89):
    x = fade(norm(np.asarray(x, dtype=np.float64), peak))
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print(f"{name}.wav  {len(x) / SR:.2f}s")


# ---------------------------------------------------------------------------
# Fire
# ---------------------------------------------------------------------------


def fire_cast():
    """Flames swirl into the hand, then the fireball whooshes away (~0.7 s)."""
    dur = 0.75
    n = int(dur * SR)
    roar = sweep_bp(noise(dur), 260, 1400, width=0.9)
    roar *= env_adsr(n, 0.18, 0.2, 0.75, 0.3, dur)
    body = lp(brown(dur), 300) * env_adsr(n, 0.12, 0.2, 0.6, 0.3, dur)
    crack = crackles(dur, 90, 1800, 6500, 0.0015) * env_adsr(n, 0.05, 0.3, 0.5, 0.2, dur)
    return 1.0 * norm(roar) + 0.6 * norm(body) + 0.35 * norm(crack)


def fire_explode():
    """Deep boom with a burst of crackling flame (~1.3 s)."""
    dur = 1.4
    n = int(dur * SR)
    t = t_axis(dur)
    # Sub thump: pitch drops from 120 Hz to 38 Hz.
    f = 38 + 82 * np.exp(-t / 0.09)
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * exp_decay(n, 0.28)
    blast = lp(noise(dur), 1800) * exp_decay(n, 0.22)
    rumble = lp(brown(dur), 160) * exp_decay(n, 0.55)
    attack = hp(noise(0.03), 2000) * np.linspace(1, 0, int(0.03 * SR))
    flames = crackles(dur, 160, 1200, 6000, 0.002) * exp_decay(n, 0.45, 0.04)
    out = 1.0 * norm(thump) + 0.8 * norm(blast) + 0.6 * norm(rumble)
    out += 0.3 * norm(flames)
    place(out, 0.7 * norm(attack), 0)
    return np.tanh(out * 1.4)


# ---------------------------------------------------------------------------
# Ice
# ---------------------------------------------------------------------------


def ice_cast():
    """Frosty shimmer that flies across (~0.6 s)."""
    dur = 0.65
    n = int(dur * SR)
    air = sweep_bp(noise(dur), 2500, 7000, width=0.8) * env_adsr(n, 0.08, 0.2, 0.7, 0.3, dur)
    t = t_axis(dur)
    shimmer = np.zeros(n)
    for k, f in enumerate([1760, 2349, 2637, 3136, 3520, 4186]):
        trem = 0.5 + 0.5 * np.sin(2 * np.pi * (9 + 3 * k) * t + k)
        shimmer += np.sin(2 * np.pi * f * t) * trem
    shimmer *= env_adsr(n, 0.12, 0.25, 0.5, 0.25, dur)
    tinkle = crackles(dur, 40, 4000, 10000, 0.003)
    return 0.8 * norm(air) + 0.45 * norm(shimmer) + 0.3 * norm(tinkle)


def ice_freeze():
    """Thud on impact, then frost creaks and crackles over the camera (~0.9 s)."""
    dur = 0.95
    n = int(dur * SR)
    t = t_axis(dur)
    f = 70 + 150 * np.exp(-t / 0.05)
    thud = np.sin(2 * np.pi * np.cumsum(f) / SR) * exp_decay(n, 0.12)
    crunch = bp(noise(dur), 1200, 5000) * exp_decay(n, 0.08)
    frost = crackles(dur, 260, 2500, 9000, 0.0012) * env_adsr(n, 0.05, 0.3, 0.6, 0.35, dur)
    # Creak: a narrow, slightly wobbling resonance.
    creak = bp(noise(dur), 900, 1100, order=2) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * t))
    creak *= env_adsr(n, 0.2, 0.3, 0.4, 0.3, dur)
    return 1.0 * norm(thud) + 0.6 * norm(crunch) + 0.6 * norm(frost) + 0.25 * norm(creak)


def glass_shatter(dur=1.0, pieces=26, low=1800, high=7500):
    n = int(dur * SR)
    out = np.zeros(n)
    snap = hp(noise(0.04), 1500) * np.exp(-np.arange(int(0.04 * SR)) / (0.008 * SR))
    place(out, 1.4 * snap, 0)
    for _ in range(pieces):
        at = abs(rng.normal(0, 0.12)) + rng.uniform(0, 0.25)
        f0 = rng.uniform(low, high)
        ratios = [1, 1.47 + rng.uniform(-0.1, 0.1), 2.09, 2.83]
        p = partials(
            0.35,
            [f0 * r for r in ratios if f0 * r < SR / 2 - 500],
            [rng.uniform(0.03, 0.12)] * 4,
            [1, 0.6, 0.4, 0.25],
        )
        place(out, p * rng.uniform(0.2, 0.7), at)
    sizzle = crackles(dur, 220, 3000, 11000, 0.0015) * exp_decay(n, 0.25)
    return out + 0.4 * norm(sizzle) * np.max(np.abs(out))


def ice_shatter():
    """The frozen camera cracks and breaks into falling shards (~1 s)."""
    return glass_shatter()


# ---------------------------------------------------------------------------
# Lightning
# ---------------------------------------------------------------------------


def lightning_strike():
    """Static buzz building up (0.3 s), then a sharp crack and thunder (~1.8 s).

    The crack lands at 0.3 s, when the bolt hits.
    """
    pre = 0.3
    dur = 1.9
    n = int(dur * SR)
    t = t_axis(dur)
    out = np.zeros(n)

    # Build-up: electric buzz (saw-ish 120 Hz harmonics) + sparks.
    bn = int(pre * SR)
    tb = t[:bn]
    buzz = sum(np.sin(2 * np.pi * 120 * k * tb) / k for k in range(1, 18))
    buzz = bp(buzz * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 31 * tb))), 200, 4000)
    buzz *= (tb / pre) ** 2
    sparks = crackles(pre, 220, 2000, 9000, 0.0008) * (tb / pre)
    out[:bn] += 0.35 * norm(buzz) + 0.35 * norm(sparks)

    # The crack: a very short, loud, bright transient with a few echoes.
    for k, (dt, a) in enumerate([(0, 1), (0.018, 0.6), (0.045, 0.45), (0.09, 0.25)]):
        ln = int(0.05 * SR)
        c = hp(noise(0.05), 1200) * np.exp(-np.arange(ln) / (0.006 * SR))
        place(out, a * 2.2 * c, pre + dt)

    # Thunder: low rolling rumble with slow amplitude swells.
    tn = n - bn
    tt = np.arange(tn) / SR
    rumble = lp(brown(tn / SR), 220) + 0.5 * lp(noise(tn / SR), 500)
    swell = 0.6 + 0.4 * np.sin(2 * np.pi * 2.3 * tt + 1) * np.sin(2 * np.pi * 0.9 * tt)
    rumble = norm(rumble) * swell * exp_decay(tn, 0.55) * np.clip(tt / 0.04, 0, 1)
    out[bn:] += 0.9 * rumble

    # Zap tail: a quickly falling tone.
    zn = int(0.25 * SR)
    zf = 2400 * np.exp(-np.arange(zn) / SR / 0.05) + 200
    zap = np.sign(np.sin(2 * np.pi * np.cumsum(zf) / SR)) * exp_decay(zn, 0.06)
    place(out, 0.25 * lp(zap, 6000), pre)
    return np.tanh(out * 1.3)


def lightning_zap():
    """Short electric discharge, for lightning clashes (~0.5 s)."""
    dur = 0.55
    n = int(dur * SR)
    t = t_axis(dur)
    f = 90 + 40 * np.sin(2 * np.pi * 7 * t)
    buzz = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR))
    buzz = bp(buzz, 150, 5000) * env_adsr(n, 0.03, 0.2, 0.6, 0.25, dur)
    sparks = crackles(dur, 300, 2000, 10000, 0.0008) * env_adsr(n, 0.01, 0.2, 0.7, 0.2, dur)
    return 0.7 * norm(buzz) + 0.6 * norm(sparks)


# ---------------------------------------------------------------------------
# Shield
# ---------------------------------------------------------------------------


def shield_up():
    """The dome rises: a warm, rising magic hum with shimmer (~0.8 s)."""
    dur = 0.85
    n = int(dur * SR)
    t = t_axis(dur)
    rise = 1 + 0.5 * (1 - np.exp(-t / 0.15))
    out = np.zeros(n)
    for f, a in [(220, 1), (330, 0.6), (440, 0.5), (660, 0.3), (880, 0.2)]:
        ph = 2 * np.pi * np.cumsum(f * rise * (1 + 0.004 * np.sin(2 * np.pi * 5 * t))) / SR
        out += a * np.sin(ph)
    out *= env_adsr(n, 0.12, 0.2, 0.7, 0.4, dur)
    whoosh = sweep_bp(noise(dur), 400, 3000, width=0.7) * env_adsr(n, 0.15, 0.15, 0.3, 0.4, dur)
    sparkle = partials(dur, [2637, 3520, 4699], [0.25, 0.2, 0.15], [0.6, 0.4, 0.3])
    return 0.8 * norm(out) + 0.4 * norm(whoosh) + 0.25 * norm(place(np.zeros(n), sparkle, 0.08))


def metal_clang(dur, base, tau=0.35):
    ratios = [1, 2.76, 5.40, 8.93, 13.3]
    p = partials(dur, [base * r for r in ratios], [tau, tau * 0.7, tau * 0.5, tau * 0.35, tau * 0.25],
                 [1, 0.7, 0.5, 0.3, 0.2], detune=0.01)
    n = len(p)
    hit = bp(noise(dur), 1000, 6000) * exp_decay(n, 0.015)
    return norm(p) + 0.6 * norm(hit)


def shield_block():
    """A spell slams into the shield: bright magic clang (~0.9 s)."""
    dur = 0.9
    n = int(dur * SR)
    clang = metal_clang(dur, 420)
    t = t_axis(dur)
    ring = np.sin(2 * np.pi * 1320 * t) * np.exp(-t / 0.4) * (0.7 + 0.3 * np.sin(2 * np.pi * 6 * t))
    thump = lp(noise(dur), 300) * exp_decay(n, 0.06)
    return np.tanh(1.2 * (0.9 * clang + 0.35 * norm(ring) + 0.5 * norm(thump)))


def shield_break():
    """Lightning smashes the shield: clang that breaks into glass (~1.1 s)."""
    dur = 1.1
    n = int(dur * SR)
    clang = metal_clang(dur, 300, tau=0.15)
    glass = glass_shatter(dur, pieces=34, low=1200, high=6500)
    out = 0.7 * norm(clang) + 0.9 * norm(glass)
    out += 0.5 * norm(lp(noise(dur), 250) * exp_decay(n, 0.1))
    return np.tanh(out * 1.2)


def shield_bash():
    """The dome pulses and a shockwave whumps into the other camera.

    Pulse at 0 s, the hit lands at 0.32 s (~0.9 s).
    """
    dur = 0.95
    n = int(dur * SR)
    t = t_axis(dur)
    out = np.zeros(n)
    # Pulse: short bright "vwoom".
    pn = int(0.3 * SR)
    tp = t[:pn]
    pulse = np.sin(2 * np.pi * np.cumsum(180 + 500 * tp / 0.3) / SR) * np.sin(np.pi * tp / 0.3)
    out[:pn] += 0.5 * pulse
    out += 0.5 * norm(sweep_bp(noise(dur), 300, 2500, width=0.8)) * env_adsr(n, 0.25, 0.07, 0.0, 0.0, dur)
    # Hit: low whump.
    hn = n - int(0.32 * SR)
    th = np.arange(hn) / SR
    f = 50 + 110 * np.exp(-th / 0.06)
    whump = np.sin(2 * np.pi * np.cumsum(f) / SR) * exp_decay(hn, 0.18)
    hit = lp(noise(hn / SR), 1200) * exp_decay(hn, 0.07)
    place(out, 1.0 * norm(whump) + 0.5 * norm(hit), 0.32)
    return np.tanh(out * 1.3)


def shield_double():
    """Two domes pulse against each other: two hums that beat (~1 s)."""
    dur = 1.1
    a = shield_up()
    b = shield_up()
    n = int(dur * SR)
    out = np.zeros(n)
    place(out, a, 0)
    place(out, 0.8 * b, 0.02)
    place(out, 0.6 * metal_clang(0.6, 560, tau=0.2), 0.5)
    return out


# ---------------------------------------------------------------------------
# Clash (same spell on both sides)
# ---------------------------------------------------------------------------


def clash_struggle():
    """Two spells grinding against each other (~0.8 s)."""
    dur = 0.8
    n = int(dur * SR)
    t = t_axis(dur)
    grind = bp(noise(dur), 300, 2500) * (0.6 + 0.4 * np.sin(2 * np.pi * (14 + 18 * t) * t))
    grind *= np.clip(t / 0.1, 0, 1) * (0.6 + 0.4 * t / dur)
    hum = np.sin(2 * np.pi * np.cumsum(80 + 60 * t / dur) / SR) * (0.4 + 0.6 * t / dur)
    return 0.8 * norm(grind) + 0.5 * norm(hum)


# ---------------------------------------------------------------------------
# Emotes
# ---------------------------------------------------------------------------

VOWELS = {
    # (F1, F2, F3) in Hz, cartoon-ish (a bit higher than an adult voice).
    "a": (900, 1300, 2900),
    "o": (550, 900, 2700),
    "u": (380, 800, 2500),
    "e": (550, 1900, 2800),
}


def resonator(x, f, bw):
    """Two-pole resonance at f with bandwidth bw."""
    from scipy.signal import lfilter

    r = np.exp(-np.pi * bw / SR)
    a = [1, -2 * r * np.cos(2 * np.pi * f / SR), r * r]
    return lfilter([1 - r], a, x)


def voice(f0, vowel_at, breath=0.08, blocks=40):
    """A cartoon voice: a pulse train at pitch f0 (array, Hz per sample),
    shaped by the formants vowel_at(0..1) returns. Processed in overlapping
    blocks so the vowel can glide."""
    n = len(f0)
    phase = np.cumsum(f0) / SR
    # Glottal-ish pulse: a sharp, rounded saw.
    src = 2 * (phase % 1) - 1
    src = np.sign(src) * np.abs(src) ** 3 + breath * rng.standard_normal(n)
    src = np.diff(src, prepend=0)  # brighter, like a real glottal pulse
    out = np.zeros(n)
    edges = np.linspace(0, n, blocks + 1).astype(int)
    hop = edges[1] - edges[0]
    for i in range(blocks):
        a, b = max(0, edges[i] - hop), min(n, edges[i + 1] + hop)
        f1, f2, f3 = vowel_at((edges[i] + hop / 2) / n)
        seg = src[a:b]
        y = resonator(seg, f1, 90) + 0.6 * resonator(seg, f2, 120) + 0.25 * resonator(seg, f3, 180)
        out[a:b] += y * np.hanning(b - a)
    return out


def mix_vowel(v1, v2, k):
    return tuple(a + (b - a) * k for a, b in zip(VOWELS[v1], VOWELS[v2]))


def tone(dur, f, tau, harmonics=((1, 1), (2, 0.35), (3, 0.12)), attack=0.004):
    """Bell / marimba-like note."""
    t = t_axis(dur)
    out = sum(a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * k / tau) for k, a in harmonics)
    return out * np.clip(t / attack, 0, 1)


def emote_send():
    """Soft pop when you send an emote (~0.12 s)."""
    dur = 0.14
    t = t_axis(dur)
    f = 380 + 900 * (t / dur) ** 0.6
    pop = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.035) * np.clip(t / 0.003, 0, 1)
    return pop


def emote_hallo():
    """Cheerful 'hi-hey' chime: two rising marimba notes and a sparkle (~0.6 s)."""
    dur = 0.65
    out = np.zeros(int(dur * SR))
    place(out, tone(0.5, 784, 0.12), 0)  # G5
    place(out, tone(0.5, 1175, 0.16), 0.11)  # D6
    place(out, 0.35 * tone(0.4, 2349, 0.08, ((1, 1),)), 0.2)
    voice_hey = voice(
        np.linspace(520, 640, int(0.2 * SR)),
        lambda k: mix_vowel("e", "e", k),
        breath=0.15,
    ) * np.sin(np.pi * np.linspace(0, 1, int(0.2 * SR))) ** 0.5
    place(out, 0.5 * norm(voice_hey), 0.1)
    return out


def emote_haha():
    """Cartoon 'ha-ha-ha-ha', getting lower (~0.75 s)."""
    syll, gap = 0.11, 0.155
    count = 4
    out = np.zeros(int((gap * count + 0.12) * SR))
    for i in range(count):
        n = int(syll * SR)
        t = np.arange(n) / SR
        f0 = (470 - 35 * i) * (1 + 0.06 * np.exp(-t / 0.03))
        v = voice(f0 * np.ones(n), lambda k: VOWELS["a"], breath=0.12, blocks=6)
        env = np.clip(t / 0.012, 0, 1) * np.exp(-t / 0.06)
        h = bp(noise(0.03), 900, 4000) * np.hanning(int(0.03 * SR))
        place(out, 0.25 * norm(h), gap * i)
        place(out, norm(v) * env * (1 - 0.1 * i), gap * i + 0.02)
    return out


def emote_boos():
    """Grumpy growl 'grrr' with a stomp (~0.7 s)."""
    dur = 0.7
    n = int(dur * SR)
    t = t_axis(dur)
    f0 = 135 + 15 * np.sin(2 * np.pi * 3 * t) + 8 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    v = voice(f0, lambda k: mix_vowel("o", "u", k), breath=0.3)
    rough = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 28 * t))
    v = norm(v) * lp(rough, 400) * env_adsr(n, 0.03, 0.1, 0.85, 0.2, dur)
    f = 60 + 90 * np.exp(-t / 0.04)
    stomp = np.sin(2 * np.pi * np.cumsum(f) / SR) * exp_decay(n, 0.09)
    return np.tanh(1.6 * (0.9 * v + 0.7 * norm(stomp)))


def emote_huilen():
    """Wailing 'waaaah' with a wobble, dropping in pitch (~1 s)."""
    dur = 1.0
    n = int(dur * SR)
    t = t_axis(dur)
    f0 = (560 - 170 * (t / dur) ** 1.4) * (1 + 0.045 * np.sin(2 * np.pi * 7 * t))
    v = voice(f0, lambda k: mix_vowel("u", "a", min(1, k * 4)) if k < 0.6 else mix_vowel("a", "u", (k - 0.6) / 0.4), breath=0.1)
    v = norm(v) * env_adsr(n, 0.08, 0.2, 0.8, 0.3, dur)
    return v


def emote_gg():
    """Little victory fanfare: C-E-G-C arpeggio into a chord (~0.9 s)."""
    dur = 0.95
    out = np.zeros(int(dur * SR))

    def brass(d, f):
        tt = t_axis(d)
        saw = sum(np.sin(2 * np.pi * f * k * tt) / k for k in range(1, 12))
        return lp(saw, 2600) * env_adsr(len(tt), 0.015, 0.08, 0.6, 0.08, d)

    for i, f in enumerate([523, 659, 784]):
        place(out, brass(0.12, f), 0.09 * i)
    for f in [523, 659, 784, 1047]:
        place(out, 0.5 * brass(0.6, f), 0.27)
    place(out, 0.4 * tone(0.5, 2093, 0.15, ((1, 1),)), 0.27)
    return out


def emote_goed():
    """Short applause with a bright 'ding' (~1 s)."""
    dur = 1.0
    n = int(dur * SR)
    out = np.zeros(n)
    for _ in range(70):
        at = rng.uniform(0, 0.75)
        ln = int(0.03 * SR)
        clap = bp(noise(0.03), rng.uniform(800, 1400), rng.uniform(2500, 4500)) * np.exp(-np.arange(ln) / (0.006 * SR))
        place(out, clap * rng.uniform(0.3, 1), at)
    out = norm(out) * env_adsr(n, 0.05, 0.3, 0.7, 0.35, dur)
    place(out, 0.7 * norm(tone(0.7, 1568, 0.25)), 0.0)
    place(out, 0.5 * norm(tone(0.6, 2093, 0.2)), 0.08)
    return out


# ---------------------------------------------------------------------------
# End of a game
# ---------------------------------------------------------------------------

# Note starts, shared with the result screen animation
# (lib/widgets/result/result_hero.dart): keep them in sync.
WIN_NOTES = (0.0, 0.14, 0.28)
LOSE_NOTES = (0.0, 0.42, 0.84)


def brass_note(dur, f, bright=3200, vibrato=0.0, slide=0.0, wah=False):
    """A brass-like note: a saw through a lowpass that opens with the
    attack. slide: semitones to bend down over the note. wah: the filter
    closes again at the end, like a muted trombone."""
    n = int(dur * SR)
    t = t_axis(dur)
    bend = 2 ** (-slide * np.clip((t - 0.25 * dur) / (0.75 * dur), 0, 1) / 12)
    vib = 1 + vibrato * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    freq = f * bend * vib
    phase = np.cumsum(freq) / SR
    saw = 2 * (phase % 1) - 1
    # Filter in blocks so the cutoff can move.
    out = np.zeros(n)
    blocks = 30
    edges = np.linspace(0, n, blocks + 1).astype(int)
    hop = edges[1] - edges[0]
    for i in range(blocks):
        a, b = max(0, edges[i] - hop), min(n, edges[i + 1] + hop)
        k = (edges[i] + hop / 2) / n
        open_ = min(1, k * dur / 0.05)
        close = 1 - 0.75 * max(0, (k - 0.55) / 0.45) if wah else 1
        cutoff = 250 + bright * open_ * close
        seg = sosfiltfilt(butter(2, min(cutoff, SR / 2 - 200), "low", fs=SR, output="sos"), saw[a:b])
        out[a:b] += seg * np.hanning(b - a)
    return out * env_adsr(n, 0.02, 0.08, 0.8, min(0.12, dur * 0.4), dur)


def result_win():
    """'De-de-duuu!': three quick rising brass notes into a bright chord,
    with a sparkle on top (~1.4 s)."""
    dur = 1.45
    out = np.zeros(int(dur * SR))
    c5, e5, g5, c6 = 523.25, 659.25, 783.99, 1046.5
    place(out, brass_note(0.13, g5), WIN_NOTES[0])
    place(out, brass_note(0.13, g5), WIN_NOTES[1])
    for f, a in [(c6, 1), (g5, 0.6), (e5, 0.5), (c5, 0.45)]:
        place(out, a * brass_note(1.0, f, vibrato=0.006), WIN_NOTES[2])
    # Sparkle: quick rising bells after the last note.
    for i, f in enumerate([2093, 2637, 3136, 4186]):
        place(out, 0.22 * tone(0.5, f, 0.12, ((1, 1),)), WIN_NOTES[2] + 0.05 + 0.05 * i)
    # Cymbal-ish shimmer.
    shimmer = hp(noise(1.0), 6000) * exp_decay(int(1.0 * SR), 0.35)
    place(out, 0.18 * norm(shimmer), WIN_NOTES[2])
    return out


def result_lose():
    """'Duh, duh, duuuuh': a sad trombone. Two short notes going down and a
    long last one that sags and wobbles (~2.1 s)."""
    dur = 2.15
    out = np.zeros(int(dur * SR))
    # D4, C#4, C4 (low and a bit muffled).
    d4, cs4, c4 = 293.66 / 2, 277.18 / 2, 261.63 / 2
    place(out, brass_note(0.34, d4, bright=1400, wah=True), LOSE_NOTES[0])
    place(out, brass_note(0.34, cs4, bright=1400, wah=True), LOSE_NOTES[1])
    place(out, brass_note(1.25, c4, bright=1300, vibrato=0.025, slide=1.5, wah=True), LOSE_NOTES[2])
    return out


SOUNDS = {
    "fire_cast": fire_cast,
    "fire_explode": fire_explode,
    "ice_cast": ice_cast,
    "ice_freeze": ice_freeze,
    "ice_shatter": ice_shatter,
    "lightning_strike": lightning_strike,
    "lightning_zap": lightning_zap,
    "shield_up": shield_up,
    "shield_block": shield_block,
    "shield_break": shield_break,
    "shield_bash": shield_bash,
    "shield_double": shield_double,
    "clash_struggle": clash_struggle,
    "emote_send": emote_send,
    "emote_hallo": emote_hallo,
    "emote_haha": emote_haha,
    "emote_boos": emote_boos,
    "emote_huilen": emote_huilen,
    "emote_gg": emote_gg,
    "emote_goed": emote_goed,
    "result_win": result_win,
    "result_lose": result_lose,
}

if __name__ == "__main__":
    for name, fn in SOUNDS.items():
        save(name, fn())
