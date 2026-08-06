---
sidebar_label: Backlog técnico
---

# Backlog Técnico — Master of Barter
**Versión 0.1 — Fase 8 · agosto 2026**

Formato: cada historia es una tarjeta. Copia el bloque completo a Trello/GitHub Projects/Notion (título = línea de la historia; el resto va en la descripción de la tarjeta). Prioridad: P0 = imprescindible MVP · P1 = importante · P2 = opcional · P3 = post-MVP. Complejidad en camisetas: S (una sesión), M (varias sesiones), L (1–2 semanas de ratos).

Orden de trabajo recomendado: sigue las etapas de la Fase 7; dentro de cada etapa, primero las P0 en el orden listado (respetan dependencias).

---

## ÉPICA A — Núcleo del duelo

### A1 · Como jugador quiero armar una oferta de objetos envueltos para iniciar una negociación

**Prioridad:** P0 · M

Objetivo: base de toda la mecánica. Criterios: selecciono 1–4 objetos de mi inventario de duelo, marco cuáles ofertar como fake (respetando máx. 2 y costo en Clips), declaro contenido; el servidor rechaza ofertas con objetos que no poseo. Dependencias: C1, D1. Riesgos: replicar por error el flag esFake (revisar §4 de arquitectura). Pruebas: ofertar objetos ajenos/inexistentes desde consola cliente → rechazado y logueado.
> **Nota (Etapa 1):** cobro en Clips diferido a Etapa 2, depende de B2. En el prototipo se aplica el techo de 2 fakes (que es lo que protege el balance) pero no se cobra nada.
> **Nota (Etapa 1):** la dependencia con D1 sobra para el prototipo — A1 y A2 se prueban con dos clientes de Studio. El orden real es el de CLAUDE.md: A1 → A2 → A4 → D1.
>
> **Sub-tareas:** A1.1 duelo mínimo (dos jugadores, copias de duelo, `DuelState` por destinatario) ✅ · A1.2 watchdog de fase + Trove · A1.3 ofertas y validación.
>
> **✅ SALDADA (2026-08-04). No queda residuo pendiente.** El cliente rival imprimió `server sent fields: appearance, claim, wrappedId` para los dos envoltorios —el genuino y el falso— con exactamente los mismos tres campos. Ni `isFake` ni `copyId` cruzan, y la forma del payload tampoco los distingue.
>
> Lo que se había anotado como no cubrible por lectura era el runtime: que la serialización del RemoteEvent no agregue nada y que ese camino sea el que de verdad se ejecuta. **Ambas cosas quedaron cubiertas**, porque la comprobación corrió sobre el payload recibido en un duelo real jugado de punta a punta, no sobre el código. La lista sale de recorrer las claves reales de la tabla que llegó.
>
> No se difiere nada a Etapa 2. Texto original abajo, solo como registro de por qué se había diferido en su momento.
>
> ~~**Verificación diferida de A1.3 → Etapa 2:**~~ la comprobación *visual* de que el payload del rival trae solo `appearance`, `claim` y `wrappedId` no se completó, porque hacerla hoy exige pelear con el multijugador de Studio y tipear comandos en consola. No se saltó: se verificó por lectura (el tipo `WrappedItemView` no tiene dónde poner `isFake`, `viewOf()` copia campo por campo y nunca clona la tabla, y la lista impresa sale de recorrer las claves reales del payload recibido, no de una lista escrita a mano). Lo que la lectura no puede cubrir es el runtime: que la serialización del RemoteEvent no agregue nada y que ese camino sea el que realmente se ejecuta. Se retoma en Etapa 2, cuando exista la UI de duelo (E2) y mirar los envoltorios en la mesa sea natural.
>
> **Deuda del doble `finish()`: movida de A1.3 → A2.** No se olvidó, se movió con razón. Los tres caminos que hacen que la carrera importe son accept / decline / watchdog, y accept/decline son acciones de negociación: no existen hasta A2. En A1.3 los únicos caminos reales eran dos watchdogs y una desconexión, prácticamente la misma carrera que ya se había descartado probar en A1.2. Escribirlo antes de A2 era escribirlo dos veces. Ver la condición de cierre en la tarjeta A2.
>
> **A1.2 — condición de cierre, no negociable:** el Trove nace en **la misma tarjeta** que el watchdog, no después. En el momento en que exista el primer `task.delay`/timer de deadline, ya tiene que estar registrado en el Trove del duelo. No puede haber ni una fase intermedia con un timer sin su limpieza.
> Test obligatorio de A1.2: un cliente cierra su ventana a mitad de `BuildingOffers` → el duelo no queda colgado y no sobrevive ningún timer. Es el primer test de desconexión real del proyecto; conviene descubrir ahí que el embudo y la limpieza aguantan, con un duelo vacío, y no en Etapa 2 con datos de por medio.

### A2 · Como jugador quiero negociar con Aceptar / Rechazar / Pedir más

**Prioridad:** P0 · M

Objetivo: el loop del meme. Criterios: turnos alternos validados en servidor; Pedir más obliga al rival a añadir/mejorar y tiene límite 3 por lado; Rechazar termina sin transferencias; timeouts por fase con resultado definido. Dependencias: A1. Pruebas: pulsar fuera de turno, spamear botones, dejar expirar cada timeout.

> **🔒 Los turnos alternos se abren DESPUÉS de la sesión de diversión 2, no antes.** Hoy `beginNegotiating` le da el turno siempre al slot 1, así que el slot 2 —sea persona o bot— solo puede responder a un "Pedir más": nunca acepta, rechaza, pide más ni acusa por iniciativa propia. Eso deja `Bots.raiseChance`, `fakeCallChance` y `declineChance` sin efecto fuera de duelos bot-contra-bot (ver D1).
> **Por qué esperar:** el veredicto de la ficha ¡ES FAKE! cambia *qué tiene que poder hacer un rival*. Si la ficha sobrevive, alternar turnos tiene que dejar espacio para acusar en el momento correcto; si se cae, la negociación es otro juego y los turnos se diseñan para ese. Rediseñar la alternancia antes de saberlo es diseñar para una mecánica que puede no existir.
> **Costo de esperar, a la vista:** hasta entonces un rival nunca te presiona, que es la mitad del juego, y D1 no sirve para probar el bluff en soledad.
> **Condición de cierre — test determinista de doble `finish()` (movida desde A1.3).** Con A2 existen por primera vez los tres caminos que compiten de verdad: aceptar, rechazar y el watchdog de fase, los tres disparables desde el servidor. El test dispara dos de ellos sobre el mismo duelo y verifica que la segunda entrada no hace nada: no limpia el Trove dos veces, no emite el fin dos veces, y el contador de vivos sigue cerrando en 0.
> Se movió desde A1.3 a propósito, no se olvidó: en A1.2 y A1.3 los únicos caminos existentes eran los watchdogs y la desconexión, y una desconexión cancela el watchdog antes de que dispare, así que la carrera casi no ocurría. Escribir el test antes de A2 era escribirlo contra caminos que no son los que importan, y reescribirlo después.
> Por qué importa más de lo que parece: en cuanto aceptar una oferta cuelgue el guardado del perfil del fin del duelo (Etapa 2), la guarda de idempotencia deja de ser defensiva y pasa a ser **lo único que impide un doble guardado**. No es una optimización, es la red.

### A3 · Como jugador quiero una revelación dramática al aceptarse un trade

**Prioridad:** P0 · M (v1 simple) / L (versión final Etapa 4)

Objetivo: el momento estrella y clipeable. Criterios: al aceptar, se desenvuelve todo con animación+sonido; transferencias y Clips aplicados atómicamente en servidor; ambos ven el mismo resultado. Dependencias: A2, C2. Pruebas: desconexión exactamente durante la revelación → estado consistente al reconectar.
> **Re-verificación heredada de A2.1 — no dar por probado lo que no se probó.** El `runFinishRaceCheck` de A2.1 pasa, pero cubre menos de lo que parece: hoy el segundo camino terminal queda frenado por el **registro** (`duels[id]` ya está en nil cuando llega), no por el claim de `resolving`. Son dos garantías distintas y hoy solo se ejercita una. Un PASS significa "los dos caminos no se pisaron en la resolución", **no** "el claim está probado".
> El claim existe para proteger el broadcast si alguna vez aparece un yield entre entrar en la fase y emitirla. Hoy no hay ninguno, así que nunca llega a actuar. **En cuanto A3 introduzca un yield en el camino de Reveal** — transferencias, DataStore, cualquier espera entre `phase = "Reveal"` y el broadcast — el claim pasa de decorativo a load-bearing, y `runFinishRaceCheck` tiene que volver a correrse **con el yield presente**, que es el único momento en que esa ventana se prueba de verdad.
> Sin esta nota, en A3 nadie se acuerda de que el test de A2.1 no cubría ese caso y se da por probado algo que no lo está.
>
> **Verificado tras B2 (2026-08-04): el pago del duelo NO introdujo yield.** Se revisaron los tres archivos del camino: `EconomyService` no tiene ninguno, el pago es mutación en memoria de `Profile.Data` y ProfileStore persiste después por auto-save; lo único asíncrono de `DataService` es `StartSessionAsync`, que está en el camino de carga; y `Signal.fire` no cede, además de que `balanceChanged` todavía no tiene suscriptores. La deuda sigue viva sin cambios.
>
> **Y la ventana es más chica de lo que parecía.** El claim protege el tramo entre reclamar el duelo y emitir el broadcast. El pago ocurre **después** del broadcast, dentro de `finish()`, y además después de que `duels[duelId]` ya se puso en nil — así que un yield ahí no reabriría la ventana del claim: solo demoraría la limpieza del Trove, y de eso ya se encarga la guarda de generación de los timers.
> Lo que **sí** reabriría la ventana es un yield dentro de `resolve()` mismo, entre marcar `resolving` y llamar a `broadcast`. Ese es el tramo a vigilar, y hoy no tiene ninguno. Si B3 hace que la revelación espere algo antes de emitir, ahí se activa la condición.
>
> **A3 no salda esta deuda.** Tal como quedó escrita, la revelación **no introduce ningún yield** en el camino de `Reveal`: el `RevealResult` se construye de forma síncrona y viaja dentro del `DuelState` final, y la pausa dramática la maneja el cliente, no el servidor. O sea que el claim de `resolving` sigue sin ejercitarse. La nota queda **viva**: se salda cuando B1/B3 metan un `await` real ahí (guardado de perfil, transferencias persistentes).
>
> **Marcador crudo de A3, con su límite conocido.** Genuino = `baseValue`, falsificación = 0, gana quien recibió más. Con solo esto la estrategia dominante es "falsificá todo siempre", y los testers lo aprenden en tres partidas. Lo frenan dos cosas que todavía no existen: el costo en Clips (B2) y sobre todo la ficha ¡ES FAKE! (A4). **No se metió ninguna penalización inventada en A3** para tapar eso: sería adelantar la mecánica de A4 y después habría que quitarla. Consecuencia: A3 cierra "la revelación emociona y hay gané/perdí", pero **el dilema del bluff no se puede juzgar hasta A4**, y por eso el punto de control de diversión está después de A4.

### A4 · Como jugador quiero una ficha ¡ES FAKE! única por duelo

**Prioridad:** P0 · S

Criterios: usable una vez, solo en fase de negociación; acierto → me llevo la oferta rival; fallo → pierdo mi apuesta; queda registrada en analítica. Dependencias: A2. Riesgo: es la mecánica 🧪 más incierta — instrumentarla bien para decidir su futuro con datos.
> **Hipótesis a falsear en el punto de control, no un bug.** A4 frena "falsificá todo siempre" —si el rival acusa, acierta y te deja sin nada—, pero en el prototipo abre la simétrica: **"acusá siempre"**. La ficha no cuesta nada, acertar solo requiere que el rival tenga *al menos una* falsificación, y falsificar todavía es gratis (el costo en Clips es B2). Con esos tres hechos juntos, acusar es casi dinero seguro.
> Lo que la frena en el diseño completo y hoy no existe: el costo en Clips hace que se falsifique menos, así que acusar deja de acertar siempre. **No se agregó ninguna penalización inventada** para compensarlo, por la misma razón que en A3.
> Qué mirar en la sesión de prueba: si en todas las partidas la jugada obvia es acusar, el equilibrio del prototipo está roto **por falta de B2**, no por A4. Es dato para decidir el futuro de la ficha (§8 la marca 🧪), no un fallo que arreglar acá.
> `AnalyticsService` no existe (F3), así que las llamadas todavía no se registran. Marcado con TODO en el código.

### A5 · Como jugador quiero que las desconexiones no me perjudiquen injustamente

**Prioridad:** P0 · M

Criterios: quien se desconecta pierde el duelo y su apuesta pasa al rival; el que queda vuelve al lobby limpio; el Trove del duelo libera todo (verificar sin fugas tras 100 duelos bot-vs-bot). Dependencias: A2, E2.

### A6 · Como jugador quiero inspeccionar objetos envueltos y notar imperfecciones

**Prioridad:** P0 · M

Criterios: zoom táctil/click; 3 tipos de imperfección (tono, costura, errata) precalculados por servidor; nunca detectables solo por color. Dependencias: A1, D2. Pruebas: verificación con simulación de daltonismo.
> **Dato de calibración de la primera partida real (2026-08-04):** con las bandas iniciales (genuino `0.00–0.18`, falso `0.12–0.55`), la falsificación sacó `tone 0.47` mientras que todo lo genuino de la partida quedó entre `0.06` y `0.18`. En esa muestra el falso se delataba **por una sola dimensión**, sin necesidad de mirar las otras dos. La mitad superior de la banda falsa es efectivamente un cartel luminoso. A6 tiene que decidir si la banda falsa se recorta hacia abajo (más solapamiento, más duda) o si el sorteo evita que las tres dimensiones se aparten a la vez.

### A7 · Como jugador quiero emotes para la guerra psicológica

**Prioridad:** ~~P1~~ → **P0** · S — subida el 2026-08-04

Criterios: 6 emotes prediseñados, visibles por el rival, con cooldown anti-spam.

> **Por qué subió.** En la primera sesión con personas, los dos testers pidieron poder hablarse durante el duelo, para venderse el objeto y hacerse los graciosos. Eso confirma lo que `gdd.md` §8 anotaba como hipótesis: la diversión vive en la **actuación de venta**, y el prototipo tenía el trueque pero no el escenario.
> Los emotes no son un adorno de esa actuación, son su forma práctica en móvil —la plataforma principal—: escribir a mitad de un duelo cronometrado es incómodo, y seis botones de reacción venden más rápido que un párrafo. Entra en la iteración corta posterior a la Etapa 1.

---

## ÉPICA B — Datos y economía

> **Orden de la épica: B1 antes que B2.** Corrige una decisión previa de arrancar por B2 (el costo en Clips de fabricar fakes), y se deja escrito el porqué:
> 1. **Dependencia técnica.** `EconomyService` necesita dónde persistir los Clips. Sin B1 no hay dónde guardarlos.
> 2. **Dependencia de producto.** Sin colección permanente no hay razón para volver mañana, y eso es lo primero que la retención necesita — antes que cualquier ajuste de balance.
> 3. **Por la regla de verificación** de `CLAUDE.md`: los datos persistentes no se agrupan ni se difieren. B1 se prueba en su momento, con su propio cuidado, porque un bug ahí no da error visible: corrompe en silencio.
>
> B2 va inmediatamente después, como el freno que hoy le falta al balance (hoy falsificar es gratis).

### B1 · Como jugadora quiero que mi progreso se guarde de forma segura

**Prioridad:** P0 · M

Objetivo: cimiento de confianza. Criterios: ProfileStore con plantilla completa (§7 arquitectura); cierre abrupto de Studio no pierde datos; perfil bloqueado por otra sesión → modo espectador con reintento, jamás datos por defecto. Dependencias: ninguna (primera historia técnica de Etapa 2). Pruebas: cerrar proceso a mitad de duelo; entrar con la misma cuenta desde dos clientes.

### B2 · Como jugador quiero ganar y gastar Clips

**Prioridad:** P0 · M

Criterios: toda mutación pasa por EconomyService; recompensas de duelo desde Config; imposible quedar en negativo; log de cada transacción. Dependencias: B1. Pruebas: compra con saldo insuficiente vía remoto manipulado → rechazada.

### B3 · Como jugador quiero una colección permanente intocable y copias de duelo apostables

**Prioridad:** P0 · M

Criterios: la colección nunca decrece por duelos; las copias se compran con Clips y son lo único transferible en la mesa. Dependencias: B1, B2. Riesgo: es la decisión 🧪 del GDD §21 — mantener la frontera clarísima en la UI.

### B4 · Como jugador quiero comprar objetos y copias en el kiosco

**Prioridad:** P0 · M

Criterios: catálogo desde Config; compra validada y reflejada al instante; precios nunca leídos del cliente. Dependencias: B2, B3.

### B5 · Como jugadora quiero vender game passes y productos sin riesgo de fraude

**Prioridad:** P1 · M

Criterios: ProcessReceipt idempotente (tabla Recibos); pass detectado al entrar; compra caída no cobra sin entregar. Dependencias: B1. Pruebas: simular recibo duplicado.

---

## ÉPICA C — Configuración y contenido

### C1 · Catálogo de objetos en Config con rarezas y valores

**Prioridad:** P0 · S (estructura) + M (15 ítems con arte)

Criterios: añadir un objeto = añadir una entrada, cero código nuevo. El panteón es propio y el tono es brainrot; nunca personajes brainrot existentes (ver `gdd.md` §22). Dependencias: ninguna.

### C2 · Sistema de temas (Theme.luau) con el tema Papelito v1

**Prioridad:** P0 · M

Objetivo: el seguro anti-caducidad del meme. Criterios: todo asset visual/sonoro del sabor papel se resuelve vía tema activo; probar creando un mini-tema alternativo de 3 assets y alternándolo. Dependencias: ninguna. Riesgo: disciplina — un solo asset hardcodeado rompe la promesa.

### C3 · Economía balanceable desde Config

**Prioridad:** P0 · S

Criterios: costos de fakes, recompensas, precios y límites en un módulo; cambiar un número no requiere tocar servicios.

---

### Deuda · `prueba-etapa1.md` usa `_G.dc`, que no llega al controlador

**Prioridad:** P1 · S

Los bloques C y D de `prueba-etapa1.md` mandan payloads con `_G.dc.offer({...})` desde la Command Bar. **Eso no funciona:** la Command Bar de Studio tiene su propio caché de módulos y sus propios globales, así que `require` ahí devuelve una segunda copia vacía del controlador y `_G` no es el mismo `_G`. Se descubrió al construir A2 y la solución fue atar acciones a teclas.

Quedan por pasar a teclas los payloads con forma arbitraria (claim inexistente, `isFake` en desacuerdo, 3 fakes, oferta vacía). El caso C-DUPE ya está hecho: tecla **V**.

**Por qué importa:** una batería de regresión que no se puede correr no es una batería de regresión. Hoy la mitad de la validación de A1.3 está escrita y no ejercitada.

---

## ÉPICA D — Bots y matchmaking

### D1 · Como jugador quiero encontrar rival rápido aunque el servidor esté vacío ✅

**Prioridad:** P0 · M — **entregada 2026-08-04**

Objetivo: matar el arranque en frío. Criterios: cola en servidor; si no hay rival en N segundos entra un bot con nombre/avatar plausible; el jugador no recibe señales obvias de que es bot. Dependencias: A2, E1.

**Entregado:** `MatchmakingService` (cola + temporizador por jugador, la persona siempre gana la carrera), `BotService` (juega solo por la superficie validada — `applyOffer`/`applyAction`, nunca tocando estado), `DuelStakes` (única capa que sabe que un bot no tiene perfil), tope diario de valor extraído de bots. Ver `checkpoint-5.md` y `decisiones.md`.

**Deuda que D1 deja a la vista, no descubierta después:**

| Qué | Dónde vive | Por qué no se arregló acá |
|---|---|---|
| El bot **nunca acepta, rechaza, pide más ni acusa** contra un humano: `beginNegotiating` da el turno siempre al slot 1. `Bots.raiseChance`/`fakeCallChance`/`declineChance` solo corren bot-vs-bot | **A2** (alternancia de turnos) | Alternar turnos es diseño de negociación —quién presiona a quién y cuándo—, no una tarjeta de bots |
| **Silla vacía**: te sentás solo a la mesa, porque un bot no tiene personaje. §11 hace mecánico ver al rival, así que es la señal obvia que §34 prohíbe | **E1/E2** (escena) | Es trabajo de escena, no de matchmaking |
| **Avatar**: `userId` salió del payload replicado porque un bot no tiene cuenta y cualquier valor ahí era el dato. Cuando E2 necesite miniaturas, vuelve **con una respuesta deliberada para bots** | **E2** | No había consumidor; un campo sin lector es una decisión tomada por accidente (regla 6) |

### D2 · Como jugadora quiero bots con personalidades que bluffean creíblemente

**Prioridad:** P0 · M (2 personalidades) + P1 · M (2 más + adaptativo)

Criterios: agresivo y tímido difieren medible en ratio de fakes, uso de Pedir más y tiempos de respuesta con jitter humano. Dependencias: D1. Pruebas: 200 duelos bot-vs-bot sin errores ni estados colgados (sirve también como test de estrés del núcleo).

**Partida en dos, y el arnés ya está hecho:**

| | Estado | Por qué |
|---|---|---|
| **Arnés de auto-juego** (`BotService.selfPlay`) | ✅ **2026-08-04** | No depende de nada y paga hoy: cada duelo que corre es una pasada completa por la partición, la validación, el escrow y la revelación. Reporta fugas y fases colgadas con números |
| **Las personalidades** | ⏸ **bloqueada por A2** | Hasta que los turnos alternen, el slot 2 solo puede responder a un "Pedir más". Un bot "agresivo" y uno "tímido" serían **indistinguibles contra un humano**, porque ninguno de los dos puede acusar ni presionar. Escribirlas ahora es escribir diferencias que nadie puede percibir |

Y A2 espera a la sesión de diversión 2, así que la cadena real es: **ficha → alternancia de turnos → personalidades.**

---

## ÉPICA E — Lobby, UI y sonido

> **Hueco detectado y cerrado el 2026-08-04.** `plan-etapas.md` Etapa 1 pedía una mesa de duelo fea que en el backlog no existía como tarjeta, porque la UI vivía sólo en E2 (Etapa 2). Sin ella, la pregunta de la Etapa 1 no se podía contestar: nadie juzga si algo divierte leyendo el Output. **E0 se construyó y la etapa cerró con ella.**

---

## ✅ Iteración corta post-prueba (Etapa 1) — CERRADA el 2026-08-04, dentro del timebox

Sale de la primera sesión con personas (`prueba-diversion.md`): el concepto engancha, pero **los dos testers pidieron poder hablarse** para venderse el objeto y hacerse los graciosos, y la pantalla parece una planilla.

**Objetivo:** llegar a la segunda sesión —la del experimento de la ficha— con un prototipo donde la actuación de venta sea posible. Nada más.

> **Resultado.** Las tres cerradas. El chat resultó existir desde siempre (`TextChatService` viene encendido) y sólo estaba tapado, así que E0.1 fue mover un frame y decir la tecla; los emotes se montaron sobre el contrato de botones que ya había, sin conceptos nuevos; y los objetos ganaron forma y color desde `Theme.luau`, que estrenó contenido — placeholder, C2 lo reemplaza.
>
> **Deuda menor abierta:** `DuelSkin.luau` quedó en 357 líneas, sobre el límite de 300 de CLAUDE.md. No se dividió porque es el archivo que E2 descarta entero, y dividirlo es trabajo que se tira con él. Queda anotado para no darlo por no visto.

**Regla de esta iteración:** cualquier otra cosa que salga de las pruebas va al backlog, **no acá**. El timebox es duro; se cierra por tiempo, no por completitud.

### ✅ E0.1 · Hacerle sitio al chat en la pantalla de duelo

**Prioridad:** P0 · S — **hecha**

Criterios: la conversación se ve **mientras** negociás, no en otra pantalla ni tapada por la UI del duelo. **Cero features de chat propias** — el filtro, la ventana y la moderación son de Roblox (`TextChatService`, ya habilitado por defecto en places nuevos). Esto es una tarjeta de *layout*, no de chat.

Diagnóstico previo obligatorio: comprobar en Play si el chat ya aparece. Lo más probable es que exista y que la pantalla de E0 —que ocupa el 94% del ancho con `IgnoreGuiInset`— simplemente lo tape. Si es eso, la tarjeta es encoger un frame.

### ✅ A7 · Emotes — **subió de P1 a P0** — hecha

Ver la tarjeta en la ÉPICA A. Sube por el dato de la primera sesión: en móvil, que es la plataforma principal, **seis botones de reacción venden más rápido que escribir**, y escribir a mitad de un duelo cronometrado es incómodo. Seis emotes prediseñados, visibles por el rival, con cooldown anti-spam.

### ✅ E0.2 · Objetos que parezcan objetos

**Prioridad:** P0 · S — **hecha**

Criterios: cada objeto se ve como una cosa y no como una fila de texto — **placeholder**: forma simple + color + nombre grande. Suficiente para que los testers juzguen el juego y no la planilla.

**Límite explícito: NO es arte.** El arte de verdad, con estética de papel, es E2. Si alguien se encuentra dibujando una Sopa Maruchan Dorada bonita, se pasó de la raya de esta iteración y hay que parar.

---

### E1 · Lobby "El Patio de Trades" con mesas, kiosco y flujo de cola

**Prioridad:** P0 · M

Criterios: caminar, unirse a cola desde una mesa, volver del duelo al mismo punto.

### E2 · UI de duelo estilo papel usable en móvil

**Prioridad:** P0 · L

Criterios: 3 botones grandes, oferta legible, inspección cómoda con dedo; aprobada en emulador (teléfono chico y tablet) antes de cerrarse. Dependencias: C2. Riesgo: es la superficie de mayor esfuerzo del MVP — dividir en sub-tarjetas por pantalla.
> **Criterio añadido — escena canónica (`gdd.md` §11).** El duelo se ve con los dos avatares **frente a frente** y la tabla de papel **en medio**, cámara lateral/cenital sobre la mesa. No es decoración: es el encuadre que hace reconocible una miniatura o un clip, y ver al rival (avatar + emotes) es parte de la información con la que se lo lee. Una UI que ocupe la pantalla entera y esconda al rival **no cumple E2**, por bonita que sea.
> E0 no se toca: sigue siendo la pantalla fea que ya está, y se descarta cuando esta entre.
>
> **Criterio añadido — "Pedir más" se deshabilita contra una oferta llena, con motivo visible.** El servidor rechaza el pedido cuando el rival ya puso el máximo de envoltorios (`maxItemsPerOffer`), porque no se le puede pedir más a quien no puede dar más. Eso dejó de ser una regla interna: es una regla que el jugador **siente**.
> Un botón que existe, se toca y **no hace nada** se lee como un bug del juego, no como una regla. Así que en la UI real el botón va gris **con el motivo a la vista** ("ya ofreció el máximo"), y lo mismo vale para las otras dos veces que un botón puede ser ilegal: sin pedidos restantes (`raisesLeft = 0`) y sin ficha (`fakeCallsLeft = 0`). Los tres estados ya viajan en el `DuelState`; falta que la piel los dibuje.

### E3 · HUD, kiosco y vitrina — **mitad servidor ✅ 2026-08-05**

**Prioridad:** P0 (HUD, kiosco) / P2 (vitrina) · M

Criterios: Clips y colección siempre coherentes con servidor; vitrina filtra textos con TextService.

**Entregado (servidor):** `PlayerDataService` empuja `PlayerDataView` —Clips, colección, copias— a **su propio dueño y a nadie más**, coalescido: los tres cambios que produce un pago de duelo salen en un solo envío.

**Por qué entró ahora y no con la UI:** `Net.names.PlayerData` estaba declarado y **nunca disparado**, y `EconomyService.balanceChanged` no tenía **un solo suscriptor**. Dos cosas sin consumidor, que por la regla 6 son dos decisiones que nadie tomó. A diferencia del remoto `DuelReveal`, acá la respuesta no era borrar —no son una segunda salida de nada, son una función faltante con el nombre ya reservado— sino darles su consumidor. Sin esto el HUD **no podía existir**: el cliente no tenía forma de saber sus Clips.

**Y `botEarnings` NO se replica**, por la misma razón que se borró `isBot`: un cliente que lee su total diario contra bots deduce que los bots existen y cuánto valen. §34 prohíbe las señales obvias, y un número que solo se mueve contra bots es tan obvio como una etiqueta. Verificado por mutación: clonando el perfil en vez de construir la vista campo por campo, cuatro aserciones se ponen en rojo.

**Falta (cliente):** el HUD que lo dibuje, la vitrina y el `TextService`.

### E4 · Sonido base del tema papel

**Prioridad:** P1 · S

Criterios: banco desde Theme; papel, cinta, revelación, victoria/derrota; volúmenes en Config.

---

## ÉPICA F — Onboarding, misiones y analítica

### F1 · Tutorial con Don Trueque

**Prioridad:** P0 · M

Criterios: duelo guiado, primer objeto regalado, un fake obvio didáctico; completable en <4 min; saltable para cuentas con progreso. Dependencias: núcleo A completo. Pruebas: persona real sin ayuda verbal.

### F2 · Misiones diarias

**Prioridad:** P1 · M

Criterios: 3 diarias desde Config, progreso persistente, reseteo diario correcto en zonas horarias distintas.

### F3 · Analítica de decisiones ✅ (parcial)

**Prioridad:** P0 · M — **el núcleo entregado 2026-08-05**

Objetivo: el balance del bluff se decide con datos. Criterios: funnel de onboarding paso a paso; evento por duelo con duración, resultado, nº Pedir más, fakes ofertados, acusaciones y acierto; evento por compra. Dependencias: A2–A4. Riesgo: instrumentar tarde = alfa a ciegas — va junto al núcleo, no después.

**Entregado:** `AnalyticsService` (una sola puerta, buffer en anillo, sinks que se desactivan solos ante error) + `Config/Analytics.luau` con los nombres de evento. Cinco eventos vivos: `duel_started`, `duel_finished`, `escrow_orphaned`, `request_rejected`, `bot_fallback`, `shop_purchase`. Cerró los cuatro `TODO(F3)` que el mes venía acumulando.

**⚠️ El dashboard de Roblox NO va a decidir la ficha, y conviene saberlo antes de la sesión.** Los eventos custom de Roblox son **agregaciones con breakdowns** por tres campos, no filas consultables. Con **dos personas**, el N es ridículo y ningún breakdown dice nada.

**El veredicto de la ficha sale de la observación de Renata + el log interno de eventos**, que ya existe, ya se imprime y ya se testea. El binding de Roblox es para **alfa en adelante**, cuando haya jugadores de verdad. No bloquea nada de la sesión de diversión 2.

**Lo que falta, y por qué no está:**

| Pendiente | Bloqueado por |
|---|---|
| ~~Verificar `LogCustomEvent`~~ ✅ **hecho 2026-08-05** | La firma estaba bien; lo que cambió el diseño fue otra cosa (ver abajo) |
| **Funnel de onboarding** paso a paso | **F1** (tutorial con Don Trueque). Un funnel sin los pasos que mide no es un funnel |
| **Compra Robux** | **B5**, que es caso (b) y espera |

---

## ÉPICA G — Lanzamiento y operaciones

### G1 · Página del juego: icono, miniatura, título, descripción (ES/EN)

**Prioridad:** P0 · M

Criterios: 2 versiones de icono y miniatura evaluadas con opiniones; descripción con términos de búsqueda del género.

### G2 · Checklist de release ejecutable

**Prioridad:** P0 · S

Criterios: documento con los pasos de §11–12 de la arquitectura (móvil, red lenta, consola limpia, guardado, compras) que se ejecuta completo antes de CADA publicación.

### G3 · Clips de la revelación para TikTok/Shorts

**Prioridad:** P1 · S

Criterios: 3–5 clips de <20 s capturados de partidas reales; publicados el día del lanzamiento.

### G4 · Pipeline de temporadas

**Prioridad:** P3 · M

Criterios: checklist para lanzar una temporada (tema + objetos + misiones) en <2 semanas de ratos; se construye tras el lanzamiento, cuando la retención lo justifique.

---

## Fuera del backlog (recordatorio de disciplina)
Trade-Up Run · mesas 4–6 · espectadores · torneos · trading libre entre jugadores · moneda dura · rankings globales. Viven en el GDD §40. Cada vez que tientes con una, pregunta: ¿qué P0 estoy retrasando a cambio?

---

## Verificación pendiente — punto de control tras A4

Lista consolidada de lo que está escrito y type-clean pero **no ejercitado en Studio**. El punto de control estaba fijado tras A3, y se corrió a **tras A4**: A3 da la revelación y un gané/perdí, pero con el marcador crudo la estrategia dominante es "falsificá todo siempre", y eso solo se frena con la ficha ¡ES FAKE!. Juzgar la diversión antes de A4 sería juzgar media mecánica. Al terminar A4 el bucle se juega entero —ofertar, negociar, aceptar, revelar, acusar— y una sola sesión cubre todo esto de una vez. Ninguna se da por buena hasta entonces.

| Qué | De dónde viene | Por qué importa |
|---|---|---|
| ~~**Camino de desconexión**~~ | commit `72114f7` | ✅ **2026-08-04.** Cerrando la ventana del rival a mitad de `Negotiating`, el cliente que quedó vivo recibió `phase=Cancelled`. Falta confirmar el `got 0` del contador de Trove en la ventana del servidor. |
| ~~Payload del rival: solo `appearance`, `claim`, `wrappedId`~~ | A1.3 | ✅ **Verificado en runtime el 2026-08-04.** Los dos envoltorios, real y falso, llegaron con los mismos tres campos. |
| ~~Bucle completo: ofertar → negociar → aceptar → revelar~~ | A2.1+A3 | ✅ **2026-08-04.** Mentir ganó 210 a 10. Ambos clientes vieron la misma revelación. |
| ~~Pedir más + ficha ¡ES FAKE! acertando~~ | A2.2+A4 | ✅ **2026-08-04.** `shouted ES FAKE and was RIGHT`; el tramposo quedó en 0 y `slipped 0` pese a que sus envoltorios cambiaron de manos. |
| ~~Aceptar / Rechazar fuera de turno, acciones inválidas~~ | A2.1 | ✅ **2026-08-05, automatizado.** `./selfplay.sh spec` |
| ~~Timeout de `Negotiating` → `Cancelled` con contador en 0~~ | A2.1 | ✅ **2026-08-05, automatizado.** Con reloj virtual, en milisegundos |
| `runFinishRaceCheck()` → PASS | A2.1 | Cubre menos de lo que parece: ver la nota en A3 sobre el claim de `resolving`. |
| ~~Pedir más: límite de 3 por lado, enmienda validada por cantidad~~ | A2.2 | ✅ **2026-08-05, automatizado.** |
| ~~Revelación: `isFake` solo al aceptar, nunca antes~~ | A3 | ✅ **2026-08-05, automatizado y con prueba de mutación.** El spec inspecciona **todos** los `DuelState` que el servidor mandó en 40 duelos y verifica que ningún envoltorio rival trae `isFake`. Rompiendo `viewOf` a propósito, caza 180 fugas. |
| ~~Marcador: genuino = `baseValue`, fake = 0, gana quien recibió más~~ | A3 | ✅ **2026-08-05, automatizado.** |
| ~~Ficha ¡ES FAKE!: acierto → te llevás la oferta del tramposo~~ | A4 | ✅ **2026-08-04.** Acierto verificado. Falta probar el fallo (acusar a quien no mintió) y que la segunda ficha del mismo lado se rechace. |
| ~~**E0 — mesa de duelo fea**~~ | E0 | ✅ **2026-08-04.** Duelo completo jugado con botones: elegir real/falso, ofertar, negociar, aceptar, revelar, acusar. Sin teclado, sin Output. Ese era el criterio de aceptación de la tarjeta. |
| **Equilibrio del bucle completo** | A2–A4 | No es una prueba de código, es la pregunta de la Etapa 1. Ver la hipótesis "acusá siempre" en la tarjeta A4. |
| ~~Watchdog por generación~~ | A2.2 | ✅ **2026-08-05, automatizado.** El reloj virtual pasa el deadline viejo y el nuevo en la misma corrida — imposible de hacer a mano sin esperar 30s reales. |

**No agrupable** (regla de CLAUDE.md): nada que toque ProfileStore, guardado o `ProcessReceipt` entra en esta lista. Eso se prueba cuando se escribe.
