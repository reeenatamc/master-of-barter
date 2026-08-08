#!/usr/bin/env python3
"""Paint features onto a .glb's own texture, so the model carries them.

The chick arrived with its beak and eyes barely in the texture, and the first
answer was to build them out of parts from Config. That works and it does not
SCALE: every new squishy would need somebody to hand-place a face in fractions.
A model should arrive with its own face the way the butter arrives with its own
wrapper.

So this paints into the texture instead. Features are given as ellipsoids in
NORMALISED model space -- fractions of the model's own bounding box, centred, so
the same numbers describe the same spot on a model of any size. For every texel
the tool works out which 3D point it covers and paints the ones that fall inside
a feature.

Working from 3D rather than from texture coordinates is what makes it usable at
all: this atlas is scattered noise with no readable layout, and "the front of
the head" is meaningless in it. In 3D it is just a place.

Usage:  python3 tools/paint-features.py in.glb out.glb chick
"""

import sys

import numpy as np
import trimesh
from PIL import Image

BLACK = (26, 22, 26)
ORANGE = (238, 126, 30)

#: Named sets, because a face belongs to a kind of animal rather than to a file.
#: at/radii are fractions of the bounding box, measured from its centre;
#: -Z is the front, +Y is up.
FEATURES = {
    "chick": [
        ("eye left",   BLACK,  (-0.17, 0.14, -0.36), (0.075, 0.085, 0.075)),
        ("eye right",  BLACK,  (0.17, 0.14, -0.36),  (0.075, 0.085, 0.075)),
        ("beak",       ORANGE, (0.0, -0.02, -0.40),  (0.10, 0.075, 0.11)),
        ("foot left",  ORANGE, (-0.16, -0.44, -0.16), (0.11, 0.06, 0.15)),
        ("foot right", ORANGE, (0.16, -0.44, -0.16),  (0.11, 0.06, 0.15)),
    ],
}


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    src, dst, kind = sys.argv[1], sys.argv[2], sys.argv[3]

    if kind not in FEATURES:
        sys.exit(f"No feature set called {kind}. Known: {', '.join(FEATURES)}")

    mesh = trimesh.load(src, process=False, force="mesh")
    uv = getattr(mesh.visual, "uv", None)
    material = getattr(mesh.visual, "material", None)
    image = getattr(material, "image", None) or getattr(material, "baseColorTexture", None)

    if uv is None or image is None:
        sys.exit("This model has no UVs or no texture, so there is nothing to paint on.")

    uv = np.asarray(uv, dtype=float)
    verts = np.asarray(mesh.vertices, dtype=float)
    faces = np.asarray(mesh.faces)

    pixels = np.array(image.convert("RGB"))
    height, width = pixels.shape[:2]
    print(f"{len(faces)} triangles, {width}x{height} texture")

    # Normalised model space: fractions of the bounding box, centred. The same
    # numbers then describe the same spot whatever size the model came at.
    lo, hi = verts.min(axis=0), verts.max(axis=0)
    size = hi - lo
    normalised = (verts - (lo + hi) / 2) / size

    painted_total = 0
    for name, colour, at, radii in FEATURES[kind]:
        at = np.array(at)
        radii = np.array(radii)

        # Only triangles that come near the feature get rasterised. Without this
        # every triangle would be walked for every feature; with it, a handful
        # are. The margin covers a triangle whose corners straddle the shape.
        near = (np.abs(normalised - at) <= radii * 2.5).all(axis=1)
        candidates = np.where(near[faces].any(axis=1))[0]

        painted = 0
        for f in candidates:
            tri = faces[f]
            tri_uv = uv[tri]
            tri_xyz = normalised[tri]

            # The triangle's footprint in the texture, in whole pixels.
            u0 = max(int(np.floor(tri_uv[:, 0].min() * (width - 1))), 0)
            u1 = min(int(np.ceil(tri_uv[:, 0].max() * (width - 1))), width - 1)
            v0 = max(int(np.floor(tri_uv[:, 1].min() * (height - 1))), 0)
            v1 = min(int(np.ceil(tri_uv[:, 1].max() * (height - 1))), height - 1)
            if u1 < u0 or v1 < v0:
                continue

            us, vs = np.meshgrid(np.arange(u0, u1 + 1), np.arange(v0, v1 + 1))
            pu = us / (width - 1)
            pv = vs / (height - 1)

            # Barycentric coordinates: which point of the triangle each texel is,
            # and therefore -- by the same weights -- where it is in 3D.
            (ax, ay), (bx, by), (cx, cy) = tri_uv
            det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(det) < 1e-12:
                continue
            w0 = ((by - cy) * (pu - cx) + (cx - bx) * (pv - cy)) / det
            w1 = ((cy - ay) * (pu - cx) + (ax - cx) * (pv - cy)) / det
            w2 = 1.0 - w0 - w1

            inside = (w0 >= -0.002) & (w1 >= -0.002) & (w2 >= -0.002)
            if not inside.any():
                continue

            point = (
                w0[..., None] * tri_xyz[0]
                + w1[..., None] * tri_xyz[1]
                + w2[..., None] * tri_xyz[2]
            )
            # Inside the ellipsoid, in normalised space.
            hit = inside & ((((point - at) / radii) ** 2).sum(axis=-1) <= 1.0)
            if not hit.any():
                continue

            pixels[vs[hit], us[hit]] = colour
            painted += int(hit.sum())

        print(f"  {name:<11} {len(candidates):>6} triangles near it, {painted:>6} texels painted")
        painted_total += painted

    if painted_total == 0:
        sys.exit("Nothing was painted. The feature positions do not touch the surface.")

    # `baseColorTexture` is where a PBRMaterial keeps its picture. The first
    # version assigned to `.image`, which that class does not have -- so Python
    # made a brand new attribute that nothing reads, no error was raised, and the
    # file exported with its original texture. Painted six million texels into a
    # variable and shipped the input.
    #
    # So the write is CHECKED, not trusted. Same lesson as everywhere else here:
    # an assignment that raises nothing is not an assignment that took.
    painted_image = Image.fromarray(pixels)
    material.baseColorTexture = painted_image
    if np.asarray(material.baseColorTexture.convert("RGB")).sum() != pixels.sum():
        sys.exit("The painted texture did not stick to the material.")

    mesh.export(dst)
    print(f"\n{painted_total} texels painted -> {dst}")
    print("Check it landed where you meant:")
    print(f"  python3 tools/sample-colors.py {src} {dst}")


if __name__ == "__main__":
    main()
