---
sidebar_label: Prueba · ¿es divertido?
---

# Sesión de prueba con personas — ¿negociar con fakes es divertido?

Esta es la prueba que cierra la Etapa 1. No es una prueba de bugs: es **el examen del juego**, y su resultado decide si se sigue construyendo o se replantea el núcleo.

Necesitás **dos personas que no seas vos**, sentadas a jugar. No hace falta que sepan nada de programación, ni que sepan que hay dos versiones.

---

## Antes de que lleguen (5 minutos, sola)

1. `rojo serve` corriendo y el plugin conectado.
2. Abrí `src/shared/Config/DuelRules.luau` y confirmá:
   - línea 21 → `fakeCallsPerDuel = 1`
   - línea 58 → `debugLogs = false`
3. Studio → **Test** → **2** jugadores → **Start**. Comprobá que las dos ventanas muestran la pantalla del duelo.
4. Acomodá las dos ventanas **lado a lado**, una para cada persona. Si tenés dos monitores, mejor.

---

## Lo único que les explicás

Leeles esto y nada más. **No expliques qué es un fake, ni la ficha, ni la estrategia.**

> "Cada uno tiene una colección. Van a ofrecerse cosas para intercambiar. Podés ofrecer algo de verdad… o podés ofrecer una falsificación y ver si cuela. El otro decide si acepta, rechaza o te pide más. Jueguen y vean qué pasa."

Después callate y mirá. **Lo que te importa no es lo que digan al final, es lo que hacen mientras juegan.**

---

## Las dos versiones

Se juegan las dos, **sin decirles que son distintas**.

| | Cómo se configura | Qué cambia para ellos |
|---|---|---|
| **(a) Con ficha** | `fakeCallsPerDuel = 1` | Aparece el botón **¡ES FAKE!** |
| **(b) Sin ficha** | `fakeCallsPerDuel = 0` | Ese botón no existe; sólo pueden rechazar o pedir más, y la verdad sale en la revelación |

**Para cambiar de versión:** editás ese número en `DuelRules.luau`, Rojo sincroniza solo, y **Stop → Start**. Nada más. El botón aparece o desaparece según el número.

**Alterná el orden entre parejas.** Si la primera pareja juega (a) y después (b), la segunda juega (b) y después (a). Si no, no vas a saber si a la gente le gustó más la segunda versión o simplemente ya había entendido el juego.

Unas 3-4 partidas de cada versión alcanzan.

---

## Qué anotar mientras juegan

Tené el celular al lado y anotá **hechos, no impresiones**. Estas son las cinco cosas que importan, en orden:

**1. ¿Dónde se rieron?** Marcá el momento exacto. En la oferta, al pedir más, en la revelación, al acusar. La risa es el dato más honesto que vas a conseguir.

**2. ¿Alguien dijo "otra"?** Sin que se lo sugieras. **Este es el criterio de aceptación de toda la etapa.** Anotá quién, cuándo, y después de qué versión.

**3. ¿Se quedaron callados en algún momento?** El silencio con cara de "no entiendo" es tan informativo como la risa. Anotá qué estaban mirando.

**4. ¿Cuánto duró cada duelo?** Cronometralo. El GDD apunta a 2-3 minutos. Si duran 30 segundos, falta tensión; si duran 8, hay algo que aburre.

**5. ¿Qué hicieron con las falsificaciones?** ¿Mintieron desde la primera partida? ¿Dejaron de mentir después de que los cazaron? ¿O nunca mintieron?

Recién **al final de todo**, preguntales: *"¿cuál de las dos versiones les gustó más?"* — sin explicarles cuál era cuál. Esa respuesta vale menos que las cinco de arriba, pero sirve para contrastar.

---

## Lo que ya sabemos que va a pasar (no lo reportes como bug)

Estas dos cosas están así **a propósito**, y forman parte de lo que la prueba tiene que medir:

- **Falsificar es gratis.** El costo en Clips no existe todavía (es la tarjeta B2, Etapa 2). Así que mentir no tiene precio.
- **Por eso, en la versión (a), acusar casi siempre acierta.** Si el rival puso una falsificación, la ficha gana. Es probable que los testers descubran que acusar siempre es la jugada obvia.

Si eso pasa, **no significa que la ficha esté rota** — significa que le falta el freno económico. Anotalo tal cual lo veas y ya está.

---

## Cómo se lee el resultado

**Si dos personas piden "otra" sin que se lo sugieras** → la Etapa 1 está aprobada. Se arranca la épica B (datos y economía) con **B2 arriba**, porque el costo en Clips es el freno que hoy falta.

**Si nadie pide otra, pero hubo risas** → hay algo, falta afinarlo. Se itera el prototipo antes de construir sistemas.

**Si no hubo ni risas ni tensión** → el plan tiene esto previsto y no es un fracaso, es información barata: se replantea el núcleo **antes** de construir la Etapa 2. Eso es exactamente para lo que existe esta etapa.

**Sobre la ficha, por separado:** si la versión (a) produjo más risas y más "otra" → se queda. Si (b) fue igual o mejor → la ficha se elimina y `gdd.md` §8 se simplifica. Si no se notó diferencia → se elimina, porque es complejidad que no paga.

---

## Si algo se rompe durante la sesión

No pares la sesión a depurar. Anotá qué pasó y en qué momento, reiniciá con Stop → Start, y seguí. La sesión mide diversión; los bugs se arreglan después con la nota que escribiste.

---

# Resultado — primera sesión (2026-08-04, 2 personas)

## Lo que salió

**El concepto interesa.** Ese es el veredicto de los testers y es la señal que importa: la mecánica de ofrecer, mentir y decidir se entiende y engancha sin que nadie explique nada.

**La UI es muy fea** y se nota. Esperado y deliberado —E0 existe para eso—, pero deja de ser gratis: si la pantalla parece una planilla, la gente juzga la planilla y no el juego. Se arregla con elementos visuales, no con más mecánica.

**Hallazgo principal, y no estaba en la lista de cosas a observar: quieren poder HABLAR.** Los dos testers pidieron poder decirse cosas durante el duelo — para venderse el objeto, para exagerar, para hacerse los graciosos.

## Por qué ese hallazgo importa más que los otros dos

Confirma, con gente real, lo que `gdd.md` §8 anotaba como hipótesis **antes** de la prueba: la diversión del meme original no está en descubrir una falsificación, está en la **actuación de venta**. El sobrehype, el "es rarísimo, no lo consigues en ningún lado".

El prototipo tiene el trueque pero no tiene el escenario donde se actúa. Los testers fueron directo al hueco.

Esto refuerza tres cosas que ya estaban escritas y que ahora dejan de ser intuición:

- **`gdd.md` §31** ya define el chat de texto + emotes como *"canal principal de la guerra psicológica"*. Estaba en el diseño; falta en el prototipo.
- **`gdd.md` §11**, la escena cara a cara, deja de ser sólo un tema de miniaturas: si vas a vender algo actuando, tenés que ver a quién se lo vendés.
- **La tarjeta A7 (emotes)** estaba marcada P1. Con este dato mira a P0.

## ✅ CRITERIO DE ACEPTACIÓN CUMPLIDO

> *"Ahora es mi turno. Otra, otra."*

Dicho por los testers, sin que nadie se lo sugiriera. Es exactamente el criterio que `plan-etapas.md` fija para cerrar la Etapa 1: **dos personas que no sos vos piden otra partida**.

La pregunta que la etapa existía para responder —*¿negociar con fakes es divertido?*— está contestada, y con el peor prototipo posible: sin arte, sin sonido, sin animaciones, sin chat, con los objetos como filas de texto. Que enganche **así** es la mejor noticia que podía dar esta prueba, porque todo lo que falta suma encima de algo que ya funciona.

## Lo que sigue sin dato

**No se comparó (a) con ficha vs (b) sin ficha.** El protocolo de las dos configuraciones quedó sin ejecutar, así que sobre la ficha ¡ES FAKE! seguimos sin saber si aporta o estorba. Queda pendiente para la segunda sesión, y no es un detalle: de eso depende que la mecánica entre o no a la Etapa 2.

## Sospecha técnica a verificar antes de diseñar nada

Puede que el chat **no faltara**, sino que estuviera tapado o roto:

1. El Output de la sesión mostraba `Failure to Start CoreScript module TopBar` — y el botón del chat vive en esa barra.
2. La pantalla de E0 ocupa el 94% del ancho con `IgnoreGuiInset`, así que aunque el chat funcionara, queda debajo.

Son dos problemas distintos con arreglos distintos: uno es "hay que hacer sitio para el chat" y el otro es "hay que arreglar por qué no arranca". Se verifica antes de escribir código.
