---
sidebar_label: Prueba · Etapa 1
---

# Sesión de prueba — punto de control Etapa 1 (tras A4)

> **⭐ No corras este documento suelto.** Está encadenado con los otros cuatro en **[`sesion-unica.md`](sesion-unica)**, que los ordena por fricción. Esto queda como el detalle.

**Duración: 10 minutos.** Eran 20–30.

Lo que se fue no se dejó de probar: **se automatizó.** Los bloques C, D y F de la versión anterior son ahora 34 aserciones que corren en menos de un segundo:

```
./selfplay.sh spec
```

Ahí viven, y con mejor cobertura que en Studio: acciones fuera de turno, las siete ofertas malformadas, el ataque de duplicación, el límite de 3 pedidos, la enmienda que no crece, los dos timeouts de fase, el watchdog por generación, el marcador, la ficha, la carrera de `finish()`, y la regla de oro verificada contra **todos** los `DuelState` que el servidor mandó en 40 duelos.

**Lo que queda acá es lo que ninguna máquina puede hacer:**

| Bloque | Por qué sigue siendo tuyo |
|---|---|
| **A y B** — el bucle completo | No verifican nada: preguntan si **es divertido**. Ese es el punto de la Etapa 1 y no hay test que lo conteste |
| **E** — desconexión | Necesita un cliente real cerrando una ventana real. El arnés no tiene clientes |

---

## Antes de empezar

1. `rojo serve` corriendo y el plugin conectado.
2. En `src/shared/Config/DuelRules.luau`, poné **`debugLogs = true`**.
3. Pestaña **Test** → *Clients and Servers* → **2** jugadores → **Start**.

**Teclas:** **Q** ofertar 1 real + 1 fake · **E** ofertar 2 reales · **R** aceptar · **T** rechazar · **Z** pedir más · **X** enmendar · **C** ¡ES FAKE!

**Cómo saber quién es quién:** cada cliente imprime `you=slot1` o `you=slot2`. El slot 1 abre la negociación.

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


## Bloque E — desconexión 🔴

**El único bloque de verificación que queda, y es el que más importa.** Un camino de desconexión roto no da error: corrompe después. Y el arnés no puede tocarlo, porque no tiene clientes que cerrar.

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

## Y al terminar

`debugLogs` a `false`.

**Lo que este documento ya no te pide, y por qué está bien:** los bloques automatizados no se "confían" — se corren en cada cambio que toque el duelo, que es más de lo que una sesión manual podía dar. Varios de ellos, además, se probaron por **mutación**: se rompió la defensa a propósito y se verificó que la aserción se pone en rojo. Un verde que nunca vio rojo no es evidencia de nada.
