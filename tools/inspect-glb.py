#!/usr/bin/env python3
"""Read a .glb and say what it will do once it is in Roblox.

Every question this answers cost us a round trip through Studio at least once:
how big it is, whether it busts the triangle budget, whether it carries its own
texture, and -- the expensive one -- which way is up. A model exported Z-up
looks identical in a file listing and arrives lying on its side.

Usage:  python3 tools/inspect-glb.py assets/whatever.glb
"""

import json
import struct
import sys

TRIANGLE_LIMIT = 10_000  # Roblox's cap for a single mesh.
TEXTURE_LIMIT = 1024     # Roblox scales anything bigger down to this.


def read_glb(path):
    """Split a .glb into its JSON chunk and its binary chunk."""
    raw = open(path, "rb").read()
    magic, _version, total = struct.unpack_from("<III", raw, 0)
    if magic != 0x46546C67:
        sys.exit(f"{path} is not a .glb (bad magic number)")

    meta, blob, off = None, None, 12
    while off < total:
        length, kind = struct.unpack_from("<II", raw, off)
        chunk = raw[off + 8 : off + 8 + length]
        if kind == 0x4E4F534A:
            meta = json.loads(chunk.decode("utf-8"))
        elif kind == 0x004E4942:
            blob = chunk
        off += 8 + length + (-length % 4)
    return meta, blob


def accessor(meta, blob, index, fmt):
    """Pull one accessor out as a list of tuples, honouring byteStride."""
    acc = meta["accessors"][index]
    view = meta["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or struct.calcsize(fmt)
    return [struct.unpack_from(fmt, blob, start + i * stride) for i in range(acc["count"])]


def area(tri):
    """Area of a triangle, by half the magnitude of the cross product."""
    (ax, ay, az), (bx, by, bz), (cx, cy, cz) = tri
    ux, uy, uz = bx - ax, by - ay, bz - az
    vx, vy, vz = cx - ax, cy - ay, cz - az
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    return 0.5 * (nx * nx + ny * ny + nz * nz) ** 0.5


def openness(verts, tris):
    """How much of each face of the bounding box is really surface.

    A container's floor is the one face that is solid; its opening is a rim.
    Comparing the two tells you which way up the model was exported, which is
    the thing a file listing cannot tell you.

    It narrows six possibilities to two -- it says which AXIS is vertical, not
    which END is the floor. Reading the dense face as the floor is a guess, and
    it was wrong once already. Look at it in Studio to pick the sign.
    """
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    size = [hi[i] - lo[i] for i in range(3)]

    rows = []
    for axis in range(3):
        a, b = [i for i in range(3) if i != axis]
        full = size[a] * size[b]
        for side, name in ((0, "min"), (1, "max")):
            edge = lo[axis] if side == 0 else hi[axis]
            flat = sum(
                area(t) for t in tris
                if all(abs(p[axis] - edge) <= 0.06 * size[axis] for p in t)
            )
            rows.append((f"{'XYZ'[axis]} {name}", 100 * flat / full if full else 0))
    return size, rows


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    meta, blob = read_glb(path)

    total_tris = 0
    for m_index, mesh in enumerate(meta.get("meshes", [])):
        for p_index, prim in enumerate(mesh["primitives"]):
            verts = accessor(meta, blob, prim["attributes"]["POSITION"], "<fff")
            kind = meta["accessors"][prim["indices"]]["componentType"]
            fmt = {5121: "<B", 5123: "<H", 5125: "<I"}[kind]
            idx = [i[0] for i in accessor(meta, blob, prim["indices"], fmt)]
            tris = [(verts[idx[i]], verts[idx[i + 1]], verts[idx[i + 2]])
                    for i in range(0, len(idx), 3)]
            total_tris += len(tris)

            label = mesh.get("name", f"mesh {m_index}")
            print(f"\n=== {label}  (primitive {p_index}) ===")
            print(f"{len(verts)} vertices, {len(tris)} triangles")

            size, rows = openness(verts, tris)
            print("size   " + "   ".join(f"{'XYZ'[k]} {size[k]:.3f}" for k in range(3)))
            print("\nhow much of each face of the bounding box is solid surface:")
            for name, pct in rows:
                print(f"  {name:>6}  {pct:6.1f}%")

            # The vertical axis is the LOPSIDED one, not the most covered one.
            # A container is symmetric about the two axes that are walls -- both
            # ends the same -- and lopsided about the one that has a floor at one
            # end and an opening at the other. Ranking by coverage instead picks
            # whichever pair of walls happens to be solidest, which is how this
            # first reported "X" for a tray that stands on Z.
            gap = [abs(rows[2 * k][1] - rows[2 * k + 1][1]) for k in range(3)]
            vertical = max(range(3), key=lambda k: gap[k])

            # A CLOSED SOLID HAS NO ANSWER HERE, and saying one anyway is worse
            # than saying nothing. Every face of a box is 100% covered, so every
            # pair is level, so `max` returns whichever index came first -- and
            # the first version announced "the vertical axis is X" about a stick
            # of butter with the same confidence it uses on a real container.
            if gap[vertical] < 10:
                print("\n  -> no face is more open than its opposite: this is a "
                      "closed solid, not a container.")
                print("     Which way up it goes is not written in the geometry. "
                      "Look at it in Studio.")
            else:
                print(f"\n  -> the vertical axis is {'XYZ'[vertical]}: its two ends "
                      f"differ by {gap[vertical]:.0f} points while the others match.")
                print("     Which END is the floor this CANNOT tell you -- the denser "
                      "face is not reliably the floor. Look at it in Studio.")

            if "TEXCOORD_0" not in prim["attributes"]:
                print("  -> NO UVs: an image texture cannot be applied to this.")
            else:
                # CAN THIS MODEL BE PAINTED ON? Add up the area the triangles
                # take on the texture map. An atlas is one unit square, so a
                # total near or below 1 means every scrap of surface has its own
                # place in the picture -- paint a spot and one spot changes.
                #
                # Well above 1 means the map is REUSED: the same texel serves
                # many places at once, which is how a noise or fur pattern is
                # tiled cheaply. The chick came in at 174, so painting an eye
                # would have put that eye in a hundred and seventy-odd places.
                # Worth knowing before trying, not after.
                tex = accessor(meta, blob, prim["attributes"]["TEXCOORD_0"], "<ff")
                total_uv = 0.0
                for i in range(0, len(idx), 3):
                    (ax, ay), (bx, by), (cx, cy) = (tex[idx[i]], tex[idx[i + 1]], tex[idx[i + 2]])
                    total_uv += abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2
                if total_uv > 2:
                    print(f"  -> the texture map is SHARED, not unique: the triangles cover "
                          f"{total_uv:.0f}x the atlas.")
                    print("     One texel serves many places at once, so features cannot be "
                          "painted into it -- they would appear everywhere at once.")

    print(f"\n=== the whole file ===")
    print(f"{total_tris} triangles against Roblox's limit of {TRIANGLE_LIMIT}: "
          + ("OK" if total_tris <= TRIANGLE_LIMIT else "OVER, it will be rejected"))

    images = meta.get("images", [])
    print(f"{len(meta.get('materials', []))} materials, {len(images)} embedded images")

    # WRITTEN OUT SO SOMEBODY LOOKS AT THEM. An earlier model shipped a
    # 1024x512 texture with nothing drawn on it -- a valid image, correctly
    # embedded, correctly referenced, and blank. No property in the file says
    # so; the only way to know was to open it. So the tool puts the pictures
    # where they can be opened instead of guessing from file size.
    for index, img in enumerate(images):
        view = meta["bufferViews"][img["bufferView"]]
        start = view.get("byteOffset", 0)
        data = blob[start : start + view["byteLength"]]
        name = f"{path.rsplit('/', 1)[-1].rsplit('.', 1)[0]}-texture-{index}.png"
        out = f"/tmp/{name}"
        with open(out, "wb") as f:
            f.write(data)

        note = ""
        if data[:8] == b"\x89PNG\r\n\x1a\n":
            width, height = struct.unpack(">II", data[16:24])
            over = " -- OVER Roblox's 1024 cap, it will be scaled down" \
                if max(width, height) > TEXTURE_LIMIT else ""
            note = f"{width}x{height}{over}, "
        print(f"  {img.get('name', '(unnamed)')}  {note}written to {out}")
        print("     LOOK AT IT. A blank texture is a valid file and says nothing.")

    if not images:
        print("  -> no texture travels with this file; whatever colour it has "
              "comes from its material or from us.")

    # glTF vertex colours do not survive Roblox's importer, so a model whose
    # colour lives there arrives white. Worth saying before it is uploaded.
    for mesh in meta.get("meshes", []):
        for prim in mesh["primitives"]:
            if "COLOR_0" in prim["attributes"] and "TEXCOORD_0" not in prim["attributes"]:
                print(f"\n  -> {mesh.get('name', 'a mesh')} carries its colour in VERTEX "
                      "COLOURS and has no UVs.")
                print("     Roblox drops those. It will arrive white and need "
                      "painting from Config.")

    moved = [n for n in meta.get("nodes", [])
             if any(k in n for k in ("rotation", "scale", "matrix", "translation"))]
    if moved:
        print("\nnodes carrying a transform (Roblox may or may not honour these):")
        for n in moved:
            print(f"  {n.get('name', '(unnamed)')}: "
                  + ", ".join(k for k in ("translation", "rotation", "scale", "matrix") if k in n))


if __name__ == "__main__":
    main()
