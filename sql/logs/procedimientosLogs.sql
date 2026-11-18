-- =====================================================================
--  procedimientosLogs.sql - módulo de análisis de logs
--  gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 2 de 3. Contiene 31 procedimientos y 7 disparadores.
--  Los procedimientos que reciben p_filtro arman la consulta con el
--  filtro que escribió el usuario (estilo Wireshark), ya traducido y
--  escapado por Django (apps/logs/filtro.py).
--
--  Orden de instalación (después de los scripts de instalacion y de
--  dispositivos; reinstalar_base.sh los ejecuta todos en orden):
--     1. creacionLogs.sql         tablas
--     2. procedimientosLogs.sql   procedimientos y disparadores
--     3. insercionLogs.sql        alias de los campos (Sophos, Microclaudia y DHCP)
--  Se pueden ejecutar más de una vez sin duplicar ni borrar nada.
-- =====================================================================

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base, con el programa que sea que lo ejecute: así
-- las tildes se guardan bien y nada mezcla intercalaciones distintas.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;

-- Los procedimientos se crean con este modo: el filtro escapa la barra
-- invertida, así que NO_BACKSLASH_ESCAPES no debe estar activo.
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DELIMITER $$

-- =====================================================================
-- 1. PROCEDIMIENTOS
-- =====================================================================

-- --------------------------------------------------------------------- log_importaciones
CREATE OR REPLACE PROCEDURE sp_log_importaciones_insertar(
    IN  p_fuente         VARCHAR(30),
    IN  p_nombre_archivo VARCHAR(255),
    IN  p_descripcion    VARCHAR(255),
    IN  p_id_usuario     INT,
    OUT p_id_importacion INT
)
BEGIN
    IF p_fuente IS NULL OR TRIM(p_fuente) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique de qué programa son los logs.';
    END IF;
    INSERT INTO log_importaciones (fuente, nombre_archivo, descripcion, id_usuario)
    VALUES (UPPER(TRIM(p_fuente)), LEFT(COALESCE(NULLIF(TRIM(p_nombre_archivo), ''), 'sin nombre'), 255),
            NULLIF(TRIM(p_descripcion), ''), p_id_usuario);
    SET p_id_importacion = LAST_INSERT_ID();
END$$

-- Al terminar de importar: totales, permitidos, denegados y fechas.
-- p_leidos = eventos que traía el archivo; p_avisos = partes sin leer.
CREATE OR REPLACE PROCEDURE sp_log_importaciones_cerrar(
    IN p_id_importacion INT,
    IN p_leidos         INT,
    IN p_avisos         INT
)
BEGIN
    DECLARE v_total INT;
    DECLARE v_permitidos INT;
    DECLARE v_denegados INT;
    DECLARE v_desde DATETIME;
    DECLARE v_hasta DATETIME;

    IF NOT EXISTS (SELECT 1 FROM log_importaciones WHERE id_importacion = p_id_importacion) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La importación no existe.';
    END IF;
    SELECT COUNT(*), COALESCE(SUM(accion = 'PERMITIDO'), 0), COALESCE(SUM(accion = 'DENEGADO'), 0), MIN(fecha), MAX(fecha)
      INTO v_total, v_permitidos, v_denegados, v_desde, v_hasta
      FROM log_eventos
     WHERE id_importacion = p_id_importacion;

    UPDATE log_importaciones
       SET total_leidos  = GREATEST(COALESCE(p_leidos, 0), v_total),
           total_eventos = v_total,
           repetidos     = GREATEST(COALESCE(p_leidos, 0) - v_total, 0),
           permitidos    = v_permitidos,
           denegados     = v_denegados,
           avisos        = COALESCE(p_avisos, 0),
           fecha_desde   = v_desde,
           fecha_hasta   = v_hasta
     WHERE id_importacion = p_id_importacion;
END$$

-- Solo se cambia la descripción
CREATE OR REPLACE PROCEDURE sp_log_importaciones_actualizar(
    IN p_id_importacion INT,
    IN p_descripcion    VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM log_importaciones WHERE id_importacion = p_id_importacion) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La importación no existe.';
    END IF;
    UPDATE log_importaciones SET descripcion = NULLIF(TRIM(p_descripcion), '')
     WHERE id_importacion = p_id_importacion;
END$$

-- Borra la importación con todos sus eventos (ON DELETE CASCADE)
CREATE OR REPLACE PROCEDURE sp_log_importaciones_eliminar(
    IN p_id_importacion INT
)
BEGIN
    DELETE FROM log_importaciones WHERE id_importacion = p_id_importacion;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La importación no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_log_importaciones_obtener(
    IN p_id_importacion INT
)
BEGIN
    SELECT i.*, CONCAT_WS(' ', u.nombre, u.apellido1) AS importado_por
      FROM log_importaciones i
      LEFT JOIN personas u ON u.id = i.id_usuario
     WHERE i.id_importacion = p_id_importacion;
END$$

-- p_fuente: solo de un programa (NULL = todas)
CREATE OR REPLACE PROCEDURE sp_log_importaciones_listar(
    IN p_fuente VARCHAR(30)
)
BEGIN
    SELECT i.*, CONCAT_WS(' ', u.nombre, u.apellido1) AS importado_por
      FROM log_importaciones i
      LEFT JOIN personas u ON u.id = i.id_usuario
     WHERE p_fuente IS NULL OR i.fuente = p_fuente
     ORDER BY i.id_importacion DESC;
END$$

-- --------------------------------------------------------------------- log_eventos
-- Guarda un evento. p_evento: los campos comunes en JSON
-- ({"fecha": "2026-10-22 08:19:16", "ip_origen": "10.1.12.2", ...}); p_datos:
-- todos los campos originales en JSON. Si el mismo evento ya está en esta
-- importación (misma huella) no se repite. No abre transacción: Django
-- importa todo el archivo en una sola (todo o nada).
-- p_evento.direcciones (opcional): [{"t": "IP", "v": "10.1.10.83"}, {"t": "MAC", "v": "A4BB6D948529"}]
-- = todas las direcciones del equipo (van a log_direcciones).
CREATE OR REPLACE PROCEDURE sp_log_eventos_insertar(
    IN p_id_importacion INT,
    IN p_evento         LONGTEXT,
    IN p_datos          LONGTEXT
)
BEGIN
    DECLARE v_id BIGINT;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;

    IF NOT JSON_VALID(p_evento) OR NOT JSON_VALID(p_datos) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El evento no es un JSON válido.';
    END IF;
    INSERT IGNORE INTO log_eventos (id_importacion, fuente, huella, fecha, tipo, accion, tipo_log, componente, subtipo, descripcion, dispositivo, id_mensaje, severidad, regla_id, regla_nombre, regla_seccion, nat_regla_id, nat_regla, politica_web, actividad, motivo, usuario, grupo_usuario, ip_origen, puerto_origen, mac_origen, pais_origen, zona_origen, interfaz_entrada, ip_origen_nat, nombre_equipo, sistema_operativo, ip_destino, puerto_destino, mac_destino, pais_destino, zona_destino, interfaz_salida, ip_destino_nat, dominio, url, categoria, categoria_tipo, codigo_http, tipo_contenido, navegador, aplicacion, aplicacion_categoria, aplicacion_riesgo, version_tls, cifrado, version_agente, vacunas_aplicadas, vacunas_pendientes, vacunas_error, protocolo, bytes_enviados, bytes_recibidos, paquetes_enviados, paquetes_recibidos, duracion, id_conexion, datos)
    SELECT i.id_importacion, i.fuente, JSON_VALUE(p_evento, '$.huella'),
           JSON_VALUE(p_evento, '$.fecha'), 
           JSON_VALUE(p_evento, '$.tipo'), 
           JSON_VALUE(p_evento, '$.accion'), 
           JSON_VALUE(p_evento, '$.tipo_log'), 
           JSON_VALUE(p_evento, '$.componente'), 
           JSON_VALUE(p_evento, '$.subtipo'), 
           JSON_VALUE(p_evento, '$.descripcion'), 
           JSON_VALUE(p_evento, '$.dispositivo'), 
           JSON_VALUE(p_evento, '$.id_mensaje'), 
           JSON_VALUE(p_evento, '$.severidad'), 
           JSON_VALUE(p_evento, '$.regla_id'), 
           JSON_VALUE(p_evento, '$.regla_nombre'), 
           JSON_VALUE(p_evento, '$.regla_seccion'), 
           JSON_VALUE(p_evento, '$.nat_regla_id'), 
           JSON_VALUE(p_evento, '$.nat_regla'), 
           JSON_VALUE(p_evento, '$.politica_web'), 
           JSON_VALUE(p_evento, '$.actividad'), 
           JSON_VALUE(p_evento, '$.motivo'), 
           JSON_VALUE(p_evento, '$.usuario'), 
           JSON_VALUE(p_evento, '$.grupo_usuario'), 
           JSON_VALUE(p_evento, '$.ip_origen'), 
           JSON_VALUE(p_evento, '$.puerto_origen'), 
           JSON_VALUE(p_evento, '$.mac_origen'), 
           JSON_VALUE(p_evento, '$.pais_origen'), 
           JSON_VALUE(p_evento, '$.zona_origen'), 
           JSON_VALUE(p_evento, '$.interfaz_entrada'), 
           JSON_VALUE(p_evento, '$.ip_origen_nat'), 
           JSON_VALUE(p_evento, '$.nombre_equipo'), 
           JSON_VALUE(p_evento, '$.sistema_operativo'), 
           JSON_VALUE(p_evento, '$.ip_destino'), 
           JSON_VALUE(p_evento, '$.puerto_destino'), 
           JSON_VALUE(p_evento, '$.mac_destino'), 
           JSON_VALUE(p_evento, '$.pais_destino'), 
           JSON_VALUE(p_evento, '$.zona_destino'), 
           JSON_VALUE(p_evento, '$.interfaz_salida'), 
           JSON_VALUE(p_evento, '$.ip_destino_nat'), 
           JSON_VALUE(p_evento, '$.dominio'), 
           JSON_VALUE(p_evento, '$.url'), 
           JSON_VALUE(p_evento, '$.categoria'), 
           JSON_VALUE(p_evento, '$.categoria_tipo'), 
           JSON_VALUE(p_evento, '$.codigo_http'), 
           JSON_VALUE(p_evento, '$.tipo_contenido'), 
           JSON_VALUE(p_evento, '$.navegador'), 
           JSON_VALUE(p_evento, '$.aplicacion'), 
           JSON_VALUE(p_evento, '$.aplicacion_categoria'), 
           JSON_VALUE(p_evento, '$.aplicacion_riesgo'), 
           JSON_VALUE(p_evento, '$.version_tls'), 
           JSON_VALUE(p_evento, '$.cifrado'), 
           JSON_VALUE(p_evento, '$.version_agente'), 
           JSON_VALUE(p_evento, '$.vacunas_aplicadas'), 
           JSON_VALUE(p_evento, '$.vacunas_pendientes'), 
           JSON_VALUE(p_evento, '$.vacunas_error'), 
           JSON_VALUE(p_evento, '$.protocolo'), 
           JSON_VALUE(p_evento, '$.bytes_enviados'), 
           JSON_VALUE(p_evento, '$.bytes_recibidos'), 
           JSON_VALUE(p_evento, '$.paquetes_enviados'), 
           JSON_VALUE(p_evento, '$.paquetes_recibidos'), 
           JSON_VALUE(p_evento, '$.duracion'), 
           JSON_VALUE(p_evento, '$.id_conexion'),
           p_datos
      FROM log_importaciones i
     WHERE i.id_importacion = p_id_importacion;

    -- Las direcciones solo si el evento se guardó (no estaba repetido)
    IF ROW_COUNT() > 0 THEN
        SET v_id = LAST_INSERT_ID();
        SET v_n = COALESCE(JSON_LENGTH(p_evento, '$.direcciones'), 0);
        WHILE v_i < v_n DO
            INSERT IGNORE INTO log_direcciones (id_evento, id_importacion, tipo, direccion)
            VALUES (v_id, p_id_importacion,
                    JSON_VALUE(p_evento, CONCAT('$.direcciones[', v_i, '].t')),
                    JSON_VALUE(p_evento, CONCAT('$.direcciones[', v_i, '].v')));
            SET v_i = v_i + 1;
        END WHILE;
    END IF;
END$$

-- Un evento con todo: campos, datos originales, la importación, los
-- equipos del inventario de origen y destino y la persona del usuario.
-- id_disp_mac / equipo_mac: el equipo que tiene la MAC de origen (en el
-- DHCP la IP cambia; la MAC es la que identifica al equipo).
CREATE OR REPLACE PROCEDURE sp_log_eventos_obtener(
    IN p_id_evento BIGINT
)
BEGIN
    SELECT x.*,
           (SELECT CONCAT_WS(' · ', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT('SERIE ', d.serie))
                  FROM equipos d
                  JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
                  JOIN marcas m ON m.id_marca = d.id_marca
                  LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo
                 WHERE d.id = x.id_disp_origen) AS equipo_origen,
           (SELECT CONCAT_WS(' · ', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT('SERIE ', d.serie))
                  FROM equipos d
                  JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
                  JOIN marcas m ON m.id_marca = d.id_marca
                  LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo
                 WHERE d.id = x.id_disp_destino) AS equipo_destino,
           (SELECT CONCAT_WS(' · ', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT('SERIE ', d.serie))
                  FROM equipos d
                  JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
                  JOIN marcas m ON m.id_marca = d.id_marca
                  LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo
                 WHERE d.id = x.id_disp_mac) AS equipo_mac,
           (SELECT u.id FROM personas u WHERE u.usuario_red = x.usuario AND u.es_proveedor = FALSE LIMIT 1) AS id_persona,
           (SELECT CONCAT_WS(' ', u.nombre, u.apellido1, u.apellido2) FROM personas u WHERE u.usuario_red = x.usuario AND u.es_proveedor = FALSE LIMIT 1) AS persona
      FROM (SELECT e.*, i.nombre_archivo, i.descripcion AS importacion_descripcion,
                   COALESCE((SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_origen ORDER BY q.id LIMIT 1), (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_origen LIMIT 1)) AS id_disp_origen,
                   COALESCE((SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_destino_nat ORDER BY q.id LIMIT 1), (SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_destino ORDER BY q.id LIMIT 1), (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_destino LIMIT 1)) AS id_disp_destino,
                   (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_origen LIMIT 1) AS id_disp_mac,
                   (SELECT COUNT(*) FROM log_eventos o
                     WHERE o.huella = e.huella AND o.id_importacion <> e.id_importacion) AS en_otras_importaciones
              FROM log_eventos e
              JOIN log_importaciones i ON i.id_importacion = e.id_importacion
             WHERE e.id_evento = p_id_evento) x;
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- p_orden: 'asc' o 'desc' (por fecha). Devuelve una página de eventos con
-- los equipos del inventario y la persona que les corresponden.
CREATE OR REPLACE PROCEDURE sp_log_eventos_buscar(
    IN p_filtro         LONGTEXT,
    IN p_orden          VARCHAR(4),
    IN p_limite         INT,
    IN p_desplazamiento INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 100), 1), 1000);
    DECLARE v_desplazamiento INT DEFAULT GREATEST(COALESCE(p_desplazamiento, 0), 0);
    DECLARE v_orden VARCHAR(4) DEFAULT IF(LOWER(p_orden) = 'asc', 'ASC', 'DESC');

    EXECUTE IMMEDIATE CONCAT(
        'SELECT x.*, ',
        '(SELECT CONCAT_WS('' · '', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT(''SERIE '', d.serie)) FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo JOIN marcas m ON m.id_marca = d.id_marca LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo WHERE d.id = x.id_disp_origen) AS equipo_origen, ',
        '(SELECT CONCAT_WS('' · '', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT(''SERIE '', d.serie)) FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo JOIN marcas m ON m.id_marca = d.id_marca LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo WHERE d.id = x.id_disp_destino) AS equipo_destino, ',
        '(SELECT CONCAT_WS('' '', u.nombre, u.apellido1, u.apellido2) FROM personas u WHERE u.usuario_red = x.usuario AND u.es_proveedor = FALSE LIMIT 1) AS persona ',
        'FROM (SELECT e.id_evento, e.id_importacion, e.fuente, e.fecha, e.tipo, e.accion, e.subtipo, e.regla_id, e.regla_nombre, e.usuario, e.ip_origen, e.puerto_origen, e.mac_origen, e.pais_origen, e.zona_origen, e.ip_destino, e.puerto_destino, e.mac_destino, e.pais_destino, e.zona_destino, e.ip_origen_nat, e.ip_destino_nat, e.dominio, e.url, e.categoria, e.aplicacion, e.protocolo, e.bytes_enviados, e.bytes_recibidos, e.id_conexion, e.politica_web, e.actividad, e.codigo_http, e.nombre_equipo, e.sistema_operativo, e.version_agente, e.vacunas_pendientes, e.descripcion, ',
        'COALESCE((SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_origen ORDER BY q.id LIMIT 1), (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_origen LIMIT 1)) AS id_disp_origen, ',
        'COALESCE((SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_destino_nat ORDER BY q.id LIMIT 1), (SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_destino ORDER BY q.id LIMIT 1), (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_destino LIMIT 1)) AS id_disp_destino ',
        'FROM log_eventos e WHERE ', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro),
        ' ORDER BY e.fecha ', v_orden, ', e.id_evento ', v_orden,
        ' LIMIT ', v_limite, ' OFFSET ', v_desplazamiento, ') x');
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
CREATE OR REPLACE PROCEDURE sp_log_eventos_contar(
    IN p_filtro LONGTEXT
)
BEGIN
    EXECUTE IMMEDIATE CONCAT('SELECT COUNT(*) AS total FROM log_eventos e WHERE ', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro));
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Números para el tablero: totales, permitidos, denegados, IP distintas,
-- dominios, bytes y rango de fechas.
CREATE OR REPLACE PROCEDURE sp_log_eventos_resumen(
    IN p_filtro LONGTEXT
)
BEGIN
    EXECUTE IMMEDIATE CONCAT(
        'SELECT COUNT(*) AS total, ',
        'COALESCE(SUM(e.accion = ''PERMITIDO''), 0) AS permitidos, ',
        'COALESCE(SUM(e.accion = ''DENEGADO''), 0) AS denegados, ',
        'COALESCE(SUM(e.accion = ''OTRO''), 0) AS otros, ',
        'COUNT(DISTINCT e.ip_origen) AS ips_origen, ',
        'COUNT(DISTINCT e.ip_destino) AS ips_destino, ',
        'COUNT(DISTINCT e.dominio) AS dominios, ',
        'COUNT(DISTINCT e.usuario) AS usuarios, ',
        'COUNT(DISTINCT e.tipo) AS tipos, ',
        'COUNT(DISTINCT e.id_importacion) AS importaciones, ',
        'COUNT(DISTINCT e.id_conexion) AS conexiones, ',
        'COALESCE(SUM(e.bytes_enviados), 0) AS bytes_enviados, ',
        'COALESCE(SUM(e.bytes_recibidos), 0) AS bytes_recibidos, ',
        'MIN(e.fecha) AS desde, MAX(e.fecha) AS hasta ',
        'FROM log_eventos e WHERE ', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro));
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Los valores más frecuentes de un campo (top), con permitidos y denegados.
-- p_campo: una columna de log_eventos (ip_origen, dominio, regla_nombre...).
CREATE OR REPLACE PROCEDURE sp_log_eventos_top(
    IN p_filtro LONGTEXT,
    IN p_campo  VARCHAR(64),
    IN p_limite INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 10), 1), 20000);
    IF p_campo IS NULL OR p_campo IN ('datos', 'huella') OR NOT EXISTS (
            SELECT 1 FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'log_eventos' AND COLUMN_NAME = p_campo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese campo no se puede usar para agrupar.';
    END IF;
    EXECUTE IMMEDIATE CONCAT(
        'SELECT e.`', p_campo, '` AS valor, COUNT(*) AS cantidad, ',
        'COALESCE(SUM(e.accion = ''PERMITIDO''), 0) AS permitidos, ',
        'COALESCE(SUM(e.accion = ''DENEGADO''), 0) AS denegados, ',
        'MIN(e.fecha) AS primera, MAX(e.fecha) AS ultima ',
        'FROM log_eventos e WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.`', p_campo, '` IS NOT NULL ',
        'GROUP BY e.`', p_campo, '` ORDER BY cantidad DESC, valor LIMIT ', v_limite);
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Cantidad de eventos por intervalo de tiempo (p_segundos: 60 = por
-- minuto, 3600 = por hora...), para el gráfico de línea de tiempo.
CREATE OR REPLACE PROCEDURE sp_log_eventos_linea_tiempo(
    IN p_filtro   LONGTEXT,
    IN p_segundos INT
)
BEGIN
    DECLARE v_segundos INT DEFAULT GREATEST(COALESCE(p_segundos, 3600), 1);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT FROM_UNIXTIME(FLOOR(UNIX_TIMESTAMP(e.fecha) / ', v_segundos, ') * ', v_segundos, ') AS inicio, ',
        'COUNT(*) AS total, ',
        'COALESCE(SUM(e.accion = ''PERMITIDO''), 0) AS permitidos, ',
        'COALESCE(SUM(e.accion = ''DENEGADO''), 0) AS denegados, ',
        'COALESCE(SUM(e.accion = ''OTRO''), 0) AS otros ',
        'FROM log_eventos e WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.fecha IS NOT NULL ',
        'GROUP BY inicio ORDER BY inicio');
END$$

-- Todos los eventos de una misma conexión (con_id), de cualquier tipo de
-- log y de cualquier importación: el Web filter y el Firewall de la misma
-- visita quedan juntos.
CREATE OR REPLACE PROCEDURE sp_log_eventos_conexion(
    IN p_id_conexion VARCHAR(30)
)
BEGIN
    SELECT e.id_evento, e.id_importacion, e.fuente, e.fecha, e.tipo, e.accion, e.subtipo, e.regla_id, e.regla_nombre, e.usuario, e.ip_origen, e.puerto_origen, e.mac_origen, e.pais_origen, e.zona_origen, e.ip_destino, e.puerto_destino, e.mac_destino, e.pais_destino, e.zona_destino, e.ip_origen_nat, e.ip_destino_nat, e.dominio, e.url, e.categoria, e.aplicacion, e.protocolo, e.bytes_enviados, e.bytes_recibidos, e.id_conexion, e.politica_web, e.actividad, e.codigo_http, e.nombre_equipo, e.sistema_operativo, e.version_agente, e.vacunas_pendientes, e.descripcion, i.nombre_archivo
      FROM log_eventos e
      JOIN log_importaciones i ON i.id_importacion = e.id_importacion
     WHERE e.id_conexion = p_id_conexion
     ORDER BY e.fecha, e.tipo, e.id_evento
     LIMIT 200;
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Conexiones (con_id) que aparecen en más de un tipo de log o en más de una
-- importación: son la misma conexión vista desde logs distintos.
CREATE OR REPLACE PROCEDURE sp_log_eventos_correlacionados(
    IN p_filtro LONGTEXT,
    IN p_limite INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 50), 1), 5000);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT e.id_conexion, COUNT(*) AS eventos, ',
        'COUNT(DISTINCT e.tipo) AS tipos_distintos, COUNT(DISTINCT e.id_importacion) AS importaciones_distintas, ',
        'GROUP_CONCAT(DISTINCT e.tipo ORDER BY e.tipo SEPARATOR ''|'') AS tipos, ',
        'GROUP_CONCAT(DISTINCT e.id_importacion ORDER BY e.id_importacion SEPARATOR '','') AS importaciones, ',
        'GROUP_CONCAT(DISTINCT e.accion ORDER BY e.accion SEPARATOR '','') AS acciones, ',
        'MIN(e.fecha) AS desde, MAX(e.fecha) AS hasta, ',
        'MAX(e.ip_origen) AS ip_origen, MAX(e.ip_destino) AS ip_destino, MAX(e.puerto_destino) AS puerto_destino, ',
        'MAX(e.dominio) AS dominio, MAX(e.regla_nombre) AS regla_nombre, MAX(e.ip_origen_nat) AS ip_origen_nat, ',
        'MAX(e.ip_destino_nat) AS ip_destino_nat ',
        'FROM log_eventos e WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.id_conexion IS NOT NULL ',
        'GROUP BY e.id_conexion ',
        'HAVING COUNT(DISTINCT e.tipo) > 1 OR COUNT(DISTINCT e.id_importacion) > 1 ',
        'ORDER BY desde DESC LIMIT ', v_limite);
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Huellas de los eventos (para saber cuáles son idénticos entre logs)
CREATE OR REPLACE PROCEDURE sp_log_eventos_huellas(
    IN p_filtro LONGTEXT,
    IN p_limite INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 50000), 1), 200000);
    EXECUTE IMMEDIATE CONCAT('SELECT DISTINCT e.huella FROM log_eventos e WHERE ', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro),
                             ' LIMIT ', v_limite);
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Para exportar: una página con todas las columnas, los datos originales
-- y los equipos y la persona del inventario. Orden estable por id_evento.
CREATE OR REPLACE PROCEDURE sp_log_eventos_exportar(
    IN p_filtro         LONGTEXT,
    IN p_limite         INT,
    IN p_desplazamiento INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 5000), 1), 20000);
    DECLARE v_desplazamiento INT DEFAULT GREATEST(COALESCE(p_desplazamiento, 0), 0);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT x.*, ',
        '(SELECT CONCAT_WS('' · '', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT(''SERIE '', d.serie)) FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo JOIN marcas m ON m.id_marca = d.id_marca LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo WHERE d.id = x.id_disp_origen) AS equipo_origen, ',
        '(SELECT CONCAT_WS('' · '', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT(''SERIE '', d.serie)) FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo JOIN marcas m ON m.id_marca = d.id_marca LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo WHERE d.id = x.id_disp_destino) AS equipo_destino, ',
        '(SELECT CONCAT_WS('' '', u.nombre, u.apellido1, u.apellido2) FROM personas u WHERE u.usuario_red = x.usuario AND u.es_proveedor = FALSE LIMIT 1) AS persona ',
        'FROM (SELECT e.id_evento, e.id_importacion, e.fuente, e.fecha, e.tipo, e.accion, e.tipo_log, e.componente, e.subtipo, e.descripcion, e.dispositivo, e.id_mensaje, e.severidad, e.regla_id, e.regla_nombre, e.regla_seccion, e.nat_regla_id, e.nat_regla, e.politica_web, e.actividad, e.motivo, e.usuario, e.grupo_usuario, e.ip_origen, e.puerto_origen, e.mac_origen, e.pais_origen, e.zona_origen, e.interfaz_entrada, e.ip_origen_nat, e.nombre_equipo, e.sistema_operativo, e.ip_destino, e.puerto_destino, e.mac_destino, e.pais_destino, e.zona_destino, e.interfaz_salida, e.ip_destino_nat, e.dominio, e.url, e.categoria, e.categoria_tipo, e.codigo_http, e.tipo_contenido, e.navegador, e.aplicacion, e.aplicacion_categoria, e.aplicacion_riesgo, e.version_tls, e.cifrado, e.version_agente, e.vacunas_aplicadas, e.vacunas_pendientes, e.vacunas_error, e.protocolo, e.bytes_enviados, e.bytes_recibidos, e.paquetes_enviados, e.paquetes_recibidos, e.duracion, e.id_conexion, e.datos, ',
        'COALESCE((SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_origen ORDER BY q.id LIMIT 1), (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_origen LIMIT 1)) AS id_disp_origen, ',
        'COALESCE((SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_destino_nat ORDER BY q.id LIMIT 1), (SELECT q.id FROM dir_ips q WHERE q.dir_ip = e.ip_destino ORDER BY q.id LIMIT 1), (SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = e.mac_destino LIMIT 1)) AS id_disp_destino ',
        'FROM log_eventos e WHERE ', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro),
        ' ORDER BY e.id_evento LIMIT ', v_limite, ' OFFSET ', v_desplazamiento, ') x');
END$$

-- --------------------------------------------------------------------- cruce con el inventario
-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Cada IP que aparece en los eventos (origen, destino o traducida por NAT)
-- con cuántas veces, permitidos, denegados, y el equipo del inventario que
-- la tiene.
CREATE OR REPLACE PROCEDURE sp_log_inventario_ips(
    IN p_filtro LONGTEXT,
    IN p_limite INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 500), 1), 5000);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT y.*, ',
        '(SELECT CONCAT_WS('' · '', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT(''SERIE '', d.serie)) FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo JOIN marcas m ON m.id_marca = d.id_marca LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo WHERE d.id = y.id_disp) AS equipo, ',
        '(SELECT ed.descripcion FROM equipos d JOIN edificios ed ON ed.id_predio = d.id_predio WHERE d.id = y.id_disp) AS edificio ',
        'FROM (SELECT x.ip, COUNT(*) AS veces, SUM(x.lado = ''O'') AS como_origen, SUM(x.lado = ''D'') AS como_destino, ',
        'SUM(x.lado = ''N'') AS por_nat, ',
        'COALESCE(SUM(x.accion = ''PERMITIDO''), 0) AS permitidos, COALESCE(SUM(x.accion = ''DENEGADO''), 0) AS denegados, ',
        'MIN(x.fecha) AS primera, MAX(x.fecha) AS ultima, ',
        '(SELECT q.id FROM dir_ips q WHERE q.dir_ip = x.ip ORDER BY q.id LIMIT 1) AS id_disp ',
        'FROM (SELECT e.ip_origen AS ip, ''O'' AS lado, e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_origen IS NOT NULL ',
        'UNION ALL SELECT e.ip_destino, ''D'', e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_destino IS NOT NULL ',
        'UNION ALL SELECT e.ip_origen_nat, ''N'', e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_origen_nat IS NOT NULL ',
        'UNION ALL SELECT e.ip_destino_nat, ''N'', e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_destino_nat IS NOT NULL) x ',
        'GROUP BY x.ip ORDER BY id_disp IS NULL, veces DESC LIMIT ', v_limite, ') y');
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Cada MAC que aparece en los eventos y el equipo del inventario que la tiene
CREATE OR REPLACE PROCEDURE sp_log_inventario_macs(
    IN p_filtro LONGTEXT,
    IN p_limite INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 500), 1), 5000);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT y.*, ',
        '(SELECT CONCAT_WS('' · '', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT(''SERIE '', d.serie)) FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo JOIN marcas m ON m.id_marca = d.id_marca LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo WHERE d.id = y.id_disp) AS equipo ',
        'FROM (SELECT x.mac, COUNT(*) AS veces, SUM(x.lado = ''O'') AS como_origen, SUM(x.lado = ''D'') AS como_destino, ',
        'GROUP_CONCAT(DISTINCT x.ip ORDER BY x.ip SEPARATOR '', '') AS ips, ',
        'MIN(x.fecha) AS primera, MAX(x.fecha) AS ultima, ',
        '(SELECT qm.id FROM dir_macs qm WHERE qm.dir_mac = x.mac LIMIT 1) AS id_disp ',
        'FROM (SELECT e.mac_origen AS mac, e.ip_origen AS ip, ''O'' AS lado, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.mac_origen IS NOT NULL ',
        'UNION ALL SELECT e.mac_destino, e.ip_destino, ''D'', e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.mac_destino IS NOT NULL) x ',
        'GROUP BY x.mac ORDER BY id_disp IS NULL, veces DESC LIMIT ', v_limite, ') y');
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Usuarios de los logs y la persona del sistema que corresponde
CREATE OR REPLACE PROCEDURE sp_log_inventario_usuarios(
    IN p_filtro LONGTEXT,
    IN p_limite INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 500), 1), 5000);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT y.*, ',
        '(SELECT u.id FROM personas u WHERE u.usuario_red = y.usuario AND u.es_proveedor = FALSE LIMIT 1) AS id_persona, ',
        '(SELECT CONCAT_WS('' '', u.nombre, u.apellido1, u.apellido2) FROM personas u WHERE u.usuario_red = y.usuario AND u.es_proveedor = FALSE LIMIT 1) AS persona ',
        'FROM (SELECT e.usuario, COUNT(*) AS veces, ',
        'COALESCE(SUM(e.accion = ''PERMITIDO''), 0) AS permitidos, COALESCE(SUM(e.accion = ''DENEGADO''), 0) AS denegados, ',
        'COUNT(DISTINCT e.ip_origen) AS ips, MIN(e.fecha) AS primera, MAX(e.fecha) AS ultima ',
        'FROM log_eventos e WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.usuario IS NOT NULL ',
        'GROUP BY e.usuario ORDER BY veces DESC LIMIT ', v_limite, ') y');
END$$

-- --------------------------------------------------------------------- agentes (Microclaudia) y cobertura
-- Equipos de un listado de agentes (una importación de Microclaudia) con
-- todas sus IP y MAC.
CREATE OR REPLACE PROCEDURE sp_log_agentes_listar(
    IN p_id_importacion INT
)
BEGIN
    SELECT e.id_evento, e.nombre_equipo, e.sistema_operativo, e.version_agente, e.fecha AS ultima_conexion,
           e.vacunas_aplicadas, e.vacunas_pendientes, e.vacunas_error,
           e.ip_origen AS ip_principal, e.mac_origen AS mac_principal,
           JSON_VALUE(e.datos, '$.fecha_alta') AS fecha_alta,
           (SELECT GROUP_CONCAT(d.direccion ORDER BY INET_ATON(d.direccion), d.direccion SEPARATOR ',')
              FROM log_direcciones d WHERE d.id_evento = e.id_evento AND d.tipo = 'IP') AS ips,
           (SELECT GROUP_CONCAT(d.direccion ORDER BY d.direccion SEPARATOR ',')
              FROM log_direcciones d WHERE d.id_evento = e.id_evento AND d.tipo = 'MAC') AS macs
      FROM log_eventos e
     WHERE e.id_importacion = p_id_importacion
     ORDER BY e.nombre_equipo, e.id_evento;
END$$

-- p_filtro: condición sobre log_eventos (alias e). La arma Django a partir
-- del filtro que escribe el usuario (apps/logs/filtro.py): solo usa
-- columnas permitidas y los valores van escapados. Vacío = todos.
-- Cobertura del agente: cada IP interna (10.x, 172.16-31.x, 192.168.x) que
-- aparece en los eventos, con las MAC vistas con ella, el dispositivo del
-- inventario (por IP o MAC) y el equipo del listado de agentes
-- (p_id_agentes) que tiene esa IP o una de esas MAC.
CREATE OR REPLACE PROCEDURE sp_log_cobertura_ips(
    IN p_filtro     LONGTEXT,
    IN p_id_agentes INT,
    IN p_limite     INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 2000), 1), 10000);
    DECLARE v_agentes INT DEFAULT COALESCE(p_id_agentes, 0);
    EXECUTE IMMEDIATE CONCAT(
        'SELECT y.*, ',
        '(SELECT q.id FROM dir_ips q WHERE q.dir_ip = y.ip ORDER BY q.id LIMIT 1) AS id_disp_ip, ',
        '(SELECT qm.id FROM dir_macs qm WHERE FIND_IN_SET(qm.dir_mac, y.macs) LIMIT 1) AS id_disp_mac, ',
        '(SELECT a.nombre_equipo FROM log_direcciones d JOIN log_eventos a ON a.id_evento = d.id_evento ',
        'WHERE d.id_importacion = ', v_agentes, ' AND d.tipo = ''IP'' AND d.direccion = y.ip ',
        'ORDER BY a.fecha DESC LIMIT 1) AS agente_ip, ',
        '(SELECT a.nombre_equipo FROM log_direcciones d JOIN log_eventos a ON a.id_evento = d.id_evento ',
        'WHERE d.id_importacion = ', v_agentes, ' AND d.tipo = ''MAC'' AND FIND_IN_SET(d.direccion, y.macs) ',
        'ORDER BY a.fecha DESC LIMIT 1) AS agente_mac ',
        'FROM (SELECT x.ip, COUNT(*) AS veces, SUM(x.lado = ''O'') AS como_origen, SUM(x.lado = ''D'') AS como_destino, ',
        'COALESCE(SUM(x.accion = ''PERMITIDO''), 0) AS permitidos, COALESCE(SUM(x.accion = ''DENEGADO''), 0) AS denegados, ',
        'MIN(x.fecha) AS primera, MAX(x.fecha) AS ultima, ',
        'GROUP_CONCAT(DISTINCT x.mac ORDER BY x.mac SEPARATOR '','') AS macs ',
        'FROM (SELECT e.ip_origen AS ip, e.mac_origen AS mac, ''O'' AS lado, e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_origen IS NOT NULL ',
        'UNION ALL SELECT e.ip_destino, e.mac_destino, ''D'', e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_destino IS NOT NULL ',
        'UNION ALL SELECT e.ip_destino_nat, NULL, ''D'', e.accion, e.fecha FROM log_eventos e ',
        'WHERE (', IF(COALESCE(TRIM(p_filtro), '') = '', 'TRUE', p_filtro), ') AND e.ip_destino_nat IS NOT NULL) x ',
        'WHERE (x.ip LIKE ''10.%'' OR x.ip LIKE ''192.168.%'' OR INET_ATON(x.ip) BETWEEN 2886729728 AND 2887778303) ',
        'GROUP BY x.ip ORDER BY veces DESC, x.ip LIMIT ', v_limite, ') y');
END$$

-- Equipos activos del inventario con sus IP, MAC y nombre en la red, y
-- el equipo del listado de agentes (p_id_agentes) que comparte alguna de
-- ellas o se llama igual.
CREATE OR REPLACE PROCEDURE sp_log_cobertura_inventario(
    IN p_id_agentes INT
)
BEGIN
    SELECT y.*,
           (SELECT CONCAT_WS(' · ', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT('SERIE ', d.serie))
                  FROM equipos d
                  JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
                  JOIN marcas m ON m.id_marca = d.id_marca
                  LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo
                 WHERE d.id = y.id_disp) AS equipo,
           (SELECT ed.descripcion FROM edificios ed WHERE ed.id_predio = y.id_predio) AS edificio,
           COALESCE(
               (SELECT a.nombre_equipo FROM log_direcciones d JOIN log_eventos a ON a.id_evento = d.id_evento
                 WHERE d.id_importacion = COALESCE(p_id_agentes, 0)
                   AND ((d.tipo = 'IP' AND FIND_IN_SET(d.direccion, y.ips)) OR (d.tipo = 'MAC' AND FIND_IN_SET(d.direccion, y.macs)))
                 ORDER BY a.fecha DESC LIMIT 1),
               (SELECT a.nombre_equipo FROM log_eventos a
                 WHERE a.id_importacion = COALESCE(p_id_agentes, 0) AND y.nombre_equipo IS NOT NULL
                   AND UPPER(SUBSTRING_INDEX(a.nombre_equipo, '.', 1)) = y.nombre_corto
                 ORDER BY a.fecha DESC LIMIT 1)) AS agente
      FROM (SELECT d.id AS id_disp, d.id_predio, (d.id_estado <> 3) AS activo, t.descripcion AS tipo, d.serie,
                   EXISTS (SELECT 1 FROM herramientas h WHERE h.id = d.id AND h.id_herram = 3) AS tiene_microclaudia,
                   d.creado_en, d.actualizado_en,
                   t.id_categoria, c.descripcion AS categoria, c.lleva_agente,
                   d.nombre_equipo, UPPER(SUBSTRING_INDEX(d.nombre_equipo, '.', 1)) AS nombre_corto,
                   d.id_usuario AS id_asignado,
                   (SELECT CONCAT_WS(' ', u.nombre, u.apellido1, u.apellido2) FROM personas u
                     WHERE u.id = d.id_usuario) AS asignado,
                   (SELECT GROUP_CONCAT(q.dir_ip ORDER BY q.num_linea SEPARATOR ',')
                      FROM dir_ips q WHERE q.id = d.id) AS ips,
                   (SELECT GROUP_CONCAT(qm.dir_mac ORDER BY qm.num_linea SEPARATOR ',')
                      FROM dir_macs qm WHERE qm.id = d.id) AS macs
              FROM equipos d
              JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
              JOIN categoria_equipos c ON c.id_categoria = t.id_categoria
             WHERE d.id_estado <> 3) y
     ORDER BY agente IS NOT NULL, tipo, id_disp;
END$$

-- --------------------------------------------------------------------- DHCP e intrusos
-- Concesiones y reservas de una importación del DHCP, ordenadas por IP.
CREATE OR REPLACE PROCEDURE sp_log_dhcp_listar(
    IN p_id_importacion INT
)
BEGIN
    SELECT e.id_evento, e.tipo, e.fecha AS expira, e.ip_origen AS ip, e.mac_origen AS mac,
           e.nombre_equipo AS nombre, e.descripcion,
           JSON_VALUE(e.datos, '$.tipo') AS tipo_cliente,
           JSON_VALUE(e.datos, '$.id_exclusivo') AS id_exclusivo
      FROM log_eventos e
     WHERE e.id_importacion = p_id_importacion
     ORDER BY INET_ATON(e.ip_origen), e.id_evento;
END$$

-- Todos los dispositivos registrados (activos e inactivos) con sus IP y MAC,
-- para compararlos con la red: una MAC de un equipo dado de baja que
-- aparece en el DHCP también es una alerta.
CREATE OR REPLACE PROCEDURE sp_log_red_inventario()
BEGIN
    SELECT y.*,
           (SELECT CONCAT_WS(' · ', t.descripcion, COALESCE(mo.descripcion, m.descripcion), d.nombre_equipo, CONCAT('SERIE ', d.serie))
                  FROM equipos d
                  JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
                  JOIN marcas m ON m.id_marca = d.id_marca
                  LEFT JOIN modelos mo ON mo.id_modelo = d.id_modelo
                 WHERE d.id = y.id_disp) AS equipo,
           (SELECT ed.descripcion FROM edificios ed WHERE ed.id_predio = y.id_predio) AS edificio
      FROM (SELECT d.id AS id_disp, d.id_predio, (d.id_estado <> 3) AS activo, t.descripcion AS tipo, d.serie,
                   EXISTS (SELECT 1 FROM herramientas h WHERE h.id = d.id AND h.id_herram = 3) AS tiene_microclaudia,
                   d.creado_en, d.actualizado_en,
                   t.id_categoria, c.descripcion AS categoria, c.lleva_agente,
                   d.nombre_equipo, UPPER(SUBSTRING_INDEX(d.nombre_equipo, '.', 1)) AS nombre_corto,
                   d.id_usuario AS id_asignado,
                   (SELECT CONCAT_WS(' ', u.nombre, u.apellido1, u.apellido2) FROM personas u
                     WHERE u.id = d.id_usuario) AS asignado,
                   (SELECT GROUP_CONCAT(q.dir_ip ORDER BY q.num_linea SEPARATOR ',')
                      FROM dir_ips q WHERE q.id = d.id) AS ips,
                   (SELECT GROUP_CONCAT(qm.dir_mac ORDER BY qm.num_linea SEPARATOR ',')
                      FROM dir_macs qm WHERE qm.id = d.id) AS macs
              FROM equipos d
              JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
              JOIN categoria_equipos c ON c.id_categoria = t.id_categoria) y
     ORDER BY y.activo DESC, y.tipo, y.id_disp;
END$$

-- --------------------------------------------------------------------- log_mapeo_campos
CREATE OR REPLACE PROCEDURE sp_log_mapeo_campos_validar(
    IN p_campo_origen VARCHAR(64),
    IN p_campo        VARCHAR(64)
)
BEGIN
    IF p_campo_origen IS NULL OR TRIM(p_campo_origen) = '' OR TRIM(p_campo_origen) NOT REGEXP '^[A-Za-z_][A-Za-z0-9_.-]*$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El nombre en el log solo lleva letras, números, punto, guion o guion bajo.';
    END IF;
    IF p_campo IN ('id_evento', 'id_importacion', 'fuente', 'huella', 'datos', 'fecha', 'tipo', 'accion')
       OR NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS
                       WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'log_eventos' AND COLUMN_NAME = p_campo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese campo común no se puede asignar.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_log_mapeo_campos_insertar(
    IN p_fuente       VARCHAR(30),
    IN p_campo_origen VARCHAR(64),
    IN p_campo        VARCHAR(64),
    IN p_prioridad    SMALLINT
)
BEGIN
    CALL sp_log_mapeo_campos_validar(p_campo_origen, p_campo);
    INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    VALUES (p_fuente, p_campo_origen, p_campo, COALESCE(p_prioridad, 1));
END$$

CREATE OR REPLACE PROCEDURE sp_log_mapeo_campos_actualizar(
    IN p_fuente       VARCHAR(30),
    IN p_campo_origen VARCHAR(64),
    IN p_campo        VARCHAR(64),
    IN p_prioridad    SMALLINT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = p_fuente AND campo_origen = p_campo_origen) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El alias no existe.';
    END IF;
    CALL sp_log_mapeo_campos_validar(p_campo_origen, p_campo);
    UPDATE log_mapeo_campos
       SET campo = p_campo, prioridad = COALESCE(p_prioridad, 1)
     WHERE fuente = p_fuente AND campo_origen = p_campo_origen;
END$$

CREATE OR REPLACE PROCEDURE sp_log_mapeo_campos_eliminar(
    IN p_fuente       VARCHAR(30),
    IN p_campo_origen VARCHAR(64)
)
BEGIN
    DELETE FROM log_mapeo_campos WHERE fuente = p_fuente AND campo_origen = p_campo_origen;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El alias no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_log_mapeo_campos_obtener(
    IN p_fuente       VARCHAR(30),
    IN p_campo_origen VARCHAR(64)
)
BEGIN
    SELECT m.fuente, m.campo_origen, m.campo, m.prioridad
      FROM log_mapeo_campos m
     WHERE m.fuente = p_fuente AND m.campo_origen = p_campo_origen;
END$$

CREATE OR REPLACE PROCEDURE sp_log_mapeo_campos_listar(
    IN p_fuente VARCHAR(30)
)
BEGIN
    SELECT m.fuente, m.campo_origen, m.campo, m.prioridad
      FROM log_mapeo_campos m
     WHERE p_fuente IS NULL OR m.fuente = p_fuente
     ORDER BY m.fuente, m.campo, m.prioridad, m.campo_origen;
END$$

-- =====================================================================
-- 2. DISPARADORES: FORMATO DE LOS ALIAS Y AUDITORÍA
-- =====================================================================

-- Los alias se guardan como los escribe el log: en minúscula. La fuente
-- (SOPHOS) en mayúscula.
DROP TRIGGER IF EXISTS trg_formato_log_mapeo_campos_ins$$
CREATE TRIGGER trg_formato_log_mapeo_campos_ins BEFORE INSERT ON log_mapeo_campos FOR EACH ROW
BEGIN
    SET NEW.fuente = UPPER(TRIM(NEW.fuente));
    SET NEW.campo_origen = LOWER(TRIM(NEW.campo_origen));
    SET NEW.campo = LOWER(TRIM(NEW.campo));
END$$

DROP TRIGGER IF EXISTS trg_formato_log_mapeo_campos_upd$$
CREATE TRIGGER trg_formato_log_mapeo_campos_upd BEFORE UPDATE ON log_mapeo_campos FOR EACH ROW
BEGIN
    SET NEW.fuente = UPPER(TRIM(NEW.fuente));
    SET NEW.campo_origen = LOWER(TRIM(NEW.campo_origen));
    SET NEW.campo = LOWER(TRIM(NEW.campo));
END$$

-- Auditoría: quién importó y quién borró cada archivo de logs (los eventos
-- no se auditan uno por uno: serían millones de filas) y los cambios a los
-- alias de los campos.

-- --------------------------------------------------------- log_importaciones
DROP TRIGGER IF EXISTS trg_aud_log_importaciones_ins$$
CREATE TRIGGER trg_aud_log_importaciones_ins AFTER INSERT ON log_importaciones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'log_importaciones',
                NEW.id_importacion, NULL, LEFT(CONCAT(NEW.fuente, ': ', NEW.nombre_archivo), 255),
                JSON_OBJECT('id_importacion', NEW.id_importacion, 'fuente', NEW.fuente, 'nombre_archivo', NEW.nombre_archivo, 'descripcion', NEW.descripcion, 'total_eventos', NEW.total_eventos));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_log_importaciones_del$$
CREATE TRIGGER trg_aud_log_importaciones_del AFTER DELETE ON log_importaciones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'log_importaciones',
                OLD.id_importacion, NULL, LEFT(CONCAT(OLD.fuente, ': ', OLD.nombre_archivo), 255),
                JSON_OBJECT('id_importacion', OLD.id_importacion, 'fuente', OLD.fuente, 'nombre_archivo', OLD.nombre_archivo, 'descripcion', OLD.descripcion, 'total_eventos', OLD.total_eventos));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_log_importaciones_upd$$
-- --------------------------------------------------------- log_mapeo_campos
DROP TRIGGER IF EXISTS trg_aud_log_mapeo_campos_ins$$
CREATE TRIGGER trg_aud_log_mapeo_campos_ins AFTER INSERT ON log_mapeo_campos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'log_mapeo_campos',
                CONCAT(NEW.fuente, '/', NEW.campo_origen), NULL, LEFT(CONCAT(NEW.campo_origen, ' -> ', NEW.campo), 255),
                JSON_OBJECT('fuente', NEW.fuente, 'campo_origen', NEW.campo_origen, 'campo', NEW.campo, 'prioridad', NEW.prioridad));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_log_mapeo_campos_upd$$
CREATE TRIGGER trg_aud_log_mapeo_campos_upd AFTER UPDATE ON log_mapeo_campos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('fuente', OLD.fuente, 'campo_origen', OLD.campo_origen, 'campo', OLD.campo, 'prioridad', OLD.prioridad);
        SET v_despues = JSON_OBJECT('fuente', NEW.fuente, 'campo_origen', NEW.campo_origen, 'campo', NEW.campo, 'prioridad', NEW.prioridad);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'log_mapeo_campos',
                    CONCAT(NEW.fuente, '/', NEW.campo_origen), NULL, LEFT(CONCAT(NEW.campo_origen, ' -> ', NEW.campo), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_log_mapeo_campos_del$$
CREATE TRIGGER trg_aud_log_mapeo_campos_del AFTER DELETE ON log_mapeo_campos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'log_mapeo_campos',
                CONCAT(OLD.fuente, '/', OLD.campo_origen), NULL, LEFT(CONCAT(OLD.campo_origen, ' -> ', OLD.campo), 255),
                JSON_OBJECT('fuente', OLD.fuente, 'campo_origen', OLD.campo_origen, 'campo', OLD.campo, 'prioridad', OLD.prioridad));
    END IF;
END$$

DELIMITER ;
