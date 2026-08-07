# assets/

Todo lo que dejes acá aparece en Studio dentro de `ReplicatedStorage → Assets`, con el nombre del archivo. Rojo lo sincroniza solo y **queda en git**: si un modelo rompe algo, se revierte como cualquier cambio.

---

## Meter un modelo 3D, paso a paso

### 1. Conseguí el archivo

Formatos que Studio importa seguro: **`.fbx`** y **`.obj`**.

Si tu herramienta te da otra cosa, convertila a `.fbx` — es el que menos problemas da y el que conserva materiales.

### 2. Importalo en Studio

Pestaña **`Avatar`** → botón **`3D Importer`** → elegí el archivo.

Se abre una vista previa con la lista de lo que trae. Ahí mismo te avisa si algo se pasa de los límites.

### 3. Revisá tres cosas en esa ventana

| Qué | Por qué |
|---|---|
| **Una sola malla, no varias** | Para que el objeto se pueda achatar y estirar tiene que ser una pieza entera. Cinco pedacitos pegados no se deforman bien |
| **Menos de 10.000 triángulos** | Es el límite de Roblox por malla. Lo que sale de una IA suele venir con muchísimos más y hay que simplificarlo antes |
| **Que esté centrado y parado** | Si el modelo viene acostado o con el origen lejos, después queda flotando o hundido en la mesa |

### 4. Guardalo en esta carpeta

En el **Explorer**, clic derecho sobre el objeto importado → **`Save to File…`** → guardalo acá con nombre claro y **sin espacios ni tildes**:

```
PulpoAzul.rbxm
```

### 5. Avisame

Decime el nombre del archivo y **para qué objeto del catálogo es** (por ejemplo: *"PulpoAzul.rbxm, es para `last_empanada`"*).

Yo lo conecto. No hay ids que copiar.

---

## Las texturas van aparte

Si el modelo trae imagen de color, esa **no** viaja en el `.rbxm`: es un archivo subido a Roblox y vive como id.

Studio → **`View`** → **`Asset Manager`** → importar la imagen → te devuelve un id → **pasámelo** y va a `Config/Theme.luau`.

Lo mismo para sonidos.

---

## Los ids no se inventan

Un id escrito de memoria apunta al asset de otra persona o a nada, y lo segundo falla en runtime sin decir por qué. Por eso los huecos de sonido en `Theme.luau` están **vacíos** en vez de llenos de números plausibles: **un hueco vacío se ve; un id equivocado, no.**
