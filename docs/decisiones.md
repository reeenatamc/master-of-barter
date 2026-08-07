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

---

## 2026-08-04 · Los costos se derivan, no se recuerdan

**Regla general del proyecto, no una decisión de una tarjeta.** Ningún precio ya cobrado se guarda: se vuelve a calcular desde lo que se compró.

**De dónde salió:** al cobrar una enmienda hacía falta saber cuánto se había pagado por la oferta anterior. Guardar ese número al lado de la oferta habría sido lo obvio y lo rápido.

**Por qué no:** un precio guardado es una segunda fuente de verdad, y envejece apenas alguien toca `Economy.luau`. El día que se rebalancee el costo de falsificar, cada oferta en curso llevaría un precio de la versión anterior, y el cobro del delta saldría mal sin que nada avise.

**En su lugar:** `toRequests()` reconstruye las peticiones desde los envoltorios guardados y `offerCost()` las vuelve a valuar. Más trabajo por llamada, cero desincronización posible.

---

## 2026-08-04 · La guarda de idempotencia dejó de ser defensiva

**No es una decisión nueva: es una predicción que se cumplió.** En A1.2 se escribió que `finish()` fuera idempotente y se anotó textualmente que "el día que `finish()` tenga un ProfileStore del otro lado, el no-op es lo que evita corromper".

Con B2 llegó ese día. El pago del duelo vive **dentro** de esa guarda, y desde ahora "pagar" significa escribir en un perfil. Un duelo que terminara dos veces pagaría dos veces.

**Vale anotarlo porque el costo se pagó meses antes del beneficio**, que es justo el tipo de inversión que se recorta cuando aprieta el tiempo.

---

## 2026-08-04 · Dos fallos distintos no pueden tener el mismo síntoma

**Regla general, tercera aparición.** Primero fue el contador de objetos vivos del Trove ("esperado 0, quedó N" en vez de "no explotó"). Después los contadores de `finish()` ("1 real, 1 bloqueado"). Ahora el acceso al DataStore.

**El caso:** con el acceso a API de Studio apagado, el jugador quedaba como espectador. Con el guardado roto, el jugador quedaba como espectador. **La misma línea en el Output para dos problemas sin nada en común** — uno es un checkbox, el otro es un bug.

Ahora el aviso lleva `DataStoreState`, así que `NoAccess` y `Access` los separan de un vistazo.

**Y de dónde salió:** de escribir el guion de prueba, no de programar. Documentar cómo se prueba algo obligó a pensar qué vería quien lo prueba, y ahí apareció que dos cosas distintas se veían igual.

---

## 2026-08-04 · Escrow: las copias salen del perfil al ofertar, no al resolver

**El problema.** Desde B3, "el que se queda gana la apuesta" significa escribir en **dos** perfiles. Y el del que se fue puede estar liberándose (`PlayerRemoving` → ProfileStore) en el mismo instante en que `finish()` intenta descontarle las copias. Si el perfil se libera antes de que la transferencia escriba: o el ganador no recibe (**pérdida**), o el perdedor conserva lo que ya entregó (**duplicación**).

**Decidido:** las copias apostadas **salen del perfil al ofertar**. El duelo las retiene. Al resolver, se devuelven o se entregan.

**Por qué el escrow y no "transferir antes de liberar":**

La razón que más pesa no es que haga imposible el dupe —que también—, sino que **elimina la carrera en vez de ordenarla**. Con escrow, al resolver un duelo por desconexión **no hay nada que escribir en el perfil del que se fue**: sus copias salieron al ofertar. Solo se escribe en el perfil del que se quedó, que sigue conectado y con su perfil vivo.

O sea: el problema de orden entre transferencia y liberación **deja de existir**, en vez de resolverse con una secuencia que hay que mantener correcta para siempre. Ordenar dos listeners de `PlayerRemoving` es una convención que el próximo cambio puede romper en silencio; que no haya nada que escribir no se rompe.

**Qué pasa si el servidor se cae a mitad:** las copias en escrow se pierden. Es aceptable y es la elección correcta entre los dos fallos posibles: una **pérdida** lastima a una persona una vez, una **duplicación** infla la economía de todos para siempre. Cuando hay que elegir cuál fallo tener, se elige el que no se propaga.

**Alternativa descartada:** transferir antes de liberar. Se descartó porque depende de un orden entre dos manejadores de `PlayerRemoving` que Roblox no garantiza, y porque una caída del servidor entre ambos pasos produce dupe, que es el peor de los dos fallos.

---

## 2026-08-04 · La colección no decrece porque la operación no existe

**Decidido:** `InventoryService` no tiene ninguna función que reste de `collection`. Ninguna.

**Por qué así:** `gdd.md` §21 dice que la colección permanente nunca se pierde 🔒, y eso ahora se vuelve código. Se podía cumplir por convención —"acordate de no restar de la colección"— o por control de acceso —"el módulo de transferencias no recibe permiso de escritura"—.

Se eligió algo más fuerte: **la operación no existe**. No se puede llamar a una función que no está. Un camino de código que reste de la colección tendría que escribirla primero, que es un acto deliberado y visible en el diff, no un descuido.

**Consecuencia a resolver en B4, no acá:** `Economy.shop.sellMultiplier` sugiere vender objetos, y vender restaría de la colección. Eso contradice §21 tal como está escrito. Cuando llegue el kiosco hay que decidir si se venden **copias de duelo** (coherente) o si §21 cambia (caso (c): preguntar). Anotado, no resuelto.

---

## 2026-08-04 · ⏸ PENDIENTE — caso (d): `sellMultiplier` contra §21

**La autonomía se suspende acá.** No implemento vender hasta que haya respuesta.

**Qué dice el doc.**

- `gdd.md` §21: *"Colección permanente: objetos obtenidos; **nunca se pierden** 🔒 (pilar anti-frustración)."* Está marcado como decidido, no como abierto.
- `gdd.md` §19 lista las fuentes de Clips: *"duelos, misiones, rachas"*. **Vender no está.** Y los sumideros: *"fabricar fakes, comprar objetos/cajas del kiosco, reintentos de misión."*
- `backlog.md` B4 pide *"comprar objetos y copias en el kiosco"*. Solo comprar.

**Qué hace el código.** `Economy.shop.sellMultiplier = 0.40` existe y **nadie lo usa**.

**De dónde salió, que importa para decidir:** lo escribí yo en el primer borrador de `Economy.luau`, arrastrado de la idea genérica de "tienda", no de ninguna línea de los docs. O sea que **probablemente la contradicción la creé yo**, y no es una inconsistencia entre documentos.

**Las lecturas posibles.**

1. **Es para vender copias de duelo.** Compatible con §21 —las copias no son la colección— pero agrega una **fuente de Clips que §19 no contempla**, y cambiar de dónde entra el dinero es diseño de economía, no implementación.
2. **Es para vender objetos de la colección.** Contradice §21 de frente, que está 🔒.
3. **Es un número que nadie decidió**, sobreviviente de un borrador.

**Mi recomendación: borrarlo.** Tres razones, en orden de peso:

- **Un número de config que existe "por las dudas" es una decisión de diseño tomada por accidente.** Alguien lo va a usar algún día porque está ahí, y en ese momento nadie se va a acordar de que nunca se decidió.
- Vender colección está prohibido por §21 🔒, y vender copias agrega una fuente de Clips que §19 no tiene. Cualquiera de las dos es una conversación de diseño, no una línea de código.
- Aun aceptando vender copias, **no agrega ninguna decisión al jugador**: las copias se compran con Clips, así que revenderlas al 0,40 es solo un viaje de ida y vuelta con pérdida. Un sumidero que no propone nada.

Si más adelante hace falta un sumidero o una fuente, se diseña a propósito y entra a §19.

---

## 2026-08-04 · Auditoría de Config: qué es una mina y qué es un valor esperando su tarjeta

**El corolario de la regla 6**, aplicado. Buscar "valores que nadie lee" da 47 resultados en este proyecto y casi todos son ruido: la mayoría se accede por índice dinámico (`Theme.items[itemId]`, `Strings.emoteSymbols[id]`, `phaseSeconds[duel.phase]`), que ningún grep de `.clave` encuentra.

**El criterio que sí sirve no es "nadie lo lee" — es "nadie lo lee Y ninguna tarjeta lo va a leer".**

| Valor | Sin consumidor | Pero |
|---|---|---|
| `secondsBeforeBot` | sí | lo consume **D1** (bots). Está en el backlog. |
| `buyMultiplier` | sí | lo consume **B4**, que es lo que sigue. |
| `itemFlavour`, `rarityNames` | sí | los consume **A6** (inspección). |
| `currencyName` | sí | lo consume **E3** (HUD). |
| `Theme.textures`, ranuras de sonido | sí | los consume **C2** cuando existan los assets. |
| `Strings.tokenSpent` | sí | **ninguna.** Lo escribí de más. |
| `Strings.owesBigger` | sí | **ninguna.** Se muestra inline, esta cadena nunca se usó. |

**Un valor que espera a una tarjeta del backlog no es una mina: tiene un consumidor con nombre y fecha.** Una mina es un valor que no tiene ni consumidor ni tarjeta ni entrada en el GDD — nadie lo va a usar porque haga falta, lo van a usar porque estaba ahí.

Los dos últimos se borraron con `sellMultiplier`.

---

## 2026-08-04 · Toda operación reversible necesita su inversa exacta

**Regla general, salida del bug del rollback de B3.**

`takeCopy` sacaba una copia y anotaba una entrada de escrow. Para deshacerlo se usaba `clearEscrow(player, duelId)`, que borraba **todas** las entradas de ese duelo — y una enmienda que fallaba a mitad borraba también los registros de las copias que **seguían legítimamente apostadas** de la oferta original.

**El fix no fue arreglar el borrado, fue cambiar la herramienta:** `returnCopy` es el inverso exacto de `takeCopy` — una copia vuelve, **un** registro se borra. Ya no puede borrar de más, no porque valide, sino porque **no sabe borrar de más**.

`clearEscrow` quedó únicamente para duelos que llegaron a revelación, donde las copias cambiaron de manos y los registros sí están todos obsoletos.

**La regla:** una operación de estado que pueda revertirse parcialmente necesita su **inversa exacta**, no una limpieza general. "Borrar todo lo del duelo" era un martillo donde hacía falta una pinza, y los martillos no dejan de golpear de más cuando el caso es raro — golpean de más justo ahí.

---

## 2026-08-04 · Plan de D1, con las tres condiciones resueltas

### 1. Los bots actúan por la misma superficie validada

**El problema concreto:** las funciones validadas de hoy toman un `Player`, y un bot no tiene ninguno. La salida fácil sería que el bot mute el estado del duelo directo — y eso es exactamente el atajo prohibido: el día que cambie una validación y el atajo no, hay dos juegos distintos corriendo en el mismo servidor.

**La solución:** partir cada acción en dos mitades. La de afuera resuelve *quién sos* (Player → duelo + lado) y existe solo para los remotos; la de adentro hace *la acción sobre un lado*, con las cuatro capas completas. El bot llama a la mitad de adentro. **Misma función, mismas validaciones, mismo orden.**

**La única divergencia, y es un hecho, no un atajo:** un bot no tiene perfil, así que no hay de dónde sacarle copias ni a quién cobrarle Clips. Eso queda aislado en dos funciones —`takeStake` y `giveStake`— que no hacen nada cuando el lado es un bot. La divergencia vive en la capa de **persistencia**, nunca en la de **reglas**: turno, fase, límites, tope de fakes y coherencia del modelo A corren idénticas para los dos.

**Corolario que acepto de antemano:** si el bot no puede hacer algo por la superficie pública, eso es una carencia de la superficie y se arregla ahí.

### 2. D1 **no** reemplaza la sesión de diversión 2

D1 permite que Renata pruebe sola y que el juego viva sin población. **No decide la ficha.**

El veredicto del ¡ES FAKE! necesita dos humanos bluffeándose, porque **la métrica es la risa** y un bot no se ríe. D1 la *facilita* —Renata puede sentir las dos configuraciones ella misma antes, y los testers pueden calentar contra bots en vez de aprender el juego durante la medición— pero la sesión con personas sigue siendo la llave. Queda escrito en la tarjeta.

### 3. El farmeo: tope diario, no pago reducido

**El problema:** si ganarle a un bot paga igual que a un humano, y las personalidades de D1 son simples, alguien le encuentra el truco rápido. Los Clips se inflan, falsificar vuelve a ser gratis, y **el freno que B2 acaba de instalar queda deshecho**. Por la regla 5, esa es la falla que se propaga.

**Descartado — pago reducido:** `gdd.md` §15 pide que el jugador no reciba señales obvias de que es un bot, y un pago distinto **es** una señal obvia. Se ve en el primer duelo.

**Descartado — no pagar:** la señal es todavía más fuerte.

**Elegido — tope diario de Clips ganados contra bots, con la misma tasa por debajo del tope.** Tres razones:

1. **No hay señal por duelo.** Por debajo del tope, un duelo contra bot paga exactamente igual que uno contra persona: indistinguible en el juego normal, que es lo que §15 pide.
2. **Acota la inflación**, que es lo único que había que acotar. Lo que se propaga no es que alguien gane Clips, es que los gane sin límite.
3. **El único que llega al tope es el que ya está farmeando** — o sea, alguien que ya descubrió que son bots. La señal aparece exactamente para quien ya no la necesitaba.

### 3-bis. El agujero: los bots también acuñan OBJETOS

**Encontrado al revisar el plan, y el tope de Clips no lo tapaba.** La cadena: el bot no tiene perfil → sus envoltorios no salen de ningún inventario → cuando un humano le gana una oferta, esas copias **se acuñan de la nada** al entrar a su perfil. Es una fuente de copias que §19 no lista, farmeable igual que los Clips y por el mismo truco.

El caso inverso está bien y no hace falta tocarlo: humano pierde contra bot → sus copias salen del escrow y se van a la nada → es un **sumidero**, no infla.

**Resuelto con el mismo instrumento, no con uno nuevo:** el tope diario cuenta **valor total extraído de bots** — Clips ganados **más** el `baseValue` de las copias recibidas — contra un único límite. Un número, una cuenta en el perfil, ninguna señal nueva por debajo del tope, las dos monedas acotadas de una.

**Detalle de aplicación, para que no haya entregas a medias:** el tope se consulta **antes** de pagar un duelo contra bot. Si ya está alcanzado, no se paga nada —ni Clips ni copias—; si no, se paga completo y se suma el valor. Un duelo puede pasarse un poco del tope, y eso es preferible a repartir media recompensa: el exceso está acotado por el valor de un duelo, mientras que una entrega parcial es una regla nueva que el jugador tendría que deducir.

**Costo aceptado:** un campo nuevo en el perfil (`botEarnings = { date, value }`). Toca datos persistentes, así que `arquitectura.md` §7 se actualiza en el mismo commit, y la fuente queda anotada en §19 — **incluida la de copias, que hoy el doc no menciona en absoluto**.

### Prerrequisito: partir `DuelService` primero

Está en **1095 líneas**, tres veces y media el límite, y la deuda está marcada desde el checkpoint 2. Meter D1 adentro sería empeorar a propósito un archivo que ya hay que partir — y peor, el cambio de D1 es justo el que toca todos sus rincones.

Se parte primero, con el comportamiento intacto, y D1 entra después sobre algo legible.

---

## 2026-08-04 · La regla de oro gobierna también DÓNDE VIVEN LOS TIPOS

**Doctrina, para todo tipo futuro.** La frontera de seguridad no es solo qué datos viajan en runtime: es también **qué formas son alcanzables al escribir código**.

- **`Shared/Types` guarda los tipos de VISTA** — lo que el cliente puede ver. `WrappedItemView` no tiene dónde poner `isFake`.
- **El servidor guarda los tipos de VERDAD** — `Side`, `Duel`. Contienen `offer`, que contiene `isFake`.

**La frontera de tipos calca la frontera de datos.**

**Por qué importa:** un `Side` importable desde el cliente es un molde esperando que alguien, con la mejor intención, serialice la verdad a través de él. No haría falta ningún error de juicio: bastaría con que el tipo estuviera disponible y pareciera el adecuado.

**Antes de crear un tipo, la pregunta es de qué lado de la frontera carga información.** Si carga verdad, no vive en Shared, por conveniente que resulte.

---

## 2026-08-04 · El embudo de censura salió más fuerte de la partición

**Verificado, no supuesto.** La condición del corte de la vista era que después siguiera habiendo **un solo** camino por el que el estado del duelo se vuelve enviable. Se comprobó con cuatro búsquedas:

1. `stateFor` y `viewOf` existen **únicamente** en `DuelView`, y son locales al archivo.
2. El remoto `DuelState` se dispara desde **un solo lugar** en todo el servidor: `DuelView:99`.
3. `side.offer` —la tabla con la verdad— se toca en `DuelService` (apuestas, validación, armado de la revelación) y en `DuelView` (censura). Ninguno de los usos de `DuelService` llega a un remoto.
4. `DuelView` exporta **solo** `broadcast`.

**Y quedó más protegido que antes.** `stateFor` era local dentro de un archivo de mil líneas: cualquier función de ese archivo podía llamarlo y mandar el resultado. Ahora ningún módulo puede siquiera **obtener** un `DuelState`; la única salida es `broadcast`, que censura al pasar.

Partir bien no solo no debilitó la regla: la endureció, porque las fronteras de módulo son más difíciles de cruzar por descuido que las de una función local.

---

## 2026-08-04 · ✅ RESUELTO — caso (d): el remoto `DuelReveal` existe y nadie lo usa

**Primero, la respuesta a "¿por dónde sale el `RevealResult`?": por el mismo embudo.** Viaja **dentro** del `DuelState`, con la compuerta `if duel.phase == "Reveal"` adentro de `stateFor`. El inventario de salidas sancionadas sigue siendo **UNA**, no dos.

**Y ahí apareció el problema.** `Net.names.DuelReveal` está declarado y **nadie lo dispara**. `arquitectura.md` §6 lo lista como remoto servidor→cliente (`Duel/Revelacion`), pero la implementación mandó la revelación adentro del estado.

**Qué dice el doc:** §6 enumera cuatro remotos servidor→cliente, entre ellos `Duel/Revelacion`.
**Qué hace el código:** tres. La revelación va dentro de `Duel/Estado`.

**Por qué esto es peor que una mina de Config.** La regla 6 dice que un valor sin consumidor es una decisión tomada por accidente. Un **remoto** sin consumidor es eso y además otra cosa: es **una segunda salida cargada y esperando**. El día que alguien implemente la animación de la revelación (A3 versión final, Etapa 4) va a encontrar `DuelReveal` ahí, con nombre perfecto, y va a mandar el `RevealResult` por él. Sin ningún error de juicio — usando lo que estaba.

Y eso crearía exactamente lo que la auditoría de salidas existe para impedir: **un segundo camino que carga `isFake` fuera del servidor**, sin la compuerta de fase que tiene `stateFor`.

**Mi recomendación: borrar el remoto y corregir §6.** El código eligió mejor que el doc. Una salida con compuerta es más auditable que dos, y "contá las salidas" solo funciona como auditoría si el número correcto es conocido y chico.

**Alternativa, por completitud:** conservar `DuelReveal` y mover la revelación ahí. Se descarta porque duplica la superficie donde la regla de oro puede fallar, a cambio de nada — el estado ya llega en ese mismo instante.

**Resolución: borrado.** El remoto salió de `Net.luau` y §6 quedó con los tres que el código realmente tiene — el doc contando lo que existe, no lo que un borrador imaginó.

**Y ella nombró el principio, que vale más que el caso:** *las estructuras enseñan; un arma cargada sobre la mesa enseña a disparar.* El que la habría disparado no cometía ningún error de juicio: encontraba un remoto llamado `DuelReveal` justo cuando implementa la animación de la revelación, con el nombre perfecto, y usaba lo que estaba puesto. La defensa no es esperar que nadie lo use — es que no exista. **Mismo movimiento de siempre: convertir la convención en imposibilidad**, como `WrappedItemView` sin campo `isFake` y como `InventoryService` sin función que reste de la colección.

**Verificado al borrar:** cero listeners huérfanos. `DuelController` conecta exactamente dos remotos —`DuelState` y `DuelEmote`— y ninguno era éste. Nada quedó esperando algo que ya no existe.

En su lugar quedó un comentario en `Net.luau` que dice por qué el hueco está ahí. Un borrado sin explicación se deshace: el próximo que necesite mandar una revelación ve tres remotos, piensa "falta uno", y lo agrega. Ahora lo primero que lee es que agregarlo **es** abrir la segunda salida.

---

## 2026-08-04 · 🔒 La compuerta de fase es pieza load-bearing de la regla de oro

Confirmar la salida única dejó algo que hasta ahora estaba implícito, y va explícito porque de esto depende la regla:

```lua
reveal = if duel.phase == "Reveal" then duel.reveal else nil,
```

Esa línea, **dentro de `stateFor` en `DuelView.luau`**, es el **único punto del código donde la regla de oro se levanta**. Y se levanta **por fase, no por camino**: no importa quién pidió el estado ni desde dónde, importa en qué fase está el duelo. Por eso no hay forma de llegar a la verdad tomando otra ruta — no hay otra ruta.

**Cualquier refactor futuro de `stateFor` o `DuelView` hereda la obligación de preservar esa compuerta.** No es una optimización ni una comodidad: sacarla no rompe ningún test de tipos, no rompe ninguna prueba de Studio, y filtra `isFake` al rival en toda fase de negociación. Es el fallo silencioso más caro que el proyecto puede tener.

**Inventario oficial de salidas servidor→cliente:**

| Salida | Qué manda | Regla de oro |
|---|---|---|
| **UNA** de estado: `broadcast` → `stateFor` | `DuelState` | Censura por defecto (`viewOf`), verdad **solo** en fase `Reveal` |
| **Cinco** triviales | strings de aviso y emotes | No las tocan: no cargan objetos de duelo |
| **Cero** remotos sin consumidor | — | Ninguna arma cargada esperando |

Auditar esto es contar hasta seis. Ese es todo el punto de que el número sea conocido y chico.

---

## 2026-08-04 · Partición cerrada: `DuelOffers` y el corte que no era mecánico

**1095 líneas quedaron en cinco módulos, el mayor de 712.** Los tres primeros cortes fueron movimiento puro. El cuarto no, y la diferencia importa:

| Módulo | Qué contesta |
|---|---|
| `DuelTypes` | las formas |
| `DuelView` | la única forma en que un estado llega a un cliente |
| `DuelReveal` | la verdad completa, construida como valor |
| `DuelOffers` | si una oferta es legal, y qué pone en la mesa |
| `DuelService` | la **vida** del duelo: quién está en uno, qué fase, de quién es el turno, cuándo termina |

**El corte de `DuelOffers` no fue "mover `submitOffer`".** Fue la línea entre las **reglas** de una oferta y el **flujo** del duelo alrededor. `submitOffer` hacía las dos cosas seguidas, y partirlo por la mitad era la decisión real:

- **Adentro (`DuelOffers.build`):** parsea, valida las cuatro capas, tira apariencias, cobra las falsificaciones, deja las copias en escrow — y **devuelve** envoltorios o un motivo.
- **Afuera (`DuelService.submitOffer`):** en qué fase estamos, guardar la oferta, pasar el turno, difundir.

**Por qué ahí y no en otro lado: D1.** Un bot tiene que armar una oferta pasando por **la misma validación** que un humano (condición 1 del plan de D1). Con `build` como unidad invocable, eso es llamar a la misma función. Sin ella, el bot necesitaría un segundo camino que alguien tendría que mantener de acuerdo con el primero a mano — y el día que se desincronicen hay dos juegos corriendo en el mismo servidor.

**Ediciones declaradas** (porque este no fue movimiento puro): `rollAppearance`, `toRequests`, `findCopy` y `parseRequests` se mudaron textuales; `reject` y `sideOf` se quedaron, porque `negotiate` y `emote` también los usan. Dentro de la región movida, cada `return reject(player, MSG)` pasó a `return nil, MSG` con el **mensaje intacto**, así los logs se leen igual — el que rechaza es quien llama. `Items`, `WrapAppearance` y `WrapRequest` salieron de `DuelService`: el corte los dejó huérfanos.

**Deuda que queda anotada:** `DuelService` sigue en 712 líneas, más del doble del límite de 300. Lo que queda adentro es todo ciclo de vida (arranque, watchdog, fases terminales, negociación, emotes), que es una sola responsabilidad — pero es grande. **No se parte más ahora**: los cortes que faltan no tienen un consumidor que los pida, y partir sin consumidor es inventar fronteras. D1 va a decir dónde duele.

---

## 2026-08-04 · D1 entregada, y tres cosas que aparecieron al construirla

Las tres condiciones aprobadas se cumplieron. Lo que sigue son los desvíos y hallazgos, que es la parte que importa.

### La condición 1 quedó estructural, no prometida

`DuelStakes` es el único módulo que sabe que un bot no tiene perfil. Todas las demás capas reciben un `Side` y no preguntan quién es. Verificado: **toda escritura a perfil dentro de un duelo pasa por ahí**; los usos de `.player` que quedan son sentar gente en la mesa y mandarle cosas a un cliente.

Y `Side.player` es opcional en vez de haber un tipo `BotSide` aparte. Con dos tipos, las reglas —turno, fase, límites, tope de fakes, coherencia del modelo A— podrían separarse sin que nada avise. Con uno solo, no hay dónde separarse.

### Se borraron `isBot` y `userId` del payload replicado

Estaban en `DuelPlayerView`: `isBot` fijo en `false`, `userId` sin ningún lector. **Esperando que D1 los llenara.** Y llenarlos es el movimiento natural: §34 dice que el jugador no recibe señales obvias de que el rival es un bot, y un booleano replicado llamado `isBot` es la señal más obvia que existe — una línea de inspección del cliente. `userId` es la misma fuga disfrazada: un bot no tiene cuenta, así que lo que fuera a ese campo (0, -1, un id prestado) **era** el dato.

Misma especie que el remoto `DuelReveal`, misma respuesta. Si el tutorial necesita anunciar a Don Trueque, eso es un hecho **del tutorial** y viaja con él, no una bandera general en todos los duelos.

### Desvío del plan: el tope se aplica en la cola, no al pagar

El plan decía: al llegar al tope, no pagar nada. Al implementarlo apareció el problema: **un duelo que llegó a la revelación ya intercambió las apuestas.** No pagarle a alguien que ya entregó sus copias no es "no cobrar", es **perder**. El tope, pensado neutro, se convertía en un castigo por jugar estando topeado.

Mismo instrumento, mismo número único en el perfil, un momento antes: al alcanzar el tope, **la cola deja de ofrecer rivales de relleno**. No se saca nada, no se paga a medias, y el jugador sigue esperando a una persona — que es para lo que la cola existe.

La señal que esto genera ("hay bots") es la misma que el plan ya había aceptado: le llega solo a quien ya extrajo un día entero de valor de ellos.

---

## 2026-08-04 · ⚠️ El bot casi nunca decide, y no es culpa del bot

**Hallazgo al trazar el flujo completo, y hay que decirlo antes de que los números de `Bots.luau` prometan algo que no pasa.**

`beginNegotiating` fija `duel.turn = 1` siempre, y en un duelo contra bot el humano es siempre el slot 1. El slot 2 solo recibe el turno cuando le deben una enmienda. Entonces:

| Lo que el bot hace contra un humano | Lo que no |
|---|---|
| Arma su oferta | Aceptar |
| Enmienda cuando le piden más | Rechazar |
| | Pedir más |
| | Acusar ¡ES FAKE! |

**`Bots.raiseChance`, `fakeCallChance` y `declineChance` hoy solo tienen efecto en duelos bot-contra-bot.** Quedan escritos igual porque el consumidor existe y está probado —`decide()` corre—, solo que la alternancia de turnos no le da la oportunidad.

**Esto no lo introdujo D1.** Es el modelo de turnos actual, que `arquitectura.md` §5 ya marca como provisional: *"el que oferta mueve primero. El slot 1 abre por ahora; alternar turnos es A2."* En humano-contra-humano pasa lo mismo: el slot 2 nunca abre.

**No lo cambio acá.** Alternar turnos es una decisión de diseño de negociación —quién puede presionar a quién y cuándo— y pertenece a A2, no a una tarjeta de bots. Pero D1 se entrega con esta limitación a la vista y no descubierta después: **un rival que nunca te presiona es la mitad del juego.**

---

## 2026-08-04 · 🔒 DOCTRINA — el cliente controla la forma, no solo el contenido

**Sale del agujero de duplicación del escrow, y es la lección más cara del proyecto hasta ahora.**

El código validaba con cuidado **cada entrada** de una oferta: el tipo, que el claim exista en el catálogo, que `isFake` concuerde con `copyId`, que la copia sea tuya, que un genuino no mienta. Cinco capas por elemento, escritas con atención.

Y después confiaba en el **orden de la lista**.

> **La suposición era: "las primeras N entradas de una enmienda son la oferta anterior."**
> Nadie la escribió como suposición. Estaba implícita en un `for index = alreadyWrapped + 1, #wrapped`.

**El principio general:** toda propiedad de una estructura que el cliente arma —**el orden, la longitud, la unicidad, que un prefijo se repita, que dos listas se correspondan**— no existe hasta que el servidor la verifica. Validar los elementos y confiar en la forma es validar la mitad.

Es la misma familia que la regla de oro, pero un piso más abajo: la regla de oro dice *no le mandes al cliente lo que no debe saber*; esta dice *no le creas al cliente cómo ordenó lo que te mandó*.

**Y la defensa fuerte no es verificar el orden — es que el orden no importe.** El arreglo tiene dos mitades y la diferencia entre ellas es la doctrina entera:

| | Qué garantiza |
|---|---|
| **Débil:** la enmienda debe empezar con la oferta que enmienda (`DuelOffers`) | *este camino* no dupea |
| **Fuerte:** `takeCopy` rechaza un `copyId` que ya está en escrow (`InventoryService`) | *no existe camino* que dupee |

La débil se queda porque da el mensaje claro y mantiene exacta la cuenta del costo. Pero la que hace el trabajo es la fuerte: **el ledger de escrow ahora guarda identidad (`copyId`), no solo tipo**, y la identidad no se puede reordenar. Si mañana alguien vuelve a suponer un orden, la doble toma sigue siendo imposible.

Mismo movimiento de siempre —convertir la convención en imposibilidad— aplicado por tercera vez: `WrappedItemView` sin campo donde poner `isFake`, `InventoryService` sin función que reste de la colección, y ahora un escrow donde una copia no puede entrar dos veces.

### Cómo apareció: el bot fue el primer usuario adversarial

**No lo encontré leyendo el código. Lo encontré escribiendo un actor que lo usa.**

Al programar cómo enmienda el bot tuve que preguntarme qué manda exactamente en el segundo payload, y ahí la suposición de orden quedó a la vista. Leer `submitOffer` cien veces no la muestra, porque leyendo uno reconstruye la intención; **escribiendo un cliente uno tiene que producir los bytes**.

Esa es la moraleja que se lleva D1 más allá de los bots: **un actor programado contra tu propia superficie encuentra lo que leerla no encuentra**, porque no comparte tus suposiciones — solo tiene la firma. Vale para el bot de hoy y para el auto-juego de D2, que va a ejercitar miles de secuencias que ningún humano tipearía.

### Protocolo aclarado para agujeros activos

Renata lo fijó al ratificar el arreglo, y queda como regla: **en un agujero de seguridad activo, el orden correcto es arreglar y reportar.** Un dupe abierto esperando aprobación es peor que cualquier error de criterio en el arreglo. El caso (a) exige que el **veredicto ocurra**, no que el arreglo espere.

---

## 2026-08-05 · 🔒 CANON — dos lecciones de prueba, del mismo agujero

Renata las subió al canon al ratificar el arreglo del escrow. Quedan acá porque las dos son operativas, no filosóficas.

### 1. Las suposiciones no escritas viven en los límites de los bucles

El código validaba cinco capas **por elemento**, con atención. Y confiaba en la **forma** por un `for index = alreadyWrapped + 1` que nadie decidió nunca.

> **Las suposiciones peligrosas no están en las líneas que alguien escribió mal. Están en las que nadie escribió.**

Y la mitad operativa —cómo se cazan—: leer `submitOffer` cien veces no la muestra, porque **el lector reconstruye la intención**. Escribir un cliente obliga a producir los bytes, y **los bytes no tienen intención**.

**Corolario para el futuro:** cuando una superficie acumule suficiente valor, escribirle un adversario paga más que releerla. El bot fue el primer atacante honesto del sistema — no porque quisiera romper nada, sino porque no compartía ninguna de nuestras suposiciones: solo tenía la firma.

### 2. Una prueba de rechazo verifica LA RAZÓN del rechazo

El documento de pruebas contaba como **aprobados** rechazos que ocurrían por la razón equivocada: los payloads malformados chocaban contra el chequeo de fase antes de llegar a la validación que decían probar.

> **Un rechazo correcto por la razón equivocada es un falso verde: el test pasa y la defensa que certifica no se ejercitó jamás.**

Regla: una prueba de rechazo verifica **capa y mensaje**, no solo que algo se rechazó.

**Y apareció una segunda vez el mismo día, con otro disfraz:** el auto-juego iba a reportar "escrow terminó en 0" en duelos bot-contra-bot, donde **ningún lado tiene perfil** y el escrow por lo tanto nunca se escribe. Cero porque no existe, no porque se limpie bien. Se arregló igual: haciendo que la aserción alcance la capa que dice probar (modo títere, un lado con perfil real), y **etiquetando el número como VACUOUS cuando no la alcanza** — un número que no puede fallar nunca debe parecerse a un número que pasó.

### 2-bis. Los guiones de prueba se pudren igual que el código

Media validación de A1.3 estuvo *"escrita y verificada"* sin correr **jamás**, porque `_G.dc` no llegaba al controlador. Verificar teclas y comandos contra el código antes de cada sentida es parte del estándar desde ahora.

---

## 2026-08-05 · El tope del bot es política de la cola, no garantía del mecanismo

`DuelService.startAgainstBot` **no** consulta el tope diario. Lo consulta `MatchmakingService` antes de llamarlo.

**Hoy se sostiene** porque hay exactamente un llamador. Pero por la doctrina de este proyecto eso es una **convención**, y una convención es un agujero esperando a su segundo llamador — el tutorial de Don Trueque (§34), un botón de "jugar contra un bot", cualquiera.

**No se hizo incondicional a propósito:** el tutorial probablemente **debe** estar exento, así que meter el chequeo adentro del mecanismo decidiría por adelantado una pregunta de diseño que todavía no toca. Queda como frontera nombrada, con su disparador escrito en el código: quien agregue el segundo llamador o consulta el tope o deja escrito por qué no.

**Alternativa descartada:** chequear adentro de `startAgainstBot` y agregar un parámetro `ignoreCap`. Se descartó porque un booleano de escape en la firma es la convención otra vez, con más pasos.

---

## 2026-08-05 · 🔒 CANON — una acción rechazada no puede dejar al actor sin jugada

**De los dos bugs que encontró el auto-juego. Los dos eran la misma cosa con dos caras.**

Un actor con el turno pide algo, el servidor lo rechaza correctamente, y el actor **se queda quieto**. Nadie más puede jugar —no es su turno— así que el duelo queda inmóvil hasta que el watchdog de fase lo mata. Lo que ve el jugador: **un rival que se congela y un duelo que muere sin motivo visible.**

### El del servidor es el más instructivo: no era un error, era una contradicción de reglas

Dos reglas individualmente correctas:

| Regla | Valor |
|---|---|
| Una enmienda tiene al menos un envoltorio **más** que la oferta que enmienda | `#previous + 1` |
| Ninguna oferta pasa de `maxItemsPerOffer` | `4` |

Chocan **exactamente** cuando la oferta ya tiene 4: la enmienda necesitaba 5 con techo de 4. `needs 5-4`. **Toda respuesta posible era ilegal**, así que quien debía la enmienda no podía actuar.

> **Reglas individualmente correctas pueden componer una trampa sin salida, y esas trampas viven en los bordes de los rangos.**

Es pariente directa de *"las suposiciones no escritas viven en los límites de los bucles"*: las dos dicen que el peligro está donde nadie miró porque cada pieza, por separado, estaba bien.

### Dónde se arregla: en el PEDIDO, no en la respuesta

Se rechaza el "Pedir más" cuando el rival ya puso el máximo. **No se le pide a nadie lo que no puede dar.** Arreglarlo del lado de la respuesta —aflojar el mínimo de la enmienda, o subir el techo— sería cambiar el balance para tapar una contradicción lógica.

**Consecuencia atada a E2:** eso ahora es una regla que el jugador **siente**, así que el botón se deshabilita con motivo visible. Un botón que existe, se toca y no hace nada se lee como un bug del juego, no como una regla.

### La red, y por qué se cuenta

El cerebro del bot ya no termina un turno sin haber actuado: cualquier rechazo cae a `Accept`, que siempre es legal para quien tiene el turno. **Aceptar un mal trueque es peor jugada que subir; congelarse no es jugada.**

Pero eso es una red de **liveness**, no una estrategia, así que está **instrumentada**:

| Lectura | Qué significa |
|---|---|
| En auto-juego | Debe ser **0**. Si dispara, el cerebro tiene un hueco nuevo — y la corrida **falla** por eso |
| Contra personas | TODO(F3) → analítica. Quien descubra cómo **acorralar** al bot hacia rechazos consigue un **Accept forzado** cada vez, que es una forma de ordeñarle buenos trueques a un rival sin jugadas legales |

La red evita el congelamiento; **el contador nos dice si alguien la está ordeñando.**

---

## 2026-08-05 · 🔒 CANON — el verde de una prueba se gana

**Tercera aparición del falso verde en dos días, y con esta la regla queda general.**

| # | Dónde | El verde mentiroso |
|---|---|---|
| 1 | Batería de ofertas inválidas | Rechazos correctos **por la razón equivocada**: chocaban contra el chequeo de fase antes de llegar a la capa que decían probar |
| 2 | Escrow en auto-juego | "Terminó en 0" en duelos donde **ningún lado tiene perfil** y el escrow nunca se escribe |
| 3 | El propio arnés | `RESULT: PASS` impreso al lado de `TIMED OUT: 2` |

> **El verde de una prueba se GANA con la propiedad que dice certificar. Y toda métrica que la corrida reporta o cuenta para el veredicto, o explica por qué no.**

De ahí las dos formas que ahora tiene el arnés: los timeouts y las activaciones de la red **fallan** la corrida; el escrow en modo bot-vs-bot se imprime como **`VACUOUS`** en vez de un `0` pelado — **un número que no puede fallar nunca debe parecerse a un número que pasó.**

**El razonamiento modelo, que es la parte reusable:** *"con bots actuando en centésimas de segundo, un watchdog no debería rescatar nada nunca"*. Se supo **qué significaría un timeout antes** de decidir si tolerarlo. Decidir después es como se racionaliza un rojo hasta volverlo verde.

---

## 2026-08-05 · 🚪 El auto-juego es una PUERTA, no una herramienta opcional

**Regla vigente desde hoy:** ninguna tarjeta que toque el duelo se cierra sin su corrida de `./selfplay.sh` limpia. Entra a la *definition of done* junto a `--!strict` y la validación en cuatro capas.

**Por qué cambia la economía del proyecto:** hasta hoy, verificar **ejecución** costaba una sentada de Renata. Desde hoy cuesta un comando. Los módulos bajo prueba son los archivos reales de `src/` —solo se falsea la superficie de Roblox—, así que cada regla nueva puede pagarse su regresión en segundos, para siempre.

**Por qué nadie lo había hecho antes:** el `luau` que instala `rokit` es **arm64** y la máquina es **Intel**. Fallaba con `Bad CPU type in executable`, que se lee como "esto no se puede" en vez de "falta el binario correcto". `brew install luau` trae el x86_64. Un misterio que ni sabíamos que teníamos.

**Lo que la puerta NO reemplaza, y está escrito en el propio script:** ProfileStore (guardado, session locking, migraciones) es el checkpoint 3 y necesita Studio; la escena y el cliente entero tampoco están cubiertos. Un verde acá no es un verde de todo — y esa lista explícita es lo que hace confiable al resto del reporte.

---

## 2026-08-05 · F3: el sink de Roblox sale APAGADO, y eso es la decisión

**Decidido:** `AnalyticsService` entrega los cinco eventos del MVP, pero `Analytics.sendToRoblox = false`. Los eventos van a consola y a un buffer en anillo; a Roblox Analytics, todavía no.

**Por qué:** la firma `LogCustomEvent(player, eventName, value, customFields)` la escribí **de memoria**. La regla 5 de este proyecto dice que una API inventada cuesta horas, y ya nos pasó con las fuentes (`Caveat`, `Amatic` y otras dos que no existen en el engine y que habría escrito con la misma confianza).

**La forma del compromiso importa más que la decisión:** en vez de no escribir el binding, o de escribirlo y confiar, quedó **aislado en una función que nada usa**. Todo lo que va después ya funciona —los eventos se cuentan, se imprimen, se testean—, así que nadie está esperando. Verificar la firma es abrir la doc cinco minutos y prender un flag; si está mal, esa función es lo único que cambia.

**Alternativa descartada:** dejar `AnalyticsService` como stub hasta poder verificar. Se descartó porque los `TODO(F3)` ya eran cuatro y crecían: cada uno era un lugar donde el código sabía algo que nadie iba a contar. Que el destino final esté pendiente no es razón para no tener la puerta.

**Y una cosa que el diseño hace a propósito:** el evento se llama `duel_finished` y lleva `accusedBy` y `accusationCorrect` como campos, en vez de haber un evento `fake_called` aparte. Una acusación es un **hecho sobre un duelo**, no una cosa distinta que pasó cerca. Un duelo, una fila — que es lo que hace que la pregunta de §8 ("¿la ficha se queda?") se conteste con una consulta y no con un join.

---

## 2026-08-05 · La verificación de la API cambió el diseño, no la firma

**Renata verificó `LogCustomEvent` contra la doc. Tres hechos, y el tercero es el que importa.**

**1. La firma estaba bien.** `LogCustomEvent(player, eventName, value, customFields)`, `value` por defecto 1. La cuarentena no era paranoia, pero por la firma no hacía falta.

**2. Hizo falta por esto:** `customFields` **solo honra `CustomField01/02/03`** (`Enum.AnalyticsCustomFieldKeys`). Cualquier otra clave **se ignora en silencio**.

> Pasar `{raises = 3, fakes = 2}` habría **compilado, corrido, y tirado los datos a la nada.**

Cuarta aparición del falso verde, y la primera atajada **antes de nacer**. La cuarentena valió por una razón distinta de la que la motivó — que es más o menos la definición de que valía la pena.

Además: los valores deben ser **strings**, y hay tope de **8.000 combinaciones únicas** entre los tres campos, compartido por toda la experiencia y **permanente**.

**3. La restricción que cambia el diseño:** los eventos custom son **agregaciones con breakdowns**, no filas guardadas ni consultables. *"Un duelo, una fila, una consulta"* **no existe** en ese dashboard.

**Lo que NO cambia:** el esquema interno. La fila completa, con la acusación como campo, sigue siendo la fuente de verdad y es lo que guarda el buffer. **Lo que sale es una proyección**, no un volcado: `duel_finished` con `value=1` y tres dimensiones — `fakes-N` / `acusacion-acerto|fallo|no_hubo` / `raises-N`. La pregunta de §8 se contesta con un breakdown, no con una query.

### El riesgo de cardinalidad era real y específico

Varios motivos de rechazo llevan **GUIDs** (`does not own copy {copyId}`). Mandarlos crudos habría quemado las 8.000 combinaciones **permanentes** de la cuenta en una tarde ocupada, llevándose puestos todos los breakdowns útiles.

**Se normaliza el motivo a su plantilla** antes de proyectarlo: 17 mensajes distintos colapsan en 12 plantillas, verificado contra strings reales.

**Alternativa descartada: una tabla de motivos conocidos.** Una tabla hay que mantenerla, y el día que alguien edite un mensaje el bucket deja de matchear **en silencio** — el mismo falso verde, un nivel más arriba. Despojar es mecánico, no se mantiene, y un mensaje nuevo se agrupa solo.

**Y un cortacircuitos:** las combinaciones se cuentan en `record`, **no en el sink**. Las 8.000 se gastan con lo que uno *mandaría*, así que el número tiene que ser conocible con el sink apagado — que es justamente lo que le permite al auto-juego **medir** la aritmética en vez de confiar en ella (200 duelos → 24 combinaciones contra un presupuesto de 2.000). Pasado el presupuesto, los eventos siguen saliendo **sin breakdowns**: perder las dimensiones en un servidor se recupera; gastar la cuota permanente de la experiencia, no.

---

## 2026-08-05 · 🔒 CANON — la analítica nunca puede ser causa de fallo del juego

**Jerarquía, no preferencia.** Un duelo que termina tiene que terminar aunque el evento que lo describe no se pueda mandar. La analítica es lo **menos importante** de cualquier camino de código donde esté.

En la práctica: el sink va en `pcall`, y uno que falla **se desactiva** en vez de reintentar —un aviso por duelo es cómo un fallo chico se convierte en la razón por la que nadie lee el output—; los eventos se registran **al final** de `finish`, con el duelo ya liberado; y el cortacircuitos de cardinalidad degrada a "sin breakdowns" en vez de a "sin eventos".

Es la misma familia que *"cobrar antes de otorgar"* y que *"el escrow sale al ofertar"*: **elegir de antemano cuál mitad se sacrifica cuando algo falla**, en vez de descubrirlo el día que falla.

---

## 2026-08-05 · 🔒 CANON — el valor del aislamiento es genérico

> **La cuarentena valió por una razón distinta de la que la motivó, que es más o menos la definición de que valía la pena.**

El binding de Roblox se aisló por miedo a que la **firma** estuviera inventada. La firma estaba bien. Lo que el aislamiento atajó fue otra cosa entera: que `customFields` ignora en silencio toda clave que no sea `CustomField01/02/03`.

**Uno aísla contra el riesgo que imagina, y el aislamiento ataja el que no imaginó.** Por eso la pregunta al escribir una frontera no es "¿qué tan probable es este riesgo?" sino "¿cuánto cuesta la frontera?". Si es barata, se pone — el riesgo que la justifique aparece después y no va a ser el que uno tenía en la cabeza.

Familia: `WrappedItemView` sin campo para `isFake`, `InventoryService` sin función que reste, `DuelStakes` como única capa que sabe de perfiles.

---

## 2026-08-05 · 🔒 Toda proyección trae su aritmética de cardinalidad

**Regla, no costumbre.** Una cuota externa compartida y permanente —las 8.000 combinaciones de Roblox Analytics— no es un bug que se arregla: es un recurso que **se gasta**, y gastarlo es un self-DoS irreversible contra la propia analítica.

Por eso el presupuesto es **parte del contrato de la proyección**, no un comentario en otro archivo: la aritmética va escrita al lado de cada una (`5 x 3 x 7 = 105`). Quien agregue una dimensión hace la cuenta ahí mismo o la está gastando por accidente.

**Tres criterios que se aplicaron y quedan:**

1. **Las normalizaciones que no requieren memoria le ganan a las que sí.** Despojar una plantilla es mecánico; una tabla de motivos conocidos hay que mantenerla, y deja de matchear en silencio el día que alguien edita un mensaje.
2. **Se cuenta donde se produce, no donde se envía.** La cuota se gasta con lo que uno *mandaría*, así que el número tiene que ser conocible con el destino apagado — que es lo que lo vuelve **medible** en vez de creíble.
3. **La degradación se elige de antemano.** Pasado el presupuesto: eventos sin breakdowns, nunca sin eventos. De los dos fallos posibles, el que no se propaga.

**Y la cuota se trata como permanente aunque la doc no lo jure.** Es la lectura segura en los dos mundos: si Roblox la resetea, sobró prudencia; si no, se salvaron los breakdowns de la cuenta.

---

## 2026-08-05 · ⚠️ CORRECCIÓN — la compuerta de fase NO era load-bearing

**El 2026-08-04 escribí, y Renata adoptó, que la compuerta `if duel.phase == "Reveal"` dentro de `stateFor` era "el único punto del código donde la regla de oro se levanta" y "pieza load-bearing".**

**Era una exageración, y la prueba de mutación la desarmó.** Borrando la compuerta entera, el spec sigue en verde y ningún cliente recibe nada de más.

**Por qué:** `duel.reveal` **solo se asigna en la transición terminal**. Durante toda la negociación es `nil`, así que la compuerta no está reteniendo nada — no hay qué retener.

| | Qué impide realmente la fuga |
|---|---|
| **Load-bearing** | Que `duel.reveal` se asigne **únicamente** al entrar en Reveal |
| **Defensa en profundidad** | La compuerta de fase en `stateFor` |

**La compuerta se queda, y sigue valiendo** — pero por una razón distinta de la que le atribuí: existe para el día en que algo **sí** calcule la revelación antes de tiempo (pre-renderizar la animación, una mecánica de inspección, un modo espectador). Ese día es la única cosa entre la verdad y un cliente.

**Y la aserción que la cubría no podía fallar**, que por nuestro propio canon es un falso verde. Se arregló haciéndola real: el spec ahora **planta** una revelación a mitad de la negociación —exactamente lo que haría esa función futura— y verifica que no llegue a nadie. Con la compuerta borrada, esa aserción **falla**.

**La lección operativa:** *"esta línea es lo que nos protege"* es una hipótesis, y la prueba de mutación es cómo se verifica. Sin ella, la frase se propaga por los documentos y la gente empieza a razonar sobre seguridad con un mapa equivocado — que es peor que no tener mapa, porque se confía.

---

## 2026-08-05 · 🔒 CANON — una prueba de mutación es cómo se gana el verde

**Tres cosas pasaron al escribir el spec, y las tres son la misma disciplina.**

**1. La mutación que no mutó.** Los primeros tres intentos de romper `viewOf` a propósito fueron **no-ops silenciosos**: el `replace` no matcheaba porque el archivo estaba en varias líneas y mi patrón en una. Reporté "el spec no caza la mutación" cuando la mutación nunca existió.

> **Una prueba de mutación necesita su propia verificación**: que la mutación entró. Ahora el script afirma que el objetivo existe antes de reemplazar, y cuenta el marcador en el bundle.

**2. La aserción que sí servía.** Con la mutación de verdad aplicada, la regla de oro cazó **180 fugas** en 40 duelos. Ese número es lo que convierte *"`WrappedItemView` no tiene campo para `isFake`"* en *"ningún cliente recibió uno"* — que son afirmaciones distintas y solo la segunda es una prueba.

**3. La aserción que no podía fallar.** La de la compuerta de fase pasaba con la compuerta borrada. Ver la corrección de arriba.

**Regla:** toda aserción que cubra una regla inviolable se acompaña de la mutación que la rompe, y se verifica que **con la mutación falla**. Un verde que nunca vio rojo no es evidencia de nada.

---

## 2026-08-05 · `runFinishRaceCheck`: qué afirma cubrir y qué cubre

**Mismo tratamiento que la compuerta, y el mismo resultado: la razón que le atribuíamos no era la que actuaba.**

| | |
|---|---|
| **Qué parece cubrir** | Que dos caminos terminales sobre el mismo duelo no se pisan — y que el **claim de `resolving`** es lo que frena al segundo |
| **Qué cubre de verdad** | Solo lo primero. Al segundo camino lo frena el **registro**: `duels[id]` ya está en `nil` cuando llega |
| **La mutación que lo demuestra** | Borrando el bloque `if duel.resolving then ... end` **entero**, `runFinishRaceCheck` **sigue reportando PASS**, incluido `second path turned away: 1` |

**Son dos garantías distintas y hoy solo se ejercita una.** Un PASS significa *"los dos caminos no se pisaron"*, **no** *"el claim está probado"*.

> **Dicho sin rodeos, porque es lo que hay que poder leer de un vistazo: el claim de `resolving` hoy NO está probado por nada.** No por este check, no por el spec, no por el auto-juego. Es código correcto y sin evidencia — que es una categoría distinta de "código probado" y de "código sospechoso", y merece su propio nombre en el mapa.

### Por qué el claim no llega a actuar

Protege el tramo entre reclamar el duelo y emitir el broadcast. Ese tramo solo importa si algo **cede** ahí adentro, y hoy nada cede: la revelación se construye de forma síncrona y viaja dentro del `DuelState` final; la pausa dramática la maneja el cliente.

### Qué haría falta para cerrar la diferencia

**Un yield en `resolve()`, entre marcar `resolving` y llamar a `broadcast`.** No se puede fabricar en una prueba sin meterlo en producción, así que la deuda no se salda escribiendo un test — se salda el día que B3 o A3-final metan un `await` real ahí (guardado de perfil, transferencias persistentes).

**Lo que sí se hizo:** en vez de anotar *"acordate de re-correr el check cuando aparezca un yield"* —que es una convención, y las convenciones se olvidan—, el spec **prueba la precondición**. Corre el camino terminal dentro de una corrutina, la reanuda una sola vez, y verifica que quedó `dead`:

```
PASS  the Reveal path does not yield (so `resolving` is still decorative)
```

El día que alguien meta un `await` ahí, esa aserción se pone en rojo con el mensaje *"A YIELD APPEARED: re-run the race check with it present"*. **La nota que alguien tenía que recordar se convirtió en una alarma que suena sola.**

---

## 2026-08-05 · 🔒 CANON — las frases sobre seguridad también se testean por mutación

> **Razonar sobre seguridad con un mapa equivocado es peor que no tener mapa, porque se confía.**

**Corolario operativo:** toda afirmación de la forma *"esta línea es lo que nos protege"* se verifica igual que el código — **borrando la línea y viendo qué se rompe**. Si no se rompe nada, la afirmación es falsa y hay que encontrar qué protege de verdad.

Dos veces en un día, las dos con el mismo resultado:

| Afirmación | Qué protegía de verdad |
|---|---|
| "la compuerta de fase es load-bearing" | La **asignación** de `duel.reveal` solo en la transición terminal |
| "el claim de `resolving` frena el segundo camino" | El **registro**: `duels[id]` ya en `nil` |

Las dos frases eran razonables, estaban escritas por gente que había leído el código, y las dos eran falsas. **La diferencia entre una y otra explicación no es académica: determina qué línea alguien puede borrar sin miedo el año que viene.**

---

## 2026-08-05 · 🔒 CANON — la escalera epistémica del spec

**Tres afirmaciones que suenan igual y no valen lo mismo:**

| Nivel | Afirmación | Qué es |
|---|---|---|
| 1 | "`WrappedItemView` no tiene campo para `isFake`" | Sobre **tipos**. Verdad de compilación |
| 2 | "ningún cliente recibió uno en 40 duelos" | Sobre **ejecución**. Verdad observada |
| 3 | "con el mutante aplicado, saltaron 180 fugas" | Que **la alarma suena** |

**Solo la segunda es prueba, y sin la tercera no se sabe si la segunda vale.** Un verde de nivel 2 con una aserción rota es indistinguible de un verde de nivel 2 con el sistema sano.

**Y el quinto falso verde fue el más recursivo de todos:** el test de mutación —el que existe para darle rojo al verde— reportó **su propio verde falso**. "El spec no caza la mutación" cuando la mutación nunca se aplicó: un `replace` que no matcheó y no dijo nada.

**Requisito del arnés, ya implementado:** un test de mutación afirma **primero** que el objetivo existe y que el reemplazo ocurrió —el marcador contado en el bundle— y **recién después** opina sobre si el spec lo cazó.

---

## 2026-08-05 · 🔒 CANON — el control positivo: la fila roja es la que firma las verdes

**La matriz de C-DUPE es el estándar de acá en adelante para toda regla inviolable:**

| Mutación | Resultado | Qué prueba |
|---|---|---|
| Defensa A borrada | Rechazado | B sola alcanza |
| Defensa B borrada | Rechazado | A sola alcanza |
| **A y B borradas** | **FALLA** | **El ataque es real, y lo detiene el código** |

**Esa última fila tiene nombre en el oficio: es el CONTROL POSITIVO.** Un test de defensa sin la fila donde el ataque **funciona** no prueba que la defensa lo detiene — prueba que *algo* lo detiene. Quizá el fixture. Quizá la luna.

**Y es exactamente lo que enseñó el sexto falso verde:** el test pasaba con **las dos** defensas borradas, por una razón ajena a toda defensa — la mano inicial tenía **una copia de cada objeto** y el ataque necesita dos. El rechazo certificaba la forma del inventario, no el código.

**Regla, hermana de la del mutador:** un test de ataque verifica **primero** que el atacante tiene los medios en ese entorno —la segunda copia, el estado necesario, el mutante efectivamente aplicado— y **su control positivo es la prueba de que los tiene**.

**Seis falsos verdes, seis mecanismos distintos, una moraleja repetida:** el verde hay que ganárselo, y **la fila roja es la que lo firma**.

| # | Dónde | Por qué era falso |
|---|---|---|
| 1 | Batería de validación | Rechazos por la razón equivocada (fase, no capa) |
| 2 | Escrow en auto-juego | Cero porque nunca se escribió |
| 3 | El arnés | PASS al lado de `TIMED OUT: 2` |
| 4 | `customFields` de Roblox | Claves ignoradas en silencio (atajado antes de nacer) |
| 5 | El mutador | Reemplazo que no matcheó y no dijo nada |
| 6 | El test del dupe | El atacante no tenía los medios |

---

## 2026-08-05 · 🔒 CANON — las deudas condicionales se cablean, no se anotan

> **La nota que alguien tenía que recordar es ahora una alarma que suena sola.**

`runFinishRaceCheck` no prueba el claim de `resolving`, y solo lo probaría si algo cediera entre reclamar el duelo y difundir. La respuesta anterior era una nota en el backlog: *"cuando A3/B3 metan un yield ahí, hay que re-correr el check"*. Una convención, y las convenciones dependen de que alguien se acuerde tres meses después.

**Ahora la precondición se vigila sola:** el spec corre el camino terminal en una corrutina y verifica que vuelva `dead`. El día que aparezca un `await`, la aserción se pone en rojo con `A YIELD APPEARED: re-run the race check with it present`.

**Toda deuda futura de la forma "cuando pase X habrá que hacer Y" hereda este tratamiento: si X es detectable, X se detecta.** Anotarlo es la opción de último recurso, para cuando X genuinamente no se puede observar desde el código.

---

## 2026-08-05 · 🔒 INVENTARIO DE SALIDAS — ahora son DOS vistas, no una

**El inventario certificado del 2026-08-04 decía UNA salida de estado. Quedó viejo el día que `PlayerDataService` entró, y un inventario viejo es peor que ninguno: la próxima auditoría contaría dos y no sabría si el segundo es legítimo o una fuga.**

### El número oficial: **9 envíos, 2 vistas sancionadas**

| Vista | Remoto | Quién la construye | Propiedades que la hacen segura |
|---|---|---|---|
| **DuelState** | `DuelState` | `DuelView.stateFor` (local del módulo) | Una recipiente por lado; **censura por defecto** (`viewOf` campo por campo, sin lugar donde poner `isFake`); la verdad solo en fase `Reveal` |
| **PlayerDataView** | `PlayerData` | `PlayerDataService.viewOf` (local del módulo) | **Un solo destinatario: su dueño**; lista blanca de tres campos; coalescida |

**Desglose exacto, 9 sitios de `FireClient`:**

| Cuántos | Remoto | Qué lleva | ¿Vista? |
|---|---|---|---|
| 1 | `DuelState` | El duelo como lo ve un lado | **Sí** |
| 1 | `PlayerData` | Tu propio perfil | **Sí** |
| 6 | `Notice` | Un string de `Config/Strings` | No |
| 1 | `DuelEmote` | `slot` + `emoteId` | No |

Los seis avisos: dos en `DuelService` (espectador sin perfil), tres en `ShopService` (sin stock, sin Clips, espectador) y uno en `MatchmakingService` (tope diario alcanzado). Ninguno carga objetos de duelo ni nada derivado de un perfil.

### Lo que una auditoría tiene que encontrar

1. **Exactamente dos funciones que construyan una vista**, las dos locales de su módulo: `DuelView.viewOf`/`stateFor` y `PlayerDataService.viewOf`. Ningún otro módulo puede fabricar una.
2. **Cero remotos sin consumidor.** Los nueve nombres de `Net` se disparan y se escuchan.
3. **Ninguna vista construida por clonación.** Ver el canon de la lista blanca.

**Y por qué esta entrada existe:** *"contar las salidas solo sirve como auditoría si el número correcto es conocido y chico"*. Dos es chico. Tres sería una alarma. Cero sería un bug.

**Pero el documento ya no es la única copia.** Esta lista se quedó vieja el día que `PlayerData` convirtió una vista en dos, y una lista que se queda vieja es peor que ninguna. Así que —doctrina de las deudas condicionales aplicada al propio inventario— **está cableada**: el spec junta el conjunto de remotos que el servidor usó en 30 duelos y lo compara con esta tabla. Un envío servidor→cliente que nadie anotó pone la corrida en rojo **con su propio nombre en el mensaje**:

```
FAIL  every send went through a sanctioned remote (1 unknown)
      --  UNDOCUMENTED: QueueJoin -- update the inventory in decisiones.md
```

Verificado con control positivo: se agregó un envío por un remoto ajeno y la aserción lo nombró.

---

## 2026-08-05 · 🔒 CANON — las vistas se construyen, nunca se clonan

**Ley general, no ya doctrina de `DuelView`.** Toda vista que va al cliente se arma **campo por campo** —lista blanca— y jamás clonando-y-podando —lista negra.

**La diferencia es la dirección en que fallan:**

| | Cuando te equivocás |
|---|---|
| **Lista blanca** | Falta un campo → **se nota** (la UI no lo dibuja) y se agrega |
| **Lista negra** | Sobra un campo → **se filtra en silencio** |

**Medido, no argumentado:** clonando el perfil en `PlayerDataService`, el payload fugó **doce campos de una sola vez** —`botEarnings`, `cosmetics`, `dataVersion`, `escrow`, `level`, `quests`, `receipts`, `stats`, `xp`— y cuatro aserciones se pusieron en rojo nombrándolos. Con lista blanca, agregar un campo al perfil no puede alcanzar al cliente: hay que escribirlo dos veces, y la segunda es visible en un diff.

---

## 2026-08-05 · 🔒 CANON — el canal lateral: lo que se MUEVE con la verdad

> **Un número que solo se mueve contra bots es tan obvio como una etiqueta.**

**Un dato que CORRELACIONA con un secreto ES el secreto con otro nombre.** Borrar `isBot` del payload no sirve de nada si un contador delator viaja al lado: `botEarnings` sube solo en duelos contra bots, así que un cliente que lo lee sabe cuáles eran, y cuánto valían.

**La pregunta de cierre para toda vista futura no es una, son dos:**

1. ¿Qué campo **carga** la verdad?
2. ¿Qué campo **se mueve** con la verdad?

La primera la contesta el sistema de tipos. La segunda no la contesta nadie más que quien esté mirando.

---

## 2026-08-05 · 🔒 CANON — tres estados, no dos: "correcto y sin evidencia"

Toda pieza de seguridad se etiqueta en uno de tres estados, y **el mapa honesto es el que distingue los dos primeros en vez de fundirlos**:

| Estado | Qué significa |
|---|---|
| **Probado** | Hay una aserción, y la mutación que la rompe la pone en rojo |
| **Correcto y sin evidencia** | Se leyó, se razonó, y **nada lo ejercita** |
| **Sospechoso** | Hay motivo para creer que está mal |

**Habitante único hoy: el claim de `resolving`.** Con su alarma `A YIELD APPEARED` vigilando la precondición que lo mudaría a "probado" el día que alguien meta un yield.

**Fundir los dos primeros es lo que produjo el mapa equivocado de la compuerta de fase:** se creyó "probado" lo que era "correcto y sin evidencia", y se razonó sobre seguridad con eso durante semanas.

---

## 2026-08-05 · El primer falso verde preempatado

**Detalle chico, hito real.** Al escribir la aserción de coalescing de `PlayerDataService` noté que el stub de `task.defer` del arnés corría el callback **inline**. Con eso, "tres cambios producen un push" habría pasado **sin que existiera coalescing alguno**: el test habría medido el stub, no el código.

Se arregló **antes** de escribir la aserción.

**Seis falsos verdes se cazaron después de nacer. El séptimo no llegó a nacer** — porque revisar el entorno del test antes de confiar en su verde ya es reflejo. El canon dejó de solo detectar y empezó a prevenir.

---

## 2026-08-05 · El discriminador de la regla 6: peligroso vs. prometido

**Dos casos, la misma pregunta, respuestas opuestas — y el criterio distinguió solo.**

| | `Net.names.DuelReveal` | `Net.names.PlayerData` + `balanceChanged` |
|---|---|---|
| ¿Alguien lo lee? | No | No |
| ¿Alguna tarjeta lo va a leer? | **No** — el estado ya llevaba la revelación | **Sí** — E3, y llegamos a E3 |
| Qué era | Una **capacidad peligrosa** huérfana: segunda salida para la verdad | Una **capacidad requerida** huérfana: función faltante con el nombre reservado |
| Qué se hizo | **Borrar** | **Completar** |

**"Nadie lo lee" no es la pregunta completa.** La pregunta es *"nadie lo lee **y** ninguna tarjeta lo va a leer"* — y si la segunda mitad da que sí, la deuda no es un arma cargada, es una promesa sin cumplir. Borrar lo huérfano-peligroso, completar lo huérfano-prometido.

---

## 2026-08-05 · El HUD es un `ScreenGui`, y es la respuesta OPUESTA a la de los botones

**Decidido:** el HUD (Clips y colección) vive en un `ScreenGui` en una esquina, no sobre la hoja de papel.

**Y eso contradice en apariencia la decisión del 2026-08-04** —*"los botones van SOBRE la hoja, no en una pantalla aparte"*—, así que vale explicar por qué no es una contradicción sino el mismo criterio dando otro resultado:

| | Botones de negociación | HUD |
|---|---|---|
| ¿Es juego o es cromo? | **Juego.** Es la mecánica | **Cromo.** Acompaña, no decide |
| ¿Existe fuera del duelo? | No | **Sí** — en el lobby no hay tablero donde dibujarlo |
| ¿Tapa al rival? | Una capa a pantalla completa, **sí** | Un papelito en una esquina, **no** |
| ¿Se toca? | Todo el tiempo | **Nunca** — así que el problema de precisión táctil que motivó la decisión original no aplica |

**El criterio de §11 no era "todo va en el mundo".** Era *"ver al rival es mecánico, así que nada puede taparlo"*. Un papelito arriba a la izquierda no tapa a nadie, y ponerlo sobre el tablero lo haría ilegible desde la cámara sobre el hombro.

**Lo que sí se respeta sin excepción es §28:** una sola birome. Cada línea del HUD pasa por `stroke`, el papel es `Theme.palette.paper`, y **no hay un solo relleno de color** — los tres botones de negociación son los únicos del juego, y un HUD que compitiera con ellos por la atención se estaría quedando con la excepción ajena.

**Alternativa descartada:** dibujar los Clips sobre la propia hoja del duelo. Se descartó porque desaparecería en el lobby y en el kiosco, que es donde más falta hace saber cuánto tenés.

**Lo que el arnés NO puede verificar:** nada de esto. El auto-juego no tiene clientes, así que el HUD entero —que se vea, que sea legible en un teléfono chico, que el número no tape nada— es de los ojos de Renata. Va al paquete visual del checkpoint 2.

---

## 2026-08-05 · 🔒 CANON — el test de ubicación: cuatro preguntas para todo elemento de UI

**Una regla que siempre da la misma respuesta es un hábito. Un criterio que produce `ScreenGui` para el HUD y mundo-3D para los botones, desde las mismas cuatro preguntas, es un principio funcionando.**

Todo elemento de interfaz nuevo se ubica contestando esto, **no por analogía con lo último que se construyó**:

| # | Pregunta | Por qué decide |
|---|---|---|
| 1 | ¿Es **juego** o es **cromo**? | El juego vive donde se juega; el cromo acompaña |
| 2 | ¿Existe **fuera del duelo**? | Si vive en el lobby, no puede depender de que haya un tablero |
| 3 | ¿**Tapa al rival**? | §11: verlo es mecánico. Nada puede taparlo |
| 4 | ¿**Se toca**? | Solo lo que se toca hereda el problema de precisión táctil en móvil |

**Resultados registrados hasta ahora:**

| Elemento | 1 | 2 | 3 | 4 | Dónde vive |
|---|---|---|---|---|---|
| Botones de negociación | juego | no | sí | sí | **Sobre la hoja**, en el mundo |
| HUD (Clips, colección) | cromo | sí | no | no | **`ScreenGui`**, una esquina |

### Corolario 1 — el monopolio visual de los tres botones

> **Un HUD que compitiera con ellos se estaría quedando con la excepción ajena.**

Los tres rellenos de color son **capital de diseño**: le dicen al jugador dónde se toca sin decírselo. **Toda pantalla nueva hereda la prohibición** — papel y birome, y si algo necesita destacarse se resuelve con **jerarquía visual** (tamaño, peso, aire), no robándose la excepción.

### Corolario 2 — la vida de un objeto sigue a su DUEÑO

El HUD **no** está en el trove del duelo, y la razón exacta importa: el cromo pertenece a la **sesión**, no a la partida. Meterlo ahí te borraba los Clips al terminar cada mano.

**Pregunta de cierre para todo montaje futuro: ¿quién es el dueño de la vida de esto?** No "¿dónde es cómodo registrarlo?".

---

## 2026-08-05 · El kiosco, contestando la tabla de las cuatro preguntas

**Se le pasó el test de ubicación antes de escribir una línea, que es para lo que existe la tabla.**

| # | Pregunta | Respuesta |
|---|---|---|
| 1 | ¿Juego o cromo? | **Cromo.** Comprar no es el juego; el duelo lo es |
| 2 | ¿Existe fuera del duelo? | **Sí, y solo ahí.** Vive en el lobby, donde no hay tablero |
| 3 | ¿Tapa al rival? | **No.** Mientras comprás no hay rival |
| 4 | ¿Se toca? | **Sí** — y esta es la que lo volvió una decisión en vez de una consulta |

**Resultado: `ScreenGui`, como el HUD. Pero a diferencia del HUD, se toca**, así que hereda el problema de precisión táctil que mandó los botones de negociación al espacio-mundo. **No los sigue hasta allá** —el lobby no tiene tablero— así que paga la deuda de otra forma: objetivos grandes con piso en píxeles.

### El monopolio de color, respetado con jerarquía

**COMPRAR no es verde.** Se gana su lugar con **jerarquía** —lo más grande de su papelito, tipografía de marcador, línea de birome más gruesa— y el kiosco entero queda en papel y tinta. Los tres rellenos siguen siendo capital exclusivo de los botones de negociación.

### El anti-tragamonedas, por fin visible

B4 hizo que la rotación se sembrara del reloj, así que **todos los jugadores de todos los servidores ven los mismos cuatro objetos**. Eso era cierto e **invisible**.

Ahora tiene cara: el encabezado lo dice —*"Lo mismo para todos, en todos los servidores"*— y un contador muestra cuándo cambia. **Una propiedad de justicia que nadie puede percibir no hace el trabajo para el que se construyó.**

### Dos hallazgos al construirlo

**1. El stock se derivaba dos veces.** El servidor lo calculaba en `ShopService`; el cliente iba a necesitar el mismo resultado para dibujar. Dos implementaciones de *"qué está a la venta"* es cómo un botón gris termina con un motivo que nadie puede explicar. Se movió a `Shared/Util/Kiosk.luau`: **una función, los dos lados la llaman**, y el servidor la vuelve a llamar antes de cobrar. Que coincidan no es el chequeo — es el punto de compartirla.

**2. El reloj era el de la máquina.** `os.time()` es lo que el dispositivo cree; `workspace:GetServerTimeNow()` está sincronizado. Un jugador con el reloj corrido una hora habría visto **un kiosco distinto del que el servidor le iba a vender**: objetos en gris sin motivo visible, y un rechazo como primera explicación.

**Y un valor de Config que estuve a punto de sobrecargar:** usé `Theme.touchPadding` para dar aire al botón, pero ese número es un **multiplicador** para objetivos en el mundo, donde el dibujo y el área tocable son objetos distintos. En UI plana son el mismo objeto. Se agregó `Theme.minTouchPixels = 44` —un **piso**, no un multiplicador— en vez de darle a un valor existente un segundo significado.

---

## 2026-08-05 · 🔒 CANON — el reloj del cliente es una segunda fuente de verdad

**Los dos hallazgos del kiosco eran la misma enfermedad con disfraces distintos.**

| Disfraz | Qué era |
|---|---|
| El stock derivado dos veces | Dos implementaciones de *"qué está a la venta"*, que divergen tarde o temprano |
| `os.time()` | **El tiempo mismo** como segunda fuente de verdad: `os.time()` es lo que **el dispositivo cree** |

**La cura, la misma en los dos casos: UNA.** Una función compartida que ambos lados llaman, con el servidor re-llamándola antes de cobrar —la derivación del cliente es **vista previa**, la del servidor **decide**— y **un** reloj, `workspace:GetServerTimeNow()`.

> **Todo lo que dependa de tiempo compartido usa el reloj del servidor.** Un jugador con el reloj corrido una hora habría visto un kiosco distinto del que el servidor le iba a vender, con el rechazo como primera explicación.

---

## 2026-08-05 · 🔒 CANON — un valor significa una sola cosa

> **Darle dos significados a un valor es cómo el primero deja de ser cierto.**

`Theme.touchPadding` es un **multiplicador** para objetivos en el mundo, donde el dibujo y el área tocable son objetos distintos. Usarlo como píxeles de UI plana —donde son el mismo objeto— le habría inventado un segundo significado, y el día que alguien ajustara el multiplicador habría movido el padding de una pantalla que no tiene nada que ver.

Nació `Theme.minTouchPixels = 44`: un **piso**, no un multiplicador, **con consumidor desde el primer commit** (regla 6 cumplida de nacimiento).

---

## 2026-08-05 · Requisito de frontera para todo lo que viva en `Shared`

**Antes de vivir en `Shared`, una pieza contesta de qué lado de la frontera carga información.**

`Shared/Util/Kiosk.luau` pasa: deriva stock **público** desde reloj + catálogo, sin nada de verdad adentro. Y lo dice **en su encabezado**, para que el próximo que le quiera agregar un parámetro herede la pregunta: *¿la entrada nueva carga algo que un lado sabe y el otro no debería?* Si sí, no va en ese archivo.

Es la misma vigilancia que la lista blanca de las vistas, un nivel más arriba: allá se pregunta qué campo sale; acá, qué módulo puede siquiera ser leído por el cliente.

---

## 2026-08-05 · 🔒 CANON — economía de confirmación, y la corrección que la precisa

**Renata corrigió el mapa, y la corrección es la parte que vale.**

Al verificar `FilterStringAsync` saqué un tercer argumento, `Enum.TextFilterContext.PublicChat`, y lo reporté como si hubiera sido una conjetura fallida. **No lo era: ese enum existe.** La verificación anterior no lo **desmentía** — simplemente no lo **cubría**.

**La quita sigue siendo correcta, pero por otra razón:**

| Lo que dije | Lo que era |
|---|---|
| "el argumento era inventado" | **"el argumento estaba inconfirmado, y el default daba lo necesario"** |

> **La regla es de economía de confirmación, no de verdad o mentira: pasar un argumento que no compra comportamiento cuesta superficie de verificación gratis.**

*Una conjetura que no cambia nada es solo una conjetura.*

**Y por qué la distinción importa lo suficiente como para corregir el registro:** es la misma familia que *"probado"* vs *"correcto y sin evidencia"*. Un mapa que funde **"quitado por innecesario"** con **"quitado por falso"** le miente al próximo que quiera volver a usar ese enum — que es una cosa perfectamente razonable de querer hacer el día que la vitrina necesite un contexto distinto de `PublicChat`.

**El estado real:** el enum existe, no está en el código porque no hace falta, y si alguna vez hace falta hay que verificar la firma de tres parámetros antes de usarlo.

---

## 2026-08-05 · Los avatares de los bots: la regla la cambió ella, y yo me había pasado

**Primero la corrección que me toca.** Al construirle cuerpo al bot dije que cargar el avatar de un usuario real *"sería llevar puesta la cara de alguien"*, y lo presenté como si fuera un impedimento.

**No lo es.** `Players:CreateHumanoidModelFromUserId` es una API oficial, los avatares de Roblox son públicos, y usarla es perfectamente legal — hay juegos que lo hacen todo el tiempo. Lo mío era **un juicio de diseño**, y presentarlo como una restricción es la misma falta que confundir *"quitado por innecesario"* con *"quitado por falso"*: le pone al otro un muro donde había una opción.

**El juicio, dicho como lo que es:** ponerle a un bot **que miente y falsifica** la cara de una persona que no se enteró puede caer mal. No es ilegal ni te bajan el juego.

**Decisión de Renata:** personalizar sí, y el bot va **emo**.

**Cómo quedó, y qué falta:** el look se arma con **colores solamente** —piel pálida, todo lo demás negro— sobre el `HumanoidDescription` que ya existía. Pelo, flequillo y ropa son **ids de catálogo**, y los ids escritos de memoria son exactamente el error que costó cuatro nombres de fuente inventados esta semana. La silueta se lee; el flequillo necesita que alguien busque los ids.

**Queda abierto:** si aparecen los ids —de una cuenta hecha para los bots, o del catálogo— se los agrego y el look mejora sin tocar código, solo Config.

---

## 2026-08-05 · 🔒 §28 REEMPLAZADA — la hoja blanca y varios marcadores

**Regla cerrada cambiada por decisión de Renata, con la foto del original sobre la mesa como referencia.**

| | Antes (§28) | Ahora |
|---|---|---|
| Papel | Kraft cálido | **Blanco**, esquinas muy redondeadas |
| Trazo | **Una sola birome azul** | **Varios marcadores**: rojo, azul, verde, rosa, ámbar |
| Mesa | — | **Madera oscura**, material con veta |

**Lo que NO cambió, y es lo que la regla realmente protegía:** que todo se vea **dibujado a mano**, con la misma herramienta física, sobre papel de verdad. La regla decía "una sola lapicera" pero lo que quería decir era "esto lo dibujó una persona". La foto del original —una hoja en un escritorio de oficina con fidget toys alrededor— cumple eso con cinco marcadores.

### El error que se repitió cinco veces, y lo que lo destrabó

Cada versión del tablero **encajonaba cada símbolo en su propio rectángulo relleno**. Se subieron los colores tres veces, se saturaron los rellenos, se cambió el símbolo a blanco — y seguía viéndose mal.

**Era un problema de forma, no de color.** Renata lo dijo exacto: *"el símbolo es del color y lo que los separa son las divisiones"*. En la referencia no hay cajas: hay **una raya por fila y dos verticales**, y las marcas dibujadas en los huecos.

> **Un bloque de color pelea contra el papel. Una marca de color se apoya encima.**

Ningún ajuste de color iba a arreglar eso, y se gastaron varias rondas intentándolo.

### Dos lapiceras, y para qué sirven

Las líneas del lado cercano son **azules** y las del lejano **rosas**. Sale de la referencia y hace un trabajo que no esperaba: **qué mitad de la hoja es tuya se contesta por el color de la línea, antes de leer un solo símbolo.**

### El techo de texto de Roblox

Cuatro rondas de agrandar celdas, filas y cajas no movieron nada porque **Roblox no dibuja texto de fuente legada por encima de tamaño 100**. Las marcas ya estaban en su máximo.

**El número que sí las mueve es `pixelsPerStud`**, la resolución de la superficie: menos píxeles por studs y esos 100 son una porción más grande de la hoja. Queda anotado ahí mismo, porque no es lo que nadie buscaría.

### Fuera de la hoja, por ahora

`showEmotes` y `showToken` en `false`: la tira de emotes y la ficha **existen y funcionan**, pero no se dibujan hasta que se decida dónde. Elegir un lugar apurado en un tablero que recién encontró su forma es cómo un dibujo limpio se vuelve a ensuciar.

### Lo que la foto original dejó pendiente

En la referencia **los objetos están sobre la mesa, alrededor del papel** — la hoja es solo para negociar, y por eso el centro está vacío. Hoy siguen dibujados en filas sobre el tablero, que es lo único que permite elegir qué ofertar.

**Sacarlos es el próximo cambio grande y todavía no está decidido cómo se elige un objeto** si ya no está en la hoja.

## 2026-08-07 — Un `pcall` que devuelve `true` no prueba que la escritura ocurrió

Las canastas no aparecían **y el Output no decía nada**. Ese silencio era el dato.

`MeshPart.MeshId` no es asignable desde un script en ejecución. La primera versión la asignaba dentro de un `pcall`, y la escritura **ni se aplicó ni tiró error**: el `pcall` informó éxito, el aviso nunca se disparó, y quedaron dos MeshParts sin malla colgadas de la mesa — invisibles, y calladas sobre serlo.

> **Un `pcall` que devuelve `true` solo prueba que nada tiró. Cuando lo que se quiere saber es "¿esto tuvo efecto?", hay que mirar el efecto, no la ausencia de excepción.**

Es la misma familia que "un verde que nunca vio rojo no es evidencia", pero peor: acá el verde lo produjo mi propia defensa. El diagnóstico defensivo dio un falso OK.

**Lo que se hizo:** `AssetService:CreateMeshPartAsync(Content.fromAssetId(id))`, verificado contra la doc oficial antes de escribirlo — firma, tipo del parámetro y que **cede**. Por eso corre fuera del camino de arranque del duelo (`task.spawn`) y **revuelve a comprobar que la mesa siga viva antes de colgarle nada**: un duelo que termina mientras la malla viaja dejaría una pieza que el Trove ya terminó de limpiar.

**Alternativa descartada:** guardar la canasta como `.rbxm` en el repo y clonarla. Funciona y no tiene riesgo de API, pero obligaba a reimportar el modelo que ella ya había borrado, y `CreateMeshPartAsync` es la herramienta que existe justamente para esto.

**Config cambió con el arreglo:** `meshId = "rbxassetid://…"` pasó a `assetId = 74562733627832`. `Content.fromAssetId` toma el número; guardar la cadena era guardar un formato que ya nadie usa.

### Y el `LIMPIAROFERTAR` en medio de la hoja

Cuando el inventario salió del tablero, el panel del borrador dejó de dibujarse **pero sus botones no**: iban en una fila que no lleva ningún objeto, así que aterrizaron pegados en el medio del papel.

Ahora **las filas sin objeto no se dibujan**. La regla quedó explícita en el código: el medio de la hoja tiene objetos y nada más; una fila que no es una cosa es interfaz, y la interfaz ya se fue. No se perdió nada — una oferta entera está a una tecla (Q / E) y las celdas regladas se dibujan por su propio camino.
