#!/usr/bin/env python3
"""Synthesise every sound in Config.Sounds as an original .ogg (no third-party samples, so no licensing issues).

    python3 tools/make_sounds.py [out_dir]      (default: palata13/assets/sounds)

Needs numpy and ffmpeg (libvorbis). Output is mono 44.1 kHz, deterministic (fixed seeds).
Looped sounds (ambience, music, breathing, buzz, heartbeat) are built from circular FFT noise,
whole-cycle tones and circular reverb, so they repeat without a click.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
TAU = 2 * np.pi


# -- building blocks ---------------------------------------------------------------------------
def rng(seed):
    return np.random.default_rng(seed)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def band_noise(n, lo, hi, seed, tilt=0.0):
    """Circular band-limited noise (seamless when looped). tilt<0 darkens (pink-ish)."""
    spec = rng(seed).normal(size=n // 2 + 1) + 1j * rng(seed + 1).normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    mask = ((f >= lo) & (f <= hi)).astype(float)
    if tilt:
        mask *= np.where(f > 0, (np.maximum(f, 1) / 1000.0) ** tilt, 0)
    x = np.fft.irfft(spec * mask, n)
    return x / (np.max(np.abs(x)) + 1e-9)


def fft_filter(x, lo=0.0, hi=SR / 2, circular=False):
    n = len(x) if circular else int(2 ** np.ceil(np.log2(len(x) * 2)))
    X = np.fft.rfft(x, n)
    f = np.fft.rfftfreq(n, 1 / SR)
    X *= ((f >= lo) & (f <= hi))
    return np.fft.irfft(X, n)[: len(x)]


def env_adsr(n, a, d, s, r, sustain_level=0.6):
    a, d, r = int(a * SR), int(d * SR), int(r * SR)
    s = max(0, n - a - d - r)
    e = np.concatenate([np.linspace(0, 1, a, endpoint=False), np.linspace(1, sustain_level, d, endpoint=False),
                        np.full(s, sustain_level), np.linspace(sustain_level, 0, r)])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def decay(n, seconds):
    return np.exp(-np.arange(n) / (seconds * SR))


def saw(phase):
    return 2 * ((phase / TAU) % 1.0) - 1


def phase_of(freq_curve):
    return np.cumsum(TAU * freq_curve / SR)


def reverb(x, seconds=2.0, mix=0.35, seed=7, circular=False, damp=4000):
    n_ir = int(seconds * SR)
    ir = rng(seed).normal(size=n_ir) * decay(n_ir, seconds / 6.0)
    ir = fft_filter(ir, 0, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    if circular:
        wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, len(x)), len(x))
    else:
        n = int(2 ** np.ceil(np.log2(len(x) + n_ir)))
        wet = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[: len(x) + n_ir]
        x = np.pad(x, (0, n_ir))
    wet *= np.max(np.abs(x)) / (np.max(np.abs(wet)) + 1e-9)
    return (1 - mix) * x + mix * wet


def softclip(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if j > i:
        buf[i:j] += x[: j - i]
    return buf


def norm(x, peak=0.89):
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def fade_tail(x, ms=15):
    k = min(len(x), int(ms / 1000 * SR))
    x = x.copy()
    x[-k:] *= np.linspace(1, 0, k)
    x[: min(len(x), 64)] *= np.linspace(0, 1, min(len(x), 64))
    return x


def loop_freq(f, dur):
    """Nearest frequency with a whole number of cycles in `dur` (keeps loops seamless)."""
    return max(1, round(f * dur)) / dur


# -- one-shots ----------------------------------------------------------------------------------
def click(pitch, seed, dur=0.14):
    t = t_axis(dur)
    body = np.sin(TAU * pitch * t) * decay(len(t), 0.012)
    snap = band_noise(len(t), 2000, 9000, seed) * decay(len(t), 0.004)
    spring = np.sin(TAU * pitch * 2.7 * t) * decay(len(t), 0.03) * 0.25
    return body * 0.7 + snap * 0.6 + spring


def flashlight_on():
    x = np.zeros(int(0.25 * SR))
    place(x, click(1800, 11), 0)
    place(x, click(2600, 12, 0.08) * 0.4, 0.035)
    hum = np.sin(TAU * 120 * t_axis(0.18)) * env_adsr(int(0.18 * SR), 0.01, 0.05, 0, 0.1, 0.3) * 0.08
    place(x, hum, 0.05)
    return x


def flashlight_off():
    x = np.zeros(int(0.22 * SR))
    place(x, click(1300, 13), 0)
    place(x, click(900, 14, 0.08) * 0.35, 0.04)
    return x


def monster_step():
    dur = 0.9
    t = t_axis(dur)
    f = 70 * np.exp(-t * 6) + 38
    thud = np.sin(phase_of(f)) * decay(len(t), 0.18)
    crunch = fft_filter(band_noise(len(t), 80, 2500, 21) * decay(len(t), 0.05), 80, 2500)
    squelch = band_noise(len(t), 300, 1400, 22) * decay(len(t), 0.12) * np.clip((t - 0.04) * 20, 0, 1)
    x = softclip(thud * 1.2 + crunch * 0.6 + squelch * 0.25, 1.6)
    return reverb(x, 0.9, 0.18, seed=23)


def monster_scream():
    dur = 2.6
    t = t_axis(dur)
    out = np.zeros(len(t))
    for i, (base, det) in enumerate([(240, 1.0), (243, 1.01), (480, 0.99), (157, 1.02), (322, 0.98)]):
        sweep = base * det * (1 + 0.55 * np.minimum(t / 0.35, 1) - 0.35 * np.clip((t - 1.2) / 1.4, 0, 1))
        vib = 1 + 0.035 * np.sin(TAU * (6.5 + i) * t) + 0.02 * rng(30 + i).normal(size=len(t)).cumsum() / np.sqrt(len(t))
        out += saw(phase_of(sweep * vib)) / (1 + i * 0.3)
    rasp = band_noise(len(t), 900, 7000, 31) * 0.8
    formant = fft_filter(out, 400, 3800) + rasp * (0.5 + 0.5 * np.sin(TAU * 13 * t))
    env = env_adsr(len(t), 0.05, 0.4, 0, 1.0, 0.75)
    x = softclip(formant * env * 1.6, 3.0)
    return reverb(x, 1.6, 0.3, seed=32)


def monster_sniff():
    x = np.zeros(int(1.4 * SR))
    for i, at in enumerate((0.0, 0.18, 0.36, 0.85)):
        d = 0.14 if i < 3 else 0.4
        n = int(d * SR)
        s = band_noise(n, 1500 + i * 200, 6500, 40 + i) * np.sin(np.linspace(0, np.pi, n)) ** 2
        if i == 3:  # long exhale with a wet growl
            g = saw(phase_of(np.full(n, 72.0))) * 0.25
            s = s * 0.6 + fft_filter(g, 60, 600)
        place(x, s * (0.8 if i < 3 else 0.6), at)
    return reverb(x, 0.6, 0.15, seed=44)


def sonar():
    dur = 1.6
    t = t_axis(dur)
    f = 95 + 380 * np.exp(-((t - 0.45) ** 2) / 0.08)
    howl = saw(phase_of(f)) * 0.6 + np.sin(phase_of(f * 0.5)) * 0.5
    howl = fft_filter(howl, 60, 3000) * env_adsr(len(t), 0.08, 0.4, 0, 0.9, 0.7)
    howl = softclip(howl * 1.5, 2.5)
    x = np.zeros(int(4.2 * SR))
    for k in range(6):  # echo off distant walls
        place(x, fft_filter(howl, 80, 3000 - k * 400) * (0.62 ** k), k * 0.42)
    return reverb(x, 2.4, 0.35, seed=51)


def chase_sting():
    dur = 2.4
    t = t_axis(dur)
    cluster = np.zeros(len(t))
    for i, f in enumerate((55, 58.27, 82.41, 87.31, 110, 116.54, 164.81)):
        cluster += saw(phase_of(np.full(len(t), f * (1 + 0.003 * i)))) / (1 + i * 0.25)
    cluster = fft_filter(cluster, 40, 2400) * env_adsr(len(t), 0.005, 0.3, 0, 1.6, 0.55)
    boom = np.sin(phase_of(55 * np.exp(-t * 3) + 30)) * decay(len(t), 0.5) * 1.4
    hit = band_noise(len(t), 200, 8000, 61) * decay(len(t), 0.08)
    swell = band_noise(len(t), 2000, 9000, 62) * np.clip(1 - t / 0.25, 0, 1) ** 2 * 0.0
    x = softclip(cluster * 0.9 + boom + hit * 0.6 + swell, 1.8)
    return reverb(x, 2.2, 0.32, seed=63)


def static():
    dur = 1.2
    n = int(dur * SR)
    hiss = band_noise(n, 300, 12000, 71)
    crackle = (rng(72).random(n) > 0.997).astype(float) * rng(73).normal(size=n) * 3
    gate = (np.sin(TAU * 31 * t_axis(dur)) > -0.3).astype(float) * 0.5 + 0.5
    return (hiss * gate * 0.6 + crackle) * env_adsr(n, 0.01, 0.1, 0, 0.2, 0.9)


def ui_hover():
    t = t_axis(0.06)
    return np.sin(TAU * 2400 * t) * decay(len(t), 0.01) * 0.4 + band_noise(len(t), 4000, 9000, 81) * decay(len(t), 0.003) * 0.3


def ui_click():
    t = t_axis(0.12)
    return (np.sin(TAU * 520 * t) * decay(len(t), 0.02) + band_noise(len(t), 600, 5000, 82) * decay(len(t), 0.006) * 0.6)


def chime(freqs, spacing, seed, length=0.9, bright=1.0):
    x = np.zeros(int((length + spacing * len(freqs)) * SR))
    for i, f in enumerate(freqs):
        t = t_axis(length)
        tone = (np.sin(TAU * f * t) + 0.35 * np.sin(TAU * f * 2.01 * t) * bright + 0.15 * np.sin(TAU * f * 3.98 * t) * bright)
        place(x, tone * decay(len(t), 0.25) * env_adsr(len(t), 0.004, 0, 0, 0.02, 1), i * spacing)
    return reverb(x, 1.0, 0.25, seed=seed)


def pickup():
    return chime((660, 990), 0.08, 91, 0.5)


def purchase():
    x = chime((784, 988, 1319), 0.07, 92, 0.7)
    coin = band_noise(int(0.2 * SR), 3000, 9000, 93) * decay(int(0.2 * SR), 0.03) * 0.4
    return place(x, coin, 0.0)


def metal_hit(base, seed, length=1.6, damp=0.35):
    t = t_axis(length)
    ratios = (1.0, 1.59, 2.14, 2.83, 3.51, 4.17, 5.43)
    x = sum(np.sin(TAU * base * r * t + rng(seed + i).random() * TAU) * decay(len(t), damp / (1 + i * 0.35)) / (1 + i * 0.4)
            for i, r in enumerate(ratios))
    x += band_noise(len(t), 500, 9000, seed + 50) * decay(len(t), 0.01) * 1.2
    return x


def metal_bang():
    x = metal_hit(180, 100, 1.8)
    x = place(np.pad(x, (0, int(0.4 * SR))), metal_hit(240, 110, 1.2, 0.2) * 0.4, 0.09)
    return reverb(softclip(x, 1.4), 1.8, 0.3, seed=101)


def fuse_insert():
    x = np.zeros(int(1.0 * SR))
    place(x, metal_hit(620, 120, 0.4, 0.05) * 0.7, 0)
    t = t_axis(0.5)
    zap = saw(phase_of(120 + 40 * np.sin(TAU * 7 * t))) * band_noise(len(t), 1000, 8000, 121) * decay(len(t), 0.12)
    place(x, fft_filter(zap, 200, 8000) * 0.8, 0.12)
    place(x, chime((330, 495), 0.06, 122, 0.4) * 0.35, 0.35)
    return x


def engine(dur, rpm_curve, seed):
    t = t_axis(dur)
    f0 = rpm_curve(t)
    ph = phase_of(f0)
    body = sum(np.sin(ph * h + h) / h ** 0.8 for h in range(1, 9))
    chug = (0.6 + 0.4 * np.sin(ph * 0.5))
    rattle = band_noise(len(t), 200, 3000, seed) * (0.3 + 0.3 * np.sin(ph * 2))
    return softclip((body * chug * 0.6 + rattle * 0.35), 2.0)


def generator_on():
    dur = 3.4
    t = t_axis(dur)
    starter = np.zeros(len(t))
    for k in range(5):  # cranking
        place(starter, metal_hit(90, 130 + k, 0.18, 0.05) * 0.6, k * 0.13)
    run = engine(dur, lambda t: 12 + 26 * np.clip((t - 0.7) / 1.4, 0, 1), 131)
    run *= np.clip((t - 0.6) / 0.3, 0, 1)
    return reverb(starter + run, 1.2, 0.2, seed=132) * env_adsr(len(t) + int(1.2 * SR), 0.01, 0, 0, 0.5, 1)


def generator_crank():
    dur = 2.6
    x = np.zeros(int(dur * SR))
    for k in range(18):  # ratchet
        place(x, metal_hit(1400 + (k % 3) * 120, 140 + k, 0.06, 0.008) * 0.5, k * 0.13 + rng(141).random() * 0.02)
    t = t_axis(dur)
    grind = band_noise(len(t), 150, 1800, 142) * (0.4 + 0.4 * np.sin(TAU * 7.7 * t) ** 2) * 0.5
    return reverb(x + grind * env_adsr(len(t), 0.1, 0, 0, 0.4, 1), 0.8, 0.2, seed=143)


def gate_open():
    dur = 4.5
    t = t_axis(dur)
    f = 180 + 60 * np.sin(TAU * 0.4 * t) + 30 * rng(150).normal(size=len(t)).cumsum() / np.sqrt(len(t)) * 3
    squeal = sum(np.sin(phase_of(f * r)) / (1 + i) for i, r in enumerate((1, 2.01, 3.03)))
    scrape = band_noise(len(t), 300, 5000, 151)
    x = (fft_filter(squeal, 120, 4000) * 0.5 + scrape * 0.4) * env_adsr(len(t), 0.3, 0, 0, 0.8, 1)
    x = place(x, metal_hit(110, 152, 1.5) * 0.9, dur - 1.0)
    return reverb(softclip(x, 1.5), 2.0, 0.3, seed=153)


def teleport():
    dur = 2.4
    t = t_axis(dur)
    swell = band_noise(len(t), 200, 9000, 160) * (t / dur) ** 3
    riser = saw(phase_of(60 + 500 * (t / dur) ** 2)) * (t / dur) ** 2 * 0.4
    x = fft_filter(swell + riser, 100, 9000)
    boom = np.sin(phase_of(70 * np.exp(-t_axis(1.5) * 3) + 28)) * decay(int(1.5 * SR), 0.4) * 1.6
    x = np.pad(x, (0, len(boom)))
    place(x, boom, dur - 0.05)
    return reverb(softclip(x, 1.5), 2.5, 0.35, seed=161)


def whisper():
    dur = 2.4
    x = np.zeros(int(dur * SR))
    r = rng(170)
    at = 0.05
    while at < dur - 0.3:
        d = 0.08 + r.random() * 0.22
        n = int(d * SR)
        lo = 800 + r.random() * 1600
        syl = band_noise(n, lo, lo + 2500 + r.random() * 2500, int(r.integers(1e6)))
        if r.random() < 0.4:  # sibilant
            syl = band_noise(n, 4000, 10000, int(r.integers(1e6)))
        syl *= np.sin(np.linspace(0, np.pi, n)) ** 1.5
        place(x, syl * (0.5 + r.random() * 0.5), at)
        at += d + r.random() * 0.12
    return reverb(x, 1.4, 0.4, seed=171)


def cloth():
    dur = 0.35
    n = int(dur * SR)
    x = band_noise(n, 1500, 9000, 180) * np.sin(np.linspace(0, np.pi, n)) ** 2
    x *= 0.6 + 0.4 * (rng(181).random(n) > 0.5)
    return fft_filter(x, 1500, 9000)


def drip():
    t = t_axis(0.5)
    f = 900 + 1500 * (1 - np.exp(-t * 60))
    blip = np.sin(phase_of(f)) * decay(len(t), 0.03)
    x = np.zeros(int(1.2 * SR))
    place(x, blip, 0)
    place(x, blip * 0.25, 0.21)
    return reverb(x, 1.5, 0.45, seed=190)


def crow():
    x = np.zeros(int(2.4 * SR))
    for k, at in enumerate((0.0, 0.45, 0.95)):
        d = 0.32 if k < 2 else 0.42
        t = t_axis(d)
        f = 520 + 160 * np.sin(np.pi * t / d) - 120 * t / d
        caw = saw(phase_of(f)) + 0.6 * saw(phase_of(f * 1.51))
        caw = fft_filter(caw * (0.6 + 0.4 * band_noise(len(t), 30, 200, 200 + k)), 700, 3800)
        caw *= np.sin(np.linspace(0, np.pi, len(t))) ** 0.6
        place(x, softclip(caw * 2, 2.5), at)
    return reverb(x, 2.5, 0.4, seed=201)


def bell():
    dur = 9.0
    t = t_axis(dur)
    base = 98.0  # low, slightly flat church bell
    parts = ((0.5, 1.0, 5.5), (1.0, 0.9, 4.0), (1.19, 0.75, 3.2), (1.5, 0.6, 2.6), (2.0, 0.55, 2.2),
             (2.52, 0.35, 1.6), (3.0, 0.3, 1.2), (4.07, 0.2, 0.8), (5.43, 0.15, 0.5))
    x = sum(a * np.sin(TAU * base * r * t + i) * decay(len(t), d) for i, (r, a, d) in enumerate(parts))
    x *= 1 + 0.1 * np.sin(TAU * 2.2 * t)  # beating
    x += band_noise(len(t), 400, 6000, 210) * decay(len(t), 0.02) * 0.8
    return reverb(x, 3.0, 0.3, seed=211)


# -- loops ------------------------------------------------------------------------------------------
def loop_monster_breath():
    dur = 4.0
    n = int(dur * SR)
    t = t_axis(dur)
    cyc = (t / dur) % 1.0
    inhale = np.clip(np.sin(TAU * cyc), 0, None) ** 1.5
    exhale = np.clip(-np.sin(TAU * cyc), 0, None) ** 1.2
    air_in = band_noise(n, 600, 5000, 300) * inhale * 0.5
    air_out = band_noise(n, 150, 2600, 301) * exhale
    growl = saw(TAU * loop_freq(62, dur) * t) + 0.5 * saw(TAU * loop_freq(93, dur) * t)
    growl = fft_filter(growl, 50, 900, circular=True) * exhale * (0.6 + 0.4 * band_noise(n, 8, 40, 302))
    wet = band_noise(n, 1000, 4000, 303) * exhale * (rng(304).random(n) > 0.995) * 2
    return reverb(air_in + air_out * 0.8 + growl * 0.55 + wet, 1.0, 0.2, seed=305, circular=True)


def loop_heartbeat():
    dur = 1.0
    x = np.zeros(int(dur * SR))
    for at, amp in ((0.0, 1.0), (0.24, 0.7)):
        t = t_axis(0.25)
        thump = np.sin(phase_of(55 * np.exp(-t * 12) + 38)) * decay(len(t), 0.06)
        place(x, thump * amp, at)
    return fft_filter(x, 20, 400, circular=True)


def loop_breathing():
    dur = 3.2
    n = int(dur * SR)
    cyc = (t_axis(dur) / dur) % 1.0
    inhale = np.clip(np.sin(TAU * cyc), 0, None)
    exhale = np.clip(-np.sin(TAU * cyc), 0, None) ** 0.8
    return band_noise(n, 900, 6000, 310) * inhale * 0.45 + band_noise(n, 300, 3500, 311) * exhale * 0.6


def loop_light_buzz():
    dur = 2.0
    t = t_axis(dur)
    n = len(t)
    hum = sum(np.sin(TAU * 100 * h * t) / h ** 1.2 for h in range(1, 14))  # 100 Hz is whole-cycle in 2 s
    hum = np.sign(hum) * np.abs(hum) ** 0.6
    flicker = 0.75 + 0.25 * band_noise(n, 2, 15, 320)
    tick = band_noise(n, 3000, 9000, 321) * (rng(322).random(n) > 0.9993) * 1.5
    return fft_filter(hum * flicker * 0.5 + tick, 80, 9000, circular=True)


def drone(dur, base, seed, partials=(1, 1.5, 2, 3), detune=0.6):
    t = t_axis(dur)
    x = np.zeros(len(t))
    for i, p in enumerate(partials):
        for d in (-detune, detune):
            f = loop_freq(base * p + d, dur)
            x += np.sin(TAU * f * t + i) / (1 + i)
    return x / len(partials)


def loop_ambience():  # hospital: deep drone, ventilation, distant knocks, metal creaks
    dur = 30.0
    n = int(dur * SR)
    t = t_axis(dur)
    x = drone(dur, 41.2, 330) * 0.7
    x += band_noise(n, 60, 700, 331, tilt=-1.0) * (0.35 + 0.15 * np.sin(TAU * t / dur * 3))
    x += fft_filter(drone(dur, 220, 332, (1, 1.06), 0.3), 150, 900, circular=True) * 0.06 * (0.5 + 0.5 * np.sin(TAU * t / dur * 2))
    for at, base, seed in ((6.3, 140, 333), (14.8, 95, 334), (22.1, 170, 335)):
        place(x, fft_filter(metal_hit(base, seed, 2.0, 0.5), 60, 1500) * 0.25, at)
    for at in (9.5, 9.85, 26.4):
        k = metal_hit(70, 336, 0.5, 0.06)
        place(x, fft_filter(k, 40, 500) * 0.35, at)
    return reverb(x, 4.0, 0.45, seed=337, circular=True, damp=2500)


def loop_ambience_morgue():  # cold room: fridge compressor hum, vent, drips, knocking from drawers
    dur = 30.0
    n = int(dur * SR)
    t = t_axis(dur)
    hum = sum(np.sin(TAU * loop_freq(50 * h, dur) * t) / h ** 1.5 for h in range(1, 8)) * 0.35
    hum *= 0.8 + 0.2 * np.sin(TAU * t / dur * 5)
    x = hum + band_noise(n, 200, 3000, 340, tilt=-0.8) * 0.25 + drone(dur, 36.7, 341) * 0.5
    for at in (3.1, 8.4, 12.9, 17.2, 21.7, 27.5):
        place(x, drip() * 0.25, at)
    for at in (15.0, 15.45, 15.9, 24.3):  # knocking from inside a drawer
        place(x, fft_filter(metal_hit(160, 342, 0.4, 0.05), 60, 1200) * 0.45, at)
    return reverb(x, 3.0, 0.4, seed=343, circular=True, damp=3000)


def loop_ambience_forest():  # night forest: wind in pines, creaking trunks, far bell, crows
    dur = 30.0
    n = int(dur * SR)
    t = t_axis(dur)
    gust = 0.55 + 0.45 * band_noise(n, 0.05, 0.5, 350)
    x = band_noise(n, 150, 2500, 351, tilt=-0.7) * gust * 0.6
    x += band_noise(n, 1800, 6000, 352) * gust ** 3 * 0.15
    x += drone(dur, 32.7, 353, (1, 2), 0.3) * 0.35
    for at in (4.0, 19.0):
        place(x, crow() * 0.18, at)
    place(x, bell() * 0.12, 11.0)
    for at in (7.5, 24.0):
        tt = t_axis(1.4)
        creak = saw(phase_of(80 + 40 * np.sin(TAU * 0.8 * tt))) * np.sin(np.linspace(0, np.pi, len(tt)))
        place(x, fft_filter(creak, 200, 1600) * 0.12, at)
    return reverb(x, 3.5, 0.35, seed=354, circular=True, damp=4000)


def loop_wind():
    dur = 20.0
    n = int(dur * SR)
    gust = 0.5 + 0.5 * band_noise(n, 0.05, 0.6, 360)
    x = band_noise(n, 200, 3000, 361, tilt=-0.6) * gust
    whistle = band_noise(n, 700, 1100, 362) * gust ** 4 * 0.5
    return reverb(x + whistle, 2.0, 0.3, seed=363, circular=True)


def loop_menu_music():  # 32 s: dark drone, slow minor pad, out-of-tune music box
    dur = 32.0
    n = int(dur * SR)
    t = t_axis(dur)
    x = drone(dur, 36.7, 370, (1, 1.5, 2), 0.4) * 0.8
    pad_chords = ((110.0, 130.81, 164.81), (103.83, 130.81, 155.56), (98.0, 116.54, 146.83), (103.83, 123.47, 155.56))
    seg = dur / len(pad_chords)
    for k, chord in enumerate(pad_chords):
        e = np.clip(np.minimum((t - k * seg) / 2.0, (k * seg + seg - t) / 2.0), 0, 1)
        e += np.clip(np.minimum((t - k * seg + dur) / 2.0, (k * seg + seg - t + dur) / 2.0), 0, 1)  # wrap
        for f in chord:
            for d in (-0.7, 0.7):
                x += np.sin(TAU * loop_freq(f + d, dur) * t) * e * 0.12
    melody = (659.3, 622.3, 587.3, 523.3, 493.9, 523.3, 440.0, 0, 659.3, 698.5, 659.3, 587.3, 523.3, 0, 493.9, 415.3)
    step = dur / len(melody)
    box = np.zeros(n)
    for i, f in enumerate(melody):
        if not f:
            continue
        f *= 1 + rng(371 + i).normal() * 0.006  # broken, slightly out of tune
        tt = t_axis(2.0)
        note = (np.sin(TAU * f * tt) + 0.4 * np.sin(TAU * f * 3.01 * tt) + 0.2 * np.sin(TAU * f * 5.03 * tt)) * decay(len(tt), 0.35)
        start = int(i * step * SR)
        idx = (np.arange(len(tt)) + start) % n  # wrap the tail to the start
        box[idx] += note
    x += box * 0.16
    x += band_noise(n, 2000, 8000, 372) * 0.02  # tape hiss
    return reverb(x, 4.0, 0.45, seed=373, circular=True, damp=3500)


SOUNDS = {
    "FlashlightOn": flashlight_on, "FlashlightOff": flashlight_off, "MonsterStep": monster_step,
    "MonsterBreath": loop_monster_breath, "MonsterScream": monster_scream, "MonsterSniff": monster_sniff,
    "Sonar": sonar, "ChaseSting": chase_sting, "Ambience": loop_ambience, "AmbienceMorgue": loop_ambience_morgue,
    "AmbienceForest": loop_ambience_forest, "MenuMusic": loop_menu_music, "Heartbeat": loop_heartbeat,
    "Static": static, "UIHover": ui_hover, "UIClick": ui_click, "Pickup": pickup, "FuseInsert": fuse_insert,
    "GeneratorOn": generator_on, "GeneratorCrank": generator_crank, "GateOpen": gate_open, "Purchase": purchase,
    "Teleport": teleport, "Whisper": whisper, "LightBuzz": loop_light_buzz, "MetalBang": metal_bang,
    "Breathing": loop_breathing, "Cloth": cloth, "Drip": drip, "Wind": loop_wind, "Crow": crow, "Bell": bell,
}
LOOPED = {"MonsterBreath", "Ambience", "AmbienceMorgue", "AmbienceForest", "MenuMusic", "Heartbeat",
          "LightBuzz", "Breathing", "Wind"}


def write_ogg(x, path, quality=4):
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        wav_path = tmp.name
    try:
        with wave.open(wav_path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    finally:
        os.unlink(wav_path)


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "assets", "sounds")
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        x = np.asarray(fn(), dtype=float)
        x = norm(x, 0.7 if name in LOOPED else 0.82)  # Vorbis overshoots by a few %; stay clear of 1.0
        if name not in LOOPED:
            x = fade_tail(x)
        path = os.path.join(out, name + ".ogg")
        write_ogg(x, path)
        print("%-15s %5.1fs %s %6.1f KB" % (name, len(x) / SR, "loop" if name in LOOPED else "    ", os.path.getsize(path) / 1024))


if __name__ == "__main__":
    main()
