"""Baja un OBJ hasta el limite de triangulos de Roblox, conservando las UV.

Agrupa vertices en una grilla 3D y colapsa cada celda en un punto. Para una
forma organica -- un peluche redondeado -- eso conserva la silueta, que es lo
unico que se ve a la distancia a la que se mira esto.

LAS UV VIAJAN. Se promedian igual que las posiciones. En una costura de la
textura eso mancha un poco, porque dos vertices que estaban en lados opuestos
del mapa terminan en el promedio -- pero sin UV el modelo es gris para siempre,
y una costura levemente corrida se ve mucho menos que eso.
"""
import pathlib, sys, numpy as np, trimesh

src, dst, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])

mesh = trimesh.load(src, process=False, force="mesh")
uv = None
if hasattr(mesh.visual, "uv") and mesh.visual.uv is not None and len(mesh.visual.uv) == len(mesh.vertices):
    uv = np.asarray(mesh.visual.uv, dtype=float)

print(f"entrada : {len(mesh.faces)} triangulos, {len(mesh.vertices)} vertices, UV: {'si' if uv is not None else 'no'}")


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
    good = (faces[:, 0] != faces[:, 1]) & (faces[:, 1] != faces[:, 2]) & (faces[:, 0] != faces[:, 2])
    faces = faces[good]

    visual = trimesh.visual.TextureVisuals(uv=merged_uv) if merged_uv is not None else None
    # process=False: dejar que trimesh vuelva a fusionar vertices tira las UV.
    return trimesh.Trimesh(vertices=verts, faces=faces, visual=visual, process=False)


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

# Escrito a mano. El exportador de trimesh omite las UV salvo que se le adjunte
# una imagen, y adjuntarla aca significaria inventarle una ruta -- asi que el
# OBJ se arma directo, que ademas es un formato de texto trivial.
out_uv = getattr(best.visual, "uv", None)
lines = ["# simplificado para el limite de 10.000 triangulos de Roblox"]
if out_uv is not None:
    lines.append("mtllib material.mtl")
for v in best.vertices:
    lines.append(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}")
if out_uv is not None:
    for t in out_uv:
        lines.append(f"vt {t[0]:.6f} {t[1]:.6f}")
    lines.append("usemtl Material")
for f in best.faces:
    a, b, c = int(f[0]) + 1, int(f[1]) + 1, int(f[2]) + 1
    if out_uv is not None:
        lines.append(f"f {a}/{a} {b}/{b} {c}/{c}")
    else:
        lines.append(f"f {a} {b} {c}")

pathlib.Path(dst).write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"salida  : {len(best.faces)} triangulos, {len(best.vertices)} vertices, UV: {'si' if out_uv is not None else 'no'}")
