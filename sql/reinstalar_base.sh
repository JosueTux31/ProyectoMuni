#!/usr/bin/env bash
# =====================================================================
#  reinstalar_base.sh - vuelve a correr la base gestion_redes de los
#  módulos de usuarios y proveedores y de equipos municipales
# ---------------------------------------------------------------------
#  Ejecute en el servidor, desde la carpeta sql del backend:
#     cd ~/repo_muni/backend/sql
#     bash reinstalar_base.sh               conserva los datos (recomendado)
#     bash reinstalar_base.sh --desde-cero  BORRA la base y la crea vacía
#     bash reinstalar_base.sh --revisar     solo revisa, no cambia nada
#
#  Qué hace:
#    1. Pide la clave del usuario de la base y prueba la conexión.
#    2. Saca un respaldo completo en la carpeta respaldos (menos el padrón
#       del TSE, que se vuelve a descargar).
#    3. Ejecuta los scripts en orden y se detiene en el primer error,
#       diciendo el archivo y la línea:
#         instalacion/01_estructura.sql
#         instalacion/02_procedimientos.sql
#         instalacion/03_datos.sql
#         dispositivos/creacionDispositivo.sql
#         dispositivos/procedimientosDispositivos.sql
#         dispositivos/insercionDispositivos.sql
#       Todos se pueden ejecutar más de una vez: no duplican ni borran datos.
#    4. Corrige tildes dañadas en catálogos y territorio (reparar_letras.sql).
#    5. Ejecuta revisar_base.sql y muestra si la base quedó como debe.
#
#  Conexión (igual que settings.py). Se puede cambiar así:
#     MUNI_DB_USUARIO=root bash reinstalar_base.sh
#  Variables: MUNI_DB_HOST, MUNI_DB_PUERTO, MUNI_DB_USUARIO, MUNI_DB_CLAVE
# =====================================================================
set -u

BASE="gestion_redes"
HOST="${MUNI_DB_HOST:-127.0.0.1}"
PUERTO="${MUNI_DB_PUERTO:-3306}"
USUARIO="${MUNI_DB_USUARIO:-admin_db}"

SCRIPTS=(
  instalacion/01_estructura.sql
  instalacion/02_procedimientos.sql
  instalacion/03_datos.sql
  dispositivos/creacionDispositivo.sql
  dispositivos/procedimientosDispositivos.sql
  dispositivos/insercionDispositivos.sql
)

MODO="normal"
case "${1:-}" in
  "") ;;
  --desde-cero) MODO="cero" ;;
  --revisar) MODO="revisar" ;;
  *) echo "Uso: bash reinstalar_base.sh [--desde-cero | --revisar]"; exit 2 ;;
esac

cd "$(dirname "$0")" || exit 1
for f in "${SCRIPTS[@]}" reparar_letras.sql revisar_base.sql; do
  if [ ! -f "$f" ]; then
    echo "No encuentro $f. Ejecute este archivo desde la carpeta sql del backend."
    exit 1
  fi
done

CLIENTE="$(command -v mariadb || command -v mysql || true)"
VOLCADO="$(command -v mariadb-dump || command -v mysqldump || true)"
if [ -z "$CLIENTE" ]; then
  echo "No encuentro el cliente de MariaDB (mariadb o mysql). Instálelo: sudo apt install mariadb-client"
  exit 1
fi

# La clave va en un archivo temporal que solo usted puede leer (no en la
# línea de comandos, donde otros usuarios del servidor la verían).
if [ -z "${MUNI_DB_CLAVE:-}" ]; then
  read -r -s -p "Clave de $USUARIO en $HOST: " MUNI_DB_CLAVE
  echo
fi
CNF="$(mktemp)"
chmod 600 "$CNF"
trap 'rm -f "$CNF"' EXIT
CLAVE_ESC="${MUNI_DB_CLAVE//\\/\\\\}"
CLAVE_ESC="${CLAVE_ESC//\"/\\\"}"
cat > "$CNF" <<EOF
[client]
host=$HOST
port=$PUERTO
user=$USUARIO
password="$CLAVE_ESC"
default-character-set=utf8mb4
EOF

sql() { "$CLIENTE" --defaults-extra-file="$CNF" "$@"; }

echo "== Conexión"
if ! VERSION="$(sql -N -B -e "SELECT VERSION()" 2>&1)"; then
  echo "No se pudo conectar: $VERSION"
  exit 1
fi
echo "   $USUARIO@$HOST:$PUERTO, servidor $VERSION"
EXISTE="$(sql -N -B -e "SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$BASE'")"

revisar() {
  echo
  echo "== Revisión de la base (revisar_base.sql)"
  sql --table < revisar_base.sql
}

if [ "$MODO" = "revisar" ]; then
  if [ "$EXISTE" = "0" ]; then echo "La base $BASE no existe."; exit 1; fi
  revisar
  exit $?
fi

# ------------------------------------------------------------- respaldo
if [ "$EXISTE" = "1" ]; then
  if [ -z "$VOLCADO" ]; then
    echo "No encuentro mariadb-dump para sacar el respaldo. Instálelo (sudo apt install mariadb-client) y vuelva a intentar."
    exit 1
  fi
  mkdir -p respaldos
  RESPALDO="respaldos/${BASE}_$(date +%Y%m%d_%H%M%S).sql"
  echo
  echo "== Respaldo en $RESPALDO"
  # Primero las tablas, después los datos y al final disparadores y
  # procedimientos (así, al restaurar, los disparadores no tocan los datos).
  # El padrón (millones de filas) va sin datos: se vuelve a cargar con
  # python manage.py cargar_padron --descargar
  dump() { "$VOLCADO" --defaults-extra-file="$CNF" --single-transaction "$@" 2>> respaldos/error_respaldo.txt; }
  : > respaldos/error_respaldo.txt
  if ! { dump --no-data --skip-triggers --databases "$BASE" \
         && dump --no-create-info --skip-triggers --ignore-table="$BASE.pad_padron" "$BASE" \
         && dump --no-create-info --no-data --triggers "$BASE"; } > "$RESPALDO"; then
    echo "No se pudo sacar el respaldo:"
    cat respaldos/error_respaldo.txt
    echo "No se cambió nada en la base."
    exit 1
  fi
  # Los procedimientos los vuelven a crear los scripts; si este usuario no
  # puede leerlos (los creó otro), el respaldo sigue sin ellos.
  if ! dump --no-create-info --no-data --skip-triggers --routines "$BASE" >> "$RESPALDO"; then
    echo "   (sin los procedimientos: los creó otro usuario de la base; los scripts los crean de nuevo)"
  fi
  rm -f respaldos/error_respaldo.txt
  chmod 600 "$RESPALDO"
  echo "   listo ($(du -h "$RESPALDO" | cut -f1)). Para volver a como estaba:"
  echo "   mariadb -u $USUARIO -p < $RESPALDO"
fi

# ------------------------------------------------------- desde cero
if [ "$MODO" = "cero" ] && [ "$EXISTE" = "1" ]; then
  echo
  echo "!! Se va a BORRAR por completo la base $BASE con todo lo que tenga:"
  echo "   usuarios, proveedores, equipos, auditoría y el padrón. El respaldo quedó en $RESPALDO."
  read -r -p "   Escriba BORRAR para seguir: " RESPUESTA
  if [ "$RESPUESTA" != "BORRAR" ]; then
    echo "No se borró nada."
    exit 1
  fi
  if ! sql -e "DROP DATABASE IF EXISTS \`$BASE\`"; then
    echo "No se pudo borrar la base (¿el usuario $USUARIO tiene permiso DROP?)."
    exit 1
  fi
  echo "   base borrada"
fi

# ---------------------------------------------------------- scripts
echo
echo "== Scripts"
for f in "${SCRIPTS[@]}"; do
  printf "   %-46s " "$f"
  if SALIDA="$(sql --table < "$f" 2>&1)"; then
    # Los scripts de creación avisan cada tabla nueva
    NUEVAS="$(printf '%s\n' "$SALIDA" | grep -c "se creó correctamente!" || true)"
    TABLAS="$(printf '%s\n' "$SALIDA" | grep -c "¡La tabla .* se creó correctamente!" || true)"
    EXTRA=""
    [ "$TABLAS" != "0" ] && EXTRA=" ($TABLAS tablas nuevas, $NUEVAS avisos de creación)"
    echo "ok$EXTRA"
  else
    echo "FALLÓ"
    echo
    echo "$SALIDA" | tail -n 8 | sed 's/^/   /'
    echo
    if printf '%s\n' "$SALIDA" | grep -q "Access denied.*$BASE"; then
      CUENTA="$(sql -N -B -e "SELECT CONCAT(\"'\", SUBSTRING_INDEX(CURRENT_USER(), '@', 1), \"'@'\", SUBSTRING_INDEX(CURRENT_USER(), '@', -1), \"'\")")"
      echo "   El usuario $USUARIO no tiene permiso sobre la base $BASE. Délo una vez como"
      echo "   administrador de MariaDB y vuelva a ejecutar este archivo:"
      echo "      sudo mariadb -e \"GRANT ALL PRIVILEGES ON $BASE.* TO $CUENTA\""
      echo
      exit 1
    fi
    echo "   El error está en $f, en la línea que indica \"at line\"."
    echo "   Los scripts anteriores quedaron aplicados; los siguientes no se ejecutaron."
    echo "   Corrija o envíe este mensaje y vuelva a correr: bash reinstalar_base.sh"
    exit 1
  fi
done

echo
echo "== Tildes (reparar_letras.sql)"
if SALIDA="$(sql -N -B < reparar_letras.sql 2>&1)"; then
  echo "$SALIDA" | sed 's/^/   /'
else
  echo "   No se pudo revisar las tildes (no impide usar el sistema):"
  echo "$SALIDA" | tail -n 3 | sed 's/^/   /'
fi

revisar
echo
if [ "$MODO" = "cero" ]; then
  echo "Base nueva. Falta, en la carpeta backend (cd ..) con el entorno activado:"
  echo "   python manage.py inicializar --usuario admin"
fi
if [ -f ../muni_backend/settings.py ] && ! grep -qE "['\"]NAME['\"]: *['\"]$BASE['\"]" ../muni_backend/settings.py; then
  echo "Falta: en muni_backend/settings.py, en DATABASES, ponga 'NAME': '$BASE'."
fi
echo "Reinicie Django (runserver) para que use los procedimientos nuevos."
