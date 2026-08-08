#!/usr/bin/env python3
"""Sample a .glb's texture at every vertex and report what colours it lands on.

Written because simplifying a chick silently ate its orange beak and black eyes.
The mesh was fine, the texture was fine, the triangle count was fine, and the
model came out uniformly cream -- because collapsing vertices AVERAGES their
UVs, and a small feature is a small island on the texture map. Averaged into its
neighbours, the beak's UVs walked off the beak.

Nothing in the file says that happened. What says it is this: sample the texture
where the vertices actually point, before and after, and compare.

Usage:  python3 tools/sample-colors.py model.glb [another.glb ...]
"""

import sys
from collections import Counter

import numpy as np
import trimesh


def sample(path):
    mesh = trimesh.load(path, process=False, force="mesh")
    uv = getattr(mesh.visual, "uv", None)
    if uv is None:
        return None, "no UVs"

    material = getattr(mesh.visual, "material", None)
    image = getattr(material, "image", None) or getattr(material, "baseColorTexture", None)
    if image is None:
        return None, "no texture"

    pixels = np.asarray(image.convert("RGB"))
    height, width = pixels.shape[:2]

    # glTF UVs put the origin at the TOP left; image rows also start at the top,
    # so V maps straight to the row. Clamped rather than wrapped: a UV outside
    # 0..1 is a broken model, not a tiling one, and wrapping would hide it.
    u = np.clip((np.asarray(uv)[:, 0] * (width - 1)).astype(int), 0, width - 1)
    v = np.clip((np.asarray(uv)[:, 1] * (height - 1)).astype(int), 0, height - 1)
    return pixels[v, u], f"{len(uv)} vertices against a {width}x{height} texture"


def family(rgb):
    """Bucket a colour into something a person would name.

    Deliberately coarse. The question is never "what shade" -- it is "did the
    orange survive at all", and a histogram of 4,000 near-identical creams
    answers nothing.
    """
    r, g, b = (int(x) for x in rgb)
    if max(r, g, b) < 70:
        return "black / very dark"
    if r > 180 and g > 180 and b > 150:
        return "cream / white"
    if r > 150 and g < 150 and b < 110:
        return "orange / red"
    if b > r and b > g:
        return "blue"
    if g > r and g > b:
        return "green"
    return "other"


for path in sys.argv[1:]:
    colours, note = sample(path)
    print(f"\n=== {path} ===")
    if colours is None:
        print(f"  {note}")
        continue
    print(f"  {note}")
    tally = Counter(family(c) for c in colours)
    total = sum(tally.values())
    for name, count in tally.most_common():
        print(f"    {name:<20} {100 * count / total:5.1f}%   ({count})")
