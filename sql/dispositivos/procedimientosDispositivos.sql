-- =====================================================================
--  procedimientosDispositivos.sql - módulo de equipos municipales
--  gestion_redes (MariaDB 10.3 o superior)
-- ---------------------------------------------------------------------
--  Paso 5. Contiene:
--    - 3 funciones (fn_formato_mac: MAC entera, sin separadores;
--      fn_categoria_por_nombre: categoría de un tipo por su nombre;
--      fn_rotulo_puerto: rótulo de un puerto de switch, 45T, 45F, 49)
--    - 98 procedimientos almacenados, igual que el resto del
--      sistema. Convención: sp_<tabla>_<acción>
--        _insertar   crea un registro (OUT con la llave generada)
--        _actualizar modifica por llave primaria
--        _eliminar   borra (equipos: los deja INACTIVOS)
--        _obtener    un registro por llave primaria
--        _listar     varios registros (filtros opcionales: NULL = todos)
--      Si no encuentran el registro: SIGNAL SQLSTATE '45000' con mensaje.
--      Las columnas que devuelven conservan los nombres que usa la
--      página (id_disp, tipo_disp, placa...).
--    - 114 disparadores: mayúsculas, formato y validación de
--      coordenadas, IP, MAC, líneas e IMEI, proveedor y persona
--      asignada válidos, y auditoría de las tablas.
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

DELIMITER $$

-- =====================================================================
-- 0. FUNCIONES
-- =====================================================================

-- Dirección MAC entera, sin separadores (AABBCCDDEEFF), venga como venga:
-- aabb.ccdd.eeff de Cisco, AA-BB-CC-DD-EE-FF de Windows, AA:BB:CC:DD:EE:FF...
-- La página la muestra con guiones: AA-BB-CC-DD-EE-FF.
CREATE OR REPLACE FUNCTION fn_formato_mac(p_mac VARCHAR(30))
RETURNS VARCHAR(30) DETERMINISTIC NO SQL
BEGIN
    DECLARE v_hex VARCHAR(30);
    IF p_mac IS NULL OR TRIM(p_mac) = '' THEN
        RETURN NULL;
    END IF;
    SET v_hex = UPPER(REGEXP_REPLACE(p_mac, '[^0-9A-Fa-f]', ''));
    IF CHAR_LENGTH(v_hex) = 12 AND TRIM(p_mac) REGEXP '^[0-9A-Fa-f:.-]+$' THEN
        RETURN v_hex;
    END IF;
    RETURN UPPER(TRIM(p_mac));   -- no es una MAC: la rechazan la validación y el disparador
END$$

-- Categoría que le corresponde a un tipo de equipo por su nombre:
-- COMPUTADORA, LAPTOP -> 2; IMPRESORA -> 6; CELULAR -> 4... Si el nombre
-- no dice nada, p_defecto.
CREATE OR REPLACE FUNCTION fn_categoria_por_nombre(p_descripcion VARCHAR(100), p_defecto INT)
RETURNS INT DETERMINISTIC NO SQL
BEGIN
    DECLARE v_nombre VARCHAR(100) DEFAULT UPPER(TRIM(p_descripcion));
    RETURN CASE
        WHEN v_nombre REGEXP 'CELULAR|SMARTPHONE|TABLET|IPAD|TEL[EÉ]FONO M[OÓ]VIL|M[OÓ]VIL|MOBILE' THEN 4
        WHEN v_nombre REGEXP 'TEL[EÉ]FONO|PHONE|CENTRAL TELEF|PBX|PLANTA TELEF' THEN 5
        WHEN v_nombre REGEXP 'SERVIDOR|SERVER|(^|[^A-Z])NAS([^A-Z]|$)|ALMACENAMIENTO|STORAGE|(^|[^A-Z])SAN([^A-Z]|$)' THEN 3
        WHEN v_nombre REGEXP 'COMPUTADOR|LAPTOP|PORT[AÁ]TIL|NOTEBOOK|ESCRITORIO|DESKTOP|WORKSTATION|ESTACI[OÓ]N DE TRABAJO|TODO EN UNO|ALL IN ONE|MINI PC|(^|[^A-Z])PC([^A-Z]|$)|(^|[^A-Z])CPU([^A-Z]|$)' THEN 2
        WHEN v_nombre REGEXP 'IMPRESORA|PRINTER|MULTIFUNCIONAL|PLOTTER|ESC[AÁ]NER|SCANNER|FOTOCOPIADORA' THEN 6
        WHEN v_nombre REGEXP 'MONITOR|PROYECTOR|PANTALLA|TELEVISOR|(^|[^A-Z])TV([^A-Z]|$)|VIDEO ?WALL' THEN 7
        WHEN v_nombre REGEXP '(^|[^A-Z])UPS([^A-Z]|$)|NO ?BREAK|REGULADOR|INVERSOR|PLANTA EL[EÉ]CTRICA' THEN 8
        WHEN v_nombre REGEXP 'C[AÁ]MARA|(^|[^A-Z])[ND]VR([^A-Z]|$)|GRABADOR|RELOJ|MARCADOR|BIOM[EÉ]TRICO|CONTROL DE ACCESO' THEN 9
        WHEN v_nombre REGEXP 'MODEM|M[OÓ]DEM|ROUTER|ENRUTADOR|SWITCH|FIREWALL|ACCESS POINT|PUNTO DE ACCESO|(^|[^A-Z])AP([^A-Z]|$)|ANTENA|RADIO ?ENLACE|CONTROLADOR' THEN 1
        ELSE p_defecto
    END;
END$$

-- Rótulo de un puerto como lo trae impreso el switch: cobre 1..N; los SFP
-- siguen la numeración (49, 50...) o, si son combo (sfp_combo), comparten el
-- número de los últimos de cobre: 45T es el de cobre y 45F el SFP.
CREATE OR REPLACE FUNCTION fn_rotulo_puerto(p_tipo CHAR(1), p_num INT, p_eth INT, p_sfp INT, p_combo BOOLEAN)
RETURNS VARCHAR(10) DETERMINISTIC NO SQL
BEGIN
    DECLARE v_base INT DEFAULT GREATEST(COALESCE(p_eth, 0) - COALESCE(p_sfp, 0), 0);
    IF p_tipo = 'F' THEN
        RETURN IF(p_combo, CONCAT(v_base + p_num, 'F'), CAST(COALESCE(p_eth, 0) + p_num AS CHAR));
    END IF;
    RETURN IF(p_combo AND COALESCE(p_sfp, 0) > 0 AND p_num > v_base, CONCAT(p_num, 'T'), CAST(p_num AS CHAR));
END$$

-- =====================================================================
-- 1. TABLAS CATÁLOGO DE EQUIPOS
-- =====================================================================

-- -------------------- categoria_equipos ------------------------
-- Categorías fijas (la página sabe qué datos pide cada una): solo se
-- consultan. cantidad_tipos: tipos de equipo de la categoría.
CREATE OR REPLACE PROCEDURE sp_categoria_equipos_obtener(
    IN p_id_categoria INT
)
BEGIN
    SELECT c.id_categoria, c.descripcion, c.lleva_agente,
           (SELECT COUNT(*) FROM tipo_equipos t WHERE t.id_categoria = c.id_categoria) AS cantidad_tipos
      FROM categoria_equipos c
     WHERE c.id_categoria = p_id_categoria;
END$$

CREATE OR REPLACE PROCEDURE sp_categoria_equipos_listar()
BEGIN
    SELECT c.id_categoria, c.descripcion, c.lleva_agente,
           (SELECT COUNT(*) FROM tipo_equipos t WHERE t.id_categoria = c.id_categoria) AS cantidad_tipos
      FROM categoria_equipos c
     ORDER BY c.id_categoria;
END$$

-- -------------------- tipo_equipos -----------------------------
-- Cada tipo pertenece a una categoría, que decide qué datos se piden al
-- registrar sus equipos. p_id_categoria NULL al insertar: la que dice el
-- nombre (fn_categoria_por_nombre) o 10 (otros equipos); al actualizar,
-- NULL deja la que tenía.
CREATE OR REPLACE PROCEDURE sp_tipo_equipos_insertar(
    IN  p_descripcion  VARCHAR(100),
    IN  p_id_categoria INT,
    OUT p_tipo_disp    INT
)
BEGIN
    DECLARE v_categoria INT DEFAULT COALESCE(p_id_categoria, fn_categoria_por_nombre(p_descripcion, 10));
    IF NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = v_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe.';
    END IF;
    INSERT INTO tipo_equipos (descripcion, id_categoria) VALUES (p_descripcion, v_categoria);
    SET p_tipo_disp = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_equipos_actualizar(
    IN p_tipo_disp    INT,
    IN p_descripcion  VARCHAR(100),
    IN p_id_categoria INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = p_tipo_disp) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de dispositivo no existe.';
    END IF;
    IF p_id_categoria IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La categoría no existe.';
    END IF;
    UPDATE tipo_equipos
       SET descripcion  = p_descripcion,
           id_categoria = COALESCE(p_id_categoria, id_categoria)
     WHERE tipo_equipo = p_tipo_disp;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_equipos_eliminar(
    IN p_tipo_disp INT
)
BEGIN
    DELETE FROM tipo_equipos WHERE tipo_equipo = p_tipo_disp;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de dispositivo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_equipos_obtener(
    IN p_tipo_disp INT
)
BEGIN
    SELECT t.tipo_equipo AS tipo_disp, t.descripcion, t.id_categoria, c.descripcion AS categoria, c.lleva_agente,
           (SELECT COUNT(*) FROM equipos d WHERE d.tipo_equipo = t.tipo_equipo) AS cantidad_dispositivos
      FROM tipo_equipos t
      JOIN categoria_equipos c ON c.id_categoria = t.id_categoria
     WHERE t.tipo_equipo = p_tipo_disp;
END$$

-- p_id_categoria: solo los tipos de una categoría (NULL = todos)
CREATE OR REPLACE PROCEDURE sp_tipo_equipos_listar(
    IN p_id_categoria INT
)
BEGIN
    SELECT t.tipo_equipo AS tipo_disp, t.descripcion, t.id_categoria, c.descripcion AS categoria, c.lleva_agente,
           (SELECT COUNT(*) FROM equipos d WHERE d.tipo_equipo = t.tipo_equipo) AS cantidad_dispositivos
      FROM tipo_equipos t
      JOIN categoria_equipos c ON c.id_categoria = t.id_categoria
     WHERE (p_id_categoria IS NULL OR t.id_categoria = p_id_categoria)
     ORDER BY t.descripcion;
END$$

-- -------------------- marcas -----------------------------------
-- Cada marca pertenece a un tipo de equipo. Salen con los nombres que usa
-- la página (tipo_disp = tipo_equipo).
CREATE OR REPLACE PROCEDURE sp_marcas_insertar(
    IN  p_tipo_equipo INT,
    IN  p_descripcion VARCHAR(100),
    OUT p_id_marca    INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = p_tipo_equipo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de dispositivo no existe.';
    END IF;
    INSERT INTO marcas (tipo_equipo, descripcion) VALUES (p_tipo_equipo, p_descripcion);
    SET p_id_marca = LAST_INSERT_ID();
END$$

-- El tipo de equipo solo se puede cambiar mientras la marca no tenga
-- modelos ni equipos.
CREATE OR REPLACE PROCEDURE sp_marcas_actualizar(
    IN p_id_marca    INT,
    IN p_tipo_equipo INT,
    IN p_descripcion VARCHAR(100)
)
BEGIN
    DECLARE v_tipo_actual INT;

    IF NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = p_id_marca) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La marca no existe.';
    END IF;

    SET v_tipo_actual = (SELECT tipo_equipo FROM marcas WHERE id_marca = p_id_marca);

    IF p_tipo_equipo <> v_tipo_actual
       AND (EXISTS (SELECT 1 FROM modelos WHERE id_marca = p_id_marca)
            OR EXISTS (SELECT 1 FROM equipos WHERE id_marca = p_id_marca)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede cambiar el tipo de dispositivo de una marca que ya tiene modelos o dispositivos.';
    END IF;

    UPDATE marcas
       SET tipo_equipo = p_tipo_equipo,
           descripcion = p_descripcion
     WHERE id_marca = p_id_marca;
END$$

CREATE OR REPLACE PROCEDURE sp_marcas_eliminar(
    IN p_id_marca INT
)
BEGIN
    DELETE FROM marcas WHERE id_marca = p_id_marca;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La marca no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_marcas_obtener(
    IN p_id_marca INT
)
BEGIN
    SELECT m.id_marca, m.descripcion,
           m.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo
      FROM marcas m
      JOIN tipo_equipos t ON t.tipo_equipo = m.tipo_equipo
     WHERE m.id_marca = p_id_marca;
END$$

-- p_tipo_equipo: marcas de un tipo de equipo (NULL = todas)
CREATE OR REPLACE PROCEDURE sp_marcas_listar(
    IN p_tipo_equipo INT
)
BEGIN
    SELECT m.id_marca, m.descripcion,
           m.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo
      FROM marcas m
      JOIN tipo_equipos t ON t.tipo_equipo = m.tipo_equipo
     WHERE (p_tipo_equipo IS NULL OR m.tipo_equipo = p_tipo_equipo)
     ORDER BY t.descripcion, m.descripcion;
END$$

-- -------------------- modelos ----------------------------------
-- Cada modelo es de una marca (y el tipo de equipo sale de la marca). Se
-- identifican por marca + modelo, como en la página; el código del modelo
-- es único en toda la tabla. num_linea sale igual al código: es el orden
-- en que se registraron.
CREATE OR REPLACE PROCEDURE sp_modelos_insertar(
    IN  p_id_marca    INT,
    IN  p_descripcion VARCHAR(150),
    OUT p_id_modelo   INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = p_id_marca) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La marca no existe.';
    END IF;
    INSERT INTO modelos (id_marca, descripcion) VALUES (p_id_marca, p_descripcion);
    SET p_id_modelo = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_modelos_actualizar(
    IN p_id_marca    INT,
    IN p_id_modelo   INT,
    IN p_descripcion VARCHAR(150)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM modelos
                    WHERE id_marca = p_id_marca AND id_modelo = p_id_modelo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El modelo no existe.';
    END IF;
    UPDATE modelos
       SET descripcion = p_descripcion
     WHERE id_marca = p_id_marca
       AND id_modelo = p_id_modelo;
END$$

CREATE OR REPLACE PROCEDURE sp_modelos_eliminar(
    IN p_id_marca  INT,
    IN p_id_modelo INT
)
BEGIN
    DELETE FROM modelos
     WHERE id_marca = p_id_marca
       AND id_modelo = p_id_modelo;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El modelo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_modelos_obtener(
    IN p_id_marca  INT,
    IN p_id_modelo INT
)
BEGIN
    SELECT m.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo,
           mo.id_marca, m.descripcion AS marca,
           mo.id_modelo AS num_linea, mo.id_modelo, mo.descripcion
      FROM modelos mo
      JOIN marcas m ON m.id_marca = mo.id_marca
      JOIN tipo_equipos t ON t.tipo_equipo = m.tipo_equipo
     WHERE mo.id_marca = p_id_marca
       AND mo.id_modelo = p_id_modelo;
END$$

-- Filtros opcionales (NULL = sin filtro): tipo de equipo y marca
CREATE OR REPLACE PROCEDURE sp_modelos_listar(
    IN p_tipo_equipo INT,
    IN p_id_marca    INT
)
BEGIN
    SELECT m.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo,
           mo.id_marca, m.descripcion AS marca,
           mo.id_modelo AS num_linea, mo.id_modelo, mo.descripcion
      FROM modelos mo
      JOIN marcas m ON m.id_marca = mo.id_marca
      JOIN tipo_equipos t ON t.tipo_equipo = m.tipo_equipo
     WHERE (p_tipo_equipo IS NULL OR m.tipo_equipo = p_tipo_equipo)
       AND (p_id_marca IS NULL OR mo.id_marca = p_id_marca)
     ORDER BY t.descripcion, m.descripcion, mo.id_modelo;
END$$

-- -------------------- procesadores -----------------------------
CREATE OR REPLACE PROCEDURE sp_procesadores_insertar(
    IN  p_descripcion VARCHAR(150),
    OUT p_id_proc INT
)
BEGIN
    INSERT INTO procesadores (descripcion) VALUES (p_descripcion);
    SET p_id_proc = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_procesadores_actualizar(
    IN p_id_proc INT,
    IN p_descripcion VARCHAR(150)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM procesadores WHERE id_proc = p_id_proc) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El procesador no existe.';
    END IF;
    UPDATE procesadores
       SET descripcion = p_descripcion
     WHERE id_proc = p_id_proc;
END$$

CREATE OR REPLACE PROCEDURE sp_procesadores_eliminar(
    IN p_id_proc INT
)
BEGIN
    DELETE FROM procesadores WHERE id_proc = p_id_proc;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El procesador no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_procesadores_obtener(
    IN p_id_proc INT
)
BEGIN
    SELECT id_proc, descripcion
      FROM procesadores
     WHERE id_proc = p_id_proc;
END$$

CREATE OR REPLACE PROCEDURE sp_procesadores_listar()
BEGIN
    SELECT id_proc, descripcion
      FROM procesadores
     ORDER BY descripcion;
END$$

-- -------------------- sis_operativos ---------------------------
CREATE OR REPLACE PROCEDURE sp_sis_operativos_insertar(
    IN  p_descripcion VARCHAR(100),
    OUT p_id_so INT
)
BEGIN
    INSERT INTO sis_operativos (descripcion) VALUES (p_descripcion);
    SET p_id_so = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_sis_operativos_actualizar(
    IN p_id_so INT,
    IN p_descripcion VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sis_operativos WHERE id_so = p_id_so) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El sistema operativo no existe.';
    END IF;
    UPDATE sis_operativos
       SET descripcion = p_descripcion
     WHERE id_so = p_id_so;
END$$

CREATE OR REPLACE PROCEDURE sp_sis_operativos_eliminar(
    IN p_id_so INT
)
BEGIN
    DELETE FROM sis_operativos WHERE id_so = p_id_so;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El sistema operativo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_sis_operativos_obtener(
    IN p_id_so INT
)
BEGIN
    SELECT id_so AS id_os, descripcion
      FROM sis_operativos
     WHERE id_so = p_id_so;
END$$

CREATE OR REPLACE PROCEDURE sp_sis_operativos_listar()
BEGIN
    SELECT id_so AS id_os, descripcion
      FROM sis_operativos
     ORDER BY descripcion;
END$$

-- -------------------- firmwares --------------------------------
CREATE OR REPLACE PROCEDURE sp_firmwares_insertar(
    IN  p_descripcion VARCHAR(100),
    OUT p_id_firmw INT
)
BEGIN
    INSERT INTO firmwares (descripcion) VALUES (p_descripcion);
    SET p_id_firmw = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_firmwares_actualizar(
    IN p_id_firmw INT,
    IN p_descripcion VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM firmwares WHERE id_firmw = p_id_firmw) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El firmware no existe.';
    END IF;
    IF p_id_firmw IN (1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El firmware lo usa el sistema: no se puede cambiar ni eliminar.';
    END IF;
    UPDATE firmwares
       SET descripcion = p_descripcion
     WHERE id_firmw = p_id_firmw;
END$$

CREATE OR REPLACE PROCEDURE sp_firmwares_eliminar(
    IN p_id_firmw INT
)
BEGIN
    IF p_id_firmw IN (1) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El firmware lo usa el sistema: no se puede cambiar ni eliminar.';
    END IF;
    DELETE FROM firmwares WHERE id_firmw = p_id_firmw;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El firmware no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_firmwares_obtener(
    IN p_id_firmw INT
)
BEGIN
    SELECT id_firmw, descripcion
      FROM firmwares
     WHERE id_firmw = p_id_firmw;
END$$

CREATE OR REPLACE PROCEDURE sp_firmwares_listar()
BEGIN
    SELECT id_firmw, descripcion
      FROM firmwares
     ORDER BY descripcion;
END$$

-- -------------------- edificios --------------------------------
-- p_gps: "latitud,longitud" del edificio para el mapa (se guarda en
-- ubicacion). País, provincia, cantón y distrito: opcionales; si vienen,
-- deben existir en la división territorial (CR, 2, 03, 01 = Grecia).
CREATE OR REPLACE PROCEDURE sp_edificios_insertar(
    IN  p_descripcion  VARCHAR(150),
    IN  p_otras_senas  TEXT,
    IN  p_gps          VARCHAR(100),
    IN  p_id_pais      VARCHAR(10),
    IN  p_id_provincia VARCHAR(10),
    IN  p_id_canton    VARCHAR(10),
    IN  p_id_distrito  VARCHAR(10),
    OUT p_id_predio    INT
)
BEGIN
    CALL sp_edificios_validar(p_id_pais, p_id_provincia, p_id_canton, p_id_distrito);
    INSERT INTO edificios (descripcion, otras_senas, ubicacion, id_pais, id_provincia, id_canton, id_distrito)
    VALUES (p_descripcion, NULLIF(TRIM(p_otras_senas), ''), NULLIF(TRIM(p_gps), ''),
            NULLIF(TRIM(p_id_pais), ''), NULLIF(TRIM(p_id_provincia), ''),
            NULLIF(TRIM(p_id_canton), ''), NULLIF(TRIM(p_id_distrito), ''));
    SET p_id_predio = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_edificios_actualizar(
    IN p_id_predio    INT,
    IN p_descripcion  VARCHAR(150),
    IN p_otras_senas  TEXT,
    IN p_gps          VARCHAR(100),
    IN p_id_pais      VARCHAR(10),
    IN p_id_provincia VARCHAR(10),
    IN p_id_canton    VARCHAR(10),
    IN p_id_distrito  VARCHAR(10)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM edificios WHERE id_predio = p_id_predio) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El edificio no existe.';
    END IF;
    CALL sp_edificios_validar(p_id_pais, p_id_provincia, p_id_canton, p_id_distrito);
    UPDATE edificios
       SET descripcion  = p_descripcion,
           otras_senas  = NULLIF(TRIM(p_otras_senas), ''),
           ubicacion    = NULLIF(TRIM(p_gps), ''),
           id_pais      = NULLIF(TRIM(p_id_pais), ''),
           id_provincia = NULLIF(TRIM(p_id_provincia), ''),
           id_canton    = NULLIF(TRIM(p_id_canton), ''),
           id_distrito  = NULLIF(TRIM(p_id_distrito), '')
     WHERE id_predio = p_id_predio;
END$$

-- La dirección del edificio va completa (país, provincia, cantón y
-- distrito) o vacía, y debe existir en la división territorial.
CREATE OR REPLACE PROCEDURE sp_edificios_validar(
    IN p_id_pais      VARCHAR(10),
    IN p_id_provincia VARCHAR(10),
    IN p_id_canton    VARCHAR(10),
    IN p_id_distrito  VARCHAR(10)
)
BEGIN
    DECLARE v_llenos INT DEFAULT (NULLIF(TRIM(p_id_pais), '') IS NOT NULL) + (NULLIF(TRIM(p_id_provincia), '') IS NOT NULL)
                               + (NULLIF(TRIM(p_id_canton), '') IS NOT NULL) + (NULLIF(TRIM(p_id_distrito), '') IS NOT NULL);
    IF v_llenos NOT IN (0, 4) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Indique país, provincia, cantón y distrito del edificio, o deje los cuatro vacíos.';
    END IF;
    IF v_llenos = 4 AND NOT EXISTS (SELECT 1 FROM geo_distritos
                                     WHERE cod_pais = TRIM(p_id_pais) AND cod_provincia = TRIM(p_id_provincia)
                                       AND cod_canton = TRIM(p_id_canton) AND cod_distrito = TRIM(p_id_distrito)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El distrito del edificio no está en la división territorial.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_edificios_eliminar(
    IN p_id_predio INT
)
BEGIN
    DELETE FROM edificios WHERE id_predio = p_id_predio;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El edificio no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_edificios_obtener(
    IN p_id_predio INT
)
BEGIN
    SELECT e.id_predio, e.descripcion, e.otras_senas, e.ubicacion AS gps,
           e.id_pais, e.id_provincia, e.id_canton, e.id_distrito,
           pa.nombre_pais, pv.nombre_provincia, ca.nombre_canton, di.nombre_distrito,
           (SELECT COUNT(*) FROM equipos d
             WHERE d.id_predio = e.id_predio AND d.id_estado <> 3) AS cantidad_dispositivos
      FROM edificios e
      LEFT JOIN geo_paises pa     ON pa.cod_pais = e.id_pais
      LEFT JOIN geo_provincias pv ON pv.cod_pais = e.id_pais AND pv.cod_provincia = e.id_provincia
      LEFT JOIN geo_cantones ca   ON ca.cod_pais = e.id_pais AND ca.cod_provincia = e.id_provincia
                                 AND ca.cod_canton = e.id_canton
      LEFT JOIN geo_distritos di  ON di.cod_pais = e.id_pais AND di.cod_provincia = e.id_provincia
                                 AND di.cod_canton = e.id_canton AND di.cod_distrito = e.id_distrito
     WHERE e.id_predio = p_id_predio;
END$$

CREATE OR REPLACE PROCEDURE sp_edificios_listar()
BEGIN
    SELECT e.id_predio, e.descripcion, e.otras_senas, e.ubicacion AS gps,
           e.id_pais, e.id_provincia, e.id_canton, e.id_distrito,
           pa.nombre_pais, pv.nombre_provincia, ca.nombre_canton, di.nombre_distrito,
           (SELECT COUNT(*) FROM equipos d
             WHERE d.id_predio = e.id_predio AND d.id_estado <> 3) AS cantidad_dispositivos
      FROM edificios e
      LEFT JOIN geo_paises pa     ON pa.cod_pais = e.id_pais
      LEFT JOIN geo_provincias pv ON pv.cod_pais = e.id_pais AND pv.cod_provincia = e.id_provincia
      LEFT JOIN geo_cantones ca   ON ca.cod_pais = e.id_pais AND ca.cod_provincia = e.id_provincia
                                 AND ca.cod_canton = e.id_canton
      LEFT JOIN geo_distritos di  ON di.cod_pais = e.id_pais AND di.cod_provincia = e.id_provincia
                                 AND di.cod_canton = e.id_canton AND di.cod_distrito = e.id_distrito
     ORDER BY e.descripcion;
END$$

-- -------------------- estado_equipos ---------------------------
CREATE OR REPLACE PROCEDURE sp_estado_equipos_insertar(
    IN  p_descripcion VARCHAR(50),
    OUT p_id_estado INT
)
BEGIN
    INSERT INTO estado_equipos (descripcion) VALUES (p_descripcion);
    SET p_id_estado = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_estado_equipos_actualizar(
    IN p_id_estado INT,
    IN p_descripcion VARCHAR(50)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM estado_equipos WHERE id_estado = p_id_estado) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado no existe.';
    END IF;
    IF p_id_estado IN (1, 2, 3) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado es de los que usa el sistema: no se puede cambiar ni eliminar.';
    END IF;
    UPDATE estado_equipos
       SET descripcion = p_descripcion
     WHERE id_estado = p_id_estado;
END$$

CREATE OR REPLACE PROCEDURE sp_estado_equipos_eliminar(
    IN p_id_estado INT
)
BEGIN
    IF p_id_estado IN (1, 2, 3) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado es de los que usa el sistema: no se puede cambiar ni eliminar.';
    END IF;
    DELETE FROM estado_equipos WHERE id_estado = p_id_estado;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_estado_equipos_obtener(
    IN p_id_estado INT
)
BEGIN
    SELECT id_estado, descripcion
      FROM estado_equipos
     WHERE id_estado = p_id_estado;
END$$

CREATE OR REPLACE PROCEDURE sp_estado_equipos_listar()
BEGIN
    SELECT id_estado, descripcion
      FROM estado_equipos
     ORDER BY descripcion;
END$$

-- -------------------- tipo_roles -------------------------------
CREATE OR REPLACE PROCEDURE sp_tipo_roles_insertar(
    IN  p_descripcion VARCHAR(100),
    OUT p_id_rol INT
)
BEGIN
    INSERT INTO tipo_roles (descripcion) VALUES (p_descripcion);
    SET p_id_rol = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_roles_actualizar(
    IN p_id_rol INT,
    IN p_descripcion VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = p_id_rol) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol no existe.';
    END IF;
    UPDATE tipo_roles
       SET descripcion = p_descripcion
     WHERE id_rol = p_id_rol;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_roles_eliminar(
    IN p_id_rol INT
)
BEGIN
    DELETE FROM tipo_roles WHERE id_rol = p_id_rol;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El rol no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_roles_obtener(
    IN p_id_rol INT
)
BEGIN
    SELECT id_rol, descripcion
      FROM tipo_roles
     WHERE id_rol = p_id_rol;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_roles_listar()
BEGIN
    SELECT id_rol, descripcion
      FROM tipo_roles
     ORDER BY descripcion;
END$$

-- -------------------- tipo_herramientas ------------------------
CREATE OR REPLACE PROCEDURE sp_tipo_herramientas_insertar(
    IN  p_descripcion VARCHAR(100),
    OUT p_id_herram INT
)
BEGIN
    INSERT INTO tipo_herramientas (descripcion) VALUES (p_descripcion);
    SET p_id_herram = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_herramientas_actualizar(
    IN p_id_herram INT,
    IN p_descripcion VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tipo_herramientas WHERE id_herram = p_id_herram) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La herramienta no existe.';
    END IF;
    IF p_id_herram IN (3) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La herramienta lo usa el sistema: no se puede cambiar ni eliminar.';
    END IF;
    UPDATE tipo_herramientas
       SET descripcion = p_descripcion
     WHERE id_herram = p_id_herram;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_herramientas_eliminar(
    IN p_id_herram INT
)
BEGIN
    IF p_id_herram IN (3) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La herramienta lo usa el sistema: no se puede cambiar ni eliminar.';
    END IF;
    DELETE FROM tipo_herramientas WHERE id_herram = p_id_herram;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La herramienta no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_herramientas_obtener(
    IN p_id_herram INT
)
BEGIN
    SELECT id_herram, descripcion
      FROM tipo_herramientas
     WHERE id_herram = p_id_herram;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_herramientas_listar()
BEGIN
    SELECT id_herram, descripcion
      FROM tipo_herramientas
     ORDER BY descripcion;
END$$

-- -------------------- tipo_archivos ----------------------------
CREATE OR REPLACE PROCEDURE sp_tipo_archivos_insertar(
    IN  p_descripcion VARCHAR(100),
    OUT p_tipo_arch INT
)
BEGIN
    INSERT INTO tipo_archivos (descripcion) VALUES (p_descripcion);
    SET p_tipo_arch = LAST_INSERT_ID();
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_archivos_actualizar(
    IN p_tipo_arch INT,
    IN p_descripcion VARCHAR(100)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = p_tipo_arch) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de archivo no existe.';
    END IF;
    UPDATE tipo_archivos
       SET descripcion = p_descripcion
     WHERE tipo_arch = p_tipo_arch;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_archivos_eliminar(
    IN p_tipo_arch INT
)
BEGIN
    DELETE FROM tipo_archivos WHERE tipo_arch = p_tipo_arch;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de archivo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_archivos_obtener(
    IN p_tipo_arch INT
)
BEGIN
    SELECT tipo_arch AS id_doc, descripcion
      FROM tipo_archivos
     WHERE tipo_arch = p_tipo_arch;
END$$

CREATE OR REPLACE PROCEDURE sp_tipo_archivos_listar()
BEGIN
    SELECT tipo_arch AS id_doc, descripcion
      FROM tipo_archivos
     ORDER BY descripcion;
END$$


-- =====================================================================
-- 2. EQUIPOS Y SUS TABLAS DE DETALLE: IP, MAC, LÍNEAS MÓVILES, IMEI Y ARCHIVOS
-- =====================================================================

-- -------------------- equipos ----------------------------------
-- Validaciones comunes de insertar y actualizar (uso interno). El
-- proveedor, la persona asignada y la garantía los valida el disparador
-- trg_valida_equipos, que protege también los cambios directos. Las
-- listas (IP, MAC, líneas, IMEI...) se revisan en sp_equipos_guardar_detalle.
CREATE OR REPLACE PROCEDURE sp_equipos_validar(
    IN p_id                   INT,            -- NULL al insertar
    IN p_serie                VARCHAR(100),
    IN p_tipo_equipo          INT,
    IN p_id_marca             INT,
    IN p_id_modelo            INT,
    IN p_nombre_equipo        VARCHAR(100),
    IN p_placa_equipo         VARCHAR(50),
    IN p_id_estado            INT,
    IN p_cant_ptos_serie      INT,
    IN p_cant_ptos_usb        INT,
    IN p_cant_ptos_eth        INT,
    IN p_cant_ptos_sfp        INT,
    IN p_cant_ptos_wireless   INT,
    IN p_cant_ptos_bluetooth  INT,
    IN p_cant_ptos_celular    INT,
    IN p_tipo_almacenamiento  VARCHAR(10),
    IN p_tecnologia_impresion VARCHAR(20),
    IN p_pulgadas             DECIMAL(4,1),
    IN p_cod_departamento     INT
)
BEGIN
    DECLARE v_id      INT DEFAULT COALESCE(p_id, 0);
    DECLARE v_nombre  VARCHAR(100) DEFAULT NULLIF(UPPER(TRIM(p_nombre_equipo)), '');
    DECLARE v_placa   VARCHAR(50) DEFAULT NULLIF(UPPER(TRIM(p_placa_equipo)), '');
    DECLARE v_estado  INT;
    DECLARE v_otro    VARCHAR(100);
    DECLARE v_mensaje VARCHAR(255);

    -- Estado con el que queda: el que viene o, si no viene, el que tenía
    -- (2 = ACTIVO para uno nuevo)
    SET v_estado = COALESCE(p_id_estado, (SELECT id_estado FROM equipos WHERE id = p_id), 2);

    IF p_serie IS NULL OR TRIM(p_serie) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La serie del equipo es obligatoria.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM marcas
                    WHERE id_marca = p_id_marca AND tipo_equipo = p_tipo_equipo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La marca no corresponde al tipo de dispositivo.';
    END IF;
    IF p_id_modelo IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM modelos
                        WHERE id_marca = p_id_marca AND id_modelo = p_id_modelo) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El modelo no corresponde a la marca.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM estado_equipos WHERE id_estado = v_estado) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado del equipo no existe.';
    END IF;
    IF GREATEST(COALESCE(p_cant_ptos_serie, 0), COALESCE(p_cant_ptos_usb, 0), COALESCE(p_cant_ptos_eth, 0),
                COALESCE(p_cant_ptos_sfp, 0), COALESCE(p_cant_ptos_wireless, 0), COALESCE(p_cant_ptos_bluetooth, 0),
                COALESCE(p_cant_ptos_celular, 0)) > 9999
       OR LEAST(COALESCE(p_cant_ptos_serie, 0), COALESCE(p_cant_ptos_usb, 0), COALESCE(p_cant_ptos_eth, 0),
                COALESCE(p_cant_ptos_sfp, 0), COALESCE(p_cant_ptos_wireless, 0), COALESCE(p_cant_ptos_bluetooth, 0),
                COALESCE(p_cant_ptos_celular, 0)) < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad de puertos debe estar entre 0 y 9999.';
    END IF;
    IF EXISTS (SELECT 1 FROM equipos
                WHERE tipo_equipo = p_tipo_equipo AND id_marca = p_id_marca
                  AND serie = UPPER(TRIM(p_serie))
                  AND id <> v_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya hay otro dispositivo de esa marca con la misma serie.';
    END IF;

    -- La placa (número de activo) es única en todo el inventario
    IF v_placa IS NOT NULL THEN
        SET v_otro = (SELECT serie FROM equipos WHERE placa_equipo = v_placa AND id <> v_id LIMIT 1);
        IF v_otro IS NOT NULL THEN
            SET v_mensaje = LEFT(CONCAT('La placa ', v_placa, ' ya la tiene el equipo con serie ', v_otro, '.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
    END IF;

    -- El nombre en la red identifica al equipo en el DHCP y en Microclaudia:
    -- no se repite entre los equipos activos (los que no están INACTIVOS)
    IF v_nombre IS NOT NULL AND v_estado <> 3 THEN
        SET v_otro = (SELECT serie FROM equipos
                       WHERE nombre_equipo = v_nombre AND id_estado <> 3 AND id <> v_id LIMIT 1);
        IF v_otro IS NOT NULL THEN
            SET v_mensaje = LEFT(CONCAT('El nombre de equipo ', v_nombre, ' ya lo tiene el equipo activo con serie ', v_otro, '.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
    END IF;

    IF NULLIF(TRIM(p_tipo_almacenamiento), '') IS NOT NULL
       AND UPPER(TRIM(p_tipo_almacenamiento)) NOT IN ('SSD', 'NVME', 'HDD', 'EMMC') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de almacenamiento debe ser SSD, NVME, HDD o EMMC.';
    END IF;
    IF NULLIF(TRIM(p_tecnologia_impresion), '') IS NOT NULL
       AND UPPER(TRIM(p_tecnologia_impresion)) NOT IN ('LÁSER', 'TINTA', 'TINTA CONTINUA', 'TÉRMICA', 'MATRIZ DE PUNTO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La tecnología de impresión debe ser LÁSER, TINTA, TINTA CONTINUA, TÉRMICA o MATRIZ DE PUNTO.';
    END IF;
    IF p_pulgadas IS NOT NULL AND p_pulgadas NOT BETWEEN 1 AND 150 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las pulgadas de la pantalla deben estar entre 1 y 150.';
    END IF;
    IF p_cod_departamento IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM cat_departamentos WHERE cod_departamento = p_cod_departamento) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El departamento no existe.';
    END IF;
END$$


-- Guarda juntas las listas de un equipo: IP, MAC, líneas móviles, IMEI,
-- roles y herramientas. Uso interno de sp_equipos_insertar y
-- sp_equipos_actualizar: corre dentro de su transacción (si algo falla no
-- se guarda nada). Cada lista es un arreglo JSON; NULL = no tocar esa
-- lista, '[]' = quitar todas:
--   p_ips:     '[{"num_linea": 1, "direccion_ip": "192.168.1.1", "interfaz": "LAN"},
--                {"direccion_ip": "10.0.0.1"}]'
--   p_macs:    '[{"direccion_mac": "AA-BB-CC-DD-EE-FF", "interfaz": "WAN"}]'
--   p_moviles: '[{"num_movil": "8888-8888", "operador": "KÖLBI"}]'
--   p_imeis:   '[{"dir_imei": "356938035643809"}]'
--   p_roles, p_herramientas: códigos de tipo_roles y tipo_herramientas, '[2, 3]'
--   p_tiene_microclaudia: TRUE agrega la herramienta 3 (MICROCLAUDIA),
--                         FALSE la quita, NULL no la toca
-- Las filas que traen num_linea (de este equipo) se modifican, las que no
-- lo traen se agregan al final y las que ya no vienen se borran. La MAC se
-- acepta con o sin separadores y se guarda entera (AABBCCDDEEFF).
CREATE OR REPLACE PROCEDURE sp_equipos_guardar_detalle(
    IN p_id                 INT,
    IN p_ips                LONGTEXT,
    IN p_macs               LONGTEXT,
    IN p_moviles            LONGTEXT,
    IN p_imeis              LONGTEXT,
    IN p_roles              LONGTEXT,
    IN p_herramientas       LONGTEXT,
    IN p_tiene_microclaudia BOOLEAN
)
BEGIN
    DECLARE v_i       INT;
    DECLARE v_j       INT;
    DECLARE v_n       INT;
    DECLARE v_linea   INT;
    DECLARE v_valor   VARCHAR(500);
    DECLARE v_otro    VARCHAR(500);
    DECLARE v_lineas  TEXT;          -- líneas que se conservan: ',1,3,'
    DECLARE v_cambian TEXT;          -- de esas, las que cambian de valor
    DECLARE v_mensaje VARCHAR(255);

    -- ------------------------------------------------------ direcciones IP
    IF p_ips IS NOT NULL THEN
        IF NOT JSON_VALID(p_ips) OR JSON_TYPE(p_ips) <> 'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de direcciones IP no es válida.';
        END IF;
        SET v_n = JSON_LENGTH(p_ips);
        IF v_n > 50 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Máximo 50 direcciones IP por equipo.';
        END IF;

        -- 1. Revisa todas antes de cambiar nada y anota las líneas que se
        --    conservan (v_lineas) y, de esas, las que cambian de valor (v_cambian)
        SET v_lineas = ',';
        SET v_cambian = ',';
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].direccion_ip'));
            SET v_valor = NULLIF(LOWER(TRIM(v_valor)), '');
            IF v_valor IS NULL OR NOT (IS_IPV4(v_valor) OR IS_IPV6(v_valor)) THEN
                SET v_mensaje = LEFT(CONCAT('La dirección IP ', COALESCE(v_valor, 'vacía'), ' no es válida (ejemplo: 192.168.1.1).'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_j = 0;
            WHILE v_j < v_i DO
                SET v_otro = JSON_VALUE(p_ips, CONCAT('$[', v_j, '].direccion_ip'));
                SET v_otro = NULLIF(LOWER(TRIM(v_otro)), '');
                IF v_otro = v_valor THEN
                    SET v_mensaje = LEFT(CONCAT('La dirección IP ', v_valor, ' está repetida.'), 128);
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
                END IF;
                SET v_j = v_j + 1;
            END WHILE;
            SET v_linea = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL THEN
                IF LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una línea de la lista de direcciones IP viene repetida.';
                END IF;
                SET v_otro = (SELECT dir_ip FROM dir_ips
                               WHERE id = p_id AND num_linea = v_linea);
                IF v_otro IS NOT NULL THEN
                    SET v_lineas = CONCAT(v_lineas, v_linea, ',');
                    IF v_otro <> v_valor THEN
                        SET v_cambian = CONCAT(v_cambian, v_linea, ',');
                    END IF;
                END IF;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 2. Borra las que ya no vienen y las que cambian de valor (se
        --    vuelven a agregar en su misma línea; así dos filas pueden
        --    intercambiar valores sin chocar con la llave única)
        DELETE FROM dir_ips
         WHERE id = p_id
           AND (LOCATE(CONCAT(',', num_linea, ','), v_lineas) = 0
                OR LOCATE(CONCAT(',', num_linea, ','), v_cambian) > 0);

        -- 3. Las que conservan su valor: solo el dato que lo acompaña (la
        --    auditoría anota únicamente si algo cambió)
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_linea = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0
               AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) = 0 THEN
                UPDATE dir_ips
                   SET interfaz = NULLIF(TRIM(JSON_VALUE(p_ips, CONCAT('$[', v_i, '].interfaz'))), '')
                 WHERE id = p_id
                   AND num_linea = v_linea;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 4. Las que cambiaron de valor, en su misma línea
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].direccion_ip'));
            SET v_valor = NULLIF(LOWER(TRIM(v_valor)), '');
            SET v_linea = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) > 0 THEN
                INSERT INTO dir_ips (id, num_linea, dir_ip, interfaz)
                VALUES (p_id, v_linea, v_valor,
                        NULLIF(TRIM(JSON_VALUE(p_ips, CONCAT('$[', v_i, '].interfaz'))), ''));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 5. Las nuevas, al final
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].direccion_ip'));
            SET v_valor = NULLIF(LOWER(TRIM(v_valor)), '');
            SET v_linea = JSON_VALUE(p_ips, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NULL OR LOCATE(CONCAT(',', v_linea, ','), v_lineas) = 0 THEN
                SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea
                  FROM dir_ips
                 WHERE id = p_id;
                INSERT INTO dir_ips (id, num_linea, dir_ip, interfaz)
                VALUES (p_id, v_linea, v_valor,
                        NULLIF(TRIM(JSON_VALUE(p_ips, CONCAT('$[', v_i, '].interfaz'))), ''));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
    END IF;

    -- ----------------------------------------------------- direcciones MAC
    IF p_macs IS NOT NULL THEN
        IF NOT JSON_VALID(p_macs) OR JSON_TYPE(p_macs) <> 'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de direcciones MAC no es válida.';
        END IF;
        SET v_n = JSON_LENGTH(p_macs);
        IF v_n > 50 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Máximo 50 direcciones MAC por equipo.';
        END IF;

        -- 1. Revisa todas antes de cambiar nada y anota las líneas que se
        --    conservan (v_lineas) y, de esas, las que cambian de valor (v_cambian)
        SET v_lineas = ',';
        SET v_cambian = ',';
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].direccion_mac'));
            IF CHAR_LENGTH(TRIM(v_valor)) <= 30 THEN
                SET v_valor = fn_formato_mac(TRIM(v_valor));
            END IF;
            IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9A-F]{12}$') THEN
                SET v_mensaje = LEFT(CONCAT('La dirección MAC ', COALESCE(v_valor, 'vacía'), ' no es válida (ejemplo: AA-BB-CC-DD-EE-FF).'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_j = 0;
            WHILE v_j < v_i DO
                SET v_otro = JSON_VALUE(p_macs, CONCAT('$[', v_j, '].direccion_mac'));
                IF CHAR_LENGTH(TRIM(v_otro)) <= 30 THEN
                    SET v_otro = fn_formato_mac(TRIM(v_otro));
                END IF;
                IF v_otro = v_valor THEN
                    SET v_mensaje = LEFT(CONCAT('La dirección MAC ', CONCAT_WS('-', SUBSTRING(v_valor, 1, 2), SUBSTRING(v_valor, 3, 2), SUBSTRING(v_valor, 5, 2),
                                    SUBSTRING(v_valor, 7, 2), SUBSTRING(v_valor, 9, 2), SUBSTRING(v_valor, 11, 2)), ' está repetida.'), 128);
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
                END IF;
                SET v_j = v_j + 1;
            END WHILE;
            -- Una MAC identifica a un solo equipo en todo el inventario
            SET v_otro = (SELECT d.serie
                            FROM dir_macs mc
                            JOIN equipos d ON d.id = mc.id
                           WHERE mc.dir_mac = v_valor
                             AND mc.id <> p_id
                           LIMIT 1);
            IF v_otro IS NOT NULL THEN
                SET v_mensaje = LEFT(CONCAT('La dirección MAC ', CONCAT_WS('-', SUBSTRING(v_valor, 1, 2), SUBSTRING(v_valor, 3, 2), SUBSTRING(v_valor, 5, 2),
                                    SUBSTRING(v_valor, 7, 2), SUBSTRING(v_valor, 9, 2), SUBSTRING(v_valor, 11, 2)),
                                            ' ya está registrada en el dispositivo con serie ', v_otro, '.'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_linea = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL THEN
                IF LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una línea de la lista de direcciones MAC viene repetida.';
                END IF;
                SET v_otro = (SELECT dir_mac FROM dir_macs
                               WHERE id = p_id AND num_linea = v_linea);
                IF v_otro IS NOT NULL THEN
                    SET v_lineas = CONCAT(v_lineas, v_linea, ',');
                    IF v_otro <> v_valor THEN
                        SET v_cambian = CONCAT(v_cambian, v_linea, ',');
                    END IF;
                END IF;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 2. Borra las que ya no vienen y las que cambian de valor (se
        --    vuelven a agregar en su misma línea; así dos filas pueden
        --    intercambiar valores sin chocar con la llave única)
        DELETE FROM dir_macs
         WHERE id = p_id
           AND (LOCATE(CONCAT(',', num_linea, ','), v_lineas) = 0
                OR LOCATE(CONCAT(',', num_linea, ','), v_cambian) > 0);

        -- 3. Las que conservan su valor: solo el dato que lo acompaña (la
        --    auditoría anota únicamente si algo cambió)
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_linea = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0
               AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) = 0 THEN
                UPDATE dir_macs
                   SET interfaz = NULLIF(TRIM(JSON_VALUE(p_macs, CONCAT('$[', v_i, '].interfaz'))), '')
                 WHERE id = p_id
                   AND num_linea = v_linea;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 4. Las que cambiaron de valor, en su misma línea
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].direccion_mac'));
            IF CHAR_LENGTH(TRIM(v_valor)) <= 30 THEN
                SET v_valor = fn_formato_mac(TRIM(v_valor));
            END IF;
            SET v_linea = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) > 0 THEN
                INSERT INTO dir_macs (id, num_linea, dir_mac, interfaz)
                VALUES (p_id, v_linea, v_valor,
                        NULLIF(TRIM(JSON_VALUE(p_macs, CONCAT('$[', v_i, '].interfaz'))), ''));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 5. Las nuevas, al final
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].direccion_mac'));
            IF CHAR_LENGTH(TRIM(v_valor)) <= 30 THEN
                SET v_valor = fn_formato_mac(TRIM(v_valor));
            END IF;
            SET v_linea = JSON_VALUE(p_macs, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NULL OR LOCATE(CONCAT(',', v_linea, ','), v_lineas) = 0 THEN
                SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea
                  FROM dir_macs
                 WHERE id = p_id;
                INSERT INTO dir_macs (id, num_linea, dir_mac, interfaz)
                VALUES (p_id, v_linea, v_valor,
                        NULLIF(TRIM(JSON_VALUE(p_macs, CONCAT('$[', v_i, '].interfaz'))), ''));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
    END IF;

    -- ------------------------------------------------------ líneas móviles
    IF p_moviles IS NOT NULL THEN
        IF NOT JSON_VALID(p_moviles) OR JSON_TYPE(p_moviles) <> 'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de líneas móviles no es válida.';
        END IF;
        SET v_n = JSON_LENGTH(p_moviles);
        IF v_n > 50 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Máximo 50 líneas móviles por equipo.';
        END IF;

        -- 1. Revisa todas antes de cambiar nada y anota las líneas que se
        --    conservan (v_lineas) y, de esas, las que cambian de valor (v_cambian)
        SET v_lineas = ',';
        SET v_cambian = ',';
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_movil'));
            SET v_valor = NULLIF(TRIM(v_valor), '');
            IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9+][0-9 -]{3,19}$') THEN
                SET v_mensaje = LEFT(CONCAT('La línea ', COALESCE(v_valor, 'vacía'), ' no es válida (ejemplo: 8888-8888).'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_j = 0;
            WHILE v_j < v_i DO
                SET v_otro = JSON_VALUE(p_moviles, CONCAT('$[', v_j, '].num_movil'));
                SET v_otro = NULLIF(TRIM(v_otro), '');
                IF v_otro = v_valor THEN
                    SET v_mensaje = LEFT(CONCAT('La línea ', v_valor, ' está repetida.'), 128);
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
                END IF;
                SET v_j = v_j + 1;
            END WHILE;
            SET v_linea = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL THEN
                IF LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una línea de la lista de líneas móviles viene repetida.';
                END IF;
                SET v_otro = (SELECT num_movil FROM num_moviles
                               WHERE id = p_id AND num_linea = v_linea);
                IF v_otro IS NOT NULL THEN
                    SET v_lineas = CONCAT(v_lineas, v_linea, ',');
                    IF v_otro <> v_valor THEN
                        SET v_cambian = CONCAT(v_cambian, v_linea, ',');
                    END IF;
                END IF;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 2. Borra las que ya no vienen y las que cambian de valor (se
        --    vuelven a agregar en su misma línea; así dos filas pueden
        --    intercambiar valores sin chocar con la llave única)
        DELETE FROM num_moviles
         WHERE id = p_id
           AND (LOCATE(CONCAT(',', num_linea, ','), v_lineas) = 0
                OR LOCATE(CONCAT(',', num_linea, ','), v_cambian) > 0);

        -- 3. Las que conservan su valor: solo el dato que lo acompaña (la
        --    auditoría anota únicamente si algo cambió)
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_linea = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0
               AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) = 0 THEN
                UPDATE num_moviles
                   SET operador = NULLIF(TRIM(JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].operador'))), '')
                 WHERE id = p_id
                   AND num_linea = v_linea;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 4. Las que cambiaron de valor, en su misma línea
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_movil'));
            SET v_valor = NULLIF(TRIM(v_valor), '');
            SET v_linea = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) > 0 THEN
                INSERT INTO num_moviles (id, num_linea, num_movil, operador)
                VALUES (p_id, v_linea, v_valor,
                        NULLIF(TRIM(JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].operador'))), ''));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 5. Las nuevas, al final
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_movil'));
            SET v_valor = NULLIF(TRIM(v_valor), '');
            SET v_linea = JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NULL OR LOCATE(CONCAT(',', v_linea, ','), v_lineas) = 0 THEN
                SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea
                  FROM num_moviles
                 WHERE id = p_id;
                INSERT INTO num_moviles (id, num_linea, num_movil, operador)
                VALUES (p_id, v_linea, v_valor,
                        NULLIF(TRIM(JSON_VALUE(p_moviles, CONCAT('$[', v_i, '].operador'))), ''));
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
    END IF;

    -- ---------------------------------------------------------------- IMEI
    IF p_imeis IS NOT NULL THEN
        IF NOT JSON_VALID(p_imeis) OR JSON_TYPE(p_imeis) <> 'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de IMEI no es válida.';
        END IF;
        SET v_n = JSON_LENGTH(p_imeis);
        IF v_n > 50 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Máximo 50 IMEI por equipo.';
        END IF;

        -- 1. Revisa todas antes de cambiar nada y anota las líneas que se
        --    conservan (v_lineas) y, de esas, las que cambian de valor (v_cambian)
        SET v_lineas = ',';
        SET v_cambian = ',';
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_imeis, CONCAT('$[', v_i, '].dir_imei'));
            SET v_valor = NULLIF(REGEXP_REPLACE(v_valor, '[^0-9]', ''), '');
            IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9]{15}$') THEN
                SET v_mensaje = LEFT(CONCAT('El IMEI ', COALESCE(v_valor, 'vacío'), ' no es válido (deben ser 15 dígitos).'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_j = 0;
            WHILE v_j < v_i DO
                SET v_otro = JSON_VALUE(p_imeis, CONCAT('$[', v_j, '].dir_imei'));
                SET v_otro = NULLIF(REGEXP_REPLACE(v_otro, '[^0-9]', ''), '');
                IF v_otro = v_valor THEN
                    SET v_mensaje = LEFT(CONCAT('El IMEI ', v_valor, ' está repetido.'), 128);
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
                END IF;
                SET v_j = v_j + 1;
            END WHILE;
            -- Un IMEI identifica a un solo equipo en todo el inventario
            SET v_otro = (SELECT d.serie
                            FROM dir_imeis im
                            JOIN equipos d ON d.id = im.id
                           WHERE im.dir_imei = v_valor
                             AND im.id <> p_id
                           LIMIT 1);
            IF v_otro IS NOT NULL THEN
                SET v_mensaje = LEFT(CONCAT('El IMEI ', v_valor, ' ya está registrado en el equipo con serie ', v_otro, '.'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_linea = JSON_VALUE(p_imeis, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL THEN
                IF LOCATE(CONCAT(',', v_linea, ','), v_lineas) > 0 THEN
                    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Una línea de la lista de IMEI viene repetida.';
                END IF;
                SET v_otro = (SELECT dir_imei FROM dir_imeis
                               WHERE id = p_id AND num_linea = v_linea);
                IF v_otro IS NOT NULL THEN
                    SET v_lineas = CONCAT(v_lineas, v_linea, ',');
                    IF v_otro <> v_valor THEN
                        SET v_cambian = CONCAT(v_cambian, v_linea, ',');
                    END IF;
                END IF;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 2. Borra las que ya no vienen y las que cambian de valor (se
        --    vuelven a agregar en su misma línea; así dos filas pueden
        --    intercambiar valores sin chocar con la llave única)
        DELETE FROM dir_imeis
         WHERE id = p_id
           AND (LOCATE(CONCAT(',', num_linea, ','), v_lineas) = 0
                OR LOCATE(CONCAT(',', num_linea, ','), v_cambian) > 0);

        -- 4. Las que cambiaron de valor, en su misma línea
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_imeis, CONCAT('$[', v_i, '].dir_imei'));
            SET v_valor = NULLIF(REGEXP_REPLACE(v_valor, '[^0-9]', ''), '');
            SET v_linea = JSON_VALUE(p_imeis, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NOT NULL AND LOCATE(CONCAT(',', v_linea, ','), v_cambian) > 0 THEN
                INSERT INTO dir_imeis (id, num_linea, dir_imei)
                VALUES (p_id, v_linea, v_valor);
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        -- 5. Las nuevas, al final
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_imeis, CONCAT('$[', v_i, '].dir_imei'));
            SET v_valor = NULLIF(REGEXP_REPLACE(v_valor, '[^0-9]', ''), '');
            SET v_linea = JSON_VALUE(p_imeis, CONCAT('$[', v_i, '].num_linea'));
            IF v_linea IS NULL OR LOCATE(CONCAT(',', v_linea, ','), v_lineas) = 0 THEN
                SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea
                  FROM dir_imeis
                 WHERE id = p_id;
                INSERT INTO dir_imeis (id, num_linea, dir_imei)
                VALUES (p_id, v_linea, v_valor);
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
    END IF;

    -- --------------------------------------------------------------- roles
    IF p_roles IS NOT NULL THEN
        IF NOT JSON_VALID(p_roles) OR JSON_TYPE(p_roles) <> 'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de roles no es válida.';
        END IF;
        SET v_n = JSON_LENGTH(p_roles);
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_roles, CONCAT('$[', v_i, ']'));
            IF v_valor IS NULL OR v_valor NOT REGEXP '^[0-9]+$'
               OR NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = v_valor) THEN
                SET v_mensaje = LEFT(CONCAT('El rol ', COALESCE(v_valor, 'vacío'), ' no está en la tabla tipo_roles.'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
        -- Quita las que ya no vienen y agrega las nuevas al final
        DELETE FROM roles
         WHERE id = p_id
           AND NOT JSON_CONTAINS(p_roles, CAST(id_rol AS CHAR));
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_roles, CONCAT('$[', v_i, ']'));
            IF NOT EXISTS (SELECT 1 FROM roles WHERE id = p_id AND id_rol = v_valor) THEN
                SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea FROM roles WHERE id = p_id;
                INSERT INTO roles (id, num_linea, id_rol) VALUES (p_id, v_linea, v_valor);
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
    END IF;

    -- -------------------------------------------------------- herramientas
    IF p_herramientas IS NOT NULL THEN
        IF NOT JSON_VALID(p_herramientas) OR JSON_TYPE(p_herramientas) <> 'ARRAY' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La lista de herramientas no es válida.';
        END IF;
        SET v_n = JSON_LENGTH(p_herramientas);
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_herramientas, CONCAT('$[', v_i, ']'));
            IF v_valor IS NULL OR v_valor NOT REGEXP '^[0-9]+$'
               OR NOT EXISTS (SELECT 1 FROM tipo_herramientas WHERE id_herram = v_valor) THEN
                SET v_mensaje = LEFT(CONCAT('La herramienta ', COALESCE(v_valor, 'vacío'), ' no está en la tabla tipo_herramientas.'), 128);
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
        -- Quita las que ya no vienen y agrega las nuevas al final
        DELETE FROM herramientas
         WHERE id = p_id
           AND NOT JSON_CONTAINS(p_herramientas, CAST(id_herram AS CHAR));
        SET v_i = 0;
        WHILE v_i < v_n DO
            SET v_valor = JSON_VALUE(p_herramientas, CONCAT('$[', v_i, ']'));
            IF NOT EXISTS (SELECT 1 FROM herramientas WHERE id = p_id AND id_herram = v_valor) THEN
                SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea FROM herramientas WHERE id = p_id;
                INSERT INTO herramientas (id, num_linea, id_herram) VALUES (p_id, v_linea, v_valor);
            END IF;
            SET v_i = v_i + 1;
        END WHILE;
    END IF;

    -- Check de Microclaudia (herramienta 3) de las páginas que solo cambian eso
    IF p_tiene_microclaudia THEN
        IF NOT EXISTS (SELECT 1 FROM herramientas WHERE id = p_id AND id_herram = 3) THEN
            SELECT COALESCE(MAX(num_linea), 0) + 1 INTO v_linea FROM herramientas WHERE id = p_id;
            INSERT INTO herramientas (id, num_linea, id_herram) VALUES (p_id, v_linea, 3);
        END IF;
    ELSEIF p_tiene_microclaudia IS NOT NULL THEN
        DELETE FROM herramientas WHERE id = p_id AND id_herram = 3;
    END IF;
END$$

-- Registra un equipo con sus listas (IP, MAC, líneas, IMEI, roles y
-- herramientas): se guarda todo o nada. p_id_so y p_id_firmw NULL = 1
-- (N/D); p_id_estado NULL = 2 (ACTIVO); puertos NULL = 0; textos vacíos = NULL.
CREATE OR REPLACE PROCEDURE sp_equipos_insertar(
    IN  p_serie                VARCHAR(100),
    IN  p_tipo_equipo          INT,
    IN  p_id_marca             INT,
    IN  p_id_modelo            INT,
    IN  p_nombre_equipo        VARCHAR(100),
    IN  p_placa_equipo         VARCHAR(50),
    IN  p_id_proces            INT,
    IN  p_cant_mem             INT,
    IN  p_cant_almac           INT,
    IN  p_tipo_almacenamiento  VARCHAR(10),
    IN  p_cant_ptos_serie      INT,
    IN  p_cant_ptos_usb        INT,
    IN  p_cant_ptos_eth        INT,
    IN  p_cant_ptos_sfp        INT,
    IN  p_cant_ptos_wireless   INT,
    IN  p_cant_ptos_bluetooth  INT,
    IN  p_cant_ptos_celular    INT,
    IN  p_id_so                INT,
    IN  p_id_firmw             INT,
    IN  p_extension            VARCHAR(10),
    IN  p_tecnologia_impresion VARCHAR(20),
    IN  p_a_color              BOOLEAN,
    IN  p_consumible           VARCHAR(100),
    IN  p_pulgadas             DECIMAL(4,1),
    IN  p_resolucion           VARCHAR(20),
    IN  p_capacidad_va         INT,
    IN  p_autonomia_min        INT,
    IN  p_canales              INT,
    IN  p_id_predio            INT,
    IN  p_ubicacion            VARCHAR(255),
    IN  p_id_estado            INT,
    IN  p_cod_departamento     INT,
    IN  p_id_usuario           INT,
    IN  p_id_proveedor         INT,
    IN  p_fecha_compra         DATE,
    IN  p_garantia_hasta       DATE,
    IN  p_observaciones        VARCHAR(500),
    IN  p_sfp_combo            BOOLEAN,
    -- listas JSON (NULL = no tocar esa lista; vea sp_equipos_guardar_detalle)
    IN  p_ips                  LONGTEXT,
    IN  p_macs                 LONGTEXT,
    IN  p_moviles              LONGTEXT,
    IN  p_imeis                LONGTEXT,
    IN  p_roles                LONGTEXT,
    IN  p_herramientas         LONGTEXT,
    IN  p_tiene_microclaudia   BOOLEAN,
    OUT p_id                   INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    CALL sp_equipos_validar(NULL, p_serie, p_tipo_equipo, p_id_marca, p_id_modelo, p_nombre_equipo, p_placa_equipo,
                            p_id_estado, p_cant_ptos_serie, p_cant_ptos_usb, p_cant_ptos_eth, p_cant_ptos_sfp,
                            p_cant_ptos_wireless, p_cant_ptos_bluetooth, p_cant_ptos_celular, p_tipo_almacenamiento,
                            p_tecnologia_impresion, p_pulgadas, p_cod_departamento);

    START TRANSACTION;

    INSERT INTO equipos (serie, tipo_equipo, id_marca, id_modelo, nombre_equipo,
                         placa_equipo, id_proces, cant_mem, cant_almac, tipo_almacenamiento,
                         cant_ptos_serie, cant_ptos_usb, cant_ptos_eth, cant_ptos_sfp, cant_ptos_wireless,
                         cant_ptos_bluetooth, cant_ptos_celular, id_so, id_firmw, extension,
                         tecnologia_impresion, a_color, consumible, pulgadas, resolucion,
                         capacidad_va, autonomia_min, canales, id_predio, ubicacion,
                         id_estado, cod_departamento, id_usuario, id_proveedor, fecha_compra,
                         garantia_hasta, observaciones, sfp_combo)
    VALUES (p_serie, p_tipo_equipo, p_id_marca,
            p_id_modelo, NULLIF(TRIM(p_nombre_equipo), ''), NULLIF(TRIM(p_placa_equipo), ''),
            p_id_proces, p_cant_mem, p_cant_almac,
            NULLIF(TRIM(p_tipo_almacenamiento), ''), COALESCE(p_cant_ptos_serie, 0), COALESCE(p_cant_ptos_usb, 0),
            COALESCE(p_cant_ptos_eth, 0), COALESCE(p_cant_ptos_sfp, 0), COALESCE(p_cant_ptos_wireless, 0),
            COALESCE(p_cant_ptos_bluetooth, 0), COALESCE(p_cant_ptos_celular, 0), COALESCE(p_id_so, 1),
            COALESCE(p_id_firmw, 1), NULLIF(TRIM(p_extension), ''), NULLIF(TRIM(p_tecnologia_impresion), ''),
            p_a_color, NULLIF(TRIM(p_consumible), ''), p_pulgadas,
            NULLIF(TRIM(p_resolucion), ''), p_capacidad_va, p_autonomia_min,
            p_canales, p_id_predio, NULLIF(TRIM(p_ubicacion), ''),
            COALESCE(p_id_estado, 2), p_cod_departamento, p_id_usuario,
            p_id_proveedor, p_fecha_compra, p_garantia_hasta,
            NULLIF(TRIM(p_observaciones), ''), COALESCE(p_sfp_combo, FALSE));
    SET p_id = LAST_INSERT_ID();

    CALL sp_equipos_guardar_detalle(p_id, p_ips, p_macs, p_moviles, p_imeis, p_roles, p_herramientas, p_tiene_microclaudia);

    COMMIT;
END$$

-- Modifica el equipo y deja sus listas como vienen (NULL = no tocar esa
-- lista). Se guarda todo o nada.
CREATE OR REPLACE PROCEDURE sp_equipos_actualizar(
    IN  p_id                   INT,
    IN  p_serie                VARCHAR(100),
    IN  p_tipo_equipo          INT,
    IN  p_id_marca             INT,
    IN  p_id_modelo            INT,
    IN  p_nombre_equipo        VARCHAR(100),
    IN  p_placa_equipo         VARCHAR(50),
    IN  p_id_proces            INT,
    IN  p_cant_mem             INT,
    IN  p_cant_almac           INT,
    IN  p_tipo_almacenamiento  VARCHAR(10),
    IN  p_cant_ptos_serie      INT,
    IN  p_cant_ptos_usb        INT,
    IN  p_cant_ptos_eth        INT,
    IN  p_cant_ptos_sfp        INT,
    IN  p_cant_ptos_wireless   INT,
    IN  p_cant_ptos_bluetooth  INT,
    IN  p_cant_ptos_celular    INT,
    IN  p_id_so                INT,
    IN  p_id_firmw             INT,
    IN  p_extension            VARCHAR(10),
    IN  p_tecnologia_impresion VARCHAR(20),
    IN  p_a_color              BOOLEAN,
    IN  p_consumible           VARCHAR(100),
    IN  p_pulgadas             DECIMAL(4,1),
    IN  p_resolucion           VARCHAR(20),
    IN  p_capacidad_va         INT,
    IN  p_autonomia_min        INT,
    IN  p_canales              INT,
    IN  p_id_predio            INT,
    IN  p_ubicacion            VARCHAR(255),
    IN  p_id_estado            INT,
    IN  p_cod_departamento     INT,
    IN  p_id_usuario           INT,
    IN  p_id_proveedor         INT,
    IN  p_fecha_compra         DATE,
    IN  p_garantia_hasta       DATE,
    IN  p_observaciones        VARCHAR(500),
    IN  p_sfp_combo            BOOLEAN,
    -- listas JSON (NULL = no tocar esa lista; vea sp_equipos_guardar_detalle)
    IN  p_ips                  LONGTEXT,
    IN  p_macs                 LONGTEXT,
    IN  p_moviles              LONGTEXT,
    IN  p_imeis                LONGTEXT,
    IN  p_roles                LONGTEXT,
    IN  p_herramientas         LONGTEXT,
    IN  p_tiene_microclaudia   BOOLEAN
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;

    CALL sp_equipos_validar(p_id, p_serie, p_tipo_equipo, p_id_marca, p_id_modelo, p_nombre_equipo, p_placa_equipo,
                            p_id_estado, p_cant_ptos_serie, p_cant_ptos_usb, p_cant_ptos_eth, p_cant_ptos_sfp,
                            p_cant_ptos_wireless, p_cant_ptos_bluetooth, p_cant_ptos_celular, p_tipo_almacenamiento,
                            p_tecnologia_impresion, p_pulgadas, p_cod_departamento);

    START TRANSACTION;

    UPDATE equipos
       SET serie                = p_serie,
           tipo_equipo          = p_tipo_equipo,
           id_marca             = p_id_marca,
           id_modelo            = p_id_modelo,
           nombre_equipo        = NULLIF(TRIM(p_nombre_equipo), ''),
           placa_equipo         = NULLIF(TRIM(p_placa_equipo), ''),
           id_proces            = p_id_proces,
           cant_mem             = p_cant_mem,
           cant_almac           = p_cant_almac,
           tipo_almacenamiento  = NULLIF(TRIM(p_tipo_almacenamiento), ''),
           cant_ptos_serie      = COALESCE(p_cant_ptos_serie, 0),
           cant_ptos_usb        = COALESCE(p_cant_ptos_usb, 0),
           cant_ptos_eth        = COALESCE(p_cant_ptos_eth, 0),
           cant_ptos_sfp        = COALESCE(p_cant_ptos_sfp, 0),
           cant_ptos_wireless   = COALESCE(p_cant_ptos_wireless, 0),
           cant_ptos_bluetooth  = COALESCE(p_cant_ptos_bluetooth, 0),
           cant_ptos_celular    = COALESCE(p_cant_ptos_celular, 0),
           id_so                = COALESCE(p_id_so, 1),
           id_firmw             = COALESCE(p_id_firmw, 1),
           extension            = NULLIF(TRIM(p_extension), ''),
           tecnologia_impresion = NULLIF(TRIM(p_tecnologia_impresion), ''),
           a_color              = p_a_color,
           consumible           = NULLIF(TRIM(p_consumible), ''),
           pulgadas             = p_pulgadas,
           resolucion           = NULLIF(TRIM(p_resolucion), ''),
           capacidad_va         = p_capacidad_va,
           autonomia_min        = p_autonomia_min,
           canales              = p_canales,
           id_predio            = p_id_predio,
           ubicacion            = NULLIF(TRIM(p_ubicacion), ''),
           id_estado            = COALESCE(p_id_estado, id_estado),
           cod_departamento     = p_cod_departamento,
           id_usuario           = p_id_usuario,
           id_proveedor         = p_id_proveedor,
           fecha_compra         = p_fecha_compra,
           garantia_hasta       = p_garantia_hasta,
           observaciones        = NULLIF(TRIM(p_observaciones), ''),
           sfp_combo            = COALESCE(p_sfp_combo, sfp_combo)
     WHERE id = p_id;

    CALL sp_equipos_guardar_detalle(p_id, p_ips, p_macs, p_moviles, p_imeis, p_roles, p_herramientas, p_tiene_microclaudia);

    COMMIT;
END$$

-- Eliminar = dar de baja: el equipo queda INACTIVO (3) y se conserva con
-- sus archivos y su historial
CREATE OR REPLACE PROCEDURE sp_equipos_eliminar(
    IN p_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
    UPDATE equipos SET id_estado = 3 WHERE id = p_id;
END$$

-- Activar: queda ACTIVO (2). El nombre en la red no se puede repetir entre
-- los equipos activos (igual que al registrar o modificar)
CREATE OR REPLACE PROCEDURE sp_equipos_activar(
    IN p_id INT
)
BEGIN
    DECLARE v_nombre  VARCHAR(100);
    DECLARE v_otro    VARCHAR(100);
    DECLARE v_mensaje VARCHAR(255);

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
    SET v_nombre = (SELECT nombre_equipo FROM equipos WHERE id = p_id);
    IF v_nombre IS NOT NULL THEN
        SET v_otro = (SELECT serie FROM equipos
                       WHERE nombre_equipo = v_nombre AND id_estado <> 3 AND id <> p_id LIMIT 1);
        IF v_otro IS NOT NULL THEN
            SET v_mensaje = LEFT(CONCAT('No se puede activar: el nombre de equipo ', v_nombre,
                                        ' ya lo tiene el equipo activo con serie ', v_otro, '.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
    END IF;
    UPDATE equipos SET id_estado = 2 WHERE id = p_id;
END$$

-- Eliminación física: borra el equipo y, por ON DELETE CASCADE, sus IP,
-- MAC, líneas, IMEI, roles, herramientas y archivos. Los archivos del
-- servidor los borra Django.
CREATE OR REPLACE PROCEDURE sp_equipos_eliminar_fisico(
    IN p_id INT
)
BEGIN
    DELETE FROM equipos WHERE id = p_id;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_equipos_obtener(
    IN p_id INT
)
BEGIN
    SELECT d.id AS id_disp, d.serie,
           d.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo,
           t.id_categoria, c.descripcion AS categoria, c.lleva_agente,
           d.id_marca, m.descripcion AS marca,
           d.id_modelo, mo.descripcion AS modelo,
           d.nombre_equipo, d.placa_equipo AS placa,
           d.id_proces, pr.descripcion AS procesador,
           d.cant_mem AS memoria_gb, d.cant_almac AS almacenamiento_gb, d.tipo_almacenamiento,
           d.cant_ptos_serie, d.cant_ptos_usb, d.cant_ptos_eth AS cant_ptos_ethernet, d.cant_ptos_sfp,
           d.cant_ptos_wireless, d.cant_ptos_bluetooth, d.cant_ptos_celular, d.sfp_combo,
           d.id_so AS id_os, so.descripcion AS sistema_operativo,
           d.id_firmw, fw.descripcion AS firmware,
           d.extension, d.tecnologia_impresion, d.a_color, d.consumible,
           d.pulgadas, d.resolucion, d.capacidad_va, d.autonomia_min, d.canales,
           d.id_predio, e.descripcion AS edificio, e.ubicacion AS gps_edificio,
           d.ubicacion,
           d.cod_departamento, dep.descripcion AS departamento,
           d.id_usuario AS id_asignado, IF(a.id IS NULL, NULL, CONCAT_WS(' ', a.nombre, a.apellido1, a.apellido2)) AS asignado,
           d.id_proveedor, IF(p.id IS NULL, NULL, CONCAT_WS(' ', p.nombre, p.apellido1, p.apellido2)) AS proveedor,
           d.fecha_compra, d.garantia_hasta, d.observaciones,
           d.id_estado, est.descripcion AS estado, (d.id_estado <> 3) AS activo,
           EXISTS (SELECT 1 FROM herramientas h WHERE h.id = d.id AND h.id_herram = 3) AS tiene_microclaudia,
           (SELECT GROUP_CONCAT(h.id_herram ORDER BY h.num_linea)
              FROM herramientas h WHERE h.id = d.id) AS herramientas,
           (SELECT GROUP_CONCAT(th.descripcion ORDER BY h.num_linea SEPARATOR ', ')
              FROM herramientas h JOIN tipo_herramientas th ON th.id_herram = h.id_herram
             WHERE h.id = d.id) AS herramientas_texto,
           (SELECT GROUP_CONCAT(r.id_rol ORDER BY r.num_linea)
              FROM roles r WHERE r.id = d.id) AS roles,
           (SELECT GROUP_CONCAT(tr.descripcion ORDER BY r.num_linea SEPARATOR ', ')
              FROM roles r JOIN tipo_roles tr ON tr.id_rol = r.id_rol
             WHERE r.id = d.id) AS roles_texto,
           (SELECT GROUP_CONCAT(i.dir_ip ORDER BY i.num_linea SEPARATOR ', ')
              FROM dir_ips i WHERE i.id = d.id) AS ips,
           (SELECT GROUP_CONCAT(mc.dir_mac ORDER BY mc.num_linea SEPARATOR ', ')
              FROM dir_macs mc WHERE mc.id = d.id) AS macs,
           (SELECT GROUP_CONCAT(CONCAT_WS(' ', nm.num_movil, nm.operador) ORDER BY nm.num_linea SEPARATOR ', ')
              FROM num_moviles nm WHERE nm.id = d.id) AS moviles,
           (SELECT GROUP_CONCAT(im.dir_imei ORDER BY im.num_linea SEPARATOR ', ')
              FROM dir_imeis im WHERE im.id = d.id) AS imeis,
           (SELECT COUNT(*) FROM archivos dd
             WHERE dd.id = d.id) AS cantidad_documentos,
           d.creado_en, d.actualizado_en
      FROM equipos d
      JOIN tipo_equipos           t   ON t.tipo_equipo = d.tipo_equipo
      JOIN categoria_equipos      c   ON c.id_categoria = t.id_categoria
      JOIN marcas                 m   ON m.id_marca = d.id_marca
      LEFT JOIN modelos           mo  ON mo.id_modelo = d.id_modelo
      LEFT JOIN procesadores      pr  ON pr.id_proc = d.id_proces
      JOIN sis_operativos         so  ON so.id_so = d.id_so
      JOIN firmwares              fw  ON fw.id_firmw = d.id_firmw
      JOIN estado_equipos         est ON est.id_estado = d.id_estado
      LEFT JOIN edificios         e   ON e.id_predio = d.id_predio
      LEFT JOIN cat_departamentos dep ON dep.cod_departamento = d.cod_departamento
      LEFT JOIN personas          a   ON a.id = d.id_usuario
      LEFT JOIN personas          p   ON p.id = d.id_proveedor
     WHERE d.id = p_id;
END$$

-- Filtros opcionales (NULL = sin filtro):
--   p_activo           TRUE = los que no están INACTIVOS, FALSE = los INACTIVOS
--   p_id_categoria     categoría (equipos de red, computadoras, móviles...)
--   p_tipo_equipo      tipo de equipo
--   p_id_marca         marca
--   p_id_predio        edificio
--   p_cod_departamento departamento que lo usa
--   p_id_usuario       funcionario que lo usa
--   p_id_proveedor     proveedor
--   p_buscar           texto en serie, modelo, nombre en la red, placa,
--                      ubicación, extensión, responsable, IMEI, línea, IP
--                      o MAC (la MAC se busca con o sin separadores)
CREATE OR REPLACE PROCEDURE sp_equipos_listar(
    IN p_activo           BOOLEAN,
    IN p_id_categoria     INT,
    IN p_tipo_equipo      INT,
    IN p_id_marca         INT,
    IN p_id_predio        INT,
    IN p_cod_departamento INT,
    IN p_id_usuario       INT,
    IN p_id_proveedor     INT,
    IN p_buscar           VARCHAR(150)
)
BEGIN
    -- Si lo buscado parece un pedazo de MAC, se compara sin separadores
    DECLARE v_mac VARCHAR(150) DEFAULT IF(p_buscar REGEXP '^[0-9A-Fa-f:.-]{2,}$',
                                          UPPER(REGEXP_REPLACE(p_buscar, '[^0-9A-Fa-f]', '')), '');

    SELECT d.id AS id_disp, d.serie,
           d.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo,
           t.id_categoria, c.descripcion AS categoria, c.lleva_agente,
           d.id_marca, m.descripcion AS marca,
           d.id_modelo, mo.descripcion AS modelo,
           d.nombre_equipo, d.placa_equipo AS placa,
           d.id_proces, pr.descripcion AS procesador,
           d.cant_mem AS memoria_gb, d.cant_almac AS almacenamiento_gb, d.tipo_almacenamiento,
           d.cant_ptos_serie, d.cant_ptos_usb, d.cant_ptos_eth AS cant_ptos_ethernet, d.cant_ptos_sfp,
           d.cant_ptos_wireless, d.cant_ptos_bluetooth, d.cant_ptos_celular, d.sfp_combo,
           d.id_so AS id_os, so.descripcion AS sistema_operativo,
           d.id_firmw, fw.descripcion AS firmware,
           d.extension, d.tecnologia_impresion, d.a_color, d.consumible,
           d.pulgadas, d.resolucion, d.capacidad_va, d.autonomia_min, d.canales,
           d.id_predio, e.descripcion AS edificio, e.ubicacion AS gps_edificio,
           d.ubicacion,
           d.cod_departamento, dep.descripcion AS departamento,
           d.id_usuario AS id_asignado, IF(a.id IS NULL, NULL, CONCAT_WS(' ', a.nombre, a.apellido1, a.apellido2)) AS asignado,
           d.id_proveedor, IF(p.id IS NULL, NULL, CONCAT_WS(' ', p.nombre, p.apellido1, p.apellido2)) AS proveedor,
           d.fecha_compra, d.garantia_hasta, d.observaciones,
           d.id_estado, est.descripcion AS estado, (d.id_estado <> 3) AS activo,
           EXISTS (SELECT 1 FROM herramientas h WHERE h.id = d.id AND h.id_herram = 3) AS tiene_microclaudia,
           (SELECT GROUP_CONCAT(h.id_herram ORDER BY h.num_linea)
              FROM herramientas h WHERE h.id = d.id) AS herramientas,
           (SELECT GROUP_CONCAT(th.descripcion ORDER BY h.num_linea SEPARATOR ', ')
              FROM herramientas h JOIN tipo_herramientas th ON th.id_herram = h.id_herram
             WHERE h.id = d.id) AS herramientas_texto,
           (SELECT GROUP_CONCAT(r.id_rol ORDER BY r.num_linea)
              FROM roles r WHERE r.id = d.id) AS roles,
           (SELECT GROUP_CONCAT(tr.descripcion ORDER BY r.num_linea SEPARATOR ', ')
              FROM roles r JOIN tipo_roles tr ON tr.id_rol = r.id_rol
             WHERE r.id = d.id) AS roles_texto,
           (SELECT GROUP_CONCAT(i.dir_ip ORDER BY i.num_linea SEPARATOR ', ')
              FROM dir_ips i WHERE i.id = d.id) AS ips,
           (SELECT GROUP_CONCAT(mc.dir_mac ORDER BY mc.num_linea SEPARATOR ', ')
              FROM dir_macs mc WHERE mc.id = d.id) AS macs,
           (SELECT GROUP_CONCAT(CONCAT_WS(' ', nm.num_movil, nm.operador) ORDER BY nm.num_linea SEPARATOR ', ')
              FROM num_moviles nm WHERE nm.id = d.id) AS moviles,
           (SELECT GROUP_CONCAT(im.dir_imei ORDER BY im.num_linea SEPARATOR ', ')
              FROM dir_imeis im WHERE im.id = d.id) AS imeis,
           (SELECT COUNT(*) FROM archivos dd
             WHERE dd.id = d.id) AS cantidad_documentos,
           d.creado_en, d.actualizado_en
      FROM equipos d
      JOIN tipo_equipos           t   ON t.tipo_equipo = d.tipo_equipo
      JOIN categoria_equipos      c   ON c.id_categoria = t.id_categoria
      JOIN marcas                 m   ON m.id_marca = d.id_marca
      LEFT JOIN modelos           mo  ON mo.id_modelo = d.id_modelo
      LEFT JOIN procesadores      pr  ON pr.id_proc = d.id_proces
      JOIN sis_operativos         so  ON so.id_so = d.id_so
      JOIN firmwares              fw  ON fw.id_firmw = d.id_firmw
      JOIN estado_equipos         est ON est.id_estado = d.id_estado
      LEFT JOIN edificios         e   ON e.id_predio = d.id_predio
      LEFT JOIN cat_departamentos dep ON dep.cod_departamento = d.cod_departamento
      LEFT JOIN personas          a   ON a.id = d.id_usuario
      LEFT JOIN personas          p   ON p.id = d.id_proveedor
     WHERE (p_activo IS NULL OR (d.id_estado <> 3) = p_activo)
       AND (p_id_categoria IS NULL OR t.id_categoria = p_id_categoria)
       AND (p_tipo_equipo IS NULL OR d.tipo_equipo = p_tipo_equipo)
       AND (p_id_marca IS NULL OR d.id_marca = p_id_marca)
       AND (p_id_predio IS NULL OR d.id_predio = p_id_predio)
       AND (p_cod_departamento IS NULL OR d.cod_departamento = p_cod_departamento)
       AND (p_id_usuario IS NULL OR d.id_usuario = p_id_usuario)
       AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
       AND (p_buscar IS NULL OR p_buscar = ''
            OR CONCAT_WS(' ', d.serie, mo.descripcion, d.nombre_equipo, d.placa_equipo, d.ubicacion,
                         d.extension, a.nombre, a.apellido1, a.apellido2) LIKE CONCAT('%', p_buscar, '%')
            OR EXISTS (SELECT 1 FROM dir_imeis im
                        WHERE im.id = d.id AND im.dir_imei LIKE CONCAT('%', p_buscar, '%'))
            OR EXISTS (SELECT 1 FROM num_moviles nm
                        WHERE nm.id = d.id AND nm.num_movil LIKE CONCAT('%', p_buscar, '%'))
            OR EXISTS (SELECT 1 FROM dir_ips i
                        WHERE i.id = d.id AND i.dir_ip LIKE CONCAT('%', p_buscar, '%'))
            OR (v_mac <> '' AND EXISTS (SELECT 1 FROM dir_macs mc
                                         WHERE mc.id = d.id AND mc.dir_mac LIKE CONCAT('%', v_mac, '%'))))
     ORDER BY t.descripcion, m.descripcion, mo.descripcion, d.serie;
END$$

-- Historial del equipo: sus cambios y los de sus IP, MAC, líneas, IMEI,
-- roles, herramientas, archivos y puertos, del más nuevo al más viejo.
-- Devuelve las mismas columnas que sp_aud_auditorias_listar para mostrarse
-- igual en la página.
CREATE OR REPLACE PROCEDURE sp_equipos_historial(
    IN p_id             INT,
    IN p_limite         INT,
    IN p_desplazamiento INT
)
BEGIN
    DECLARE v_limite INT DEFAULT LEAST(GREATEST(COALESCE(p_limite, 50), 1), 500);
    DECLARE v_desplazamiento INT DEFAULT GREATEST(COALESCE(p_desplazamiento, 0), 0);
    -- La llave como texto en una variable: así usa la misma intercalación
    -- (collation) que la columna llave y no choca con la de la conexión
    DECLARE v_llave VARCHAR(20) DEFAULT p_id;

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
     WHERE (a.tabla = 'equipos' AND a.llave = v_llave)
        OR (a.tabla IN ('dir_ips', 'dir_macs', 'num_moviles', 'dir_imeis', 'roles', 'herramientas',
                        'archivos', 'puertos_switch')
            AND a.llave LIKE CONCAT(v_llave, '/%'))
        -- los puertos de otro switch donde se conectó o desconectó este equipo
        OR (a.tabla = 'puertos_switch'
            AND (JSON_VALUE(a.datos_despues, '$.id_equipo') = p_id
                 OR JSON_VALUE(a.datos_antes, '$.id_equipo') = p_id))
     ORDER BY a.id DESC
     LIMIT v_limite OFFSET v_desplazamiento;
END$$

-- -------------------- dir_ips ----------------------------------
CREATE OR REPLACE PROCEDURE sp_dir_ips_insertar(
    IN  p_id        INT,
    IN  p_dir_ip VARCHAR(45),
    IN  p_interfaz VARCHAR(50),
    OUT p_num_linea INT
)
BEGIN
    DECLARE v_valor VARCHAR(45);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_valor = NULLIF(LOWER(TRIM(p_dir_ip)), '');
    IF v_valor IS NULL OR NOT (IS_IPV4(v_valor) OR IS_IPV6(v_valor)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección IP no es válida (ejemplo: 192.168.1.1).';
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
    IF EXISTS (SELECT 1 FROM dir_ips WHERE id = p_id AND dir_ip = v_valor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo ya tiene esa dirección IP.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM dir_ips
     WHERE id = p_id;

    INSERT INTO dir_ips (id, num_linea, dir_ip, interfaz)
    VALUES (p_id, p_num_linea, v_valor, NULLIF(TRIM(p_interfaz), ''));

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_ips_actualizar(
    IN p_id        INT,
    IN p_num_linea INT,
    IN p_dir_ip VARCHAR(45),
    IN p_interfaz VARCHAR(50)
)
BEGIN
    DECLARE v_valor VARCHAR(45);

    IF NOT EXISTS (SELECT 1 FROM dir_ips
                    WHERE id = p_id AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección IP no existe.';
    END IF;
    SET v_valor = NULLIF(LOWER(TRIM(p_dir_ip)), '');
    IF v_valor IS NULL OR NOT (IS_IPV4(v_valor) OR IS_IPV6(v_valor)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección IP no es válida (ejemplo: 192.168.1.1).';
    END IF;
    IF EXISTS (SELECT 1 FROM dir_ips
                WHERE (id = p_id AND dir_ip = v_valor) AND NOT (id = p_id AND num_linea = p_num_linea)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo ya tiene esa dirección IP.';
    END IF;
    UPDATE dir_ips
       SET dir_ip = v_valor,
           interfaz = NULLIF(TRIM(p_interfaz), '')
     WHERE id = p_id
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_ips_eliminar(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    DELETE FROM dir_ips
     WHERE id = p_id
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección IP no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_ips_obtener(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.dir_ip AS direccion_ip, x.interfaz
      FROM dir_ips x
     WHERE x.id = p_id
       AND x.num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_ips_listar(
    IN p_id INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.dir_ip AS direccion_ip, x.interfaz
      FROM dir_ips x
     WHERE x.id = p_id
     ORDER BY x.num_linea;
END$$

-- -------------------- dir_macs ---------------------------------
CREATE OR REPLACE PROCEDURE sp_dir_macs_insertar(
    IN  p_id        INT,
    IN  p_dir_mac VARCHAR(30),
    IN  p_interfaz VARCHAR(50),
    OUT p_num_linea INT
)
BEGIN
    DECLARE v_valor VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_valor = fn_formato_mac(p_dir_mac);
    IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9A-F]{12}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección MAC no es válida (ejemplo: AA-BB-CC-DD-EE-FF).';
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
    IF EXISTS (SELECT 1 FROM dir_macs WHERE dir_mac = v_valor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esa dirección MAC ya está registrada en un dispositivo.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM dir_macs
     WHERE id = p_id;

    INSERT INTO dir_macs (id, num_linea, dir_mac, interfaz)
    VALUES (p_id, p_num_linea, v_valor, NULLIF(TRIM(p_interfaz), ''));

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_macs_actualizar(
    IN p_id        INT,
    IN p_num_linea INT,
    IN p_dir_mac VARCHAR(30),
    IN p_interfaz VARCHAR(50)
)
BEGIN
    DECLARE v_valor VARCHAR(30);

    IF NOT EXISTS (SELECT 1 FROM dir_macs
                    WHERE id = p_id AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección MAC no existe.';
    END IF;
    SET v_valor = fn_formato_mac(p_dir_mac);
    IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9A-F]{12}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección MAC no es válida (ejemplo: AA-BB-CC-DD-EE-FF).';
    END IF;
    IF EXISTS (SELECT 1 FROM dir_macs
                WHERE (dir_mac = v_valor) AND NOT (id = p_id AND num_linea = p_num_linea)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Esa dirección MAC ya está registrada en un dispositivo.';
    END IF;
    UPDATE dir_macs
       SET dir_mac = v_valor,
           interfaz = NULLIF(TRIM(p_interfaz), '')
     WHERE id = p_id
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_macs_eliminar(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    DELETE FROM dir_macs
     WHERE id = p_id
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección MAC no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_macs_obtener(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.dir_mac AS direccion_mac, x.interfaz
      FROM dir_macs x
     WHERE x.id = p_id
       AND x.num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_macs_listar(
    IN p_id INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.dir_mac AS direccion_mac, x.interfaz
      FROM dir_macs x
     WHERE x.id = p_id
     ORDER BY x.num_linea;
END$$

-- -------------------- num_moviles ------------------------------
CREATE OR REPLACE PROCEDURE sp_num_moviles_insertar(
    IN  p_id        INT,
    IN  p_num_movil VARCHAR(20),
    IN  p_operador VARCHAR(50),
    OUT p_num_linea INT
)
BEGIN
    DECLARE v_valor VARCHAR(20);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_valor = NULLIF(TRIM(p_num_movil), '');
    IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9+][0-9 -]{3,19}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La línea no es válida (ejemplo: 8888-8888).';
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
    IF EXISTS (SELECT 1 FROM num_moviles WHERE id = p_id AND num_movil = v_valor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El equipo ya tiene esa línea.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM num_moviles
     WHERE id = p_id;

    INSERT INTO num_moviles (id, num_linea, num_movil, operador)
    VALUES (p_id, p_num_linea, v_valor, NULLIF(TRIM(p_operador), ''));

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_num_moviles_actualizar(
    IN p_id        INT,
    IN p_num_linea INT,
    IN p_num_movil VARCHAR(20),
    IN p_operador VARCHAR(50)
)
BEGIN
    DECLARE v_valor VARCHAR(20);

    IF NOT EXISTS (SELECT 1 FROM num_moviles
                    WHERE id = p_id AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La línea no existe.';
    END IF;
    SET v_valor = NULLIF(TRIM(p_num_movil), '');
    IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9+][0-9 -]{3,19}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La línea no es válida (ejemplo: 8888-8888).';
    END IF;
    IF EXISTS (SELECT 1 FROM num_moviles
                WHERE (id = p_id AND num_movil = v_valor) AND NOT (id = p_id AND num_linea = p_num_linea)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El equipo ya tiene esa línea.';
    END IF;
    UPDATE num_moviles
       SET num_movil = v_valor,
           operador = NULLIF(TRIM(p_operador), '')
     WHERE id = p_id
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_num_moviles_eliminar(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    DELETE FROM num_moviles
     WHERE id = p_id
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La línea no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_num_moviles_obtener(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.num_movil, x.operador
      FROM num_moviles x
     WHERE x.id = p_id
       AND x.num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_num_moviles_listar(
    IN p_id INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.num_movil, x.operador
      FROM num_moviles x
     WHERE x.id = p_id
     ORDER BY x.num_linea;
END$$

-- -------------------- dir_imeis --------------------------------
CREATE OR REPLACE PROCEDURE sp_dir_imeis_insertar(
    IN  p_id        INT,
    IN  p_dir_imei VARCHAR(30),
    OUT p_num_linea INT
)
BEGIN
    DECLARE v_valor VARCHAR(30);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    SET v_valor = NULLIF(REGEXP_REPLACE(p_dir_imei, '[^0-9]', ''), '');
    IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9]{15}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El IMEI debe tener 15 dígitos.';
    END IF;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;
    IF EXISTS (SELECT 1 FROM dir_imeis WHERE dir_imei = v_valor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese IMEI ya está registrado en un equipo.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM dir_imeis
     WHERE id = p_id;

    INSERT INTO dir_imeis (id, num_linea, dir_imei)
    VALUES (p_id, p_num_linea, v_valor);

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_imeis_actualizar(
    IN p_id        INT,
    IN p_num_linea INT,
    IN p_dir_imei VARCHAR(30)
)
BEGIN
    DECLARE v_valor VARCHAR(30);

    IF NOT EXISTS (SELECT 1 FROM dir_imeis
                    WHERE id = p_id AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El IMEI no existe.';
    END IF;
    SET v_valor = NULLIF(REGEXP_REPLACE(p_dir_imei, '[^0-9]', ''), '');
    IF v_valor IS NULL OR NOT (v_valor REGEXP '^[0-9]{15}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El IMEI debe tener 15 dígitos.';
    END IF;
    IF EXISTS (SELECT 1 FROM dir_imeis
                WHERE (dir_imei = v_valor) AND NOT (id = p_id AND num_linea = p_num_linea)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese IMEI ya está registrado en un equipo.';
    END IF;
    UPDATE dir_imeis
       SET dir_imei = v_valor
     WHERE id = p_id
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_imeis_eliminar(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    DELETE FROM dir_imeis
     WHERE id = p_id
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El IMEI no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_imeis_obtener(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.dir_imei
      FROM dir_imeis x
     WHERE x.id = p_id
       AND x.num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_dir_imeis_listar(
    IN p_id INT
)
BEGIN
    SELECT x.id AS id_disp, x.num_linea, x.dir_imei
      FROM dir_imeis x
     WHERE x.id = p_id
     ORDER BY x.num_linea;
END$$

-- -------------------- archivos ---------------------------------
-- Archivos de cada equipo. Salen con los nombres que usa la página
-- (id_disp, id_doc, tipo_documento, path_docs).
CREATE OR REPLACE PROCEDURE sp_archivos_insertar(
    IN  p_id        INT,
    IN  p_tipo_arch INT,
    IN  p_path_arch VARCHAR(255),
    OUT p_num_linea INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id FOR UPDATE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El dispositivo no existe.';
    END IF;

    SELECT COALESCE(MAX(num_linea), 0) + 1 INTO p_num_linea
      FROM archivos
     WHERE id = p_id;

    INSERT INTO archivos (id, num_linea, tipo_arch, path_arch)
    VALUES (p_id, p_num_linea, p_tipo_arch, p_path_arch);

    COMMIT;
END$$

CREATE OR REPLACE PROCEDURE sp_archivos_actualizar(
    IN p_id        INT,
    IN p_num_linea INT,
    IN p_tipo_arch INT,
    IN p_path_arch VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM archivos
                    WHERE id = p_id AND num_linea = p_num_linea) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El documento no existe.';
    END IF;
    UPDATE archivos
       SET tipo_arch = p_tipo_arch,
           path_arch = p_path_arch
     WHERE id = p_id
       AND num_linea = p_num_linea;
END$$

CREATE OR REPLACE PROCEDURE sp_archivos_eliminar(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    DELETE FROM archivos
     WHERE id = p_id
       AND num_linea = p_num_linea;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El documento no existe.';
    END IF;
END$$

CREATE OR REPLACE PROCEDURE sp_archivos_obtener(
    IN p_id        INT,
    IN p_num_linea INT
)
BEGIN
    SELECT dd.id AS id_disp, dd.num_linea, dd.tipo_arch AS id_doc, c.descripcion AS tipo_documento,
           dd.path_arch AS path_docs, dd.creado_en
      FROM archivos dd
      JOIN tipo_archivos c ON c.tipo_arch = dd.tipo_arch
     WHERE dd.id = p_id
       AND dd.num_linea = p_num_linea;
END$$

-- p_tipo_arch: solo un tipo de archivo (NULL = todos)
CREATE OR REPLACE PROCEDURE sp_archivos_listar(
    IN p_id        INT,
    IN p_tipo_arch INT
)
BEGIN
    SELECT dd.id AS id_disp, dd.num_linea, dd.tipo_arch AS id_doc, c.descripcion AS tipo_documento,
           dd.path_arch AS path_docs, dd.creado_en
      FROM archivos dd
      JOIN tipo_archivos c ON c.tipo_arch = dd.tipo_arch
     WHERE dd.id = p_id
       AND (p_tipo_arch IS NULL OR dd.tipo_arch = p_tipo_arch)
     ORDER BY dd.num_linea;
END$$


-- =====================================================================
-- 3. PUERTOS DE LOS SWITCHES: QUÉ EQUIPO ESTÁ CONECTADO A CADA UNO
-- =====================================================================

-- -------------------- puertos_switch ---------------------------
-- Puertos con datos de un switch (NULL = los de todos), con el equipo
-- conectado. Los puertos que no salen están libres. fuera_de_rango: el
-- puerto ya no existe porque al switch se le bajó la cantidad de puertos.
CREATE OR REPLACE PROCEDURE sp_puertos_switch_listar(
    IN p_id_switch INT
)
BEGIN
    SELECT p.id_switch, p.tipo_puerto, p.num_puerto,
           fn_rotulo_puerto(p.tipo_puerto, p.num_puerto, s.cant_ptos_eth, s.cant_ptos_sfp, s.sfp_combo) AS rotulo,
           (p.num_puerto > IF(p.tipo_puerto = 'T', s.cant_ptos_eth, s.cant_ptos_sfp)) AS fuera_de_rango,
           p.estado, p.vlan, p.nota, p.actualizado_en,
           p.id_equipo AS id_disp, d.serie, (d.id_estado <> 3) AS activo, d.nombre_equipo, d.placa_equipo AS placa,
           d.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo, t.id_categoria, c.descripcion AS categoria,
           m.descripcion AS marca, mo.descripcion AS modelo,
           e.descripcion AS edificio, d.ubicacion, dep.descripcion AS departamento,
           IF(a.id IS NULL, NULL, CONCAT_WS(' ', a.nombre, a.apellido1, a.apellido2)) AS asignado,
           (SELECT GROUP_CONCAT(i.dir_ip ORDER BY i.num_linea SEPARATOR ', ')
              FROM dir_ips i WHERE i.id = d.id) AS ips,
           (SELECT GROUP_CONCAT(mc.dir_mac ORDER BY mc.num_linea SEPARATOR ', ')
              FROM dir_macs mc WHERE mc.id = d.id) AS macs,
           -- en cuántos puertos (de este u otros switches) está el mismo equipo
           (SELECT COUNT(*) FROM puertos_switch o WHERE o.id_equipo = p.id_equipo) AS puertos_del_equipo
      FROM puertos_switch p
      JOIN equipos s                          ON s.id = p.id_switch
      LEFT JOIN equipos d                     ON d.id = p.id_equipo
      LEFT JOIN tipo_equipos      t     ON t.tipo_equipo = d.tipo_equipo
      LEFT JOIN categoria_equipos c     ON c.id_categoria = t.id_categoria
      LEFT JOIN marcas                  m     ON m.id_marca = d.id_marca
      LEFT JOIN modelos                 mo    ON mo.id_modelo = d.id_modelo
      LEFT JOIN edificios               e     ON e.id_predio = d.id_predio
      LEFT JOIN cat_departamentos           dep   ON dep.cod_departamento = d.cod_departamento
      LEFT JOIN personas                a     ON a.id = d.id_usuario
     WHERE p_id_switch IS NULL OR p.id_switch = p_id_switch
     ORDER BY p.id_switch, p.tipo_puerto DESC, p.num_puerto;
END$$

-- Equipos de red con puertos (switches, routers, firewalls...): los que
-- muestran el frente con sus puertos. Primero los switches; luego por
-- edificio (los sin edificio al final) y por nombre en la red o serie.
--   p_activo  TRUE/FALSE (NULL = todos)
CREATE OR REPLACE PROCEDURE sp_puertos_switch_equipos(
    IN p_activo BOOLEAN
)
BEGIN
    SELECT d.id AS id_disp, d.serie, d.nombre_equipo, d.placa_equipo AS placa, (d.id_estado <> 3) AS activo,
           d.tipo_equipo AS tipo_disp, t.descripcion AS tipo_dispositivo,
           m.descripcion AS marca, mo.descripcion AS modelo,
           d.cant_ptos_eth AS cant_ptos_ethernet, d.cant_ptos_sfp, d.sfp_combo,
           d.id_predio, e.descripcion AS edificio, d.ubicacion,
           (SELECT GROUP_CONCAT(i.dir_ip ORDER BY i.num_linea SEPARATOR ', ')
              FROM dir_ips i WHERE i.id = d.id) AS ips
      FROM equipos d
      JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
      JOIN marcas             m ON m.id_marca = d.id_marca
      LEFT JOIN modelos       mo ON mo.id_modelo = d.id_modelo
      LEFT JOIN edificios     e  ON e.id_predio = d.id_predio
     WHERE t.id_categoria = 1
       AND d.cant_ptos_eth + d.cant_ptos_sfp > 0
       AND (p_activo IS NULL OR (d.id_estado <> 3) = p_activo)
     ORDER BY (t.descripcion LIKE '%SWITCH%') DESC, e.descripcion IS NULL, e.descripcion, COALESCE(d.nombre_equipo, d.serie);
END$$

-- Dónde está conectado un equipo: los puertos de switch que lo tienen.
CREATE OR REPLACE PROCEDURE sp_puertos_switch_de_equipo(
    IN p_id_equipo INT
)
BEGIN
    SELECT p.id_switch, s.serie AS switch_serie, s.nombre_equipo AS switch_nombre, (s.id_estado <> 3) AS switch_activo,
           ts.descripcion AS switch_tipo, ms.descripcion AS switch_marca, mos.descripcion AS switch_modelo,
           es.descripcion AS switch_edificio, s.ubicacion AS switch_ubicacion,
           p.tipo_puerto, p.num_puerto,
           fn_rotulo_puerto(p.tipo_puerto, p.num_puerto, s.cant_ptos_eth, s.cant_ptos_sfp, s.sfp_combo) AS rotulo,
           p.estado, p.vlan, p.nota, p.actualizado_en
      FROM puertos_switch p
      JOIN equipos s             ON s.id = p.id_switch
      JOIN tipo_equipos ts ON ts.tipo_equipo = s.tipo_equipo
      JOIN marcas             ms ON ms.id_marca = s.id_marca
      LEFT JOIN modelos       mos ON mos.id_modelo = s.id_modelo
      LEFT JOIN edificios     es ON es.id_predio = s.id_predio
     WHERE p.id_equipo = p_id_equipo
     ORDER BY (s.id_estado <> 3) DESC, s.serie, p.tipo_puerto DESC, p.num_puerto;
END$$

-- Guarda un puerto: el equipo conectado, el estado, la VLAN y la nota.
--   p_tipo_puerto  T = cobre, F = SFP
--   p_num_puerto   1..cant_ptos_eth (T) o 1..cant_ptos_sfp (F)
--   p_id_equipo    equipo conectado (NULL = ninguno). Con equipo el puerto
--                  queda EN_USO.
--   p_estado       EN_USO, LIBRE, DESHABILITADO o DANADO (NULL = según si
--                  tiene equipo)
--   p_vlan         10, 10,20 o 1-100 (de 1 a 4094)
-- Un puerto libre sin VLAN ni nota se borra (los libres no se guardan). En
-- un switch con SFP combo, 45T y 45F son el mismo puerto: solo uno puede
-- estar en uso.
CREATE OR REPLACE PROCEDURE sp_puertos_switch_guardar(
    IN p_id_switch   INT,
    IN p_tipo_puerto CHAR(1),
    IN p_num_puerto  INT,
    IN p_id_equipo     INT,
    IN p_estado      VARCHAR(15),
    IN p_vlan        VARCHAR(30),
    IN p_nota        VARCHAR(255)
)
BEGIN
    DECLARE v_eth     INT;
    DECLARE v_sfp     INT;
    DECLARE v_combo   BOOLEAN;
    DECLARE v_tipo    CHAR(1) DEFAULT UPPER(TRIM(COALESCE(p_tipo_puerto, '')));
    DECLARE v_estado  VARCHAR(15) DEFAULT REPLACE(REPLACE(UPPER(TRIM(COALESCE(p_estado, ''))), ' ', '_'), 'Ñ', 'N');
    DECLARE v_vlan    VARCHAR(30) DEFAULT NULLIF(REPLACE(TRIM(COALESCE(p_vlan, '')), ' ', ''), '');
    DECLARE v_nota    VARCHAR(255) DEFAULT NULLIF(TRIM(COALESCE(p_nota, '')), '');
    DECLARE v_resto   VARCHAR(30);
    DECLARE v_numero  VARCHAR(30);
    DECLARE v_base    INT;
    DECLARE v_par_t   CHAR(1);
    DECLARE v_par_n   INT;
    DECLARE v_mensaje VARCHAR(255);

    IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id_switch) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El switch no existe.';
    END IF;
    SET v_eth = (SELECT d.cant_ptos_eth FROM equipos d JOIN tipo_equipos t ON t.tipo_equipo = d.tipo_equipo
                  WHERE d.id = p_id_switch AND t.id_categoria = 1);
    SET v_sfp = (SELECT cant_ptos_sfp FROM equipos WHERE id = p_id_switch);
    SET v_combo = (SELECT sfp_combo FROM equipos WHERE id = p_id_switch);
    IF v_eth IS NULL OR v_eth + v_sfp = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ese equipo no es un equipo de red con puertos.';
    END IF;
    IF v_tipo NOT IN ('T', 'F') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El tipo de puerto debe ser T (cobre) o F (SFP).';
    END IF;
    IF v_tipo = 'F' AND v_sfp = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El switch no tiene puertos SFP.';
    END IF;
    IF p_num_puerto IS NULL OR p_num_puerto < 1 OR p_num_puerto > IF(v_tipo = 'T', v_eth, v_sfp) THEN
        SET v_mensaje = IF(v_tipo = 'T', CONCAT('El switch tiene ', v_eth, ' puertos de cobre (1 a ', v_eth, ').'),
                                         CONCAT('El switch tiene ', v_sfp, ' puertos SFP.'));
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
    END IF;

    -- Equipo conectado
    IF p_id_equipo IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM equipos WHERE id = p_id_equipo) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El equipo conectado no existe.';
        END IF;
        IF p_id_equipo = p_id_switch THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un equipo no se puede conectar a sí mismo.';
        END IF;
        IF EXISTS (SELECT 1 FROM equipos WHERE id = p_id_equipo AND id_estado = 3) THEN
            SET v_mensaje = LEFT(CONCAT('El equipo con serie ', (SELECT serie FROM equipos WHERE id = p_id_equipo),
                                        ' está dado de baja: actívelo antes de conectarlo.'), 128);
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
        IF v_estado IN ('DESHABILITADO', 'DANADO') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un puerto deshabilitado o dañado no puede tener un equipo conectado.';
        END IF;
        SET v_estado = 'EN_USO';
    END IF;
    IF v_estado = '' THEN
        SET v_estado = 'LIBRE';
    END IF;
    IF v_estado NOT IN ('EN_USO', 'LIBRE', 'DESHABILITADO', 'DANADO') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El estado del puerto debe ser EN_USO, LIBRE, DESHABILITADO o DANADO.';
    END IF;

    -- VLAN: 10, 10,20 o 1-100, cada una de 1 a 4094
    IF v_vlan IS NOT NULL THEN
        IF NOT v_vlan REGEXP '^[0-9]{1,4}([,-][0-9]{1,4})*$' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La VLAN debe ser un número (10), una lista (10,20) o un rango (1-100).';
        END IF;
        SET v_resto = REPLACE(v_vlan, '-', ',');
        WHILE v_resto <> '' DO
            SET v_numero = SUBSTRING_INDEX(v_resto, ',', 1);
            IF CAST(v_numero AS UNSIGNED) NOT BETWEEN 1 AND 4094 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Las VLAN van de 1 a 4094.';
            END IF;
            SET v_resto = IF(LOCATE(',', v_resto) > 0, SUBSTRING(v_resto, LOCATE(',', v_resto) + 1), '');
        END WHILE;
    END IF;

    -- SFP combo: 45T y 45F son el mismo puerto
    IF v_combo AND v_sfp > 0 AND v_estado = 'EN_USO' THEN
        SET v_base = GREATEST(v_eth - v_sfp, 0);
        IF v_tipo = 'T' AND p_num_puerto > v_base THEN
            SET v_par_t = 'F', v_par_n = p_num_puerto - v_base;
        ELSEIF v_tipo = 'F' AND v_base + p_num_puerto <= v_eth THEN
            SET v_par_t = 'T', v_par_n = v_base + p_num_puerto;
        END IF;
        IF v_par_t IS NOT NULL AND EXISTS (SELECT 1 FROM puertos_switch
                                            WHERE id_switch = p_id_switch AND tipo_puerto = v_par_t
                                              AND num_puerto = v_par_n AND estado = 'EN_USO') THEN
            SET v_mensaje = CONCAT('El puerto ', fn_rotulo_puerto(v_tipo, p_num_puerto, v_eth, v_sfp, v_combo),
                                   ' es combo con el ', fn_rotulo_puerto(v_par_t, v_par_n, v_eth, v_sfp, v_combo),
                                   ', que ya está en uso: solo uno de los dos puede estar conectado.');
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_mensaje;
        END IF;
    END IF;

    IF p_id_equipo IS NULL AND v_estado = 'LIBRE' AND v_vlan IS NULL AND v_nota IS NULL THEN
        DELETE FROM puertos_switch
         WHERE id_switch = p_id_switch AND tipo_puerto = v_tipo AND num_puerto = p_num_puerto;
    ELSEIF EXISTS (SELECT 1 FROM puertos_switch
                    WHERE id_switch = p_id_switch AND tipo_puerto = v_tipo AND num_puerto = p_num_puerto) THEN
        UPDATE puertos_switch
           SET id_equipo = p_id_equipo, estado = v_estado, vlan = v_vlan, nota = v_nota
         WHERE id_switch = p_id_switch AND tipo_puerto = v_tipo AND num_puerto = p_num_puerto;
    ELSE
        INSERT INTO puertos_switch (id_switch, tipo_puerto, num_puerto, id_equipo, estado, vlan, nota)
        VALUES (p_id_switch, v_tipo, p_num_puerto, p_id_equipo, v_estado, v_vlan, v_nota);
    END IF;
END$$

-- Libera un puerto: borra su equipo, estado, VLAN y nota (si no tenía nada,
-- no hace nada).
CREATE OR REPLACE PROCEDURE sp_puertos_switch_eliminar(
    IN p_id_switch   INT,
    IN p_tipo_puerto CHAR(1),
    IN p_num_puerto  INT
)
BEGIN
    DELETE FROM puertos_switch
     WHERE id_switch = p_id_switch AND tipo_puerto = UPPER(TRIM(p_tipo_puerto)) AND num_puerto = p_num_puerto;
END$$


-- =====================================================================
-- 4. PROCEDIMIENTOS DEL MODELO ANTERIOR QUE YA NO SE USAN
-- =====================================================================

DROP PROCEDURE IF EXISTS sp_cat_categorias_dispositivos_listar$$
DROP PROCEDURE IF EXISTS sp_cat_categorias_dispositivos_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_edificios_insertar$$
DROP PROCEDURE IF EXISTS sp_cat_edificios_actualizar$$
DROP PROCEDURE IF EXISTS sp_cat_edificios_eliminar$$
DROP PROCEDURE IF EXISTS sp_cat_edificios_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_edificios_listar$$
DROP PROCEDURE IF EXISTS sp_cat_marcas_insertar$$
DROP PROCEDURE IF EXISTS sp_cat_marcas_actualizar$$
DROP PROCEDURE IF EXISTS sp_cat_marcas_eliminar$$
DROP PROCEDURE IF EXISTS sp_cat_marcas_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_marcas_listar$$
DROP PROCEDURE IF EXISTS sp_cat_modelos_insertar$$
DROP PROCEDURE IF EXISTS sp_cat_modelos_actualizar$$
DROP PROCEDURE IF EXISTS sp_cat_modelos_eliminar$$
DROP PROCEDURE IF EXISTS sp_cat_modelos_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_modelos_listar$$
DROP PROCEDURE IF EXISTS sp_cat_sistemas_operativos_insertar$$
DROP PROCEDURE IF EXISTS sp_cat_sistemas_operativos_actualizar$$
DROP PROCEDURE IF EXISTS sp_cat_sistemas_operativos_eliminar$$
DROP PROCEDURE IF EXISTS sp_cat_sistemas_operativos_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_sistemas_operativos_listar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_dispositivos_insertar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_dispositivos_actualizar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_dispositivos_eliminar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_dispositivos_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_dispositivos_listar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_documentos_insertar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_documentos_actualizar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_documentos_eliminar$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_documentos_obtener$$
DROP PROCEDURE IF EXISTS sp_cat_tipos_documentos_listar$$
DROP PROCEDURE IF EXISTS sp_red_documentos_dispositivos_insertar$$
DROP PROCEDURE IF EXISTS sp_red_documentos_dispositivos_actualizar$$
DROP PROCEDURE IF EXISTS sp_red_documentos_dispositivos_eliminar$$
DROP PROCEDURE IF EXISTS sp_red_documentos_dispositivos_obtener$$
DROP PROCEDURE IF EXISTS sp_red_documentos_dispositivos_listar$$
DROP PROCEDURE IF EXISTS sp_red_macs_dispositivos_insertar$$
DROP PROCEDURE IF EXISTS sp_red_macs_dispositivos_actualizar$$
DROP PROCEDURE IF EXISTS sp_red_macs_dispositivos_eliminar$$
DROP PROCEDURE IF EXISTS sp_red_macs_dispositivos_obtener$$
DROP PROCEDURE IF EXISTS sp_red_macs_dispositivos_listar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_validar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_guardar_direcciones$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_insertar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_actualizar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_eliminar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_activar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_eliminar_fisico$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_obtener$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_listar$$
DROP PROCEDURE IF EXISTS sp_equiposMuni_historial$$
DROP PROCEDURE IF EXISTS sp_red_puertos_switch_listar$$
DROP PROCEDURE IF EXISTS sp_red_puertos_switch_equipos$$
DROP PROCEDURE IF EXISTS sp_red_puertos_switch_de_equipo$$
DROP PROCEDURE IF EXISTS sp_red_puertos_switch_guardar$$
DROP PROCEDURE IF EXISTS sp_red_puertos_switch_eliminar$$
DROP PROCEDURE IF EXISTS sp_red_ips_dispositivos_insertar$$
DROP PROCEDURE IF EXISTS sp_red_ips_dispositivos_actualizar$$
DROP PROCEDURE IF EXISTS sp_red_ips_dispositivos_eliminar$$
DROP PROCEDURE IF EXISTS sp_red_ips_dispositivos_obtener$$
DROP PROCEDURE IF EXISTS sp_red_ips_dispositivos_listar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_validar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_guardar_direcciones$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_insertar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_actualizar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_eliminar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_activar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_eliminar_fisico$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_obtener$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_listar$$
DROP PROCEDURE IF EXISTS sp_red_dispositivos_historial$$

-- =====================================================================
-- 5. DISPARADORES: TODO EN MAYÚSCULA
-- =====================================================================

DROP TRIGGER IF EXISTS trg_mayus_tipo_equipos_ins$$
CREATE TRIGGER trg_mayus_tipo_equipos_ins BEFORE INSERT ON tipo_equipos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_equipos_upd$$
CREATE TRIGGER trg_mayus_tipo_equipos_upd BEFORE UPDATE ON tipo_equipos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_marcas_ins$$
CREATE TRIGGER trg_mayus_marcas_ins BEFORE INSERT ON marcas FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_marcas_upd$$
CREATE TRIGGER trg_mayus_marcas_upd BEFORE UPDATE ON marcas FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_modelos_ins$$
CREATE TRIGGER trg_mayus_modelos_ins BEFORE INSERT ON modelos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_modelos_upd$$
CREATE TRIGGER trg_mayus_modelos_upd BEFORE UPDATE ON modelos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_procesadores_ins$$
CREATE TRIGGER trg_mayus_procesadores_ins BEFORE INSERT ON procesadores FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_procesadores_upd$$
CREATE TRIGGER trg_mayus_procesadores_upd BEFORE UPDATE ON procesadores FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_sis_operativos_ins$$
CREATE TRIGGER trg_mayus_sis_operativos_ins BEFORE INSERT ON sis_operativos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_sis_operativos_upd$$
CREATE TRIGGER trg_mayus_sis_operativos_upd BEFORE UPDATE ON sis_operativos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_firmwares_ins$$
CREATE TRIGGER trg_mayus_firmwares_ins BEFORE INSERT ON firmwares FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_firmwares_upd$$
CREATE TRIGGER trg_mayus_firmwares_upd BEFORE UPDATE ON firmwares FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_estado_equipos_ins$$
CREATE TRIGGER trg_mayus_estado_equipos_ins BEFORE INSERT ON estado_equipos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_estado_equipos_upd$$
CREATE TRIGGER trg_mayus_estado_equipos_upd BEFORE UPDATE ON estado_equipos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_roles_ins$$
CREATE TRIGGER trg_mayus_tipo_roles_ins BEFORE INSERT ON tipo_roles FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_roles_upd$$
CREATE TRIGGER trg_mayus_tipo_roles_upd BEFORE UPDATE ON tipo_roles FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_herramientas_ins$$
CREATE TRIGGER trg_mayus_tipo_herramientas_ins BEFORE INSERT ON tipo_herramientas FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_herramientas_upd$$
CREATE TRIGGER trg_mayus_tipo_herramientas_upd BEFORE UPDATE ON tipo_herramientas FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_archivos_ins$$
CREATE TRIGGER trg_mayus_tipo_archivos_ins BEFORE INSERT ON tipo_archivos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_tipo_archivos_upd$$
CREATE TRIGGER trg_mayus_tipo_archivos_upd BEFORE UPDATE ON tipo_archivos FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
END$$
DROP TRIGGER IF EXISTS trg_mayus_edificios_ins$$
CREATE TRIGGER trg_mayus_edificios_ins BEFORE INSERT ON edificios FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
    SET NEW.otras_senas = UPPER(TRIM(NEW.otras_senas));
END$$
DROP TRIGGER IF EXISTS trg_mayus_edificios_upd$$
CREATE TRIGGER trg_mayus_edificios_upd BEFORE UPDATE ON edificios FOR EACH ROW
BEGIN
    SET NEW.descripcion = UPPER(TRIM(NEW.descripcion));
    SET NEW.otras_senas = UPPER(TRIM(NEW.otras_senas));
END$$
DROP TRIGGER IF EXISTS trg_mayus_equipos_ins$$
CREATE TRIGGER trg_mayus_equipos_ins BEFORE INSERT ON equipos FOR EACH ROW
BEGIN
    SET NEW.serie = UPPER(TRIM(NEW.serie));
    SET NEW.ubicacion = UPPER(TRIM(NEW.ubicacion));
    SET NEW.nombre_equipo = UPPER(TRIM(NEW.nombre_equipo));
    SET NEW.placa_equipo = UPPER(TRIM(NEW.placa_equipo));
    SET NEW.tipo_almacenamiento = UPPER(TRIM(NEW.tipo_almacenamiento));
    SET NEW.tecnologia_impresion = UPPER(TRIM(NEW.tecnologia_impresion));
    SET NEW.consumible = UPPER(TRIM(NEW.consumible));
    SET NEW.resolucion = UPPER(TRIM(NEW.resolucion));
    SET NEW.observaciones = UPPER(TRIM(NEW.observaciones));
END$$
DROP TRIGGER IF EXISTS trg_mayus_equipos_upd$$
CREATE TRIGGER trg_mayus_equipos_upd BEFORE UPDATE ON equipos FOR EACH ROW
BEGIN
    SET NEW.serie = UPPER(TRIM(NEW.serie));
    SET NEW.ubicacion = UPPER(TRIM(NEW.ubicacion));
    SET NEW.nombre_equipo = UPPER(TRIM(NEW.nombre_equipo));
    SET NEW.placa_equipo = UPPER(TRIM(NEW.placa_equipo));
    SET NEW.tipo_almacenamiento = UPPER(TRIM(NEW.tipo_almacenamiento));
    SET NEW.tecnologia_impresion = UPPER(TRIM(NEW.tecnologia_impresion));
    SET NEW.consumible = UPPER(TRIM(NEW.consumible));
    SET NEW.resolucion = UPPER(TRIM(NEW.resolucion));
    SET NEW.observaciones = UPPER(TRIM(NEW.observaciones));
END$$
DROP TRIGGER IF EXISTS trg_mayus_dir_ips_ins$$
CREATE TRIGGER trg_mayus_dir_ips_ins BEFORE INSERT ON dir_ips FOR EACH ROW
BEGIN
    SET NEW.interfaz = UPPER(TRIM(NEW.interfaz));
END$$
DROP TRIGGER IF EXISTS trg_mayus_dir_ips_upd$$
CREATE TRIGGER trg_mayus_dir_ips_upd BEFORE UPDATE ON dir_ips FOR EACH ROW
BEGIN
    SET NEW.interfaz = UPPER(TRIM(NEW.interfaz));
END$$
DROP TRIGGER IF EXISTS trg_mayus_dir_macs_ins$$
CREATE TRIGGER trg_mayus_dir_macs_ins BEFORE INSERT ON dir_macs FOR EACH ROW
BEGIN
    SET NEW.interfaz = UPPER(TRIM(NEW.interfaz));
END$$
DROP TRIGGER IF EXISTS trg_mayus_dir_macs_upd$$
CREATE TRIGGER trg_mayus_dir_macs_upd BEFORE UPDATE ON dir_macs FOR EACH ROW
BEGIN
    SET NEW.interfaz = UPPER(TRIM(NEW.interfaz));
END$$
DROP TRIGGER IF EXISTS trg_mayus_num_moviles_ins$$
CREATE TRIGGER trg_mayus_num_moviles_ins BEFORE INSERT ON num_moviles FOR EACH ROW
BEGIN
    SET NEW.operador = UPPER(TRIM(NEW.operador));
END$$
DROP TRIGGER IF EXISTS trg_mayus_num_moviles_upd$$
CREATE TRIGGER trg_mayus_num_moviles_upd BEFORE UPDATE ON num_moviles FOR EACH ROW
BEGIN
    SET NEW.operador = UPPER(TRIM(NEW.operador));
END$$
DROP TRIGGER IF EXISTS trg_mayus_puertos_switch_ins$$
CREATE TRIGGER trg_mayus_puertos_switch_ins BEFORE INSERT ON puertos_switch FOR EACH ROW
BEGIN
    SET NEW.nota = UPPER(TRIM(NEW.nota));
END$$
DROP TRIGGER IF EXISTS trg_mayus_puertos_switch_upd$$
CREATE TRIGGER trg_mayus_puertos_switch_upd BEFORE UPDATE ON puertos_switch FOR EACH ROW
BEGIN
    SET NEW.nota = UPPER(TRIM(NEW.nota));
END$$

-- =====================================================================
-- 6. DISPARADORES: FORMATO Y VALIDACIÓN (proveedor, coordenadas, IP, MAC, líneas e IMEI)
-- =====================================================================

DROP TRIGGER IF EXISTS trg_formato_edificios_ins$$
CREATE TRIGGER trg_formato_edificios_ins BEFORE INSERT ON edificios FOR EACH ROW
BEGIN
    SET NEW.ubicacion = NULLIF(TRIM(NEW.ubicacion), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_edificios_upd$$
CREATE TRIGGER trg_formato_edificios_upd BEFORE UPDATE ON edificios FOR EACH ROW
BEGIN
    SET NEW.ubicacion = NULLIF(TRIM(NEW.ubicacion), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_equipos_ins$$
CREATE TRIGGER trg_formato_equipos_ins BEFORE INSERT ON equipos FOR EACH ROW
BEGIN
    SET NEW.nombre_equipo = NULLIF(TRIM(NEW.nombre_equipo), '');
    SET NEW.placa_equipo = NULLIF(TRIM(NEW.placa_equipo), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_equipos_upd$$
CREATE TRIGGER trg_formato_equipos_upd BEFORE UPDATE ON equipos FOR EACH ROW
BEGIN
    SET NEW.nombre_equipo = NULLIF(TRIM(NEW.nombre_equipo), '');
    SET NEW.placa_equipo = NULLIF(TRIM(NEW.placa_equipo), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_dir_ips_ins$$
CREATE TRIGGER trg_formato_dir_ips_ins BEFORE INSERT ON dir_ips FOR EACH ROW
BEGIN
    SET NEW.dir_ip = NULLIF(LOWER(TRIM(NEW.dir_ip)), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_dir_ips_upd$$
CREATE TRIGGER trg_formato_dir_ips_upd BEFORE UPDATE ON dir_ips FOR EACH ROW
BEGIN
    SET NEW.dir_ip = NULLIF(LOWER(TRIM(NEW.dir_ip)), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_dir_macs_ins$$
CREATE TRIGGER trg_formato_dir_macs_ins BEFORE INSERT ON dir_macs FOR EACH ROW
BEGIN
    SET NEW.dir_mac = fn_formato_mac(NEW.dir_mac);
END$$
DROP TRIGGER IF EXISTS trg_formato_dir_macs_upd$$
CREATE TRIGGER trg_formato_dir_macs_upd BEFORE UPDATE ON dir_macs FOR EACH ROW
BEGIN
    SET NEW.dir_mac = fn_formato_mac(NEW.dir_mac);
END$$
DROP TRIGGER IF EXISTS trg_formato_num_moviles_ins$$
CREATE TRIGGER trg_formato_num_moviles_ins BEFORE INSERT ON num_moviles FOR EACH ROW
BEGIN
    SET NEW.num_movil = NULLIF(TRIM(NEW.num_movil), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_num_moviles_upd$$
CREATE TRIGGER trg_formato_num_moviles_upd BEFORE UPDATE ON num_moviles FOR EACH ROW
BEGIN
    SET NEW.num_movil = NULLIF(TRIM(NEW.num_movil), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_dir_imeis_ins$$
CREATE TRIGGER trg_formato_dir_imeis_ins BEFORE INSERT ON dir_imeis FOR EACH ROW
BEGIN
    SET NEW.dir_imei = NULLIF(REGEXP_REPLACE(NEW.dir_imei, '[^0-9]', ''), '');
END$$
DROP TRIGGER IF EXISTS trg_formato_dir_imeis_upd$$
CREATE TRIGGER trg_formato_dir_imeis_upd BEFORE UPDATE ON dir_imeis FOR EACH ROW
BEGIN
    SET NEW.dir_imei = NULLIF(REGEXP_REPLACE(NEW.dir_imei, '[^0-9]', ''), '');
END$$

DROP TRIGGER IF EXISTS trg_valida_equipos_ins$$
CREATE TRIGGER trg_valida_equipos_ins BEFORE INSERT ON equipos FOR EACH ROW
FOLLOWS trg_formato_equipos_ins
BEGIN
    IF NEW.id_proveedor IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM personas WHERE id = NEW.id_proveedor AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor indicado no es válido: debe ser una persona registrada como proveedor.';
    END IF;
    IF NEW.id_usuario IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM personas WHERE id = NEW.id_usuario AND es_proveedor = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La persona asignada no es válida: debe ser un funcionario registrado, no un proveedor.';
    END IF;
    IF NEW.garantia_hasta < NEW.fecha_compra THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La garantía no puede terminar antes de la fecha de compra.';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_equipos_upd$$
CREATE TRIGGER trg_valida_equipos_upd BEFORE UPDATE ON equipos FOR EACH ROW
FOLLOWS trg_formato_equipos_upd
BEGIN
    IF NEW.id_proveedor IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM personas WHERE id = NEW.id_proveedor AND es_proveedor = TRUE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El proveedor indicado no es válido: debe ser una persona registrada como proveedor.';
    END IF;
    IF NEW.id_usuario IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM personas WHERE id = NEW.id_usuario AND es_proveedor = FALSE) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La persona asignada no es válida: debe ser un funcionario registrado, no un proveedor.';
    END IF;
    IF NEW.garantia_hasta < NEW.fecha_compra THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La garantía no puede terminar antes de la fecha de compra.';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_dir_ips_ins$$
CREATE TRIGGER trg_valida_dir_ips_ins BEFORE INSERT ON dir_ips FOR EACH ROW
FOLLOWS trg_formato_dir_ips_ins
BEGIN
    IF NEW.dir_ip IS NULL OR NOT (IS_IPV4(NEW.dir_ip) OR IS_IPV6(NEW.dir_ip)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección IP no es válida (ejemplo: 192.168.1.1).';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_dir_ips_upd$$
CREATE TRIGGER trg_valida_dir_ips_upd BEFORE UPDATE ON dir_ips FOR EACH ROW
FOLLOWS trg_formato_dir_ips_upd
BEGIN
    IF NEW.dir_ip IS NULL OR NOT (IS_IPV4(NEW.dir_ip) OR IS_IPV6(NEW.dir_ip)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección IP no es válida (ejemplo: 192.168.1.1).';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_dir_macs_ins$$
CREATE TRIGGER trg_valida_dir_macs_ins BEFORE INSERT ON dir_macs FOR EACH ROW
FOLLOWS trg_formato_dir_macs_ins
BEGIN
    IF NEW.dir_mac IS NULL OR NEW.dir_mac NOT REGEXP '^[0-9A-F]{12}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección MAC no es válida (ejemplo: AA-BB-CC-DD-EE-FF).';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_dir_macs_upd$$
CREATE TRIGGER trg_valida_dir_macs_upd BEFORE UPDATE ON dir_macs FOR EACH ROW
FOLLOWS trg_formato_dir_macs_upd
BEGIN
    IF NEW.dir_mac IS NULL OR NEW.dir_mac NOT REGEXP '^[0-9A-F]{12}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La dirección MAC no es válida (ejemplo: AA-BB-CC-DD-EE-FF).';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_num_moviles_ins$$
CREATE TRIGGER trg_valida_num_moviles_ins BEFORE INSERT ON num_moviles FOR EACH ROW
FOLLOWS trg_formato_num_moviles_ins
BEGIN
    IF NEW.num_movil IS NULL OR NEW.num_movil NOT REGEXP '^[0-9+][0-9 -]{3,19}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La línea no es válida (ejemplo: 8888-8888).';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_num_moviles_upd$$
CREATE TRIGGER trg_valida_num_moviles_upd BEFORE UPDATE ON num_moviles FOR EACH ROW
FOLLOWS trg_formato_num_moviles_upd
BEGIN
    IF NEW.num_movil IS NULL OR NEW.num_movil NOT REGEXP '^[0-9+][0-9 -]{3,19}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La línea no es válida (ejemplo: 8888-8888).';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_dir_imeis_ins$$
CREATE TRIGGER trg_valida_dir_imeis_ins BEFORE INSERT ON dir_imeis FOR EACH ROW
FOLLOWS trg_formato_dir_imeis_ins
BEGIN
    IF NEW.dir_imei IS NULL OR NEW.dir_imei NOT REGEXP '^[0-9]{15}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El IMEI debe tener 15 dígitos.';
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_valida_dir_imeis_upd$$
CREATE TRIGGER trg_valida_dir_imeis_upd BEFORE UPDATE ON dir_imeis FOR EACH ROW
FOLLOWS trg_formato_dir_imeis_upd
BEGIN
    IF NEW.dir_imei IS NULL OR NEW.dir_imei NOT REGEXP '^[0-9]{15}$' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El IMEI debe tener 15 dígitos.';
    END IF;
END$$

-- =====================================================================
-- 7. DISPARADORES: AUDITORÍA DE CADA TABLA (insertar, actualizar, eliminar)
-- =====================================================================

-- --------------------------------------------------------- tipo_equipos
DROP TRIGGER IF EXISTS trg_aud_tipo_equipos_ins$$
CREATE TRIGGER trg_aud_tipo_equipos_ins AFTER INSERT ON tipo_equipos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'tipo_equipos',
                NEW.tipo_equipo, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('tipo_equipo', NEW.tipo_equipo, 'descripcion', NEW.descripcion, 'id_categoria', NEW.id_categoria));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_equipos_upd$$
CREATE TRIGGER trg_aud_tipo_equipos_upd AFTER UPDATE ON tipo_equipos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('tipo_equipo', OLD.tipo_equipo, 'descripcion', OLD.descripcion, 'id_categoria', OLD.id_categoria);
        SET v_despues = JSON_OBJECT('tipo_equipo', NEW.tipo_equipo, 'descripcion', NEW.descripcion, 'id_categoria', NEW.id_categoria);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'tipo_equipos',
                    NEW.tipo_equipo, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_equipos_del$$
CREATE TRIGGER trg_aud_tipo_equipos_del AFTER DELETE ON tipo_equipos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'tipo_equipos',
                OLD.tipo_equipo, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('tipo_equipo', OLD.tipo_equipo, 'descripcion', OLD.descripcion, 'id_categoria', OLD.id_categoria));
    END IF;
END$$
-- --------------------------------------------------------- marcas
DROP TRIGGER IF EXISTS trg_aud_marcas_ins$$
CREATE TRIGGER trg_aud_marcas_ins AFTER INSERT ON marcas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'marcas',
                NEW.id_marca, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('tipo_equipo', NEW.tipo_equipo, 'id_marca', NEW.id_marca, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_marcas_upd$$
CREATE TRIGGER trg_aud_marcas_upd AFTER UPDATE ON marcas FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('tipo_equipo', OLD.tipo_equipo, 'id_marca', OLD.id_marca, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('tipo_equipo', NEW.tipo_equipo, 'id_marca', NEW.id_marca, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'marcas',
                    NEW.id_marca, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_marcas_del$$
CREATE TRIGGER trg_aud_marcas_del AFTER DELETE ON marcas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'marcas',
                OLD.id_marca, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('tipo_equipo', OLD.tipo_equipo, 'id_marca', OLD.id_marca, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- modelos
DROP TRIGGER IF EXISTS trg_aud_modelos_ins$$
CREATE TRIGGER trg_aud_modelos_ins AFTER INSERT ON modelos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'modelos',
                NEW.id_modelo, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_marca', NEW.id_marca, 'id_modelo', NEW.id_modelo, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_modelos_upd$$
CREATE TRIGGER trg_aud_modelos_upd AFTER UPDATE ON modelos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_marca', OLD.id_marca, 'id_modelo', OLD.id_modelo, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_marca', NEW.id_marca, 'id_modelo', NEW.id_modelo, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'modelos',
                    NEW.id_modelo, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_modelos_del$$
CREATE TRIGGER trg_aud_modelos_del AFTER DELETE ON modelos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'modelos',
                OLD.id_modelo, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_marca', OLD.id_marca, 'id_modelo', OLD.id_modelo, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- procesadores
DROP TRIGGER IF EXISTS trg_aud_procesadores_ins$$
CREATE TRIGGER trg_aud_procesadores_ins AFTER INSERT ON procesadores FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'procesadores',
                NEW.id_proc, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_proc', NEW.id_proc, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_procesadores_upd$$
CREATE TRIGGER trg_aud_procesadores_upd AFTER UPDATE ON procesadores FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_proc', OLD.id_proc, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_proc', NEW.id_proc, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'procesadores',
                    NEW.id_proc, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_procesadores_del$$
CREATE TRIGGER trg_aud_procesadores_del AFTER DELETE ON procesadores FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'procesadores',
                OLD.id_proc, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_proc', OLD.id_proc, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- sis_operativos
DROP TRIGGER IF EXISTS trg_aud_sis_operativos_ins$$
CREATE TRIGGER trg_aud_sis_operativos_ins AFTER INSERT ON sis_operativos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'sis_operativos',
                NEW.id_so, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_so', NEW.id_so, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_sis_operativos_upd$$
CREATE TRIGGER trg_aud_sis_operativos_upd AFTER UPDATE ON sis_operativos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_so', OLD.id_so, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_so', NEW.id_so, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'sis_operativos',
                    NEW.id_so, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_sis_operativos_del$$
CREATE TRIGGER trg_aud_sis_operativos_del AFTER DELETE ON sis_operativos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'sis_operativos',
                OLD.id_so, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_so', OLD.id_so, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- firmwares
DROP TRIGGER IF EXISTS trg_aud_firmwares_ins$$
CREATE TRIGGER trg_aud_firmwares_ins AFTER INSERT ON firmwares FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'firmwares',
                NEW.id_firmw, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_firmw', NEW.id_firmw, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_firmwares_upd$$
CREATE TRIGGER trg_aud_firmwares_upd AFTER UPDATE ON firmwares FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_firmw', OLD.id_firmw, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_firmw', NEW.id_firmw, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'firmwares',
                    NEW.id_firmw, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_firmwares_del$$
CREATE TRIGGER trg_aud_firmwares_del AFTER DELETE ON firmwares FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'firmwares',
                OLD.id_firmw, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_firmw', OLD.id_firmw, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- edificios
DROP TRIGGER IF EXISTS trg_aud_edificios_ins$$
CREATE TRIGGER trg_aud_edificios_ins AFTER INSERT ON edificios FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'edificios',
                NEW.id_predio, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_predio', NEW.id_predio, 'descripcion', NEW.descripcion, 'otras_senas', NEW.otras_senas, 'ubicacion', NEW.ubicacion, 'id_pais', NEW.id_pais, 'id_provincia', NEW.id_provincia, 'id_canton', NEW.id_canton, 'id_distrito', NEW.id_distrito));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_edificios_upd$$
CREATE TRIGGER trg_aud_edificios_upd AFTER UPDATE ON edificios FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_predio', OLD.id_predio, 'descripcion', OLD.descripcion, 'otras_senas', OLD.otras_senas, 'ubicacion', OLD.ubicacion, 'id_pais', OLD.id_pais, 'id_provincia', OLD.id_provincia, 'id_canton', OLD.id_canton, 'id_distrito', OLD.id_distrito);
        SET v_despues = JSON_OBJECT('id_predio', NEW.id_predio, 'descripcion', NEW.descripcion, 'otras_senas', NEW.otras_senas, 'ubicacion', NEW.ubicacion, 'id_pais', NEW.id_pais, 'id_provincia', NEW.id_provincia, 'id_canton', NEW.id_canton, 'id_distrito', NEW.id_distrito);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'edificios',
                    NEW.id_predio, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_edificios_del$$
CREATE TRIGGER trg_aud_edificios_del AFTER DELETE ON edificios FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'edificios',
                OLD.id_predio, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_predio', OLD.id_predio, 'descripcion', OLD.descripcion, 'otras_senas', OLD.otras_senas, 'ubicacion', OLD.ubicacion, 'id_pais', OLD.id_pais, 'id_provincia', OLD.id_provincia, 'id_canton', OLD.id_canton, 'id_distrito', OLD.id_distrito));
    END IF;
END$$
-- --------------------------------------------------------- estado_equipos
DROP TRIGGER IF EXISTS trg_aud_estado_equipos_ins$$
CREATE TRIGGER trg_aud_estado_equipos_ins AFTER INSERT ON estado_equipos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'estado_equipos',
                NEW.id_estado, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_estado', NEW.id_estado, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_estado_equipos_upd$$
CREATE TRIGGER trg_aud_estado_equipos_upd AFTER UPDATE ON estado_equipos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_estado', OLD.id_estado, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_estado', NEW.id_estado, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'estado_equipos',
                    NEW.id_estado, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_estado_equipos_del$$
CREATE TRIGGER trg_aud_estado_equipos_del AFTER DELETE ON estado_equipos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'estado_equipos',
                OLD.id_estado, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_estado', OLD.id_estado, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- tipo_roles
DROP TRIGGER IF EXISTS trg_aud_tipo_roles_ins$$
CREATE TRIGGER trg_aud_tipo_roles_ins AFTER INSERT ON tipo_roles FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'tipo_roles',
                NEW.id_rol, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_rol', NEW.id_rol, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_roles_upd$$
CREATE TRIGGER trg_aud_tipo_roles_upd AFTER UPDATE ON tipo_roles FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_rol', OLD.id_rol, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_rol', NEW.id_rol, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'tipo_roles',
                    NEW.id_rol, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_roles_del$$
CREATE TRIGGER trg_aud_tipo_roles_del AFTER DELETE ON tipo_roles FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'tipo_roles',
                OLD.id_rol, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_rol', OLD.id_rol, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- tipo_herramientas
DROP TRIGGER IF EXISTS trg_aud_tipo_herramientas_ins$$
CREATE TRIGGER trg_aud_tipo_herramientas_ins AFTER INSERT ON tipo_herramientas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'tipo_herramientas',
                NEW.id_herram, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('id_herram', NEW.id_herram, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_herramientas_upd$$
CREATE TRIGGER trg_aud_tipo_herramientas_upd AFTER UPDATE ON tipo_herramientas FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_herram', OLD.id_herram, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('id_herram', NEW.id_herram, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'tipo_herramientas',
                    NEW.id_herram, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_herramientas_del$$
CREATE TRIGGER trg_aud_tipo_herramientas_del AFTER DELETE ON tipo_herramientas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'tipo_herramientas',
                OLD.id_herram, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('id_herram', OLD.id_herram, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- tipo_archivos
DROP TRIGGER IF EXISTS trg_aud_tipo_archivos_ins$$
CREATE TRIGGER trg_aud_tipo_archivos_ins AFTER INSERT ON tipo_archivos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'tipo_archivos',
                NEW.tipo_arch, NULL, LEFT(NEW.descripcion, 255),
                JSON_OBJECT('tipo_arch', NEW.tipo_arch, 'descripcion', NEW.descripcion));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_archivos_upd$$
CREATE TRIGGER trg_aud_tipo_archivos_upd AFTER UPDATE ON tipo_archivos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('tipo_arch', OLD.tipo_arch, 'descripcion', OLD.descripcion);
        SET v_despues = JSON_OBJECT('tipo_arch', NEW.tipo_arch, 'descripcion', NEW.descripcion);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'tipo_archivos',
                    NEW.tipo_arch, NULL, LEFT(NEW.descripcion, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_tipo_archivos_del$$
CREATE TRIGGER trg_aud_tipo_archivos_del AFTER DELETE ON tipo_archivos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'tipo_archivos',
                OLD.tipo_arch, NULL, LEFT(OLD.descripcion, 255),
                JSON_OBJECT('tipo_arch', OLD.tipo_arch, 'descripcion', OLD.descripcion));
    END IF;
END$$
-- --------------------------------------------------------- equipos
DROP TRIGGER IF EXISTS trg_aud_equipos_ins$$
CREATE TRIGGER trg_aud_equipos_ins AFTER INSERT ON equipos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'equipos',
                NEW.id, NULL, LEFT(CONCAT_WS(' · ', CONCAT('SERIE ', NEW.serie), NEW.nombre_equipo), 255),
                JSON_OBJECT('id', NEW.id, 'serie', NEW.serie, 'tipo_equipo', NEW.tipo_equipo, 'id_marca', NEW.id_marca, 'id_modelo', NEW.id_modelo, 'nombre_equipo', NEW.nombre_equipo, 'placa_equipo', NEW.placa_equipo, 'id_proces', NEW.id_proces, 'cant_mem', NEW.cant_mem, 'cant_almac', NEW.cant_almac, 'tipo_almacenamiento', NEW.tipo_almacenamiento, 'cant_ptos_serie', NEW.cant_ptos_serie, 'cant_ptos_usb', NEW.cant_ptos_usb, 'cant_ptos_eth', NEW.cant_ptos_eth, 'cant_ptos_sfp', NEW.cant_ptos_sfp, 'cant_ptos_wireless', NEW.cant_ptos_wireless, 'cant_ptos_bluetooth', NEW.cant_ptos_bluetooth, 'cant_ptos_celular', NEW.cant_ptos_celular, 'id_so', NEW.id_so, 'id_firmw', NEW.id_firmw, 'extension', NEW.extension, 'tecnologia_impresion', NEW.tecnologia_impresion, 'a_color', NEW.a_color, 'consumible', NEW.consumible, 'pulgadas', NEW.pulgadas, 'resolucion', NEW.resolucion, 'capacidad_va', NEW.capacidad_va, 'autonomia_min', NEW.autonomia_min, 'canales', NEW.canales, 'id_predio', NEW.id_predio, 'ubicacion', NEW.ubicacion, 'id_estado', NEW.id_estado, 'cod_departamento', NEW.cod_departamento, 'id_usuario', NEW.id_usuario, 'id_proveedor', NEW.id_proveedor, 'fecha_compra', NEW.fecha_compra, 'garantia_hasta', NEW.garantia_hasta, 'observaciones', NEW.observaciones, 'sfp_combo', NEW.sfp_combo));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_equipos_upd$$
CREATE TRIGGER trg_aud_equipos_upd AFTER UPDATE ON equipos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'serie', OLD.serie, 'tipo_equipo', OLD.tipo_equipo, 'id_marca', OLD.id_marca, 'id_modelo', OLD.id_modelo, 'nombre_equipo', OLD.nombre_equipo, 'placa_equipo', OLD.placa_equipo, 'id_proces', OLD.id_proces, 'cant_mem', OLD.cant_mem, 'cant_almac', OLD.cant_almac, 'tipo_almacenamiento', OLD.tipo_almacenamiento, 'cant_ptos_serie', OLD.cant_ptos_serie, 'cant_ptos_usb', OLD.cant_ptos_usb, 'cant_ptos_eth', OLD.cant_ptos_eth, 'cant_ptos_sfp', OLD.cant_ptos_sfp, 'cant_ptos_wireless', OLD.cant_ptos_wireless, 'cant_ptos_bluetooth', OLD.cant_ptos_bluetooth, 'cant_ptos_celular', OLD.cant_ptos_celular, 'id_so', OLD.id_so, 'id_firmw', OLD.id_firmw, 'extension', OLD.extension, 'tecnologia_impresion', OLD.tecnologia_impresion, 'a_color', OLD.a_color, 'consumible', OLD.consumible, 'pulgadas', OLD.pulgadas, 'resolucion', OLD.resolucion, 'capacidad_va', OLD.capacidad_va, 'autonomia_min', OLD.autonomia_min, 'canales', OLD.canales, 'id_predio', OLD.id_predio, 'ubicacion', OLD.ubicacion, 'id_estado', OLD.id_estado, 'cod_departamento', OLD.cod_departamento, 'id_usuario', OLD.id_usuario, 'id_proveedor', OLD.id_proveedor, 'fecha_compra', OLD.fecha_compra, 'garantia_hasta', OLD.garantia_hasta, 'observaciones', OLD.observaciones, 'sfp_combo', OLD.sfp_combo);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'serie', NEW.serie, 'tipo_equipo', NEW.tipo_equipo, 'id_marca', NEW.id_marca, 'id_modelo', NEW.id_modelo, 'nombre_equipo', NEW.nombre_equipo, 'placa_equipo', NEW.placa_equipo, 'id_proces', NEW.id_proces, 'cant_mem', NEW.cant_mem, 'cant_almac', NEW.cant_almac, 'tipo_almacenamiento', NEW.tipo_almacenamiento, 'cant_ptos_serie', NEW.cant_ptos_serie, 'cant_ptos_usb', NEW.cant_ptos_usb, 'cant_ptos_eth', NEW.cant_ptos_eth, 'cant_ptos_sfp', NEW.cant_ptos_sfp, 'cant_ptos_wireless', NEW.cant_ptos_wireless, 'cant_ptos_bluetooth', NEW.cant_ptos_bluetooth, 'cant_ptos_celular', NEW.cant_ptos_celular, 'id_so', NEW.id_so, 'id_firmw', NEW.id_firmw, 'extension', NEW.extension, 'tecnologia_impresion', NEW.tecnologia_impresion, 'a_color', NEW.a_color, 'consumible', NEW.consumible, 'pulgadas', NEW.pulgadas, 'resolucion', NEW.resolucion, 'capacidad_va', NEW.capacidad_va, 'autonomia_min', NEW.autonomia_min, 'canales', NEW.canales, 'id_predio', NEW.id_predio, 'ubicacion', NEW.ubicacion, 'id_estado', NEW.id_estado, 'cod_departamento', NEW.cod_departamento, 'id_usuario', NEW.id_usuario, 'id_proveedor', NEW.id_proveedor, 'fecha_compra', NEW.fecha_compra, 'garantia_hasta', NEW.garantia_hasta, 'observaciones', NEW.observaciones, 'sfp_combo', NEW.sfp_combo);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'equipos',
                    NEW.id, NULL, LEFT(CONCAT_WS(' · ', CONCAT('SERIE ', NEW.serie), NEW.nombre_equipo), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_equipos_del$$
CREATE TRIGGER trg_aud_equipos_del AFTER DELETE ON equipos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'equipos',
                OLD.id, NULL, LEFT(CONCAT_WS(' · ', CONCAT('SERIE ', OLD.serie), OLD.nombre_equipo), 255),
                JSON_OBJECT('id', OLD.id, 'serie', OLD.serie, 'tipo_equipo', OLD.tipo_equipo, 'id_marca', OLD.id_marca, 'id_modelo', OLD.id_modelo, 'nombre_equipo', OLD.nombre_equipo, 'placa_equipo', OLD.placa_equipo, 'id_proces', OLD.id_proces, 'cant_mem', OLD.cant_mem, 'cant_almac', OLD.cant_almac, 'tipo_almacenamiento', OLD.tipo_almacenamiento, 'cant_ptos_serie', OLD.cant_ptos_serie, 'cant_ptos_usb', OLD.cant_ptos_usb, 'cant_ptos_eth', OLD.cant_ptos_eth, 'cant_ptos_sfp', OLD.cant_ptos_sfp, 'cant_ptos_wireless', OLD.cant_ptos_wireless, 'cant_ptos_bluetooth', OLD.cant_ptos_bluetooth, 'cant_ptos_celular', OLD.cant_ptos_celular, 'id_so', OLD.id_so, 'id_firmw', OLD.id_firmw, 'extension', OLD.extension, 'tecnologia_impresion', OLD.tecnologia_impresion, 'a_color', OLD.a_color, 'consumible', OLD.consumible, 'pulgadas', OLD.pulgadas, 'resolucion', OLD.resolucion, 'capacidad_va', OLD.capacidad_va, 'autonomia_min', OLD.autonomia_min, 'canales', OLD.canales, 'id_predio', OLD.id_predio, 'ubicacion', OLD.ubicacion, 'id_estado', OLD.id_estado, 'cod_departamento', OLD.cod_departamento, 'id_usuario', OLD.id_usuario, 'id_proveedor', OLD.id_proveedor, 'fecha_compra', OLD.fecha_compra, 'garantia_hasta', OLD.garantia_hasta, 'observaciones', OLD.observaciones, 'sfp_combo', OLD.sfp_combo));
    END IF;
END$$
-- --------------------------------------------------------- dir_ips
DROP TRIGGER IF EXISTS trg_aud_dir_ips_ins$$
CREATE TRIGGER trg_aud_dir_ips_ins AFTER INSERT ON dir_ips FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'dir_ips',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.dir_ip, 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'dir_ip', NEW.dir_ip, 'interfaz', NEW.interfaz));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_dir_ips_upd$$
CREATE TRIGGER trg_aud_dir_ips_upd AFTER UPDATE ON dir_ips FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'dir_ip', OLD.dir_ip, 'interfaz', OLD.interfaz);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'dir_ip', NEW.dir_ip, 'interfaz', NEW.interfaz);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'dir_ips',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.dir_ip, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_dir_ips_del$$
CREATE TRIGGER trg_aud_dir_ips_del AFTER DELETE ON dir_ips FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'dir_ips',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT(OLD.dir_ip, 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'dir_ip', OLD.dir_ip, 'interfaz', OLD.interfaz));
    END IF;
END$$
-- --------------------------------------------------------- dir_macs
DROP TRIGGER IF EXISTS trg_aud_dir_macs_ins$$
CREATE TRIGGER trg_aud_dir_macs_ins AFTER INSERT ON dir_macs FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'dir_macs',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.dir_mac, 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'dir_mac', NEW.dir_mac, 'interfaz', NEW.interfaz));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_dir_macs_upd$$
CREATE TRIGGER trg_aud_dir_macs_upd AFTER UPDATE ON dir_macs FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'dir_mac', OLD.dir_mac, 'interfaz', OLD.interfaz);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'dir_mac', NEW.dir_mac, 'interfaz', NEW.interfaz);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'dir_macs',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.dir_mac, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_dir_macs_del$$
CREATE TRIGGER trg_aud_dir_macs_del AFTER DELETE ON dir_macs FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'dir_macs',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT(OLD.dir_mac, 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'dir_mac', OLD.dir_mac, 'interfaz', OLD.interfaz));
    END IF;
END$$
-- --------------------------------------------------------- num_moviles
DROP TRIGGER IF EXISTS trg_aud_num_moviles_ins$$
CREATE TRIGGER trg_aud_num_moviles_ins AFTER INSERT ON num_moviles FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'num_moviles',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.num_movil, 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'num_movil', NEW.num_movil, 'operador', NEW.operador));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_num_moviles_upd$$
CREATE TRIGGER trg_aud_num_moviles_upd AFTER UPDATE ON num_moviles FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'num_movil', OLD.num_movil, 'operador', OLD.operador);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'num_movil', NEW.num_movil, 'operador', NEW.operador);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'num_moviles',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.num_movil, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_num_moviles_del$$
CREATE TRIGGER trg_aud_num_moviles_del AFTER DELETE ON num_moviles FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'num_moviles',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT(OLD.num_movil, 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'num_movil', OLD.num_movil, 'operador', OLD.operador));
    END IF;
END$$
-- --------------------------------------------------------- dir_imeis
DROP TRIGGER IF EXISTS trg_aud_dir_imeis_ins$$
CREATE TRIGGER trg_aud_dir_imeis_ins AFTER INSERT ON dir_imeis FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'dir_imeis',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.dir_imei, 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'dir_imei', NEW.dir_imei));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_dir_imeis_upd$$
CREATE TRIGGER trg_aud_dir_imeis_upd AFTER UPDATE ON dir_imeis FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'dir_imei', OLD.dir_imei);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'dir_imei', NEW.dir_imei);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'dir_imeis',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.dir_imei, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_dir_imeis_del$$
CREATE TRIGGER trg_aud_dir_imeis_del AFTER DELETE ON dir_imeis FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'dir_imeis',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT(OLD.dir_imei, 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'dir_imei', OLD.dir_imei));
    END IF;
END$$
-- --------------------------------------------------------- roles
DROP TRIGGER IF EXISTS trg_aud_roles_ins$$
CREATE TRIGGER trg_aud_roles_ins AFTER INSERT ON roles FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'roles',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT((SELECT descripcion FROM tipo_roles WHERE id_rol = NEW.id_rol), 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'id_rol', NEW.id_rol));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_roles_upd$$
CREATE TRIGGER trg_aud_roles_upd AFTER UPDATE ON roles FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'id_rol', OLD.id_rol);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'id_rol', NEW.id_rol);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'roles',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT((SELECT descripcion FROM tipo_roles WHERE id_rol = NEW.id_rol), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_roles_del$$
CREATE TRIGGER trg_aud_roles_del AFTER DELETE ON roles FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'roles',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT((SELECT descripcion FROM tipo_roles WHERE id_rol = OLD.id_rol), 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'id_rol', OLD.id_rol));
    END IF;
END$$
-- --------------------------------------------------------- herramientas
DROP TRIGGER IF EXISTS trg_aud_herramientas_ins$$
CREATE TRIGGER trg_aud_herramientas_ins AFTER INSERT ON herramientas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'herramientas',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT((SELECT descripcion FROM tipo_herramientas WHERE id_herram = NEW.id_herram), 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'id_herram', NEW.id_herram));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_herramientas_upd$$
CREATE TRIGGER trg_aud_herramientas_upd AFTER UPDATE ON herramientas FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'id_herram', OLD.id_herram);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'id_herram', NEW.id_herram);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'herramientas',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT((SELECT descripcion FROM tipo_herramientas WHERE id_herram = NEW.id_herram), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_herramientas_del$$
CREATE TRIGGER trg_aud_herramientas_del AFTER DELETE ON herramientas FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'herramientas',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT((SELECT descripcion FROM tipo_herramientas WHERE id_herram = OLD.id_herram), 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'id_herram', OLD.id_herram));
    END IF;
END$$
-- --------------------------------------------------------- archivos
DROP TRIGGER IF EXISTS trg_aud_archivos_ins$$
CREATE TRIGGER trg_aud_archivos_ins AFTER INSERT ON archivos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'archivos',
                CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.path_arch, 255),
                JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'tipo_arch', NEW.tipo_arch, 'path_arch', NEW.path_arch));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_archivos_upd$$
CREATE TRIGGER trg_aud_archivos_upd AFTER UPDATE ON archivos FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'tipo_arch', OLD.tipo_arch, 'path_arch', OLD.path_arch);
        SET v_despues = JSON_OBJECT('id', NEW.id, 'num_linea', NEW.num_linea, 'tipo_arch', NEW.tipo_arch, 'path_arch', NEW.path_arch);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'archivos',
                    CONCAT(NEW.id, '/', NEW.num_linea), NULL, LEFT(NEW.path_arch, 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_archivos_del$$
CREATE TRIGGER trg_aud_archivos_del AFTER DELETE ON archivos FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'archivos',
                CONCAT(OLD.id, '/', OLD.num_linea), NULL, LEFT(OLD.path_arch, 255),
                JSON_OBJECT('id', OLD.id, 'num_linea', OLD.num_linea, 'tipo_arch', OLD.tipo_arch, 'path_arch', OLD.path_arch));
    END IF;
END$$
-- --------------------------------------------------------- puertos_switch
DROP TRIGGER IF EXISTS trg_aud_puertos_switch_ins$$
CREATE TRIGGER trg_aud_puertos_switch_ins AFTER INSERT ON puertos_switch FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_despues)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'INSERTAR', 'puertos_switch',
                CONCAT(NEW.id_switch, '/', NEW.tipo_puerto, NEW.num_puerto), NULL, LEFT((SELECT CONCAT('PUERTO ', fn_rotulo_puerto(NEW.tipo_puerto, NEW.num_puerto, s.cant_ptos_eth, s.cant_ptos_sfp, s.sfp_combo), ' DEL ', COALESCE(s.nombre_equipo, CONCAT('SERIE ', s.serie))) FROM equipos s WHERE s.id = NEW.id_switch), 255),
                JSON_OBJECT('id_switch', NEW.id_switch, 'tipo_puerto', NEW.tipo_puerto, 'num_puerto', NEW.num_puerto, 'id_equipo', NEW.id_equipo, 'estado', NEW.estado, 'vlan', NEW.vlan, 'nota', NEW.nota));
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_puertos_switch_upd$$
CREATE TRIGGER trg_aud_puertos_switch_upd AFTER UPDATE ON puertos_switch FOR EACH ROW
BEGIN
    DECLARE v_antes LONGTEXT;
    DECLARE v_despues LONGTEXT;
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        SET v_antes = JSON_OBJECT('id_switch', OLD.id_switch, 'tipo_puerto', OLD.tipo_puerto, 'num_puerto', OLD.num_puerto, 'id_equipo', OLD.id_equipo, 'estado', OLD.estado, 'vlan', OLD.vlan, 'nota', OLD.nota);
        SET v_despues = JSON_OBJECT('id_switch', NEW.id_switch, 'tipo_puerto', NEW.tipo_puerto, 'num_puerto', NEW.num_puerto, 'id_equipo', NEW.id_equipo, 'estado', NEW.estado, 'vlan', NEW.vlan, 'nota', NEW.nota);
        IF NOT (v_antes <=> v_despues) THEN
            INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes, datos_despues)
            VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ACTUALIZAR', 'puertos_switch',
                    CONCAT(NEW.id_switch, '/', NEW.tipo_puerto, NEW.num_puerto), NULL, LEFT((SELECT CONCAT('PUERTO ', fn_rotulo_puerto(NEW.tipo_puerto, NEW.num_puerto, s.cant_ptos_eth, s.cant_ptos_sfp, s.sfp_combo), ' DEL ', COALESCE(s.nombre_equipo, CONCAT('SERIE ', s.serie))) FROM equipos s WHERE s.id = NEW.id_switch), 255),
                    v_antes, v_despues);
        END IF;
    END IF;
END$$
DROP TRIGGER IF EXISTS trg_aud_puertos_switch_del$$
CREATE TRIGGER trg_aud_puertos_switch_del AFTER DELETE ON puertos_switch FOR EACH ROW
BEGIN
    IF COALESCE(@muni_sin_auditoria, 0) = 0 THEN
        INSERT INTO aud_auditorias (id_usuario, nombre_usuario, ip, accion, tabla, llave, id_persona, descripcion, datos_antes)
        VALUES (@muni_usuario_id, @muni_usuario_nombre, @muni_ip, 'ELIMINAR', 'puertos_switch',
                CONCAT(OLD.id_switch, '/', OLD.tipo_puerto, OLD.num_puerto), NULL, LEFT((SELECT CONCAT('PUERTO ', fn_rotulo_puerto(OLD.tipo_puerto, OLD.num_puerto, s.cant_ptos_eth, s.cant_ptos_sfp, s.sfp_combo), ' DEL ', COALESCE(s.nombre_equipo, CONCAT('SERIE ', s.serie))) FROM equipos s WHERE s.id = OLD.id_switch), 255),
                JSON_OBJECT('id_switch', OLD.id_switch, 'tipo_puerto', OLD.tipo_puerto, 'num_puerto', OLD.num_puerto, 'id_equipo', OLD.id_equipo, 'estado', OLD.estado, 'vlan', OLD.vlan, 'nota', OLD.nota));
    END IF;
END$$

DELIMITER ;
