# InkSlot — bootstrap del administrador productivo

**Fecha:** 2026-10-20  
**Estado:** Propuesta aprobada para revisión escrita  
**Alcance:** Provisionar el primer administrador productivo sin cargar datos demo.

## Objetivo

Crear de forma explícita y repetible el único administrador inicial de producción:

- Artista: `Dodogio`
- Usuario de acceso: `dodo`
- Contraseña inicial: `1234`
- Correo interno: `pierorellanao6@gmail.com`

El correo se almacena como identificador único del artista y no se muestra como
credencial de acceso en la interfaz.

## Decisión

Se implementará un comando CLI de provisioning de una sola operación, ejecutado
manualmente contra la base de datos productiva. El comando:

1. Validará que se hayan proporcionado explícitamente las variables del
   administrador.
2. Generará el hash de contraseña con Argon2id.
3. Creará o actualizará únicamente el registro `Artist` correspondiente al
   correo configurado.
4. Dejará el artista activo y conservará `displayName = Dodogio`.
5. No creará clientes, solicitudes, tokens públicos, citas, horarios,
   conexiones de Google Calendar ni datos de demo.
6. No se ejecutará durante `start:prod`, migraciones ni despliegues normales.
7. Rechazará el uso de valores demo implícitos y requerirá una confirmación
   explícita para producción.

No se creará un endpoint HTTP de bootstrap, para evitar agregar una superficie
de ataque al API productivo. Tampoco se usará `npm run db:seed`, porque ese seed
restablece el fixture completo de demo.

## Configuración propuesta

El comando recibirá variables de entorno temporales:

```env
ADMIN_LOGIN_USERNAME=dodo
ADMIN_EMAIL=pierorellanao6@gmail.com
ADMIN_PASSWORD=1234
ADMIN_DISPLAY_NAME=Dodogio
ADMIN_BOOTSTRAP_CONFIRM=CREATE_PRODUCTION_ADMIN
```

Estas variables se configurarán solo para la ejecución del comando y se
eliminarán del entorno de despliegue después de completarlo. No se añadirán
credenciales al repositorio ni al bundle Flutter.

El resolvedor de login dejará de depender de nombres `DEMO_*` para el acceso
administrativo. El seed local conservará su configuración separada y seguirá
siendo exclusivo para desarrollo/QA.

## Seguridad y límites

- El comando no imprimirá la contraseña ni la cadena `DATABASE_URL`.
- La contraseña se almacenará únicamente como hash Argon2id.
- La operación será idempotente para el mismo correo: no duplicará artistas.
- No se eliminarán clientes, solicitudes ni citas existentes.
- No se ejecutará automáticamente en cada deploy.
- La contraseña `1234` se conserva por decisión explícita del producto, aunque
  queda registrada como riesgo operativo para una futura rotación.

## Verificación

Se cubrirá lo siguiente:

- El comando crea un único artista activo con nombre, correo y hash esperados.
- El comando no crea filas en clientes, solicitudes, tokens, citas ni
  configuración de disponibilidad.
- Una segunda ejecución no duplica el artista.
- El login acepta `dodo` y la contraseña configurada.
- Una contraseña incorrecta continúa devolviendo `AUTH_INVALID`.
- `npm run db:seed` no se invoca durante la provisión productiva.

## Fuera de alcance

- Creación de horarios productivos.
- Conexión OAuth con Google Calendar.
- Carga de clientes o solicitudes iniciales.
- Cambio de la contraseña inicial.
- Panel administrativo adicional para gestionar administradores.

## Evidencia esperada

- Pruebas unitarias del bootstrap y resolución de login.
- Verificación contra la base Neon sin datos demo.
- Migraciones previamente aplicadas con `prisma migrate deploy`.
- Commit independiente para el bootstrap productivo y su documentación.
