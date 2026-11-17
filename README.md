# Gestión municipal: usuarios y proveedores + equipos municipales

Este proyecto es el sistema separado por módulos. Por ahora trae dos
módulos: **usuarios y proveedores** y **equipos municipales** (con los
switches y sus puertos). Los demás módulos (análisis de logs, correo
institucional y licencias) se van a ir uniendo después, uno por uno.

| Parte        | Contenido |
|--------------|-----------|
| `apps/core`         | Conexión a los procedimientos, inicio de sesión, permisos, archivos y búsqueda por cédula |
| `apps/usuarios`     | Usuarios con sus teléfonos, correos, páginas web y claves |
| `apps/proveedores`  | Proveedores con sus contactos, imagen y catálogo de servicios |
| `apps/catalogos`    | Roles, departamentos, tipos de identificación, teléfono y correo, categorías de proveedores |
| `apps/geografia`    | Países, provincias, cantones y distritos |
| `apps/auditoria`    | Historial de cambios e inicios de sesión |
| `apps/dispositivos` | Equipos municipales: equipos con IP, MAC, líneas, IMEI y documentos; switches y puertos; edificios, marcas, modelos y catálogos de equipos |
| `frontend`          | La página web (se abre en `/app/`) |
| `sql`               | Scripts de la base de datos de los dos módulos |

## Módulos

| Módulo | Estado | Rama de Git |
|--------|--------|-------------|
| 1. Usuarios y proveedores | incluido | `modular` |
| 2. Equipos municipales y switches | incluido | `modulo-equipos`, unida a `modular` |
| 3. Análisis de logs | pendiente | |
| 4. Correo institucional | pendiente | |
| 5. Licencias y reportes | pendiente | |

Al entrar, la página muestra el menú de módulos con los dos que hay. Lo que
depende de un módulo que todavía no está queda afuera hasta que ese módulo
se una:

- La pestaña «En la red» de cada equipo, que muestra lo importado en el
  módulo de logs, vuelve con ese módulo.
- `frontend/js/csv.js` tiene las funciones para exportar a CSV que en el
  sistema completo están en `logs_ui.js`. Cuando se una el módulo de logs,
  `dispositivos.js` y `switch.js` las vuelven a tomar de ahí y este archivo
  se quita.
- La migración desde el modelo de datos anterior
  (`00_cambio_de_modelo.sql` y `migrarDispositivos.sql`) se queda en la
  rama `main`: se usa una sola vez y la base del servidor ya la tiene.

## Base de datos

Usa la misma base `gestion_redes` que el sistema completo y crea solo lo de
estos dos módulos: 39 tablas, 196 procedimientos, 4 funciones y 196
disparadores. Si la base ya tiene los demás módulos no los toca, así que el
sistema completo y este pueden usar la misma base al mismo tiempo.

```bash
cd sql
bash reinstalar_base.sh               # crea o actualiza; conserva los datos y saca un respaldo antes
bash reinstalar_base.sh --revisar     # solo revisa
bash reinstalar_base.sh --desde-cero  # BORRA la base gestion_redes completa y la crea vacía
```

Orden de los scripts (lo sigue `reinstalar_base.sh`):

1. `instalacion/01_estructura.sql`, `02_procedimientos.sql` y `03_datos.sql`: usuarios y proveedores
2. `dispositivos/creacionDispositivo.sql`, `procedimientosDispositivos.sql` e `insercionDispositivos.sql`: equipos municipales

Datos de ejemplo, opcionales: `mariadb -u admin_db -p < sql/pruebas/poblarDatosEjemplo.sql`.
Trae 17 departamentos, 17 funcionarios, 7 proveedores, 53 equipos y 38
puertos de switches. Los quita `sql/pruebas/borrarDatosEjemplo.sql`.

## Instalación

```bash
cd ~/repo_muni/backend
source <carpeta del entorno de Python>/bin/activate   # el mismo del sistema completo sirve
pip install -r requirements.txt                       # solo si es un entorno nuevo
cd sql && bash reinstalar_base.sh && cd ..
python manage.py inicializar --usuario admin          # solo si la base no tiene usuarios
python manage.py runserver 0.0.0.0:8002
```

La página queda en `http://<servidor>:8002/app/` y la documentación de la
API en `http://<servidor>:8002/api/docs/`. Se usa el puerto 8002 para que
pueda correr al mismo tiempo que el sistema completo, que usa el 8001.

La conexión a la base está en `muni_backend/settings.py`, en `DATABASES`:
el nombre de la base debe ser `gestion_redes`. Los documentos de los
equipos se guardan en la carpeta de `MEDIA_ROOT`; el tamaño máximo de cada
uno está en `MUNI_MAX_MB_DOCUMENTO_RED`.

## API

Todas las rutas piden sesión: `POST /api/usuarios/login/` devuelve el token,
que se envía como `Authorization: Bearer <token>`.

Usuarios y proveedores:

- `/api/usuarios/` con `<id>/telefonos/`, `<id>/correos/`, `<id>/paginas-webs/` y `<id>/historial-claves/`
- `/api/proveedores/` con los mismos contactos, `<id>/imagen/` y `<id>/catalogo/`
- `/api/catalogos/<catálogo>/`
- `/api/geografia/paises/`, `provincias/`, `cantones/` y `distritos/`
- `/api/auditoria/`
- `/api/consultas/cedula/<número>/`

Equipos municipales:

- `/api/dispositivos/` con `<id>/ips/`, `<id>/macs/`, `<id>/moviles/`, `<id>/imeis/`, `<id>/documentos/` y `<id>/historial/`
- `/api/dispositivos/switches/`, `<id>/puertos/` y `<id>/conexiones/`
- `/api/dispositivos/tipos/`, `marcas/`, `modelos/`, `edificios/`, `sistemas-operativos/`,
  `procesadores/`, `firmwares/`, `estados/`, `roles/`, `herramientas/`, `tipos-documentos/` y `categorias/`
