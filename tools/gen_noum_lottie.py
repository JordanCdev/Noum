"""Generate brand-exact Lottie JSON for Noum V6.1 moments.

Pure shape layers (ty:4) only — no embedded rasters, no illustration, fully
recolourable at runtime via lottie-ios keypaths. Palette is V6.1.
"""
import json, math, os

OUT = os.path.dirname(os.path.abspath(__file__))

GOLD_L = [0.996, 0.878, 0.545]
GOLD   = [0.969, 0.655, 0.180]
GOLD_D = [0.851, 0.400, 0.059]
BLUE   = [0.298, 0.576, 0.941]
BLUE_D = [0.122, 0.325, 0.769]
VIOLET = [0.486, 0.361, 1.000]
WHITE  = [1.0, 1.0, 1.0]

def ease(v_out=0.66, v_in=0.35):
    return {"o": {"x": [v_out], "y": [0]}, "i": {"x": [v_in], "y": [1]}}

def kf(t, s, e=True):
    d = {"t": t, "s": s if isinstance(s, list) else [s]}
    if e:
        d.update(ease())
    return d

def anim(keys):
    return {"a": 1, "k": keys}

def static(v):
    return {"a": 0, "k": v}

def tr(pos=(0, 0), scale=100, rot=0, op=100, anchor=(0, 0)):
    return {"ty": "tr",
            "p": pos if isinstance(pos, dict) else static(list(pos)),
            "a": static(list(anchor)),
            "s": scale if isinstance(scale, dict) else static([scale, scale]),
            "r": rot if isinstance(rot, dict) else static(rot),
            "o": op if isinstance(op, dict) else static(op),
            "sk": static(0), "sa": static(0), "nm": "Transform"}

def layer(nm, shapes, ip=0, op=60, ks=None, ind=1):
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": nm, "sr": 1,
            "ks": ks or {"o": static(100), "r": static(0), "p": static([256, 256, 0]),
                          "a": static([0, 0, 0]), "s": static([100, 100, 100])},
            "ao": 0, "shapes": shapes, "ip": ip, "op": op, "st": 0, "bm": 0}

def comp(nm, layers, w=512, h=512, fr=60, op=60):
    return {"v": "5.9.0", "fr": fr, "ip": 0, "op": op, "w": w, "h": h,
            "nm": nm, "ddd": 0, "assets": [], "layers": layers, "markers": []}

def ellipse(size, fill=None, stroke=None, swidth=8, pos=(0, 0)):
    it = [{"ty": "el", "p": static(list(pos)), "s": static([size, size]),
           "d": 1, "nm": "Ellipse"}]
    if fill:
        it.append({"ty": "fl", "c": static(fill + [1]), "o": static(100),
                   "r": 1, "nm": "Fill"})
    if stroke:
        it.append({"ty": "st", "c": static(stroke + [1]), "o": static(100),
                   "w": static(swidth), "lc": 2, "lj": 2, "nm": "Stroke"})
    return it

def group(items, transform=None, nm="Group"):
    return {"ty": "gr", "it": items + [transform or tr()], "nm": nm}

# ---------------------------------------------------------------- 1. check draw
def build_check():
    """Gold disc pops in, white checkmark draws itself. The Rep-complete hero."""
    layers = []

    # contact shadow — grounds the disc
    layers.append(layer("shadow", [group(
        ellipse(196, fill=[0.118, 0.173, 0.314]) + [],
        tr(pos=(0, 96), scale=anim([kf(4, [0, 0]), kf(14, [104, 30]), kf(22, [92, 26])]),
           op=anim([kf(4, 0), kf(14, 18), kf(60, 14)])))], ind=1))

    # disc: overshoot pop
    disc_scale = anim([kf(2, [20, 20, 100]), kf(14, [118, 118, 100]), kf(24, [96, 96, 100]), kf(32, [100, 100, 100])])
    layers.append(layer("disc", [
        group(ellipse(200, fill=GOLD), tr(), "fill"),
        group(ellipse(200, stroke=WHITE, swidth=10), tr(), "rim"),
        # specular cap
        group([{"ty": "el", "p": static([0, -44]), "s": static([150, 74]), "d": 1, "nm": "E"},
               {"ty": "fl", "c": static(GOLD_L + [1]), "o": static(52), "r": 1, "nm": "F"}],
              tr(), "gloss"),
    ], ks={"o": anim([kf(2, 0), kf(8, 100)]), "r": static(0),
           "p": static([256, 256, 0]), "a": static([0, 0, 0]), "s": disc_scale}, ind=2))

    # checkmark: trim-path draw
    check_path = {"ty": "sh", "ind": 0, "nm": "check", "d": 1,
                  "ks": static({"i": [[0, 0], [0, 0], [0, 0]],
                                "o": [[0, 0], [0, 0], [0, 0]],
                                "v": [[-52, 4], [-14, 44], [58, -40]], "c": False})}
    layers.append(layer("check", [group([
        check_path,
        {"ty": "st", "c": static(WHITE + [1]), "o": static(100), "w": static(22),
         "lc": 2, "lj": 2, "nm": "Stroke"},
        {"ty": "tm", "s": static(0),
         "e": anim([kf(18, 0), kf(38, 100)]), "o": static(0), "m": 1, "nm": "Trim"},
    ], tr(), "checkgrp")], ind=3))

    # sparkle ring
    for i in range(8):
        a = i * math.pi / 4
        d0, d1 = 108, 168
        x0, y0 = math.cos(a) * d0, math.sin(a) * d0
        x1, y1 = math.cos(a) * d1, math.sin(a) * d1
        col = [GOLD_L, BLUE, VIOLET, GOLD][i % 4]
        t0 = 16 + i * 2
        layers.append(layer(f"spark{i}", [group(
            ellipse(18, fill=col),
            tr(pos=anim([kf(t0, [x0, y0]), kf(t0 + 22, [x1, y1])]),
               scale=anim([kf(t0, [0, 0]), kf(t0 + 10, [120, 120]), kf(t0 + 26, [0, 0])]),
               op=anim([kf(t0, 0), kf(t0 + 6, 100), kf(t0 + 26, 0)])))], ind=4 + i))

    # layers[0] renders on top: check above disc, shadow at the back
    shadow, disc, check = layers[0], layers[1], layers[2]
    sparks = layers[3:]
    return comp("noum-check-draw", [check] + sparks + [disc, shadow], op=60)

# ------------------------------------------------------------- 2. reward burst
def build_burst():
    """Radial particle burst in brand colours — the celebration moment."""
    layers = []
    cols = [GOLD, GOLD_L, BLUE, VIOLET, GOLD_D, BLUE_D]
    n = 22
    for i in range(n):
        a = (i / n) * math.tau + (0.19 if i % 2 else 0)
        dist = 150 if i % 3 else 205
        x1, y1 = math.cos(a) * dist, math.sin(a) * dist
        col = cols[i % len(cols)]
        t0 = 0 + (i % 5) * 2
        size = 26 if i % 3 == 0 else 16
        rot = anim([kf(t0, 0), kf(t0 + 34, 180 if i % 2 else -180)])
        layers.append(layer(f"p{i}", [group(
            # rounded rect confetti chip, not a circle — reads richer in motion
            [{"ty": "rc", "p": static([0, 0]), "s": static([size, size * 1.6]),
              "r": static(size * 0.35), "d": 1, "nm": "R"},
             {"ty": "fl", "c": static(col + [1]), "o": static(100), "r": 1, "nm": "F"}],
            tr(pos=anim([kf(t0, [0, 0]), kf(t0 + 34, [x1, y1])]),
               scale=anim([kf(t0, [0, 0]), kf(t0 + 8, [116, 116]), kf(t0 + 34, [72, 72])]),
               rot=rot,
               op=anim([kf(t0, 0), kf(t0 + 5, 100), kf(t0 + 26, 100), kf(t0 + 40, 0)])))],
            ind=i + 1))
    return comp("noum-reward-burst", layers, op=48)

# --------------------------------------------------------------- 3. node unlock
def build_unlock():
    """Ring expands, node floods with colour — the path-unlock beat."""
    layers = []
    # expanding rings
    for i, t0 in enumerate([0, 8]):
        layers.append(layer(f"ring{i}", [group(
            ellipse(120, stroke=BLUE, swidth=10),
            tr(scale=anim([kf(t0, [40, 40]), kf(t0 + 34, [180, 180])]),
               op=anim([kf(t0, 0), kf(t0 + 6, 70), kf(t0 + 34, 0)])))], ind=i + 1))
    # the node itself
    layers.append(layer("node", [
        group(ellipse(150, fill=BLUE_D), tr(pos=(0, 10)), "edge"),
        group(ellipse(150, fill=BLUE), tr(), "face"),
        group(ellipse(150, stroke=WHITE, swidth=9), tr(), "rim"),
        group([{"ty": "el", "p": static([0, -34]), "s": static([112, 56]), "d": 1, "nm": "E"},
               {"ty": "fl", "c": static(WHITE + [1]), "o": static(34), "r": 1, "nm": "F"}],
              tr(), "gloss"),
    ], ks={"o": anim([kf(6, 0), kf(12, 100)]), "r": static(0),
           "p": static([256, 256, 0]), "a": static([0, 0, 0]),
           "s": anim([kf(6, [60, 60, 100]), kf(20, [122, 122, 100]), kf(30, [100, 100, 100])])}, ind=3))
    # node on top, rings expanding behind it
    return comp("noum-node-unlock", [layers[2], layers[0], layers[1]], op=48)

for name, doc in [("noum-check-draw", build_check()),
                  ("noum-reward-burst", build_burst()),
                  ("noum-node-unlock", build_unlock())]:
    p = os.path.join(OUT, name + ".json")
    with open(p, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    print(name, "%.1f KB" % (os.path.getsize(p) / 1024), "layers=%d" % len(doc["layers"]))
