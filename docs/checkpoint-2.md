---
sidebar_label: Checkpoint 2 · revisión visual
---

# Checkpoint 2 — revisión visual (C2 + E2)

Esto es lo único que necesita tus ojos ahora. Todo lo demás siguió sin vos.

**Tiempo estimado: 15 minutos.** Diez de mirar, cinco de decir qué está mal.

> **El HUD de E3 ya está construido y entra a este paquete** (2026-08-05). Dos papelitos arriba a la izquierda: **Clips** y **colección** (`n / 12`). El servidor los empuja y el HUD los dibuja; nada ahí calcula nada.
>
> **Qué mirar, y por qué cada cosa:**
>
> | Mirá | Qué está en juego |
> |---|---|
> | ¿Se lee de un vistazo **en el teléfono chico**? | Los papelitos miden 20% del ancho. Si en móvil hay que entrecerrar los ojos, el número está mal y es un valor, no un rediseño |
> | ¿**Tapa** algo? Sobre todo al rival | §11: ver al rival es mecánico. Un HUD que estorba es un HUD que se mueve o se achica |
> | ¿Parece **dibujado por la misma birome** que el tablero? | §28 es no negociable. Si el HUD parece de otro juego, no cumple, por prolijo que sea |
> | Ganá o gastá Clips y mirá el número | Tiene que **saltar y asentarse**, no cambiar de golpe. Un número que salta es un número que nadie nota |
> | ¿La inclinación de los papelitos se siente **hecha a mano o descuidada**? | Es a propósito (`Theme.tiltDegrees`), y si se lee como error hay que bajarla |
>
> **El kiosco y la vitrina también entraron** (2026-08-05), así que **el paquete visual está completo**: tablero, catálogo, móvil, HUD, kiosco y vitrina en una sola sentada.
>
> **Kiosco:** cuatro papelitos con precio, COMPRAR **deshabilitado con el motivo** (*"te faltan 40"*), contador de rotación y el cartel de que el stock es igual para todos. Mirá que COMPRAR **no compita** con los tres botones de negociación — no es verde a propósito, se destaca por tamaño y trazo. Si igual te roba la atención, es señal de que la jerarquía no alcanzó.
>
> **Vitrina:** nombre editable y cuatro ranuras. **Lo que hay que probar acá es de moderación, no de estética:** escribí un nombre y fijate que lo que queda en pantalla **no sea exactamente lo que tipeaste** — pasa por el filtro de Roblox y se muestra el resultado. Si ves tu texto tal cual, avisá: sería el único fallo grave del paquete.

---

## Lo que cambió desde la primera versión de este checkpoint

Llegaron tus mockups, y **cambiaron cosas de fondo**. Esta versión ya está rehecha contra ellos, así que lo que vas a ver es la escena final — tu única sentada.

**El tablero se acostó.** La instrucción escrita decía "hoja vertical sobre la mesa"; las imágenes la muestran plana entre los dos. Se frenó, se preguntó, ganó la imagen, y `gdd.md` §25 quedó corregido el mismo día para que el doc no siga contradiciendo a los mockups.

**La tinta es birome azul.** Es lo más definitorio de las imágenes y no se ve hasta mirarlas: absolutamente todo el trazo del mundo es la misma lapicera. Quedó escrito en `gdd.md` §28 como regla de arte 🔒, y en el código todo el dibujo pasa por una sola función, así que la regla se cumple por construcción y no por memoria.

**Los objetos ahora son recortes de papel parados**, con borde blanco de tijera y sombra en la base — no cuadraditos de color. Es la fase 1 de dos: los modelos de origami 3D los reemplazan de a uno, empezando por los legendarios.

---

## Cómo verlo

1. `rojo serve` corriendo, plugin conectado.
2. Studio → **Test** → **2** jugadores → **Start**.
3. Cada ventana: **click sobre el juego** una vez.

Ya no hay panel flotando: **la cámara te pone en la mesa mirando hacia abajo**, con el tablero acostado entre vos y el rival, y él enfrente. Todo se toca sobre el tablero.

De lejos a cerca vas a ver: los tres botones de él en contorno, sus casilleros, la red punteada, tus casilleros, y tus tres botones grandes y rellenos.

Jugá un duelo entero: elegí **Real** o **Falso** en unos objetos, **OFERTAR**, y después **Aceptar** para llegar a la revelación.

**Si algo se rompe y no ves nada:** abrí `src/shared/Config/Theme.luau`, buscá `screen = "table"` y ponelo en `"flat"`. Vuelve la pantalla vieja de E0, que sigue funcionando. Esa salida existe justamente para que un checkpoint no te deje sin juego.

---

## Qué mirar, en orden de importancia

**1. ¿Se parece a tus mockups?** Es la pregunta del checkpoint. Papel kraft cálido, birome azul en todo, recortes torcidos, casilleros punteados, tus tres botones rellenos en rojo/verde/azul. Si algo no da, describime qué y ajusto `Theme.luau` — la estructura aguantó cambiar la paleta entera dos veces sin que se tocara nada de lo que la lee.

**2. La Revelación™.** Los envoltorios se destapan **de a uno**, no todos juntos, con un rebote al caer. ¿Se siente un momento, o se siente una lista?

**3. Que nada esté perfectamente derecho.** Cada recorte está rotado un poco distinto, a propósito (§28). ¿Se lee como papel, o como un error?

**4. Móvil — la prueba que decide.** Test → **Device** → un teléfono. **Es criterio de cierre de E2**, no un extra.

Lo que decide: **¿los botones sobre el tablero se tocan bien con el dedo?** Es el riesgo que asumí al ponerlos en el mundo en vez de en la pantalla. Ya está la protección — cada zona táctil es **1,5× más grande que el botón dibujado**, invisible y centrada, así que el dedo no necesita puntería. Si aun así falla, el plan B es mover los tres botones a un `ScreenGui` al pie y dejar solo el trueque en el tablero.

**5. Ventana de PC.** Achicá y agrandá la ventana. Nada debería descolocarse: todo está en escala.

---

## Decisiones `[propuesta]` que esperan tu sí o tu no

### El catálogo — 12 objetos originales

Reemplazan a los 6 squishies de prueba. La gracia es que son cosas de tu casa tratadas como reliquias — el tono de §22 sin tomar prestado el personaje de nadie:

| | Objeto | Valor | Línea |
|---|---|---|---|
| Común | Sopa Maruchan Dorada | 12 | *Sabor camarón. Nunca la vas a cocinar.* |
| Común | Piedra que Parece Papa | 15 | *O una papa que parece piedra. Nadie mordió.* |
| Común | Control de la Abuela | 18 | *Forrado en plástico desde 1994. Impecable.* |
| Común | Lápiz Mordido | 22 | *Mordido por alguien famoso. Eso dicen.* |
| Común | La Media Que Falta | 26 | *La otra está en la secadora. Desde siempre.* |
| Raro | Yogur Vencido en 2011 | 48 | *Sin abrir. Técnicamente sigue siendo yogur.* |
| Raro | Tu Primer Diente | 62 | *El ratón nunca vino. Vos te lo quedaste.* |
| Raro | Pizza del Fondo | 78 | *Del fondo del freezer. Tiene escarcha propia.* |
| Raro | Módem Que Sí Andaba | 96 | *Lo desenchufaste una vez y nunca más fue igual.* |
| Legendario | Destornillador de Papá | 210 | *No es para tornillos. Es para todo lo demás.* |
| Legendario | El Cargador Perdido | 270 | *Nadie sabe de quién es. Todos lo reclaman.* |
| Legendario | La Última Empanada | 340 | *Estaba en la bandeja. Ahora es tuya. Ganaste.* |

Cambiar cualquiera es una línea en tres archivos y cero código, como prometía C1. Si alguno no te causa gracia, decilo y lo cambio: **el humor es la mitad del producto**, no es decoración.

Dos aparecen en tus mockups (la Maruchan y la piedra con carita), pero eso **no los da por aprobados** — sigue pendiente tu veredicto nombre por nombre.

### Otras que quiero que veas

- **Paleta rederivada de tus imágenes** — kraft cálido, birome azul, y los tres botones como paneles rellenos pálidos. La acusación lleva un rojo más oscuro que Rechazar a propósito: son jugadas opuestas, y compartir color haría que el botón más fuerte del juego parezca el más suave.
- **Fuentes** — `PermanentMarker` para títulos y botones, `PatrickHand` para texto. Verificadas contra la API real; `Caveat`, `Amatic` y `ArchitectsDaughter` **no existen** en Roblox aunque suenen a que sí.
- **Tiempos del juice** — en `Theme.motion`. Si la revelación se siente lenta o apurada, es un número ahí.
- **Sonidos: no hay ninguno.** Están todos vacíos a propósito. Un id inventado apunta al sonido de otra persona o a nada. Los nombres describen qué necesita cada hueco (papel arrugándose, cinta, sello, "ohhh" de chicos), así que llenarlos es ir de compras, no diseñar.

---

## Lo que NO decide este checkpoint

**La ficha ¡ES FAKE! sigue esperando el checkpoint 1** (`prueba-diversion-2.md`), que nunca se corrió. Mientras tanto no construí nada que dependa de que exista **ni** de que no exista: sigue gobernada por un número en Config.

---

## Deudas abiertas, marcadas para que no pasen por no vistas

- **`DuelService` está en 927 líneas**, tres veces el límite de 300. No lo dividí en medio de E2 porque es un refactor grande y arriesga romper un juego que funciona. Toca antes de B1.
- **`DuelSkin` en 360 líneas** — la pantalla vieja de E0, que ahora es solo el plan B. Se borra cuando E2 esté aprobada.
- **Rate limiting general** sigue sin existir. El único que hay es el cooldown de emotes.

---

## Mientras esperás

Sigo con **B1** (ProfileStore y persistencia), que no depende de este checkpoint. El checkpoint 3 va a ser el de persistencia, y ese sí es obligatorio antes de seguir: los datos que se guardan no se auto-certifican.
