# Documentación

Master of Barter: negociación y bluff 1v1 con estética de papel dibujado a mano.
Dos jugadores ofrecen objetos envueltos —reales o falsificados—, negocian con
tres botones, y una única ficha por duelo permite acusar «¡ES FAKE!».

Esta es la puerta de entrada. Ante cualquier duda de diseño, la respuesta está
en alguno de estos documentos: si no está acá, todavía no está decidido.

## Por dónde empezar

| Documento | Qué contesta |
|---|---|
| [Game Design Document](./gdd) | Qué es el juego. Las 39 secciones de diseño, del bucle principal a la seguridad. |
| [Arquitectura técnica](./arquitectura) | Cómo está construido: servicios, máquina de estados del duelo, flujo de remotos, datos. |
| [Plan por etapas](./plan-etapas) | En qué orden se construye, de la preparación al mantenimiento. |
| [Backlog técnico](./backlog) | Las tarjetas concretas, por épica, con lo que falta verificar. |

## Sesiones de prueba

| Documento | Cuándo se usa |
|---|---|
| [Prueba de Etapa 1](./prueba-etapa1) | Punto de control tras A4: el duelo completo, de punta a punta. |
| [Prueba de diversión](./prueba-diversion) | Con personas reales, para responder si negociar con fakes es divertido. |

## Dos secciones que son ley

- **§39 del GDD** — seguridad. `isFake` nunca se replica al rival.
- **§4 de la arquitectura** — separación cliente/servidor. El servidor es la
  única autoridad; el cliente pide, nunca dicta.

## Referencia de la API

La sección **API** se genera sola a partir de los comentarios `---` del código
en `src/`, así que no puede desincronizarse: si una firma cambia, la
documentación cambia con ella en la próxima corrida de `./docs.sh`.

Por ahora cubre `src/shared/Util` (`Trove` y `Net`). El resto de los módulos se
suman a medida que reciban su bloque `@class`; la lista vive en `CODE_PATHS`,
arriba de todo en `docs.sh`.
