-- =====================================================================
--  creacionDispositivo.sql - módulo de equipos municipales
--  gestion_redes (MariaDB 10.3 o superior)
-- ---------------------------------------------------------------------
--  Paso 4. Crea las 21 tablas del módulo con el modelo de la especificación:
--  las tablas catálogo (tipo_equipos, marcas, modelos, procesadores,
--  sis_operativos, firmwares, edificios, estado_equipos, tipo_roles,
--  tipo_herramientas y tipo_archivos), la tabla equipos y sus tablas de
--  detalle (roles, herramientas, dir_macs, dir_ips, num_moviles,
--  dir_imeis y archivos), más las categorías y los puertos de los
--  switches. Cada tabla avisa si ya existe; si no, se crea y después se
--  le agregan su llave primaria, sus índices y sus llaves foráneas.
--
--  Orden de instalación (lo sigue reinstalar_base.sh):
--     1-3. instalacion/01_estructura, 02_procedimientos, 03_datos
--     4. creacionDispositivo.sql         tablas
--     5. procedimientosDispositivos.sql  funciones, procedimientos y disparadores
--     6. insercionDispositivos.sql       datos iniciales de los catálogos
--  Se pueden ejecutar más de una vez sin duplicar ni borrar nada.
-- =====================================================================

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base, con el programa que sea que lo ejecute: así
-- las tildes se guardan bien y nada mezcla intercalaciones distintas.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;


-- =====================================================================
-- EQUIPOS MUNICIPALES
--    Tablas catálogo (tipo, marca, modelo, procesador, sistema operativo,
--    firmware, edificio, estado, roles, herramientas y tipo de archivo),
--    la tabla Equipos y sus tablas de detalle (IP, MAC, líneas móviles,
--    IMEI, roles, herramientas y archivos), más los puertos de los
--    switches. Cada equipo se liga a un edificio, a un departamento, al
--    funcionario que lo usa y a su proveedor de soporte (tabla personas).
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla categoria_equipos                       */
/*                                                                              */
/********************************************************************************/
-- Categorías de equipo: deciden qué datos se piden al registrar cada uno
-- (puertos; procesador, memoria y disco; IMEI y línea; impresión...).
-- Son fijas porque la página sabe qué campos lleva cada una.
-- lleva_agente: se espera que tenga el agente de Microclaudia
-- (computadoras y servidores).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'categoria_equipos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla categoria_equipos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE categoria_equipos (
      id_categoria INT NOT NULL,
      descripcion  VARCHAR(100) NOT NULL,
      lleva_agente BOOLEAN NOT NULL DEFAULT FALSE
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla categoria_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla categoria_equipos */
    ALTER TABLE categoria_equipos
      ADD CONSTRAINT pk_categoria_equipos PRIMARY KEY (id_categoria);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_categoria_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_categoria_equipos_desc */
    ALTER TABLE categoria_equipos
      ADD CONSTRAINT uk_categoria_equipos_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_categoria_equipos_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla tipo_equipos                          */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo tipo_equipos: modem, firewall, router, switch, server...
-- Cada tipo pertenece a una categoría.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tipo_equipos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_equipos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE tipo_equipos (
      tipo_equipo  INT NOT NULL,
      descripcion  VARCHAR(100) NOT NULL,
      id_categoria INT NOT NULL DEFAULT 1    -- 1 = equipos de red
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla tipo_equipos */
    ALTER TABLE tipo_equipos
      ADD CONSTRAINT pk_tipo_equipos PRIMARY KEY (tipo_equipo),
      MODIFY tipo_equipo INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_tipo_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_tipo_equipos_desc */
    ALTER TABLE tipo_equipos
      ADD CONSTRAINT uk_tipo_equipos_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_tipo_equipos_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_tipo_equipos_categoria */
    ALTER TABLE tipo_equipos
      ADD CONSTRAINT fk_tipo_equipos_categoria FOREIGN KEY (id_categoria) REFERENCES categoria_equipos(id_categoria);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_tipo_equipos_categoria se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                            Crear la tabla marcas                             */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo marcas. Cada marca es de un tipo de equipo: CISCO de
-- firewall, CISCO de router y CISCO de switch son registros distintos,
-- cada uno con sus modelos.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'marcas') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla marcas ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE marcas (
      id_marca    INT NOT NULL,
      descripcion VARCHAR(100) NOT NULL,
      tipo_equipo INT NOT NULL             -- tipo de equipo de la marca
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla marcas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla marcas */
    ALTER TABLE marcas
      ADD CONSTRAINT pk_marcas PRIMARY KEY (id_marca),
      MODIFY id_marca INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_marcas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_marcas_tipo */
    ALTER TABLE marcas
      ADD CONSTRAINT uk_marcas_tipo UNIQUE (tipo_equipo, id_marca);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_marcas_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_marcas_desc */
    ALTER TABLE marcas
      ADD CONSTRAINT uk_marcas_desc UNIQUE (tipo_equipo, descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_marcas_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_marcas_tipo */
    ALTER TABLE marcas
      ADD CONSTRAINT fk_marcas_tipo FOREIGN KEY (tipo_equipo) REFERENCES tipo_equipos(tipo_equipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_marcas_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                            Crear la tabla modelos                            */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo modelos. Cada modelo es de una marca.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'modelos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla modelos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE modelos (
      id_modelo   INT NOT NULL,
      descripcion VARCHAR(150) NOT NULL,
      id_marca    INT NOT NULL             -- marca del modelo
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla modelos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla modelos */
    ALTER TABLE modelos
      ADD CONSTRAINT pk_modelos PRIMARY KEY (id_modelo),
      MODIFY id_modelo INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_modelos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_modelos_marca */
    ALTER TABLE modelos
      ADD CONSTRAINT uk_modelos_marca UNIQUE (id_marca, id_modelo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_modelos_marca se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_modelos_desc */
    ALTER TABLE modelos
      ADD CONSTRAINT uk_modelos_desc UNIQUE (id_marca, descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_modelos_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_modelos_marca */
    ALTER TABLE modelos
      ADD CONSTRAINT fk_modelos_marca FOREIGN KEY (id_marca) REFERENCES marcas(id_marca);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_modelos_marca se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla procesadores                          */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo procesadores: AMD Ryzen R1606G, Intel Atom C2718...
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'procesadores') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla procesadores ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE procesadores (
      id_proc     INT NOT NULL,
      descripcion VARCHAR(150) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla procesadores se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla procesadores */
    ALTER TABLE procesadores
      ADD CONSTRAINT pk_procesadores PRIMARY KEY (id_proc),
      MODIFY id_proc INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_procesadores se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_procesadores_desc */
    ALTER TABLE procesadores
      ADD CONSTRAINT uk_procesadores_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_procesadores_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                        Crear la tabla sis_operativos                         */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo sis_operativos: N/D, Linux Debian 12, Windows 10...
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sis_operativos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla sis_operativos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE sis_operativos (
      id_so       INT NOT NULL,
      descripcion VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla sis_operativos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla sis_operativos */
    ALTER TABLE sis_operativos
      ADD CONSTRAINT pk_sis_operativos PRIMARY KEY (id_so),
      MODIFY id_so INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_sis_operativos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_sis_operativos_desc */
    ALTER TABLE sis_operativos
      ADD CONSTRAINT uk_sis_operativos_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_sis_operativos_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                           Crear la tabla firmwares                           */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo firmwares: N/D, SFOS 22.0.2... (versión del sistema o firmware)
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'firmwares') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla firmwares ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE firmwares (
      id_firmw    INT NOT NULL,
      descripcion VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla firmwares se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla firmwares */
    ALTER TABLE firmwares
      ADD CONSTRAINT pk_firmwares PRIMARY KEY (id_firmw),
      MODIFY id_firmw INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_firmwares se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_firmwares_desc */
    ALTER TABLE firmwares
      ADD CONSTRAINT uk_firmwares_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_firmwares_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                           Crear la tabla edificios                           */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo edificios: dónde están los equipos. El país, la
-- provincia, el cantón y el distrito son los de la división territorial
-- (CR, 2, 03, 01 = Costa Rica, Alajuela, Grecia, Grecia). ubicacion son
-- las coordenadas "latitud,longitud" para el mapa: el mapa de cada equipo
-- es el de su edificio.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'edificios') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla edificios ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE edificios (
      id_predio    INT NOT NULL,
      descripcion  VARCHAR(150) NOT NULL,   -- nombre del edificio
      id_pais      VARCHAR(10) NULL,
      id_provincia VARCHAR(10) NULL,
      id_canton    VARCHAR(10) NULL,
      id_distrito  VARCHAR(10) NULL,
      ubicacion    VARCHAR(100) NULL,       -- coordenadas: "latitud,longitud"
      otras_senas  TEXT NULL                -- opcional
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla edificios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla edificios */
    ALTER TABLE edificios
      ADD CONSTRAINT pk_edificios PRIMARY KEY (id_predio),
      MODIFY id_predio INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_edificios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_edificios_desc */
    ALTER TABLE edificios
      ADD CONSTRAINT uk_edificios_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_edificios_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_edificios_distrito */
    ALTER TABLE edificios
      ADD CONSTRAINT fk_edificios_distrito FOREIGN KEY (id_pais, id_provincia, id_canton, id_distrito) REFERENCES geo_distritos(cod_pais, cod_provincia, cod_canton, cod_distrito);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_edificios_distrito se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                        Crear la tabla estado_equipos                         */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo estado_equipos: N/D, ACTIVO, INACTIVO (dado de baja)
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'estado_equipos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla estado_equipos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE estado_equipos (
      id_estado   INT NOT NULL,
      descripcion VARCHAR(50) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla estado_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla estado_equipos */
    ALTER TABLE estado_equipos
      ADD CONSTRAINT pk_estado_equipos PRIMARY KEY (id_estado),
      MODIFY id_estado INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_estado_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_estado_equipos_desc */
    ALTER TABLE estado_equipos
      ADD CONSTRAINT uk_estado_equipos_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_estado_equipos_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla tipo_roles                           */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo tipo_roles: roles de un servidor (dominio, DHCP, DNS, NTP...)
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tipo_roles') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_roles ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE tipo_roles (
      id_rol      INT NOT NULL,
      descripcion VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_roles se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla tipo_roles */
    ALTER TABLE tipo_roles
      ADD CONSTRAINT pk_tipo_roles PRIMARY KEY (id_rol),
      MODIFY id_rol INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_tipo_roles se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_tipo_roles_desc */
    ALTER TABLE tipo_roles
      ADD CONSTRAINT uk_tipo_roles_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_tipo_roles_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla tipo_herramientas                       */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo tipo_herramientas: herramientas de seguridad instaladas (Bitdefender, Microclaudia...)
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tipo_herramientas') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_herramientas ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE tipo_herramientas (
      id_herram   INT NOT NULL,
      descripcion VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_herramientas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla tipo_herramientas */
    ALTER TABLE tipo_herramientas
      ADD CONSTRAINT pk_tipo_herramientas PRIMARY KEY (id_herram),
      MODIFY id_herram INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_tipo_herramientas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_tipo_herramientas_desc */
    ALTER TABLE tipo_herramientas
      ADD CONSTRAINT uk_tipo_herramientas_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_tipo_herramientas_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla tipo_archivos                         */
/*                                                                              */
/********************************************************************************/
-- Tabla catálogo tipo_archivos: manual, garantía, soporte, configuración...
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tipo_archivos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_archivos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE tipo_archivos (
      tipo_arch   INT NOT NULL,
      descripcion VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla tipo_archivos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla tipo_archivos */
    ALTER TABLE tipo_archivos
      ADD CONSTRAINT pk_tipo_archivos PRIMARY KEY (tipo_arch),
      MODIFY tipo_arch INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_tipo_archivos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_tipo_archivos_desc */
    ALTER TABLE tipo_archivos
      ADD CONSTRAINT uk_tipo_archivos_desc UNIQUE (descripcion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_tipo_archivos_desc se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                            Crear la tabla equipos                            */
/*                                                                              */
/********************************************************************************/
-- Tabla Equipos: firewalls, routers, switches, servidores, workstations,
-- laptops, telefonía IP, impresoras, scanners, tablets y teléfonos
-- móviles (antes equiposMuni). Los campos con «tabla catálogo» se
-- llenan con el código de su catálogo. Las IP, MAC, líneas móviles,
-- IMEI, roles, herramientas y archivos van en sus tablas, una fila por
-- cada uno (id + num_linea).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'equipos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla equipos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE equipos (
      id                   INT NOT NULL,                           -- código del equipo
      tipo_equipo          INT NOT NULL,                           -- tabla catálogo tipo_equipos
      serie                VARCHAR(100) NOT NULL,
      id_marca             INT NOT NULL,                           -- tabla catálogo marcas
      id_modelo            INT NULL,                               -- tabla catálogo modelos; NULL si la marca aún no tiene modelos
      nombre_equipo        VARCHAR(100) NULL,                      -- nombre en la red (hostname): se compara con el DHCP y Microclaudia
      placa_equipo         VARCHAR(50) NULL,                       -- número de activo (placa patrimonial)
      id_proces            INT NULL,                               -- tabla catálogo procesadores
      cant_mem             SMALLINT UNSIGNED NULL,                 -- memoria RAM en GB
      cant_almac           INT UNSIGNED NULL,                      -- almacenamiento en GB
      cant_ptos_serie      SMALLINT UNSIGNED NOT NULL DEFAULT 0,   -- puertos serie o de consola
      cant_ptos_usb        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      cant_ptos_eth        SMALLINT UNSIGNED NOT NULL DEFAULT 0,   -- puertos Ethernet de cobre
      cant_ptos_sfp        SMALLINT UNSIGNED NOT NULL DEFAULT 0,   -- puertos SFP de fibra
      cant_ptos_wireless   SMALLINT UNSIGNED NOT NULL DEFAULT 0,   -- radios o antenas inalámbricas
      cant_ptos_bluetooth  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      cant_ptos_celular    SMALLINT UNSIGNED NOT NULL DEFAULT 0,   -- ranuras para SIM
      id_so                INT NOT NULL DEFAULT 1,                 -- tabla catálogo sis_operativos; 1 = N/D
      id_firmw             INT NOT NULL DEFAULT 1,                 -- tabla catálogo firmwares; 1 = N/D
      id_predio            INT NULL,                               -- tabla catálogo edificios: su mapa es el del edificio
      ubicacion            VARCHAR(255) NULL,                      -- dentro del edificio: piso, oficina, rack
      id_estado            INT NOT NULL DEFAULT 2,                 -- tabla catálogo estado_equipos; 2 = ACTIVO
      id_usuario           INT NULL,                               -- funcionario que lo usa (personas, no proveedor)
      id_proveedor         INT NULL,                               -- quién le da soporte (personas con es_proveedor)
      tipo_almacenamiento  VARCHAR(10) NULL,                       -- SSD, NVME, HDD, EMMC
      extension            VARCHAR(10) NULL,                       -- teléfonos IP y centrales telefónicas
      tecnologia_impresion VARCHAR(20) NULL,                       -- LÁSER, TINTA, TINTA CONTINUA, TÉRMICA, MATRIZ DE PUNTO
      a_color              BOOLEAN NULL,                           -- imprime a color
      consumible           VARCHAR(100) NULL,                      -- modelo del tóner o cartucho
      pulgadas             DECIMAL(4,1) NULL,                      -- tamaño de la pantalla
      resolucion           VARCHAR(20) NULL,                       -- 1920X1080, 4K...
      capacidad_va         INT UNSIGNED NULL,                      -- UPS: capacidad en VA
      autonomia_min        SMALLINT UNSIGNED NULL,                 -- UPS: minutos con batería
      canales              SMALLINT UNSIGNED NULL,                 -- grabadores NVR/DVR
      cod_departamento     INT NULL,                               -- departamento que lo usa
      fecha_compra         DATE NULL,
      garantia_hasta       DATE NULL,
      observaciones        VARCHAR(500) NULL,
      sfp_combo            BOOLEAN NOT NULL DEFAULT FALSE,         -- switches: los SFP comparten número con los últimos de cobre (45F = 45T)
      creado_en            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      actualizado_en       TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla equipos */
    ALTER TABLE equipos
      ADD CONSTRAINT pk_equipos PRIMARY KEY (id),
      MODIFY id INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_equipos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_equipos_serie */
    ALTER TABLE equipos
      ADD CONSTRAINT uk_equipos_serie UNIQUE (tipo_equipo, id_marca, serie);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_equipos_serie se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_equipos_placa */
    ALTER TABLE equipos
      ADD CONSTRAINT uk_equipos_placa UNIQUE (placa_equipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_equipos_placa se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_equipos_estado */
    ALTER TABLE equipos
      ADD INDEX idx_equipos_estado (id_estado);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_equipos_estado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_equipos_nombre */
    ALTER TABLE equipos
      ADD INDEX idx_equipos_nombre (nombre_equipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_equipos_nombre se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_tipo */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_tipo FOREIGN KEY (tipo_equipo) REFERENCES tipo_equipos(tipo_equipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_marca */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_marca FOREIGN KEY (tipo_equipo, id_marca) REFERENCES marcas(tipo_equipo, id_marca);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_marca se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_modelo */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_modelo FOREIGN KEY (id_marca, id_modelo) REFERENCES modelos(id_marca, id_modelo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_modelo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_procesador */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_procesador FOREIGN KEY (id_proces) REFERENCES procesadores(id_proc);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_procesador se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_so */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_so FOREIGN KEY (id_so) REFERENCES sis_operativos(id_so);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_so se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_firmware */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_firmware FOREIGN KEY (id_firmw) REFERENCES firmwares(id_firmw);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_firmware se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_predio */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_predio FOREIGN KEY (id_predio) REFERENCES edificios(id_predio);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_predio se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_estado */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_estado FOREIGN KEY (id_estado) REFERENCES estado_equipos(id_estado);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_estado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_departamento */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_departamento FOREIGN KEY (cod_departamento) REFERENCES cat_departamentos(cod_departamento);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_departamento se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_usuario */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_equipos_proveedor */
    ALTER TABLE equipos
      ADD CONSTRAINT fk_equipos_proveedor FOREIGN KEY (id_proveedor) REFERENCES personas(id);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_equipos_proveedor se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                             Crear la tabla roles                             */
/*                                                                              */
/********************************************************************************/
-- Tabla roles: roles de cada equipo (un servidor puede ser de dominio, DHCP y DNS).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'roles') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla roles ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE roles (
      id        INT NOT NULL,   -- código del equipo
      num_linea INT NOT NULL,
      id_rol    INT NOT NULL    -- tabla catálogo tipo_roles
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla roles se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla roles */
    ALTER TABLE roles
      ADD CONSTRAINT pk_roles PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_roles se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_roles_rol */
    ALTER TABLE roles
      ADD CONSTRAINT uk_roles_rol UNIQUE (id, id_rol);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_roles_rol se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_roles_tipo */
    ALTER TABLE roles
      ADD INDEX idx_roles_tipo (id_rol);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_roles_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_roles_equipo */
    ALTER TABLE roles
      ADD CONSTRAINT fk_roles_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_roles_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_roles_tipo */
    ALTER TABLE roles
      ADD CONSTRAINT fk_roles_tipo FOREIGN KEY (id_rol) REFERENCES tipo_roles(id_rol);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_roles_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla herramientas                          */
/*                                                                              */
/********************************************************************************/
-- Tabla herramientas: herramientas de seguridad instaladas en cada equipo
-- (la 3, MICROCLAUDIA, se compara con el listado de Microclaudia).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'herramientas') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla herramientas ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE herramientas (
      id        INT NOT NULL,   -- código del equipo
      num_linea INT NOT NULL,
      id_herram INT NOT NULL    -- tabla catálogo tipo_herramientas
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla herramientas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla herramientas */
    ALTER TABLE herramientas
      ADD CONSTRAINT pk_herramientas PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_herramientas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_herramientas_herram */
    ALTER TABLE herramientas
      ADD CONSTRAINT uk_herramientas_herram UNIQUE (id, id_herram);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_herramientas_herram se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_herramientas_tipo */
    ALTER TABLE herramientas
      ADD INDEX idx_herramientas_tipo (id_herram);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_herramientas_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_herramientas_equipo */
    ALTER TABLE herramientas
      ADD CONSTRAINT fk_herramientas_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_herramientas_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_herramientas_tipo */
    ALTER TABLE herramientas
      ADD CONSTRAINT fk_herramientas_tipo FOREIGN KEY (id_herram) REFERENCES tipo_herramientas(id_herram);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_herramientas_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                           Crear la tabla dir_macs                            */
/*                                                                              */
/********************************************************************************/
-- Tabla dir_macs: direcciones MAC de cada equipo. Se guardan enteras, sin
-- separadores; la página las muestra con guiones. Una MAC no se repite en
-- todo el inventario.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dir_macs') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla dir_macs ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE dir_macs (
      id        INT NOT NULL,        -- código del equipo
      num_linea INT NOT NULL,
      dir_mac   CHAR(12) NOT NULL,   -- sin separadores: AABBCCDDEEFF
      interfaz  VARCHAR(50) NULL     -- opcional: WAN, LAN, GESTIÓN, GI0/1...
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla dir_macs se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla dir_macs */
    ALTER TABLE dir_macs
      ADD CONSTRAINT pk_dir_macs PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_dir_macs se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_dir_macs_mac */
    ALTER TABLE dir_macs
      ADD CONSTRAINT uk_dir_macs_mac UNIQUE (dir_mac);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_dir_macs_mac se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_dir_macs_equipo */
    ALTER TABLE dir_macs
      ADD CONSTRAINT fk_dir_macs_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_dir_macs_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_dir_macs_mac */
    ALTER TABLE dir_macs
      ADD CONSTRAINT ck_dir_macs_mac CHECK (dir_mac REGEXP '^[0-9A-F]{12}$');
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_dir_macs_mac se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                            Crear la tabla dir_ips                            */
/*                                                                              */
/********************************************************************************/
-- Tabla dir_ips: direcciones IP de cada equipo.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dir_ips') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla dir_ips ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE dir_ips (
      id        INT NOT NULL,           -- código del equipo
      num_linea INT NOT NULL,
      dir_ip    VARCHAR(45) NOT NULL,   -- IPv4 o IPv6
      interfaz  VARCHAR(50) NULL        -- opcional: WAN, LAN, GESTIÓN, GI0/1...
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla dir_ips se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla dir_ips */
    ALTER TABLE dir_ips
      ADD CONSTRAINT pk_dir_ips PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_dir_ips se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_dir_ips_equipo */
    ALTER TABLE dir_ips
      ADD CONSTRAINT uk_dir_ips_equipo UNIQUE (id, dir_ip);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_dir_ips_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_dir_ips_ip */
    ALTER TABLE dir_ips
      ADD INDEX idx_dir_ips_ip (dir_ip);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_dir_ips_ip se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_dir_ips_equipo */
    ALTER TABLE dir_ips
      ADD CONSTRAINT fk_dir_ips_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_dir_ips_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla num_moviles                          */
/*                                                                              */
/********************************************************************************/
-- Tabla num_moviles: líneas telefónicas de cada equipo (celulares, tablets).
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'num_moviles') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla num_moviles ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE num_moviles (
      id        INT NOT NULL,           -- código del equipo
      num_linea INT NOT NULL,
      num_movil VARCHAR(20) NOT NULL,   -- número de la línea
      operador  VARCHAR(50) NULL        -- KÖLBI, CLARO, LIBERTY...
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla num_moviles se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla num_moviles */
    ALTER TABLE num_moviles
      ADD CONSTRAINT pk_num_moviles PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_num_moviles se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_num_moviles_equipo */
    ALTER TABLE num_moviles
      ADD CONSTRAINT uk_num_moviles_equipo UNIQUE (id, num_movil);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_num_moviles_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_num_moviles_equipo */
    ALTER TABLE num_moviles
      ADD CONSTRAINT fk_num_moviles_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_num_moviles_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                           Crear la tabla dir_imeis                           */
/*                                                                              */
/********************************************************************************/
-- Tabla dir_imeis: IMEI de cada equipo, uno por SIM. No se repite en todo el
-- inventario.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dir_imeis') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla dir_imeis ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE dir_imeis (
      id        INT NOT NULL,           -- código del equipo
      num_linea INT NOT NULL,
      dir_imei  VARCHAR(15) NOT NULL    -- 15 dígitos
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla dir_imeis se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla dir_imeis */
    ALTER TABLE dir_imeis
      ADD CONSTRAINT pk_dir_imeis PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_dir_imeis se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_dir_imeis_imei */
    ALTER TABLE dir_imeis
      ADD CONSTRAINT uk_dir_imeis_imei UNIQUE (dir_imei);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_dir_imeis_imei se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_dir_imeis_equipo */
    ALTER TABLE dir_imeis
      ADD CONSTRAINT fk_dir_imeis_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_dir_imeis_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_dir_imeis_imei */
    ALTER TABLE dir_imeis
      ADD CONSTRAINT ck_dir_imeis_imei CHECK (dir_imei REGEXP '^[0-9]{15}$');
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_dir_imeis_imei se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                           Crear la tabla archivos                            */
/*                                                                              */
/********************************************************************************/
-- Tabla archivos: manuales, garantías, configuraciones, respaldos... de cada
-- equipo. El archivo vive en el servidor; aquí va su ruta.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'archivos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla archivos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE archivos (
      id        INT NOT NULL,                          -- código del equipo
      num_linea INT NOT NULL,
      tipo_arch INT NOT NULL,                          -- tabla catálogo tipo_archivos
      path_arch VARCHAR(255) NOT NULL,                 -- ruta del archivo en el servidor
      creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla archivos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla archivos */
    ALTER TABLE archivos
      ADD CONSTRAINT pk_archivos PRIMARY KEY (id, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_archivos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_archivos_tipo */
    ALTER TABLE archivos
      ADD INDEX idx_archivos_tipo (tipo_arch);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_archivos_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_archivos_equipo */
    ALTER TABLE archivos
      ADD CONSTRAINT fk_archivos_equipo FOREIGN KEY (id) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_archivos_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_archivos_tipo */
    ALTER TABLE archivos
      ADD CONSTRAINT fk_archivos_tipo FOREIGN KEY (tipo_arch) REFERENCES tipo_archivos(tipo_arch);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_archivos_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                        Crear la tabla puertos_switch                         */
/*                                                                              */
/********************************************************************************/
-- Puertos de los switches (y demás equipos de red con puertos): qué equipo
-- del inventario está conectado a cada uno, su estado, su VLAN y una nota.
-- Solo se guardan los puertos con algún dato; los que no están, están libres.
-- tipo_puerto T = cobre (1..cant_ptos_eth) y F = SFP (1..cant_ptos_sfp).
-- El rótulo que se ve (12, 45T, 45F, 49) lo da fn_rotulo_puerto según el
-- check sfp_combo del switch.
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'puertos_switch') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla puertos_switch ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE puertos_switch (
      id_switch      INT NOT NULL,                           -- equipo con los puertos
      tipo_puerto    CHAR(1) NOT NULL,                       -- T = cobre, F = SFP
      num_puerto     SMALLINT UNSIGNED NOT NULL,
      id_equipo      INT NULL,                               -- equipo conectado
      estado         VARCHAR(15) NOT NULL DEFAULT 'LIBRE',   -- EN_USO, LIBRE, DESHABILITADO, DANADO
      vlan           VARCHAR(30) NULL,                       -- 10, 10,20 o 1-100
      nota           VARCHAR(255) NULL,                      -- rótulo del cable, patch panel, oficina
      actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla puertos_switch se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla puertos_switch */
    ALTER TABLE puertos_switch
      ADD CONSTRAINT pk_puertos_switch PRIMARY KEY (id_switch, tipo_puerto, num_puerto);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_puertos_switch se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_puertos_equipo */
    ALTER TABLE puertos_switch
      ADD INDEX idx_puertos_equipo (id_equipo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_puertos_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_puertos_switch */
    ALTER TABLE puertos_switch
      ADD CONSTRAINT fk_puertos_switch FOREIGN KEY (id_switch) REFERENCES equipos(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_puertos_switch se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_puertos_equipo */
    ALTER TABLE puertos_switch
      ADD CONSTRAINT fk_puertos_equipo FOREIGN KEY (id_equipo) REFERENCES equipos(id) ON DELETE SET NULL;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_puertos_equipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_puertos_tipo */
    ALTER TABLE puertos_switch
      ADD CONSTRAINT ck_puertos_tipo CHECK (tipo_puerto IN ('T', 'F'));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_puertos_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_puertos_estado */
    ALTER TABLE puertos_switch
      ADD CONSTRAINT ck_puertos_estado CHECK (estado IN ('EN_USO', 'LIBRE', 'DESHABILITADO', 'DANADO'));
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_puertos_estado se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

-- =====================================================================
-- Índice para el historial de cada equipo: busca en la auditoría por
-- tabla y llave (sp_equipos_historial).
-- =====================================================================
CREATE INDEX IF NOT EXISTS idx_aud_tabla_llave ON aud_auditorias (tabla, llave);
