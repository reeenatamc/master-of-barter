# tools/

## `simplify-mesh.py`

Baja un `.obj` hasta el límite de **10.000 triángulos** de Roblox, conservando las coordenadas de textura.

```
python3 tools/simplify-mesh.py entrada.obj salida.obj 9000
```

**Cómo funciona:** agrupa los vértices en una grilla 3D y colapsa cada celda en un punto, buscando por bisección el tamaño de celda más chico que deje el modelo bajo el límite — cuanto más chica la celda, más detalle sobrevive. Para una forma orgánica conserva la silueta, que es lo único que se ve a la distancia a la que se miran estos objetos.

**Las UV viajan.** Se promedian junto con las posiciones. En una costura de la textura eso mancha un poco, porque dos vértices que estaban en lados opuestos del mapa terminan en el promedio — pero sin UV el modelo es gris para siempre, y una costura levemente corrida se nota mucho menos.

**Por qué escribe el `.obj` a mano:** el exportador de `trimesh` omite las UV salvo que se le adjunte una imagen, y adjuntarla acá significaría inventarle una ruta.

Necesita `trimesh` y `numpy` (`pip3 install --user trimesh numpy`).

## Achicar una textura

Roblox topea las imágenes en 1024×1024, así que subir una de 4096 es peso al pedo:

```python
from PIL import Image
Image.open("entrada.png").convert("RGB").resize((1024, 1024), Image.LANCZOS).save("salida.png", optimize=True)
```

Una textura de 4096 pesa unos 10 MB; a 1024 queda en menos de uno.
