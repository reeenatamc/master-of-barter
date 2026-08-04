# Sesión de prueba — punto de control Etapa 1 (tras A4)

Una sola sesión que ejercita todo lo acumulado sin probar: **A2.1, A2.2, A3, A4** y el camino de desconexión del commit `72114f7`. Está ordenada para que no tengas que reiniciar entre bloques más de lo necesario.

Duración estimada: 20–30 min.

---

## Antes de empezar

1. `rojo serve` corriendo y el plugin conectado.
2. En `src/shared/Config/DuelRules.luau`, poné **`debugLogs = true`** (línea 46). Rojo lo sincroniza solo.
3. Pestaña **Test** → *Clients and Servers* → **2** jugadores → **Start**. Se abren tres ventanas: un servidor y dos clientes.
4. En la Command Bar de **cada cliente** (contexto Client):

```lua
local dc = require(game.Players.LocalPlayer.PlayerScripts.Controllers.DuelController)
```

Guardá esa línea a mano: hay que repetirla cada vez que reinicies la sesión de Play.

**Cómo saber quién es quién:** al entrar, cada cliente imprime `you=slot1` o `you=slot2`. El slot 1 es el que abre la negociación.

---

## Bloque A — el bucle completo, versión "el tramposo gana"

Esto es lo que responde la pregunta de la Etapa 1. Todo lo demás es plomería.

| # | Dónde | Comando | Qué tiene que pasar |
|---|---|---|---|
| A1 | slot 1 | `dc.offerDemo()` | Ofrece 1 genuino + 1 falsificación del Unicornio Arcoíris |
| A2 | slot 2 | `local s = dc.getState() dc.offer({{copyId=s.yourHand[1].copyId,isFake=false,claim=s.yourHand[1].itemId},{copyId=s.yourHand[5].copyId,isFake=false,claim=s.yourHand[5].itemId}})` | Oferta 100% honesta: Pulpito Azul + Zorro Galaxia |
| A3 | ambos | — | Los dos ven `phase=Negotiating`, `turn=slot1` |
| A4 | slot 1 | `dc.accept()` | La revelación |

**Lo que tiene que salir en la revelación**, idéntico en las dos ventanas:

```
── THE REVEAL ──
slot1 offered:
  "Pulpito Azul" was real
  "Unicornio Arcoíris" was FAKE
  walks away with 210 in value, slipped 1 fake(s)
slot2 offered:
  "Pulpito Azul" was real
  "Zorro Galaxia" was real
  walks away with 10 in value, slipped 0 fake(s)
```

Slot 1 gana **210 a 10 mintiendo**. Eso no es un bug: es exactamente el marcador crudo que dejamos a propósito, sin costo en Clips. Anotá si se siente injusto o si se siente rico — es dato de diseño.

**Mirá también:** antes de A4, ningún cliente vio nunca la palabra `FAKE`. La regla de oro se levanta en ese instante y no antes.

---

## Bloque B — el mismo bucle, pero con la ficha

Reiniciá Play (Stop → Start) y volvé a pegar la línea del `dc`.

| # | Dónde | Comando | Qué tiene que pasar |
|---|---|---|---|
| B1 | slot 1 | `dc.offerDemo()` | Igual que antes: uno genuino, uno falso |
| B2 | slot 2 | el comando largo de A2 | Oferta honesta |
| B3 | slot 1 | `dc.accept()` — **NO**, esperá | Es turno de slot 1; para que acuse slot 2 hace falta pasarle el turno |
| B3 | slot 1 | `dc.raise()` | Slot 1 pide más → turno pasa a slot 2, que ahora "OWES A BIGGER OFFER" |
| B4 | slot 2 | `dc.amendDemo()` | Slot 2 agrega un envoltorio → turno vuelve a slot 1 |
| B5 | slot 1 | `dc.raise()` | Segundo pedido → turno a slot 2 otra vez |
| B6 | slot 2 | `dc.fakeCall()` | **Acusa.** Slot 1 sí tiene una falsificación → acierta |

**Lo que tiene que salir:**

```
── THE REVEAL ──
slot2 shouted ES FAKE and was RIGHT
slot1 ... walks away with 0 in value, slipped 0 fake(s)
slot2 ... walks away with <su valor + el genuino de slot1>
```

Fijate en `slipped 0 fake(s)` de slot 1: la falsificación cambió de manos, pero lo cazaron. Eso es el arreglo de `5f65de0`.

**Y acá está la pregunta que importa:** ¿acusar se sintió como una apuesta, o como dinero gratis? Está anotado en el backlog como hipótesis: con las falsificaciones gratis, sospecho que "acusá siempre" domina. Si te pasa eso, **no es un fallo de A4** — es la falta del costo en Clips (B2). Necesito tu impresión, no tu diagnóstico.

---

## Bloque C — validación (lo que tiene que ser rechazado)

Reiniciá. Llegá a `Negotiating` con `dc.offerDemo()` en los dos.

Todo esto va en **una línea** desde el cliente **slot 2**:

```lua
dc.accept() dc.negotiate("Nope") dc.negotiate(42) dc.fakeCall()
```

En el Output del **servidor**, cuatro `rejected:` seguidos:

- `not your turn (slot 1 is up)` ×2 (el accept y el fakeCall)
- `action "Nope" is not available yet`
- `action is not a string`

Después, desde **slot 1**, en una línea:

```lua
local s = dc.getState() local c = s.yourHand[1].copyId dc.offer({{isFake=true,claim="no_existe"}}) dc.offer({{copyId=c,isFake=false,claim="rainbow_unicorn"}}) dc.offer({{copyId=c,isFake=true,claim="blue_octopus"}}) dc.offer({{isFake=true,claim="blue_octopus"},{isFake=true,claim="mint_turtle"},{isFake=true,claim="galaxy_fox"}}) dc.offer({})
```

Cinco rechazos más: claim inexistente · genuino mintiendo sobre su identidad · `isFake` en desacuerdo con `copyId` · 3 fakes · 0 envoltorios. Todos deberían decir `no raise is pending on you`, porque estamos en `Negotiating` — eso también es correcto: la primera capa que falla es la que corta.

Y las fichas: `dc.fakeCall()` dos veces desde slot 1 → la segunda da `your FakeCall token is already spent`.

---

## Bloque D — límites y timeouts

| # | Qué | Qué mirar |
|---|---|---|
| D1 | Reiniciá, llegá a `Negotiating`, hacé `dc.raise()` 4 veces desde slot 1 (con `dc.amendDemo()` en slot 2 entre medio) | La cuarta da `no raises left (limit is 3 per side)` |
| D2 | Enmendar sin agregar nada: en slot 2 con un raise pendiente, repetí su oferta original | `amendment has N wrappers, needs N+1-4` |
| D3 | **Watchdog por generación.** Hacé un `dc.raise()` + `dc.amendDemo()` y después **no toques nada 30s** | El duelo **no** se cancela antes de tiempo. Si muere apenas pasan 30s desde que empezó `Negotiating` en vez de 30s desde la enmienda, el timer viejo no se está descartando |
| D4 | Reiniciá, llegá a `Negotiating`, no toques nada 30s | `Cancelled` + `expected 0 live objects, got 0` |
| D5 | Reiniciá, no ofertes nada, esperá 45s | `BuildingOffers timed out` + `got 0` |

---

## Bloque E — desconexión 🔴

**Este es el importante.** Es el único que cubre un cambio ya commiteado y sin probar (`72114f7`), y un camino de desconexión roto no da error: corrompe después.

1. Reiniciá. Llegá a `Negotiating` con `dc.offerDemo()` en los dos.
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
