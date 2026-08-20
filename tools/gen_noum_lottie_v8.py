"""Generate V8 "Sticker Bold" Lottie assets for Noum.

Sticker motion vocabulary: things LAND, STAMP and PEEL — they never breathe or
glow (that was the rejected glossy language). Pure shape layers, no rasters.

Gotchas encoded here (learned the hard way):
  * layers[0] renders ON TOP — order back-to-front reversed.
  * layer-level p/s need THREE components; group transforms take two.
  * a stamped shadow must appear AT CONTACT, never travel with the object.
"""
import json, math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "Noum", "Resources", "Lottie")
OUT = os.path.normpath(OUT)

INK    = [0.102, 0.090, 0.149]
DEEP   = [0.055, 0.043, 0.094]
CREAM  = [1.000, 0.965, 0.914]
BLUE   = [0.231, 0.427, 0.961]
BLUE_D = [0.137, 0.282, 0.784]
PURPLE = [0.545, 0.361, 0.965]
GOLD   = [1.000, 0.773, 0.192]
GOLD_D = [0.878, 0.604, 0.000]
PRESS  = [1.000, 0.353, 0.239]

def ease(o=0.62, i=0.28):
    return {"o": {"x": [o], "y": [0]}, "i": {"x": [i], "y": [1]}}

def kf(t, s, e=True):  # every keyframe MUST carry easing — a bare t=0 keyframe kills the layer
    d = {"t": t, "s": s if isinstance(s, list) else [s]}
    if e: d.update(ease())
    return d

def anim(k): return {"a": 1, "k": k}
def static(v): return {"a": 0, "k": v}

def tr(pos=(0, 0), scale=100, rot=0, op=100, anchor=(0, 0)):
    return {"ty": "tr",
            "p": pos if isinstance(pos, dict) else static(list(pos)),
            "a": static(list(anchor)),
            "s": scale if isinstance(scale, dict) else static([scale, scale]),
            "r": rot if isinstance(rot, dict) else static(rot),
            "o": op if isinstance(op, dict) else static(op),
            "sk": static(0), "sa": static(0), "nm": "Transform"}

def layer(nm, shapes, ks=None, ind=1, op=72):
    return {"ddd": 0, "ind": ind, "ty": 4, "nm": nm, "sr": 1,
            "ks": ks or {"o": static(100), "r": static(0), "p": static([256, 256, 0]),
                         "a": static([0, 0, 0]), "s": static([100, 100, 100])},
            "ao": 0, "shapes": shapes, "ip": 0, "op": op, "st": 0, "bm": 0}

def comp(nm, layers, w=512, h=512, fr=60, op=72):
    return {"v": "5.9.0", "fr": fr, "ip": 0, "op": op, "w": w, "h": h,
            "nm": nm, "ddd": 0, "assets": [], "layers": layers, "markers": []}

def rect(w, h, r, fill=None, stroke=None, sw=10):
    it = [{"ty": "rc", "p": static([0, 0]), "s": static([w, h]),
           "r": static(r), "d": 1, "nm": "R"}]
    if fill:   it.append({"ty": "fl", "c": static(fill + [1]), "o": static(100), "r": 1, "nm": "F"})
    if stroke: it.append({"ty": "st", "c": static(stroke + [1]), "o": static(100),
                          "w": static(sw), "lc": 2, "lj": 2, "nm": "S"})
    return it

def ell(size, fill=None, stroke=None, sw=8, pos=(0, 0)):
    it = [{"ty": "el", "p": static(list(pos)), "s": static([size, size]), "d": 1, "nm": "E"}]
    if fill:   it.append({"ty": "fl", "c": static(fill + [1]), "o": static(100), "r": 1, "nm": "F"})
    if stroke: it.append({"ty": "st", "c": static(stroke + [1]), "o": static(100),
                          "w": static(sw), "lc": 2, "lj": 2, "nm": "S"})
    return it

def grp(items, transform=None, nm="G"):
    return {"ty": "gr", "it": items + [transform or tr()], "nm": nm}

# ---------------------------------------------------------------- 1. sticker land
def build_land(name, face, w=300, h=180, land=14):
    """A sticker drops onto the page, rotation settling, shadow appearing at contact."""
    # shadow: no travel — it simply exists at the contact frame
    shadow = layer("shadow", [grp(rect(w, h, 26, fill=DEEP), tr(pos=(0, 7), op=55))],
                   ks={"o": anim([kf(land - 1, 0), kf(land + 3, 55)]),
                       "r": static(-2), "p": static([256, 256, 0]),
                       "a": static([0, 0, 0]), "s": static([100, 100, 100])}, ind=2)
    sticker = layer("sticker", [
        grp(rect(w, h, 26, fill=face), tr(), "face"),
        grp(rect(w, h, 26, stroke=CREAM, sw=10), tr(), "keyline"),
    ], ks={
        "o": anim([kf(0, 0), kf(6, 100)]),
        "r": anim([kf(0, -7), kf(land, -1.2), kf(land + 8, -2)]),
        "p": anim([kf(0, [256, 186, 0]), kf(land, [256, 256, 0])]),
        "a": static([0, 0, 0]),
        "s": anim([kf(0, [107, 107, 100]), kf(land, [98, 98, 100]),
                   kf(land + 9, [100, 100, 100])]),
    }, ind=1)
    return comp(name, [sticker, shadow], op=48)

# ------------------------------------------------------------- 2. reward stamp
def build_reward_stamp():
    """Ground is already gold in-app; the die-cut disc STAMPS in, chips scatter."""
    layers = []
    chips = []
    cols = [BLUE, PURPLE, GOLD_D, CREAM, PRESS]
    n = 16
    for i in range(n):
        a = (i / n) * math.tau + (0.21 if i % 2 else 0)
        d = 168 if i % 3 else 214
        x1, y1 = math.cos(a) * d, math.sin(a) * d
        t0 = 12 + (i % 4) * 2
        s = 24 if i % 3 == 0 else 15
        chips.append(layer("chip%d" % i, [grp(
            rect(s, s * 1.5, s * 0.34, fill=cols[i % len(cols)]),
            tr(pos=anim([kf(t0, [0, 0]), kf(t0 + 30, [x1, y1])]),
               scale=anim([kf(t0, [0, 0]), kf(t0 + 7, [112, 112]), kf(t0 + 30, [74, 74])]),
               rot=anim([kf(t0, 0), kf(t0 + 30, 170 if i % 2 else -170)]),
               op=anim([kf(t0, 0), kf(t0 + 4, 100), kf(t0 + 24, 100),
                        kf(t0 + 36, 0)])))], ind=20 + i))
    # the die-cut disc: hard stamp with a rotation kick
    disc = layer("disc", [
        grp(ell(220, fill=CREAM), tr(), "face"),
        grp(ell(220, stroke=INK, sw=12), tr(), "keyline"),
        grp(ell(188, stroke=INK, sw=3), tr(), "registration"),
    ], ks={"o": anim([kf(6, 0), kf(11, 100)]),
           "r": anim([kf(6, -4), kf(16, 0.8), kf(24, 0)]),
           "p": static([256, 256, 0]), "a": static([0, 0, 0]),
           "s": anim([kf(6, [152, 152, 100]), kf(16, [94, 94, 100]),
                      kf(26, [100, 100, 100])])}, ind=1)
    shadow = layer("disc shadow", [grp(ell(220, fill=DEEP), tr(pos=(0, 9), op=45))],
                   ks={"o": anim([kf(14, 0), kf(18, 45)]), "r": static(0),
                       "p": static([256, 256, 0]), "a": static([0, 0, 0]),
                       "s": static([100, 100, 100])}, ind=2)
    # layers[0] on top: chips above the disc, shadow last
    layers = chips + [disc, shadow]
    return comp("noum-reward-stamp", layers, op=60)

# ------------------------------------------------------------------ 3. unlock
def build_unlock():
    """A locked slot fills with colour and a seal stamps on — the path unlock."""
    ring = []
    for i, t0 in enumerate([10, 18]):
        ring.append(layer("tick%d" % i, [grp(
            ell(200, stroke=CREAM, sw=5),
            tr(scale=anim([kf(t0, [56, 56]), kf(t0 + 26, [150, 150])]),
               op=anim([kf(t0, 0), kf(t0 + 5, 55), kf(t0 + 26, 0)])))], ind=10 + i))
    seal = layer("seal", [
        grp(ell(78, fill=GOLD), tr(), "face"),
        grp(ell(78, stroke=CREAM, sw=8), tr(), "keyline"),
    ], ks={"o": anim([kf(20, 0), kf(25, 100)]),
           "r": anim([kf(20, -12), kf(30, 3), kf(38, 0)]),
           "p": static([336, 190, 0]), "a": static([0, 0, 0]),
           "s": anim([kf(20, [40, 40, 100]), kf(30, [116, 116, 100]),
                      kf(40, [100, 100, 100])])}, ind=1)
    card = layer("card", [
        grp(rect(300, 180, 26, fill=BLUE), tr(), "face"),
        grp(rect(300, 180, 26, stroke=CREAM, sw=10), tr(), "keyline"),
    ], ks={"o": anim([kf(4, 0), kf(12, 100)]), "r": static(0),
           "p": static([256, 256, 0]), "a": static([0, 0, 0]),
           "s": anim([kf(4, [92, 92, 100]), kf(14, [104, 104, 100]),
                      kf(24, [100, 100, 100])])}, ind=2)
    slot = layer("slot", [grp(rect(300, 180, 26, stroke=CREAM, sw=10),
                              tr(op=static(35)))],
                 ks={"o": anim([kf(0, 100), kf(12, 0)]), "r": static(0),
                     "p": static([256, 256, 0]), "a": static([0, 0, 0]),
                     "s": static([100, 100, 100])}, ind=3)
    shadow = layer("shadow", [grp(rect(300, 180, 26, fill=DEEP), tr(pos=(0, 7), op=55))],
                   ks={"o": anim([kf(12, 0), kf(16, 55)]), "r": static(0),
                       "p": static([256, 256, 0]), "a": static([0, 0, 0]),
                       "s": static([100, 100, 100])}, ind=4)
    return comp("noum-unlock-stamp", [seal] + ring + [card, slot, shadow], op=60)

os.makedirs(OUT, exist_ok=True)
built = [
    ("noum-sticker-land-blue", build_land("noum-sticker-land-blue", BLUE)),
    ("noum-sticker-land-gold", build_land("noum-sticker-land-gold", GOLD)),
    ("noum-reward-stamp", build_reward_stamp()),
    ("noum-unlock-stamp", build_unlock()),
]
for name, doc in built:
    p = os.path.join(OUT, name + ".json")
    with open(p, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    print("%-26s %5.1f KB  layers=%d" % (name, os.path.getsize(p) / 1024, len(doc["layers"])))
