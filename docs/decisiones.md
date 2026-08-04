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

---

## 2026-08-04 · Confirmación: la separación cerebro/piel se pagó sola

**No es una decisión nueva, es el resultado de una vieja.** En E0 se pagó el costo de dividir la pantalla en tres —contrato, cerebro, piel— cuando lo barato era escribir un archivo y seguir.

En E2 se cambió **la apariencia entera** del juego: de un panel plano sobre el mundo a una hoja de papel en una mesa 3D, con cámara sobre el hombro, cuadrícula, recortes torcidos y revelación escalonada. Costó **un archivo nuevo**. `DuelScreen`, `DuelPanels` y el razonamiento de `UIController` no se tocaron: cuándo se habilita Aceptar, cuándo se gastó la ficha, qué ve el rival — nada de eso se volvió a escribir.

Y se repitió al llegar los mockups: la paleta se reemplazó **entera** —de marcador oscuro sobre crema a birome azul sobre kraft— y nada de lo que la lee necesitó tocarse.

**Lo que compró:** la condición que se puso en E0 ("si E0 mezcla lógica y piel, E2 reescribe todo y E0 fue trabajo tirado") era correcta, y este checkpoint es la prueba. La inversión de estructura de hace semanas es la razón de que este haya sido barato.

---

## 2026-08-04 · Zonas táctiles más grandes que el dibujo

**Decidido:** cada botón de la hoja tiene una zona de toque invisible 1.5× más grande que el recorte visible (`Theme.touchPadding`), centrada sobre él.

**Por qué:** los botones viven en espacio-mundo, vistos en ángulo, y móvil es la plataforma principal (§5). Una zona del tamaño del dibujo exige una puntería que el dedo gordo no tiene. Un botón que se ve bien y falla es peor que uno que se ve un poco peor.

**Alternativa descartada:** agrandar los botones dibujados. Se descartó porque la composición de los mockups tiene tamaños concretos, y engordarlos para que el dedo acierte deforma el diseño para resolver un problema que es de entrada, no de dibujo.

**Cómo está hecho:** el contenedor conserva el tamaño visual, así que ningún sitio de llamada cambió; la zona de toque desborda ese contenedor por igual en los cuatro lados.

---

## 2026-08-04 · El tablero va ACOSTADO, no parado — los mockups mandan

**Decidido:** el tablero de papel se apoya plano sobre la mesa, entre los dos jugadores, y la cámara mira hacia abajo desde sobre tu hombro.

**Por qué se frenó primero:** la instrucción escrita decía "la hoja de papel VERTICAL sobre la mesa" y los mockups la muestran acostada. Contradicción entre fuentes — el caso (d), donde la autonomía se suspende. Se había construido la versión parada siguiendo el texto.

**Por qué gana la imagen:** el texto era una interpretación anterior a que las imágenes existieran; la imagen es la fuente de verdad de la dirección de arte. Y acostado es mejor por tres razones:

1. **Es el meme real.** Los papelitos de los videos están sobre una mesa o el piso, entre los dos. Nunca parados como atril.
2. **Los dos juegan sobre el mismo objeto físico**, que es lo que hace que las filas espejadas signifiquen algo: cerca lo mío grande y relleno, lejos lo suyo chico y en contorno, la red punteada al medio.
3. **Mirar hacia abajo a una mesa es más natural** que mirar de frente a un atril.

**Consecuencia técnica que vale la pena anotar:** un tablero acostado tiene **una sola cara** para dos jugadores. Funciona porque cada cliente crea su propio `SurfaceGui` local sobre esa cara y solo ve el suyo; el de slot 2 va rotado 180° para que "cerca" sea cerca para los dos. La regla de oro sigue siendo estructural: la vista del rival no existe en esta máquina.

**`gdd.md` §25 corregido el mismo día**, para que el doc no siga contradiciendo a los mockups.

---

## 2026-08-04 · Los objetos, en dos fases

**Decidido:** ahora, recortes de papel parados —cutout con borde blanco de tijera y sombra en la base—; después, modelos 3D de papel reemplazándolos objeto por objeto, empezando por los legendarios.

**Por qué:** los mockups muestran modelos de papel de verdad (la sopa, la piedra con carita) y los envueltos como paquetitos de origami con un "?" dibujado. Es la dirección correcta y queda aprobada, pero son doce modelos: salto de contenido, no ajuste. Fasearlo hace que el tablero nuevo salga ya con objetos dignos sin que el checkpoint espere a que existan los doce.

**Alternativa descartada:** dejar los cuadraditos de color hasta tener los modelos. Se descartó porque el checkpoint es una revisión visual, y revisarla con placeholders mide el placeholder.

---

## 2026-08-04 · Una sola lapicera dibujó este mundo

**Decidido:** birome azul para absolutamente todo el trazo. Los únicos rellenos de color son los tres botones de negociación.

**Por qué:** es la decisión más definitoria de los mockups y no se ve hasta que se miran. Esa unidad es lo que hace que el mundo se lea como una sola hoja en vez de como assets juntados de lados distintos. Un elemento con otra tinta rompe el efecto entero, y por eso quedó escrito en `gdd.md` §28 como regla de arte 🔒 y no como preferencia.

---

## 2026-08-04 · ProfileStore vendorizado y auditado por banderas, no leído entero

**Decidido:** se bajó `MadStudioRoblox/ProfileStore` (2242 líneas) a `src/server/ProfileStore.luau`, con la auditoría escrita en la cabecera del archivo.

**Por qué así:** `arquitectura.md` §1 ya había elegido ProfileStore, así que usarlo no era la decisión; **cómo confiar en él** sí. La regla 5 de CLAUDE.md dice nunca código de fuentes no auditadas, y leer 2242 líneas con criterio no es algo que se pueda afirmar honestamente. Lo que sí se hizo, y quedó escrito: cero `loadstring`, cero `getfenv`/`setfenv`, cero `_G`, cero `require(` de terceros (el único del archivo está comentado), y solo cuatro servicios tocados — `HttpService` únicamente para `GenerateGUID`, nunca para red.

**Lo que eso significa y lo que no:** significa que no hace nada que un módulo de guardado no deba hacer y que no trae código de ningún otro lado. **No** significa que se haya leído entero, y la cabecera lo dice con esas palabras.

**Detalle para que no sorprenda:** ProfileStore usa `MessagingService` internamente para resolver conflictos de lock entre servidores. `arquitectura.md` §1 dice "cross-server: ninguno", pero eso es sobre features nuestras, no sobre las tripas de la dependencia que la misma §1 eligió. No es contradicción; se anota para que nadie lo descubra con sorpresa.

---

## 2026-08-04 · `DataConfig` aparte de `Economy`

**Decidido:** el nombre del store, el prefijo de clave, la versión del esquema y el switch del mock van en `Config/DataConfig.luau`, no en `Economy.luau`.

**Por qué:** `Economy` es el archivo que se abre para rebalancear, y va a abrirse seguido. Estos no son números de balance: cambiar el nombre del store no ajusta el juego, **apunta a datos guardados distintos**. Mezclarlos es cómo alguien toca un número para balancear y deja huérfano cada perfil del juego, sin un solo error.

**Alternativa descartada:** meterlos en `Economy` o en `DuelRules` para no crear otro archivo.

---

## 2026-08-04 · El mock de ProfileStore por defecto en Studio

**Decidido:** en Studio se usa el DataStore simulado de ProfileStore, salvo que `DataConfig.useMockInStudio` diga que no.

**Por qué:** sin eso, nada de datos funciona en Studio hasta publicar el lugar con acceso a API, y **cada prueba escribe en los datos reales**. Con eso, Studio anda de entrada y las pruebas no ensucian nada. Y el simulador igual aplica session locking, así que el fallo interesante —dos sesiones peleando por un perfil— se sigue pudiendo probar.

**El límite, escrito en el checkpoint:** un simulador que se porta bien no prueba que un DataStore se porte bien. La prueba 4 del checkpoint 3 corre contra el store real, y es obligatoria.
