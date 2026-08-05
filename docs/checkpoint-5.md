---
sidebar_label: Checkpoint 5 · bots y partición
---

# Checkpoint 5 — bots, matchmaking y la partición de DuelService

**Tiempo: 15 minutos.** Cuatro pruebas, y **dos importan**: la 1 (que D1 funcione) y la 4 (200 duelos automáticos, que es la que más evidencia da por minuto tuyo). Las otras dos confirman cosas ya verificadas por tipos y por lectura.

**Este checkpoint no cambia tu orden de cola.** Sigue mandando el checkpoint 3 (persistencia) primero y solo, después la sesión de diversión 2. Este entra donde te quede cómodo — pero **leé la sección "Lo que necesita tu sí o tu no"**, porque ahí hay una corrección de seguridad esperándote.

---

## Antes de empezar

`rojo serve` corriendo, plugin conectado. Nada más.

---

## Prueba 1 — el arranque en frío murió

**Esto es todo lo que D1 tenía que lograr.**

1. **Play** con **un** jugador.
2. **Esperá 15 segundos sin tocar nada.** No hay que apretar nada para entrar a la cola: el cliente entra solo al arrancar.

**Qué tiene que pasar en el Output:**

```
[Matchmaking] Player1 joined the queue (1 waiting)
[Matchmaking] Player1 waited 15s; filled with a bot
[Duel] <id>
  phase=BuildingOffers ... you=slot1
  slot1: Player1 (you) -- 4 copies, 3 raises left
  slot2: mica.exe -- 4 copies, 3 raises left
```

El nombre del slot 2 sale de una lista y cambia cada vez. **Fijate que no diga nada tipo "Bot" ni "CPU"** — si dijera, esa es exactamente la señal que §34 prohíbe.

3. Apretá **Q** (ofertar 1 real + 1 FAKE). **Esperá unos segundos.**

Entre 1,2 y 4,5 segundos después el bot oferta solo, y el duelo pasa a `Negotiating`. El retardo es al azar dentro de ese rango a propósito: un rival que contesta siempre en el mismo tiempo es una máquina en el segundo duelo.

4. Apretá **Z** (pedir más). El bot te contesta con una oferta **más grande** — un envoltorio más que antes, y los anteriores intactos.
5. Apretá **R** (aceptar). Revelación normal, con la verdad de los dos lados.

**Recordatorio de teclas** (las de siempre, no cambiaron): **Q** ofertar 1 real + 1 fake · **E** ofertar 2 reales · **R** aceptar · **T** rechazar · **Z** pedir más · **X** enmendar · **C** ¡ES FAKE!

**Si el bot nunca oferta:** eso es el fallo que importa. Mandame el Output.

---

## Prueba 2 — una persona le gana la carrera al bot (opcional)

1. Test → **2** jugadores → **Start**. (Los dos entran a la cola solos.)
2. **No toques nada durante 20 segundos.**

**Qué tiene que pasar:** se emparejan entre ellos al instante, y **ningún bot aparece** — ni siquiera pasados los 15 segundos. Con alguien esperando, el emparejamiento resuelve antes de que se arme ningún temporizador.

```
[Matchmaking] Player1 joined the queue (1 waiting)
[Matchmaking] Player2 joined the queue (2 waiting)
[Matchmaking] duel started: Player1 vs Player2
```

**Lo que estaría mal:** que a los 15 segundos apareciera un bot para uno de los dos. Significaría que un bot le robó el lugar a una persona.

---

## Prueba 3 — nada se rompió con la partición (opcional)

`DuelService` pasó de 1095 líneas a cinco módulos. **El comportamiento no cambió**, y esta prueba lo confirma con números.

1. `DuelRules.debugLogs = true` en `src/shared/Config/DuelRules.luau`.
2. Test → **2** jugadores. Duelo hasta llegar a `Negotiating`.
3. Command Bar, contexto **Server**:

```lua
require(game.ServerScriptService.Services.DuelService).runFinishRaceCheck()
```

Tiene que imprimir **RESULT: PASS** con los seis números en lo esperado. Es la misma prueba de antes de partir.

4. Volvé `debugLogs` a `false`.

---

## Prueba 4 — 200 duelos en un minuto (opcional, pero es la que más paga)

**Bot contra bot, sin nadie mirando.** Ejercita la partición entera, la validación de ofertas, el escrow y la revelación en cientos de secuencias que ningún humano tipearía, y busca las dos cosas que un fallo silencioso deja: **fugas** y **fases colgadas**.

1. `DuelRules.debugLogs = true`.
2. **Play** con un jugador. Command Bar, contexto **Server**:

```lua
require(game.ServerScriptService.Services.BotService).selfPlay(200)
```

3. Esperá — tarda alrededor de un minuto (los bots piensan a 0,03s en este modo).

**Qué tiene que salir:**

```
[BotService] self-play: 200/200 duels in 58.3s
  accepted: 171
  fake called: 21
  declined: 8
  duels that leaked a live object: 0   (expected 0)
  RESULT: PASS
```

Los repartos varían; lo que **no** puede variar son tres cosas:

| Línea | Qué significa si sale mal |
|---|---|
| `200/200` | Si es menos, un duelo **nunca terminó**: una fase colgada. Es el peor fallo de esta lista |
| `TIMED OUT: n` | Un watchdog tuvo que rescatar un duelo. Los bots actúan en 0,03s: no debería hacer falta nunca |
| `leaked: 0` | Cualquier otro número es una conexión o un temporizador que sobrevivió a su duelo |

4. Volvé `debugLogs` a `false`.

**No toca ningún perfil:** los dos lados son bots, así que todas las escrituras son no-ops. Podés correrlo mil veces sin ensuciar datos.

**Lo que esta prueba no puede contestar:** si algo de esto es divertido. Para eso siguen haciendo falta dos personas en una habitación.

---

## Lo que necesita tu sí o tu no

### 1. 🔴 Caso (a) — arreglé un agujero de duplicación en el escrow

**Es el punto importante de este checkpoint.** Lo encontré escribiendo la lógica de enmienda del bot.

**El agujero:** cuando enmendás una oferta, el servidor solo cobra y solo pone en escrow **lo nuevo** — se saltea las primeras N entradas asumiendo que son la oferta anterior. Pero nada verificaba que lo fueran, y el cliente elige qué manda.

**El exploit, concreto:** ofertás [real A]. Enmendás con [real B, real A]. El escrow se saltea la posición 1 y toma A **por segunda vez**, mientras **B queda en la mesa sin haber salido nunca de tu perfil**. Ganes o pierdas, el rival recibe B y vos seguís teniéndolo. **Eso es duplicación**, que por tu regla 5 es el fallo que se propaga.

**La otra mitad:** una enmienda que **omite** una copia apostada cumple igual con el conteo, y esa copia queda abandonada en el escrow, donde nada la devuelve. Pérdida silenciosa, misma causa, signo contrario.

**El arreglo, en dos mitades — y tenías razón en pedir la segunda:**

| | Dónde | Qué garantiza |
|---|---|---|
| Una enmienda debe **empezar con la oferta que enmienda**, sin cambios | `DuelOffers` | El rechazo claro, y que la cuenta del costo siga exacta |
| **`takeCopy` rechaza un `copyId` que ya está en escrow** | `InventoryService` | Que **ninguna ruta futura** pueda reabrirlo suponiendo un orden otra vez |

La primera sola era **la versión débil**: cerraba el camino actual, no la clase. La segunda es la fuerte, y para tenerla el ledger de escrow ahora guarda **identidad** (`copyId`), no solo tipo — **la identidad no se puede reordenar**.

Mismo movimiento que `WrappedItemView` sin campo donde poner `isFake` y que `InventoryService` sin función que reste de la colección: convertir la convención en imposibilidad.

**El ataque quedó como caso de regresión permanente:** tecla **V** manda el payload exacto ([nuevo, anterior]), y `prueba-etapa1.md` bloque **C-DUPE** dice qué rechazo esperar y cómo confirmar que el perfil no se movió. Si algún día alguien borra la primera defensa, el ataque tiene que seguir fallando con un mensaje más feo — esa es la prueba de que es estructural.

**Ya ratificaste el protocolo** (arreglar y reportar, en ese orden, ante un agujero activo), así que acá no queda nada esperando tu sí. Queda para que sepas qué cambió de forma.

### 2. `Economy.botEarningsCapPerDay = 900` `[propuesta]`

Unos cuatro duelos generosos. Suficiente para que una sesión normal en servidor vacío nunca lo toque, poco para que farmear bots no sea un sueldo. Se calibra en alfa como todo lo demás.

### 3. Los números de `Bots.luau` `[propuesta]`

`fakeChance = 0.35`, `raiseChance = 0.3`, `fakeCallChance = 0.12`, `declineChance = 0.08`, y pensar entre 1,2 y 4,5 segundos.

El único con criterio fuerte detrás es `fakeCallChance`: bajo a propósito, porque un bot que acusa seguido le enseña al jugador que acusar es barato — justo el hábito que la sesión de diversión 2 tiene que medir **en humanos**, sin contaminar.

---

## Lo que tenés que saber, aunque no requiera decisión

### ⚠️ El bot casi nunca decide, y no es culpa del bot

`beginNegotiating` le da el turno **siempre al slot 1**, y en un duelo contra bot vos sos el slot 1. El slot 2 solo recibe el turno cuando le debe una enmienda.

| El bot hace | El bot no hace |
|---|---|
| Armar su oferta | Aceptar |
| Enmendar cuando le pedís más | Rechazar · Pedir más · Acusar |

**`raiseChance`, `fakeCallChance` y `declineChance` hoy solo corren en duelos bot-contra-bot.**

**Esto no lo trajo D1.** Es el modelo de turnos actual, que `arquitectura.md` §5 ya marca como provisional (*"el slot 1 abre por ahora; alternar turnos es A2"*). En humano-contra-humano pasa igual: el slot 2 nunca abre.

**No lo toqué** porque alternar turnos es una decisión de diseño de negociación —quién puede presionar a quién y cuándo— y pertenece a A2, no a una tarjeta de bots. Pero lo decís vos: **un rival que nunca te presiona es la mitad del juego**, y si querés que D1 sirva para probar el juego sola, esto es lo primero que te va a faltar.

### La silla vacía

En un duelo contra bot te sentás solo a la mesa: un bot no tiene personaje. §11 dice que ver al rival es mecánico, así que **una silla vacía es exactamente la señal obvia que §34 prohíbe**. Es trabajo de escena (E1/E2), no un bloqueo de D1, y queda escrito para que no se descubra después.

### El remoto `DuelReveal` ya no existe

Aprobaste borrarlo. Hecho, con §6 corregido a los tres remotos que el código realmente tiene, y con un comentario en `Net.luau` que explica por qué el hueco está ahí — un borrado sin motivo se deshace.

Y quedó nombrada en `decisiones.md` la pieza que sostiene la regla: la compuerta `if duel.phase == "Reveal"` **dentro de `stateFor`** es el único punto del código donde la regla de oro se levanta, y se levanta **por fase, no por camino**. Cualquier refactor futuro hereda la obligación de conservarla.

### La partición cerrada

1095 líneas → cinco módulos, el mayor de 712.

| Módulo | Contesta |
|---|---|
| `DuelTypes` | las formas |
| `DuelView` | la única forma en que un estado llega a un cliente |
| `DuelReveal` | la verdad completa, como valor |
| `DuelOffers` | si una oferta es legal |
| `DuelStakes` | qué escribe un duelo en un perfil (y que un bot no tiene) |
| `DuelService` | la vida del duelo |

**Auditoría de salidas, otra vez, con todo esto encima:** siete envíos al cliente — **seis triviales** (avisos y emotes) y **UNO** que es el embudo. `stateFor` y `viewOf` siguen siendo locales de `DuelView`: ningún otro módulo puede construir un `DuelState`. Cero remotos sin consumidor.
