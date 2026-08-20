#!/usr/bin/env python3
"""Noum V8 UI sound kit — synthesized, no samples, no licensing.

Design notes (why v1 sounded cheap):
  * A fixed-frequency sine is a BEEP. Percussive UI sound needs a PITCH ENVELOPE —
    the body drops in pitch as it decays. That is the difference between a thock
    and a bleep, and it is the single biggest quality lever here.
  * Every cue is layered: a short filtered noise TRANSIENT (the contact), a pitched
    BODY with its own decay, and for weighty cues a SUB.
  * Frequently repeated cues ship in 3 variants so repetition does not fatigue.
    Rotate them at the call site (round-robin or random).
  * The room is tiny. Sticker-on-paper barely rings.
"""
import subprocess, os, math

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "..", "Noum", "Resources", "Sounds"))
os.makedirs(OUT, exist_ok=True)

def sweep(f0, f1, k, amp, decay):
    """A pitched body whose frequency glides f0 -> f1 at rate k, decaying at `decay`.
    Uses the integral of the instantaneous frequency so the sweep is phase-correct."""
    phase = "2*PI*(%g*t + %g*(1-exp(-%g*t))/%g)" % (f1, f0 - f1, k, k)
    return "%g*sin(%s)*exp(-%g*t)" % (amp, phase, decay)

def noise(amp, decay):
    return "%g*random(1)*exp(-%g*t)" % (amp, decay)

def tone(f, amp, decay):
    return "%g*sin(2*PI*%g*t)*exp(-%g*t)" % (amp, f, decay)

def gated(expr, t0, t1):
    return "(%s)*between(t,%g,%g)" % (expr, t0, t1)

def build(name, layers, dur, post="", gain=1.0):
    """layers: list of (expr, filterchain). Each becomes its own lavfi input so it can
    be filtered independently, then they are mixed."""
    cmd = ["ffmpeg", "-v", "error"]
    for expr, _ in layers:
        cmd += ["-f", "lavfi", "-i", "aevalsrc='%s':d=%g:s=44100" % (expr, dur)]
    parts, labels = [], []
    for i, (_, filt) in enumerate(layers):
        chain = filt if filt else "anull"
        parts.append("[%d]%s[a%d]" % (i, chain, i))
        labels.append("[a%d]" % i)
    fc = ";".join(parts) + ";" + "".join(labels) + \
         "amix=inputs=%d:normalize=0" % len(layers)
    if post:
        fc += "," + post
    fc += ",volume=%g,alimiter=limit=0.92[o]" % gain
    path = os.path.join(OUT, name + ".wav")
    cmd += ["-filter_complex", fc, "-map", "[o]", "-ac", "1", "-y", path]
    subprocess.run(cmd, check=True)
    return path

ROOM_TIGHT = "aecho=0.9:0.22:11:0.10"
ROOM_SMALL = "aecho=0.88:0.32:19|31:0.16|0.08"

# ---- LAND: a sticker meeting paper. 3 variants, subtly different woods. -------
for i, (f0, f1, k, dec, tr_dec) in enumerate(
        [(430, 158, 44, 26, 210), (470, 172, 50, 29, 240), (395, 146, 40, 23, 185)], 1):
    build("land-%d" % i, [
        (sweep(f0, f1, k, 0.62, dec), "lowpass=f=4200"),
        (sweep(f0 * 2.7, f1 * 2.4, k * 1.3, 0.15, dec * 1.6), "bandpass=f=1600:width_type=o:w=2"),
        (noise(0.5, tr_dec), "highpass=f=1400,lowpass=f=6500"),
    ], 0.30, post=ROOM_TIGHT, gain=0.95)

# ---- STAMP: weight. sub + body + paper contact. 2 variants. ------------------
for i, (f0, sub, dec) in enumerate([(305, 92, 19), (280, 84, 17)], 1):
    build("stamp-%d" % i, [
        (tone(sub, 0.72, 13), "lowpass=f=200"),
        (sweep(f0, 105, 34, 0.6, dec), "lowpass=f=3200"),
        (noise(0.55, 130), "highpass=f=900,lowpass=f=5200"),
        (noise(0.22, 46), "highpass=f=3800"),          # paper crinkle tail
    ], 0.5, post=ROOM_TIGHT, gain=0.95)

# ---- PRESS: tight, dry, crisp -----------------------------------------------
build("press", [
    (sweep(980, 420, 120, 0.4, 95), "lowpass=f=6000"),
    (noise(0.4, 300), "highpass=f=2200,lowpass=f=7500"),
], 0.10, gain=0.8)

# ---- TICK: countdown, dry wood ----------------------------------------------
build("tick", [
    (sweep(760, 360, 70, 0.55, 40), "lowpass=f=4800"),
    (tone(1180, 0.16, 60), "bandpass=f=1180:width_type=o:w=1.5"),
    (noise(0.32, 220), "highpass=f=1800,lowpass=f=6800"),
], 0.28, post=ROOM_TIGHT, gain=0.9)

# ---- PEEL: sticker lifting — rising filtered noise ---------------------------
build("peel", [
    ("0.55*random(1)*sin(PI*t/0.34)*(0.35+1.9*t)", "highpass=f=800,lowpass=f=7000"),
    (sweep(240, 900, -7, 0.14, 6), "bandpass=f=1400:width_type=o:w=2"),
], 0.34, gain=0.6)

# ---- UNLOCK: stamp body + a warm rising fifth (two notes, not a jingle) ------
build("unlock", [
    (tone(120, 0.6, 17), "lowpass=f=240"),
    (sweep(300, 120, 30, 0.45, 20), "lowpass=f=3000"),
    (noise(0.45, 150), "highpass=f=900,lowpass=f=5000"),
    (gated(tone(587.33, 0.30, 7), 0.10, 0.24), "anull"),   # D5
    (gated(tone(880.00, 0.34, 5), 0.24, 0.85), "anull"),   # A5
], 0.9, post=ROOM_SMALL, gain=0.95)

# ---- REWARD STAMP: the big one ----------------------------------------------
build("reward-stamp", [
    (tone(68, 0.85, 11), "lowpass=f=170"),
    (sweep(262, 88, 24, 0.62, 15), "lowpass=f=2600"),
    (noise(0.62, 105), "highpass=f=700,lowpass=f=5600"),
    (gated(tone(523.25, 0.18, 5) + "+" + tone(783.99, 0.14, 5.5), 0.06, 1.1), "anull"),
    (gated(tone(1567.98, 0.09, 7), 0.10, 1.1), "highpass=f=1200"),
], 1.15, post=ROOM_SMALL, gain=1.0)

# ---- CHIP: tiny confetti ticks, 3 variants ----------------------------------
for i, f in enumerate([2100, 2650, 1750], 1):
    build("chip-%d" % i, [
        (sweep(f, f * 0.45, 150, 0.30, 150), "bandpass=f=%g:width_type=o:w=2" % f),
        (noise(0.22, 420), "highpass=f=3000"),
    ], 0.09, gain=0.55)

# ---- SLIDE: screen transition, air moving -----------------------------------
build("slide", [
    ("0.45*random(1)*sin(PI*t/0.38)", "highpass=f=380,lowpass=f=2600"),
    ("0.3*random(1)*sin(PI*t/0.38)", "highpass=f=1800,lowpass=f=5200,adelay=60"),
], 0.4, gain=0.5)


# ---- BALANCE ----------------------------------------------------------------
# Peak targets per cue, chosen by role: a cue you hear 40 times a day sits well
# below the one you hear once. Without this the kit is a level lottery.
TARGETS = {
    "press": -9.0, "land": -10.0, "chip": -13.5, "tick": -10.0,
    "stamp": -8.0, "unlock": -7.0, "reward-stamp": -5.0,
    "peel": -11.0, "slide": -13.0,
}

def role(fname):
    stem = fname[:-4]
    for k in sorted(TARGETS, key=len, reverse=True):
        if stem == k or stem.startswith(k + "-"):
            return k
    return None

def peak_db(path):
    out = subprocess.run(["ffmpeg", "-i", path, "-af", "volumedetect", "-f", "null", "/dev/null"],
                         capture_output=True, text=True).stderr
    for line in out.splitlines():
        if "max_volume" in line:
            return float(line.split("max_volume:")[1].strip().split()[0])
    return None

for f in sorted(os.listdir(OUT)):
    if not f.endswith(".wav"):
        continue
    r = role(f)
    if r is None:
        continue
    p = os.path.join(OUT, f)
    cur = peak_db(p)
    if cur is None:
        continue
    delta = TARGETS[r] - cur
    if abs(delta) < 0.25:
        continue
    tmp = p + ".tmp.wav"
    subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-af",
                    "volume=%.2fdB,alimiter=limit=0.95" % delta, "-y", tmp], check=True)
    os.replace(tmp, p)

files = sorted(f for f in os.listdir(OUT) if f.endswith(".wav"))
print("%-18s %8s %8s" % ("file", "dur", "peak"))
for f in files:
    p = os.path.join(OUT, f)
    d = subprocess.run(["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
                        "-of", "csv=p=0", p], capture_output=True, text=True).stdout.strip()
    vd = subprocess.run(["ffmpeg", "-i", p, "-af", "volumedetect", "-f", "null", "/dev/null"],
                        capture_output=True, text=True).stderr
    peak = next((l.split("max_volume:")[1].strip() for l in vd.splitlines()
                 if "max_volume" in l), "?")
    print("%-18s %8.3f %8s" % (f, float(d), peak))
