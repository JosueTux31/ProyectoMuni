# Gestión municipal: usuarios y proveedores + equipos municipales + análisis de logs

Este proyecto es el sistema separado por módulos. Por ahora trae tres:
**usuarios y proveedores**, **equipos municipales** (con los switches y sus
puertos) y **análisis de logs**. Los que faltan (correo institucional y
licencias) se van a ir uniendo después, uno por uno.

| Parte        | Contenido |
|--------------|-----------|
| `apps/core`         | Conexión a los procedimientos, inicio de sesión, permisos, archivos y búsqueda por cédula |
| `apps/usuarios`     | Usuarios con sus teléfonos, correos, páginas web y claves |
| `apps/proveedores`  | Proveedores con sus contactos, imagen y catálogo de servicios |
| `apps/catalogos`    | Roles, departamentos, tipos de identificación, teléfono y correo, categorías de proveedores |
| `apps/geografia`    | Países, provincias, cantones y distritos |
| `apps/auditoria`    | Historial de cambios e inicios de sesión |
| `apps/dispositivos` | Equipos municipales: equipos con IP, MAC, líneas, IMEI y documentos; switches y puertos; edificios, marcas, modelos y catálogos de equipos |
| `apps/logs`         | Análisis de logs: importación de Sophos Firewall, del listado de Microclaudia y de las concesiones del DHCP; filtro estilo Wireshark, tablero, comparación, intrusos en la red, equipos sin agente y cruce con el inventario |
| `frontend`          | La página web (se abre en `/app/`) |
| `sql`               | Scripts de la base de datos de los tres módulos |

## Módulos

| Módulo | Estado | Rama de Git |
|--------|--------|-------------|
| 1. Usuarios y proveedores | incluido | `modular` |
| 2. Equipos municipales y switches | incluido | `modulo-equipos`, unida a `modular` |
| 3. Análisis de logs | incluido | `modulo-logs`, unida a `modular` |
| 4. Correo institucional | pendiente | |
| 5. Licencias y reportes | pendiente | |

Al entrar, la página muestra el menú de módulos. El de análisis de logs
es solo para administradores: los demás usuarios no lo ven en el menú y la
API les responde que no tienen permiso.

Con este módulo vuelve la pestaña «En la red» de cada equipo, que ven los
administradores y muestra lo que el equipo tiene en el DHCP, en
Microclaudia y en los logs de Sophos.
Las funciones para exportar a CSV vuelven a estar en `logs_ui.js`, así que
`frontend/js/csv.js` ya no se usa y se quita.

Lo que todavía queda afuera hasta que se una su módulo:

- La ruta `/api/logs/licencias/` ya está, pero la pantalla que la usa es la
  de licencias, que viene con ese módulo.
- La migración desde el modelo de datos anterior
  (`00_cambio_de_modelo.sql` y `migrarDispositivos.sql`) se queda en la
  rama `main`: se usa una sola vez y la base del servidor ya la tiene.

## Base de datos

Usa la misma base `gestion_redes` que el sistema completo y crea solo lo de
estos tres módulos: 43 tablas, 227 procedimientos, 4 funciones y 203
disparadores. Si la base ya tiene el módulo de correo no lo toca, así que el
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
3. `logs/creacionLogs.sql`, `procedimientosLogs.sql` e `insercionLogs.sql`: análisis de logs

Datos de ejemplo, opcionales: `mariadb -u admin_db -p < sql/pruebas/poblarDatosEjemplo.sql`.
Trae 17 departamentos, 17 funcionarios, 7 proveedores, 53 equipos y 38
puertos de switches. Los quita `sql/pruebas/borrarDatosEjemplo.sql`.

Datos de prueba del DHCP, opcionales: `sql/pruebas/cargaPruebaEquipos.sql`
registra la mitad de los equipos de la lista del DHCP del 26/10/2026, para
que en «Intrusos en la red» se vean equipos registrados y sin registrar.
Los quita `sql/pruebas/borrarPruebaEquipos.sql`.

Los logs no traen datos de ejemplo: se importan desde la página, en
Análisis de logs → Importar.

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
equipos se guardan en la carpeta de `MEDIA_ROOT`. Los tamaños máximos están
en el mismo archivo: `MUNI_MAX_MB_DOCUMENTO_RED` para los documentos de los
equipos, `MUNI_MAX_MB_LOG` para cada archivo de logs que se importa y
`MUNI_MAX_EXPORTAR_LOGS` para los eventos que se exportan a CSV de una vez.

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

Análisis de logs (solo administradores):

- `/api/logs/importaciones/` con `sophos/`, `microclaudia/` y `dhcp/` para importar, y `<id>/`
- `/api/logs/eventos/` con `tablero/`, `top/`, `exportar/` y `<id>/`
- `/api/logs/filtro/`, `campos/`, `comparar/` e `inventario/`
- `/api/logs/agentes/`, `cobertura/`, `intrusos/`, `licencias/` y `equipos/<id>/`
- `/api/logs/mapeo/` y `mapeo/<programa>/<campo>/`
