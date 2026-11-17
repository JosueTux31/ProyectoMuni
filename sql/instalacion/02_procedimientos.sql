-- =====================================================================
--  02_PROCEDIMIENTOS.SQL - gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 2 de 3. Ejecutar después de 01_estructura.sql.
--
--  Contiene la versión final de todo el código de la base de datos:
--    - 1 función (fn_formato_telefono)
--    - 98 procedimientos almacenados (CRUD de cada tabla, proveedores,
--      auditoría y padrón). Convención: sp_<tabla>_<acción>
--        _insertar   crea un registro (OUT con la llave generada)
--        _actualizar modifica por llave primaria
--        _eliminar   borra (usuarios y proveedores: desactiva)
--        _obtener    un registro por llave primaria
--        _listar     varios registros (filtros opcionales: NULL = todos)
--      Si no encuentran el registro: SIGNAL SQLSTATE '45000' con mensaje.
--    - 82 disparadores: código postal automático, mayúsculas, formato
--      de teléfono y auditoría de todas las tablas.
--
--  Se puede ejecutar más de una vez: reemplaza lo que ya exista.
-- =====================================================================

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base, con el programa que sea que lo ejecute: así
-- las tildes se guardan bien y nada mezcla intercalaciones distintas.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;

DELIMITER $$

-- =====================================================================
-- Modelo de datos nuevo: la tabla usr_usuarios se llama ahora personas.
-- Se quitan los procedimientos y disparadores con el nombre anterior
-- (los disparadores siguen pegados a la tabla después de renombrarla).
-- =====================================================================
DROP PROCEDURE IF EXISTS sp_usr_usuarios_activar$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_actualizar$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_actualizar_imagen$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_cambiar_clave$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_eliminar$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_eliminar_fisico$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_insertar$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_listar$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_obtener$$
DROP PROCEDURE IF EXISTS sp_usr_usuarios_obtener_por_login$$
DROP TRIGGER IF EXISTS trg_aud_usr_usuarios_del$$
DROP TRIGGER IF EXISTS trg_aud_usr_usuarios_ins$$
DROP TRIGGER IF EXISTS trg_aud_usr_usuarios_upd$$
DROP TRIGGER IF EXISTS trg_mayus_usr_usuarios_ins$$
DROP TRIGGER IF EXISTS trg_mayus_usr_usuarios_upd$$
DROP TRIGGER IF EXISTS trg_usr_usuarios_cp_ins$$
DROP TRIGGER IF EXISTS trg_usr_usuarios_cp_upd$$

-- =====================================================================
-- 0. FUNCIONES
-- =====================================================================

CREATE OR REPLACE FUNCTION fn_formato_telefono(p_telefono VARCHAR(25))
RETURNS VARCHAR(25) DETERMINISTIC NO SQL
BEGIN
    DECLARE v_digitos VARCHAR(25);
    IF p_telefono IS NULL THEN
        RETURN NULL;
    END IF;
    SET v_digitos = REGEXP_REPLACE(p_telefono, '[^0-9]', '');
    IF TRIM(p_telefono) NOT LIKE '+%' AND CHAR_LENGTH(v_digitos) = 8 THEN
        RETURN CONCAT(LEFT(v_digitos, 4), '-', RIGHT(v_digitos, 4));
    END IF;
    RETURN TRIM(p_telefono);
END$$


-- =====================================================================
-- 1. DIVISIÓN TERRITORIAL
-- =====================================================================

-- -------------------- geo_paises --------------------------------
CREATE OR REPLACE PROCEDURE sp_geo_paises_insertar(
    IN p_cod_pais    VARCHAR(10),
    IN p_nombre_pais VARCHAR(100)
)
BEGIN
    INSERT INTO geo_paises (cod_pais, nombre_pais)
    VALUES (p_cod_pais, p_nombre_pais);
END$$

CREATE OR REPLACE PROCEDURE sp_geo_paises_actualizar(
    IN p_cod_pais    VARCHAR(10),
    IN p_nombre_pais VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM geo_paises WHERE cod_pais = p_cod_pais) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El país no existe.';
    END IF;
    UPDATE geo_paises
       SET nombre_pais = p_nombre_pais
     WHERE cod_pais = p_cod_pais;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_paises_eliminar(
    IN p_cod_pais VARCHAR(10)
)
BEGIN
    DELETE FROM geo_paises WHERE cod_pais = p_cod_pais;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El país no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_paises_obtener(
    IN p_cod_pais VARCHAR(10)
)
BEGIN
    SELECT cod_pais, nombre_pais
      FROM geo_paises
     WHERE cod_pais = p_cod_pais;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_paises_listar()
BEGIN
    SELECT cod_pais, nombre_pais
      FROM geo_paises
     ORDER BY nombre_pais;
END$$

-- -------------------- geo_provincias ----------------------------
CREATE OR REPLACE PROCEDURE sp_geo_provincias_insertar(
    IN p_cod_pais         VARCHAR(10),
    IN p_cod_provincia    VARCHAR(10),
    IN p_nombre_provincia VARCHAR(100)
)
BEGIN
    INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia)
    VALUES (p_cod_pais, p_cod_provincia, p_nombre_provincia);
END$$

CREATE OR REPLACE PROCEDURE sp_geo_provincias_actualizar(
    IN p_cod_pais         VARCHAR(10),
    IN p_cod_provincia    VARCHAR(10),
    IN p_nombre_provincia VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM geo_provincias
                    WHERE cod_pais = p_cod_pais AND cod_provincia = p_cod_provincia) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La provincia no existe.';
    END IF;
    UPDATE geo_provincias
       SET nombre_provincia = p_nombre_provincia
     WHERE cod_pais = p_cod_pais
       AND cod_provincia = p_cod_provincia;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_provincias_eliminar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10)
)
BEGIN
    DELETE FROM geo_provincias
     WHERE cod_pais = p_cod_pais
       AND cod_provincia = p_cod_provincia;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La provincia no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_provincias_obtener(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10)
)
BEGIN
    SELECT p.cod_pais, pa.nombre_pais, p.cod_provincia, p.nombre_provincia
      FROM geo_provincias p
      JOIN geo_paises pa ON pa.cod_pais = p.cod_pais
     WHERE p.cod_pais = p_cod_pais
       AND p.cod_provincia = p_cod_provincia;
END$$

-- p_cod_pais NULL = todas las provincias
CREATE OR REPLACE PROCEDURE sp_geo_provincias_listar(
    IN p_cod_pais VARCHAR(10)
)
BEGIN
    SELECT p.cod_pais, pa.nombre_pais, p.cod_provincia, p.nombre_provincia
      FROM geo_provincias p
      JOIN geo_paises pa ON pa.cod_pais = p.cod_pais
     WHERE (p_cod_pais IS NULL OR p.cod_pais = p_cod_pais)
     ORDER BY p.cod_pais, p.cod_provincia;
END$$

-- -------------------- geo_cantones ------------------------------
CREATE OR REPLACE PROCEDURE sp_geo_cantones_insertar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10),
    IN p_nombre_canton VARCHAR(100)
)
BEGIN
    INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton)
    VALUES (p_cod_pais, p_cod_provincia, p_cod_canton, p_nombre_canton);
END$$

CREATE OR REPLACE PROCEDURE sp_geo_cantones_actualizar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10),
    IN p_nombre_canton VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM geo_cantones
                    WHERE cod_pais = p_cod_pais AND cod_provincia = p_cod_provincia
                      AND cod_canton = p_cod_canton) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cantón no existe.';
    END IF;
    UPDATE geo_cantones
       SET nombre_canton = p_nombre_canton
     WHERE cod_pais = p_cod_pais
       AND cod_provincia = p_cod_provincia
       AND cod_canton = p_cod_canton;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_cantones_eliminar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10)
)
BEGIN
    DELETE FROM geo_cantones
     WHERE cod_pais = p_cod_pais
       AND cod_provincia = p_cod_provincia
       AND cod_canton = p_cod_canton;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cantón no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_cantones_obtener(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10)
)
BEGIN
    SELECT c.cod_pais, c.cod_provincia, pr.nombre_provincia,
           c.cod_canton, c.nombre_canton
      FROM geo_cantones c
      JOIN geo_provincias pr ON pr.cod_pais = c.cod_pais
                            AND pr.cod_provincia = c.cod_provincia
     WHERE c.cod_pais = p_cod_pais
       AND c.cod_provincia = p_cod_provincia
       AND c.cod_canton = p_cod_canton;
END$$

-- Filtros opcionales: NULL = sin filtro
CREATE OR REPLACE PROCEDURE sp_geo_cantones_listar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10)
)
BEGIN
    SELECT c.cod_pais, c.cod_provincia, pr.nombre_provincia,
           c.cod_canton, c.nombre_canton
      FROM geo_cantones c
      JOIN geo_provincias pr ON pr.cod_pais = c.cod_pais
                            AND pr.cod_provincia = c.cod_provincia
     WHERE (p_cod_pais IS NULL OR c.cod_pais = p_cod_pais)
       AND (p_cod_provincia IS NULL OR c.cod_provincia = p_cod_provincia)
     ORDER BY c.cod_pais, c.cod_provincia, c.cod_canton;
END$$

-- -------------------- geo_distritos -----------------------------
CREATE OR REPLACE PROCEDURE sp_geo_distritos_insertar(
    IN p_cod_pais        VARCHAR(10),
    IN p_cod_provincia   VARCHAR(10),
    IN p_cod_canton      VARCHAR(10),
    IN p_cod_distrito    VARCHAR(10),
    IN p_nombre_distrito VARCHAR(100),
    IN p_codigo_postal   VARCHAR(10)    -- NULL: se arma con los códigos (solo CR)
)
BEGIN
    INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    VALUES (p_cod_pais, p_cod_provincia, p_cod_canton, p_cod_distrito, p_nombre_distrito, NULLIF(p_codigo_postal, ''));
END$$

CREATE OR REPLACE PROCEDURE sp_geo_distritos_actualizar(
    IN p_cod_pais        VARCHAR(10),
    IN p_cod_provincia   VARCHAR(10),
    IN p_cod_canton      VARCHAR(10),
    IN p_cod_distrito    VARCHAR(10),
    IN p_nombre_distrito VARCHAR(100),
    IN p_codigo_postal   VARCHAR(10)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM geo_distritos
                    WHERE cod_pais = p_cod_pais AND cod_provincia = p_cod_provincia
                      AND cod_canton = p_cod_canton AND cod_distrito = p_cod_distrito) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El distrito no existe.';
    END IF;
    UPDATE geo_distritos
       SET nombre_distrito = p_nombre_distrito,
           codigo_postal   = NULLIF(p_codigo_postal, '')
     WHERE cod_pais = p_cod_pais
       AND cod_provincia = p_cod_provincia
       AND cod_canton = p_cod_canton
       AND cod_distrito = p_cod_distrito;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_distritos_eliminar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10),
    IN p_cod_distrito  VARCHAR(10)
)
BEGIN
    DELETE FROM geo_distritos
     WHERE cod_pais = p_cod_pais
       AND cod_provincia = p_cod_provincia
       AND cod_canton = p_cod_canton
       AND cod_distrito = p_cod_distrito;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El distrito no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_distritos_obtener(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10),
    IN p_cod_distrito  VARCHAR(10)
)
BEGIN
    SELECT d.cod_pais, d.cod_provincia, d.cod_canton, c.nombre_canton,
           d.cod_distrito, d.nombre_distrito, d.codigo_postal
      FROM geo_distritos d
      JOIN geo_cantones c ON c.cod_pais = d.cod_pais
                         AND c.cod_provincia = d.cod_provincia
                         AND c.cod_canton = d.cod_canton
     WHERE d.cod_pais = p_cod_pais
       AND d.cod_provincia = p_cod_provincia
       AND d.cod_canton = p_cod_canton
       AND d.cod_distrito = p_cod_distrito;
END$$

CREATE OR REPLACE PROCEDURE sp_geo_distritos_listar(
    IN p_cod_pais      VARCHAR(10),
    IN p_cod_provincia VARCHAR(10),
    IN p_cod_canton    VARCHAR(10)
)
BEGIN
    SELECT d.cod_pais, d.cod_provincia, d.cod_canton, c.nombre_canton,
           d.cod_distrito, d.nombre_distrito, d.codigo_postal
      FROM geo_distritos d
      JOIN geo_cantones c ON c.cod_pais = d.cod_pais
                         AND c.cod_provincia = d.cod_provincia
                         AND c.cod_canton = d.cod_canton
     WHERE (p_cod_pais IS NULL OR d.cod_pais = p_cod_pais)
       AND (p_cod_provincia IS NULL OR d.cod_provincia = p_cod_provincia)
       AND (p_cod_canton IS NULL OR d.cod_canton = p_cod_canton)
     ORDER BY d.cod_pais, d.cod_provincia, d.cod_canton, d.cod_distrito;
END$$


-- =====================================================================
-- 2. CATÁLOGOS DEL SISTEMA
-- =====================================================================

-- -------------------- cat_tipos_identificaciones ----------------
CREATE OR REPLACE PROCEDURE sp_cat_tipos_identificaciones_insertar(
    IN  p_descripcion             VARCHAR(50),
    OUT p_cod_tipo_identificacion INT
)
BEGIN
    INSERT INTO cat_tipos_identificaciones (descripcion) VALUES (p_descripcion);
    SET p_cod_tipo_identificacion = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_identificaciones_actualizar(
    IN p_cod_tipo_identificacion INT,
    IN p_descripcion             VARCHAR(50)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_tipos_identificaciones
                    WHERE cod_tipo_identificacion = p_cod_tipo_identificacion) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de identificación no existe.';
    END IF;
    UPDATE cat_tipos_identificaciones
       SET descripcion = p_descripcion
     WHERE cod_tipo_identificacion = p_cod_tipo_identificacion;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_identificaciones_eliminar(
    IN p_cod_tipo_identificacion INT
)
BEGIN
    DELETE FROM cat_tipos_identificaciones
     WHERE cod_tipo_identificacion = p_cod_tipo_identificacion;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de identificación no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_identificaciones_obtener(
    IN p_cod_tipo_identificacion INT
)
BEGIN
    SELECT cod_tipo_identificacion, descripcion
      FROM cat_tipos_identificaciones
     WHERE cod_tipo_identificacion = p_cod_tipo_identificacion;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_identificaciones_listar()
BEGIN
    SELECT cod_tipo_identificacion, descripcion
      FROM cat_tipos_identificaciones
     ORDER BY descripcion;
END$$

-- -------------------- cat_roles_usuarios ------------------------
CREATE OR REPLACE PROCEDURE sp_cat_roles_usuarios_insertar(
    IN  p_descripcion VARCHAR(50),
    OUT p_cod_rol     INT
)
BEGIN
    INSERT INTO cat_roles_usuarios (descripcion) VALUES (p_descripcion);
    SET p_cod_rol = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_roles_usuarios_actualizar(
    IN p_cod_rol     INT,
    IN p_descripcion VARCHAR(50)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_roles_usuarios WHERE cod_rol = p_cod_rol) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol no existe.';
    END IF;
    UPDATE cat_roles_usuarios
       SET descripcion = p_descripcion
     WHERE cod_rol = p_cod_rol;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_roles_usuarios_eliminar(
    IN p_cod_rol INT
)
BEGIN
    DELETE FROM cat_roles_usuarios WHERE cod_rol = p_cod_rol;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_roles_usuarios_obtener(
    IN p_cod_rol INT
)
BEGIN
    SELECT cod_rol, descripcion
      FROM cat_roles_usuarios
     WHERE cod_rol = p_cod_rol;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_roles_usuarios_listar()
BEGIN
    SELECT cod_rol, descripcion
      FROM cat_roles_usuarios
     ORDER BY descripcion;
END$$

-- -------------------- cat_tipos_autenticaciones -----------------
CREATE OR REPLACE PROCEDURE sp_cat_tipos_autenticaciones_insertar(
    IN  p_descripcion   VARCHAR(80),
    OUT p_cod_tipo_auth INT
)
BEGIN
    INSERT INTO cat_tipos_autenticaciones (descripcion) VALUES (p_descripcion);
    SET p_cod_tipo_auth = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_autenticaciones_actualizar(
    IN p_cod_tipo_auth INT,
    IN p_descripcion   VARCHAR(80)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_tipos_autenticaciones WHERE cod_tipo_auth = p_cod_tipo_auth) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de autenticación no existe.';
    END IF;
    UPDATE cat_tipos_autenticaciones
       SET descripcion = p_descripcion
     WHERE cod_tipo_auth = p_cod_tipo_auth;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_autenticaciones_eliminar(
    IN p_cod_tipo_auth INT
)
BEGIN
    DELETE FROM cat_tipos_autenticaciones WHERE cod_tipo_auth = p_cod_tipo_auth;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de autenticación no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_autenticaciones_obtener(
    IN p_cod_tipo_auth INT
)
BEGIN
    SELECT cod_tipo_auth, descripcion
      FROM cat_tipos_autenticaciones
     WHERE cod_tipo_auth = p_cod_tipo_auth;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_autenticaciones_listar()
BEGIN
    SELECT cod_tipo_auth, descripcion
      FROM cat_tipos_autenticaciones
     ORDER BY descripcion;
END$$

-- -------------------- cat_departamentos -------------------------
CREATE OR REPLACE PROCEDURE sp_cat_departamentos_insertar(
    IN  p_descripcion      VARCHAR(120),
    OUT p_cod_departamento INT
)
BEGIN
    INSERT INTO cat_departamentos (descripcion) VALUES (p_descripcion);
    SET p_cod_departamento = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_departamentos_actualizar(
    IN p_cod_departamento INT,
    IN p_descripcion      VARCHAR(120)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_departamentos WHERE cod_departamento = p_cod_departamento) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El departamento no existe.';
    END IF;
    UPDATE cat_departamentos
       SET descripcion = p_descripcion
     WHERE cod_departamento = p_cod_departamento;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_departamentos_eliminar(
    IN p_cod_departamento INT
)
BEGIN
    DELETE FROM cat_departamentos WHERE cod_departamento = p_cod_departamento;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El departamento no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_departamentos_obtener(
    IN p_cod_departamento INT
)
BEGIN
    SELECT cod_departamento, descripcion
      FROM cat_departamentos
     WHERE cod_departamento = p_cod_departamento;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_departamentos_listar()
BEGIN
    SELECT cod_departamento, descripcion
      FROM cat_departamentos
     ORDER BY descripcion;
END$$

-- -------------------- cat_tipos_telefonos -----------------------
CREATE OR REPLACE PROCEDURE sp_cat_tipos_telefonos_insertar(
    IN  p_descripcion  VARCHAR(50),
    OUT p_cod_telefono INT
)
BEGIN
    INSERT INTO cat_tipos_telefonos (descripcion) VALUES (p_descripcion);
    SET p_cod_telefono = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_telefonos_actualizar(
    IN p_cod_telefono INT,
    IN p_descripcion  VARCHAR(50)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_tipos_telefonos WHERE cod_telefono = p_cod_telefono) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de teléfono no existe.';
    END IF;
    UPDATE cat_tipos_telefonos
       SET descripcion = p_descripcion
     WHERE cod_telefono = p_cod_telefono;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_telefonos_eliminar(
    IN p_cod_telefono INT
)
BEGIN
    DELETE FROM cat_tipos_telefonos WHERE cod_telefono = p_cod_telefono;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de teléfono no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_telefonos_obtener(
    IN p_cod_telefono INT
)
BEGIN
    SELECT cod_telefono, descripcion
      FROM cat_tipos_telefonos
     WHERE cod_telefono = p_cod_telefono;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_telefonos_listar()
BEGIN
    SELECT cod_telefono, descripcion
      FROM cat_tipos_telefonos
     ORDER BY descripcion;
END$$

-- -------------------- cat_tipos_correos -------------------------
CREATE OR REPLACE PROCEDURE sp_cat_tipos_correos_insertar(
    IN  p_descripcion VARCHAR(50),
    OUT p_cod_correo  INT
)
BEGIN
    INSERT INTO cat_tipos_correos (descripcion) VALUES (p_descripcion);
    SET p_cod_correo = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_correos_actualizar(
    IN p_cod_correo  INT,
    IN p_descripcion VARCHAR(50)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_tipos_correos WHERE cod_correo = p_cod_correo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de correo no existe.';
    END IF;
    UPDATE cat_tipos_correos
       SET descripcion = p_descripcion
     WHERE cod_correo = p_cod_correo;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_correos_eliminar(
    IN p_cod_correo INT
)
BEGIN
    DELETE FROM cat_tipos_correos WHERE cod_correo = p_cod_correo;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de correo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_correos_obtener(
    IN p_cod_correo INT
)
BEGIN
    SELECT cod_correo, descripcion
      FROM cat_tipos_correos
     WHERE cod_correo = p_cod_correo;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_tipos_correos_listar()
BEGIN
    SELECT cod_correo, descripcion
      FROM cat_tipos_correos
     ORDER BY descripcion;
END$$

-- -------------------- cat_categorias_proveedores ----------------
CREATE OR REPLACE PROCEDURE sp_cat_categorias_proveedores_insertar(
    IN  p_descripcion   VARCHAR(150),
    OUT p_cod_categoria INT
)
BEGIN
    INSERT INTO cat_categorias_proveedores (descripcion) VALUES (p_descripcion);
    SET p_cod_categoria = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_cat_categorias_proveedores_actualizar(
    IN p_cod_categoria INT,
    IN p_descripcion   VARCHAR(150)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE cod_categoria = p_cod_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe.';
    END IF;
    UPDATE cat_categorias_proveedores
       SET descripcion = p_descripcion
     WHERE cod_categoria = p_cod_categoria;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_categorias_proveedores_eliminar(
    IN p_cod_categoria INT
)
BEGIN
    DELETE FROM cat_categorias_proveedores WHERE cod_categoria = p_cod_categoria;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_categorias_proveedores_obtener(
    IN p_cod_categoria INT
)
BEGIN
    SELECT cod_categoria, descripcion
      FROM cat_categorias_proveedores
     WHERE cod_categoria = p_cod_categoria;
END$$

CREATE OR REPLACE PROCEDURE sp_cat_categorias_proveedores_listar()
BEGIN
    SELECT cod_categoria, descripcion
      FROM cat_categorias_proveedores
     ORDER BY cod_categoria;
END$$


-- =====================================================================
-- 3. USUARIOS
-- =====================================================================

-- -------------------- personas ------------------------------
CREATE OR REPLACE PROCEDURE sp_personas_insertar(
    IN  p_cod_rol                 INT,
    IN  p_cod_tipo_auth           INT,
    IN  p_cod_tipo_identificacion INT,
    IN  p_dni                     VARCHAR(30),
    IN  p_nombre                  VARCHAR(150),
    IN  p_apellido1               VARCHAR(100),
    IN  p_apellido2               VARCHAR(100),
    IN  p_cod_pais                VARCHAR(10),
    IN  p_cod_provincia           VARCHAR(10),
    IN  p_cod_canton              VARCHAR(10),
    IN  p_cod_distrito            VARCHAR(10),
    IN  p_otras_senas             TEXT,
    IN  p_imagen_path             VARCHAR(255),
    IN  p_cod_departamento        INT,
    IN  p_usuario_red             VARCHAR(50),
    IN  p_password_hash           VARCHAR(255),   -- NULL si autentica por AD
    OUT p_id                      INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    INSERT INTO personas (
        cod_rol, cod_tipo_auth, cod_tipo_identificacion, dni,
        nombre, apellido1, apellido2,
        cod_pais, cod_provincia, cod_canton, cod_distrito,
        otras_senas, imagen_path, cod_departamento,
        usuario_red, password_hash
    ) VALUES (
        p_cod_rol, p_cod_tipo_auth, p_cod_tipo_identificacion, p_dni,
        p_nombre, p_apellido1, p_apellido2,
        p_cod_pais, p_cod_provincia, p_cod_canton, p_cod_distrito,
        p_otras_senas, p_imagen_path, p_cod_departamento,
        p_usuario_red, p_password_hash
    );

    SET p_id = LAST_INSERT_ID();

    -- Primera clave en el historial (solo si autentica con la app)
    IF p_password_hash IS NOT NULL THEN
        INSERT INTO usr_historiales_claves (id_usuario, num_linea, password_hash)
        VALUES (p_id, 1, p_password_hash);
    END IF;

    COMMIT;
END$$

-- Actualiza los datos del usuario. La foto se cambia con sp_personas_actualizar_imagen
-- y la clave con sp_personas_cambiar_clave.
CREATE OR REPLACE PROCEDURE sp_personas_actualizar(
    IN p_id                      INT,
    IN p_cod_rol                 INT,
    IN p_cod_tipo_auth           INT,
    IN p_cod_tipo_identificacion INT,
    IN p_dni                     VARCHAR(30),
    IN p_nombre                  VARCHAR(150),
    IN p_apellido1               VARCHAR(100),
    IN p_apellido2               VARCHAR(100),
    IN p_cod_pais                VARCHAR(10),
    IN p_cod_provincia           VARCHAR(10),
    IN p_cod_canton              VARCHAR(10),
    IN p_cod_distrito            VARCHAR(10),
    IN p_otras_senas             TEXT,
    IN p_cod_departamento        INT,
    IN p_usuario_red             VARCHAR(50),
    IN p_activo                  BOOLEAN
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    UPDATE personas
       SET cod_rol                 = p_cod_rol,
           cod_tipo_auth           = p_cod_tipo_auth,
           cod_tipo_identificacion = p_cod_tipo_identificacion,
           dni                     = p_dni,
           nombre                  = p_nombre,
           apellido1               = p_apellido1,
           apellido2               = p_apellido2,
           cod_pais                = p_cod_pais,
           cod_provincia           = p_cod_provincia,
           cod_canton              = p_cod_canton,
           cod_distrito            = p_cod_distrito,
           otras_senas             = p_otras_senas,
           cod_departamento        = p_cod_departamento,
           usuario_red             = p_usuario_red,
           activo                  = COALESCE(p_activo, activo)
     WHERE id = p_id
       AND es_proveedor = FALSE;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_cambiar_clave(
    IN p_id                INT,
    IN p_password_hash     VARCHAR(255),
    IN p_historial_bloqueo INT
)
BEGIN
    DECLARE v_num_linea INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_password_hash IS NULL OR p_password_hash = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La clave no puede ser vacía.';
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = FALSE FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    IF COALESCE(p_historial_bloqueo, 0) > 0 AND EXISTS (
        SELECT 1
          FROM (SELECT password_hash
                  FROM usr_historiales_claves
                 WHERE id_usuario = p_id
                 ORDER BY num_linea DESC
                 LIMIT p_historial_bloqueo) h
         WHERE h.password_hash = p_password_hash
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La clave ya fue utilizada recientemente.';
    END IF;

    UPDATE personas SET password_hash = p_password_hash WHERE id = p_id;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_num_linea
      FROM usr_historiales_claves
     WHERE id_usuario = p_id;

    INSERT INTO usr_historiales_claves (id_usuario, num_linea, password_hash)
    VALUES (p_id, v_num_linea, p_password_hash);

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_eliminar(
    IN p_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;
    UPDATE personas SET activo = FALSE WHERE id = p_id AND es_proveedor = FALSE;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_activar(
    IN p_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;
    UPDATE personas SET activo = TRUE WHERE id = p_id AND es_proveedor = FALSE;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_eliminar_fisico(
    IN p_id INT
)
BEGIN
    DELETE FROM personas WHERE id = p_id AND es_proveedor = FALSE;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_obtener(
    IN p_id INT
)
BEGIN
    SELECT u.id,
           u.cod_rol, r.descripcion  AS rol,
           u.cod_tipo_auth, ta.descripcion AS tipo_autenticacion,
           u.cod_tipo_identificacion, ti.descripcion AS tipo_identificacion,
           u.dni, u.nombre, u.apellido1, u.apellido2,
           u.cod_pais, pa.nombre_pais,
           u.cod_provincia, pr.nombre_provincia,
           u.cod_canton, ca.nombre_canton,
           u.cod_distrito, di.nombre_distrito,
           u.codigo_postal,
           u.otras_senas, u.imagen_path,
           u.cod_departamento, de.descripcion AS departamento,
           u.usuario_red, u.activo, u.creado_en, u.actualizado_en
      FROM personas u
      JOIN cat_roles_usuarios         r  ON r.cod_rol = u.cod_rol
      JOIN cat_tipos_autenticaciones  ta ON ta.cod_tipo_auth = u.cod_tipo_auth
      JOIN cat_tipos_identificaciones ti ON ti.cod_tipo_identificacion = u.cod_tipo_identificacion
      JOIN geo_paises                 pa ON pa.cod_pais = u.cod_pais
      JOIN geo_provincias             pr ON pr.cod_pais = u.cod_pais
                                        AND pr.cod_provincia = u.cod_provincia
      JOIN geo_cantones               ca ON ca.cod_pais = u.cod_pais
                                        AND ca.cod_provincia = u.cod_provincia
                                        AND ca.cod_canton = u.cod_canton
      JOIN geo_distritos              di ON di.cod_pais = u.cod_pais
                                        AND di.cod_provincia = u.cod_provincia
                                        AND di.cod_canton = u.cod_canton
                                        AND di.cod_distrito = u.cod_distrito
      LEFT JOIN cat_departamentos     de ON de.cod_departamento = u.cod_departamento
     WHERE u.id = p_id
       AND u.es_proveedor = FALSE;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_obtener_por_login(
    IN p_usuario_red VARCHAR(50)
)
BEGIN
    SELECT u.id, u.usuario_red, u.password_hash,
           u.cod_rol, r.descripcion AS rol,
           u.cod_tipo_auth, ta.descripcion AS tipo_autenticacion,
           u.nombre, u.apellido1, u.apellido2, u.imagen_path, u.activo
      FROM personas u
      JOIN cat_roles_usuarios        r  ON r.cod_rol = u.cod_rol
      JOIN cat_tipos_autenticaciones ta ON ta.cod_tipo_auth = u.cod_tipo_auth
     WHERE u.usuario_red = p_usuario_red
       AND u.es_proveedor = FALSE;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_listar(
    IN p_activo           BOOLEAN,
    IN p_cod_rol          INT,
    IN p_cod_departamento INT,
    IN p_buscar           VARCHAR(150)
)
BEGIN
    SELECT u.id,
           u.cod_rol, r.descripcion AS rol,
           u.cod_tipo_auth, ta.descripcion AS tipo_autenticacion,
           u.cod_tipo_identificacion, ti.descripcion AS tipo_identificacion,
           u.dni, u.nombre, u.apellido1, u.apellido2,
           u.cod_departamento, de.descripcion AS departamento,
           u.usuario_red, u.imagen_path, u.activo, u.creado_en, u.actualizado_en
      FROM personas u
      JOIN cat_roles_usuarios         r  ON r.cod_rol = u.cod_rol
      JOIN cat_tipos_autenticaciones  ta ON ta.cod_tipo_auth = u.cod_tipo_auth
      JOIN cat_tipos_identificaciones ti ON ti.cod_tipo_identificacion = u.cod_tipo_identificacion
      LEFT JOIN cat_departamentos     de ON de.cod_departamento = u.cod_departamento
     WHERE u.es_proveedor = FALSE
       AND (p_activo IS NULL OR u.activo = p_activo)
       AND (p_cod_rol IS NULL OR u.cod_rol = p_cod_rol)
       AND (p_cod_departamento IS NULL OR u.cod_departamento = p_cod_departamento)
       AND (p_buscar IS NULL OR p_buscar = ''
            OR CONCAT_WS(' ', u.nombre, u.apellido1, u.apellido2) LIKE CONCAT('%', p_buscar, '%')
            OR u.dni LIKE CONCAT('%', p_buscar, '%')
            OR u.usuario_red LIKE CONCAT('%', p_buscar, '%'))
     ORDER BY u.nombre, u.apellido1, u.apellido2;
END$$

CREATE OR REPLACE PROCEDURE sp_personas_actualizar_imagen(
    IN p_id          INT,
    IN p_imagen_path VARCHAR(255)   -- NULL para quitar la foto
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;
    UPDATE personas SET imagen_path = p_imagen_path WHERE id = p_id AND es_proveedor = FALSE;
END$$


-- =====================================================================
-- 4. DETALLE DE USUARIOS Y PROVEEDORES (teléfonos, correos, páginas web, claves)
-- =====================================================================

-- -------------------- usr_telefonos -----------------------------
CREATE OR REPLACE PROCEDURE sp_usr_telefonos_insertar(
    IN  p_id_usuario   INT,
    IN  p_cod_telefono INT,
    IN  p_telefono     VARCHAR(25),
    IN  p_es_whatsapp  BOOLEAN,
    OUT p_num_linea    INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id_usuario FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM usr_telefonos
     WHERE id_usuario = p_id_usuario;

    INSERT INTO usr_telefonos (id_usuario, num_linea, cod_telefono, telefono, es_whatsapp)
    VALUES (p_id_usuario, p_num_linea, p_cod_telefono, p_telefono, COALESCE(p_es_whatsapp, FALSE));

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_telefonos_actualizar(
    IN p_id_usuario   INT,
    IN p_num_linea    INT,
    IN p_cod_telefono INT,
    IN p_telefono     VARCHAR(25),
    IN p_es_whatsapp  BOOLEAN
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usr_telefonos
                    WHERE id_usuario = p_id_usuario AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El teléfono no existe.';
    END IF;
    UPDATE usr_telefonos
       SET cod_telefono = p_cod_telefono,
           telefono     = p_telefono,
           es_whatsapp  = COALESCE(p_es_whatsapp, FALSE)
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_telefonos_eliminar(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    DELETE FROM usr_telefonos
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El teléfono no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_telefonos_obtener(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    SELECT t.id_usuario, t.num_linea, t.cod_telefono, c.descripcion AS tipo_telefono,
           t.telefono, t.es_whatsapp
      FROM usr_telefonos t
      JOIN cat_tipos_telefonos c ON c.cod_telefono = t.cod_telefono
     WHERE t.id_usuario = p_id_usuario
       AND t.num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_telefonos_listar(
    IN p_id_usuario INT
)
BEGIN
    SELECT t.id_usuario, t.num_linea, t.cod_telefono, c.descripcion AS tipo_telefono,
           t.telefono, t.es_whatsapp
      FROM usr_telefonos t
      JOIN cat_tipos_telefonos c ON c.cod_telefono = t.cod_telefono
     WHERE t.id_usuario = p_id_usuario
     ORDER BY t.num_linea;
END$$

-- -------------------- usr_correos -------------------------------
CREATE OR REPLACE PROCEDURE sp_usr_correos_insertar(
    IN  p_id_usuario INT,
    IN  p_cod_correo INT,
    IN  p_correo     VARCHAR(150),
    OUT p_num_linea  INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id_usuario FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM usr_correos
     WHERE id_usuario = p_id_usuario;

    INSERT INTO usr_correos (id_usuario, num_linea, cod_correo, correo)
    VALUES (p_id_usuario, p_num_linea, p_cod_correo, p_correo);

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_correos_actualizar(
    IN p_id_usuario INT,
    IN p_num_linea  INT,
    IN p_cod_correo INT,
    IN p_correo     VARCHAR(150)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usr_correos
                    WHERE id_usuario = p_id_usuario AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo no existe.';
    END IF;
    UPDATE usr_correos
       SET cod_correo = p_cod_correo,
           correo     = p_correo
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_correos_eliminar(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    DELETE FROM usr_correos
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El correo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_correos_obtener(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    SELECT e.id_usuario, e.num_linea, e.cod_correo, c.descripcion AS tipo_correo, e.correo
      FROM usr_correos e
      JOIN cat_tipos_correos c ON c.cod_correo = e.cod_correo
     WHERE e.id_usuario = p_id_usuario
       AND e.num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_correos_listar(
    IN p_id_usuario INT
)
BEGIN
    SELECT e.id_usuario, e.num_linea, e.cod_correo, c.descripcion AS tipo_correo, e.correo
      FROM usr_correos e
      JOIN cat_tipos_correos c ON c.cod_correo = e.cod_correo
     WHERE e.id_usuario = p_id_usuario
     ORDER BY e.num_linea;
END$$

-- -------------------- usr_paginas_webs --------------------------
CREATE OR REPLACE PROCEDURE sp_usr_paginas_webs_insertar(
    IN  p_id_usuario INT,
    IN  p_url_web    VARCHAR(255),
    OUT p_num_linea  INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id_usuario FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM usr_paginas_webs
     WHERE id_usuario = p_id_usuario;

    INSERT INTO usr_paginas_webs (id_usuario, num_linea, url_web)
    VALUES (p_id_usuario, p_num_linea, p_url_web);

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_paginas_webs_actualizar(
    IN p_id_usuario INT,
    IN p_num_linea  INT,
    IN p_url_web    VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usr_paginas_webs
                    WHERE id_usuario = p_id_usuario AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La página web no existe.';
    END IF;
    UPDATE usr_paginas_webs
       SET url_web = p_url_web
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_paginas_webs_eliminar(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    DELETE FROM usr_paginas_webs
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La página web no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_paginas_webs_obtener(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    SELECT id_usuario, num_linea, url_web
      FROM usr_paginas_webs
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_paginas_webs_listar(
    IN p_id_usuario INT
)
BEGIN
    SELECT id_usuario, num_linea, url_web
      FROM usr_paginas_webs
     WHERE id_usuario = p_id_usuario
     ORDER BY num_linea;
END$$

-- -------------------- usr_historiales_claves --------------------
-- Normalmente se llena solo vía sp_personas_insertar y
-- sp_personas_cambiar_clave. Se incluye el CRUD completo por si
-- se requiere mantenimiento manual.
CREATE OR REPLACE PROCEDURE sp_usr_historiales_claves_insertar(
    IN  p_id_usuario    INT,
    IN  p_password_hash VARCHAR(255),
    OUT p_num_linea     INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id_usuario FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El usuario no existe.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM usr_historiales_claves
     WHERE id_usuario = p_id_usuario;

    INSERT INTO usr_historiales_claves (id_usuario, num_linea, password_hash)
    VALUES (p_id_usuario, p_num_linea, p_password_hash);

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_historiales_claves_actualizar(
    IN p_id_usuario    INT,
    IN p_num_linea     INT,
    IN p_password_hash VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usr_historiales_claves
                    WHERE id_usuario = p_id_usuario AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El registro de historial no existe.';
    END IF;
    UPDATE usr_historiales_claves
       SET password_hash = p_password_hash
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_historiales_claves_eliminar(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    DELETE FROM usr_historiales_claves
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El registro de historial no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_usr_historiales_claves_obtener(
    IN p_id_usuario INT,
    IN p_num_linea  INT
)
BEGIN
    SELECT id_usuario, num_linea, password_hash, fecha_registro
      FROM usr_historiales_claves
     WHERE id_usuario = p_id_usuario
       AND num_linea = p_num_linea;
END$$

-- p_limite NULL = todo el historial; si no, las últimas N claves
CREATE OR REPLACE PROCEDURE sp_usr_historiales_claves_listar(
    IN p_id_usuario INT,
    IN p_limite     INT
)
BEGIN
    DECLARE v_limite BIGINT UNSIGNED DEFAULT 18446744073709551615;
    IF p_limite IS NOT NULL AND p_limite > 0 THEN
        SET v_limite = p_limite;
    END IF;

    SELECT id_usuario, num_linea, password_hash, fecha_registro
      FROM usr_historiales_claves
     WHERE id_usuario = p_id_usuario
     ORDER BY num_linea DESC
     LIMIT v_limite;
END$$


-- =====================================================================
-- 5. PROVEEDORES (personas con es_proveedor = TRUE)
-- =====================================================================

-- -------------------- prv_proveedores ---------------------------
CREATE OR REPLACE PROCEDURE sp_prv_proveedores_insertar(
    IN  p_cod_tipo_identificacion INT,
    IN  p_dni                     VARCHAR(30),
    IN  p_nombre                  VARCHAR(150),
    IN  p_apellido1               VARCHAR(100),
    IN  p_apellido2               VARCHAR(100),
    IN  p_cod_pais                VARCHAR(10),
    IN  p_cod_provincia           VARCHAR(10),
    IN  p_cod_canton              VARCHAR(10),
    IN  p_cod_distrito            VARCHAR(10),
    IN  p_otras_senas             TEXT,
    IN  p_mapa                    VARCHAR(100),
    IN  p_cod_categoria           INT,
    OUT p_id                      INT
)
BEGIN
    INSERT INTO personas (
        es_proveedor, cod_categoria,
        cod_rol, cod_tipo_auth, cod_tipo_identificacion, dni,
        nombre, apellido1, apellido2,
        cod_pais, cod_provincia, cod_canton, cod_distrito,
        otras_senas, mapa,
        cod_departamento, usuario_red, password_hash
    ) VALUES (
        TRUE, p_cod_categoria,
        NULL, NULL, p_cod_tipo_identificacion, p_dni,
        p_nombre, p_apellido1, p_apellido2,
        p_cod_pais, p_cod_provincia, p_cod_canton, p_cod_distrito,
        p_otras_senas, p_mapa,
        NULL, NULL, NULL
    );
    SET p_id = LAST_INSERT_ID();
END$$

-- La imagen y el catálogo de servicios se cambian con sus propios
-- procedimientos (los usa la subida de archivos de la API).
CREATE OR REPLACE PROCEDURE sp_prv_proveedores_actualizar(
    IN p_id                      INT,
    IN p_cod_tipo_identificacion INT,
    IN p_dni                     VARCHAR(30),
    IN p_nombre                  VARCHAR(150),
    IN p_apellido1               VARCHAR(100),
    IN p_apellido2               VARCHAR(100),
    IN p_cod_pais                VARCHAR(10),
    IN p_cod_provincia           VARCHAR(10),
    IN p_cod_canton              VARCHAR(10),
    IN p_cod_distrito            VARCHAR(10),
    IN p_otras_senas             TEXT,
    IN p_mapa                    VARCHAR(100),
    IN p_cod_categoria           INT,
    IN p_activo                  BOOLEAN
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe.';
    END IF;

    UPDATE personas
       SET cod_tipo_identificacion = p_cod_tipo_identificacion,
           dni                     = p_dni,
           nombre                  = p_nombre,
           apellido1               = p_apellido1,
           apellido2               = p_apellido2,
           cod_pais                = p_cod_pais,
           cod_provincia           = p_cod_provincia,
           cod_canton              = p_cod_canton,
           cod_distrito            = p_cod_distrito,
           otras_senas             = p_otras_senas,
           mapa                    = p_mapa,
           cod_categoria           = p_cod_categoria,
           activo                  = COALESCE(p_activo, activo)
     WHERE id = p_id
       AND es_proveedor = TRUE;
END$$

CREATE OR REPLACE PROCEDURE sp_prv_proveedores_actualizar_imagen(
    IN p_id          INT,
    IN p_imagen_path VARCHAR(255)   -- NULL para quitarla
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe.';
    END IF;
    UPDATE personas SET imagen_path = p_imagen_path WHERE id = p_id AND es_proveedor = TRUE;
END$$

CREATE OR REPLACE PROCEDURE sp_prv_proveedores_actualizar_archivo(
    IN p_id           INT,
    IN p_archivo_path VARCHAR(255)  -- NULL para quitarlo
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe.';
    END IF;
    UPDATE personas SET archivo_path = p_archivo_path WHERE id = p_id AND es_proveedor = TRUE;
END$$

-- Eliminación lógica: el proveedor queda inactivo y se conserva.
CREATE OR REPLACE PROCEDURE sp_prv_proveedores_eliminar(
    IN p_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe.';
    END IF;
    UPDATE personas SET activo = FALSE WHERE id = p_id AND es_proveedor = TRUE;
END$$

CREATE OR REPLACE PROCEDURE sp_prv_proveedores_activar(
    IN p_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM personas WHERE id = p_id AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe.';
    END IF;
    UPDATE personas SET activo = TRUE WHERE id = p_id AND es_proveedor = TRUE;
END$$

-- Eliminación física: borra el proveedor y, por ON DELETE CASCADE,
-- sus teléfonos, correos y páginas web.
CREATE OR REPLACE PROCEDURE sp_prv_proveedores_eliminar_fisico(
    IN p_id INT
)
BEGIN
    DELETE FROM personas WHERE id = p_id AND es_proveedor = TRUE;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_prv_proveedores_obtener(
    IN p_id INT
)
BEGIN
    SELECT u.id, u.es_proveedor,
           u.cod_categoria, cp.descripcion AS categoria,
           u.cod_tipo_identificacion, ti.descripcion AS tipo_identificacion,
           u.dni, u.nombre, u.apellido1, u.apellido2,
           u.cod_pais, pa.nombre_pais,
           u.cod_provincia, pr.nombre_provincia,
           u.cod_canton, ca.nombre_canton,
           u.cod_distrito, di.nombre_distrito,
           u.codigo_postal,
           u.otras_senas, u.mapa, u.imagen_path, u.archivo_path,
           u.activo, u.creado_en, u.actualizado_en
      FROM personas u
      JOIN cat_categorias_proveedores cp ON cp.cod_categoria = u.cod_categoria
      JOIN cat_tipos_identificaciones ti ON ti.cod_tipo_identificacion = u.cod_tipo_identificacion
      JOIN geo_paises                 pa ON pa.cod_pais = u.cod_pais
      JOIN geo_provincias             pr ON pr.cod_pais = u.cod_pais
                                        AND pr.cod_provincia = u.cod_provincia
      JOIN geo_cantones               ca ON ca.cod_pais = u.cod_pais
                                        AND ca.cod_provincia = u.cod_provincia
                                        AND ca.cod_canton = u.cod_canton
      JOIN geo_distritos              di ON di.cod_pais = u.cod_pais
                                        AND di.cod_provincia = u.cod_provincia
                                        AND di.cod_canton = u.cod_canton
                                        AND di.cod_distrito = u.cod_distrito
     WHERE u.id = p_id
       AND u.es_proveedor = TRUE;
END$$

-- Filtros opcionales (NULL = sin filtro):
--   p_activo        TRUE/FALSE
--   p_cod_categoria categoría
--   p_buscar        texto en nombre, apellidos o identificación
CREATE OR REPLACE PROCEDURE sp_prv_proveedores_listar(
    IN p_activo        BOOLEAN,
    IN p_cod_categoria INT,
    IN p_buscar        VARCHAR(150)
)
BEGIN
    SELECT u.id,
           u.cod_categoria, cp.descripcion AS categoria,
           u.cod_tipo_identificacion, ti.descripcion AS tipo_identificacion,
           u.dni, u.nombre, u.apellido1, u.apellido2,
           u.mapa, u.imagen_path, u.archivo_path,
           (SELECT t.telefono FROM usr_telefonos t
             WHERE t.id_usuario = u.id ORDER BY t.num_linea LIMIT 1) AS telefono_principal,
           (SELECT c.correo FROM usr_correos c
             WHERE c.id_usuario = u.id ORDER BY c.num_linea LIMIT 1) AS correo_principal,
           u.activo, u.creado_en, u.actualizado_en
      FROM personas u
      JOIN cat_categorias_proveedores cp ON cp.cod_categoria = u.cod_categoria
      JOIN cat_tipos_identificaciones ti ON ti.cod_tipo_identificacion = u.cod_tipo_identificacion
     WHERE u.es_proveedor = TRUE
       AND (p_activo IS NULL OR u.activo = p_activo)
       AND (p_cod_categoria IS NULL OR u.cod_categoria = p_cod_categoria)
       AND (p_buscar IS NULL OR p_buscar = ''
            OR CONCAT_WS(' ', u.nombre, u.apellido1, u.apellido2) LIKE CONCAT('%', p_buscar, '%')
            OR u.dni LIKE CONCAT('%', p_buscar, '%'))
     ORDER BY u.nombre, u.apellido1, u.apellido2;
END$$


-- =====================================================================
-- 6. AUDITORÍA
-- =====================================================================

-- -------------------- aud_auditorias ----------------------------
-- Registra un evento que no es un cambio de tabla (inicio y cierre de
-- sesión, intentos fallidos). Quién lo hace sale de las variables @muni_*.
CREATE OR REPLACE PROCEDURE sp_aud_auditorias_registrar(
    IN p_accion      VARCHAR(20),
    IN p_tabla       VARCHAR(64),
    IN p_llave       VARCHAR(255),
    IN p_id_persona  INT,
    IN p_descripcion VARCHAR(255),
    IN p_detalle     LONGTEXT       -- JSON opcional
)
BEGIN
    INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
    VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, p_accion, p_tabla, p_llave,
            p_id_persona, LEFT(p_descripcion, 255), p_detalle);
END$$

-- Consulta con filtros opcionales (NULL = sin filtro), de lo más nuevo a lo más viejo.
--   p_id_usuario  quién hizo el cambio
--   p_id_persona  usuario o proveedor afectado
--   p_tabla       tabla afectada
--   p_accion      INSERTAR, ACTUALIZAR, ELIMINAR, INICIO_SESION, ...
--   p_desde/hasta rango de fechas (inclusive)
--   p_buscar      texto en la descripción, el nombre de quién lo hizo o la llave
CREATE OR REPLACE PROCEDURE sp_aud_auditorias_listar(
    IN p_id_usuario     INT,
    IN p_id_persona     INT,
    IN p_tabla          VARCHAR(64),
    IN p_accion         VARCHAR(20),
    IN p_desde          DATE,
    IN p_hasta          DATE,
    IN p_buscar         VARCHAR(150),
    IN p_limite         INT,
    IN p_desplazamiento INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 50), 1), 500);
    DECLARE v_desplazamiento INT DEFAULT GREATEST(COALESCE(p_desplazamiento, 0), 0);

    SELECT a.id, a.fecha, a.accion, a.tabla, a.llave, a.descripcion, a.ip,
           a.id_usuario, a.nombre_usuario,
           act.nombre AS actor_nombre, act.apellido1 AS actor_apellido1,
           act.imagen_path AS actor_imagen_path,
           a.id_persona,
           per.nombre AS persona_nombre, per.apellido1 AS persona_apellido1,
           per.apellido2 AS persona_apellido2, per.es_proveedor AS persona_es_proveedor,
           a.datos_antes, a.datos_despues
      FROM aud_auditorias a
      LEFT JOIN personas act ON act.id = a.id_usuario
      LEFT JOIN personas per ON per.id = a.id_persona
     WHERE (p_id_usuario IS NULL OR a.id_usuario = p_id_usuario)
       AND (p_id_persona IS NULL OR a.id_persona = p_id_persona)
       AND (p_tabla IS NULL OR p_tabla = '' OR a.tabla = p_tabla)
       AND (p_accion IS NULL OR p_accion = '' OR a.accion = p_accion)
       AND (p_desde IS NULL OR a.fecha >= p_desde)
       AND (p_hasta IS NULL OR a.fecha < p_hasta + INTERVAL 1 DAY)
       AND (p_buscar IS NULL OR p_buscar = ''
            OR a.descripcion LIKE CONCAT('%', p_buscar, '%')
            OR a.nombre_usuario LIKE CONCAT('%', p_buscar, '%')
            OR a.llave = p_buscar)
     ORDER BY a.id DESC
     LIMIT v_limite OFFSET v_desplazamiento;
END$$


-- =====================================================================
-- 7. PADRÓN ELECTORAL (búsqueda de nombre por cédula)
-- =====================================================================

-- -------------------- pad_padron --------------------------------
CREATE OR REPLACE PROCEDURE sp_pad_padron_consultar(
    IN p_cedula VARCHAR(9)
)
BEGIN
    SELECT cedula, nombre, apellido1, apellido2, sexo, vencimiento
      FROM pad_padron
     WHERE cedula = p_cedula;
END$$

CREATE OR REPLACE PROCEDURE sp_pad_padron_resumen()
BEGIN
    SELECT COUNT(*) AS personas FROM pad_padron;
END$$


-- =====================================================================
-- 8. DISPARADORES: CÓDIGO POSTAL AUTOMÁTICO
-- =====================================================================

DROP TRIGGER IF EXISTS trg_geo_distritos_cp_ins$$
CREATE TRIGGER trg_geo_distritos_cp_ins
BEFORE INSERT ON geo_distritos FOR EACH ROW
BEGIN
    IF (NEW.codigo_postal IS NULL OR NEW.codigo_postal = '') AND NEW.cod_pais = 'CR'
       AND CONCAT(NEW.cod_provincia, NEW.cod_canton, NEW.cod_distrito) REGEXP '^[0-9]{5}$' THEN
        SET NEW.codigo_postal = CONCAT(NEW.cod_provincia, NEW.cod_canton, NEW.cod_distrito);
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_geo_distritos_cp_upd$$
CREATE TRIGGER trg_geo_distritos_cp_upd
AFTER UPDATE ON geo_distritos FOR EACH ROW
BEGIN
    IF NOT (NEW.codigo_postal <=> OLD.codigo_postal) THEN
        UPDATE personas
           SET codigo_postal = NEW.codigo_postal
         WHERE cod_pais = NEW.cod_pais
           AND cod_provincia = NEW.cod_provincia
           AND cod_canton = NEW.cod_canton
           AND cod_distrito = NEW.cod_distrito;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_personas_cp_ins$$
CREATE TRIGGER trg_personas_cp_ins
BEFORE INSERT ON personas FOR EACH ROW
BEGIN
    SET NEW.codigo_postal = (
        SELECT d.codigo_postal FROM geo_distritos d
         WHERE d.cod_pais = NEW.cod_pais AND d.cod_provincia = NEW.cod_provincia
           AND d.cod_canton = NEW.cod_canton AND d.cod_distrito = NEW.cod_distrito);
END$$

DROP TRIGGER IF EXISTS trg_personas_cp_upd$$
CREATE TRIGGER trg_personas_cp_upd
BEFORE UPDATE ON personas FOR EACH ROW
BEGIN
    IF NEW.codigo_postal IS NULL
       OR NOT (NEW.cod_pais <=> OLD.cod_pais AND NEW.cod_provincia <=> OLD.cod_provincia
               AND NEW.cod_canton <=> OLD.cod_canton AND NEW.cod_distrito <=> OLD.cod_distrito) THEN
        SET NEW.codigo_postal = (
            SELECT d.codigo_postal FROM geo_distritos d
             WHERE d.cod_pais = NEW.cod_pais AND d.cod_provincia = NEW.cod_provincia
               AND d.cod_canton = NEW.cod_canton AND d.cod_distrito = NEW.cod_distrito);
    END IF;
END$$


-- =====================================================================
-- 9. DISPARADORES: TODO EN MAYÚSCULA
-- =====================================================================

DROP TRIGGER IF EXISTS trg_mayus_geo_paises_ins$$
CREATE TRIGGER trg_mayus_geo_paises_ins BEFORE INSERT ON geo_paises FOR EACH ROW
BEGIN
    SET NEW.nombre_pais = UPPER(TRIM(NEW.nombre_pais));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_paises_upd$$
CREATE TRIGGER trg_mayus_geo_paises_upd BEFORE UPDATE ON geo_paises FOR EACH ROW
BEGIN
    SET NEW.nombre_pais = UPPER(TRIM(NEW.nombre_pais));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_provincias_ins$$
CREATE TRIGGER trg_mayus_geo_provincias_ins BEFORE INSERT ON geo_provincias FOR EACH ROW
BEGIN
    SET NEW.nombre_provincia = UPPER(TRIM(NEW.nombre_provincia));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_provincias_upd$$
CREATE TRIGGER trg_mayus_geo_provincias_upd BEFORE UPDATE ON geo_provincias FOR EACH ROW
BEGIN
    SET NEW.nombre_provincia = UPPER(TRIM(NEW.nombre_provincia));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_cantones_ins$$
CREATE TRIGGER trg_mayus_geo_cantones_ins BEFORE INSERT ON geo_cantones FOR EACH ROW
BEGIN
    SET NEW.nombre_canton = UPPER(TRIM(NEW.nombre_canton));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_cantones_upd$$
CREATE TRIGGER trg_mayus_geo_cantones_upd BEFORE UPDATE ON geo_cantones FOR EACH ROW
BEGIN
    SET NEW.nombre_canton = UPPER(TRIM(NEW.nombre_canton));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_distritos_ins$$
CREATE TRIGGER trg_mayus_geo_distritos_ins BEFORE INSERT ON geo_distritos FOR EACH ROW
BEGIN
    SET NEW.nombre_distrito = UPPER(TRIM(NEW.nombre_distrito));
END$$

DROP TRIGGER IF EXISTS trg_mayus_geo_distritos_upd$$
CREATE TRIGGER trg_mayus_geo_distritos_upd BEFORE UPDATE ON geo_distritos FOR EACH ROW
BEGIN
    SET NEW.nombre_distrito = UPPER(TRIM(NEW.nombre_distrito));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_identificaciones_ins$$
CREATE TRIGGER trg_mayus_cat_tipos_identificaciones_ins BEFORE INSERT ON cat_tipos_identificaciones FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_identificaciones_upd$$
CREATE TRIGGER trg_mayus_cat_tipos_identificaciones_upd BEFORE UPDATE ON cat_tipos_identificaciones FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_roles_usuarios_ins$$
CREATE TRIGGER trg_mayus_cat_roles_usuarios_ins BEFORE INSERT ON cat_roles_usuarios FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_roles_usuarios_upd$$
CREATE TRIGGER trg_mayus_cat_roles_usuarios_upd BEFORE UPDATE ON cat_roles_usuarios FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_autenticaciones_ins$$
CREATE TRIGGER trg_mayus_cat_tipos_autenticaciones_ins BEFORE INSERT ON cat_tipos_autenticaciones FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_autenticaciones_upd$$
CREATE TRIGGER trg_mayus_cat_tipos_autenticaciones_upd BEFORE UPDATE ON cat_tipos_autenticaciones FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_departamentos_ins$$
CREATE TRIGGER trg_mayus_cat_departamentos_ins BEFORE INSERT ON cat_departamentos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_departamentos_upd$$
CREATE TRIGGER trg_mayus_cat_departamentos_upd BEFORE UPDATE ON cat_departamentos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_telefonos_ins$$
CREATE TRIGGER trg_mayus_cat_tipos_telefonos_ins BEFORE INSERT ON cat_tipos_telefonos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_telefonos_upd$$
CREATE TRIGGER trg_mayus_cat_tipos_telefonos_upd BEFORE UPDATE ON cat_tipos_telefonos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_correos_ins$$
CREATE TRIGGER trg_mayus_cat_tipos_correos_ins BEFORE INSERT ON cat_tipos_correos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_tipos_correos_upd$$
CREATE TRIGGER trg_mayus_cat_tipos_correos_upd BEFORE UPDATE ON cat_tipos_correos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_categorias_proveedores_ins$$
CREATE TRIGGER trg_mayus_cat_categorias_proveedores_ins BEFORE INSERT ON cat_categorias_proveedores FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_cat_categorias_proveedores_upd$$
CREATE TRIGGER trg_mayus_cat_categorias_proveedores_upd BEFORE UPDATE ON cat_categorias_proveedores FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$

DROP TRIGGER IF EXISTS trg_mayus_personas_ins$$
CREATE TRIGGER trg_mayus_personas_ins BEFORE INSERT ON personas FOR EACH ROW
BEGIN
    SET NEW.dni = UPPER(TRIM(NEW.dni));
    SET NEW.nombre = UPPER(TRIM(NEW.nombre));
    SET NEW.apellido1 = UPPER(TRIM(NEW.apellido1));
    SET NEW.apellido2 = UPPER(TRIM(NEW.apellido2));
    SET NEW.otras_senas = UPPER(TRIM(NEW.otras_senas));
    SET NEW.usuario_red = UPPER(TRIM(NEW.usuario_red));
END$$

DROP TRIGGER IF EXISTS trg_mayus_personas_upd$$
CREATE TRIGGER trg_mayus_personas_upd BEFORE UPDATE ON personas FOR EACH ROW
BEGIN
    SET NEW.dni = UPPER(TRIM(NEW.dni));
    SET NEW.nombre = UPPER(TRIM(NEW.nombre));
    SET NEW.apellido1 = UPPER(TRIM(NEW.apellido1));
    SET NEW.apellido2 = UPPER(TRIM(NEW.apellido2));
    SET NEW.otras_senas = UPPER(TRIM(NEW.otras_senas));
    SET NEW.usuario_red = UPPER(TRIM(NEW.usuario_red));
END$$


-- =====================================================================
-- 10. DISPARADORES: FORMATO DE TELÉFONO (0000-0000) Y CORREO
-- =====================================================================

DROP TRIGGER IF EXISTS trg_formato_usr_telefonos_ins$$
CREATE TRIGGER trg_formato_usr_telefonos_ins BEFORE INSERT ON usr_telefonos FOR EACH ROW
BEGIN
    SET NEW.telefono = fn_formato_telefono(NEW.telefono);
END$$

DROP TRIGGER IF EXISTS trg_formato_usr_telefonos_upd$$
CREATE TRIGGER trg_formato_usr_telefonos_upd BEFORE UPDATE ON usr_telefonos FOR EACH ROW
BEGIN
    SET NEW.telefono = fn_formato_telefono(NEW.telefono);
END$$

DROP TRIGGER IF EXISTS trg_formato_usr_correos_ins$$
CREATE TRIGGER trg_formato_usr_correos_ins BEFORE INSERT ON usr_correos FOR EACH ROW
BEGIN
    SET NEW.correo = TRIM(NEW.correo);
END$$

DROP TRIGGER IF EXISTS trg_formato_usr_correos_upd$$
CREATE TRIGGER trg_formato_usr_correos_upd BEFORE UPDATE ON usr_correos FOR EACH ROW
BEGIN
    SET NEW.correo = TRIM(NEW.correo);
END$$


-- =====================================================================
-- 11. DISPARADORES: PROTECCIÓN DE LA AUDITORÍA
-- =====================================================================

DROP TRIGGER IF EXISTS trg_aud_auditorias_sin_cambios$$
CREATE TRIGGER trg_aud_auditorias_sin_cambios BEFORE UPDATE ON aud_auditorias FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los registros de auditoría no se pueden modificar.';
END$$

DROP TRIGGER IF EXISTS trg_aud_auditorias_sin_borrar$$
CREATE TRIGGER trg_aud_auditorias_sin_borrar BEFORE DELETE ON aud_auditorias FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Los registros de auditoría no se pueden borrar.';
END$$


-- =====================================================================
-- 12. DISPARADORES: AUDITORÍA DE CADA TABLA (insertar, actualizar, eliminar)
-- =====================================================================

DROP TRIGGER IF EXISTS trg_aud_geo_paises_ins$$
CREATE TRIGGER trg_aud_geo_paises_ins AFTER INSERT ON geo_paises FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'geo_paises',
                NEW.cod_pais, NULL, LEFT(NEW.nombre_pais, 255),
                JSON_OBJECT('cod_pais', NEW.cod_pais, 'nombre_pais', NEW.nombre_pais));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_paises_upd$$
CREATE TRIGGER trg_aud_geo_paises_upd AFTER UPDATE ON geo_paises FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_pais', OLD.cod_pais, 'nombre_pais', OLD.nombre_pais);
        SET v_despues = JSON_OBJECT('cod_pais', NEW.cod_pais, 'nombre_pais', NEW.nombre_pais);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'geo_paises',
                    NEW.cod_pais, NULL, LEFT(NEW.nombre_pais, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_paises_del$$
CREATE TRIGGER trg_aud_geo_paises_del AFTER DELETE ON geo_paises FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'geo_paises',
                OLD.cod_pais, NULL, LEFT(OLD.nombre_pais, 255),
                JSON_OBJECT('cod_pais', OLD.cod_pais, 'nombre_pais', OLD.nombre_pais));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_provincias_ins$$
CREATE TRIGGER trg_aud_geo_provincias_ins AFTER INSERT ON geo_provincias FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'geo_provincias',
                CONCAT_WS('/', NEW.cod_pais, NEW.cod_provincia), NULL, LEFT(NEW.nombre_provincia, 255),
                JSON_OBJECT('cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'nombre_provincia', NEW.nombre_provincia));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_provincias_upd$$
CREATE TRIGGER trg_aud_geo_provincias_upd AFTER UPDATE ON geo_provincias FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'nombre_provincia', OLD.nombre_provincia);
        SET v_despues = JSON_OBJECT('cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'nombre_provincia', NEW.nombre_provincia);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'geo_provincias',
                    CONCAT_WS('/', NEW.cod_pais, NEW.cod_provincia), NULL, LEFT(NEW.nombre_provincia, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_provincias_del$$
CREATE TRIGGER trg_aud_geo_provincias_del AFTER DELETE ON geo_provincias FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'geo_provincias',
                CONCAT_WS('/', OLD.cod_pais, OLD.cod_provincia), NULL, LEFT(OLD.nombre_provincia, 255),
                JSON_OBJECT('cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'nombre_provincia', OLD.nombre_provincia));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_cantones_ins$$
CREATE TRIGGER trg_aud_geo_cantones_ins AFTER INSERT ON geo_cantones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'geo_cantones',
                CONCAT_WS('/', NEW.cod_pais, NEW.cod_provincia, NEW.cod_canton), NULL, LEFT(NEW.nombre_canton, 255),
                JSON_OBJECT('cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'cod_canton', NEW.cod_canton, 'nombre_canton', NEW.nombre_canton));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_cantones_upd$$
CREATE TRIGGER trg_aud_geo_cantones_upd AFTER UPDATE ON geo_cantones FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'cod_canton', OLD.cod_canton, 'nombre_canton', OLD.nombre_canton);
        SET v_despues = JSON_OBJECT('cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'cod_canton', NEW.cod_canton, 'nombre_canton', NEW.nombre_canton);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'geo_cantones',
                    CONCAT_WS('/', NEW.cod_pais, NEW.cod_provincia, NEW.cod_canton), NULL, LEFT(NEW.nombre_canton, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_cantones_del$$
CREATE TRIGGER trg_aud_geo_cantones_del AFTER DELETE ON geo_cantones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'geo_cantones',
                CONCAT_WS('/', OLD.cod_pais, OLD.cod_provincia, OLD.cod_canton), NULL, LEFT(OLD.nombre_canton, 255),
                JSON_OBJECT('cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'cod_canton', OLD.cod_canton, 'nombre_canton', OLD.nombre_canton));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_distritos_ins$$
CREATE TRIGGER trg_aud_geo_distritos_ins AFTER INSERT ON geo_distritos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'geo_distritos',
                CONCAT_WS('/', NEW.cod_pais, NEW.cod_provincia, NEW.cod_canton, NEW.cod_distrito), NULL, LEFT(NEW.nombre_distrito, 255),
                JSON_OBJECT('cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'cod_canton', NEW.cod_canton, 'cod_distrito', NEW.cod_distrito, 'nombre_distrito', NEW.nombre_distrito, 'codigo_postal', NEW.codigo_postal));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_distritos_upd$$
CREATE TRIGGER trg_aud_geo_distritos_upd AFTER UPDATE ON geo_distritos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'cod_canton', OLD.cod_canton, 'cod_distrito', OLD.cod_distrito, 'nombre_distrito', OLD.nombre_distrito, 'codigo_postal', OLD.codigo_postal);
        SET v_despues = JSON_OBJECT('cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'cod_canton', NEW.cod_canton, 'cod_distrito', NEW.cod_distrito, 'nombre_distrito', NEW.nombre_distrito, 'codigo_postal', NEW.codigo_postal);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'geo_distritos',
                    CONCAT_WS('/', NEW.cod_pais, NEW.cod_provincia, NEW.cod_canton, NEW.cod_distrito), NULL, LEFT(NEW.nombre_distrito, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_geo_distritos_del$$
CREATE TRIGGER trg_aud_geo_distritos_del AFTER DELETE ON geo_distritos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'geo_distritos',
                CONCAT_WS('/', OLD.cod_pais, OLD.cod_provincia, OLD.cod_canton, OLD.cod_distrito), NULL, LEFT(OLD.nombre_distrito, 255),
                JSON_OBJECT('cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'cod_canton', OLD.cod_canton, 'cod_distrito', OLD.cod_distrito, 'nombre_distrito', OLD.nombre_distrito, 'codigo_postal', OLD.codigo_postal));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_identificaciones_ins$$
CREATE TRIGGER trg_aud_cat_tipos_identificaciones_ins AFTER INSERT ON cat_tipos_identificaciones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_tipos_identificaciones',
                NEW.cod_tipo_identificacion, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_tipo_identificacion', NEW.cod_tipo_identificacion, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_identificaciones_upd$$
CREATE TRIGGER trg_aud_cat_tipos_identificaciones_upd AFTER UPDATE ON cat_tipos_identificaciones FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_tipo_identificacion', OLD.cod_tipo_identificacion, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_tipo_identificacion', NEW.cod_tipo_identificacion, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_tipos_identificaciones',
                    NEW.cod_tipo_identificacion, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_identificaciones_del$$
CREATE TRIGGER trg_aud_cat_tipos_identificaciones_del AFTER DELETE ON cat_tipos_identificaciones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_tipos_identificaciones',
                OLD.cod_tipo_identificacion, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_tipo_identificacion', OLD.cod_tipo_identificacion, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_roles_usuarios_ins$$
CREATE TRIGGER trg_aud_cat_roles_usuarios_ins AFTER INSERT ON cat_roles_usuarios FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_roles_usuarios',
                NEW.cod_rol, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_rol', NEW.cod_rol, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_roles_usuarios_upd$$
CREATE TRIGGER trg_aud_cat_roles_usuarios_upd AFTER UPDATE ON cat_roles_usuarios FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_rol', OLD.cod_rol, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_rol', NEW.cod_rol, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_roles_usuarios',
                    NEW.cod_rol, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_roles_usuarios_del$$
CREATE TRIGGER trg_aud_cat_roles_usuarios_del AFTER DELETE ON cat_roles_usuarios FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_roles_usuarios',
                OLD.cod_rol, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_rol', OLD.cod_rol, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_autenticaciones_ins$$
CREATE TRIGGER trg_aud_cat_tipos_autenticaciones_ins AFTER INSERT ON cat_tipos_autenticaciones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_tipos_autenticaciones',
                NEW.cod_tipo_auth, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_tipo_auth', NEW.cod_tipo_auth, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_autenticaciones_upd$$
CREATE TRIGGER trg_aud_cat_tipos_autenticaciones_upd AFTER UPDATE ON cat_tipos_autenticaciones FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_tipo_auth', OLD.cod_tipo_auth, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_tipo_auth', NEW.cod_tipo_auth, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_tipos_autenticaciones',
                    NEW.cod_tipo_auth, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_autenticaciones_del$$
CREATE TRIGGER trg_aud_cat_tipos_autenticaciones_del AFTER DELETE ON cat_tipos_autenticaciones FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_tipos_autenticaciones',
                OLD.cod_tipo_auth, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_tipo_auth', OLD.cod_tipo_auth, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_departamentos_ins$$
CREATE TRIGGER trg_aud_cat_departamentos_ins AFTER INSERT ON cat_departamentos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_departamentos',
                NEW.cod_departamento, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_departamento', NEW.cod_departamento, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_departamentos_upd$$
CREATE TRIGGER trg_aud_cat_departamentos_upd AFTER UPDATE ON cat_departamentos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_departamento', OLD.cod_departamento, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_departamento', NEW.cod_departamento, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_departamentos',
                    NEW.cod_departamento, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_departamentos_del$$
CREATE TRIGGER trg_aud_cat_departamentos_del AFTER DELETE ON cat_departamentos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_departamentos',
                OLD.cod_departamento, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_departamento', OLD.cod_departamento, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_telefonos_ins$$
CREATE TRIGGER trg_aud_cat_tipos_telefonos_ins AFTER INSERT ON cat_tipos_telefonos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_tipos_telefonos',
                NEW.cod_telefono, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_telefono', NEW.cod_telefono, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_telefonos_upd$$
CREATE TRIGGER trg_aud_cat_tipos_telefonos_upd AFTER UPDATE ON cat_tipos_telefonos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_telefono', OLD.cod_telefono, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_telefono', NEW.cod_telefono, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_tipos_telefonos',
                    NEW.cod_telefono, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_telefonos_del$$
CREATE TRIGGER trg_aud_cat_tipos_telefonos_del AFTER DELETE ON cat_tipos_telefonos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_tipos_telefonos',
                OLD.cod_telefono, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_telefono', OLD.cod_telefono, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_correos_ins$$
CREATE TRIGGER trg_aud_cat_tipos_correos_ins AFTER INSERT ON cat_tipos_correos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_tipos_correos',
                NEW.cod_correo, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_correo', NEW.cod_correo, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_correos_upd$$
CREATE TRIGGER trg_aud_cat_tipos_correos_upd AFTER UPDATE ON cat_tipos_correos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_correo', OLD.cod_correo, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_correo', NEW.cod_correo, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_tipos_correos',
                    NEW.cod_correo, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_tipos_correos_del$$
CREATE TRIGGER trg_aud_cat_tipos_correos_del AFTER DELETE ON cat_tipos_correos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_tipos_correos',
                OLD.cod_correo, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_correo', OLD.cod_correo, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_categorias_proveedores_ins$$
CREATE TRIGGER trg_aud_cat_categorias_proveedores_ins AFTER INSERT ON cat_categorias_proveedores FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'cat_categorias_proveedores',
                NEW.cod_categoria, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('cod_categoria', NEW.cod_categoria, 'descripcion', NEW.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_categorias_proveedores_upd$$
CREATE TRIGGER trg_aud_cat_categorias_proveedores_upd AFTER UPDATE ON cat_categorias_proveedores FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('cod_categoria', OLD.cod_categoria, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('cod_categoria', NEW.cod_categoria, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'cat_categorias_proveedores',
                    NEW.cod_categoria, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_cat_categorias_proveedores_del$$
CREATE TRIGGER trg_aud_cat_categorias_proveedores_del AFTER DELETE ON cat_categorias_proveedores FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'cat_categorias_proveedores',
                OLD.cod_categoria, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('cod_categoria', OLD.cod_categoria, 'descripcion', OLD.descripcion));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_personas_ins$$
CREATE TRIGGER trg_aud_personas_ins AFTER INSERT ON personas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'personas',
                NEW.id, NEW.id, LEFT(CONCAT_WS(' ', NEW.nombre, NEW.apellido1, NEW.apellido2), 255),
                JSON_OBJECT('id', NEW.id, 'es_proveedor', NEW.es_proveedor, 'cod_categoria', NEW.cod_categoria, 'cod_rol', NEW.cod_rol, 'cod_tipo_auth', NEW.cod_tipo_auth, 'cod_tipo_identificacion', NEW.cod_tipo_identificacion, 'dni', NEW.dni, 'nombre', NEW.nombre, 'apellido1', NEW.apellido1, 'apellido2', NEW.apellido2, 'cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'cod_canton', NEW.cod_canton, 'cod_distrito', NEW.cod_distrito, 'codigo_postal', NEW.codigo_postal, 'otras_senas', NEW.otras_senas, 'mapa', NEW.mapa, 'imagen_path', NEW.imagen_path, 'archivo_path', NEW.archivo_path, 'cod_departamento', NEW.cod_departamento, 'usuario_red', NEW.usuario_red, 'activo', NEW.activo));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_personas_upd$$
CREATE TRIGGER trg_aud_personas_upd AFTER UPDATE ON personas FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'es_proveedor', OLD.es_proveedor, 'cod_categoria', OLD.cod_categoria, 'cod_rol', OLD.cod_rol, 'cod_tipo_auth', OLD.cod_tipo_auth, 'cod_tipo_identificacion', OLD.cod_tipo_identificacion, 'dni', OLD.dni, 'nombre', OLD.nombre, 'apellido1', OLD.apellido1, 'apellido2', OLD.apellido2, 'cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'cod_canton', OLD.cod_canton, 'cod_distrito', OLD.cod_distrito, 'codigo_postal', OLD.codigo_postal, 'otras_senas', OLD.otras_senas, 'mapa', OLD.mapa, 'imagen_path', OLD.imagen_path, 'archivo_path', OLD.archivo_path, 'cod_departamento', OLD.cod_departamento, 'usuario_red', OLD.usuario_red, 'activo', OLD.activo);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'es_proveedor', NEW.es_proveedor, 'cod_categoria', NEW.cod_categoria, 'cod_rol', NEW.cod_rol, 'cod_tipo_auth', NEW.cod_tipo_auth, 'cod_tipo_identificacion', NEW.cod_tipo_identificacion, 'dni', NEW.dni, 'nombre', NEW.nombre, 'apellido1', NEW.apellido1, 'apellido2', NEW.apellido2, 'cod_pais', NEW.cod_pais, 'cod_provincia', NEW.cod_provincia, 'cod_canton', NEW.cod_canton, 'cod_distrito', NEW.cod_distrito, 'codigo_postal', NEW.codigo_postal, 'otras_senas', NEW.otras_senas, 'mapa', NEW.mapa, 'imagen_path', NEW.imagen_path, 'archivo_path', NEW.archivo_path, 'cod_departamento', NEW.cod_departamento, 'usuario_red', NEW.usuario_red, 'activo', NEW.activo);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'personas',
                    NEW.id, NEW.id, LEFT(CONCAT_WS(' ', NEW.nombre, NEW.apellido1, NEW.apellido2), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_personas_del$$
CREATE TRIGGER trg_aud_personas_del AFTER DELETE ON personas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'personas',
                OLD.id, OLD.id, LEFT(CONCAT_WS(' ', OLD.nombre, OLD.apellido1, OLD.apellido2), 255),
                JSON_OBJECT('id', OLD.id, 'es_proveedor', OLD.es_proveedor, 'cod_categoria', OLD.cod_categoria, 'cod_rol', OLD.cod_rol, 'cod_tipo_auth', OLD.cod_tipo_auth, 'cod_tipo_identificacion', OLD.cod_tipo_identificacion, 'dni', OLD.dni, 'nombre', OLD.nombre, 'apellido1', OLD.apellido1, 'apellido2', OLD.apellido2, 'cod_pais', OLD.cod_pais, 'cod_provincia', OLD.cod_provincia, 'cod_canton', OLD.cod_canton, 'cod_distrito', OLD.cod_distrito, 'codigo_postal', OLD.codigo_postal, 'otras_senas', OLD.otras_senas, 'mapa', OLD.mapa, 'imagen_path', OLD.imagen_path, 'archivo_path', OLD.archivo_path, 'cod_departamento', OLD.cod_departamento, 'usuario_red', OLD.usuario_red, 'activo', OLD.activo));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_telefonos_ins$$
CREATE TRIGGER trg_aud_usr_telefonos_ins AFTER INSERT ON usr_telefonos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'usr_telefonos',
                CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(NEW.telefono, 255),
                JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'cod_telefono', NEW.cod_telefono, 'telefono', NEW.telefono, 'es_whatsapp', NEW.es_whatsapp));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_telefonos_upd$$
CREATE TRIGGER trg_aud_usr_telefonos_upd AFTER UPDATE ON usr_telefonos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'cod_telefono', OLD.cod_telefono, 'telefono', OLD.telefono, 'es_whatsapp', OLD.es_whatsapp);
        SET v_despues = JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'cod_telefono', NEW.cod_telefono, 'telefono', NEW.telefono, 'es_whatsapp', NEW.es_whatsapp);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'usr_telefonos',
                    CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(NEW.telefono, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_telefonos_del$$
CREATE TRIGGER trg_aud_usr_telefonos_del AFTER DELETE ON usr_telefonos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'usr_telefonos',
                CONCAT(OLD.id_usuario, '/', OLD.num_linea), OLD.id_usuario, LEFT(OLD.telefono, 255),
                JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'cod_telefono', OLD.cod_telefono, 'telefono', OLD.telefono, 'es_whatsapp', OLD.es_whatsapp));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_correos_ins$$
CREATE TRIGGER trg_aud_usr_correos_ins AFTER INSERT ON usr_correos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'usr_correos',
                CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(NEW.correo, 255),
                JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'cod_correo', NEW.cod_correo, 'correo', NEW.correo));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_correos_upd$$
CREATE TRIGGER trg_aud_usr_correos_upd AFTER UPDATE ON usr_correos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'cod_correo', OLD.cod_correo, 'correo', OLD.correo);
        SET v_despues = JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'cod_correo', NEW.cod_correo, 'correo', NEW.correo);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'usr_correos',
                    CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(NEW.correo, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_correos_del$$
CREATE TRIGGER trg_aud_usr_correos_del AFTER DELETE ON usr_correos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'usr_correos',
                CONCAT(OLD.id_usuario, '/', OLD.num_linea), OLD.id_usuario, LEFT(OLD.correo, 255),
                JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'cod_correo', OLD.cod_correo, 'correo', OLD.correo));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_paginas_webs_ins$$
CREATE TRIGGER trg_aud_usr_paginas_webs_ins AFTER INSERT ON usr_paginas_webs FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'usr_paginas_webs',
                CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(NEW.url_web, 255),
                JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'url_web', NEW.url_web));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_paginas_webs_upd$$
CREATE TRIGGER trg_aud_usr_paginas_webs_upd AFTER UPDATE ON usr_paginas_webs FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'url_web', OLD.url_web);
        SET v_despues = JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'url_web', NEW.url_web);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'usr_paginas_webs',
                    CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(NEW.url_web, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_paginas_webs_del$$
CREATE TRIGGER trg_aud_usr_paginas_webs_del AFTER DELETE ON usr_paginas_webs FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'usr_paginas_webs',
                CONCAT(OLD.id_usuario, '/', OLD.num_linea), OLD.id_usuario, LEFT(OLD.url_web, 255),
                JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'url_web', OLD.url_web));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_historiales_claves_ins$$
CREATE TRIGGER trg_aud_usr_historiales_claves_ins AFTER INSERT ON usr_historiales_claves FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'usr_historiales_claves',
                CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(CONCAT('Clave N.º ', NEW.num_linea), 255),
                JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'fecha_registro', NEW.fecha_registro));
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_historiales_claves_upd$$
CREATE TRIGGER trg_aud_usr_historiales_claves_upd AFTER UPDATE ON usr_historiales_claves FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'fecha_registro', OLD.fecha_registro);
        SET v_despues = JSON_OBJECT('id_usuario', NEW.id_usuario, 'num_linea', NEW.num_linea, 'fecha_registro', NEW.fecha_registro);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'usr_historiales_claves',
                    CONCAT(NEW.id_usuario, '/', NEW.num_linea), NEW.id_usuario, LEFT(CONCAT('Clave N.º ', NEW.num_linea), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_aud_usr_historiales_claves_del$$
CREATE TRIGGER trg_aud_usr_historiales_claves_del AFTER DELETE ON usr_historiales_claves FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'usr_historiales_claves',
                CONCAT(OLD.id_usuario, '/', OLD.num_linea), OLD.id_usuario, LEFT(CONCAT('Clave N.º ', OLD.num_linea), 255),
                JSON_OBJECT('id_usuario', OLD.id_usuario, 'num_linea', OLD.num_linea, 'fecha_registro', OLD.fecha_registro));
    END IF;
END$$

DELIMITER ;
