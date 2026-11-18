-- =====================================================================
--  procedimientosCorreo.sql - módulo de correo institucional
--  gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 2 de 2. Contiene 23 procedimientos y 10 disparadores.
--
--  Orden de instalación (después de los scripts de instalacion; los
--  ejecuta reinstalar_base.sh en orden):
--     1. creacionCorreo.sql         tablas
--     2. procedimientosCorreo.sql   procedimientos y disparadores
--  Se pueden ejecutar más de una vez sin duplicar ni borrar nada.
-- =====================================================================

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base, con el programa que sea que lo ejecute: así
-- las tildes se guardan bien y nada mezcla intercalaciones distintas.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;

SET SESSION sql_mode = 'STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DELIMITER $$

-- =====================================================================
-- 1. PROCEDIMIENTOS
-- =====================================================================

-- --------------------------------------------------------------------- configuración
CREATE OR REPLACE PROCEDURE sp_cor_configuracion_obtener()
BEGIN
    SELECT c.*, CONCAT_WS(' ', u.nombre, u.apellido1) AS actualizado_por
      FROM cor_configuracion c
      LEFT JOIN personas u ON u.id = c.id_usuario
     WHERE c.id_config = 1;
END$$

-- Guarda la cuenta institucional. p_cambiar_clave = FALSE conserva la clave
-- guardada; TRUE la cambia por p_clave_cifrada (NULL = sin clave). Si cambia
-- el servidor, el puerto, la seguridad, el usuario o la clave, la última
-- prueba deja de valer.
CREATE OR REPLACE PROCEDURE sp_cor_configuracion_guardar(
    IN p_servidor         VARCHAR(150),
    IN p_puerto           INT,
    IN p_seguridad        VARCHAR(10),
    IN p_usuario          VARCHAR(150),
    IN p_cambiar_clave    BOOLEAN,
    IN p_clave_cifrada    VARCHAR(1000),
    IN p_correo_remitente VARCHAR(150),
    IN p_nombre_remitente VARCHAR(150),
    IN p_responder_a      VARCHAR(150),
    IN p_firma            TEXT,
    IN p_limite_diario    INT,
    IN p_activo           BOOLEAN,
    IN p_id_usuario       INT
)
BEGIN
    DECLARE v_usuario VARCHAR(150) DEFAULT NULLIF(TRIM(p_usuario), '');
    DECLARE v_responder VARCHAR(150) DEFAULT NULLIF(LOWER(TRIM(p_responder_a)), '');
    DECLARE v_seguridad VARCHAR(10) DEFAULT UPPER(TRIM(p_seguridad));

    IF p_servidor IS NULL OR TRIM(p_servidor) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique el servidor de correo (SMTP).';
    END IF;
    IF p_puerto IS NULL OR p_puerto < 1 OR p_puerto > 65535 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El puerto debe ser un número entre 1 y 65535.';
    END IF;
    IF v_seguridad NOT IN ('STARTTLS', 'SSL', 'NINGUNA') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La seguridad debe ser STARTTLS, SSL o NINGUNA.';
    END IF;
    IF p_correo_remitente IS NULL OR TRIM(p_correo_remitente) NOT REGEXP '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo del remitente no es válido.';
    END IF;
    IF v_responder IS NOT NULL AND v_responder NOT REGEXP '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo para las respuestas no es válido.';
    END IF;
    IF p_limite_diario IS NULL OR p_limite_diario < 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El límite diario debe ser mayor que cero.';
    END IF;

    IF EXISTS (SELECT 1 FROM cor_configuracion WHERE id_config = 1) THEN
        -- MariaDB asigna de izquierda a derecha: la prueba se revisa antes
        -- de cambiar los datos de la conexión
        UPDATE cor_configuracion
           SET prueba_ok        = IF(servidor <=> TRIM(p_servidor) AND puerto <=> p_puerto AND seguridad <=> v_seguridad
                                     AND usuario <=> v_usuario AND NOT COALESCE(p_cambiar_clave, FALSE), prueba_ok, NULL),
               resultado_prueba = IF(prueba_ok IS NULL AND ultima_prueba IS NOT NULL,
                                     'Cambió la conexión: vuelva a enviar el correo de prueba.', resultado_prueba),
               servidor         = TRIM(p_servidor),
               puerto           = p_puerto,
               seguridad        = v_seguridad,
               usuario          = v_usuario,
               clave_cifrada    = IF(COALESCE(p_cambiar_clave, FALSE), NULLIF(p_clave_cifrada, ''), clave_cifrada),
               correo_remitente = LOWER(TRIM(p_correo_remitente)),
               nombre_remitente = NULLIF(TRIM(p_nombre_remitente), ''),
               responder_a      = v_responder,
               firma            = NULLIF(TRIM(p_firma), ''),
               limite_diario    = p_limite_diario,
               activo           = COALESCE(p_activo, TRUE),
               id_usuario       = p_id_usuario
         WHERE id_config = 1;
    ELSE
        INSERT INTO cor_configuracion (id_config, servidor, puerto, seguridad, usuario, clave_cifrada, correo_remitente,
                                       nombre_remitente, responder_a, firma, limite_diario, activo, id_usuario)
        VALUES (1, TRIM(p_servidor), p_puerto, v_seguridad, v_usuario,
                IF(COALESCE(p_cambiar_clave, FALSE), NULLIF(p_clave_cifrada, ''), NULL),
                LOWER(TRIM(p_correo_remitente)), NULLIF(TRIM(p_nombre_remitente), ''), v_responder,
                NULLIF(TRIM(p_firma), ''), p_limite_diario, COALESCE(p_activo, TRUE), p_id_usuario);
    END IF;
END$$

-- Resultado del último correo de prueba (no se audita: no cambia la cuenta)
CREATE OR REPLACE PROCEDURE sp_cor_configuracion_resultado_prueba(
    IN p_ok        BOOLEAN,
    IN p_resultado VARCHAR(255)
)
BEGIN
    UPDATE cor_configuracion
       SET ultima_prueba = NOW(), prueba_ok = p_ok, resultado_prueba = LEFT(p_resultado, 255)
     WHERE id_config = 1;
END$$

-- --------------------------------------------------------------------- personal
-- El personal (no proveedores) con todos sus correos: «correo|TIPO»
-- separados por punto y coma, primero los institucionales.
-- p_solo_activos: TRUE = solo activos; FALSE o NULL = todos.
CREATE OR REPLACE PROCEDURE sp_cor_personal_listar(
    IN p_solo_activos BOOLEAN
)
BEGIN
    SELECT u.id, u.nombre, u.apellido1, u.apellido2,
           CONCAT_WS(' ', u.nombre, u.apellido1, u.apellido2) AS nombre_completo,
           u.cod_departamento, d.descripcion AS departamento, u.activo, u.usuario_red,
           (SELECT GROUP_CONCAT(CONCAT(c.correo, '|', COALESCE(t.descripcion, ''))
                                ORDER BY COALESCE(t.descripcion, '') = 'INSTITUCIONAL' DESC, c.num_linea SEPARATOR ';')
              FROM usr_correos c
              LEFT JOIN cat_tipos_correos t ON t.cod_correo = c.cod_correo
             WHERE c.id_usuario = u.id) AS correos
      FROM personas u
      LEFT JOIN cat_departamentos d ON d.cod_departamento = u.cod_departamento
     WHERE u.es_proveedor = FALSE
       AND (NOT COALESCE(p_solo_activos, FALSE) OR u.activo = TRUE)
     ORDER BY u.nombre, u.apellido1, u.apellido2, u.id;
END$$

-- --------------------------------------------------------------------- envíos
-- Crea un aviso con sus destinatarios. p_lista es un JSON:
--   [{"p": 5, "n": "ANA MORA", "c": "ana.mora@grecia.go.cr"}, ...]
-- (p = id de la persona, n = nombre, c = correo). Un correo repetido se
-- guarda una sola vez. No abre transacción: Django crea el aviso, sus
-- destinatarios y sus adjuntos en una sola.
CREATE OR REPLACE PROCEDURE sp_cor_envios_insertar(
    IN  p_asunto        VARCHAR(200),
    IN  p_mensaje       TEXT,
    IN  p_destinatarios VARCHAR(255),
    IN  p_remitente     VARCHAR(255),
    IN  p_id_usuario    INT,
    IN  p_lista         LONGTEXT,
    OUT p_id_envio      INT
)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_linea INT DEFAULT 0;
    DECLARE v_correo VARCHAR(150);

    IF p_asunto IS NULL OR TRIM(p_asunto) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Escriba el asunto del aviso.';
    END IF;
    IF p_mensaje IS NULL OR TRIM(p_mensaje) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Escriba el mensaje del aviso.';
    END IF;
    IF p_lista IS NULL OR NOT JSON_VALID(p_lista) OR COALESCE(JSON_LENGTH(p_lista), 0) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Elija al menos un destinatario con correo.';
    END IF;

    -- total: los que trae la lista (al final queda el número exacto, sin repetidos)
    INSERT INTO cor_envios (asunto, mensaje, destinatarios, remitente, total, id_usuario)
    VALUES (TRIM(p_asunto), p_mensaje, LEFT(p_destinatarios, 255), LEFT(p_remitente, 255), JSON_LENGTH(p_lista), p_id_usuario);
    SET p_id_envio = LAST_INSERT_ID();

    SET v_n = JSON_LENGTH(p_lista);
    WHILE v_i < v_n DO
        SET v_correo = LOWER(TRIM(JSON_VALUE(p_lista, CONCAT('$[', v_i, '].c'))));
        IF v_correo REGEXP '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
           AND NOT EXISTS (SELECT 1 FROM cor_envios_destinatarios WHERE id_envio = p_id_envio AND correo = v_correo) THEN
            SET v_linea = v_linea + 1;
            INSERT INTO cor_envios_destinatarios (id_envio, num_linea, id_persona, nombre, correo)
            VALUES (p_id_envio, v_linea,
                    (SELECT u.id FROM personas u WHERE u.id = JSON_VALUE(p_lista, CONCAT('$[', v_i, '].p'))),
                    LEFT(JSON_VALUE(p_lista, CONCAT('$[', v_i, '].n')), 255), v_correo);
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    IF v_linea = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ninguno de los destinatarios tiene un correo válido.';
    END IF;
    UPDATE cor_envios SET total = v_linea WHERE id_envio = p_id_envio;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_envios_adjuntos_insertar(
    IN p_id_envio       INT,
    IN p_nombre_archivo VARCHAR(255),
    IN p_ruta           VARCHAR(255),
    IN p_tamano         BIGINT,
    IN p_tipo           VARCHAR(100)
)
BEGIN
    INSERT INTO cor_envios_adjuntos (id_envio, num_linea, nombre_archivo, ruta, tamano, tipo)
    SELECT p_id_envio, COALESCE(MAX(num_linea), 0) + 1, LEFT(p_nombre_archivo, 255), p_ruta, COALESCE(p_tamano, 0), p_tipo
      FROM cor_envios_adjuntos
     WHERE id_envio = p_id_envio;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_envios_adjuntos_listar(
    IN p_id_envio INT
)
BEGIN
    SELECT a.id_envio, a.num_linea, a.nombre_archivo, a.ruta, a.tamano, a.tipo
      FROM cor_envios_adjuntos a
     WHERE a.id_envio = p_id_envio
     ORDER BY a.num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_envios_obtener(
    IN p_id_envio INT
)
BEGIN
    SELECT e.*, CONCAT_WS(' ', u.nombre, u.apellido1) AS enviado_por,
           (SELECT COUNT(*) FROM cor_envios_destinatarios x WHERE x.id_envio = e.id_envio AND x.estado = 'PENDIENTE') AS pendientes,
           (SELECT COUNT(*) FROM cor_envios_destinatarios x WHERE x.id_envio = e.id_envio AND x.estado = 'CANCELADO') AS cancelados,
           (SELECT COUNT(*) FROM cor_envios_adjuntos a WHERE a.id_envio = e.id_envio) AS adjuntos
      FROM cor_envios e
      LEFT JOIN personas u ON u.id = e.id_usuario
     WHERE e.id_envio = p_id_envio;
END$$

-- p_buscar: texto en el asunto o en el mensaje (NULL = todos)
CREATE OR REPLACE PROCEDURE sp_cor_envios_listar(
    IN p_buscar VARCHAR(150)
)
BEGIN
    SELECT e.id_envio, e.asunto, LEFT(e.mensaje, 300) AS extracto, e.destinatarios, e.remitente, e.estado,
           e.total, e.enviados, e.errores, e.creado_en, e.terminado_en, e.id_usuario,
           CONCAT_WS(' ', u.nombre, u.apellido1) AS enviado_por,
           (SELECT COUNT(*) FROM cor_envios_adjuntos a WHERE a.id_envio = e.id_envio) AS adjuntos
      FROM cor_envios e
      LEFT JOIN personas u ON u.id = e.id_usuario
     WHERE p_buscar IS NULL OR TRIM(p_buscar) = ''
        OR e.asunto LIKE CONCAT('%', TRIM(p_buscar), '%') OR e.mensaje LIKE CONCAT('%', TRIM(p_buscar), '%')
     ORDER BY e.id_envio DESC;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_envios_destinatarios_listar(
    IN p_id_envio INT
)
BEGIN
    SELECT x.id_envio, x.num_linea, x.id_persona, x.nombre, x.correo, x.estado, x.error, x.enviado_en,
           d.descripcion AS departamento
      FROM cor_envios_destinatarios x
      LEFT JOIN personas u ON u.id = x.id_persona
      LEFT JOIN cat_departamentos d ON d.cod_departamento = u.cod_departamento
     WHERE x.id_envio = p_id_envio
     ORDER BY FIELD(x.estado, 'ERROR', 'PENDIENTE', 'CANCELADO', 'ENVIADO'), x.nombre, x.num_linea;
END$$

-- Los siguientes destinatarios por enviar (de a p_limite). Si el aviso
-- estaba PENDIENTE pasa a ENVIANDO.
CREATE OR REPLACE PROCEDURE sp_cor_envios_pendientes(
    IN p_id_envio INT,
    IN p_limite   INT
)
BEGIN
    UPDATE cor_envios SET estado = 'ENVIANDO' WHERE id_envio = p_id_envio AND estado = 'PENDIENTE';
    SELECT x.num_linea, x.id_persona, x.nombre, x.correo
      FROM cor_envios_destinatarios x
     WHERE x.id_envio = p_id_envio AND x.estado = 'PENDIENTE'
     ORDER BY x.num_linea
     LIMIT p_limite;
END$$

-- Vuelve a contar enviados y errores y deja el estado del aviso al día.
CREATE OR REPLACE PROCEDURE sp_cor_envios_recalcular(
    IN p_id_envio INT
)
BEGIN
    DECLARE v_enviados INT;
    DECLARE v_errores INT;
    DECLARE v_pendientes INT;
    DECLARE v_cancelados INT;
    SELECT COALESCE(SUM(estado = 'ENVIADO'), 0), COALESCE(SUM(estado = 'ERROR'), 0),
           COALESCE(SUM(estado = 'PENDIENTE'), 0), COALESCE(SUM(estado = 'CANCELADO'), 0)
      INTO v_enviados, v_errores, v_pendientes, v_cancelados
      FROM cor_envios_destinatarios
     WHERE id_envio = p_id_envio;
    UPDATE cor_envios
       SET enviados = v_enviados,
           errores = v_errores,
           estado = CASE
                        WHEN v_pendientes > 0 THEN IF(v_enviados + v_errores + v_cancelados = 0 AND estado = 'PENDIENTE', 'PENDIENTE', 'ENVIANDO')
                        WHEN v_errores > 0 THEN 'CON_ERRORES'
                        WHEN v_cancelados > 0 THEN 'CANCELADO'
                        ELSE 'ENVIADO'
                    END,
           terminado_en = IF(v_pendientes > 0, NULL, COALESCE(terminado_en, NOW()))
     WHERE id_envio = p_id_envio;
END$$

-- Resultado de un destinatario: p_ok = TRUE (enviado) o FALSE (p_error)
CREATE OR REPLACE PROCEDURE sp_cor_envios_marcar(
    IN p_id_envio  INT,
    IN p_num_linea INT,
    IN p_ok        BOOLEAN,
    IN p_error     VARCHAR(255)
)
BEGIN
    UPDATE cor_envios_destinatarios
       SET estado = IF(p_ok, 'ENVIADO', 'ERROR'),
           error = IF(p_ok, NULL, LEFT(COALESCE(p_error, 'No se pudo enviar.'), 255)),
           enviado_en = IF(p_ok, NOW(), NULL)
     WHERE id_envio = p_id_envio AND num_linea = p_num_linea AND estado = 'PENDIENTE';
    CALL sp_cor_envios_recalcular(p_id_envio);
END$$

-- Vuelve a poner por enviar los que dieron error o se cancelaron
CREATE OR REPLACE PROCEDURE sp_cor_envios_reintentar(
    IN p_id_envio INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cor_envios WHERE id_envio = p_id_envio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El aviso no existe.';
    END IF;
    UPDATE cor_envios_destinatarios SET estado = 'PENDIENTE', error = NULL
     WHERE id_envio = p_id_envio AND estado IN ('ERROR', 'CANCELADO');
    CALL sp_cor_envios_recalcular(p_id_envio);
END$$

-- Detiene el envío: los que faltan quedan cancelados
CREATE OR REPLACE PROCEDURE sp_cor_envios_cancelar(
    IN p_id_envio INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cor_envios WHERE id_envio = p_id_envio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El aviso no existe.';
    END IF;
    UPDATE cor_envios_destinatarios SET estado = 'CANCELADO'
     WHERE id_envio = p_id_envio AND estado = 'PENDIENTE';
    CALL sp_cor_envios_recalcular(p_id_envio);
END$$

-- Solo se puede borrar un aviso que no le llegó a nadie (lo enviado queda
-- en el historial)
CREATE OR REPLACE PROCEDURE sp_cor_envios_eliminar(
    IN p_id_envio INT
)
BEGIN
    IF EXISTS (SELECT 1 FROM cor_envios_destinatarios WHERE id_envio = p_id_envio AND estado = 'ENVIADO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Este aviso ya se le envió a alguien: queda en el historial y no se puede eliminar.';
    END IF;
    DELETE FROM cor_envios WHERE id_envio = p_id_envio;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El aviso no existe.';
    END IF;
END$$

-- Correos enviados hoy (para el límite diario de la cuenta)
CREATE OR REPLACE PROCEDURE sp_cor_enviados_hoy()
BEGIN
    SELECT COUNT(*) AS total
      FROM cor_envios_destinatarios
     WHERE estado = 'ENVIADO' AND enviado_en >= CURDATE();
END$$

-- --------------------------------------------------------------------- listas de correos
-- Guarda una lista importada. p_origen: GOOGLE, SOPHOS u OTRA.
-- p_correos es un JSON:
--   [{"c": "ana.mora@grecia.go.cr", "n": "Ana", "a": "Mora Solís", "e": "Active",
--     "u": "2026-10-15 14:21:00", "x": 0, "g": 12.5}, ...]
-- u = último acceso, x = 1 si nunca ha iniciado sesión, g = uso en GB
-- (los tres opcionales). Un correo repetido se guarda una sola vez.
CREATE OR REPLACE PROCEDURE sp_cor_listas_insertar(
    IN  p_nombre_archivo VARCHAR(255),
    IN  p_descripcion    VARCHAR(255),
    IN  p_dominio        VARCHAR(150),
    IN  p_id_usuario     INT,
    IN  p_origen         VARCHAR(10),
    IN  p_correos        LONGTEXT,
    OUT p_id_lista       INT
)
BEGIN
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_n INT DEFAULT 0;
    DECLARE v_linea INT DEFAULT 0;
    DECLARE v_correo VARCHAR(150);

    IF p_correos IS NULL OR NOT JSON_VALID(p_correos) OR COALESCE(JSON_LENGTH(p_correos), 0) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista no trae correos.';
    END IF;
    INSERT INTO cor_listas (origen, nombre_archivo, descripcion, dominio, total, id_usuario)
    VALUES (IF(UPPER(p_origen) IN ('GOOGLE', 'SOPHOS'), UPPER(p_origen), 'OTRA'),
            LEFT(COALESCE(NULLIF(TRIM(p_nombre_archivo), ''), 'sin nombre'), 255), NULLIF(TRIM(p_descripcion), ''),
            NULLIF(LOWER(TRIM(p_dominio)), ''), JSON_LENGTH(p_correos), p_id_usuario);
    SET p_id_lista = LAST_INSERT_ID();

    SET v_n = JSON_LENGTH(p_correos);
    WHILE v_i < v_n DO
        SET v_correo = LOWER(TRIM(JSON_VALUE(p_correos, CONCAT('$[', v_i, '].c'))));
        IF v_correo REGEXP '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$'
           AND NOT EXISTS (SELECT 1 FROM cor_listas_correos WHERE id_lista = p_id_lista AND correo = v_correo) THEN
            SET v_linea = v_linea + 1;
            INSERT INTO cor_listas_correos (id_lista, num_linea, correo, nombre, apellidos, estado,
                                            ultimo_acceso, nunca_entro, uso_gb)
            VALUES (p_id_lista, v_linea, v_correo,
                    NULLIF(LEFT(TRIM(JSON_VALUE(p_correos, CONCAT('$[', v_i, '].n'))), 150), ''),
                    NULLIF(LEFT(TRIM(JSON_VALUE(p_correos, CONCAT('$[', v_i, '].a'))), 150), ''),
                    NULLIF(LEFT(TRIM(JSON_VALUE(p_correos, CONCAT('$[', v_i, '].e'))), 30), ''),
                    STR_TO_DATE(JSON_VALUE(p_correos, CONCAT('$[', v_i, '].u')), '%Y-%m-%d %H:%i:%s'),
                    CASE JSON_VALUE(p_correos, CONCAT('$[', v_i, '].x')) WHEN '1' THEN TRUE WHEN '0' THEN FALSE END,
                    CAST(JSON_VALUE(p_correos, CONCAT('$[', v_i, '].g')) AS DECIMAL(10,2)));
        END IF;
        SET v_i = v_i + 1;
    END WHILE;

    IF v_linea = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista no trae ningún correo válido.';
    END IF;
    UPDATE cor_listas SET total = v_linea WHERE id_lista = p_id_lista;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_listas_obtener(
    IN p_id_lista INT
)
BEGIN
    SELECT l.*, CONCAT_WS(' ', u.nombre, u.apellido1) AS importado_por
      FROM cor_listas l
      LEFT JOIN personas u ON u.id = l.id_usuario
     WHERE l.id_lista = p_id_lista;
END$$

-- p_origen: GOOGLE, SOPHOS u OTRA; NULL = todas
CREATE OR REPLACE PROCEDURE sp_cor_listas_listar(
    IN p_origen VARCHAR(10)
)
BEGIN
    SELECT l.*, CONCAT_WS(' ', u.nombre, u.apellido1) AS importado_por
      FROM cor_listas l
      LEFT JOIN personas u ON u.id = l.id_usuario
     WHERE p_origen IS NULL OR p_origen = '' OR l.origen = p_origen
     ORDER BY l.id_lista DESC;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_listas_correos_listar(
    IN p_id_lista INT
)
BEGIN
    SELECT c.num_linea, c.correo, c.nombre, c.apellidos, c.estado, c.ultimo_acceso, c.nunca_entro, c.uso_gb
      FROM cor_listas_correos c
     WHERE c.id_lista = p_id_lista
     ORDER BY c.num_linea;
END$$

-- Solo se cambia la descripción
CREATE OR REPLACE PROCEDURE sp_cor_listas_actualizar(
    IN p_id_lista    INT,
    IN p_descripcion VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cor_listas WHERE id_lista = p_id_lista) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista no existe.';
    END IF;
    UPDATE cor_listas SET descripcion = NULLIF(TRIM(p_descripcion), '') WHERE id_lista = p_id_lista;
END$$

CREATE OR REPLACE PROCEDURE sp_cor_listas_eliminar(
    IN p_id_lista INT
)
BEGIN
    DELETE FROM cor_listas WHERE id_lista = p_id_lista;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista no existe.';
    END IF;
END$$

-- =====================================================================
-- 2. DISPARADORES: FORMATO Y AUDITORÍA
-- =====================================================================

-- Los correos se guardan en minúscula y sin espacios
DROP TRIGGER IF EXISTS trg_formato_cor_envios_destinatarios_ins$$
CREATE TRIGGER trg_formato_cor_envios_destinatarios_ins BEFORE INSERT ON cor_envios_destinatarios FOR EACH ROW
BEGIN
    SET NEW.correo = LOWER(TRIM(NEW.correo));
END$$

DROP TRIGGER IF EXISTS trg_formato_cor_listas_correos_ins$$
CREATE TRIGGER trg_formato_cor_listas_correos_ins BEFORE INSERT ON cor_listas_correos FOR EACH ROW
BEGIN
    SET NEW.correo = LOWER(TRIM(NEW.correo));
END$$

-- Auditoría: la cuenta institucional (sin la clave), cada aviso (cuando se
-- crea, cuando cambia de estado y si se elimina) y las listas importadas
-- (al importarlas, al cambiar su descripción y al eliminarlas). Los
-- destinatarios no se auditan uno por uno: el aviso guarda el total.

-- --------------------------------------------------------- cor_configuracion
DROP TRIGGER IF EXISTS trg_aud_cor_configuracion_ins$$
CREATE TRIGGER trg_aud_cor_configuracion_ins AFTER INSERT ON cor_configuracion FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cor_configuracion',
                NEW.id_config, NULL, LEFT(NEW.correo_remitente, 255),
                JSON_OBJECT('servidor', NEW.servidor, 'puerto', NEW.puerto, 'seguridad', NEW.seguridad, 'usuario', NEW.usuario, 'clave', IF(NEW.clave_cifrada IS NULL, NULL, LEFT(SHA2(NEW.clave_cifrada, 256), 10)), 'correo_remitente', NEW.correo_remitente, 'nombre_remitente', NEW.nombre_remitente, 'responder_a', NEW.responder_a, 'firma', NEW.firma, 'limite_diario', NEW.limite_diario, 'activo', NEW.activo));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_cor_configuracion_upd$$
CREATE TRIGGER trg_aud_cor_configuracion_upd AFTER UPDATE ON cor_configuracion FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('servidor', OLD.servidor, 'puerto', OLD.puerto, 'seguridad', OLD.seguridad, 'usuario', OLD.usuario, 'clave', IF(OLD.clave_cifrada IS NULL, NULL, LEFT(SHA2(OLD.clave_cifrada, 256), 10)), 'correo_remitente', OLD.correo_remitente, 'nombre_remitente', OLD.nombre_remitente, 'responder_a', OLD.responder_a, 'firma', OLD.firma, 'limite_diario', OLD.limite_diario, 'activo', OLD.activo);
        SET v_despues = JSON_OBJECT('servidor', NEW.servidor, 'puerto', NEW.puerto, 'seguridad', NEW.seguridad, 'usuario', NEW.usuario, 'clave', IF(NEW.clave_cifrada IS NULL, NULL, LEFT(SHA2(NEW.clave_cifrada, 256), 10)), 'correo_remitente', NEW.correo_remitente, 'nombre_remitente', NEW.nombre_remitente, 'responder_a', NEW.responder_a, 'firma', NEW.firma, 'limite_diario', NEW.limite_diario, 'activo', NEW.activo);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cor_configuracion',
                    NEW.id_config, NULL, LEFT(NEW.correo_remitente, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
-- --------------------------------------------------------- cor_envios
DROP TRIGGER IF EXISTS trg_aud_cor_envios_ins$$
CREATE TRIGGER trg_aud_cor_envios_ins AFTER INSERT ON cor_envios FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cor_envios',
                NEW.id_envio, NULL, LEFT(NEW.asunto, 255),
                JSON_OBJECT('asunto', NEW.asunto, 'destinatarios', NEW.destinatarios, 'estado', NEW.estado, 'total', NEW.total, 'enviados', NEW.enviados, 'errores', NEW.errores));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_cor_envios_upd$$
CREATE TRIGGER trg_aud_cor_envios_upd AFTER UPDATE ON cor_envios FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 AND NOT (OLD.estado <=> NEW.estado) THEN
        SET v_antes = JSON_OBJECT('asunto', OLD.asunto, 'destinatarios', OLD.destinatarios, 'estado', OLD.estado, 'total', OLD.total, 'enviados', OLD.enviados, 'errores', OLD.errores);
        SET v_despues = JSON_OBJECT('asunto', NEW.asunto, 'destinatarios', NEW.destinatarios, 'estado', NEW.estado, 'total', NEW.total, 'enviados', NEW.enviados, 'errores', NEW.errores);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cor_envios',
                    NEW.id_envio, NULL, LEFT(NEW.asunto, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_cor_envios_del$$
CREATE TRIGGER trg_aud_cor_envios_del AFTER DELETE ON cor_envios FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cor_envios',
                OLD.id_envio, NULL, LEFT(OLD.asunto, 255),
                JSON_OBJECT('asunto', OLD.asunto, 'destinatarios', OLD.destinatarios, 'estado', OLD.estado, 'total', OLD.total, 'enviados', OLD.enviados, 'errores', OLD.errores));
    END IF;
END$$
-- --------------------------------------------------------- cor_listas
DROP TRIGGER IF EXISTS trg_aud_cor_listas_ins$$
CREATE TRIGGER trg_aud_cor_listas_ins AFTER INSERT ON cor_listas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cor_listas',
                NEW.id_lista, NULL, LEFT(NEW.nombre_archivo, 255),
                JSON_OBJECT('origen', NEW.origen, 'nombre_archivo', NEW.nombre_archivo, 'descripcion', NEW.descripcion, 'dominio', NEW.dominio, 'total', NEW.total));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_cor_listas_upd$$
CREATE TRIGGER trg_aud_cor_listas_upd AFTER UPDATE ON cor_listas FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 AND NOT (OLD.descripcion <=> NEW.descripcion) THEN
        SET v_antes = JSON_OBJECT('origen', OLD.origen, 'nombre_archivo', OLD.nombre_archivo, 'descripcion', OLD.descripcion, 'dominio', OLD.dominio, 'total', OLD.total);
        SET v_despues = JSON_OBJECT('origen', NEW.origen, 'nombre_archivo', NEW.nombre_archivo, 'descripcion', NEW.descripcion, 'dominio', NEW.dominio, 'total', NEW.total);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cor_listas',
                    NEW.id_lista, NULL, LEFT(NEW.nombre_archivo, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_cor_listas_del$$
CREATE TRIGGER trg_aud_cor_listas_del AFTER DELETE ON cor_listas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cor_listas',
                OLD.id_lista, NULL, LEFT(OLD.nombre_archivo, 255),
                JSON_OBJECT('origen', OLD.origen, 'nombre_archivo', OLD.nombre_archivo, 'descripcion', OLD.descripcion, 'dominio', OLD.dominio, 'total', OLD.total));
    END IF;
END$$

DELIMITER ;
