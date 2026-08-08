#!/usr/bin/env python3
"""Bring a .glb under Roblox's triangle limit, keeping its texture.

The sibling of tools/simplify-mesh.py, which does the same for an .obj. This
one exists because .glb carries its texture INSIDE the file, and that is the
whole reason we ask for .glb -- so a simplifier that drops it would undo the
point of the format.

The algorithm is the same and so is the trade: vertices are grouped into a 3D
grid and each cell collapses to one point. For an organic shape -- a rounded
plush -- that keeps the silhouette, which is all you can see at the distance
these are looked at from.

THE UVs TRAVEL, averaged the same way as the positions. On a seam that smudges
slightly, because two vertices that sat on opposite sides of the texture map end
up at their average. A slightly shifted seam is far less visible than the
alternative, which is no UVs and a grey model forever.

Usage:  python3 tools/simplify-glb.py in.glb out.glb 10000
"""

import sys

import numpy as np
import trimesh

src, dst, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])

#: How finely the texture map is divided when deciding whether two vertices may
#: merge. 1/64 means a 64x64 grid over the atlas: features further apart than
#: that on the texture never collapse into each other.
#:
#: Finer keeps more detail and removes fewer triangles. If a model cannot reach
#: its limit, this is the knob -- and the script says so rather than quietly
#: handing back something too big.
UV_CELL = 1.0 / 64.0

mesh = trimesh.load(src, process=False, force="mesh")

uv = None
if getattr(mesh.visual, "uv", None) is not None and len(mesh.visual.uv) == len(mesh.vertices):
    uv = np.asarray(mesh.visual.uv, dtype=float)

# The picture itself, kept aside so it can be reattached to the result. Losing
# it here would be losing the reason we wanted a .glb.
material = getattr(mesh.visual, "material", None)

print(f"in : {len(mesh.faces)} triangles, {len(mesh.vertices)} vertices, "
      f"UVs: {'yes' if uv is not None else 'NO'}, "
      f"texture: {'yes' if material is not None else 'no'}")

if uv is None:
    print("  !! no UVs -- the result cannot be textured. Simplifying anyway.")


def cluster(cell):
    keys = np.floor(mesh.vertices / cell).astype(np.int64)

    if uv is not None:
        # THE UV GOES IN THE KEY, not just into the average afterwards.
        #
        # This is the fix for a chick that came out uniformly cream. Two
        # vertices can sit right next to each other in space and land far apart
        # on the texture -- an eye and the fluff around it, a beak and the face
        # behind it. Merging those and averaging their UVs walks the eye's UVs
        # off the eye, and the small feature is gone. No error, no warning; the
        # mesh is valid, the texture is untouched, and the bird has no face.
        #
        # With the UV in the key, vertices only merge when they are close in
        # BOTH: same place, same patch of texture. Islands survive.
        keys = np.concatenate([keys, np.floor(uv / UV_CELL).astype(np.int64)], axis=1)

    _, inverse, counts = np.unique(keys, axis=0, return_inverse=True, return_counts=True)

    verts = np.zeros((counts.shape[0], 3))
    np.add.at(verts, inverse, mesh.vertices)
    verts /= counts[:, None]

    merged_uv = None
    if uv is not None:
        merged_uv = np.zeros((counts.shape[0], 2))
        np.add.at(merged_uv, inverse, uv)
        merged_uv /= counts[:, None]

    faces = inverse[mesh.faces]
    # A triangle whose corners collapsed into the same cell is not a triangle.
    good = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])
    faces = faces[good]

    visual = None
    if merged_uv is not None:
        visual = trimesh.visual.TextureVisuals(uv=merged_uv, material=material)

    # process=False: letting trimesh re-merge vertices throws the UVs away.
    return trimesh.Trimesh(vertices=verts, faces=faces, visual=visual, process=False)


# Binary search for the coarsest grid that still fits under the limit: the
# relationship between cell size and triangle count is monotonic but not
# something worth solving in closed form.
size = mesh.extents.max()
lo, hi = size / 500, size / 4
best = None

for _ in range(40):
    mid = (lo + hi) / 2
    trial = cluster(mid)
    if len(trial.faces) > limit:
        lo = mid
    else:
        hi = mid
        best = trial

best = best if best is not None else cluster(hi)

# Keeping UV islands apart puts a FLOOR under how few triangles are reachable,
# and handing back something over the limit for the uploader to reject is the
# kind of quiet failure this whole toolchain exists to stop.
if len(best.faces) > limit:
    sys.exit(
        f"Could not get under {limit} triangles without merging across the "
        f"texture map.\nThe best was {len(best.faces)}. Raising UV_CELL "
        f"(currently 1/{round(1 / UV_CELL)}) trades detail for triangles, but "
        "re-exporting\nthe model at a lower density keeps both -- prefer that."
    )

best.export(dst)

kept = 100 * len(best.faces) / len(mesh.faces)
print(f"out: {len(best.faces)} triangles, {len(best.vertices)} vertices "
      f"({kept:.0f}% of the original) -> {dst}")
print("     Now check the colours survived, which triangle counts do not show:")
print(f"       python3 tools/sample-colors.py {src} {dst}")
