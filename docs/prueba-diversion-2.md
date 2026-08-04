---
sidebar_label: Prueba 2 · ¿la ficha aporta?
---

# Segunda sesión — el experimento de la ficha

La primera sesión ya contestó la pregunta grande: **el juego divierte**. Esta contesta una distinta y más chica, pero que decide qué código entra a la Etapa 2:

> **¿La ficha ¡ES FAKE! aporta algo, o es una regla de más?**

Y de paso mira si, con chat y emotes, aparece la **actuación de venta** que los testers pidieron.

> **Este protocolo se escribió ANTES de construir la iteración corta, a propósito.** Si se escribiera después, mirando lo que quedó hecho, el experimento se acomodaría a lo que resultó fácil de probar. La pregunta se congela primero; las herramientas se adaptan a ella.

---

## Las dos versiones

| | Configuración | Qué cambia para ellos |
|---|---|---|
| **(a) Con ficha** | `fakeCallsPerDuel = 1` | Existe el botón **¡ES FAKE!** |
| **(b) Sin ficha** | `fakeCallsPerDuel = 0` | Ese botón no existe. La única defensa es rechazar o pedir más, y la verdad sale recién en la revelación |

Se cambia editando ese número en `src/shared/Config/DuelRules.luau` (línea 21). Rojo sincroniza solo; **Stop → Start** y listo.

**Nunca les digas que hay dos versiones.**

---

## Reglas del experimento

**Mismas personas que la primera vez**, si se puede. Ya conocen el juego, así que no vas a estar midiendo "aprender a jugar" en vez de "cuál versión es mejor".

**Alterná qué versión va primero.** Si la pareja A juega (a) y después (b), la pareja B juega al revés. Sin eso, no distinguís "les gustó más la segunda" de "ya le habían agarrado la mano".

**3–4 partidas de cada versión.** Menos que eso es anécdota.

---

## Qué observar

### Sobre la ficha — la pregunta principal

1. **¿En qué versión hubo más risas?** Sigue siendo el dato más honesto.
2. **¿En cuál pidieron "otra" más rápido?**
3. **En la versión (b), sin ficha: ¿la revelación se sintió mejor o peor?** Sin ficha nadie interrumpe la mentira antes de tiempo — puede que eso haga la revelación más explosiva, o puede que quite toda la tensión previa.
4. **En la versión (a): ¿acusar se sintió como apostar o como cobrar?** Si acusar siempre acierta, es porque falsificar todavía es gratis (falta B2). Anotalo como lo veas.

### Sobre la actuación de venta — la pregunta secundaria

5. **¿Se hablaron?** ¿Usaron el chat, los emotes, o se hablaron en voz alta entre ellos?
6. **¿Mintieron con la boca, además de con el objeto?** Frases tipo "es rarísimo, no lo consigues". Eso es exactamente lo que el juego quiere provocar.
7. **¿Los emotes se usaron, o quedaron de adorno?**

---

## Cómo se lee el resultado

**Si (a) produjo más risas y más "otra"** → la ficha se queda. Entra a la Etapa 2 y `gdd.md` §8 pierde su 🧪.

**Si (b) fue igual o mejor** → la ficha **se elimina**. Se borra A4, se simplifica §8, y la Etapa 2 se construye sin ella. Es una mecánica menos que mantener para siempre.

**Si no se notó diferencia** → también se elimina, por la misma razón: complejidad que no paga.

Cualquiera de los tres desenlaces es un buen resultado. El único mal resultado sería construir diez semanas de Etapa 2 encima de una mecánica que nunca se midió.

---

## Controles — todo con botones

**No hace falta el teclado para nada del juego.** Esto es lo único que tenés que explicarles, y sólo si preguntan:

| Para… | Hacen esto |
|---|---|
| Elegir qué ofrecer | En **Tu colección**, tocan **Real** (algo que tienen de verdad) o **Falso** (una falsificación) |
| Sacar algo elegido | La **X** en Tu oferta |
| Mandar la oferta | **OFERTAR** |
| Negociar | **Aceptar** · **Rechazar** · **Pedir más** |
| Acusar *(sólo versión a)* | **¡ES FAKE!** |
| Reaccionar | Los seis botones de **Reacciones** — 🤩 🤨 😂 🙏 💀 🔥 |
| **Hablar** | Apretar **`/`** y escribir. El cartel gris arriba se los recuerda |

**Lo de hablar es lo nuevo y es lo que esta sesión viene a mirar.** No se los subrayes: si tienen que preguntarte cómo hablar, eso ya es información.

## Antes de que lleguen

1. `rojo serve` corriendo, plugin conectado.
2. `src/shared/Config/DuelRules.luau` → `fakeCallsPerDuel` en el valor de la versión que va primero.
3. Studio → **Test** → **2** jugadores → **Start**, ventanas lado a lado.
4. Que cada persona **haga click sobre su ventana** una vez, para que tome el teclado y puedan escribir.

---

## Si algo se rompe

Igual que la vez pasada: no pares a depurar. Anotá qué pasó y cuándo, Stop → Start, y seguí. La sesión mide diversión.
