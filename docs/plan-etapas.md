---
sidebar_label: Plan por etapas
---

# Plan por Etapas — Master of Barter
**Versión 0.1 — Fase 7 · agosto 2026**

Calibración: desarrolladora sola, ~5–8 h/semana en ratos sueltos, avanzando en paralelo con la ruta de aprendizaje. Los tiempos son **calendario realista**, no horas de trabajo. Total estimado hasta lanzamiento público: **9–12 meses**. Si el ritmo semanal cambia, avisar y se recalibra.

Leyenda de tareas: 🟥 Imprescindible · 🟨 Importante · 🟩 Opcional · 💤 Pospuesta

---

## Etapa 0 — Preparación (1–2 semanas · en paralelo con Niveles 0–1 de la ruta)

**Objetivo:** entorno listo y alcance congelado para no decidir nada dos veces.
**Dificultad:** baja · **Conocimientos:** ninguno previo.

| Tarea | Prio |
|---|---|
| Cuenta + Studio instalado y verificado; publicar un lugar privado de prueba | 🟥 |
| Crear el lugar del proyecto "Master of Barter [DEV]" (privado) | 🟥 |
| Tablero Trello/GitHub Projects con el backlog de la Fase 8 | 🟥 |
| Convenciones: nombres en español para dominio (Ofertar, Clips), PascalCase módulos, camelCase variables | 🟨 |
| Congelar alcance del MVP: imprimir/fijar la lista "Fuera del MVP" del análisis de Fase 4 | 🟥 |
| Carpeta de referencias visuales del estilo papel (capturas del meme, paletas) | 🟩 |

**Entregables:** lugar dev publicado, tablero con backlog, documento de convenciones (media página).
**Riesgos:** sobre-prepararse como forma de procrastinar. Límite duro: 2 semanas.
**Criterio de aceptación:** puedes abrir Studio, tocar Play, y sabes exactamente cuál es la siguiente tarjeta del tablero.
**Resultado jugable:** ninguno aún (único caso permitido).

---

## Etapa 1 — Prototipo (4–6 semanas · al ir terminando el Nivel 2)

**Objetivo:** responder UNA pregunta: **¿negociar con fakes es divertido?** Nada más importa.
**Dificultad:** media · **Conocimientos:** Luau básico, eventos, remotos elementales, UI cruda.

| Tarea | Prio |
|---|---|
| Mesa de duelo con UI fea: 3 botones + lista de objetos como texto plano | 🟥 |
| Lógica de negociación completa en servidor (ofertar, pedir más ×3, aceptar, rechazar) | 🟥 |
| Fakes: marcar objetos como fake al ofertar; revelación al aceptar (un `print` glorificado) | 🟥 |
| Ficha ¡ES FAKE! y su resolución | 🟥 |
| 6 objetos de prueba con valores inventados; pistas = una errata en el nombre del fake | 🟥 |
| Bot rival tonto (acepta/rechaza al azar) para probar sola | 🟥 |
| Sesiones de prueba con 2 clientes de Studio + al menos 3 personas reales (amigos/familia) | 🟥 |
| Cronometrar duelos: ¿caben en 2–3 min? Ajustar límites de rondas/tiempos | 🟨 |

**Entregables:** prototipo jugable feo + notas de las pruebas (qué dio risa, qué aburrió, qué confundió).
**Dependencias:** Etapa 0; Nivel 2 de la ruta (remotos y validación).
**Riesgos:** ⚠️ el mayor del proyecto: que la mecánica NO sea divertida. Si tras iterar 2–3 veces las pruebas no producen risas ni tensión, se replantea el núcleo ANTES de construir nada más. Este es el punto de salida barato.
**Criterio de aceptación:** dos personas que no eres tú piden "otra partida" sin que se lo sugieras. — ✅ **CUMPLIDO el 2026-08-04.** Textual: *"ahora es mi turno, otra, otra"*, sin que nadie lo sugiriera, con el prototipo feo y sin chat. Ver `prueba-diversion.md`.

**Protocolo de la prueba de diversión — la ficha ¡ES FAKE! es un experimento, no una decisión.**

El razonamiento está en `gdd.md` §8: la diversión del meme original vive en la *actuación de venta*, y eso ya funciona sin que exista ninguna falsificación física. La ficha es capa nuestra encima. Así que la sesión no pregunta "¿te gustó?", compara dos versiones:

| | Configuración | Cómo se defiende quien recibe |
|---|---|---|
| **(a) Con ficha** | `fakeCallsPerDuel = 1` | Acusar, rechazar o pedir más |
| **(b) Sin ficha** | `fakeCallsPerDuel = 0` | Solo rechazar o pedir más; el fake se descubre recién en la revelación |

Se juegan varias partidas de cada una, **alternando cuál va primero entre parejas** para que el orden no contamine el resultado. No se le explica a nadie que hay dos versiones.

Lo que se observa, y en este orden de importancia: **dónde hubo más risas**, **cuál produjo más "otra"**, y sólo después qué dijeron cuando se les preguntó. Lo que la gente hace pesa más que lo que opina.

Posibles desenlaces: la ficha multiplica la tensión (se queda), la ficha agrega una regla a algo que ya funcionaba (se elimina y §8 se simplifica), o no se nota diferencia (se elimina por ser complejidad que no paga).

**Resultado jugable:** un duelo completo horrible de ver y divertido de jugar.

---

## Etapa 2 — MVP (10–14 semanas · durante el Nivel 3)

**Objetivo:** el bucle completo con la arquitectura real de la Fase 6.
**Dificultad:** alta (la etapa más larga y donde se abandona; tareas chicas, victorias frecuentes).
**Conocimientos:** arquitectura por servicios, ProfileStore, tipado básico, TweenService, Rojo+Git (migrar aquí).

| Tarea | Prio |
|---|---|
| Migrar prototipo a la estructura de la Fase 6 (servicios/controladores, config central) | 🟥 |
| Migrar a Rojo + Git; primer commit limpio | 🟨 |
| DataService con ProfileStore: perfil completo, BindToClose, prueba de cierre abrupto | 🟥 |
| EconomyService (Clips) + InventoryService (colección + copias de duelo) | 🟥 |
| MatchmakingService: cola en servidor + entrada de bots por timeout | 🟥 |
| BotService v1: 2 personalidades (agresivo, tímido) | 🟥 |
| DuelService definitivo: FSM completa, watchdogs, desconexiones, Trove por duelo | 🟥 |
| Validación en 4 capas de todos los remotos + rate limiting | 🟥 |
| UI papel v1: mesa, negociación, revelación animada (versión sencilla), HUD, kiosco | 🟥 |
| **Juice: feedback audiovisual tras CADA acción significativa** — poner un objeto en la mesa, pedir más, aceptar, acusar, revelar. No sólo la Revelación™ | 🟥 |
| Emulador móvil como parte del cierre de cada pantalla | 🟥 |
| Kiosco: comprar objetos/copias con Clips | 🟥 |
| 12 objetos en 3 rarezas con pistas de fake (3 tipos de imperfección) | 🟥 |
| 1–2 game passes cosméticos (un envoltorio + un efecto de revelación) con ProcessReceipt | 🟨 |
| Sonidos base (papel, cinta, revelación) desde Theme.luau | 🟨 |
| Emotes prediseñados (6) | 🟨 |
| Vitrina simple en lobby | 🟩 |

<!--
Nota de rate limiting (detectada al cerrar A1.3): no alcanza con throttlear las
acciones VÁLIDAS. Un cliente puede spamear solicitudes inválidas sin límite:
cada una se rechaza correctamente, pero ninguna consume el estado que frena la
repetición (ej. el "ya ofertaste" de DuelOffer solo aplica tras una oferta
válida). Mil rechazos por segundo se procesan y se loguean igual — el logging de
rechazos es en sí un costo que el cliente puede inflar. La tarea necesita las dos
mitades: throttle de acciones válidas y techo de solicitudes inválidas por
jugador.
Además: esto no tiene tarjeta propia en backlog.md, así que hoy no tiene
criterios de aceptación como el resto del trabajo P0. Se escribe la tarjeta al
entrar a Etapa 2, con criterios como cualquier P0:
  - qué se throttlea exactamente (qué remotos, qué ventana, qué límite);
  - techo de solicitudes inválidas por jugador, separado del throttle de válidas;
  - cómo se prueba que un cliente que spamea queda efectivamente cortado.
Una regla sin criterio de aceptación es una intención, no una tarea.
-->

**Entregables:** juego completo jugable de punta a punta en servidor privado.
**Dependencias:** Etapa 1 validada (¡divertido!); Nivel 3 de la ruta en curso.
**Riesgos:** scope creep ("ya que estoy, agrego…" → NO: al backlog de post-MVP); fatiga de mitad de proyecto (mitigación: publicar avances a amigos cada 2 semanas).

**Sobre el juice, que subió de prioridad:** la guía de retención de Roblox es explícita en que un loop funciona cuando **la siguiente acción es obvia y cada acción devuelve feedback inmediato**. Reservar todo el jugo para la revelación deja el 90 % del duelo mudo: ofertar, pedir más y aceptar tienen que sonar y moverse también. Es barato (TweenService y sonidos que ya están en `Theme.luau`) y es la diferencia entre un prototipo que se siente vivo y uno que se siente un formulario.
**Criterio de aceptación:** una persona nueva entra, juega 3 duelos contra humano y contra bot sin distinguirlo con certeza, compra algo en el kiosco, cierra el juego, vuelve y su progreso está intacto. Cero errores en consola.
**Resultado jugable:** Master of Barter reconocible, feo en los bordes, sólido en el centro.

---

## Etapa 3 — Alfa (4–6 semanas)

**Objetivo:** contenido, onboarding y ojos: que jueguen personas reales y que la analítica lo cuente.
**Dificultad:** media · **Conocimientos:** Analytics, diseño de tutorial, iteración con feedback.

| Tarea | Prio |
|---|---|
| Onboarding con Don Trueque: duelo guiado, primer objeto regalado, fake obvio didáctico. **Primeros ~10 segundos: se entiende qué está pasando y hay una recompensa al alcance; primer trade dentro del primer minuto** | 🟥 |
| AnalyticsService: funnel de onboarding + eventos de duelo/kiosco | 🟥 |
| Misiones diarias (3) | 🟨 |
| Completar a 15 objetos; pasada de arte a los que quedaron feos | 🟨 |
| Pruebas cerradas: 10–20 jugadores invitados (amigos, conocidos, algún server de Discord) | 🟥 |
| Ciclo semanal: leer datos + feedback → ajustar economía/pistas en Config → repetir | 🟥 |
| Corrección de todos los bugs de consola reportados | 🟥 |

**Entregables:** build alfa + primer informe de métricas (funnel, duración de duelo, uso de fakes/acusaciones).
**Riesgos:** tomar el feedback de 10 personas como verdad absoluta (los datos moderan las anécdotas); descuidar el balance del bluff (es EL trabajo de esta etapa).
**Criterio de aceptación:** >60 % de jugadores nuevos completa el onboarding y juega ≥3 duelos; el ratio de ofertas con fake está entre 25–60 % (ni "nadie miente" ni "todos mienten").

**El primer minuto es su propio criterio.** No alcanza con que el tutorial sea completable: en los primeros ~10 segundos el jugador tiene que **entender qué está pasando** y tener **una recompensa a la vista**, y estar en su primer trade antes del minuto. El funnel de §36 tiene que medir ese tramo con su propio paso, porque es donde se cae la gente que nunca llega a saber si el juego le gusta.
**Resultado jugable:** un juego que desconocidos entienden solos.

---

## Etapa 4 — Beta (4–6 semanas)

**Objetivo:** pulir hasta que dé gusto, balancear con datos y dejar la monetización operativa.
**Dificultad:** media.

| Tarea | Prio |
|---|---|
| La Revelación™: animación y sonido dignos de clip (3 variantes) — prioridad de adquisición | 🟥 |
| Balance final de economía y pistas con datos de alfa | 🟥 |
| Optimización medida: MicroProfiler, memoria en sesiones largas, gama baja real si es posible | 🟥 |
| Catálogo cosmético inicial (2–3 por categoría) + estructura del pase de temporada v1 ligero | 🟨 |
| Bots: +2 personalidades (caótico, honesto) y dificultad adaptativa simple | 🟨 |
| Prueba con 30–50 jugadores (segunda ola de invitados) | 🟥 |
| Accesibilidad: revisar pistas sin dependencia de color, textos, tiempos | 🟨 |

**Criterio de aceptación:** sesión media >10 min; cero errores de consola en 48 h de pruebas; una compra de cada producto verificada en vivo; el juego corre fluido en el peor dispositivo disponible.
**Resultado jugable:** el juego que no te da vergüenza mostrar en TikTok.

---

## Etapa 5 — Lanzamiento (2–3 semanas)

**Objetivo:** salir al público con la mejor primera impresión posible.

| Tarea | Prio |
|---|---|
| Icono y miniatura estilo papel: 2 versiones de cada uno, elegir por opiniones | 🟥 |
| Título de página, descripción con palabras clave del género, traducción EN | 🟥 |
| Cuestionario de madurez + revisión final contra Normas de la Comunidad | 🟥 |
| Publicar público + servidores privados habilitados (gratis) | 🟥 |
| 3–5 clips del momento de revelación para TikTok/Shorts (tu marketing de costo cero) | 🟨 |
| Guardia de lanzamiento: Developer Console + métricas diarias la primera semana | 🟥 |
| 💤 Anuncios pagados de Roblox: solo si las métricas orgánicas de D1 son buenas | 💤 |

**Criterio de aceptación:** juego público, sin errores en la primera semana, con datos de D1 reales en el dashboard.

---

## Etapa 6 — Mantenimiento (permanente, ritmo sostenible)

**Objetivo:** vivir por temporadas sin quemarte.

- Cadencia: temporada nueva cada 6–8 semanas (tema del trend vigente vía `Theme.luau` + 4–6 objetos + misiones). 🟥
- Corrección de bugs semanal; revisión de métricas quincenal contra el plan. 🟥
- Escuchar jugadores con filtro: las sugerencias entran al backlog, no al código. 🟨
- Contenido futuro según la lista ordenada del GDD §40 (Trade-Up Run primero) SOLO si la retención lo justifica. 💤
- Moderación: revisar reportes; vigilar que el chat no derive en toxicidad estructural. 🟥

**Criterio de éxito de largo plazo:** D30 estable o creciente tras dos temporadas. Si tras 3 temporadas la retención no despega, sesión honesta de "persistir, pivotar o siguiente juego" — con todo lo aprendido, el segundo juego se construye en una fracción del tiempo.
