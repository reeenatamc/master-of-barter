---
sidebar_label: Checkpoint 4 · economía
---

# Checkpoint 4 — economía (B2)

> **⭐ No corras este documento suelto.** Está encadenado con los otros cuatro en **[`sesion-unica.md`](sesion-unica)**, que los ordena por fricción. Esto queda como el detalle.

**El checkpoint 3 va primero y va solo.** Este espera a que la persistencia esté probada, porque acá los Clips se escriben en el perfil: si el guardado no está verificado, este checkpoint mide humo.

**Tiempo: 10 minutos**, una vez que el 3 haya pasado.

---

## Qué cambió

Falsificar **ya no es gratis**. Cuesta Clips, proporcional al valor de lo que imitás, que es la regla de `gdd.md` §19: mentir sobre algo caro tiene que costar caro, para que una falsificación sea una apuesta y no una opción libre.

Y el final del duelo **paga**: victoria, empate o derrota, más un extra por cada falsificación que colaste y por acertar con la ficha.

Eso es exactamente el freno que faltaba. Las dos estrategias dominantes que aparecieron en la primera prueba —"falsificá todo" y después "acusá siempre"— eran síntomas de este precio faltante.

---

## La prueba

1. **Play**, dos jugadores. Command Bar, contexto **Server**:

```lua
local E = require(game.ServerScriptService.Services.EconomyService)
for _, p in game.Players:GetPlayers() do print(p.Name, E.balanceOf(p)) end
```

Los dos arrancan con **250**.

2. Jugá un duelo. En uno de los clientes armá una oferta **con una falsificación** y ofertá.

3. Volvé a imprimir los saldos. **El que falsificó tiene menos.** Cuánto menos depende de qué imitó — falsificar La Última Empanada (340) cuesta mucho más que la Sopa Maruchan (12).

4. Terminá el duelo aceptando, y volvé a imprimir. **Los dos cobraron**, y el que ganó cobró más.

5. **La prueba que importa:** gastá casi todo y tratá de falsificar algo caro.

```lua
local D = require(game.ServerScriptService.Services.DataService)
D.get(game.Players:GetPlayers()[1]).clips = 5
```

Ahora ofertá una falsificación de un legendario desde ese cliente. **Tiene que rechazarse**, y en el Output del servidor:

```
[DuelService] request from Player1 rejected: cannot pay N Clips for the forgeries (NotEnough)
```

Y el saldo tiene que seguir en **5** — un rechazo no cobra nada a medias.

---

## Decisiones `[propuesta]` que esperan tu sí o tu no

Todos estos números están en `src/shared/Config/Economy.luau`. **Cambiar cualquiera es una línea**, y ninguno está calibrado: `gdd.md` §19 marca la economía entera como "calibrar en alfa".

### Cuánto cuesta falsificar

`costo = valor × 0.45 + 15`

| Objeto | Vale | Falsificarlo cuesta |
|---|---|---|
| Sopa Maruchan Dorada | 12 | 20 |
| Yogur Vencido en 2011 | 48 | 36 |
| Módem Que Sí Andaba | 96 | 58 |
| La Última Empanada | 340 | 168 |

**La pregunta de diseño:** ¿mentir sobre lo caro duele lo suficiente? Con 250 Clips de arranque, podés permitirte falsificar la empanada una vez y quedarte casi sin nada. Esa es la intención — pero es intención, no dato.

### Cuánto paga un duelo

| Concepto | Clips |
|---|---|
| Ganar | 120 |
| Empatar | 60 |
| Perder | 25 |
| Por jugar (siempre) | 10 |
| Por falsificación colada | 60 |
| Por acertar la ficha | 80 |

**La pregunta de diseño:** ganar honestamente paga 130. Colar dos falsificaciones y ganar paga 250. ¿Está bien que mentir bien pague casi el doble, o eso empuja el juego demasiado hacia el engaño?

**La estructura sí está decidida: el bluff DEBE pagar más.** Carga un riesgo que el juego honesto no carga — el costo hundido de fabricar, más la ruina si te cazan. Retorno alto con varianza alta contra retorno bajo seguro: eso es póker, y es la tensión que el juego quiere. Cuánto más (¿1,9×? ¿1,5×?) es número calibrable; que exista el premio es diseño correcto.

> ### ⚠️ Esta pregunta no se puede cerrar antes que la sesión de diversión 2
>
> Toda la respuesta de arriba **asume que existe el contrapeso**, y el contrapeso es la ficha **¡ES FAKE!**, cuyo destino depende del checkpoint 1 (`prueba-diversion-2.md`), que todavía no se corrió.
>
> Si esa sesión mata la ficha, mentir **pierde su castigo**: el 250 contra 130 pasa a ser estrategia dominante sin freno, y habría que bajar el premio entero o encontrar otro contrapeso.
>
> **El veredicto del premio al bluff depende del veredicto de la ficha.** Por eso la sesión de diversión 2 se volvió el cuello de botella de **dos** decisiones, no de una.

---

## Lo que este checkpoint NO prueba

**Que el kiosco funcione.** Comprar objetos con Clips es B4; hoy los Clips solo se gastan en falsificaciones y se ganan en duelos.

**Que la colección crezca.** Sigue siendo B3. Los duelos reparten objetos de prueba en memoria.
