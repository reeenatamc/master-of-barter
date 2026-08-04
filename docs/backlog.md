# Backlog Técnico — Master of Barter
**Versión 0.1 — Fase 8 · agosto 2026**

Formato: cada historia es una tarjeta. Copia el bloque completo a Trello/GitHub Projects/Notion (título = línea de la historia; el resto va en la descripción de la tarjeta). Prioridad: P0 = imprescindible MVP · P1 = importante · P2 = opcional · P3 = post-MVP. Complejidad en camisetas: S (una sesión), M (varias sesiones), L (1–2 semanas de ratos).

Orden de trabajo recomendado: sigue las etapas de la Fase 7; dentro de cada etapa, primero las P0 en el orden listado (respetan dependencias).

---

## ÉPICA A — Núcleo del duelo

**A1 · Como jugador quiero armar una oferta de objetos envueltos para iniciar una negociación** — P0 · M
Objetivo: base de toda la mecánica. Criterios: selecciono 1–4 objetos de mi inventario de duelo, marco cuáles ofertar como fake (respetando máx. 2 y costo en Clips), declaro contenido; el servidor rechaza ofertas con objetos que no poseo. Dependencias: C1, D1. Riesgos: replicar por error el flag esFake (revisar §4 de arquitectura). Pruebas: ofertar objetos ajenos/inexistentes desde consola cliente → rechazado y logueado.
> **Nota (Etapa 1):** cobro en Clips diferido a Etapa 2, depende de B2. En el prototipo se aplica el techo de 2 fakes (que es lo que protege el balance) pero no se cobra nada.
> **Nota (Etapa 1):** la dependencia con D1 sobra para el prototipo — A1 y A2 se prueban con dos clientes de Studio. El orden real es el de CLAUDE.md: A1 → A2 → A4 → D1.
>
> **Sub-tareas:** A1.1 duelo mínimo (dos jugadores, copias de duelo, `DuelState` por destinatario) ✅ · A1.2 watchdog de fase + Trove · A1.3 ofertas y validación.
>
> **A1.3 — condición de cierre heredada de A1.2:** test determinista de doble `finish()`: tres caminos (accept / decline / watchdog) hacia `finish()` disparables desde el servidor; nace acá, no antes. En A1.2 la carrera casi no existe (una desconexión cancela el watchdog antes de que dispare), así que el test se escribió recién cuando los caminos que compiten son los definitivos, en vez de escribirlo dos veces.
> Por qué importa más de lo que parece: en cuanto aceptar una oferta cuelgue el guardado del perfil del fin del duelo (Etapa 2, pero el camino se abre acá), la guarda de idempotencia deja de ser defensiva y pasa a ser **lo único que impide un doble guardado**. No es una optimización, es la red.
>
> **A1.2 — condición de cierre, no negociable:** el Trove nace en **la misma tarjeta** que el watchdog, no después. En el momento en que exista el primer `task.delay`/timer de deadline, ya tiene que estar registrado en el Trove del duelo. No puede haber ni una fase intermedia con un timer sin su limpieza.
> Test obligatorio de A1.2: un cliente cierra su ventana a mitad de `BuildingOffers` → el duelo no queda colgado y no sobrevive ningún timer. Es el primer test de desconexión real del proyecto; conviene descubrir ahí que el embudo y la limpieza aguantan, con un duelo vacío, y no en Etapa 2 con datos de por medio.

**A2 · Como jugador quiero negociar con Aceptar / Rechazar / Pedir más** — P0 · M
Objetivo: el loop del meme. Criterios: turnos alternos validados en servidor; Pedir más obliga al rival a añadir/mejorar y tiene límite 3 por lado; Rechazar termina sin transferencias; timeouts por fase con resultado definido. Dependencias: A1. Pruebas: pulsar fuera de turno, spamear botones, dejar expirar cada timeout.

**A3 · Como jugador quiero una revelación dramática al aceptarse un trade** — P0 · M (v1 simple) / L (versión final Etapa 4)
Objetivo: el momento estrella y clipeable. Criterios: al aceptar, se desenvuelve todo con animación+sonido; transferencias y Clips aplicados atómicamente en servidor; ambos ven el mismo resultado. Dependencias: A2, C2. Pruebas: desconexión exactamente durante la revelación → estado consistente al reconectar.

**A4 · Como jugador quiero una ficha ¡ES FAKE! única por duelo** — P0 · S
Criterios: usable una vez, solo en fase de negociación; acierto → me llevo la oferta rival; fallo → pierdo mi apuesta; queda registrada en analítica. Dependencias: A2. Riesgo: es la mecánica 🧪 más incierta — instrumentarla bien para decidir su futuro con datos.

**A5 · Como jugador quiero que las desconexiones no me perjudiquen injustamente** — P0 · M
Criterios: quien se desconecta pierde el duelo y su apuesta pasa al rival; el que queda vuelve al lobby limpio; el Trove del duelo libera todo (verificar sin fugas tras 100 duelos bot-vs-bot). Dependencias: A2, E2.

**A6 · Como jugador quiero inspeccionar objetos envueltos y notar imperfecciones** — P0 · M
Criterios: zoom táctil/click; 3 tipos de imperfección (tono, costura, errata) precalculados por servidor; nunca detectables solo por color. Dependencias: A1, D2. Pruebas: verificación con simulación de daltonismo.

**A7 · Como jugador quiero emotes para la guerra psicológica** — P1 · S
Criterios: 6 emotes prediseñados, visibles por el rival, con cooldown anti-spam.

---

## ÉPICA B — Datos y economía

**B1 · Como jugadora quiero que mi progreso se guarde de forma segura** — P0 · M
Objetivo: cimiento de confianza. Criterios: ProfileStore con plantilla completa (§7 arquitectura); cierre abrupto de Studio no pierde datos; perfil bloqueado por otra sesión → modo espectador con reintento, jamás datos por defecto. Dependencias: ninguna (primera historia técnica de Etapa 2). Pruebas: cerrar proceso a mitad de duelo; entrar con la misma cuenta desde dos clientes.

**B2 · Como jugador quiero ganar y gastar Clips** — P0 · M
Criterios: toda mutación pasa por EconomyService; recompensas de duelo desde Config; imposible quedar en negativo; log de cada transacción. Dependencias: B1. Pruebas: compra con saldo insuficiente vía remoto manipulado → rechazada.

**B3 · Como jugador quiero una colección permanente intocable y copias de duelo apostables** — P0 · M
Criterios: la colección nunca decrece por duelos; las copias se compran con Clips y son lo único transferible en la mesa. Dependencias: B1, B2. Riesgo: es la decisión 🧪 del GDD §21 — mantener la frontera clarísima en la UI.

**B4 · Como jugador quiero comprar squishies y copias en el kiosco** — P0 · M
Criterios: catálogo desde Config; compra validada y reflejada al instante; precios nunca leídos del cliente. Dependencias: B2, B3.

**B5 · Como jugadora quiero vender game passes y productos sin riesgo de fraude** — P1 · M
Criterios: ProcessReceipt idempotente (tabla Recibos); pass detectado al entrar; compra caída no cobra sin entregar. Dependencias: B1. Pruebas: simular recibo duplicado.

---

## ÉPICA C — Configuración y contenido

**C1 · Catálogo de squishies en Config con rarezas y valores** — P0 · S (estructura) + M (15 ítems con arte)
Criterios: añadir un squishy = añadir una entrada, cero código nuevo. Dependencias: ninguna.

**C2 · Sistema de temas (Theme.luau) con el tema Papelito v1** — P0 · M
Objetivo: el seguro anti-caducidad del meme. Criterios: todo asset visual/sonoro del sabor papel se resuelve vía tema activo; probar creando un mini-tema alternativo de 3 assets y alternándolo. Dependencias: ninguna. Riesgo: disciplina — un solo asset hardcodeado rompe la promesa.

**C3 · Economía balanceable desde Config** — P0 · S
Criterios: costos de fakes, recompensas, precios y límites en un módulo; cambiar un número no requiere tocar servicios.

---

## ÉPICA D — Bots y matchmaking

**D1 · Como jugador quiero encontrar rival rápido aunque el servidor esté vacío** — P0 · M
Objetivo: matar el arranque en frío. Criterios: cola en servidor; si no hay rival en N segundos entra un bot con nombre/avatar plausible; el jugador no recibe señales obvias de que es bot. Dependencias: A2, E1.

**D2 · Como jugadora quiero bots con personalidades que bluffean creíblemente** — P0 · M (2 personalidades) + P1 · M (2 más + adaptativo)
Criterios: agresivo y tímido difieren medible en ratio de fakes, uso de Pedir más y tiempos de respuesta con jitter humano. Dependencias: D1. Pruebas: 200 duelos bot-vs-bot sin errores ni estados colgados (sirve también como test de estrés del núcleo).

---

## ÉPICA E — Lobby, UI y sonido

**E1 · Lobby "El Patio de Trades" con mesas, kiosco y flujo de cola** — P0 · M
Criterios: caminar, unirse a cola desde una mesa, volver del duelo al mismo punto.

**E2 · UI de duelo estilo papel usable en móvil** — P0 · L
Criterios: 3 botones grandes, oferta legible, inspección cómoda con dedo; aprobada en emulador (teléfono chico y tablet) antes de cerrarse. Dependencias: C2. Riesgo: es la superficie de mayor esfuerzo del MVP — dividir en sub-tarjetas por pantalla.

**E3 · HUD, kiosco y vitrina** — P0 (HUD, kiosco) / P2 (vitrina) · M
Criterios: Clips y colección siempre coherentes con servidor; vitrina filtra textos con TextService.

**E4 · Sonido base del tema papel** — P1 · S
Criterios: banco desde Theme; papel, cinta, revelación, victoria/derrota; volúmenes en Config.

---

## ÉPICA F — Onboarding, misiones y analítica

**F1 · Tutorial con Don Trueque** — P0 · M
Criterios: duelo guiado, primer squishy regalado, un fake obvio didáctico; completable en <4 min; saltable para cuentas con progreso. Dependencias: núcleo A completo. Pruebas: persona real sin ayuda verbal.

**F2 · Misiones diarias** — P1 · M
Criterios: 3 diarias desde Config, progreso persistente, reseteo diario correcto en zonas horarias distintas.

**F3 · Analítica de decisiones** — P0 · M
Objetivo: el balance del bluff se decide con datos. Criterios: funnel de onboarding paso a paso; evento por duelo con duración, resultado, nº Pedir más, fakes ofertados, acusaciones y acierto; evento por compra. Dependencias: A2–A4. Riesgo: instrumentar tarde = alfa a ciegas — va junto al núcleo, no después.

---

## ÉPICA G — Lanzamiento y operaciones

**G1 · Página del juego: icono, miniatura, título, descripción (ES/EN)** — P0 · M
Criterios: 2 versiones de icono y miniatura evaluadas con opiniones; descripción con términos de búsqueda del género.

**G2 · Checklist de release ejecutable** — P0 · S
Criterios: documento con los pasos de §11–12 de la arquitectura (móvil, red lenta, consola limpia, guardado, compras) que se ejecuta completo antes de CADA publicación.

**G3 · Clips de la revelación para TikTok/Shorts** — P1 · S
Criterios: 3–5 clips de <20 s capturados de partidas reales; publicados el día del lanzamiento.

**G4 · Pipeline de temporadas** — P3 · M
Criterios: checklist para lanzar una temporada (tema + squishies + misiones) en <2 semanas de ratos; se construye tras el lanzamiento, cuando la retención lo justifique.

---

## Fuera del backlog (recordatorio de disciplina)
Trade-Up Run · mesas 4–6 · espectadores · torneos · trading libre entre jugadores · moneda dura · rankings globales. Viven en el GDD §40. Cada vez que tientes con una, pregunta: ¿qué P0 estoy retrasando a cambio?
