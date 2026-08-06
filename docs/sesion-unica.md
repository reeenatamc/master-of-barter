---
sidebar_label: ⭐ Sesión única de pruebas
---

# Sesión única de pruebas

**Los cinco checkpoints en un solo documento, en el orden que menos te hace pelear con Studio.**

No están en orden numérico: están en orden de **fricción**. Lo que antes eran cinco archivos, cinco arranques de Play y cuatro cambios de configuración, acá son **cuatro bloques y un cambio de configuración**.

| Bloque | Qué prueba | Jugadores | Tiempo |
|---|---|---|---|
| **1** | Persistencia (checkpoint 3) 🔴 | 1–2 | 20 min |
| **2** | Visual + bucle + economía (checkpoints 2 y 4, prueba etapa 1) | 2 | 25 min |
| **3** | Desconexión 🔴 | 2 | 3 min |
| **4** | Bots y arranque en frío (checkpoint 5) | 1 | 5 min |

**Total: ~55 minutos.** Se puede cortar entre bloques sin perder nada.

**La sesión de la ficha ¡ES FAKE! no está acá** — es otra cosa (`prueba-diversion-2.md`): no verifica, decide, y necesita dos personas jugando en serio.

> **Los dos bloques con 🔴 son los que no se pueden saltear.** Un fallo de persistencia o de desconexión **no da error**: corrompe callado y se descubre la semana que viene. Todo lo demás, si falla, se ve.

---

## Antes de empezar (una vez, dos minutos)

1. **`rojo serve`** corriendo, plugin conectado en Studio.
2. En `src/shared/Config/DuelRules.luau`: **`debugLogs = true`**.
3. En `src/shared/Config/DataConfig.luau`: confirmá **`useMockInStudio = true`**.

Rojo sincroniza los dos solos. **No los vas a tocar de nuevo hasta el bloque 1, paso 4.**

### El teclado, completo

No hay UI de duelo con mouse todavía; todo va por teclas. **Esta es la única lista que necesitás:**

| Tecla | Qué hace |
|---|---|
| **Q** | Ofertar 1 real + 1 falso |
| **E** | Ofertar 2 reales (oferta honesta) |
| **R** | Aceptar |
| **T** | Rechazar |
| **Z** | Pedir más |
| **X** | Enmendar |
| **C** | ¡ES FAKE! |
| **K** | Abrir/cerrar el **kiosco** |
| **L** | Abrir/cerrar la **vitrina** |

*(Existen también **B** y **V** —batería de ofertas inválidas y ataque de duplicación—, pero **esta sesión no las usa**: eso ya lo corre `./selfplay.sh spec` en cada cambio. Quedan por si algún día querés verlas pasar por el camino real del remoto.)*


**Cómo saber quién sos:** cada cliente imprime `you=slot1` o `you=slot2`. El slot 1 abre la negociación.

**Dónde está el Output:** pestaña **View** → **Output**. En pruebas de dos jugadores hay una ventana por cliente más la del servidor; cuando abajo diga "en el servidor", es la que dice *Server*.

---

# BLOQUE 1 — Persistencia 🔴

**20 minutos.** El único bloque que no se puede agrupar con nada, porque cambia configuración a mitad.

**Por qué va primero:** todo lo demás escribe en el perfil. Si el guardado no está probado, el bloque 2 mide humo.

## 1.1 — El perfil carga

**Play**, un jugador. Command Bar, contexto **Server**:

```lua
print(require(game.ServerScriptService.Services.DataService).get(game.Players:GetPlayers()[1]))
```

✅ Imprime una tabla.
❌ Imprime `nil` → **parás acá**. El perfil no cargó y nada de lo que sigue significa algo. Mandame el Output.

## 1.2 — Cierre abrupto sin pérdida

1. Con el Play todavía corriendo, en la Command Bar (**Server**):

```lua
require(game.ServerScriptService.Services.DataService).get(game.Players:GetPlayers()[1]).clips = 9999
```

2. **Mirá el HUD**: arriba a la izquierda tiene que decir **9999**. *(Eso también prueba que el empuje de datos al cliente funciona — dos pruebas por el precio de una.)*
3. **Stop** con el cuadrado rojo. Sin avisar, sin esperar.
4. **Play** de nuevo. Mirá el HUD.

✅ Dice **9999**.
❌ Dice **250** → el guardado no ocurrió. **Parás.** Es exactamente el fallo silencioso que este bloque existe para atrapar.

## 1.3 — Dos sesiones peleando por un perfil

1. **Test** → **2** jugadores → **Start**.
2. En el Output del **servidor**, buscá `has no profile; spectator mode`.

✅ **No aparece** con dos jugadores distintos: son dos perfiles, no uno.
✅ Si cerrás una ventana y volvés a entrar rápido con el mismo jugador y **sí** aparece, **eso está bien** — es el lock haciendo su trabajo.
❌ Que alguien entre con un perfil **vacío** en vez de quedar como espectador.

## 1.4 — Contra el DataStore de verdad

Las tres anteriores usan el simulador. **Un simulador que se porta bien no prueba que un DataStore se porte bien.**

### Preparación (una sola vez en la vida del proyecto)

1. **File → Publish to Roblox** (o *Publish to Roblox As…* la primera vez).
2. **Home → Game Settings → Security →** prendé **Enable Studio Access to API Services** → **Save**.
3. `src/shared/Config/DataConfig.luau` → **`useMockInStudio = false`**.

### La prueba

Repetí **1.2** entera: escribís `clips = 9999`, Stop de golpe, Play, mirás el HUD.

✅ Sigue diciendo 9999 → **la persistencia está probada de verdad.**

### Si queda como espectador, mirá el motivo

El servidor te dice **por qué**, y hasta te dice qué significa, porque los dos fallos se ven igual:

```
[DataService] Player1 has no profile; spectator mode. DataStore access: NoAccess.
  (NoAccess = Studio API access is off, or the place is unpublished.
   Access = reachable, so the profile is genuinely locked elsewhere.)
```

| Dice | Significa | Qué hacer |
|---|---|---|
| `NoAccess` | API apagada, o el lugar sin publicar | Volvé a los pasos 1 y 2. **No es un bug** |
| `NotReady` | Todavía averiguando | Esperá unos segundos y reintentá |
| `NoInternet` | Sin conexión | Nada del código |
| `Access` | El DataStore responde bien | Entonces hay algo roto de verdad. **Mandámelo** |

### ⚠️ Al terminar el bloque

**Volvé `useMockInStudio` a `true`.** Si no, todas las pruebas de todos los días escriben en los datos reales del juego.

---

# BLOQUE 2 — Visual, bucle y economía

**25 minutos, un solo Play.** Acá se juntan tres checkpoints que antes eran tres arranques.

**Test** → **2** jugadores → **Start**. **No cierres esta sesión hasta terminar el bloque.**

## 2.1 — El paquete visual (checkpoint 2)

Antes de tocar nada, **mirá**. Diez minutos de mirar, y anotá lo que te chirríe.

### El tablero

| Mirá | Qué está en juego |
|---|---|
| ¿Se lee **desde la cámara** sin acercarte? | El tablero está acostado sobre la mesa. Si hay que forzar la vista, la cámara o el tamaño están mal |
| ¿Los tres botones son **lo más llamativo** de la pantalla? | Son el ícono visual del juego (§25). Si algo les gana la atención, ese algo se corrige |
| ¿Parece **dibujado con una sola birome**? | §28, no negociable |
| ¿La inclinación de los papeles se siente **hecha a mano** o **descuidada**? | Es a propósito. Si se lee como error, hay que bajarla |

### El HUD (arriba a la izquierda)

Dos papelitos: **Clips** y **colección** (`n / 12`).

- ¿Se lee **de un vistazo**?
- ¿**Tapa** algo? Sobre todo al rival
- Cuando cobres al final de un duelo, el número tiene que **saltar y asentarse**, no cambiar de golpe

### El kiosco — tecla **K**

Cuatro papelitos con nombre, precio y **COMPRAR**.

| Mirá | Qué está en juego |
|---|---|
| ¿**COMPRAR** compite con los tres botones de negociación? | **No es verde a propósito.** Se destaca por tamaño y trazo. Si igual te roba la atención, la jerarquía no alcanzó |
| Con pocos Clips, ¿el botón dice **cuánto te falta**? | Un botón gris sin motivo se lee como juego roto |
| ¿Se ve el contador de **"cambia en M:SS"** y el cartel de que el stock es igual para todos? | Es la decisión anti-tragamonedas hecha visible. Si no se nota, no sirve |

### La vitrina — tecla **L**

**Acá hay una prueba que no es estética. Es la única de moderación del proyecto.**

1. Escribí un nombre en la caja y apretá **PONER**.
2. **Mirá lo que queda en pantalla.**

✅ **No es exactamente lo que tipeaste** — pasó por el filtro de Roblox y se muestra el resultado.
🔴 **Si ves tu texto tal cual: avisame.** Sería el único fallo grave del paquete.

*(En Studio el filtro a veces no responde. Si sale "No pudimos revisar ese nombre ahora mismo", **eso también está bien**: significa que falló cerrado — no guardó nada en vez de guardar sin filtrar.)*

## 2.2 — El bucle completo, versión "el tramposo gana"

**Esto es lo que responde la pregunta de la Etapa 1. Todo lo demás es plomería.**

| Dónde | Tecla | Qué pasa |
|---|---|---|
| slot 1 | **Q** | Ofrece 1 genuino + 1 falsificación |
| slot 2 | **E** | Oferta 100% honesta |
| — | — | Los dos ven `phase=Negotiating`, `turn=slot1` |
| slot 1 | **R** | La revelación |

**Antes de apretar R:** ningún cliente vio nunca la palabra `FAKE`. Y en cada envoltorio del rival, el Output dice `server sent fields: appearance, claim, wrappedId` — **tres campos, ninguno es `isFake`**.

**La pregunta que importa:** ¿se sintió injusto o se sintió rico? *Necesito tu impresión, no tu diagnóstico.*

## 2.3 — El mismo bucle con la ficha

Reiniciá Play (Stop → Start).

| Dónde | Tecla | Qué pasa |
|---|---|---|
| slot 1 | **Q** | Uno genuino, uno falso |
| slot 2 | **E** | Oferta honesta |
| slot 1 | **Z** | Pide más → el turno pasa a slot 2, que dice `OWES A BIGGER OFFER` |
| slot 2 | **X** | Agrega un envoltorio → el turno vuelve |
| slot 1 | **Z** | Segundo pedido |
| slot 2 | **C** | **Acusa**, y acierta |

> Slot 2 no puede acusar sin que le pasen el turno: hoy la negociación **siempre** abre en slot 1. Alternar turnos es A2 y espera al veredicto de la ficha.

**La pregunta que importa:** ¿acusar se sintió como una **apuesta** o como **dinero gratis**?

## 2.4 — La economía (checkpoint 4)

Falsificar **ya no es gratis**: cuesta Clips en proporción a lo que imitás.

1. **Mirá el HUD antes de ofertar.** Anotá el número.
2. En un cliente, **Q** (que incluye una falsificación).
3. **Mirá el HUD otra vez.** ✅ Bajó. Cuánto depende de qué imitó.
4. Terminá el duelo con **R**. ✅ Los dos cobran, y el que ganó cobra más.

**La prueba que importa** — Command Bar, **Server**:

```lua
require(game.ServerScriptService.Services.DataService).get(game.Players:GetPlayers()[1]).clips = 5
```

Ahora desde **ese** cliente ofertá con falsificación (**Q**).

✅ Se rechaza, y en el servidor:

```
[DuelService] request from Player1 rejected: cannot pay N Clips for the forgeries (NotEnough)
```

✅ **Y el saldo sigue en 5** — un rechazo no cobra nada a medias.

---

# BLOQUE 3 — Desconexión 🔴

**3 minutos.** Va solo porque termina cerrando una ventana.

**El bloque más importante después de la persistencia**, y por la misma razón: un camino de desconexión roto **no da error**, corrompe después. Y es lo único del paquete que **ninguna máquina puede probar** — el auto-juego no tiene clientes que cerrar.

1. **Test** → **2** jugadores → **Start**. Llegá a `Negotiating` con **Q** en los dos.
2. **Cerrá la ventana de slot 2** (la X de la ventana, **no** Stop).

En el cliente que **queda vivo**:

```
[Duel] ... phase=Cancelled
```

En el **servidor**:

```
[DuelService] duel ... ended (PlayerN disconnected): expected 0 live objects, got 0
```

❌ **Si el que se queda NO recibe el `Cancelled`, el cambio no funcionó** — aunque el servidor diga `got 0`.

3. Repetilo cerrando durante `BuildingOffers` en vez de `Negotiating`.

### Y la mitad que importa del escrow

Antes de cerrar la ventana, en la Command Bar (**Server**):

```lua
local D = require(game.ServerScriptService.Services.DataService)
for _, p in game.Players:GetPlayers() do print(p.Name, D.get(p).duelCopies) end
```

Ofertá con objetos **reales** (**E**) desde slot 2 y volvé a imprimir: **al que ofertó le faltan esas copias**. Salieron del perfil al ofertar — eso es el escrow.

Ahora cerrá la ventana de slot 2 e imprimí el perfil del que quedó.

| Si ves | Es | Gravedad |
|---|---|---|
| El que se quedó **no recibió nada** | **Pérdida** | Malo |
| El que se fue **conserva** lo que apostó | **Duplicación** | **Peor** — infla la economía de todos, para siempre |

Y algo que no cuesta nada mirar: **la colección de los dos igual que al empezar**. Un duelo mueve copias, nunca colección.

---

# BLOQUE 4 — Bots y arranque en frío

**5 minutos.** Un solo jugador.

1. **Play** con **un** jugador.
2. **Esperá 15 segundos sin tocar nada.** No hay que apretar nada para entrar a la cola.

```
[Matchmaking] Player1 joined the queue (1 waiting)
[Matchmaking] Player1 waited 15s; filled with a bot
```

3. Mirá el nombre del slot 2. ✅ Es un nombre común (`mica.exe`, `Rulo`, `pau_trades`). ❌ Si dice "Bot" o "CPU", esa es exactamente la señal que el diseño prohíbe.
4. **Q** para ofertar. **Esperá unos segundos** — entre 1,2 y 4,5 el bot oferta solo.
5. **Z** (pedir más). El bot contesta con una oferta **más grande**.
6. **R** (aceptar). Revelación normal.

❌ **Si el bot nunca oferta**, ese es el fallo que importa. Mandame el Output.

### Opcional: que una persona le gane la carrera al bot

**Test** → **2** jugadores → **Start**, y **no toques nada 20 segundos**.

✅ Se emparejan entre ellos al instante y **ningún bot aparece**.
❌ Que a los 15 segundos aparezca un bot para uno de los dos: significaría que un bot le robó el lugar a una persona.

---

# Al terminar

1. `DuelRules.debugLogs` → **`false`**.
2. `DataConfig.useMockInStudio` → **`true`** (si el bloque 1.4 lo dejó en `false`).

---

# Lo que tengo que saber cuando termines

**No hace falta que contestes todo. Lo de arriba es lo urgente.**

## 🔴 Fallos, si los hubo

Los tres que frenan todo: **persistencia** (1.2 o 1.4), **desconexión** (bloque 3), y **ver tu texto sin filtrar** en la vitrina.

## Las dos preguntas de diseño

1. ¿El bucle se sintió **injusto o rico**? (2.2)
2. ¿Acusar se sintió como **apuesta o dinero gratis**? (2.3)

## Las decisiones `[propuesta]` esperando tu sí o tu no

Están detalladas en cada checkpoint; acá el resumen para que las contestes juntas:

| Qué | Dónde está el detalle |
|---|---|
| La paleta y las texturas derivadas del texto del GDD | `checkpoint-2.md` |
| Los tiempos del juice (`Theme.motion`) | `checkpoint-2.md` |
| Los precios y recompensas de la economía | `checkpoint-4.md` |
| `botEarningsCapPerDay = 900` (tope diario contra bots) | `checkpoint-5.md` |
| Los números de personalidad de los bots | `checkpoint-5.md` |

## Lo que ya no te pido, y por qué

Lo que antes eran los bloques C, D y F de la prueba de etapa 1 —validación de ofertas inválidas, límites, timeouts, la carrera de `finish()`— **ya no está acá porque se automatizó**. Son 55 aserciones que corren en menos de un segundo con `./selfplay.sh spec`, en cada cambio, y varias están probadas por **mutación**: se rompe la defensa a propósito y se verifica que la aserción se ponga en rojo.

**Tu sentada es exactamente lo que ninguna máquina puede hacer:** mirar y decir qué está feo, sentir si es divertido, y desenchufar un cable de verdad.
