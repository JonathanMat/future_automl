"""Synthesizes the spell, emote, result and badge sound effects in assets/sounds/.

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
    if i >= len(dst):
        return dst
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


def room(x, decay=0.8, wet=0.3, bright=7000, tail=0.3):
    """A simple reverb, so a sound sits in a space instead of in your ear:
    x convolved with decaying noise (highs die faster). No discrete early
    reflections: those comb-filter the sound and make it metallic. The
    result is `tail` seconds longer than x."""
    from scipy.signal import fftconvolve

    x = np.concatenate([x, np.zeros(int(tail * SR))])
    n = int(decay * SR)
    t = np.arange(n) / SR
    ir = lp(rng.standard_normal(n), bright) * np.exp(-t * 6.9 / decay)
    ir += 0.4 * hp(rng.standard_normal(n), bright) * np.exp(-t * 6.9 / (0.35 * decay))
    ir[: int(0.008 * SR)] = 0  # pre-delay
    ir /= np.sqrt(np.sum(ir**2))
    w = fftconvolve(x, ir)[: len(x)]
    w *= np.sqrt(np.mean(x**2) / (np.mean(w**2) + 1e-12))
    return (1 - wet) * x + wet * w


def n_wave(d):
    """One shock wave: a jump up, a straight fall to below zero, a jump
    back. The building block of thunder and of every sharp crack."""
    return np.linspace(1, -1, max(3, int(d * SR)))


def pulse_train(dur, times, amps, durs):
    out = np.zeros(int(dur * SR))
    for at, a, d in zip(times, amps, durs):
        if 0 <= at < dur:
            place(out, a * n_wave(d), at)
    return out


def modes(freqs, taus, amps, excite=0.0008):
    """Something struck: a short noise tap rings a few resonances (its
    modes), each dying away at its own speed."""
    dur = min(0.6, 5 * max(taus))
    n = int(dur * SR)
    ex = np.zeros(n)
    ln = max(2, int(excite * SR))
    ex[:ln] = rng.standard_normal(ln) * np.hanning(ln)
    out = np.zeros(n)
    for f, tau, a in zip(freqs, taus, amps):
        if f >= SR / 2 - 500:
            continue
        y = resonator(ex, f, 1 / (np.pi * tau))
        out += a * y / (np.max(np.abs(y)) + 1e-12)
    return out


def ice_tink(f0, tau=0.05):
    """A small piece of ice ringing: a few inharmonic modes."""
    ratios = [1, 1.62 * rng.uniform(0.97, 1.03), 2.31 * rng.uniform(0.97, 1.03), 3.17 * rng.uniform(0.97, 1.03)]
    return modes([f0 * r for r in ratios], [tau, tau * 0.7, tau * 0.5, tau * 0.35], [1, 0.7, 0.45, 0.3], excite=0.0005)


def ice_crack(size=0.0):
    """A brittle snap. size 0 is a tiny crackle (ice cubes in a drink),
    1 a big crack running through a sheet of ice."""
    f = (4800 - 3900 * size) * rng.uniform(0.8, 1.25)
    body = modes([f, f * 1.43, f * 2.07], [0.004 + 0.03 * size, 0.003 + 0.02 * size, 0.002 + 0.012 * size], [1, 0.6, 0.4], excite=0.0003 + 0.0008 * size)
    ln = int((0.002 + 0.012 * size) * SR)
    snap = hp(rng.standard_normal(ln), 700) * np.exp(-np.arange(ln) / (ln / 5))
    out = np.zeros(max(len(body), ln) + 10)
    place(out, 0.8 * norm(snap), 0)
    place(out, 0.6 * body, 0)
    place(out, 0.9 * n_wave(0.0002 + 0.0008 * size), 0)
    return out


def crackling(dur, rate, size=(0.0, 0.2)):
    """Ice crackling: snaps at random moments. rate(k) is snaps per second
    at k (0..1 through the sound)."""
    out = np.zeros(int(dur * SR))
    t = 0.0
    while True:
        t += rng.exponential(1 / max(1.0, rate(t / dur)))
        if t >= dur:
            return out
        place(out, rng.uniform(0.15, 1) ** 1.5 * ice_crack(rng.uniform(*size)), t)


def ice_creak(dur, f_from=90, f_to=55):
    """Ice under stress: a stick-slip groan, irregular pulses ringing the
    sheet's low modes."""
    out = np.zeros(int(dur * SR))
    t = 0.0
    while t < dur:
        out[int(t * SR)] = rng.uniform(0.5, 1)
        t += 1 / (f_from * (f_to / f_from) ** (t / dur) * rng.uniform(0.8, 1.25))
    y = resonator(out, 700, 60) + 0.6 * resonator(out, 1500, 90) + 0.3 * resonator(out, 2600, 150)
    return norm(y) * np.sin(np.pi * np.arange(len(y)) / len(y)) ** 0.7


def ice_cast():
    """A cold whoosh while ice forms: crackles that speed up, little pieces
    tinkling, then a crisp crack as the shard sets (~0.65 s)."""
    dur = 0.65
    n = int(dur * SR)
    whoosh = sweep_bp(noise(dur), 700, 3200, width=1.1) * env_adsr(n, 0.12, 0.2, 0.7, 0.28, dur)
    body = bp(noise(dur), 250, 900) * env_adsr(n, 0.1, 0.2, 0.5, 0.25, dur)
    form = crackling(0.55, lambda k: 15 + 380 * k**2, size=(0.0, 0.15))
    tinks = np.zeros(n)
    for _ in range(14):
        place(tinks, rng.uniform(0.3, 1) * ice_tink(rng.uniform(2500, 6500), rng.uniform(0.012, 0.035)), 0.05 + 0.45 * rng.random() ** 0.7)
    out = 0.5 * norm(whoosh) + 0.15 * norm(body) + 0.3 * norm(tinks)
    place(out, 0.6 * norm(form), 0)
    place(out, 0.55 * ice_crack(0.35), 0.52)
    for f in (2900, 3900, 5200):
        place(out, 0.2 * ice_tink(f, 0.045), 0.525)
    return room(out, decay=0.6, wet=0.22, bright=3500, tail=0.25)


def ice_freeze():
    """The ice hits, then the camera freezes over: a crunchy impact,
    crackling that rushes out and slows down, a few bigger cracks and a
    groan of stressed ice (~0.95 s)."""
    dur = 0.95
    n = int(dur * SR)
    t = t_axis(dur)
    out = np.zeros(n)
    place(out, 1.0 * norm(ice_crack(1.0)), 0)
    crunch = bp(noise(0.09), 1200, 9000) * exp_decay(int(0.09 * SR), 0.018)
    thud = lp(noise(0.25), 280) * exp_decay(int(0.25 * SR), 0.05)
    place(out, 0.7 * norm(crunch), 0)
    place(out, 0.6 * norm(thud), 0)
    spread = crackling(0.85, lambda k: 450 * np.exp(-3 * k) + 25, size=(0.0, 0.3))
    spread *= np.exp(-np.arange(len(spread)) / (0.3 * SR))  # the ice settles
    place(out, 0.8 * norm(spread), 0.02)
    for at in sorted(rng.uniform(0.08, 0.7, 6)):
        place(out, rng.uniform(0.35, 0.7) * np.exp(-at / 0.4) * norm(ice_crack(rng.uniform(0.45, 0.8))), at)
    place(out, 0.2 * ice_creak(0.3), 0.35)
    grain = lp((rng.random(n) < 0.25).astype(float), 3000)
    frost = hp(noise(dur), 5000) * grain * np.exp(-t / 0.3)
    out += 0.12 * norm(frost)
    return room(out, decay=0.7, wet=0.22, bright=3500, tail=0.3)


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
    """The frozen camera breaks: a big crack, shards flying off and
    bouncing as they land, heavier chunks and fine debris (~1 s)."""
    dur = 1.0
    out = np.zeros(int(dur * SR))
    place(out, 1.2 * norm(ice_crack(1.0)), 0)
    place(out, 0.8 * norm(ice_crack(0.7)), 0.006)
    place(out, 0.7 * norm(crackling(0.12, lambda k: 1500 * (1 - k) + 50, size=(0.1, 0.5))), 0.004)
    shards = np.zeros(len(out))
    for _ in range(40):
        t0 = abs(rng.normal(0, 0.03))
        f0, tau, a = rng.uniform(1800, 7500), rng.uniform(0.012, 0.045), rng.uniform(0.3, 1)
        place(shards, a * ice_tink(f0, tau), t0)
        if rng.random() < 0.6:  # it falls, lands and bounces
            at, gap = t0 + rng.uniform(0.18, 0.45), rng.uniform(0.06, 0.12)
            for b in range(rng.integers(1, 4)):
                place(shards, a * 0.5 ** (b + 1) * ice_tink(f0 * rng.uniform(0.98, 1.02), tau * 0.8), at)
                at, gap = at + gap, gap * 0.6
    out += 0.6 * norm(shards)
    for _ in range(7):
        f = rng.uniform(350, 900)
        chunk = modes([f, f * 1.7, f * 2.6], [0.03, 0.02, 0.012], [1, 0.6, 0.35], excite=0.002)
        place(chunk, 0.5 * norm(bp(noise(0.04), 1000, 6000)) * np.exp(-np.arange(int(0.04 * SR)) / (0.006 * SR)), 0)
        place(out, rng.uniform(0.25, 0.5) * norm(chunk), rng.uniform(0.2, 0.6))
    out += 0.3 * norm(crackling(dur, lambda k: 250 * np.exp(-4 * k) + 10, size=(0.0, 0.1)))
    return room(out, decay=0.7, wet=0.22, bright=3500, tail=0.3)


# ---------------------------------------------------------------------------
# Lightning
# ---------------------------------------------------------------------------


def electric_arc(dur, rate=110, flicker=0.0):
    """A high-voltage arc: short discharges about `rate` times a second,
    regular enough to give a clear 'bzzz' pitch, with a crackle on each
    one. flicker: chance that a discharge drops out."""
    n = int(dur * SR)
    clicks = np.zeros(n)
    pulses = np.zeros(n)
    t = 0.0
    while t < dur:
        if rng.random() > flicker:
            a = rng.uniform(0.6, 1)
            pulses[int(t * SR)] = a
            for _ in range(rng.integers(1, 3)):
                ln = int(rng.uniform(0.0002, 0.0008) * SR) + 2
                burst = rng.standard_normal(ln) * np.exp(-np.arange(ln) / (ln / 3))
                place(clicks, burst * a * rng.uniform(0.4, 1), t + rng.uniform(0, 0.0008))
        t += rng.uniform(0.93, 1.07) / rate
    # Each discharge also rings the air/electrodes: that is the buzz tone.
    buzz = resonator(pulses, 900, 500) + 0.7 * resonator(pulses, 2300, 700) + 0.4 * resonator(pulses, 4200, 900)
    y = hp(0.9 * norm(buzz) + 0.6 * norm(clicks), 200)
    return np.tanh(1.4 * norm(y))


def lightning_strike():
    """A charging arc buzzes louder (0.3 s), then the bolt: a tearing crack
    of shock waves, a boom and thunder that rolls away, with the arc
    sizzling out (~2.4 s).

    The crack lands at 0.3 s, when the bolt hits.
    """
    pre = 0.3
    dur = 1.9
    out = np.zeros(int(dur * SR))

    tc = t_axis(pre + 0.02)
    place(out, 0.4 * electric_arc(pre + 0.02, rate=110) * np.clip(tc / pre, 0, 1) ** 2.5, 0)

    # The crack: shock waves from the nearby part of the bolt, arriving in a
    # quick, tearing burst.
    times = np.concatenate([[0, 0.004, 0.011], rng.exponential(0.07, 160)])
    amps = (0.35 + 0.65 * rng.random(len(times))) * np.exp(-times / 0.12)
    amps[:3] = [1, 0.8, 0.7]
    durs = np.exp(rng.uniform(np.log(0.0004), np.log(0.006), len(times)))
    durs[:3] = [0.0035, 0.002, 0.003]
    crack = lp(pulse_train(0.7, times, amps, durs), 10000)
    place(out, norm(crack), pre)

    # Rolling thunder: shock waves from further along the bolt, arriving
    # later and duller (the air takes the highs away).
    rest = dur - pre
    rt = 0.04 + rng.gamma(1.6, 0.3, 300)
    roll = lp(pulse_train(rest, rt, rng.uniform(0.2, 1, len(rt)) * np.exp(-rt / 0.6), np.exp(rng.uniform(np.log(0.004), np.log(0.03), len(rt)))), 700)
    tt = t_axis(rest)
    s = lp(rng.standard_normal(len(tt)), 4)
    swell = 0.6 + 0.4 * s / (np.max(np.abs(s)) + 1e-9)
    # Phone speakers barely play below ~150 Hz, so the body sits at 100-400 Hz.
    rumble = bp(brown(rest), 60, 320, order=2) * np.clip(tt / 0.03, 0, 1) * np.exp(-tt / 0.7)
    boom = bp(noise(rest), 50, 220, order=2) * np.clip(tt / 0.004, 0, 1) * np.exp(-tt / 0.25)
    place(out, 0.7 * norm(roll) * swell + 0.6 * norm(rumble) + 0.9 * norm(boom), pre)

    sizzle = electric_arc(0.5, rate=100, flicker=0.2) * exp_decay(int(0.5 * SR), 0.12)
    place(out, 0.25 * sizzle, pre + 0.02)
    # Saturating gives the low end harmonics a phone speaker can play.
    out = fade(np.tanh(1.8 * norm(out)), fout=0.3)
    return room(out, decay=1.8, wet=0.3, bright=3500, tail=0.5)


def lightning_zap():
    """A short, flickering electric discharge with a few sharp snaps, for
    lightning clashes (~0.75 s)."""
    dur = 0.55
    n = int(dur * SR)
    arc = electric_arc(dur, rate=120, flicker=0.25) * env_adsr(n, 0.005, 0.12, 0.7, 0.2, dur)
    snaps = np.zeros(n)
    for at, a in [(0.0, 1), (0.12, 0.6), (0.27, 0.7)]:
        times = at + np.concatenate([[0], rng.exponential(0.01, 6)])
        snaps += pulse_train(dur, times, a * rng.uniform(0.3, 1, len(times)), rng.uniform(0.0006, 0.002, len(times)))
    out = np.tanh(1.5 * (0.7 * norm(arc) + 0.8 * norm(snaps)))
    return room(out, decay=0.6, wet=0.2, bright=6000, tail=0.2)


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
    "i": (320, 2400, 3100),
    "l": (380, 1100, 2600),  # the 'l', glides into the next vowel
    "m": (260, 1200, 2300),  # humming with the mouth shut
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


def syl(dur, f0, vowel, scale=1.0, breath=0.1, attack=0.012, release=0.06, vib=0.0, vib_hz=6.5):
    """One cartoon syllable. f0: (from, to) in Hz (log glide) or a function
    of k (0..1). vowel: a VOWELS name, a (from, to) pair to glide between,
    or a function of k returning formants. scale: >1 makes the character
    smaller and squeakier."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    k = t / dur
    f = f0(k) if callable(f0) else f0[0] * (f0[1] / f0[0]) ** k
    f = f * (1 + vib * np.sin(2 * np.pi * vib_hz * t))
    if isinstance(vowel, str):
        shape = lambda q: VOWELS[vowel]
    elif callable(vowel):
        shape = vowel
    else:
        shape = lambda q: mix_vowel(vowel[0], vowel[1], q)
    v = voice(f, lambda q: tuple(x * scale for x in shape(q)), breath=breath, blocks=max(6, int(dur * 70)))
    env = np.clip(t / attack, 0, 1) * np.clip((dur - t) / release, 0, 1)
    return norm(v) * env


def breath_h(dur=0.05, lo=700, hi=3800):
    """The 'h' in front of a syllable."""
    return norm(bp(noise(dur), lo, hi)) * np.hanning(int(dur * SR))


def sniff(dur=0.11):
    """A quick snotty inhale, the hiss rising in pitch."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    return norm(sweep_bp(noise(dur), 1400, 4200, width=0.5, steps=12)) * np.sin(np.pi * t / dur) ** 1.5


def snort(dur=0.17):
    """A piggy snort: a slow, noisy buzz through the nose."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 55 + 35 * np.sin(np.pi * t / dur)
    ph = (np.cumsum(f) / SR) % 1
    src = (ph < 0.18) - 0.18 + 0.8 * rng.standard_normal(n) * (ph < 0.35)
    y = resonator(src, 420, 160) + 0.8 * resonator(src, 1150, 260) + 0.25 * norm(bp(noise(dur), 300, 2500))
    return norm(y) * np.sin(np.pi * t / dur) ** 0.6


def kettle(dur):
    """Steam whistle, as if steam comes out of the angry character's ears."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 2300 + 700 * (t / dur) ** 0.5 + 25 * np.sin(2 * np.pi * 9 * t)
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR)
    hiss = norm(hp(noise(dur), 4500))
    return (0.8 * whistle + 0.3 * hiss) * np.clip(t / (0.6 * dur), 0, 1) * np.clip((dur - t) / 0.05, 0, 1)


def slide_whistle(dur, f_from, f_to):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f_from * (f_to / f_from) ** (t / dur) * (1 + 0.01 * np.sin(2 * np.pi * 6 * t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.06 * bp(noise(dur), 1500, 5000)
    return x * np.sin(np.pi * t / dur) ** 0.4


def kazoo(dur, f, vib=0.0):
    """A buzzy kazoo note: a voice humming through a rattling membrane."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = f * (1 + vib * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.08) / 0.1, 0, 1))
    v = norm(voice(freq, lambda q: (520, 1500, 3100), breath=0.04, blocks=max(6, int(dur * 40))))
    buzz = np.tanh(5 * v)
    rasp = norm(hp(noise(dur), 2500) * np.abs(v))
    y = bp(0.8 * buzz + 0.35 * rasp, 220, 7000)
    tongue = np.zeros(n)  # the little 't' each note starts with
    place(tongue, norm(bp(noise(0.012), 2000, 6000)) * np.hanning(int(0.012 * SR)), 0)
    return y * env_adsr(n, 0.015, 0.05, 0.85, 0.05, dur) + 0.4 * tongue


def party_horn(dur=0.32):
    """Party blower unrolling: 'prrrrt' with a rising pitch."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 560 * 1.35 ** (t / dur)
    saw = 2 * ((np.cumsum(f) / SR) % 1) - 1
    flutter = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 32 * t))
    y = lp(saw, 3500) * lp(flutter, 300) + 0.15 * bp(noise(dur), 1000, 5000)
    return norm(y) * env_adsr(n, 0.01, 0.05, 0.9, 0.08, dur)


def emote_hallo():
    """A sing-song 'Hal-looo!' from a little character, with a slide
    whistle going up under the 'looo' (~0.75 s)."""
    out = np.zeros(int(0.8 * SR))
    place(out, 0.35 * breath_h(0.05), 0.0)
    place(out, syl(0.13, (390, 440), "a", scale=1.2, breath=0.12), 0.035)
    place(out, 0.95 * syl(
        0.42,
        lambda k: 470 * (1 + 0.38 * np.clip(k * 2.5, 0, 1) - 0.08 * np.clip((k - 0.75) / 0.25, 0, 1)),
        lambda q: mix_vowel("l", "o", q / 0.18) if q < 0.18 else mix_vowel("o", "u", (q - 0.18) / 0.82),
        scale=1.2, breath=0.1, attack=0.03, release=0.12, vib=0.025,
    ), 0.17)
    place(out, 0.22 * slide_whistle(0.36, 900, 1900), 0.18)
    place(out, 0.25 * tone(0.3, 2349, 0.07, ((1, 1),)), 0.5)
    return out


def emote_haha():
    """A cheeky 'hee-hee-hee-hee' that ends in a piggy snort and one more
    'hihi' (~1 s)."""
    out = np.zeros(int(1.05 * SR))

    def hee(at, f, amp=1.0, dur=0.075):
        place(out, 0.3 * amp * breath_h(0.03, 1500, 5000), at)
        place(out, amp * syl(dur, (f * 1.08, f), ("e", "i"), scale=1.35, breath=0.15, attack=0.006, release=0.03), at + 0.018)

    for i in range(5):
        hee(0.09 * i, 720 - 30 * i + (35 if i % 2 else 0))
    place(out, 0.9 * snort(0.18), 0.5)
    hee(0.74, 660, 0.8)
    hee(0.83, 620, 0.7)
    return out


def emote_boos():
    """An angry growl 'grrrr', a stomp and a 'HMPF!', while steam whistles
    out of their ears (~1.2 s)."""
    out = np.zeros(int(1.2 * SR))
    dur = 0.52
    n = int(dur * SR)
    t = np.arange(n) / SR
    growl = syl(dur, lambda k: 140 + 45 * k + 10 * np.sin(2 * np.pi * 11 * k), ("o", "a"), breath=0.35, attack=0.03, release=0.05)
    rolled = lp(0.45 + 0.55 * np.sign(np.sin(2 * np.pi * 27 * t)), 350)  # the rolling 'rrr'
    place(out, np.tanh(2.2 * growl * rolled), 0.0)
    f = 55 + 90 * np.exp(-t / 0.04)
    place(out, 0.8 * np.sin(2 * np.pi * np.cumsum(f) / SR) * exp_decay(n, 0.09), 0.0)
    # 'Hm' with the mouth shut, then the 'pf' bursts out.
    place(out, 0.9 * syl(0.15, (230, 160), "m", breath=0.1, attack=0.005, release=0.03), 0.6)
    puff = norm(bp(noise(0.09), 500, 3500)) * exp_decay(int(0.09 * SR), 0.025)
    place(out, 0.75 * puff, 0.74)
    place(out, 0.75 * np.sin(2 * np.pi * np.cumsum(55 + 70 * np.exp(-t / 0.03)) / SR) * exp_decay(n, 0.06), 0.6)
    place(out, 0.22 * kettle(0.6), 0.55)
    return out


def emote_huilen():
    """Sobbing 'hu-hu' with snotty sniffs, a big wobbly 'bwaaaah' and a
    sniffle at the end (~1.6 s)."""
    out = np.zeros(int(1.6 * SR))
    for at, f in [(0.0, 520), (0.24, 570)]:
        place(out, 0.3 * breath_h(0.04), at)
        place(out, 0.8 * syl(0.12, (f, f * 1.12), "u", scale=1.2, breath=0.18, attack=0.008, release=0.04), at + 0.025)
        place(out, 0.5 * sniff(0.09), at + 0.15)
    place(out, syl(
        0.88,
        lambda k: 690 - 260 * k ** 1.3,
        lambda q: mix_vowel("u", "a", q / 0.15) if q < 0.15 else mix_vowel("a", "o", max(0, q - 0.6) / 0.4),
        scale=1.2, breath=0.16, attack=0.04, release=0.2, vib=0.07, vib_hz=7.5,
    ), 0.48)
    place(out, 0.55 * sniff(0.08), 1.39)
    place(out, 0.6 * sniff(0.1), 1.48)
    return out


def emote_gg():
    """A silly kazoo fanfare 'ta-ta-ta-taaaa' and a party blower (~1.3 s)."""
    out = np.zeros(int(1.3 * SR))
    for at, f in [(0.0, 392), (0.12, 523.25), (0.24, 659.25)]:
        place(out, 0.8 * kazoo(0.1, f), at)
    place(out, kazoo(0.55, 783.99, vib=0.025), 0.36)
    place(out, 0.55 * party_horn(0.3), 0.95)
    return out


def emote_goed():
    """An impressed 'Ooooh... WOW!' from a deep voice, then applause and a
    ding (~1.35 s)."""
    out = np.zeros(int(1.35 * SR))
    place(out, 0.7 * syl(0.26, (190, 240), ("u", "o"), breath=0.12, attack=0.05, release=0.06), 0.0)
    place(out, syl(
        0.46,
        lambda k: 240 + 190 * np.sin(np.pi * np.clip(k, 0, 1) ** 0.7),
        lambda q: mix_vowel("u", "a", q / 0.3) if q < 0.3 else mix_vowel("a", "u", max(0, q - 0.65) / 0.35),
        breath=0.12, attack=0.02, release=0.1, vib=0.015,
    ), 0.27)
    claps = np.zeros(int(0.9 * SR))
    for _ in range(80):
        ln = int(0.03 * SR)
        clap = bp(noise(0.03), rng.uniform(800, 1400), rng.uniform(2500, 4500)) * np.exp(-np.arange(ln) / (0.006 * SR))
        place(claps, clap * rng.uniform(0.3, 1), rng.uniform(0, 0.75))
    claps = norm(claps) * env_adsr(len(claps), 0.1, 0.3, 0.7, 0.3, 0.9)
    place(out, 0.45 * claps, 0.45)
    place(out, 0.4 * norm(tone(0.6, 1568, 0.22)), 0.72)
    place(out, 0.3 * norm(tone(0.5, 2093, 0.18)), 0.8)
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


# ---------------------------------------------------------------------------
# Badges
# ---------------------------------------------------------------------------

# When the medal lands in the unlock overlay: 0.42 of its 1.8 s entrance
# (lib/widgets/badges/badge_unlock_overlay.dart). Keep them in sync.
BADGE_LAND = 0.42 * 1.8


def badge_unlock():
    """The medal spins in with a whoosh and a rising sparkle, then lands on
    a big 'TA-DAAA': a boom, a bright brass chord, bells and glitter
    (~2.4 s)."""
    land = BADGE_LAND
    dur = land + 1.65
    n = int(dur * SR)
    out = np.zeros(n)

    # Spin-in: a whoosh that rises, pulsing slower as the spin slows down.
    wn = int(land * SR)
    wt = np.arange(wn) / SR
    spin_rate = 14 - 9 * (wt / land)
    pulse = 0.55 + 0.45 * np.sin(2 * np.pi * np.cumsum(spin_rate) / SR)
    whoosh = sweep_bp(noise(land), 500, 5000, width=0.7) * pulse * (wt / land) ** 1.5
    place(out, 0.5 * norm(whoosh), 0)
    # Rising sparkle: a quick pentatonic run up to the landing.
    run = [1047, 1175, 1319, 1568, 1760, 2093, 2349, 2637, 3136]
    for i, f in enumerate(run):
        at = 0.12 + (land - 0.16) * (i / (len(run) - 1)) ** 0.8
        place(out, (0.12 + 0.12 * i / len(run)) * tone(0.25, f, 0.06, ((1, 1), (3, 0.15))), at)

    # Landing: a short pickup note, then the chord.
    place(out, 0.55 * brass_note(0.1, 783.99, bright=3600), land - 0.11)
    c5, e5, g5, c6 = 523.25, 659.25, 783.99, 1046.5
    for f, a in [(c6, 1), (g5, 0.7), (e5, 0.6), (c5, 0.55), (c5 / 2, 0.4)]:
        place(out, 0.55 * a * brass_note(1.2, f, bright=3800, vibrato=0.006), land)
    tl = np.arange(n - int(land * SR)) / SR
    bf = 45 + 110 * np.exp(-tl / 0.05)
    boom = np.sin(2 * np.pi * np.cumsum(bf) / SR) * np.exp(-tl / 0.25)
    place(out, 0.8 * boom, land)
    crash = hp(noise(1.4), 5000) * exp_decay(int(1.4 * SR), 0.45)
    place(out, 0.25 * norm(crash), land)
    for f, a in [(2093, 1), (2637, 0.7), (3136, 0.6)]:
        place(out, 0.3 * a * tone(1.2, f, 0.35, ((1, 1), (2.76, 0.2))), land)
    # Glitter falling around the medal.
    for _ in range(26):
        at = land + 0.05 + rng.exponential(0.35)
        if at > dur - 0.2:
            continue
        f = rng.uniform(3000, 7000)
        place(out, rng.uniform(0.04, 0.12) * tone(0.2, f, 0.04, ((1, 1),)), at)
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
    "emote_hallo": emote_hallo,
    "emote_haha": emote_haha,
    "emote_boos": emote_boos,
    "emote_huilen": emote_huilen,
    "emote_gg": emote_gg,
    "emote_goed": emote_goed,
    "result_win": result_win,
    "result_lose": result_lose,
    "badge_unlock": badge_unlock,
}

if __name__ == "__main__":
    for name, fn in SOUNDS.items():
        save(name, fn())
