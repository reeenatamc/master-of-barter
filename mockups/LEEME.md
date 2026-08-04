# Referencias de arte

**Esta carpeta está vacía y hace falta.** Poné acá las imágenes de inspiración: capturas del meme original, paletas, texturas de papel, cualquier cosa que muestre el tono que querés.

Formatos: `.png`, `.jpg`, `.webp`. Los nombres no importan.

## Por qué importa

`Theme.luau` (tarjeta C2) define la piel entera del juego, y `E2` construye la UI contra ella. Hoy la paleta salió de la **descripción escrita** del GDD —§25 "dibujado con marcador en hojas cuadriculadas, botones como recortes pegados con cinta", §28 "colores planos, la imperfección del trazo es estética"— que es material real, pero no es lo mismo que ver lo que vos tenés en la cabeza.

Todo lo que salga de esa descripción está marcado **`[propuesta]`** en `Theme.luau` y en `docs/decisiones.md`. Cuando pongas las imágenes acá, se rederiva la paleta contra ellas.

Lo que **no** cambia cuando lleguen: la estructura del tema (qué claves existe y cómo se leen). Eso es lo que E2 consume, y está hecho para sobrevivir un cambio de paleta.
