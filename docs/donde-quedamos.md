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

## Lo que está esperando una decisión tuya 🎨

**Cómo se eligen los objetos.** Hoy no se puede elegir tocando: el inventario salió de la hoja y todavía no está decidido con qué se reemplaza. Ofertar es tarea del teclado (**Q** y **E**) hasta entonces.

Lo que se sabe: los objetos van **sobre la mesa, alrededor del papel**, en 3D, y se van a poder achatar y estirar al tocarlos.

**Estás sketcheando eso.**

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
