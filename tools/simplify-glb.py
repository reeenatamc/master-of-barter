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

best.export(dst)

kept = 100 * len(best.faces) / len(mesh.faces)
print(f"out: {len(best.faces)} triangles, {len(best.vertices)} vertices "
      f"({kept:.0f}% of the original) -> {dst}")
print("     LOOK AT IT before uploading. Silhouette is what this preserves; "
      "detail is what it spends.")
