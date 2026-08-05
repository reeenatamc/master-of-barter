---
sidebar_label: Prueba · Etapa 1
---

# Sesión de prueba — punto de control Etapa 1 (tras A4)

Una sola sesión que ejercita todo lo acumulado sin probar: **A2.1, A2.2, A3, A4** y el camino de desconexión del commit `72114f7`. Está ordenada para que no tengas que reiniciar entre bloques más de lo necesario.

Duración estimada: 20–30 min.

---

## Antes de empezar

1. `rojo serve` corriendo y el plugin conectado.
2. En `src/shared/Config/DuelRules.luau`, poné **`debugLogs = true`**. Rojo lo sincroniza solo.
3. Pestaña **Test** → *Clients and Servers* → **2** jugadores → **Start**. Se abren tres ventanas: un servidor y dos clientes.

**No hace falta preparar nada en la Command Bar.** Todo se maneja con teclas, y esa es una corrección importante de este documento:

> La versión anterior pedía `_G.dc = require(...)` en la Command Bar de cada cliente. **Eso no funciona.** La Command Bar de Studio tiene su propio caché de módulos *y* sus propios globales: `require` ahí devuelve una **segunda copia vacía** del controlador, y el `_G` que ves no es el `_G` del cliente. No hay forma de alcanzar el controlador vivo desde esa consola. Por eso todo pasó a teclas, que corren dentro del cliente.

**Las teclas** (letras y no dígitos: 1-9 son la mochila de Roblox y WASD es movimiento):

| Tecla | Qué hace |
|---|---|
| **Q** | Ofertar 1 genuino + 1 falsificación |
| **E** | Ofertar 2 genuinos (oferta honesta) |
| **R** | Aceptar |
| **T** | Rechazar |
| **Z** | Pedir más |
| **X** | Enmendar (reenvía tu oferta + 1 falsificación) |
| **C** | ¡ES FAKE! |
| **B** | Batería de ofertas malformadas — todas deben rechazarse |
| **V** | Ataque de duplicación — debe rechazarse |

**Cómo saber quién es quién:** al entrar, cada cliente imprime `you=slot1` o `you=slot2`. El slot 1 es el que abre la negociación.

**Sobre los nombres de objetos:** el catálogo tiene 12 objetos y las manos se reparten de la colección de cada quien, así que los nombres concretos varían. Abajo se describe la **forma** de la salida, no los nombres — si un día cambia el catálogo, la prueba sigue valiendo.

---

## Bloque A — el bucle completo, versión "el tramposo gana"

Esto es lo que responde la pregunta de la Etapa 1. Todo lo demás es plomería.

| # | Dónde | Tecla | Qué tiene que pasar |
|---|---|---|---|
| A1 | slot 1 | **Q** | Ofrece 1 genuino + 1 falsificación |
| A2 | slot 2 | **E** | Oferta 100% honesta: dos genuinos |
| A3 | ambos | — | Los dos ven `phase=Negotiating`, `turn=slot1` |
| A4 | slot 1 | **R** | La revelación |

**La forma que tiene que tener la revelación**, idéntica en las dos ventanas:

```
── THE REVEAL ──
slot1 offered:
  "<algo>" was real
  "<algo>" was FAKE
  walks away with <N> in value, slipped 1 fake(s)
slot2 offered:
  "<algo>" was real
  "<algo>" was real
  walks away with <M> in value, slipped 0 fake(s)
```

Slot 1 se lleva más **mintiendo**, y paga Clips por la falsificación (eso es B2, que no existía cuando se escribió este documento). Anotá si se siente injusto o si se siente rico — es dato de diseño.

**Mirá también:** antes de A4, ningún cliente vio nunca la palabra `FAKE`. La regla de oro se levanta en ese instante y no antes. Y en cada envoltorio del rival, la línea `server sent fields: appearance, claim, wrappedId` — tres campos, y ninguno es `isFake`.

---

## Bloque B — el mismo bucle, pero con la ficha

Reiniciá Play (Stop → Start).

| # | Dónde | Tecla | Qué tiene que pasar |
|---|---|---|---|
| B1 | slot 1 | **Q** | Uno genuino, uno falso |
| B2 | slot 2 | **E** | Oferta honesta |
| B3 | slot 1 | **Z** | Slot 1 pide más → el turno pasa a slot 2, que ahora dice `OWES A BIGGER OFFER` |
| B4 | slot 2 | **X** | Slot 2 agrega un envoltorio → el turno vuelve a slot 1 |
| B5 | slot 1 | **Z** | Segundo pedido → turno a slot 2 otra vez |
| B6 | slot 2 | **C** | **Acusa.** Slot 1 sí tiene una falsificación → acierta |

> Slot 2 no puede acusar sin que le pasen el turno, y por eso B3 existe: hoy `beginNegotiating` le da el turno **siempre al slot 1**. Alternar turnos es A2 y espera al veredicto de la ficha (ver backlog).

**Lo que tiene que salir:**

```
── THE REVEAL ──
slot2 shouted ES FAKE and was RIGHT
slot1 ... walks away with 0 in value, slipped 0 fake(s)
slot2 ... walks away with <lo suyo + el genuino de slot1>
```

Fijate en `slipped 0 fake(s)` de slot 1: la falsificación cambió de manos, pero lo cazaron.

**Y acá está la pregunta que importa:** ¿acusar se sintió como una apuesta, o como dinero gratis? Necesito tu impresión, no tu diagnóstico.

---

## Bloque C — validación (lo que tiene que ser rechazado)

### C-1 — acciones inválidas

Llegá a `Negotiating` con **Q** en los dos. Desde el cliente **slot 2** (que no tiene el turno) apretá **R** (aceptar) y después **C** (¡ES FAKE!).

En el Output del **servidor**, dos rechazos:

```
[DuelService] request from Player2 rejected: not your turn (slot 1 is up)
```

### C-2 — la batería de ofertas malformadas: tecla **B**

**Corré esto ANTES de ofertar, apenas empieza el duelo.** Es lo que cambió respecto de la versión vieja de este documento y es el punto entero:

> Desde `Negotiating`, **todos** estos payloads chocan primero contra el chequeo de fase y devuelven `no raise is pending on you`. La versión anterior de esta prueba los mandaba desde ahí y contaba eso como aprobado — pero un rechazo por fase **no prueba nada** sobre la capa que cada caso fue escrito para ejercitar.

1. Duelo nuevo. **No ofertes.**
2. Apretá **B**.

Seis payloads salen seguidos, cada uno anunciado por el cliente, y **los seis tienen que ser rechazados** con un motivo distinto:

| # | Payload | Rechazo esperado | Qué capa prueba |
|---|---|---|---|
| 1 | claim que no existe en el catálogo | `unknown claim "no_existe"` | Existencia contra Config |
| 2 | envoltorio genuino que declara otra cosa | `genuine wrapper claims ... but holds ...` | Coherencia del modelo A |
| 3 | `isFake=true` con un `copyId` | `isFake disagrees with copyId` | Coherencia del modelo A |
| 4 | tres falsificaciones | `more than 2 fakes` | Límite de Config |
| 5 | oferta vacía | `offer has 0 wrappers, needs 1-4` | Rango |
| 6 | la misma copia envuelta dos veces | `same copy wrapped twice` | Unicidad **dentro** del payload |

3. **Después de la batería, mirá tu mano.** Tiene que estar intacta: seis ofertas rechazadas no sacan ni una copia del perfil. Si falta alguna, un rechazo dejó estado a medias — que es peor que aceptar la oferta.

> El caso 6 merece una nota: es de la misma familia que C-DUPE. Los dos son "el cliente arma la lista y el servidor no puede suponer nada sobre su forma" — uno dentro de un payload, el otro entre dos payloads sucesivos.

Y las fichas: llegá a `Negotiating` y apretá **C** dos veces desde slot 1 → la segunda da `no FakeCall tokens left`.

### C-DUPE 🔴 — el ataque de duplicación, caso de regresión permanente

**Este no se saltea nunca.** Es el agujero más serio que tuvo el proyecto: el escrow confiaba en el **orden** de una lista que arma el **cliente**. Está arreglado en dos lugares independientes, y esta prueba verifica que los dos siguen ahí.

**Pasos:**

1. Dos jugadores. Los dos ofertan (**Q**).
2. Desde **slot 1**, pedí más (**Z**).
3. Desde **slot 2** —que ahora debe una enmienda— apretá **V**.

**El payload que manda V** es el ataque exacto: el envoltorio **nuevo primero**, la oferta anterior después.

```
oferta original:  [ real A ]
enmienda enviada: [ real B , real A ]     ← B adelante: eso es todo el ataque
```

**Qué tiene que salir en el Output del servidor:**

```
[Duel] sending the dupe payload: new wrapper first, previous offer after   (cliente)
[DuelService] request from Player2 rejected: amendment changed wrapper 1; it may only append
```

**Y lo que tiene que seguir siendo cierto después:** el perfil del slot 2 no cambió. Ni ganó una copia ni perdió una:

```lua
print(require(game.ServerScriptService.Services.DataService).get(game.Players:GetPlayers()[2]).duelCopies)
```

**Las dos defensas, y por qué son dos:**

| Defensa | Dónde | Qué aporta |
|---|---|---|
| Una enmienda debe **empezar** con la oferta que enmienda | `DuelOffers` | El rechazo claro, y que la cuenta del costo siga siendo exacta |
| `takeCopy` **rechaza un `copyId` que ya está en escrow** | `InventoryService` | Que ninguna ruta futura pueda reabrir el agujero suponiendo un orden otra vez |

La primera dice *"este camino no dupea"*. La segunda dice *"no existe camino que dupee"*. Si algún día alguien borra la primera, el ataque tiene que seguir fallando — con un mensaje más feo (`cannot stake copy ... `) pero fallando igual. **Esa es la prueba de que el arreglo es estructural y no una convención.**

---

## Bloque D — límites y timeouts

> **Antes de este bloque:** si tenés `phaseSeconds` subido para tener tiempo de tipear (300s), bajá `BuildingOffers` y `Negotiating` a **15** en `DuelRules.luau`. Con 300 te quedás cinco minutos mirando la pantalla en cada fila. Los tiempos de abajo asumen 15.

| # | Qué | Qué mirar |
|---|---|---|
| D1 | Reiniciá, llegá a `Negotiating`, apretá **Z** 4 veces desde slot 1 (con **X** en slot 2 entre medio, porque cada pedido hay que satisfacerlo) | La cuarta da `no raises left (limit is 3 per side)` |
| D2 | Enmendar sin agregar nada: en slot 2, con un pedido pendiente, apretá **V** (que reenvía la oferta reordenada, no ampliada) | Rechazo. Ver C-DUPE: hoy corta antes, en la regla de que una enmienda solo puede **agregar** |
| D3 | **Watchdog por generación.** **Z** en slot 1 + **X** en slot 2, y después **no toques nada** | El duelo **no** se cancela antes de tiempo. Si muere contando desde que empezó `Negotiating` en vez de desde la enmienda, el timer viejo no se está descartando |
| D4 | Reiniciá, llegá a `Negotiating`, no toques nada | `Cancelled` + `expected 0 live objects, got 0` |
| D5 | Reiniciá, no ofertes nada, esperá | `BuildingOffers timed out` + `got 0` |

---

## Bloque E — desconexión 🔴

**Este es el importante.** Es el único que cubre un cambio ya commiteado y sin probar (`72114f7`), y un camino de desconexión roto no da error: corrompe después.

1. Reiniciá. Llegá a `Negotiating` con **Q** en los dos.
2. **Cerrá la ventana de slot 2** (la X de la ventana, no Stop).

En el cliente que **queda vivo** (slot 1):

```
[Duel] ... phase=Cancelled
```

En el **servidor**:

```
[DuelService] duel ... ended (PlayerN disconnected): expected 0 live objects, got 0
```

**Si el cliente que se queda NO recibe el `Cancelled`, el cambio no funcionó**, aunque el servidor diga `got 0`. Ese es exactamente el fallo silencioso que este bloque busca.

Repetilo una vez más cerrando durante `BuildingOffers` en vez de `Negotiating`.

---

## Bloque F — la carrera de `finish()`

Necesita la Command Bar de la **ventana del servidor** (contexto Server), con un duelo vivo en `Negotiating`:

```lua
require(game.ServerScriptService.Services.DuelService).runFinishRaceCheck()
```

Seis líneas con lo esperado al lado y `RESULT: PASS`.

**Lo que este PASS NO significa:** el segundo camino queda frenado por el registro (`duels[id]` ya en nil), no por el claim de `resolving`. El claim protege contra un yield antes del broadcast, y hoy no existe ninguno. Está anotado en la tarjeta A3 del backlog: esa deuda se salda cuando B1/B3 metan un guardado real ahí.

---

## Al terminar

1. **Volvé `debugLogs` a `false`** en `DuelRules.luau:46`.
2. Si bajaste algún tiempo de `phaseSeconds` para no esperar, devolvelo.

## Qué anotar

Lo técnico se ve solo: pasa o no pasa. Lo que no puedo ver yo:

- ¿Hubo un momento de tensión antes de aceptar?
- ¿La revelación se sintió como algo, o fue solo texto?
- ¿Acusar se sintió como apostar o como cobrar?
- ¿Cuánto duró un duelo de punta a punta? (el objetivo del GDD §7 son 2–3 min)
- ¿Alguien pidió "otra"? — ese es el criterio de aceptación real de la Etapa 1.
