---
sidebar_label: 📍 Dónde quedamos
---

# Dónde quedamos

*Última actualización: 2026-08-05, al final de la sesión de pruebas y rediseño del tablero.*

---

## Probado y cerrado ✅

| | |
|---|---|
| **Persistencia** 🔴 | Contra el DataStore real. 272 Clips sobrevivieron al Stop |
| **Desconexión** 🔴 | El que queda recibe `Cancelled`, sin fugas |
| **Economía** | La cuenta dio exacta: 250 − 168 (falsificar) + 190 (ganar) = 272 |
| **Bots** | Entran a los 15s, ofertan, enmiendan, y ahora tienen cuerpo emo |

**Los dos bloques peligrosos están probados.** Lo que falla callado ya no puede fallar callado.

## El tablero, rediseñado

Quedó como la referencia: hoja blanca sobre madera, dos rayas —azul la tuya, rosa la del rival—, cuatro verticales, seis marcas grandes y el centro vacío.

**Fuera de la hoja por ahora** (interruptores en `Theme.table`): la tira de emotes y la ficha ¡ES FAKE! (`showEmotes`, `showToken`), y el inventario de objetos.

## La decisión de los objetos, ya tomada ✅

**Salen de una canasta.** El modelo de la canasta trajo su propia nota de diseño y resolvió lo que estaba trabado:

> una canasta afuera de cada lado de la mesa · los squishies no elegidos se quedan adentro · solo los elegidos llegan al tablero

Las dos canastas ya se construyen por código en cada duelo (`DuelSceneService`), con la malla referenciada por id y el look en `Theme.table.basket`.

**Falta:** meter los squishies adentro, poder sacarlos con el dedo, y el achatado al tocarlos.

## Listo y esperando

`assets/Squishy01.obj` — 8.996 triángulos, una pieza, con UV.
`assets/Squishy01_textura.png` — 1024×1024, 0,7 MB.

**Falta**: importarlo en Studio (**`Home` → `Import`**), pegarle la textura por `Asset Manager`, y guardarlo como `Squishy01.rbxm` en `assets/`. Después decir para qué objeto del catálogo es.

## Antes de publicar, acordate

En `DuelRules.luau`, dos valores están subidos **para la sesión de pruebas**:

```
phaseSeconds.BuildingOffers = 600   → los de balance son 45
phaseSeconds.Negotiating   = 600   → los de balance son 30
debugLogs = true                    → en producción, false
```

## Lo próximo del lado del código

**E1, el lobby.** La única tarjeta grande que no depende de tus veredictos — y borra las teclas y las solapas provisorias. No arrancada a propósito: si el tablero y los objetos van a moverse, construir el lobby alrededor es construir sobre algo que se mueve.
