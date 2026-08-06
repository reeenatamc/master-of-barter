---
sidebar_label: Checkpoint 3 · persistencia
---

# Checkpoint 3 — persistencia (B1)

> **⭐ No corras este documento suelto.** Está encadenado con los otros cuatro en **[`sesion-unica.md`](sesion-unica)**, que los ordena por fricción. Esto queda como el detalle.

**Este no se agrupa y no se difiere.** Es la regla que ya fijamos: los datos que se guardan no se auto-certifican. Un duelo roto se ve en un segundo; un guardado roto se ve la semana que viene, cuando a alguien le falta la colección.

**Tiempo: 25 minutos.** Cinco pruebas, en orden. La quinta es la que más importa: apostar objetos de verdad y cortar la conexión a mitad.

---

## Antes de empezar

`rojo serve` corriendo y el plugin conectado. Nada más.

**No hace falta publicar el lugar** para las tres primeras pruebas: en Studio, `DataService` habla con el DataStore simulado que trae ProfileStore. Eso hace que las pruebas no toquen datos reales y que igual se verifique el session locking, que es la parte interesante.

La cuarta prueba **sí** necesita el DataStore de verdad, y por eso va al final.

---

## Prueba 1 — el perfil carga

1. **Play** (un jugador).
2. Command Bar, contexto **Server**:

```lua
print(require(game.ServerScriptService.Services.DataService).get(game.Players:GetPlayers()[1]))
```

Tiene que imprimir una tabla, no `nil`. Si imprime `nil`, el perfil no cargó y el resto de las pruebas no significan nada.

---

## Prueba 2 — cierre abrupto sin pérdida

> **⚠️ ESTA PRUEBA NO FUNCIONA CON EL SIMULADOR, y el documento decía lo contrario.** El mock de ProfileStore guarda en una tabla común de módulo (`local MockStore = {}`); al apretar **Stop**, Studio recarga los scripts y esa tabla vuelve a cero. Con `useMockInStudio = true` esto **siempre** muestra el valor inicial, ande o no ande el guardado — un falso fallo garantizado.
>
> **Es la misma prueba que la 4**, que sí apaga el simulador. Correr las dos era correr una que no puede pasar y después la de verdad. Ver `sesion-unica.md`, donde quedaron unificadas.

Esta es la que importa más. Prueba que lo que ganaste sigue ahí después de un cierre feo.

1. **Play**. En la Command Bar, contexto **Server**, escribí algo en el perfil:

```lua
require(game.ServerScriptService.Services.DataService).get(game.Players:GetPlayers()[1]).clips = 9999
```

2. **Stop** con el cuadrado rojo. Sin avisar, sin esperar.
3. **Play** de nuevo.
4. Volvé a imprimir el perfil como en la prueba 1.

**Tiene que decir `clips = 9999`.** Si dice 250 —el valor inicial— el guardado no ocurrió y **ahí paramos todo**: es exactamente el fallo silencioso que este checkpoint existe para atrapar.

---

## Prueba 3 — dos sesiones peleando por un perfil

Prueba el session locking: que dos servidores no puedan escribir el mismo perfil a la vez.

1. Test → **2** jugadores → **Start**.
2. En el Output del **servidor**, buscá si alguno quedó como espectador:

```
[DataService] PlayerN has no profile; spectator mode
```

Con dos jugadores distintos (Player1 y Player2 tienen ids distintos), **no debería aparecer**: son dos perfiles, no uno.

3. Ahora el caso real: cerrá una ventana y volvé a entrar rápido con el mismo jugador. El perfil viejo puede tardar en soltarse. Si aparece el mensaje de espectador, **eso está bien** — es el lock haciendo su trabajo. Lo que está mal sería que entrara con un perfil vacío.

**Qué mirar:** que un jugador sin perfil quede como espectador **con aviso**, y nunca con datos por defecto.

---

## Prueba 4 — contra el DataStore de verdad

Las tres anteriores usan el simulador. Un simulador que se porta bien no prueba que un DataStore se porte bien.

**Esta prueba tiene preparación, y es donde la gente pierde la tarde.** Hacela completa antes de tocar Play, para que tu sentada sean 20 minutos de probar y no 20 de configurar.

### Preparación (una sola vez)

**1. El lugar tiene que estar publicado.** Sin publicar, no existe ningún DataStore al que hablarle.

> **File → Publish to Roblox** (o *Publish to Roblox As…* si nunca lo publicaste). Si ya lo hiciste antes, este paso ya está.

**2. Activar el acceso a API desde Studio.** Por defecto viene **apagado**, y es lo que más muerde.

> Pestaña **Home** → **Game Settings** → sección **Security** → prendé **Enable Studio Access to API Services** → **Save**.
>
> Si no ves *Game Settings* en Home, está también en el menú de arriba: **File → Game Settings**.

**3. Apagar el simulador.** `src/shared/Config/DataConfig.luau` → `useMockInStudio = false`. Rojo lo sincroniza solo.

### La prueba

Repetí la **prueba 2** completa: escribís `clips = 9999`, Stop de golpe, Play, y leés.

Si sigue diciendo 9999, **la persistencia está probada de verdad**.

### Cómo distinguir "falta un permiso" de "está roto"

Los dos fallos se ven igual a primera vista: el jugador queda como espectador. Por eso el mensaje del servidor ahora dice **por qué**:

```
[DataService] Player1 has no profile; spectator mode. DataStore access: NoAccess.
```

| Si dice | Significa | Qué hacer |
|---|---|---|
| `NoAccess` | El acceso a API está apagado, o el lugar no está publicado | Volvé al paso 1 y 2 de preparación. **No es un bug.** |
| `NotReady` | Todavía está averiguando. Esperá unos segundos y reintentá | Nada, dale tiempo |
| `Access` | El DataStore responde bien | Entonces el perfil **sí** está bloqueado por otra sesión, o hay algo roto de verdad. Mandámelo |

Sin esa línea, un checkbox apagado y un bug de guardado producen exactamente el mismo síntoma.

### Al terminar

**Volvé `useMockInStudio` a `true`.** Si no, todas las pruebas de todos los días pasan a escribir en los datos reales de tu juego.

---

## Prueba 5 — desconexión con copias reales en juego

**Esta es la que B3 agrega, y es la más importante de las cinco.** Prueba que apostar objetos de verdad no pierde ni duplica nada cuando alguien se va a mitad.

1. Test → **2** jugadores → **Start**.
2. En la Command Bar, contexto **Server**, anotá qué tiene cada uno:

```lua
local D = require(game.ServerScriptService.Services.DataService)
for _, p in game.Players:GetPlayers() do print(p.Name, D.get(p).duelCopies) end
```

Los dos arrancan con las mismas cuatro copias iniciales.

3. En **un** cliente, armá una oferta con **objetos reales** (botón *Real*, no *Falso*) y **OFERTAR**.
4. Imprimí de nuevo. **Al que ofertó le faltan esas copias** — salieron del perfil al ofertar, no al resolver. Eso es el escrow.
5. **Cerrá esa ventana** (la X, no Stop) a mitad del duelo.
6. Imprimí el perfil del que **quedó**.

**Qué tiene que pasar:** el que se quedó **recibió** las copias apostadas por el que se fue.

**Los dos fallos que esta prueba busca:**

| Si ves | Es | Gravedad |
|---|---|---|
| El que se quedó **no recibió nada** | **Pérdida** | Malo. Alguien perdió lo suyo |
| El que se fue **conserva** las copias que apostó | **Duplicación** | Peor. Eso infla la economía de todos, para siempre |

7. Volvé a entrar con el jugador que se fue y revisá su perfil. **No puede tener de vuelta lo que apostó.**

Y una que no cuesta nada mirar: **la colección de los dos tiene que estar igual que al empezar**. Un duelo mueve copias, nunca colección (§21). Si la colección cambió, eso es un fallo del pilar anti-frustración del juego.

---

## Lo que este checkpoint NO prueba

**Que la colección se llene.** Los duelos mueven **copias**, nunca colección — a propósito (§21). Qué te gana un lugar en la colección permanente es otra pregunta, y B3 no la contesta.

**Las migraciones.** La cadena existe y funciona, pero está vacía: la versión 1 es la primera, así que no hay de dónde migrar. Se prueba cuando exista una versión 2.

---

## Si algo falla

**Parás.** Esta es la única prueba del proyecto donde seguir adelante con un fallo es peor que no haber probado: un guardado que falla a veces es indistinguible de uno que anda, hasta que no lo es.

Mandame el Output completo y qué prueba falló.
