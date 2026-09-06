"""Generate the canonical Noum cold-launch Lottie handoff.

The shipping view mirrors these keyframes natively in SwiftUI so the app does
not add a one-off animation runtime on its most performance-sensitive route.
"""

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "Noum" / "Resources" / "Lottie" / "noum-splash-conversation.json"

WIDTH = 393
HEIGHT = 852
FRAMERATE = 60
OUT_FRAME = 315  # 5.25 seconds

WHITE = [1.0, 1.0, 1.0]
ORANGE = [0.992, 0.298, 0.012]
ORANGE_EDGE = [0.992, 0.396, 0.024]
ORANGE_SHADOW = [0.929, 0.137, 0.008]
YELLOW = [0.992, 0.737, 0.024]
YELLOW_EDGE = [1.0, 0.918, 0.475]
YELLOW_SHADOW = [0.969, 0.545, 0.004]
FACE_YELLOW = [1.0, 0.839, 0.031]
INK = [0.663, 0.173, 0.008]


def static(value):
    return {"a": 0, "k": value}


def keyframe(frame, value, easing="ease-out"):
    curves = {
        "ease-out": (0.0, 0.0, 0.58, 1.0),
        "ease-in-out": (0.42, 0.0, 0.58, 1.0),
        "camera": (0.18, 0.0, 0.16, 1.0),
        "gentle": (0.22, 0.80, 0.32, 1.0),
    }
    x1, y1, x2, y2 = curves[easing]
    return {
        "t": frame,
        "s": value if isinstance(value, list) else [value],
        "o": {"x": [x1], "y": [y1]},
        "i": {"x": [x2], "y": [y2]},
    }


def animated(*frames):
    return {"a": 1, "k": list(frames)}


def shape_transform(position=(0, 0), scale=(100, 100), opacity=100):
    return {
        "ty": "tr",
        "p": static(list(position)),
        "a": static([0, 0]),
        "s": static(list(scale)),
        "r": static(0),
        "o": static(opacity),
        "sk": static(0),
        "sa": static(0),
        "nm": "Transform",
    }


def layer_transform(position, opacity=None, scale=None):
    return {
        "o": opacity or static(100),
        "r": static(0),
        "p": position if isinstance(position, dict) else static([*position, 0]),
        "a": static([0, 0, 0]),
        "s": scale or static([100, 100, 100]),
    }


def fill(color, name="Fill"):
    return {
        "ty": "fl",
        "c": static([*color, 1]),
        "o": static(100),
        "r": 1,
        "nm": name,
    }


def gradient_fill(stops, start, end, name="Gradient fill"):
    values = []
    for offset, color in stops:
        values.extend([offset, *color])

    # Explicit opaque stops keep the gradient consistent across Creator,
    # lottie-web, and native players that parse the optional alpha tail.
    for offset, _ in stops:
        values.extend([offset, 1])

    return {
        "ty": "gf",
        "o": static(100),
        "r": 1,
        "bm": 0,
        "g": {"p": len(stops), "k": static(values)},
        "s": static(list(start)),
        "e": static(list(end)),
        "t": 1,
        "nm": name,
    }


def stroke(color, width, name="Stroke"):
    return {
        "ty": "st",
        "c": static([*color, 1]),
        "o": static(100),
        "w": static(width),
        "lc": 2,
        "lj": 2,
        "nm": name,
    }


def bezier(vertices, closed, incoming=None, outgoing=None):
    incoming = incoming or [[0, 0] for _ in vertices]
    outgoing = outgoing or [[0, 0] for _ in vertices]
    return {
        "i": incoming,
        "o": outgoing,
        "v": vertices,
        "c": closed,
    }


def cubic_path(start, segments, closed=True):
    """Translate absolute cubic controls into Lottie's relative tangents.

    For a closed path, the final segment must end at `start`; that closing
    vertex is folded back into the first vertex rather than duplicated.
    """
    vertices = [list(start)]
    incoming = [[0, 0]]
    outgoing = [[0, 0]]

    for index, (control1, control2, end) in enumerate(segments):
        current = vertices[-1]
        outgoing[-1] = [control1[0] - current[0], control1[1] - current[1]]

        is_closing = closed and index == len(segments) - 1 and tuple(end) == tuple(start)
        if is_closing:
            incoming[0] = [control2[0] - start[0], control2[1] - start[1]]
        else:
            vertices.append(list(end))
            incoming.append([control2[0] - end[0], control2[1] - end[1]])
            outgoing.append([0, 0])

    return bezier(vertices, closed, incoming, outgoing)


def normalized_cubic_path(width, height, start, segments, closed=True):
    def point(value):
        return (value[0] * width - width / 2, value[1] * height - height / 2)

    return cubic_path(
        point(start),
        [(point(control1), point(control2), point(end)) for control1, control2, end in segments],
        closed=closed,
    )


def group(name, items, transform=None):
    return {
        "ty": "gr",
        "nm": name,
        "it": [*items, transform or shape_transform()],
    }


def shape_layer(name, shapes, transform, index):
    return {
        "ddd": 0,
        "ind": index,
        "ty": 4,
        "nm": name,
        "sr": 1,
        "ks": transform,
        "ao": 0,
        "shapes": shapes,
        "ip": 0,
        "op": OUT_FRAME,
        "st": 0,
        "bm": 0,
    }


def field_layer(name, color, index, opacity=None):
    rectangle = {
        "ty": "rc",
        "p": static([0, 0]),
        "s": static([WIDTH, HEIGHT]),
        "r": static(0),
        "d": 1,
        "nm": "Full field",
    }
    return shape_layer(
        name,
        [group("Field", [rectangle, fill(color)])],
        layer_transform((WIDTH / 2, HEIGHT / 2), opacity=opacity),
        index,
    )


def gradient_field_layer(name, stops, index, opacity=None):
    rectangle = {
        "ty": "rc",
        "p": static([0, 0]),
        "s": static([WIDTH, HEIGHT]),
        "r": static(0),
        "d": 1,
        "nm": "Full blended field",
    }
    return shape_layer(
        name,
        [
            group(
                "Conversation colour field",
                [
                    rectangle,
                    gradient_fill(
                        stops,
                        (-WIDTH / 2, -HEIGHT / 2),
                        (WIDTH / 2, HEIGHT / 2),
                        "Orange and yellow conversation gradient",
                    ),
                ],
            )
        ],
        layer_transform((WIDTH / 2, HEIGHT / 2), opacity=opacity),
        index,
    )


def path_shape(name, path):
    return {
        "ty": "sh",
        "ind": 0,
        "ks": static(path),
        "nm": name,
    }


def animated_path_shape(name, frames):
    return {
        "ty": "sh",
        "ind": 0,
        "ks": animated(
            *(keyframe(frame, [path], easing) for frame, path, easing in frames)
        ),
        "nm": name,
    }


def rear_mouth_path(openness):
    width = 160
    height = 176
    depth = 0.026 + (0.069 * openness)
    bottom_y = 0.343 + depth
    return normalized_cubic_path(
        width,
        height,
        (0.356, 0.343),
        [
            (
                (0.416, 0.343 + depth * 0.42),
                (0.574, 0.343 + depth * 0.52),
                (0.630, 0.343),
            ),
            (
                (0.606, 0.343 + depth * 0.86),
                (0.555, bottom_y),
                (0.494, bottom_y),
            ),
            (
                (0.430, bottom_y),
                (0.384, 0.343 + depth * 0.70),
                (0.356, 0.343),
            ),
        ],
    )


def front_silhouette_path(openness):
    width = 175
    height = 172
    lower_tip_x = 0.119 + (0.080 * openness)
    lower_tip_y = 0.364 + (0.017 * openness)
    upper_tip_x = 0.116 + (0.065 * openness)
    upper_tip_y = 0.364 - (0.010 * openness)
    return normalized_cubic_path(
        width,
        height,
        (0.053, 0.313),
        [
            ((0.165, 0.109), (0.329, 0.006), (0.539, 0.002)),
            ((0.793, -0.005), (0.972, 0.164), (0.994, 0.382)),
            ((1.016, 0.530), (0.963, 0.657), (0.854, 0.759)),
            ((0.779, 0.829), (0.766, 0.913), (0.860, 0.976)),
            ((0.882, 0.990), (0.878, 1.000), (0.851, 0.998)),
            ((0.759, 0.995), (0.675, 0.964), (0.588, 0.925)),
            ((0.345, 0.907), (0.133, 0.771), (0.026, 0.557)),
            ((0.026, 0.557), (0.002, 0.496), (0.002, 0.496)),
            ((-0.004, 0.477), (0.008, 0.463), (0.028, 0.459)),
            (
                (0.108, 0.444),
                (lower_tip_x - 0.018, 0.412),
                (lower_tip_x, lower_tip_y),
            ),
            (
                (lower_tip_x + 0.009, 0.365),
                (upper_tip_x + 0.018, 0.357),
                (upper_tip_x, upper_tip_y),
            ),
            ((upper_tip_x, upper_tip_y), (0.064, 0.334), (0.064, 0.334)),
            ((0.049, 0.331), (0.043, 0.321), (0.053, 0.313)),
        ],
    )


def rear_bubble_shapes():
    width = 160
    height = 176
    silhouette = normalized_cubic_path(
        width,
        height,
        (0.020, 0.971),
        [
            ((0.110, 0.883), (0.150, 0.811), (0.130, 0.741)),
            ((0.120, 0.680), (0.070, 0.620), (0.040, 0.558)),
            ((-0.020, 0.420), (-0.010, 0.270), (0.070, 0.160)),
            ((0.160, 0.030), (0.340, 0.000), (0.490, 0.000)),
            ((0.720, 0.000), (0.910, 0.120), (0.980, 0.310)),
            ((1.050, 0.520), (0.930, 0.740), (0.750, 0.870)),
            ((0.560, 1.000), (0.300, 1.020), (0.030, 1.000)),
            ((0.010, 1.000), (0.005, 0.987), (0.020, 0.971)),
        ],
    )
    left_eye = normalized_cubic_path(
        width,
        height,
        (0.286, 0.265),
        [((0.325, 0.202), (0.399, 0.202), (0.433, 0.265))],
        closed=False,
    )
    right_eye = normalized_cubic_path(
        width,
        height,
        (0.544, 0.265),
        [((0.581, 0.202), (0.657, 0.202), (0.692, 0.264))],
        closed=False,
    )
    # Lottie shape contents stack front-to-back, so facial details precede
    # the body group. This keeps Creator from painting the gradient over them.
    return [
        group(
            "Speaking mouth",
            [
                animated_path_shape(
                    "Rear speaking mouth",
                    [
                        (0, rear_mouth_path(0.22), "ease-in-out"),
                        (71, rear_mouth_path(0.22), "ease-in-out"),
                        (84, rear_mouth_path(1.00), "ease-in-out"),
                        (87, rear_mouth_path(1.00), "ease-in-out"),
                        (100, rear_mouth_path(0.38), "ease-in-out"),
                        (103, rear_mouth_path(0.38), "ease-in-out"),
                        (116, rear_mouth_path(0.88), "ease-in-out"),
                        (117, rear_mouth_path(0.88), "ease-in-out"),
                        (130, rear_mouth_path(0.22), "ease-in-out"),
                    ],
                ),
                fill(FACE_YELLOW, "Yellow face fill"),
            ],
        ),
        group(
            "Closed smiling eyes",
            [
                path_shape("Left closed eye", left_eye),
                path_shape("Right closed eye", right_eye),
                stroke(FACE_YELLOW, 4, "Yellow face stroke"),
            ],
        ),
        group(
            "Rear app-icon character",
            [
                path_shape("Organic rear speech bubble", silhouette),
                gradient_fill(
                    [
                        (0, ORANGE_EDGE),
                        (0.52, ORANGE),
                        (1, ORANGE_SHADOW),
                    ],
                    (-width / 2, -height / 2),
                    (width / 2, height / 2),
                    "Orange app-icon gradient",
                ),
                stroke(ORANGE_EDGE, 4, "Orange rim"),
            ],
        ),
    ]


def front_bubble_shapes():
    width = 175
    height = 172
    mouth_frames = [
        (0, front_silhouette_path(0.35), "ease-in-out"),
        (129, front_silhouette_path(0.35), "ease-in-out"),
        (142, front_silhouette_path(1.00), "ease-in-out"),
        (145, front_silhouette_path(1.00), "ease-in-out"),
        (158, front_silhouette_path(0.45), "ease-in-out"),
        (161, front_silhouette_path(0.45), "ease-in-out"),
        (175, front_silhouette_path(0.90), "ease-in-out"),
        (176, front_silhouette_path(0.90), "ease-in-out"),
        (189, front_silhouette_path(0.35), "ease-in-out"),
    ]
    eye = {
        "ty": "el",
        "p": static([(0.321 - 0.5) * width, (0.272 - 0.5) * height]),
        "s": static([0.124 * width, 0.120 * height]),
        "d": 1,
        "nm": "Single app-icon eye",
    }
    return [
        group("Eye", [eye, fill(INK, "Eye fill")]),
        group(
            "Front app-icon character",
            [
                animated_path_shape("Speaking mouth silhouette", mouth_frames),
                gradient_fill(
                    [
                        (0, YELLOW_EDGE),
                        (0.52, YELLOW),
                        (1, YELLOW_SHADOW),
                    ],
                    (-width / 2, -height / 2),
                    (width / 2, height / 2),
                    "Yellow app-icon gradient",
                ),
                stroke(YELLOW_EDGE, 4, "Yellow rim"),
            ],
        ),
        group(
            "Front app-icon shadow",
            [
                animated_path_shape("Speaking mouth shadow silhouette", mouth_frames),
                fill(INK, "Warm shadow fill"),
            ],
            transform=shape_transform(
                position=(3, 5),
                scale=(103, 103),
                opacity=12,
            ),
        ),
    ]


def bubble_layer(name, shapes, index, position, scale, opacity):
    return shape_layer(
        name,
        shapes,
        layer_transform(position, opacity=opacity, scale=scale),
        index,
    )


def wordmark_layer(index):
    return {
        "ddd": 0,
        "ind": index,
        "ty": 5,
        "nm": "wordmark.noum",
        "sr": 1,
        "ks": layer_transform(
            (WIDTH / 2, HEIGHT / 2 + 16),
            opacity=animated(
                keyframe(246, 0, "ease-in-out"),
                keyframe(285, 100, "ease-out"),
            ),
            scale=animated(
                keyframe(246, [82, 82, 100], "ease-in-out"),
                keyframe(285, [100, 100, 100], "ease-out"),
            ),
        ),
        "ao": 0,
        "t": {
            "d": {
                "k": [
                    {
                        "s": {
                            "s": 120,
                            "f": "Figtree-ExtraBold",
                            "t": "noum",
                            "j": 2,
                            "tr": -13,
                            "lh": 128,
                            "ls": 0,
                            "fc": WHITE,
                        },
                        "t": 0,
                    }
                ]
            },
            "p": {},
            "m": {"g": 1, "a": static([0, 0])},
            "a": [],
        },
        "ip": 0,
        "op": OUT_FRAME,
        "st": 0,
        "bm": 0,
    }


def build():
    mark_width = min(WIDTH * 0.68, 268)
    mark_height = mark_width * 0.804
    mark_origin = ((WIDTH - mark_width) / 2, (HEIGHT - mark_height) / 2)
    conversation_focus = (
        mark_origin[0] + mark_width * 0.43,
        mark_origin[1] + mark_height * 0.44,
    )
    camera_center = (WIDTH / 2, HEIGHT / 2)

    def zoomed_position(position):
        return [
            camera_center[0]
            + (position[0] - conversation_focus[0]) * 5.20,
            camera_center[1]
            + (position[1] - conversation_focus[1]) * 5.20,
            0,
        ]

    orange_scale = animated(
        keyframe(0, [100, 100, 100]),
        keyframe(183, [100, 100, 100], "camera"),
        keyframe(246, [520, 520, 100], "camera"),
    )
    orange_position = animated(
        keyframe(0, [143, 406, 0]),
        keyframe(183, [143, 406, 0], "camera"),
        keyframe(246, zoomed_position((143, 406)), "camera"),
    )
    orange_opacity = animated(
        keyframe(0, 100),
        keyframe(183, 100, "camera"),
        keyframe(246, 4, "camera"),
        keyframe(285, 0, "ease-out"),
    )

    yellow_scale = animated(
        keyframe(0, [100, 100, 100]),
        keyframe(183, [100, 100, 100], "camera"),
        keyframe(246, [520, 520, 100], "camera"),
    )
    yellow_position = animated(
        keyframe(0, [243, 448, 0]),
        keyframe(183, [243, 448, 0], "camera"),
        keyframe(246, zoomed_position((243, 448)), "camera"),
    )
    yellow_opacity = animated(
        keyframe(42, 0, "ease-in-out"),
        keyframe(72, 100, "ease-in-out"),
        keyframe(183, 100, "camera"),
        keyframe(246, 4, "camera"),
        keyframe(285, 0, "ease-out"),
    )

    conversation_field_opacity = animated(
        keyframe(183, 0, "camera"),
        keyframe(246, 100, "camera"),
    )

    layers = [
        wordmark_layer(1),
        bubble_layer(
            "bubble.yellow",
            front_bubble_shapes(),
            2,
            yellow_position,
            yellow_scale,
            yellow_opacity,
        ),
        bubble_layer(
            "bubble.orange",
            rear_bubble_shapes(),
            3,
            orange_position,
            orange_scale,
            orange_opacity,
        ),
        gradient_field_layer(
            "takeover.conversation-gradient",
            [
                (0.00, ORANGE_SHADOW),
                (0.28, ORANGE),
                (0.50, ORANGE_EDGE),
                (0.72, YELLOW_SHADOW),
                (0.88, YELLOW),
                (1.00, YELLOW_EDGE),
            ],
            4,
            opacity=conversation_field_opacity,
        ),
        field_layer("background.white", WHITE, 5),
    ]

    return {
        "v": "5.9.0",
        "fr": FRAMERATE,
        "ip": 0,
        "op": OUT_FRAME,
        "w": WIDTH,
        "h": HEIGHT,
        "nm": "noum-splash-conversation",
        "ddd": 0,
        "assets": [],
        "fonts": {
            "list": [
                {
                    "fName": "Figtree-ExtraBold",
                    "fFamily": "Figtree",
                    "fStyle": "ExtraBold",
                    "ascent": 74.0,
                }
            ]
        },
        "layers": layers,
        "markers": [
            {"tm": 0, "cm": "first-bubble", "dr": 42},
            {"tm": 42, "cm": "second-bubble", "dr": 29},
            {"tm": 71, "cm": "mouth-conversation", "dr": 112},
            {"tm": 183, "cm": "conversation-zoom", "dr": 63},
            {"tm": 246, "cm": "wordmark", "dr": 69},
        ],
        "meta": {
            "g": "Noum / LottieFiles Creator handoff",
            "a": "OpenAI Codex",
            "k": "splash,conversation,brand,one-shot",
        },
    }


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", encoding="utf-8") as handle:
        json.dump(build(), handle, separators=(",", ":"))
        handle.write("\n")
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({OUTPUT.stat().st_size / 1024:.1f} KB)")
