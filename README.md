# Gestión municipal: módulo de usuarios y proveedores

Este proyecto es el sistema separado con un solo módulo: usuarios y
proveedores. Trae lo que ese módulo necesita para funcionar y nada de los
demás módulos (equipos municipales, switches, logs, correo y licencias):

| Parte        | Contenido |
|--------------|-----------|
| `apps/core`        | Conexión a los procedimientos, inicio de sesión, permisos, archivos y búsqueda por cédula |
| `apps/usuarios`    | Usuarios con sus teléfonos, correos, páginas web y claves |
| `apps/proveedores` | Proveedores con sus contactos, imagen y catálogo de servicios |
| `apps/catalogos`   | Roles, departamentos, tipos de identificación, teléfono y correo, categorías de proveedores |
| `apps/geografia`   | Países, provincias, cantones y distritos |
| `apps/auditoria`   | Historial de cambios e inicios de sesión |
| `frontend`         | La página web (se abre en `/app/`) |
| `sql`              | Scripts de la base de datos del módulo |

## Base de datos

Usa la misma base `gestion_redes` que el sistema completo y solo crea sus
18 tablas, 98 procedimientos y 82 disparadores. Si la base ya tiene los
demás módulos no los toca, así que los dos sistemas pueden usar la misma
base al mismo tiempo.

```bash
cd sql
bash reinstalar_base.sh               # crea o actualiza; conserva los datos y saca un respaldo antes
bash reinstalar_base.sh --revisar     # solo revisa
bash reinstalar_base.sh --desde-cero  # BORRA la base gestion_redes completa y la crea vacía
```

Datos de ejemplo, opcionales: `mariadb -u admin_db -p < sql/pruebas/poblarDatosEjemplo.sql`
(los quita `sql/pruebas/borrarDatosEjemplo.sql`).

## Instalación

```bash
cd ~/modulo_usuarios/backend
source <carpeta del entorno de Python>/bin/activate   # el mismo del sistema completo sirve
pip install -r requirements.txt                       # solo si es un entorno nuevo
bash verificar_archivos.sh                            # revisa que los archivos estén completos
cd sql && bash reinstalar_base.sh && cd ..
python manage.py inicializar --usuario admin          # solo si la base no tiene usuarios
python manage.py runserver 0.0.0.0:8002
```

La página queda en `http://<servidor>:8002/app/` y la documentación de la
API en `http://<servidor>:8002/api/docs/`. Se usa el puerto 8002 para que
pueda correr al mismo tiempo que el sistema completo, que usa el 8001.

La conexión a la base está en `muni_backend/settings.py`, en `DATABASES`:
el nombre de la base debe ser `gestion_redes`.

## API

Todas las rutas piden sesión: `POST /api/usuarios/login/` devuelve el token,
que se envía como `Authorization: Bearer <token>`.

- `/api/usuarios/` con `<id>/telefonos/`, `<id>/correos/`, `<id>/paginas-webs/` y `<id>/historial-claves/`
- `/api/proveedores/` con los mismos contactos, `<id>/imagen/` y `<id>/catalogo/`
- `/api/catalogos/<catálogo>/`
- `/api/geografia/paises/`, `provincias/`, `cantones/` y `distritos/`
- `/api/auditoria/`
- `/api/consultas/cedula/<número>/`
