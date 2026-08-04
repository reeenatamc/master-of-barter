---
sidebar_label: Decisiones
---

# Registro de decisiones

Desde que empezó la **autonomía guiada** (2026-08-04), las decisiones que antes pasaban por aprobación previa se toman sobre la marcha y se anotan acá. Renata lee este log en los checkpoints.

Formato: qué se decidió, por qué, y **qué alternativa se descartó** — esa última parte es la que hace el registro útil, porque una decisión sin alternativa descartada no es una decisión, es una ocurrencia.

Las marcadas **`[propuesta]`** esperan su sí o su no en un checkpoint.

---

## 2026-08-04 · Los mockups no existen; la paleta sale del texto del GDD `[propuesta]`

**Decidido:** avanzar con C2 derivando la paleta, las texturas y el tono de la **descripción escrita** del GDD (§25 y §28) en vez de esperar las imágenes.

**Por qué:** la instrucción decía mirar `/docs/mockups` antes de diseñar, pero la carpeta no existe en el repo. Frenar C2 entero bloquearía también E2, B1 y B2, que son semanas de trabajo que no dependen de una paleta. El GDD sí describe la estética con suficiente detalle como para trabajar: *"dibujado con marcador en hojas cuadriculadas, botones como recortes pegados con cinta"* (§25), *"colores planos, la imperfección del trazo es estética, no defecto"* (§28).

**Alternativa descartada:** esperar las imágenes. Se descartó por costo de bloqueo, no porque las imágenes sobren.

**Cómo se revierte:** todo lo derivado está marcado `[propuesta]` en `Theme.luau`. La **estructura** del tema —qué claves existen y cómo se leen— está pensada para sobrevivir un cambio de paleta, así que cuando lleguen las imágenes se rederivan los valores sin tocar E2. Ver `docs/mockups/LEEME.md`.

---

## 2026-08-04 · La ficha ¡ES FAKE! se queda intacta hasta el checkpoint 1

**Decidido:** no construir nada que dependa de que la ficha exista **ni** de que no exista. Queda como está, gobernada por `DuelRules.limits.fakeCallsPerDuel`.

**Por qué:** el checkpoint 1 (la sesión de `prueba-diversion-2.md`) todavía no se corrió, y de él depende si A4 vive. Cualquier código que asuma una de las dos respuestas hay que reescribirlo cuando llegue la otra.

**Alternativa descartada:** asumir que se queda (es lo más probable) y construir sobre eso. Se descartó porque el costo de equivocarse es rehacer trabajo, y el costo de esperar es cero: el toggle ya funciona.

---

## 2026-08-04 · Fuentes verificadas contra la API, no elegidas de memoria

**Decidido:** `PermanentMarker` para títulos y botones, `PatrickHand` para texto largo.

**Por qué:** §25 pide marcador sobre hoja cuadriculada. `PermanentMarker` es literalmente eso; `PatrickHand` es manuscrita pero legible, que importa más que el carácter cuando hay un párrafo.

**Cómo se eligieron:** probando una lista de candidatas contra el analizador de tipos antes de usarlas. **`Caveat`, `Amatic`, `ArchitectsDaughter` y `Schoolbell` no existen en Roblox** y las habría escrito de memoria: son nombres de fuentes reales del mundo, pero no están en el engine. Habrían fallado recién en Studio.

**Alternativa descartada:** elegir por nombre y confiar. Es exactamente el tipo de API inventada que CLAUDE.md regla 5 dice que cuesta horas.

---

## 2026-08-04 · Los assets de sonido y textura quedan vacíos, no inventados

**Decidido:** `Theme.sounds` y `Theme.textures` quedan con string vacío, y quien renderiza cae a color plano o a silencio.

**Por qué:** un `rbxassetid://` inventado apunta al sonido de otra persona o a nada. Las dos cosas son peores que el silencio, y la segunda además falla en runtime sin decir por qué. Los nombres de las claves describen qué necesita cada hueco (§26: papel arrugándose, cinta, marcador, "ohhh" de chicos), así que llenarlos es ir de compras, no diseñar.

**Alternativa descartada:** poner ids de la biblioteca de Roblox de memoria.

---

## 2026-08-04 · La skill `roblox-gui` entra al flujo de trabajo de UI

**Decidido:** usarla como referencia al construir E2.

**Por qué:** a diferencia de la anterior (`roblox-game-development`, cuya capa de datos hubo que descartar entera), esta es corta, precisa y no contradice nada del proyecto. Aporta tres cosas que E2 necesita y que no estaban resueltas:

- **`SurfaceGui` con `PixelsPerStud`** — el mecanismo para poner la hoja de papel *sobre la mesa en 3D*, que es la escena canónica de §11. Sin esto, E2 seguiría siendo una pantalla plana encima del mundo.
- **`BillboardGui`** — emotes flotando sobre el avatar del rival, en vez de en una esquina de la pantalla. §11 dice que ver al rival es mecánico, no decorativo; esto lo hace literal.
- **Dos trampas concretas:** `AbsoluteSize` vale cero en el primer frame (hay que leerlo dentro de `task.defer`), y los clicks atraviesan frames superpuestos salvo que se bloquee la entrada.

**Ya adoptado:** `ZIndexBehavior.Sibling` en el `ScreenGui`, que no estaba puesto.

**Alternativa descartada:** ignorarla y seguir con lo que ya sabía. Se descartó porque la escena canónica necesita `SurfaceGui`, y eso no lo tenía resuelto.

---

## 2026-08-04 · Los botones van SOBRE la hoja, no en una pantalla aparte

**Decidido:** todo se toca sobre la hoja de papel en el mundo (`SurfaceGui`), incluidos los tres botones de negociación. No hay `ScreenGui` encima.

**Por qué:** la instrucción decía "la hoja de papel VERTICAL sobre la mesa con filas de botones espejadas". Poner los controles en una capa aparte flotando sobre el mundo sería volver a E0 con mejor tipografía, y rompería la escena de §11: una UI que ocupa la pantalla esconde al rival, y ver al rival es mecánico.

**Alternativa descartada:** híbrido — la hoja muestra el trueque, los tres botones van en un `ScreenGui` al pie. Es más seguro para el dedo en móvil, y sigue siendo el plan B si la prueba dice que tocar en el mundo no funciona.

**Riesgo asumido, a verificar en el checkpoint 2:** tocar botones en espacio-mundo es menos preciso que en pantalla, y móvil es la plataforma principal (§5). Está escrito como punto explícito del checkpoint.

---

## 2026-08-04 · La mesa se construye por código, no en el editor

**Decidido:** `DuelSceneService` crea la mesa y la hoja con `Instance.new`, con las medidas en `Theme.table`.

**Por qué:** mismo criterio que en E0 — ¿importa la estética acá? Es una mesa y una hoja; la estética vive en la textura y la paleta, que son del tema. Y la tarjeta E1 reemplaza todo esto con el lobby de verdad, así que colocar partes a mano es esfuerzo con fecha de vencimiento conocida.

**Alternativa descartada:** modelarla en Studio. Se descartó por eso y porque el editor viene siendo la mayor fuente de fricción del proyecto.

---

## 2026-08-04 · Se descartó una cuarta rareza

**Decidido:** el catálogo de 12 objetos se reparte en **tres** rarezas.

**Por qué:** al escribirlo salió natural una cuarta ("Épico") para los valores del medio. `gdd.md` §18 fija tres. Agregar una es **alterar** una mecánica del GDD, no agregarle detalle — el caso (c) donde la autonomía se suspende. Se redistribuyó en tres en vez de preguntar, porque tres alcanzan.

**Alternativa descartada:** proponer la cuarta rareza en el checkpoint. Se descartó porque no hacía falta: el catálogo funciona con tres, y el cambio habría arrastrado economía, kiosco y frecuencias de sorteo.
