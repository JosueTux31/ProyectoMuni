-- =====================================================================
--  01_ESTRUCTURA.SQL - gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 1 de 3: crea la base de datos y todas las tablas, ya en su
--  versión final (incluye proveedores, código postal, auditoría y padrón).
--
--  Módulo de usuarios y proveedores. Orden de instalación (lo sigue
--  reinstalar_base.sh):
--     1. 01_estructura.sql        (este archivo)
--     2. 02_procedimientos.sql    funciones, procedimientos y disparadores
--     3. 03_datos.sql             catálogos y territorio de Costa Rica
--
--  Cada tabla sigue el estilo de la especificación: si ya existe se
--  avisa y no se toca; si no, se crea y después se le agregan su llave
--  primaria, sus índices y sus llaves foráneas, avisando cada paso. Se
--  puede ejecutar más de una vez: no borra ni cambia tablas que ya
--  existan. La tabla de usuarios y proveedores se llama personas.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS gestion_redes
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base, con el programa que sea que lo ejecute: así
-- las tildes se guardan bien y nada mezcla intercalaciones distintas.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;


-- =====================================================================
-- 1. DIVISIÓN TERRITORIAL (códigos en texto)
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla geo_paises                           */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'geo_paises') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_paises ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE geo_paises (
      cod_pais    VARCHAR(10) NOT NULL,    -- Ej: 'CR', 'USA', 'ES'
      nombre_pais VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_paises se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla geo_paises */
    ALTER TABLE geo_paises
      ADD CONSTRAINT pk_geo_paises PRIMARY KEY (cod_pais);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_geo_paises se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                        Crear la tabla geo_provincias                         */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'geo_provincias') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_provincias ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE geo_provincias (
      cod_pais         VARCHAR(10) NOT NULL,
      cod_provincia    VARCHAR(10) NOT NULL,
      nombre_provincia VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_provincias se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla geo_provincias */
    ALTER TABLE geo_provincias
      ADD CONSTRAINT pk_geo_provincias PRIMARY KEY (cod_pais, cod_provincia);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_geo_provincias se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_geo_provincias_pais */
    ALTER TABLE geo_provincias
      ADD CONSTRAINT fk_geo_provincias_pais FOREIGN KEY (cod_pais) REFERENCES geo_paises(cod_pais);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_geo_provincias_pais se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla geo_cantones                          */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'geo_cantones') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_cantones ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE geo_cantones (
      cod_pais      VARCHAR(10) NOT NULL,
      cod_provincia VARCHAR(10) NOT NULL,
      cod_canton    VARCHAR(10) NOT NULL,
      nombre_canton VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_cantones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla geo_cantones */
    ALTER TABLE geo_cantones
      ADD CONSTRAINT pk_geo_cantones PRIMARY KEY (cod_pais, cod_provincia, cod_canton);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_geo_cantones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_geo_cantones_provincia */
    ALTER TABLE geo_cantones
      ADD CONSTRAINT fk_geo_cantones_provincia FOREIGN KEY (cod_pais, cod_provincia) REFERENCES geo_provincias(cod_pais, cod_provincia);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_geo_cantones_provincia se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla geo_distritos                         */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'geo_distritos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_distritos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE geo_distritos (
      cod_pais        VARCHAR(10) NOT NULL,
      cod_provincia   VARCHAR(10) NOT NULL,
      cod_canton      VARCHAR(10) NOT NULL,
      cod_distrito    VARCHAR(10) NOT NULL,
      nombre_distrito VARCHAR(100) NOT NULL,
      codigo_postal   VARCHAR(10) NULL         -- provincia + cantón + distrito (ej. 20301)
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla geo_distritos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla geo_distritos */
    ALTER TABLE geo_distritos
      ADD CONSTRAINT pk_geo_distritos PRIMARY KEY (cod_pais, cod_provincia, cod_canton, cod_distrito);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_geo_distritos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_geo_distritos_cp */
    ALTER TABLE geo_distritos
      ADD INDEX idx_geo_distritos_cp (codigo_postal);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_geo_distritos_cp se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_geo_distritos_canton */
    ALTER TABLE geo_distritos
      ADD CONSTRAINT fk_geo_distritos_canton FOREIGN KEY (cod_pais, cod_provincia, cod_canton) REFERENCES geo_cantones(cod_pais, cod_provincia, cod_canton);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_geo_distritos_canton se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;


-- =====================================================================
-- 2. CATÁLOGOS DEL SISTEMA
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                  Crear la tabla cat_tipos_identificaciones                   */
/*                                                                              */
/********************************************************************************/
-- Cédula física, jurídica, DIMEX, pasaporte...
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_tipos_identificaciones') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_identificaciones ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_tipos_identificaciones (
      cod_tipo_identificacion INT NOT NULL,
      descripcion             VARCHAR(50) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_identificaciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_tipos_identificaciones */
    ALTER TABLE cat_tipos_identificaciones
      ADD CONSTRAINT pk_cat_tipos_identificaciones PRIMARY KEY (cod_tipo_identificacion),
      MODIFY cod_tipo_identificacion INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_tipos_identificaciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                      Crear la tabla cat_roles_usuarios                       */
/*                                                                              */
/********************************************************************************/
-- Administrador, estándar...
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_roles_usuarios') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_roles_usuarios ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_roles_usuarios (
      cod_rol     INT NOT NULL,
      descripcion VARCHAR(50) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_roles_usuarios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_roles_usuarios */
    ALTER TABLE cat_roles_usuarios
      ADD CONSTRAINT pk_cat_roles_usuarios PRIMARY KEY (cod_rol),
      MODIFY cod_rol INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_roles_usuarios se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                   Crear la tabla cat_tipos_autenticaciones                   */
/*                                                                              */
/********************************************************************************/
-- Sistema App, Active Directory
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_tipos_autenticaciones') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_autenticaciones ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_tipos_autenticaciones (
      cod_tipo_auth INT NOT NULL,
      descripcion   VARCHAR(80) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_autenticaciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_tipos_autenticaciones */
    ALTER TABLE cat_tipos_autenticaciones
      ADD CONSTRAINT pk_cat_tipos_autenticaciones PRIMARY KEY (cod_tipo_auth),
      MODIFY cod_tipo_auth INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_tipos_autenticaciones se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla cat_departamentos                       */
/*                                                                              */
/********************************************************************************/
-- Departamentos municipales
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_departamentos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_departamentos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_departamentos (
      cod_departamento INT NOT NULL,
      descripcion      VARCHAR(120) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_departamentos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_departamentos */
    ALTER TABLE cat_departamentos
      ADD CONSTRAINT pk_cat_departamentos PRIMARY KEY (cod_departamento),
      MODIFY cod_departamento INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_departamentos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                      Crear la tabla cat_tipos_telefonos                      */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_tipos_telefonos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_telefonos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_tipos_telefonos (
      cod_telefono INT NOT NULL,
      descripcion  VARCHAR(50) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_telefonos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_tipos_telefonos */
    ALTER TABLE cat_tipos_telefonos
      ADD CONSTRAINT pk_cat_tipos_telefonos PRIMARY KEY (cod_telefono),
      MODIFY cod_telefono INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_tipos_telefonos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla cat_tipos_correos                       */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_tipos_correos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_correos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_tipos_correos (
      cod_correo  INT NOT NULL,
      descripcion VARCHAR(50) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_tipos_correos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_tipos_correos */
    ALTER TABLE cat_tipos_correos
      ADD CONSTRAINT pk_cat_tipos_correos PRIMARY KEY (cod_correo),
      MODIFY cod_correo INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_tipos_correos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                  Crear la tabla cat_categorias_proveedores                   */
/*                                                                              */
/********************************************************************************/
-- Categorías de proveedores
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'cat_categorias_proveedores') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_categorias_proveedores ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE cat_categorias_proveedores (
      cod_categoria INT NOT NULL,
      descripcion   VARCHAR(150) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla cat_categorias_proveedores se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla cat_categorias_proveedores */
    ALTER TABLE cat_categorias_proveedores
      ADD CONSTRAINT pk_cat_categorias_proveedores PRIMARY KEY (cod_categoria),
      MODIFY cod_categoria INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_cat_categorias_proveedores se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;


-- =====================================================================
-- 3. USUARIOS Y PROVEEDORES (una sola tabla)
--    es_proveedor = FALSE: usuario del sistema (rol, inicio de sesión)
--    es_proveedor = TRUE:  proveedor (categoría; nunca inicia sesión)
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                           Crear la tabla personas                            */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'personas') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla personas ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE personas (
      id                      INT NOT NULL,
      es_proveedor            BOOLEAN NOT NULL DEFAULT FALSE,
      cod_categoria           INT NULL,                               -- solo proveedores
      cod_rol                 INT NULL,                               -- Clasificación (rol y forma de inicio de sesión: solo usuarios)
      cod_tipo_auth           INT NULL,
      cod_tipo_identificacion INT NOT NULL,
      dni                     VARCHAR(30) NOT NULL,
      nombre                  VARCHAR(150) NOT NULL,                  -- Datos de la persona o empresa (en empresas: razón social en nombre)
      apellido1               VARCHAR(100) NULL,
      apellido2               VARCHAR(100) NULL,
      cod_pais                VARCHAR(10) NOT NULL,                   -- Ubicación
      cod_provincia           VARCHAR(10) NOT NULL,
      cod_canton              VARCHAR(10) NOT NULL,
      cod_distrito            VARCHAR(10) NOT NULL,
      codigo_postal           VARCHAR(10) NULL,                       -- lo asigna un disparador según el distrito
      otras_senas             TEXT NULL,
      mapa                    VARCHAR(100) NULL,                      -- "latitud,longitud" (proveedores)
      imagen_path             VARCHAR(255) NULL,                      -- Archivos (ruta relativa dentro de la carpeta "archivos" de Django)
      archivo_path            VARCHAR(255) NULL,                      -- catálogo de servicios del proveedor
      cod_departamento        INT NULL,                               -- Acceso (solo usuarios)
      usuario_red             VARCHAR(50) NULL,                       -- login (app o Active Directory)
      password_hash           VARCHAR(255) NULL,                      -- NULL si entra por Active Directory
      activo                  BOOLEAN DEFAULT TRUE,                   -- Control
      creado_en               TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      actualizado_en          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla personas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla personas */
    ALTER TABLE personas
      ADD CONSTRAINT pk_personas PRIMARY KEY (id),
      MODIFY id INT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_personas se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_usr_documento */
    ALTER TABLE personas
      ADD CONSTRAINT uk_usr_documento UNIQUE (cod_tipo_identificacion, dni, es_proveedor);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_usr_documento se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice único uk_usr_login */
    ALTER TABLE personas
      ADD CONSTRAINT uk_usr_login UNIQUE (usuario_red);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice único uk_usr_login se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_usr_tipo_identificacion */
    ALTER TABLE personas
      ADD INDEX idx_usr_tipo_identificacion (cod_tipo_identificacion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_usr_tipo_identificacion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_usr_es_proveedor */
    ALTER TABLE personas
      ADD INDEX idx_usr_es_proveedor (es_proveedor, activo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_usr_es_proveedor se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_usr_rol */
    ALTER TABLE personas
      ADD CONSTRAINT fk_usr_rol FOREIGN KEY (cod_rol) REFERENCES cat_roles_usuarios(cod_rol);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_usr_rol se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_usr_auth */
    ALTER TABLE personas
      ADD CONSTRAINT fk_usr_auth FOREIGN KEY (cod_tipo_auth) REFERENCES cat_tipos_autenticaciones(cod_tipo_auth);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_usr_auth se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_usr_tipo_identificacion */
    ALTER TABLE personas
      ADD CONSTRAINT fk_usr_tipo_identificacion FOREIGN KEY (cod_tipo_identificacion) REFERENCES cat_tipos_identificaciones(cod_tipo_identificacion);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_usr_tipo_identificacion se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_usr_distrito */
    ALTER TABLE personas
      ADD CONSTRAINT fk_usr_distrito FOREIGN KEY (cod_pais, cod_provincia, cod_canton, cod_distrito) REFERENCES geo_distritos(cod_pais, cod_provincia, cod_canton, cod_distrito);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_usr_distrito se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_usr_departamento */
    ALTER TABLE personas
      ADD CONSTRAINT fk_usr_departamento FOREIGN KEY (cod_departamento) REFERENCES cat_departamentos(cod_departamento);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_usr_departamento se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_usr_categoria_proveedor */
    ALTER TABLE personas
      ADD CONSTRAINT fk_usr_categoria_proveedor FOREIGN KEY (cod_categoria) REFERENCES cat_categorias_proveedores(cod_categoria);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_usr_categoria_proveedor se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Revisión de datos ck_usr_tipo_registro */
    ALTER TABLE personas
      ADD CONSTRAINT ck_usr_tipo_registro CHECK ( (es_proveedor = 0 AND cod_rol IS NOT NULL AND cod_tipo_auth IS NOT NULL AND cod_categoria IS NULL) OR (es_proveedor = 1 AND cod_categoria IS NOT NULL AND cod_rol IS NULL AND cod_tipo_auth IS NULL AND usuario_red IS NULL AND password_hash IS NULL) );
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La revisión ck_usr_tipo_registro se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;


-- =====================================================================
-- 4. DETALLE DE USUARIOS Y PROVEEDORES
--    num_linea lo calculan los procedimientos (1, 2, 3... por persona)
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                         Crear la tabla usr_telefonos                         */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usr_telefonos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_telefonos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE usr_telefonos (
      id_usuario   INT NOT NULL,
      num_linea    INT NOT NULL,
      cod_telefono INT NOT NULL,
      telefono     VARCHAR(25) NOT NULL,    -- se guarda como 0000-0000
      es_whatsapp  BOOLEAN DEFAULT FALSE
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_telefonos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla usr_telefonos */
    ALTER TABLE usr_telefonos
      ADD CONSTRAINT pk_usr_telefonos PRIMARY KEY (id_usuario, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_usr_telefonos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_utelefonos_usuario */
    ALTER TABLE usr_telefonos
      ADD CONSTRAINT fk_utelefonos_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_utelefonos_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_utelefonos_tipo */
    ALTER TABLE usr_telefonos
      ADD CONSTRAINT fk_utelefonos_tipo FOREIGN KEY (cod_telefono) REFERENCES cat_tipos_telefonos(cod_telefono);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_utelefonos_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla usr_correos                          */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usr_correos') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_correos ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE usr_correos (
      id_usuario INT NOT NULL,
      num_linea  INT NOT NULL,
      cod_correo INT NOT NULL,
      correo     VARCHAR(150) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_correos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla usr_correos */
    ALTER TABLE usr_correos
      ADD CONSTRAINT pk_usr_correos PRIMARY KEY (id_usuario, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_usr_correos se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_ucorreos_usuario */
    ALTER TABLE usr_correos
      ADD CONSTRAINT fk_ucorreos_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_ucorreos_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_ucorreos_tipo */
    ALTER TABLE usr_correos
      ADD CONSTRAINT fk_ucorreos_tipo FOREIGN KEY (cod_correo) REFERENCES cat_tipos_correos(cod_correo);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_ucorreos_tipo se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                       Crear la tabla usr_paginas_webs                        */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usr_paginas_webs') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_paginas_webs ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE usr_paginas_webs (
      id_usuario INT NOT NULL,
      num_linea  INT NOT NULL,
      url_web    VARCHAR(255) NOT NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_paginas_webs se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla usr_paginas_webs */
    ALTER TABLE usr_paginas_webs
      ADD CONSTRAINT pk_usr_paginas_webs PRIMARY KEY (id_usuario, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_usr_paginas_webs se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_uweb_usuario */
    ALTER TABLE usr_paginas_webs
      ADD CONSTRAINT fk_uweb_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_uweb_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                    Crear la tabla usr_historiales_claves                     */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usr_historiales_claves') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_historiales_claves ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE usr_historiales_claves (
      id_usuario     INT NOT NULL,
      num_linea      INT NOT NULL,
      password_hash  VARCHAR(255) NOT NULL,
      fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla usr_historiales_claves se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla usr_historiales_claves */
    ALTER TABLE usr_historiales_claves
      ADD CONSTRAINT pk_usr_historiales_claves PRIMARY KEY (id_usuario, num_linea);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_usr_historiales_claves se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave foránea fk_uclaves_usuario */
    ALTER TABLE usr_historiales_claves
      ADD CONSTRAINT fk_uclaves_usuario FOREIGN KEY (id_usuario) REFERENCES personas(id) ON DELETE CASCADE;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave foránea fk_uclaves_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;


-- =====================================================================
-- 5. AUDITORÍA
--    Un registro por cada alta, cambio o baja en cualquier tabla, más
--    inicios y cierres de sesión. Sin llaves foráneas: el historial se
--    conserva aunque se borre el usuario. Disparadores impiden
--    modificar o borrar estos registros.
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                        Crear la tabla aud_auditorias                         */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'aud_auditorias') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla aud_auditorias ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE aud_auditorias (
      id             BIGINT NOT NULL,
      fecha          TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
      id_usuario     INT NULL,                               -- quién lo hizo (NULL = sistema o script)
      nombre_usuario VARCHAR(255) NULL,                      -- nombre de quién lo hizo en ese momento
      ip             VARCHAR(45) NULL,
      accion         VARCHAR(20) NOT NULL,                   -- INSERTAR, ACTUALIZAR, ELIMINAR, INICIO_SESION, CIERRE_SESION, INICIO_FALLIDO
      tabla          VARCHAR(64) NULL,
      llave          VARCHAR(255) NULL,                      -- llave del registro, p. ej. "5" o "5/2"
      id_persona     INT NULL,                               -- usuario o proveedor al que pertenece el registro
      descripcion    VARCHAR(255) NULL,                      -- nombre legible del registro afectado
      datos_antes    JSON NULL,
      datos_despues  JSON NULL
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla aud_auditorias se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla aud_auditorias */
    ALTER TABLE aud_auditorias
      ADD CONSTRAINT pk_aud_auditorias PRIMARY KEY (id),
      MODIFY id BIGINT NOT NULL AUTO_INCREMENT;
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_aud_auditorias se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_aud_fecha */
    ALTER TABLE aud_auditorias
      ADD INDEX idx_aud_fecha (fecha);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_aud_fecha se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_aud_usuario */
    ALTER TABLE aud_auditorias
      ADD INDEX idx_aud_usuario (id_usuario, id);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_aud_usuario se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_aud_persona */
    ALTER TABLE aud_auditorias
      ADD INDEX idx_aud_persona (id_persona, id);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_aud_persona se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Índice idx_aud_tabla */
    ALTER TABLE aud_auditorias
      ADD INDEX idx_aud_tabla (tabla, id);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡El índice idx_aud_tabla se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;


-- =====================================================================
-- 6. PADRÓN ELECTORAL DEL TSE (búsqueda de nombre por cédula)
--    Se llena con:  python manage.py cargar_padron --descargar
-- =====================================================================

/********************************************************************************/
/*                                                                              */
/*                          Crear la tabla pad_padron                           */
/*                                                                              */
/********************************************************************************/
/* Si la tabla existe se avisa; si no, se crea con sus llaves */
DELIMITER $$
BEGIN NOT ATOMIC
  IF EXISTS (SELECT 1 FROM information_schema.TABLES
              WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'pad_padron') THEN
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla pad_padron ya existe!'
     UNION ALL SELECT '***********************************************************************************************';
  ELSE
    CREATE TABLE pad_padron (
      cedula      VARCHAR(9) NOT NULL,
      nombre      VARCHAR(100) NOT NULL,
      apellido1   VARCHAR(100) NULL,
      apellido2   VARCHAR(100) NULL,
      sexo        TINYINT NULL,            -- 1 hombre, 2 mujer (como lo publica el TSE)
      vencimiento DATE NULL,               -- vencimiento de la cédula
      codelec     VARCHAR(6) NULL          -- código electoral (distrito de votación)
    ) ENGINE=InnoDB;

    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La tabla pad_padron se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';

    /* Llave primaria de la tabla pad_padron */
    ALTER TABLE pad_padron
      ADD CONSTRAINT pk_pad_padron PRIMARY KEY (cedula);
    SELECT '***********************************************************************************************' AS ''
     UNION ALL SELECT '¡La llave primaria pk_pad_padron se creó correctamente!'
     UNION ALL SELECT '***********************************************************************************************';
  END IF;
END $$
DELIMITER ;
