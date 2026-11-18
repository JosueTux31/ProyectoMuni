-- =====================================================================
--  creacionCorreo.sql - módulo de correo institucional
--  gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 1 de 2. Crea las 6 tablas del módulo de correo institucional:
--    - cor_configuracion: la cuenta con que se envían los avisos.
--    - cor_envios, cor_envios_destinatarios y cor_envios_adjuntos:
--      cada aviso, a quién se le envió y con qué resultado.
--    - cor_listas y cor_listas_correos: listas de correos importadas
--      para compararlas con los correos del personal.
--  Requiere las tablas del sistema (personas, usr_correos,
--  cat_departamentos, aud_auditorias).
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

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla cor_configuracion                       */
/*                                                                              */
/********************************************************************************/
-- La cuenta de correo institucional con la que el sistema envía los
-- avisos. Hay una sola fila (id_config = 1). La clave del servidor de
-- correo se guarda cifrada por Django y nunca sale por la API.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cor_configuracion') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_configuracion ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cor_configuracion (
      id_config        TINYINT NOT NULL DEFAULT 1,
      servidor         VARCHAR(150) NOT NULL,                  -- smtp.gmail.com
      puerto           SMALLINT NOT NULL DEFAULT 587,
      seguridad        VARCHAR(10) NOT NULL DEFAULT 'STARTTLS', -- STARTTLS, SSL o NINGUNA
      usuario          VARCHAR(150) NULL,                      -- cuenta con que se inicia sesión en el servidor
      clave_cifrada    VARCHAR(1000) NULL,                     -- cifrada; NULL = sin clave
      correo_remitente VARCHAR(150) NOT NULL,                  -- De:
      nombre_remitente VARCHAR(150) NULL,                      -- Municipalidad de Grecia
      responder_a      VARCHAR(150) NULL,                      -- a dónde llegan las respuestas
      firma            TEXT NULL,                              -- texto al final de cada aviso
      limite_diario    INT NOT NULL DEFAULT 1500,              -- correos por día (Google Workspace permite 2000)
      activo           BOOLEAN NOT NULL DEFAULT TRUE,          -- FALSE = el envío está pausado
      ultima_prueba    DATETIME NULL,
      prueba_ok        BOOLEAN NULL,
      resultado_prueba VARCHAR(255) NULL,
      id_usuario       INT NULL,                               -- quién la cambió por última vez
      actualizado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_configuracion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cor_configuracion */
    ALTER TABLE cor_configuracion
      ADD CONSTRAINT pk_cor_configuracion PRIMARY KEY (id_config);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cor_configuracion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_corcfg_unica */
    ALTER TABLE cor_configuracion
      ADD CONSTRAINT ck_corcfg_unica CHECK (id_config = 1);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_corcfg_unica se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_corcfg_seguridad */
    ALTER TABLE cor_configuracion
      ADD CONSTRAINT ck_corcfg_seguridad CHECK (seguridad IN ('STARTTLS', 'SSL', 'NINGUNA'));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_corcfg_seguridad se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_corcfg_puerto */
    ALTER TABLE cor_configuracion
      ADD CONSTRAINT ck_corcfg_puerto CHECK (puerto BETWEEN 1 AND 65535);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_corcfg_puerto se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_corcfg_limite */
    ALTER TABLE cor_configuracion
      ADD CONSTRAINT ck_corcfg_limite CHECK (limite_diario > 0);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_corcfg_limite se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_corcfg_usuario */
    ALTER TABLE cor_configuracion
      ADD CONSTRAINT fk_corcfg_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE SET NULL;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_corcfg_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla cor_envios                           */
/*                                                                              */
/********************************************************************************/
-- Cada aviso enviado (o por enviar) al personal.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cor_envios') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_envios ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cor_envios (
      id_envio      INT NOT NULL,
      asunto        VARCHAR(200) NOT NULL,
      mensaje       TEXT NOT NULL,
      destinatarios VARCHAR(255) NULL,                      -- a quiénes, en palabras: «Todo el personal»
      remitente     VARCHAR(255) NULL,                      -- De: con que salió
      estado        VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE',
      total         INT NOT NULL DEFAULT 0,                 -- destinatarios
      enviados      INT NOT NULL DEFAULT 0,
      errores       INT NOT NULL DEFAULT 0,
      id_usuario    INT NULL,                               -- quién lo envió
      creado_en     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      terminado_en  DATETIME NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_envios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cor_envios */
    ALTER TABLE cor_envios
      ADD CONSTRAINT pk_cor_envios PRIMARY KEY (id_envio),
      MODIFY id_envio INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cor_envios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_corenv_fecha */
    ALTER TABLE cor_envios
      ADD INDEX idx_corenv_fecha (creado_en);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_corenv_fecha se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_corenv_estado */
    ALTER TABLE cor_envios
      ADD CONSTRAINT ck_corenv_estado CHECK (estado IN ('PENDIENTE', 'ENVIANDO', 'ENVIADO', 'CON_ERRORES', 'CANCELADO'));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_corenv_estado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_corenv_usuario */
    ALTER TABLE cor_envios
      ADD CONSTRAINT fk_corenv_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE SET NULL;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_corenv_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                   Crear la tabla cor_envios_destinatarios                    */
/*                                                                              */
/********************************************************************************/
-- Cada destinatario de un aviso: un correo por persona, con su resultado.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cor_envios_destinatarios') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_envios_destinatarios ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cor_envios_destinatarios (
      id_envio   INT NOT NULL,
      num_linea  INT NOT NULL,
      id_persona INT NULL,                               -- personas.id
      nombre     VARCHAR(255) NULL,                      -- nombre de la persona al enviarlo
      correo     VARCHAR(150) NOT NULL,
      estado     VARCHAR(10) NOT NULL DEFAULT 'PENDIENTE',
      error      VARCHAR(255) NULL,                      -- lo que respondió el servidor de correo
      enviado_en DATETIME NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_envios_destinatarios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cor_envios_destinatarios */
    ALTER TABLE cor_envios_destinatarios
      ADD CONSTRAINT pk_cor_envios_destinatarios PRIMARY KEY (id_envio, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cor_envios_destinatarios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_cordest_correo */
    ALTER TABLE cor_envios_destinatarios
      ADD CONSTRAINT uk_cordest_correo UNIQUE (id_envio, correo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_cordest_correo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_cordest_estado */
    ALTER TABLE cor_envios_destinatarios
      ADD INDEX idx_cordest_estado (id_envio, estado);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_cordest_estado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_cordest_enviado */
    ALTER TABLE cor_envios_destinatarios
      ADD INDEX idx_cordest_enviado (estado, enviado_en);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_cordest_enviado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_cordest_persona */
    ALTER TABLE cor_envios_destinatarios
      ADD INDEX idx_cordest_persona (id_persona);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_cordest_persona se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_cordest_estado */
    ALTER TABLE cor_envios_destinatarios
      ADD CONSTRAINT ck_cordest_estado CHECK (estado IN ('PENDIENTE', 'ENVIADO', 'ERROR', 'CANCELADO'));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_cordest_estado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_cordest_envio */
    ALTER TABLE cor_envios_destinatarios
      ADD CONSTRAINT fk_cordest_envio FOREIGN KEY (id_envio) REFERENCES cor_envios(id_envio) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_cordest_envio se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_cordest_persona */
    ALTER TABLE cor_envios_destinatarios
      ADD CONSTRAINT fk_cordest_persona FOREIGN KEY (id_persona) REFERENCES personas(id) ON DELETE SET NULL;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_cordest_persona se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                      Crear la tabla cor_envios_adjuntos                      */
/*                                                                              */
/********************************************************************************/
-- Archivos adjuntos de un aviso (la ruta es relativa a la carpeta
-- «archivos» de Django).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cor_envios_adjuntos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_envios_adjuntos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cor_envios_adjuntos (
      id_envio       INT NOT NULL,
      num_linea      INT NOT NULL,
      nombre_archivo VARCHAR(255) NOT NULL,
      ruta           VARCHAR(255) NOT NULL,
      tamano         BIGINT NOT NULL DEFAULT 0,
      tipo           VARCHAR(100) NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_envios_adjuntos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cor_envios_adjuntos */
    ALTER TABLE cor_envios_adjuntos
      ADD CONSTRAINT pk_cor_envios_adjuntos PRIMARY KEY (id_envio, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cor_envios_adjuntos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_coradj_envio */
    ALTER TABLE cor_envios_adjuntos
      ADD CONSTRAINT fk_coradj_envio FOREIGN KEY (id_envio) REFERENCES cor_envios(id_envio) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_coradj_envio se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla cor_listas                           */
/*                                                                              */
/********************************************************************************/
-- Listas de correos importadas (por ejemplo, las cuentas de Google
-- Workspace) para compararlas con los correos del personal registrado.
-- origen: GOOGLE (cuentas de Google Workspace), SOPHOS (cuentas
-- protegidas por Sophos Email) u OTRA (cualquier lista de correos).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cor_listas') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_listas ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cor_listas (
      id_lista       INT NOT NULL,
      origen         VARCHAR(10) NOT NULL DEFAULT 'OTRA',
      nombre_archivo VARCHAR(255) NOT NULL,
      descripcion    VARCHAR(255) NULL,
      dominio        VARCHAR(150) NULL,                     -- el dominio que más se repite (grecia.go.cr)
      total          INT NOT NULL DEFAULT 0,
      id_usuario     INT NULL,                              -- quién la importó
      creado_en      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_listas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cor_listas */
    ALTER TABLE cor_listas
      ADD CONSTRAINT pk_cor_listas PRIMARY KEY (id_lista),
      MODIFY id_lista INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cor_listas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_corlis_usuario */
    ALTER TABLE cor_listas
      ADD CONSTRAINT fk_corlis_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE SET NULL;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_corlis_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                      Crear la tabla cor_listas_correos                       */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cor_listas_correos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_listas_correos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cor_listas_correos (
      id_lista      INT NOT NULL,
      num_linea     INT NOT NULL,
      correo        VARCHAR(150) NOT NULL,
      nombre        VARCHAR(150) NULL,
      apellidos     VARCHAR(150) NULL,
      estado        VARCHAR(30) NULL,        -- Active, Suspended... como venga en el archivo
      ultimo_acceso DATETIME NULL,           -- último inicio de sesión (Last Sign In)
      nunca_entro   BOOLEAN NULL,            -- TRUE = nunca ha iniciado sesión; NULL = el archivo no lo dice
      uso_gb        DECIMAL(10,2) NULL       -- espacio usado del buzón (Email Usage)
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cor_listas_correos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cor_listas_correos */
    ALTER TABLE cor_listas_correos
      ADD CONSTRAINT pk_cor_listas_correos PRIMARY KEY (id_lista, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cor_listas_correos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_corlc_correo */
    ALTER TABLE cor_listas_correos
      ADD CONSTRAINT uk_corlc_correo UNIQUE (id_lista, correo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_corlc_correo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_corlc_lista */
    ALTER TABLE cor_listas_correos
      ADD CONSTRAINT fk_corlc_lista FOREIGN KEY (id_lista) REFERENCES cor_listas(id_lista) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_corlc_lista se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

-- Base con la versión anterior del módulo: agrega las columnas nuevas
-- (de dónde es cada lista y el uso de cada cuenta) sin tocar los datos
ALTER TABLE cor_listas
    ADD COLUMN IF NOT EXISTS origen VARCHAR(10) NOT NULL DEFAULT 'OTRA' AFTER id_lista;
CREATE INDEX IF NOT EXISTS idx_corlis_origen ON cor_listas (origen);
ALTER TABLE cor_listas_correos
    ADD COLUMN IF NOT EXISTS ultimo_acceso DATETIME NULL AFTER estado,
    ADD COLUMN IF NOT EXISTS nunca_entro BOOLEAN NULL AFTER ultimo_acceso,
    ADD COLUMN IF NOT EXISTS uso_gb DECIMAL(10,2) NULL AFTER nunca_entro;
