# assets/

**Acá van los modelos.** Todo lo que dejes en esta carpeta aparece en Studio dentro de `ReplicatedStorage → Assets`, con el mismo nombre del archivo.

Rojo lo sincroniza solo, igual que el código. Y como vive en el repo, **queda en git**: si un modelo se rompe, se vuelve atrás como cualquier otro cambio.

## Cómo meter un modelo

1. Armalo o importalo en Studio (podés usar el **3D Importer** de la pestaña *Avatar* para un `.fbx` o `.obj`).
2. En el **Explorer**, clic derecho sobre el modelo → **Save to File…**
3. Guardalo **en esta carpeta**, con un nombre claro y sin espacios: `PeluchePulpo.rbxm`.
4. Avisá qué nombre le pusiste y para qué es.

Eso es todo. No hay ids que copiar ni pegar.

## Qué SÍ funciona así

Modelos, partes, meshes, `Folder`s con cosas adentro — cualquier instancia de Roblox.

## Qué NO

**Imágenes y sonidos** no viven en el repo: son assets subidos a Roblox y se identifican por un **id**. Para esos:

1. Studio → pestaña **View** → **Asset Manager** → botón de importar.
2. Subís el archivo. Roblox te devuelve un id (`rbxassetid://123456789`).
3. Pasame el id y va a `Config/Theme.luau`, que es donde viven todos.

Vale para: texturas de ropa, caras, imágenes de la UI, y los sonidos que hoy están vacíos.

## Los ids no se inventan

Un id escrito de memoria apunta al asset de otra persona o a nada, y la segunda falla en runtime sin decir por qué. Por eso los huecos de sonido en `Theme.luau` están en blanco en vez de rellenos con números plausibles: **un hueco vacío se ve; un id equivocado, no.**
