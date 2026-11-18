-- =====================================================================
--  creacionLogs.sql - módulo de análisis de logs
--  gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 1 de 3. Crea las 4 tablas del módulo de análisis de logs:
--    - log_importaciones: cada archivo importado (Sophos, Microclaudia, DHCP...).
--    - log_eventos: los eventos, con los campos comunes en columnas y
--      todos los originales en JSON (diseño híbrido documento + tabla).
--    - log_direcciones: todas las IP y MAC de un evento (equipos con
--      varias tarjetas de red, como los de Microclaudia).
--    - log_mapeo_campos: cómo se llama cada campo común en cada programa.
--  Si la base ya tenía una versión anterior del módulo, agrega las
--  columnas nuevas sin borrar nada.
--  Requiere las tablas del sistema (personas, aud_auditorias) y las
--  del módulo de equipos (equipos, dir_ips, dir_macs) para el
--  cruce con el inventario.
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

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla log_importaciones                       */
/*                                                                              */
/********************************************************************************/
-- Cada archivo de logs que se importa (Sophos, Microclaudia, el DHCP y,
-- más adelante, otros programas). Al borrar una importación se borran sus
-- eventos.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'log_importaciones') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_importaciones ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE log_importaciones (
      id_importacion INT NOT NULL,
      fuente         VARCHAR(30) NOT NULL,                  -- SOPHOS, MICROCLAUDIA, DHCP
      nombre_archivo VARCHAR(255) NOT NULL,
      descripcion    VARCHAR(255) NULL,
      total_leidos   INT NOT NULL DEFAULT 0,                -- eventos que traía el archivo
      total_eventos  INT NOT NULL DEFAULT 0,                -- eventos guardados
      repetidos      INT NOT NULL DEFAULT 0,                -- eventos repetidos dentro del archivo
      permitidos     INT NOT NULL DEFAULT 0,
      denegados      INT NOT NULL DEFAULT 0,
      avisos         INT NOT NULL DEFAULT 0,                -- partes del archivo que no se pudieron leer
      fecha_desde    DATETIME NULL,                         -- primer evento
      fecha_hasta    DATETIME NULL,                         -- último evento
      id_usuario     INT NULL,                              -- quién la importó
      creado_en      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_importaciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla log_importaciones */
    ALTER TABLE log_importaciones
      ADD CONSTRAINT pk_log_importaciones PRIMARY KEY (id_importacion),
      MODIFY id_importacion INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_log_importaciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logimp_fuente */
    ALTER TABLE log_importaciones
      ADD INDEX idx_logimp_fuente (fuente, creado_en);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logimp_fuente se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_logimp_usuario */
    ALTER TABLE log_importaciones
      ADD CONSTRAINT fk_logimp_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE SET NULL;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_logimp_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla log_eventos                          */
/*                                                                              */
/********************************************************************************/
-- Eventos de los logs. Diseño híbrido (documento + columnas):
--   - Los datos importantes, con el mismo nombre venga del programa que
--     venga (apps/logs/esquema.py), van en columnas con índice para
--     filtrar y comparar rápido.
--   - datos guarda TODOS los campos originales del evento en JSON, como
--     una base de documentos: lo que no tiene columna también se puede
--     filtrar (datos.hb_status == "No Heartbeat") y exportar.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'log_eventos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_eventos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE log_eventos (
      id_evento            BIGINT NOT NULL,
      id_importacion       INT NOT NULL,
      fuente               VARCHAR(30) NOT NULL,
      huella               CHAR(32) NOT NULL,      -- identifica el evento (MD5 de su contenido)
      fecha                DATETIME NULL,          -- General
      tipo                 VARCHAR(60) NULL,       -- Tipo de log
      accion               VARCHAR(12) NULL,       -- Acción
      tipo_log             VARCHAR(60) NULL,       -- Clase
      componente           VARCHAR(60) NULL,       -- Componente
      subtipo              VARCHAR(60) NULL,       -- Resultado
      descripcion          VARCHAR(255) NULL,      -- Descripción
      dispositivo          VARCHAR(100) NULL,      -- Firewall que lo registró
      id_mensaje           VARCHAR(20) NULL,       -- Código del mensaje
      severidad            VARCHAR(30) NULL,       -- Severidad
      regla_id             VARCHAR(20) NULL,       -- Regla y política
      regla_nombre         VARCHAR(150) NULL,      -- Regla
      regla_seccion        VARCHAR(60) NULL,       -- Sección de la regla
      nat_regla_id         VARCHAR(20) NULL,       -- Regla NAT (código)
      nat_regla            VARCHAR(150) NULL,      -- Regla NAT
      politica_web         VARCHAR(150) NULL,      -- Política web
      actividad            VARCHAR(150) NULL,      -- Actividad
      motivo               VARCHAR(255) NULL,      -- Motivo
      usuario              VARCHAR(100) NULL,      -- Usuario
      grupo_usuario        VARCHAR(100) NULL,      -- Grupo del usuario
      ip_origen            VARCHAR(45) NULL,       -- Origen
      puerto_origen        INT NULL,               -- Puerto de origen
      mac_origen           CHAR(12) NULL,          -- MAC de origen
      pais_origen          VARCHAR(10) NULL,       -- País de origen
      zona_origen          VARCHAR(30) NULL,       -- Zona de origen
      interfaz_entrada     VARCHAR(100) NULL,      -- Interfaz de entrada
      ip_origen_nat        VARCHAR(45) NULL,       -- IP de origen traducida (NAT)
      nombre_equipo        VARCHAR(100) NULL,      -- Nombre del equipo
      sistema_operativo    VARCHAR(150) NULL,      -- Sistema operativo
      ip_destino           VARCHAR(45) NULL,       -- Destino
      puerto_destino       INT NULL,               -- Puerto de destino
      mac_destino          CHAR(12) NULL,          -- MAC de destino
      pais_destino         VARCHAR(10) NULL,       -- País de destino
      zona_destino         VARCHAR(30) NULL,       -- Zona de destino
      interfaz_salida      VARCHAR(100) NULL,      -- Interfaz de salida
      ip_destino_nat       VARCHAR(45) NULL,       -- IP de destino traducida (NAT)
      dominio              VARCHAR(255) NULL,      -- Web
      url                  TEXT NULL,              -- URL
      categoria            VARCHAR(100) NULL,      -- Categoría
      categoria_tipo       VARCHAR(50) NULL,       -- Tipo de categoría
      codigo_http          BIGINT NULL,            -- Código HTTP
      tipo_contenido       VARCHAR(100) NULL,      -- Tipo de contenido
      navegador            TEXT NULL,              -- Navegador (user agent)
      aplicacion           VARCHAR(150) NULL,      -- Aplicación
      aplicacion_categoria VARCHAR(100) NULL,      -- Categoría de la aplicación
      aplicacion_riesgo    BIGINT NULL,            -- Riesgo de la aplicación
      version_tls          VARCHAR(20) NULL,       -- Versión TLS
      cifrado              VARCHAR(100) NULL,      -- Cifrado
      version_agente       VARCHAR(50) NULL,       -- Versión del agente
      vacunas_aplicadas    BIGINT NULL,            -- Vacunas aplicadas
      vacunas_pendientes   BIGINT NULL,            -- Vacunas pendientes
      vacunas_error        BIGINT NULL,            -- Vacunas con error
      protocolo            VARCHAR(20) NULL,       -- Tráfico
      bytes_enviados       BIGINT NULL,            -- Bytes enviados
      bytes_recibidos      BIGINT NULL,            -- Bytes recibidos
      paquetes_enviados    BIGINT NULL,            -- Paquetes enviados
      paquetes_recibidos   BIGINT NULL,            -- Paquetes recibidos
      duracion             BIGINT NULL,            -- Duración (segundos)
      id_conexion          VARCHAR(30) NULL,       -- Conexión (con_id)
      datos                LONGTEXT NOT NULL       -- todos los campos originales (JSON)
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_eventos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla log_eventos */
    ALTER TABLE log_eventos
      ADD CONSTRAINT pk_log_eventos PRIMARY KEY (id_evento),
      MODIFY id_evento BIGINT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_log_eventos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_logev_huella */
    ALTER TABLE log_eventos
      ADD CONSTRAINT uk_logev_huella UNIQUE (id_importacion, huella);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_logev_huella se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_fecha */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_fecha (fecha);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_fecha se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_importacion */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_importacion (id_importacion, fecha);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_importacion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_huella */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_huella (huella);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_huella se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_ip_origen */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_ip_origen (ip_origen);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_ip_origen se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_ip_destino */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_ip_destino (ip_destino);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_ip_destino se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_mac_origen */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_mac_origen (mac_origen);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_mac_origen se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_mac_destino */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_mac_destino (mac_destino);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_mac_destino se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_conexion */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_conexion (id_conexion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_conexion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_dominio */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_dominio (dominio);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_dominio se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_usuario */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_usuario (usuario);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_accion */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_accion (accion, fecha);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_accion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logev_nombre_equipo */
    ALTER TABLE log_eventos
      ADD INDEX idx_logev_nombre_equipo (nombre_equipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logev_nombre_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_logev_importacion */
    ALTER TABLE log_eventos
      ADD CONSTRAINT fk_logev_importacion FOREIGN KEY (id_importacion) REFERENCES log_importaciones(id_importacion) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_logev_importacion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_logev_datos */
    ALTER TABLE log_eventos
      ADD CONSTRAINT ck_logev_datos CHECK (JSON_VALID(datos));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_logev_datos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

-- Versión 2 (Microclaudia): columnas del equipo y del agente. En una base
-- que ya tenía log_eventos se agregan aquí; si ya están, no pasa nada.
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS nombre_equipo VARCHAR(100) NULL;
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS sistema_operativo VARCHAR(150) NULL;
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS version_agente VARCHAR(50) NULL;
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS vacunas_aplicadas BIGINT NULL;
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS vacunas_pendientes BIGINT NULL;
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS vacunas_error BIGINT NULL;
CREATE INDEX IF NOT EXISTS idx_logev_nombre_equipo ON log_eventos (nombre_equipo);

-- Versión 3 (DHCP): descripción de la reserva o del evento.
ALTER TABLE log_eventos ADD COLUMN IF NOT EXISTS descripcion VARCHAR(255) NULL;

/********************************************************************************/
/*                                                                              */
/*                        Crear la tabla log_direcciones                        */
/*                                                                              */
/********************************************************************************/
-- Todas las IP y MAC de un evento cuando son varias (un equipo de
-- Microclaudia tiene varias tarjetas de red). Sirve para cruzar un equipo
-- por cualquiera de sus direcciones. Solo IPv4 y MAC (12 caracteres).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'log_direcciones') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_direcciones ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE log_direcciones (
      id_evento      BIGINT NOT NULL,
      id_importacion INT NOT NULL,
      tipo           CHAR(3) NOT NULL,       -- IP o MAC
      direccion      VARCHAR(45) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_direcciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla log_direcciones */
    ALTER TABLE log_direcciones
      ADD CONSTRAINT pk_log_direcciones PRIMARY KEY (id_evento, tipo, direccion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_log_direcciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logdir_direccion */
    ALTER TABLE log_direcciones
      ADD INDEX idx_logdir_direccion (tipo, direccion, id_importacion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logdir_direccion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logdir_importacion */
    ALTER TABLE log_direcciones
      ADD INDEX idx_logdir_importacion (id_importacion, tipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logdir_importacion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_logdir_evento */
    ALTER TABLE log_direcciones
      ADD CONSTRAINT fk_logdir_evento FOREIGN KEY (id_evento) REFERENCES log_eventos(id_evento) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_logdir_evento se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_logdir_tipo */
    ALTER TABLE log_direcciones
      ADD CONSTRAINT ck_logdir_tipo CHECK (tipo IN ('IP', 'MAC'));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_logdir_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla log_mapeo_campos                        */
/*                                                                              */
/********************************************************************************/
-- Cómo se llama cada campo común en cada programa. Sophos llama
-- fw_rule_id a la regla en el firewall y rule_id en la inspección SSL:
-- los dos van a regla_id. Si un evento trae varios alias del mismo campo,
-- gana el de menor prioridad.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'log_mapeo_campos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_mapeo_campos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE log_mapeo_campos (
      fuente       VARCHAR(30) NOT NULL,          -- SOPHOS
      campo_origen VARCHAR(64) NOT NULL,          -- nombre en el log (fw_rule_id)
      campo        VARCHAR(64) NOT NULL,          -- campo común (regla_id)
      prioridad    SMALLINT NOT NULL DEFAULT 1
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla log_mapeo_campos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla log_mapeo_campos */
    ALTER TABLE log_mapeo_campos
      ADD CONSTRAINT pk_log_mapeo_campos PRIMARY KEY (fuente, campo_origen);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_log_mapeo_campos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_logmap_campo */
    ALTER TABLE log_mapeo_campos
      ADD INDEX idx_logmap_campo (fuente, campo, prioridad);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_logmap_campo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;
