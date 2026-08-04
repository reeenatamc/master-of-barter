---
sidebar_label: Game Design Document
---

# Game Design Document — Master of Barter
**Versión 0.1 — documento vivo, agosto 2026**
Convención: 🔒 = decidido · 🧪 = a validar en pruebas · 💤 = pospuesto post-MVP

---

## Concepto

### 1. Nombre provisional
**Master of Barter** 🔒 (revisar disponibilidad y variantes cortas antes del lanzamiento; el título de la página puede llevar coletilla descriptiva tipo "Master of Barter 🤝 [Trade & Bluff]").

### 2. Resumen del juego
Juego de negociación y bluff 1v1 con estética de papelito dibujado a mano, inspirado en el trend viral de tradear objetos absurdos. Ofreces objetos envueltos declarando qué son — pueden ser reales o falsificaciones. El rival negocia con tres botones (Aceptar / Rechazar / Pedir más) y usa pistas visuales y la conversación para descubrir tus mentiras. Bluffear con tu objeto real significa arriesgarlo de verdad. Ganar duelos alimenta tu colección permanente de objetos absurdos coleccionables (los squishies son parte del set, no el set entero).

### 3. Género
Juego de mesa social / bluff / negociación, con capa de colección.

### 4. Público objetivo
General (13+ de facto por la naturaleza social). Núcleo esperado: 10–20 años, consumidores del humor absurdo tipo brainrot y de contenido de trades en TikTok/YouTube. El humor y las partidas cortas lo hacen apto para "cualquiera que quiera reírse" (visión original).

### 5. Plataformas
Móvil primero 🔒 (la UI de tres botones grandes es nativamente táctil), PC segundo, consola compatible sin esfuerzo extra (navegación de UI con gamepad 🧪).

### 6. Fantasía principal del jugador
"Soy un estafador encantador / un detector de mentiras infalible." Ganar engañando con estilo, o cazar al mentiroso en el momento exacto.

## Jugabilidad

### 7. Bucle principal (2–3 min)
1. Entrar a cola → emparejado con jugador (o bot disfrazado si no hay nadie).
2. Ambos arman oferta inicial: objetos envueltos + declaración.
3. Rondas de negociación (máx. 3 "Pedir más" por lado 🧪).
4. Resolución: Aceptar (revelación dramática), Rechazar, o ficha ¡ES FAKE! (una por duelo 🧪).
5. Recompensas en moneda + progreso de misiones.
6. "Otra partida" a un botón de distancia.

### 8. Mecánicas principales
- **Ofertar:** eliges objetos de tu inventario de duelo, decides cuáles envolver como reales y cuáles como fakes, declaras su contenido.
- **Negociar:** Aceptar / Rechazar / Pedir más. "Pedir más" obliga al rival a añadir o mejorar la oferta.
- **Fabricar fakes:** cuestan moneda del juego, proporcional al valor del objeto imitado. Máximo 2 fakes por duelo 🔒 (techo anti-pay-to-win).
- **Detectar:** inspeccionar objetos envueltos (zoom); los fakes tienen imperfecciones sutiles (2–3 tipos en el MVP: tono de color desviado, costura irregular, etiqueta con errata 🧪). La conducta negociadora del rival es pista adicional.
- **Acusar:** ficha única ¡ES FAKE! por duelo. Acierto → te llevas la oferta del tramposo. Fallo → pierdes tu apuesta. 🧪 (si en pruebas el meta "fakear siempre" no aparece, simplificar o eliminar).
  > **Por qué esta mecánica es 🧪 y no 🔒 — contexto de diseño.** Al revisar los videos del meme original, la diversión núcleo no está en descubrir una falsificación: está en la **actuación de venta**, en el sobrehype de "es raro, es limitado, no lo consigues en ningún lado". Eso ya lo cubren la declaración (`claim`), Pedir más y los emotes: se puede mentir descaradamente sobre el VALOR de algo auténtico sin que exista ninguna falsificación.
  > El objeto físicamente falso y la ficha para acusarlo son **nuestra capa inventada encima** del meme, no algo que el meme ya demostrara divertido. Puede que multiplique la tensión o puede que agregue reglas a algo que funcionaba sin ellas. Esa pregunta no se resuelve discutiendo: se resuelve viendo a personas jugar las dos versiones. Ver el protocolo del experimento en `plan-etapas.md`, Etapa 1.
- **Riesgo del real:** ofrecer tu objeto valioso auténtico es la forma más creíble de bluffear… y puedes perderlo en ese duelo.

### 9. Mecánicas secundarias
Misiones diarias (jugar X duelos, ganar con un fake, cazar un fake) · rachas de victorias con multiplicador de moneda · historial de duelos · 💤 modo Trade-Up Run · 💤 mesas de 4–6 jugadores · 💤 torneos.

### 10. Controles
Táctil/click puro: tres botones grandes de negociación, tap para inspeccionar, drag para armar oferta. Sin movimiento de personaje durante el duelo. Gamepad: navegación por foco de UI.

### 11. Cámara
**Escena canónica del duelo 🔒:** los dos avatares parados **frente a frente**, con la tabla de papel **en medio de ambos**, y la cámara lateral/cenital sobre la mesa — el encuadre del meme original.

Dos razones, y ninguna es estética: **(1)** reconocimiento instantáneo — una miniatura o un clip de TikTok con ese encuadre se lee como "esto es aquello" sin leer una palabra; **(2)** ver al rival es **mecánico**, no decorativo: su avatar y sus emotes son parte de la información con la que decides si te está mintiendo, igual que las pistas visuales del envoltorio.

En el lobby, cámara estándar de tercera persona.

### 12. Sistema de movimiento
Estándar de Roblox solo en el lobby (caminar entre mesas, vitrina, tienda). Cero plataformeo, cero parkour.

## Mundo y contenido

### 13. Mundo o mapas
Un único lobby pequeño: "El Patio de Trades" — ambientación de recreo/patio escolar de papel y cartón. Mesas de duelo alrededor, tienda-kiosco, muro de vitrinas. MVP: un solo mapa 🔒.

Cada mesa de duelo se construye para la escena canónica de §11: dos posiciones enfrentadas con la tabla en medio, no dos jugadores mirando cada uno su propia pantalla.

### 14. Personajes
Avatares estándar de Roblox (los jugadores conservan su identidad, importante para lo social). Accesorios cosméticos propios del juego encima. Sin personajes jugables custom en el MVP.

### 15. NPC
- **Bots de duelo** (crítico — mitigación del arranque en frío): rivales bluffeadores con 3–4 personalidades (agresivo, tímido, caótico, honesto) que llenan la cola cuando no hay jugadores. Deben resultar naturales; nombre y avatar plausibles. 🧪 calibrar dificultad.
- **NPC de tutorial:** "Don Trueque", vendedor del kiosco, enseña el primer duelo guiado.

### 16. Enemigos
No aplica en sentido clásico. El "enemigo" es el rival humano o bot.

### 17. Misiones
Diarias (3/día, moneda) y semanales (1, recompensa mayor). Diseñadas para empujar comportamientos variados: no solo ganar, también acusar bien, negociar largo, usar objetos de cierta rareza. 💤 misiones narrativas.

## Progresión y economía

### 18. Sistema de progresión
- **Nivel de tramposo (XP por duelo):** desbloquea mesas de mayor valor de apuesta y ranuras de vitrina.
- **Colección:** obtener los 12–15 objetos del set base (3 rarezas: común/raro/legendario). Completar sets da títulos y marcos.
- **Maestría de detección** 💤: estadísticas visibles de aciertos como cazador de fakes.

### 19. Economía
Moneda blanda única: **Clips** 📎 (guiño al clip rojo). Fuentes: duelos (ganar > perder, pero perder da algo), misiones, rachas. Sumideros: fabricar fakes, comprar objetos/cajas del kiosco, reintentos de misión. Regla de oro: el sumidero de fakes escala con el valor imitado para que mentir caro cueste caro. Toda la economía en un módulo de configuración central para poder balancear sin tocar código. 🧪 valores iniciales a calibrar en alfa.

### 20. Monedas
Solo Clips en el MVP 🔒. 💤 posible moneda dura cosmética ("Estrellitas Doradas") si el catálogo cosmético crece; evitar doble moneda al inicio (complejidad y percepción de casino).

### 21. Inventario
- **Colección permanente:** objetos obtenidos; nunca se pierden 🔒 (pilar anti-frustración).
- **Inventario de duelo:** al iniciar un duelo eliges qué objetos "llevar a la mesa"; lo apostado en el duelo sí puede perderse… 🧪 DECISIÓN ABIERTA CLAVE: opción A) se pierde la *copia* apostada (las copias de duelo se compran con Clips, la colección es intocable) vs opción B) se pierde el objeto real con seguro pagable. La opción A es más segura para retención; prototipar A primero.

### 22. Objetos
Set base: 12–15 **objetos coleccionables absurdos** con nombre, personalidad visual y rareza. Cada uno tiene versión real y plantilla de fake (con sus imperfecciones). Diseño de arte: dibujado a mano, colores planos, ojos expresivos — deben ser *deseables y memeables* por sí mismos.

**El tono es brainrot; el panteón es propio 🔒.** El humor apunta al absurdo cotidiano elevado a reliquia: *Sopa Maruchan Dorada*, *Control Remoto de la Abuela*, *Piedra que Parece Papa*. Los squishies siguen siendo parte del set, no el set entero.

**Nunca personajes brainrot existentes** (Tralalero Tralala, Tung Tung Sahur y compañía) 🔒. Tres motivos: son IP y meme de otros, exponen el juego a moderación y a reclamos, y convierten el juego en un clon de algo en vez de una cosa propia. Se toma el registro de humor, no los personajes.

> **Nota de arquitectura:** este cambio **no requiere tocar código**. `Items.luau` es catálogo puro (id, rareza, valor) y los nombres visibles ya viven en `Strings.luau`; el aspecto se resuelve por `Theme.luau`. Los 6 ítems de prueba actuales se quedan como están: el catálogo real se renombra cuando toque contenido (Etapa 2/3), y para entonces será editar entradas de config, no lógica.

### 23. Recompensas
Fin de duelo: Clips + XP + (si ganaste la apuesta) los objetos de la mesa. Revelaciones dramáticas siempre: la recompensa emocional es tan importante como la numérica. Racha de días con login: pequeña, sin FOMO agresivo.

### 24. Personalización
Cosméticos: skins de objetos, envoltorios, mesas, emotes/taunts, efectos de revelación, marcos de vitrina. Visibles para el rival durante el duelo (motor de deseo). MVP: 2–3 ítems por categoría para probar el pipeline 🔒; catálogo real post-lanzamiento.

## Presentación

### 25. Interfaz
Estética papel: todo parece dibujado con marcador en hojas cuadriculadas, botones como recortes pegados con cinta. UDim2 por escala + UIAspectRatioConstraint; probada en emulador desde el primer día. Los tres botones de negociación son EL ícono visual del juego — grandes, torpes, adorables.

### 26. Sonido
Foley casero intencional: papel arrugándose, cinta adhesiva, marcador escribiendo, "¡ohhh!" de niños en la revelación. Fuente: librería con licencia de Roblox + grabaciones propias.

### 27. Música
Lo-fi juguetón de fondo en lobby; en duelo, tensión creciente por ronda de negociación (capas que se suman). Librería con licencia de Roblox; nada con copyright externo 🔒.

### 28. Estilo artístico
Papel/dibujado a mano (fiel al meme) 🔒. Ventaja estratégica: es mayormente 2D/UI — poco modelado 3D, rinde perfecto en gama baja, y una desarrolladora sola puede producirlo. La imperfección del trazo es estética, no defecto.

### 29. Animaciones
Pocas y jugosas: desenvolver (la estrella del juego — merece 3 variantes), poner objeto en mesa, estampar el sello de ¡ES FAKE!, celebración/derrota. Animación de UI con TweenService; animación de personaje mínima.

## Jugadores y negocio

### 30. Experiencia de incorporación
Primer ingreso → duelo guiado contra Don Trueque (bot tutorial) que te deja ganar tu primer objeto y te mete un fake obvio para enseñar la inspección. Meta: primer duelo real antes del minuto 4. 🧪 medir con funnel de Analytics dónde se cae la gente.

### 31. Sistemas sociales
Chat de texto (filtro nativo de Roblox) + emotes prediseñados como canal principal de la guerra psicológica (más seguro y más divertido que texto libre). Vitrina pública en el lobby. 💤 amigos/revanchas, espectadores de duelo, clips compartibles.

### 32. Multijugador
Duelos 1v1 emparejados dentro del servidor (servidores de ~20 jugadores; lobby compartido, duelos en instancias/mesas). Sin matchmaking global en MVP 🔒 — cola simple dentro del servidor + bots de relleno. Desconexión a mitad de duelo = derrota del que se fue, apuesta para el que se quedó.

### 33. Retención
D1: onboarding rápido + primer objeto regalado. D7: misiones + colección incompleta + rachas. D30: temporadas con objetos nuevos cada 6–8 semanas 🔒 (compromiso de contenido), con drops quincenales dentro de cada temporada — ver §40. Métricas objetivo iniciales (hipótesis 🧪): D1 > 20 %, sesión media > 12 min.

**Benchmarks de referencia** (para leer los datos de alfa sin inventar el listón): D1 **20 % bueno / 30 % notable / 40 %+ excelente** · D7 **8 % bueno** · D30 **3 % bueno**. La meta propia sigue siendo D1 > 20 %; estos números sirven para saber si 22 % es un éxito discreto o una señal de alarma.

### 34. Monetización
**Modelo: F2P + cosméticos + pase de temporada + conveniencia con techo.**
1. **Cosméticos** (game passes y productos): skins, envoltorios, mesas, emotes, efectos de revelación. La revelación es el escaparate: el momento más mirado del juego exhibe lo comprado.
2. **Pase de temporada** (por temporada de 6–8 semanas): vía premium de recompensas cosméticas.
3. **Clips por Robux** (developer product) — permitido SOLO porque el techo de 2 fakes/duelo impide comprar ventaja 🔒. Si el techo cambia, esta venta se revisa.
4. **Premium Payouts** (pasivo, por engagement de suscriptores Premium).
Prohibido 🔒: vender fakes o ventaja de duelo por Robux; loot con odds ocultas de valor real; presión FOMO agresiva. Nada de monetización activa hasta la beta — primero retención.

## Operación y calidad

### 35. Moderación
Filtro de chat nativo obligatorio; emotes como canal social principal; botón de reporte estándar de Roblox; nombres de vitrina pasan por TextService. Cuestionario de madurez completado con honestidad (el juego no contiene apuestas de valor real: las apuestas son de objetos del juego con resolución por habilidad/información, no por azar puro — mantener esto así también por diseño 🔒).

### 36. Analítica
Roblox Analytics + eventos personalizados desde el MVP: funnel de onboarding, duelos por sesión, ratio fake/real por oferta, aciertos de acusación, uso de Pedir más, abandono a mitad de duelo, conversión del kiosco. El balance del bluff se ajusta con estos datos, no con opiniones.

### 37. Accesibilidad
Pistas de fakes nunca solo por color (patrón + forma + texto) para daltonismo 🔒; textos escalables; sin dependencias de audio para jugar; tiempos de decisión generosos y configurables 🧪.

### 38. Rendimiento
Presupuesto: fluido en Android de gama baja. Ventajas de partida: juego UI-first, un solo mapa pequeño, sin física intensiva. Reglas: atlas de imágenes, pocas partículas simultáneas, StreamingEnabled activado, medir con MicroProfiler antes de cada release.

### 39. Seguridad
- El servidor es la única autoridad del estado del duelo 🔒.
- El cliente rival NUNCA recibe si un objeto envuelto es real o fake antes de la revelación — el dato vive solo en servidor 🔒 (condiciona la arquitectura: el "envoltorio" replicado es un objeto neutro).
- Todos los botones son solicitudes; el servidor valida turno, legalidad y tiempos.
- Rate limiting por jugador en todos los remotos; Clips y colección solo se modifican en servidor; guardado con ProfileStore (session locking).
- ProcessReceipt idempotente para toda compra.

## Después del MVP

### 40. Contenido futuro
Orden tentativo post-lanzamiento: 1) temporada 2 de objetos + catálogo cosmético real → 2) modo Trade-Up Run → 3) mesas de 4–6 → 4) espectadores + clips → 5) torneos/eventos → 6) colaboraciones de sets temáticos. Cada adición se justifica con datos de retención, no por acumular features.

**Cadencia de drops:** las temporadas siguen siendo de 6–8 semanas, pero **dentro** de cada una los objetos nuevos pueden salir cada dos semanas. Es barato porque un objeto nuevo es una entrada en `Items.luau` más su nombre en `Strings.luau` — config, no sistemas. Sigue aplicando la regla de §34: sin presión FOMO agresiva; un drop es "hay algo nuevo", no "esto desaparece mañana".

---

*Próximo documento: Fase 6 — Arquitectura técnica.*
