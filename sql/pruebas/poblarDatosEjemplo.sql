-- =====================================================================
--  poblarDatosEjemplo.sql - datos de ejemplo de los módulos de usuarios
--  y proveedores y de equipos municipales
--  gestion_redes (MariaDB 10.3 o superior)
-- ---------------------------------------------------------------------
--  Llena las tablas que normalmente se llenan desde la página, con datos
--  de ejemplo de la Municipalidad de Grecia:
--    - geografía: las 7 provincias, los cantones de Alajuela y los
--      distritos de Grecia
--    - 17 departamentos
--    - 17 funcionarios con teléfono y correo: 5 entran con clave del
--      sistema (ver la clave en la entrega) y los demás por Active Directory
--    - 7 proveedores con teléfono, correo y página web
--    - modelos, procesadores, versiones y 2 edificios más
--    - 53 equipos de todos los tipos con IP, MAC, líneas, IMEI,
--      herramientas de seguridad y roles de servidor
--    - 38 puertos de switches conectados a sus equipos
--    - cambios, una baja y un funcionario que se retiró, para que el
--      historial tenga movimientos
--  Todo pasa por los procedimientos del sistema: se valida igual que en
--  la página y queda en la auditoría como «CARGA DE DATOS DE EJEMPLO».
--  Las cédulas empiezan en 9 y los correos son del dominio grecia.test,
--  que no existe: no son de personas reales. Los equipos llevan
--  «DATO DE EJEMPLO» en observaciones.
--
--  Se puede ejecutar más de una vez: lo que ya existe no se repite.
--  Para quitar estos datos: pruebas/borrarDatosEjemplo.sql
--  Uso:  mariadb -u admin_db -p < pruebas/poblarDatosEjemplo.sql
-- =====================================================================

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;

/********************************************************************************/
/*                                                                              */
/*                  Revisar que la base tenga el modelo nuevo                   */
/*                                                                              */
/********************************************************************************/
DELIMITER $$
BEGIN NOT ATOMIC
  IF NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'dir_macs')
     OR NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'personas') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La base no tiene el modelo de datos nuevo: ejecute primero reinstalar_base.sh.';
  END IF;
END $$
DELIMITER ;

-- Así aparece en el historial quién hizo los cambios
SET @muni_usuario_id = NULL, @muni_usuario_nombre = 'CARGA DE DATOS DE EJEMPLO', @muni_ip = '127.0.0.1';
/********************************************************************************/
/*                                                                              */
/*                Procedimientos auxiliares (se borran al final)                */
/*                                                                              */
/********************************************************************************/
DELIMITER $$
CREATE OR REPLACE FUNCTION fn_ej_tipo(p VARCHAR(100)) RETURNS INT READS SQL DATA
  RETURN (SELECT tipo_equipo FROM tipo_equipos WHERE descripcion = p)$$
CREATE OR REPLACE FUNCTION fn_ej_marca(p_tipo VARCHAR(100), p VARCHAR(100)) RETURNS INT READS SQL DATA
  RETURN (SELECT id_marca FROM marcas WHERE tipo_equipo = fn_ej_tipo(p_tipo) AND descripcion = p)$$
CREATE OR REPLACE FUNCTION fn_ej_modelo(p_tipo VARCHAR(100), p_marca VARCHAR(100), p VARCHAR(150)) RETURNS INT READS SQL DATA
  RETURN (SELECT id_modelo FROM modelos WHERE id_marca = fn_ej_marca(p_tipo, p_marca) AND descripcion = p)$$
CREATE OR REPLACE FUNCTION fn_ej_equipo(p VARCHAR(100)) RETURNS INT READS SQL DATA
  RETURN (SELECT MIN(id) FROM equipos WHERE serie = p)$$
CREATE OR REPLACE FUNCTION fn_ej_persona(p VARCHAR(30)) RETURNS INT READS SQL DATA
  RETURN (SELECT MIN(id) FROM personas WHERE dni = p)$$
CREATE OR REPLACE FUNCTION fn_ej_depto(p VARCHAR(120)) RETURNS INT READS SQL DATA
  RETURN (SELECT MIN(cod_departamento) FROM cat_departamentos WHERE descripcion = p)$$

-- Un funcionario con su teléfono de oficina, su celular y su correo
CREATE OR REPLACE PROCEDURE tmp_ej_funcionario(
    p_dni VARCHAR(30), p_nombre VARCHAR(150), p_ap1 VARCHAR(100), p_ap2 VARCHAR(100), p_distrito VARCHAR(10),
    p_senas TEXT, p_depto VARCHAR(120), p_rol VARCHAR(60), p_usuario VARCHAR(50), p_hash VARCHAR(255),
    p_oficina VARCHAR(25), p_celular VARCHAR(25), p_correo VARCHAR(150))
BEGIN
  IF fn_ej_persona(p_dni) IS NULL THEN
    CALL sp_personas_insertar(
      (SELECT MIN(cod_rol) FROM cat_roles_usuarios WHERE descripcion = COALESCE(p_rol, 'ESTÁNDAR')),
      (SELECT MIN(cod_tipo_auth) FROM cat_tipos_autenticaciones
        WHERE descripcion = IF(p_hash IS NULL, 'ACTIVE DIRECTORY', 'SISTEMA APP')),
      (SELECT MIN(cod_tipo_identificacion) FROM cat_tipos_identificaciones WHERE descripcion = 'CÉDULA FÍSICA'),
      p_dni, p_nombre, p_ap1, p_ap2, 'CR', '2', '03', p_distrito, p_senas, NULL,
      fn_ej_depto(p_depto), p_usuario, p_hash, @ej_id);
    CALL sp_usr_telefonos_insertar(@ej_id, (SELECT MIN(cod_telefono) FROM cat_tipos_telefonos WHERE descripcion = 'TRABAJO FIJO'), p_oficina, FALSE, @ej_n);
    CALL sp_usr_telefonos_insertar(@ej_id, (SELECT MIN(cod_telefono) FROM cat_tipos_telefonos WHERE descripcion = 'TRABAJO CELULAR'), p_celular, TRUE, @ej_n);
    CALL sp_usr_correos_insertar(@ej_id, (SELECT MIN(cod_correo) FROM cat_tipos_correos WHERE descripcion = 'INSTITUCIONAL'), p_correo, @ej_n);
    IF p_hash IS NOT NULL THEN
      CALL sp_usr_historiales_claves_insertar(@ej_id, p_hash, @ej_n);
    END IF;
  END IF;
END$$

-- Un proveedor con su teléfono, su correo y su página web
CREATE OR REPLACE PROCEDURE tmp_ej_proveedor(
    p_dni VARCHAR(30), p_nombre VARCHAR(150), p_categoria VARCHAR(150), p_distrito VARCHAR(10), p_senas TEXT,
    p_telefono VARCHAR(25), p_correo VARCHAR(150), p_web VARCHAR(255))
BEGIN
  IF fn_ej_persona(p_dni) IS NULL THEN
    CALL sp_prv_proveedores_insertar(
      (SELECT MIN(cod_tipo_identificacion) FROM cat_tipos_identificaciones WHERE descripcion = 'CÉDULA JURÍDICA'),
      p_dni, p_nombre, NULL, NULL, 'CR', '2', '03', p_distrito, p_senas, NULL,
      (SELECT MIN(cod_categoria) FROM cat_categorias_proveedores WHERE descripcion = p_categoria), @ej_id);
    CALL sp_usr_telefonos_insertar(@ej_id, (SELECT MIN(cod_telefono) FROM cat_tipos_telefonos WHERE descripcion = 'TRABAJO FIJO'), p_telefono, FALSE, @ej_n);
    CALL sp_usr_correos_insertar(@ej_id, (SELECT MIN(cod_correo) FROM cat_tipos_correos WHERE descripcion = 'TRABAJO'), p_correo, @ej_n);
    IF p_web IS NOT NULL THEN
      CALL sp_usr_paginas_webs_insertar(@ej_id, p_web, @ej_n);
    END IF;
  END IF;
END$$

-- Un modelo de una marca de un tipo de equipo
CREATE OR REPLACE PROCEDURE tmp_ej_modelo(p_tipo VARCHAR(100), p_marca VARCHAR(100), p_modelo VARCHAR(150))
BEGIN
  IF fn_ej_marca(p_tipo, p_marca) IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Falta una marca de la especificación: ejecute primero insercionDispositivos.sql.';
  END IF;
  IF fn_ej_modelo(p_tipo, p_marca, p_modelo) IS NULL THEN
    CALL sp_modelos_insertar(fn_ej_marca(p_tipo, p_marca), p_modelo, @ej_id);
  END IF;
END$$

-- Un equipo, con los catálogos por nombre (tipo, marca, modelo, sistema...)
CREATE OR REPLACE PROCEDURE tmp_ej_equipo(
    p_serie VARCHAR(100),
    p_tipo VARCHAR(100),
    p_marca VARCHAR(100),
    p_modelo VARCHAR(150),
    p_nombre VARCHAR(100),
    p_placa VARCHAR(50),
    p_proc VARCHAR(150),
    p_mem INT,
    p_almac INT,
    p_talm VARCHAR(10),
    p_serie_ptos INT,
    p_usb INT,
    p_eth INT,
    p_sfp INT,
    p_wl INT,
    p_bt INT,
    p_cel INT,
    p_so VARCHAR(150),
    p_firmw VARCHAR(100),
    p_ext VARCHAR(10),
    p_tec VARCHAR(20),
    p_color BOOLEAN,
    p_consumible VARCHAR(100),
    p_pulg DECIMAL(4,1),
    p_res VARCHAR(20),
    p_va INT,
    p_aut INT,
    p_canales INT,
    p_edificio VARCHAR(150),
    p_ubic VARCHAR(255),
    p_estado INT,
    p_depto VARCHAR(120),
    p_persona VARCHAR(30),
    p_prov VARCHAR(30),
    p_compra DATE,
    p_garantia DATE,
    p_obs VARCHAR(500),
    p_combo BOOLEAN,
    p_ips LONGTEXT,
    p_macs LONGTEXT,
    p_moviles LONGTEXT,
    p_imeis LONGTEXT,
    p_roles LONGTEXT,
    p_herr LONGTEXT)
BEGIN
  IF fn_ej_tipo(p_tipo) IS NULL OR fn_ej_marca(p_tipo, p_marca) IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Falta un tipo o una marca de la especificación: ejecute primero insercionDispositivos.sql.';
  END IF;
  IF fn_ej_equipo(p_serie) IS NULL THEN
    CALL sp_equipos_insertar(p_serie, fn_ej_tipo(p_tipo), fn_ej_marca(p_tipo, p_marca), fn_ej_modelo(p_tipo, p_marca, p_modelo),
      p_nombre, p_placa, (SELECT id_proc FROM procesadores WHERE descripcion = p_proc), p_mem, p_almac, p_talm,
      p_serie_ptos, p_usb, p_eth, p_sfp, p_wl, p_bt, p_cel,
      COALESCE((SELECT id_so FROM sis_operativos WHERE descripcion = p_so), 1),
      COALESCE((SELECT id_firmw FROM firmwares WHERE descripcion = p_firmw), 1),
      p_ext, p_tec, p_color, p_consumible, p_pulg, p_res, p_va, p_aut, p_canales,
      (SELECT id_predio FROM edificios WHERE descripcion = p_edificio), p_ubic, p_estado, fn_ej_depto(p_depto),
      fn_ej_persona(p_persona), fn_ej_persona(p_prov), p_compra, p_garantia, p_obs, p_combo,
      p_ips, p_macs, p_moviles, p_imeis, p_roles, p_herr, NULL, @ej_id);
  END IF;
END$$

-- Un cambio a un equipo que ya existe (mismos datos que tmp_ej_equipo)
CREATE OR REPLACE PROCEDURE tmp_ej_cambio(
    p_serie VARCHAR(100),
    p_tipo VARCHAR(100),
    p_marca VARCHAR(100),
    p_modelo VARCHAR(150),
    p_nombre VARCHAR(100),
    p_placa VARCHAR(50),
    p_proc VARCHAR(150),
    p_mem INT,
    p_almac INT,
    p_talm VARCHAR(10),
    p_serie_ptos INT,
    p_usb INT,
    p_eth INT,
    p_sfp INT,
    p_wl INT,
    p_bt INT,
    p_cel INT,
    p_so VARCHAR(150),
    p_firmw VARCHAR(100),
    p_ext VARCHAR(10),
    p_tec VARCHAR(20),
    p_color BOOLEAN,
    p_consumible VARCHAR(100),
    p_pulg DECIMAL(4,1),
    p_res VARCHAR(20),
    p_va INT,
    p_aut INT,
    p_canales INT,
    p_edificio VARCHAR(150),
    p_ubic VARCHAR(255),
    p_estado INT,
    p_depto VARCHAR(120),
    p_persona VARCHAR(30),
    p_prov VARCHAR(30),
    p_compra DATE,
    p_garantia DATE,
    p_obs VARCHAR(500),
    p_combo BOOLEAN,
    p_ips LONGTEXT,
    p_macs LONGTEXT,
    p_moviles LONGTEXT,
    p_imeis LONGTEXT,
    p_roles LONGTEXT,
    p_herr LONGTEXT)
BEGIN
  CALL sp_equipos_actualizar(fn_ej_equipo(p_serie), p_serie, fn_ej_tipo(p_tipo), fn_ej_marca(p_tipo, p_marca), fn_ej_modelo(p_tipo, p_marca, p_modelo),
      p_nombre, p_placa, (SELECT id_proc FROM procesadores WHERE descripcion = p_proc), p_mem, p_almac, p_talm,
      p_serie_ptos, p_usb, p_eth, p_sfp, p_wl, p_bt, p_cel,
      COALESCE((SELECT id_so FROM sis_operativos WHERE descripcion = p_so), 1),
      COALESCE((SELECT id_firmw FROM firmwares WHERE descripcion = p_firmw), 1),
      p_ext, p_tec, p_color, p_consumible, p_pulg, p_res, p_va, p_aut, p_canales,
      (SELECT id_predio FROM edificios WHERE descripcion = p_edificio), p_ubic, p_estado, fn_ej_depto(p_depto),
      fn_ej_persona(p_persona), fn_ej_persona(p_prov), p_compra, p_garantia, p_obs, p_combo,
      p_ips, p_macs, p_moviles, p_imeis, p_roles, p_herr, NULL);
END$$

-- Un puerto de un switch y el equipo que tiene conectado
CREATE OR REPLACE PROCEDURE tmp_ej_puerto(p_switch VARCHAR(100), p_tipo CHAR(1), p_num INT, p_equipo VARCHAR(100),
    p_estado VARCHAR(15), p_vlan VARCHAR(30), p_nota VARCHAR(255))
BEGIN
  IF NOT EXISTS (SELECT 1 FROM puertos_switch WHERE id_switch = fn_ej_equipo(p_switch) AND tipo_puerto = p_tipo AND num_puerto = p_num) THEN
    CALL sp_puertos_switch_guardar(fn_ej_equipo(p_switch), p_tipo, p_num, fn_ej_equipo(p_equipo), p_estado, p_vlan, p_nota);
  END IF;
END$$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*      Geografía: provincias, cantones de Alajuela y distritos de Grecia       */
/*                                                                              */
/********************************************************************************/
/* Solo se agrega lo que falta */
SET @muni_sin_auditoria = 1;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT (SELECT COUNT(*) FROM geo_provincias) + (SELECT COUNT(*) FROM geo_cantones) + (SELECT COUNT(*) FROM geo_distritos));
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '1', 'SAN JOSÉ' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '1');
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '2', 'ALAJUELA' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '2');
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '3', 'CARTAGO' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '3');
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '4', 'HEREDIA' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '4');
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '5', 'GUANACASTE' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '5');
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '6', 'PUNTARENAS' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '6');
  INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) SELECT 'CR', '7', 'LIMÓN' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_provincias WHERE cod_pais = 'CR' AND cod_provincia = '7');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '01', 'ALAJUELA' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '01');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '02', 'SAN RAMÓN' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '02');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '03', 'GRECIA' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '04', 'SAN MATEO' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '04');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '05', 'ATENAS' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '05');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '06', 'NARANJO' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '06');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '07', 'PALMARES' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '07');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '08', 'POÁS' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '08');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '09', 'OROTINA' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '09');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '10', 'SAN CARLOS' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '10');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '11', 'ZARCERO' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '11');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '12', 'SARCHÍ' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '12');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '13', 'UPALA' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '13');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '14', 'LOS CHILES' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '14');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '15', 'GUATUSO' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '15');
  INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) SELECT 'CR', '2', '16', 'RÍO CUARTO' FROM DUAL
   WHERE NOT EXISTS (SELECT 1 FROM geo_cantones WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '16');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '01', 'GRECIA', '20301' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '01');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '02', 'SAN ISIDRO', '20302' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '02');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '03', 'SAN JOSÉ', '20303' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '03');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '04', 'SAN ROQUE', '20304' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '04');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '05', 'TACARES', '20305' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '05');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '07', 'PUENTE DE PIEDRA', '20307' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '07');
  INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal)
    SELECT 'CR', '2', '03', '08', 'BOLÍVAR', '20308' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM geo_distritos WHERE cod_pais = 'CR' AND cod_provincia = '2' AND cod_canton = '03' AND cod_distrito = '08');
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Provincias, cantones y distritos nuevos: ', (SELECT (SELECT COUNT(*) FROM geo_provincias) + (SELECT COUNT(*) FROM geo_cantones) + (SELECT COUNT(*) FROM geo_distritos)) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                      Departamentos de la municipalidad                       */
/*                                                                              */
/********************************************************************************/
/* Los departamentos a los que pertenecen las personas y los equipos */
SET @muni_sin_auditoria = 1;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM cat_departamentos);
  IF fn_ej_depto('ALCALDÍA MUNICIPAL') IS NULL THEN CALL sp_cat_departamentos_insertar('ALCALDÍA MUNICIPAL', @ej_id); END IF;
  IF fn_ej_depto('CONCEJO MUNICIPAL') IS NULL THEN CALL sp_cat_departamentos_insertar('CONCEJO MUNICIPAL', @ej_id); END IF;
  IF fn_ej_depto('AUDITORÍA INTERNA') IS NULL THEN CALL sp_cat_departamentos_insertar('AUDITORÍA INTERNA', @ej_id); END IF;
  IF fn_ej_depto('ASESORÍA LEGAL') IS NULL THEN CALL sp_cat_departamentos_insertar('ASESORÍA LEGAL', @ej_id); END IF;
  IF fn_ej_depto('RECURSOS HUMANOS') IS NULL THEN CALL sp_cat_departamentos_insertar('RECURSOS HUMANOS', @ej_id); END IF;
  IF fn_ej_depto('PROVEEDURÍA') IS NULL THEN CALL sp_cat_departamentos_insertar('PROVEEDURÍA', @ej_id); END IF;
  IF fn_ej_depto('TESORERÍA') IS NULL THEN CALL sp_cat_departamentos_insertar('TESORERÍA', @ej_id); END IF;
  IF fn_ej_depto('CONTABILIDAD') IS NULL THEN CALL sp_cat_departamentos_insertar('CONTABILIDAD', @ej_id); END IF;
  IF fn_ej_depto('CATASTRO') IS NULL THEN CALL sp_cat_departamentos_insertar('CATASTRO', @ej_id); END IF;
  IF fn_ej_depto('INGENIERÍA Y CONTROL URBANO') IS NULL THEN CALL sp_cat_departamentos_insertar('INGENIERÍA Y CONTROL URBANO', @ej_id); END IF;
  IF fn_ej_depto('GESTIÓN AMBIENTAL') IS NULL THEN CALL sp_cat_departamentos_insertar('GESTIÓN AMBIENTAL', @ej_id); END IF;
  IF fn_ej_depto('PATENTES') IS NULL THEN CALL sp_cat_departamentos_insertar('PATENTES', @ej_id); END IF;
  IF fn_ej_depto('COBRO ADMINISTRATIVO') IS NULL THEN CALL sp_cat_departamentos_insertar('COBRO ADMINISTRATIVO', @ej_id); END IF;
  IF fn_ej_depto('PLATAFORMA DE SERVICIOS') IS NULL THEN CALL sp_cat_departamentos_insertar('PLATAFORMA DE SERVICIOS', @ej_id); END IF;
  IF fn_ej_depto('POLICÍA MUNICIPAL') IS NULL THEN CALL sp_cat_departamentos_insertar('POLICÍA MUNICIPAL', @ej_id); END IF;
  IF fn_ej_depto('SERVICIOS GENERALES') IS NULL THEN CALL sp_cat_departamentos_insertar('SERVICIOS GENERALES', @ej_id); END IF;
  IF fn_ej_depto('ACUEDUCTO MUNICIPAL') IS NULL THEN CALL sp_cat_departamentos_insertar('ACUEDUCTO MUNICIPAL', @ej_id); END IF;
  IF fn_ej_depto('TECNOLOGÍAS DE INFORMACIÓN') IS NULL THEN CALL sp_cat_departamentos_insertar('TECNOLOGÍAS DE INFORMACIÓN', @ej_id); END IF;
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Departamentos nuevos: ', (SELECT COUNT(*) FROM cat_departamentos) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*      Catálogos de equipos: modelos, procesadores, versiones y edificios      */
/*                                                                              */
/********************************************************************************/
/* Los que trae la especificación ya están; aquí van los que usan los equipos de ejemplo */
SET @muni_sin_auditoria = 1;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT (SELECT COUNT(*) FROM modelos) + (SELECT COUNT(*) FROM procesadores) + (SELECT COUNT(*) FROM firmwares) + (SELECT COUNT(*) FROM edificios));
  CALL tmp_ej_modelo('MODEM', 'ARRIS', 'SURFBOARD SB8200');
  CALL tmp_ej_modelo('ACCESS POINT', 'UBIQUITI', 'U6 PRO');
  CALL tmp_ej_modelo('SERVER', 'DELL', 'POWEREDGE R740');
  CALL tmp_ej_modelo('SERVER', 'DELL', 'POWEREDGE R650');
  CALL tmp_ej_modelo('SERVER', 'HP', 'PROLIANT DL380 GEN10');
  CALL tmp_ej_modelo('NAS', 'SYNOLOGY', 'DS920+');
  CALL tmp_ej_modelo('LAPTOP', 'LENOVO', 'THINKPAD T14 GEN 3');
  CALL tmp_ej_modelo('LAPTOP', 'LENOVO', 'THINKPAD E14');
  CALL tmp_ej_modelo('LAPTOP', 'DELL', 'LATITUDE 5440');
  CALL tmp_ej_modelo('LAPTOP', 'DELL', 'LATITUDE 3490');
  CALL tmp_ej_modelo('LAPTOP', 'HP', 'PROBOOK 450 G9');
  CALL tmp_ej_modelo('COMPUTADORA DE ESCRITORIO', 'DELL', 'OPTIPLEX 7010');
  CALL tmp_ej_modelo('COMPUTADORA DE ESCRITORIO', 'DELL', 'OPTIPLEX 3000');
  CALL tmp_ej_modelo('COMPUTADORA DE ESCRITORIO', 'HP', 'PRODESK 400 G7');
  CALL tmp_ej_modelo('COMPUTADORA DE ESCRITORIO', 'LENOVO', 'THINKCENTRE M70S');
  CALL tmp_ej_modelo('TODO EN UNO', 'HP', 'PROONE 440 G9');
  CALL tmp_ej_modelo('MONITOR', 'DELL', 'P2422H');
  CALL tmp_ej_modelo('MONITOR', 'LG', '27MP400');
  CALL tmp_ej_modelo('PRINTER', 'HP', 'LASERJET PRO M404DN');
  CALL tmp_ej_modelo('PRINTER', 'EPSON', 'ECOTANK L3250');
  CALL tmp_ej_modelo('PRINTER/SCANNER', 'RICOH', 'IM 430F');
  CALL tmp_ej_modelo('PRINTER/SCANNER', 'KYOCERA', 'ECOSYS M3655IDN');
  CALL tmp_ej_modelo('PLOTTER', 'HP', 'DESIGNJET T650');
  CALL tmp_ej_modelo('SCANNER', 'FUJITSU', 'FI-8170');
  CALL tmp_ej_modelo('IP PHONE', 'YEALINK', 'T46U');
  CALL tmp_ej_modelo('IP PHONE', 'YEALINK', 'T33G');
  CALL tmp_ej_modelo('IP PHONE', 'GRANDSTREAM', 'GRP2614');
  CALL tmp_ej_modelo('CENTRAL TELEFÓNICA', 'GRANDSTREAM', 'UCM6304');
  CALL tmp_ej_modelo('MOBILE PHONE', 'SAMSUNG', 'GALAXY A54');
  CALL tmp_ej_modelo('MOBILE PHONE', 'SAMSUNG', 'GALAXY A15');
  CALL tmp_ej_modelo('MOBILE PHONE', 'APPLE', 'IPHONE 13');
  CALL tmp_ej_modelo('TABLET', 'SAMSUNG', 'GALAXY TAB A9');
  CALL tmp_ej_modelo('UPS', 'APC', 'SMART-UPS SRT 3000');
  CALL tmp_ej_modelo('UPS', 'CDP', 'R-SMART 1510');
  CALL tmp_ej_modelo('CÁMARA IP', 'HIKVISION', 'DS-2CD2143G2-I');
  CALL tmp_ej_modelo('GRABADOR NVR', 'HIKVISION', 'DS-7608NI-K2');
  CALL tmp_ej_modelo('RELOJ MARCADOR', 'ZKTECO', 'SPEEDFACE V5L');
  CALL tmp_ej_modelo('PROYECTOR', 'EPSON', 'POWERLITE E20');
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL XEON SILVER 4210') THEN CALL sp_procesadores_insertar('INTEL XEON SILVER 4210', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL XEON SILVER 4314') THEN CALL sp_procesadores_insertar('INTEL XEON SILVER 4314', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL CORE I7-1255U') THEN CALL sp_procesadores_insertar('INTEL CORE I7-1255U', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL CORE I5-1335U') THEN CALL sp_procesadores_insertar('INTEL CORE I5-1335U', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL CORE I5-12500') THEN CALL sp_procesadores_insertar('INTEL CORE I5-12500', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL CORE I5-10500') THEN CALL sp_procesadores_insertar('INTEL CORE I5-10500', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL CORE I3-12100') THEN CALL sp_procesadores_insertar('INTEL CORE I3-12100', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'AMD RYZEN 5 5625U') THEN CALL sp_procesadores_insertar('AMD RYZEN 5 5625U', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM procesadores WHERE descripcion = 'INTEL CORE I5-8250U') THEN CALL sp_procesadores_insertar('INTEL CORE I5-8250U', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = '11 PRO 23H2') THEN CALL sp_firmwares_insertar('11 PRO 23H2', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = '10 PRO 22H2') THEN CALL sp_firmwares_insertar('10 PRO 22H2', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'SERVER 2022') THEN CALL sp_firmwares_insertar('SERVER 2022', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'SERVER 2019') THEN CALL sp_firmwares_insertar('SERVER 2019', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'ESXI 8.0 U2') THEN CALL sp_firmwares_insertar('ESXI 8.0 U2', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'DEBIAN 12.7') THEN CALL sp_firmwares_insertar('DEBIAN 12.7', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'DSM 7.2') THEN CALL sp_firmwares_insertar('DSM 7.2', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'ANDROID 14') THEN CALL sp_firmwares_insertar('ANDROID 14', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'IOS 17') THEN CALL sp_firmwares_insertar('IOS 17', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'IOS 17.5') THEN CALL sp_firmwares_insertar('IOS 17.5', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'UBIQUITI 6.6') THEN CALL sp_firmwares_insertar('UBIQUITI 6.6', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM firmwares WHERE descripcion = 'UCM 1.0.27') THEN CALL sp_firmwares_insertar('UCM 1.0.27', @ej_id); END IF;
  IF NOT EXISTS (SELECT 1 FROM edificios WHERE descripcion = 'BIBLIOTECA MUNICIPAL') THEN
    CALL sp_edificios_insertar('BIBLIOTECA MUNICIPAL', 'COSTADO NORTE DEL PARQUE CENTRAL', '10.0729,-84.3118', 'CR', '2', '03', '01', @ej_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM edificios WHERE descripcion = 'CENTRO DE CUIDO TACARES') THEN
    CALL sp_edificios_insertar('CENTRO DE CUIDO TACARES', 'TACARES NORTE, 100 M DE LA ESCUELA', '10.0647,-84.2932', 'CR', '2', '03', '05', @ej_id);
  END IF;
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Modelos, procesadores, versiones y edificios nuevos: ', (SELECT (SELECT COUNT(*) FROM modelos) + (SELECT COUNT(*) FROM procesadores) + (SELECT COUNT(*) FROM firmwares) + (SELECT COUNT(*) FROM edificios)) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                     Funcionarios y usuarios del sistema                      */
/*                                                                              */
/********************************************************************************/
/* 5 entran con clave del sistema; los demás por Active Directory */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM personas WHERE es_proveedor = FALSE);
  CALL tmp_ej_funcionario('901110101', 'ANDREA', 'MORA', 'VARGAS', '01', 'BARRIO LATINO, 100 M NORTE DE LA IGLESIA', 'TECNOLOGÍAS DE INFORMACIÓN', 'ADMINISTRADOR', 'amora', 'pbkdf2_sha256$1000000$oghaG4675ovJG74eOtPrXg$fbgamn+CdOXV97jQiGIfMamh9KgQrhTrUWNQDuDY95Q=', '24950101', '88100101', 'amora@grecia.test');
  CALL tmp_ej_funcionario('901110102', 'CARLOS', 'ALFARO', 'ROJAS', '02', 'SAN ISIDRO CENTRO, FRENTE AL PARQUE', 'TECNOLOGÍAS DE INFORMACIÓN', 'ADMINISTRADOR', 'calfaro', 'pbkdf2_sha256$1000000$vFKMqz201UJMHj9mrLPOPh$2HpKavlFzL2Rodxd7nqalTWBxdpH1HwmlbFkYj8TMzU=', '24950102', '88100102', 'calfaro@grecia.test');
  CALL tmp_ej_funcionario('901110103', 'DANIEL', 'QUESADA', 'SOLÍS', '04', 'SAN ROQUE, 200 M ESTE DE LA ESCUELA', 'TECNOLOGÍAS DE INFORMACIÓN', 'ESTÁNDAR', 'dquesada', 'pbkdf2_sha256$1000000$vsJa108TpafHiqVxBc9ViS$/UQChUtcYHwiSxgHx1lr3NvpaQ116nhkZCPt8BTNgxc=', '24950103', '88100103', 'dquesada@grecia.test');
  CALL tmp_ej_funcionario('901110104', 'MARÍA FERNANDA', 'CHAVES', 'ARAYA', '01', 'URBANIZACIÓN EL CEMENTERIO, CASA 12', 'RECURSOS HUMANOS', 'ESTÁNDAR', 'mchaves', 'pbkdf2_sha256$1000000$xOsHgOXO0zb00I9EYQ05gr$UnmxhJn4+E/TQ4UNlmRM88Bkcp3vtPGHjbSCwmluoxg=', '24950104', '88100104', 'mchaves@grecia.test');
  CALL tmp_ej_funcionario('901110105', 'LAURA', 'SALAS', 'MÉNDEZ', '05', 'TACARES NORTE, CONTIGUO AL SÚPER', 'PROVEEDURÍA', 'ESTÁNDAR', 'lsalas', 'pbkdf2_sha256$1000000$rDpv4NuQOCpd43eVTcpIev$T4NXmcviuFZtcS3X9AFn/Nox3daUz5Mucynoi3F/W60=', '24950105', '88100105', 'lsalas@grecia.test');
  CALL tmp_ej_funcionario('901110106', 'ROBERTO', 'JIMÉNEZ', 'CAMPOS', '01', 'CENTRO DE GRECIA, AVENIDA 2', 'ALCALDÍA MUNICIPAL', 'ESTÁNDAR', 'rjimenez', NULL, '24950106', '88100106', 'rjimenez@grecia.test');
  CALL tmp_ej_funcionario('901110107', 'KATHERINE', 'ROJAS', 'UREÑA', '03', 'SAN JOSÉ DE GRECIA, CALLE PRINCIPAL', 'TESORERÍA', 'ESTÁNDAR', 'krojas', NULL, '24950107', '88100107', 'krojas@grecia.test');
  CALL tmp_ej_funcionario('901110108', 'MARIO', 'CASTRO', 'ZÚÑIGA', '07', 'PUENTE DE PIEDRA, 50 M SUR DEL PUENTE', 'CONTABILIDAD', 'ESTÁNDAR', 'mcastro', NULL, '24950108', '88100108', 'mcastro@grecia.test');
  CALL tmp_ej_funcionario('901110109', 'SOFÍA', 'HERRERA', 'PORRAS', '08', 'BOLÍVAR, FRENTE A LA PLAZA', 'CATASTRO', 'ESTÁNDAR', 'sherrera', NULL, '24950109', '88100109', 'sherrera@grecia.test');
  CALL tmp_ej_funcionario('901110110', 'ESTEBAN', 'MONTERO', 'VEGA', '01', 'BARRIO SAN VICENTE, CASA ESQUINERA', 'INGENIERÍA Y CONTROL URBANO', 'ESTÁNDAR', 'emontero', NULL, '24950110', '88100110', 'emontero@grecia.test');
  CALL tmp_ej_funcionario('901110111', 'PAOLA', 'RODRÍGUEZ', 'CALDERÓN', '02', 'SAN ISIDRO, URBANIZACIÓN LAS FLORES', 'GESTIÓN AMBIENTAL', 'ESTÁNDAR', 'prodriguez', NULL, '24950111', '88100111', 'prodriguez@grecia.test');
  CALL tmp_ej_funcionario('901110112', 'LUIS DIEGO', 'SANABRIA', 'ACUÑA', '04', 'SAN ROQUE, CALLE LOS MANGOS', 'PATENTES', 'ESTÁNDAR', 'lsanabria', NULL, '24950112', '88100112', 'lsanabria@grecia.test');
  CALL tmp_ej_funcionario('901110113', 'NATALIA', 'VILLALOBOS', 'MURILLO', '01', 'CENTRO DE GRECIA, DETRÁS DEL MERCADO', 'PLATAFORMA DE SERVICIOS', 'ESTÁNDAR', 'nvillalobos', NULL, '24950113', '88100113', 'nvillalobos@grecia.test');
  CALL tmp_ej_funcionario('901110114', 'ALONSO', 'CORDERO', 'BRENES', '05', 'TACARES SUR, 300 M OESTE DE LA IGLESIA', 'POLICÍA MUNICIPAL', 'ESTÁNDAR', 'acordero', NULL, '24950114', '88100114', 'acordero@grecia.test');
  CALL tmp_ej_funcionario('901110115', 'FABIÁN', 'ALPÍZAR', 'SOTO', '03', 'SAN JOSÉ DE GRECIA, BARRIO EL PROGRESO', 'SERVICIOS GENERALES', 'ESTÁNDAR', 'falpizar', NULL, '24950115', '88100115', 'falpizar@grecia.test');
  CALL tmp_ej_funcionario('901110116', 'GABRIELA', 'UGALDE', 'MADRIGAL', '07', 'PUENTE DE PIEDRA, CONTIGUO AL TANQUE', 'ACUEDUCTO MUNICIPAL', 'ESTÁNDAR', 'gugalde', NULL, '24950116', '88100116', 'gugalde@grecia.test');
  CALL tmp_ej_funcionario('901110117', 'ISABEL', 'ARAYA', 'LEÓN', '01', 'BARRIO LATINO, CASA 45', 'CONCEJO MUNICIPAL', 'ESTÁNDAR', 'iaraya', NULL, '24950117', '88100117', 'iaraya@grecia.test');
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Funcionarios nuevos: ', (SELECT COUNT(*) FROM personas WHERE es_proveedor = FALSE) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                                 Proveedores                                  */
/*                                                                              */
/********************************************************************************/
/* Empresas que vendieron o dan mantenimiento a los equipos */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM personas WHERE es_proveedor = TRUE);
  CALL tmp_ej_proveedor('3101900101', 'SOLUCIONES TECNOLÓGICAS DEL VALLE S.A.', 'INFORMATICA', '01', 'CENTRO COMERCIAL GRECIA, LOCAL 8', '24960201', 'ventas@solucionesvalle.test', 'https://www.solucionesvalle.test');
  CALL tmp_ej_proveedor('3101900102', 'DISTRIBUIDORA DE CÓMPUTO CENTRAL S.A.', 'INFRAESTRUCTURA EQUIPO DE COMPUTO - SERVERS, WORKSTATIONS, ALMACENAMIENTO E IMPRESORAS', '01', 'AVENIDA CENTRAL, 150 M ESTE DEL BANCO', '24960202', 'cotizaciones@computocentral.test', 'https://www.computocentral.test');
  CALL tmp_ej_proveedor('3101900103', 'SEGURIDAD PERIMETRAL CR S.A.', 'INFRAESTRUCTURA EQUIPO DE RED - FIREWALLS, ROUTERS, SWITCHES', '02', 'SAN ISIDRO, OFICENTRO EL ROBLE', '24960203', 'soporte@perimetralcr.test', 'https://www.perimetralcr.test');
  CALL tmp_ej_proveedor('3101900104', 'TELECOMUNICACIONES IP DE OCCIDENTE S.A.', 'INFRAESTRUCTURA EQUIPO TELEFONICO - CENTRALES IP Y TELEFONOS IP', '04', 'SAN ROQUE, BODEGA 3', '24960204', 'info@telecomip.test', 'https://www.telecomip.test');
  CALL tmp_ej_proveedor('3101900105', 'REDES Y CABLEADO OCCIDENTE S.A.', 'INFRAESTRUCTURA CABLEADO DE RED - COBRE Y FIBRA OPTICA', '05', 'TACARES, CONTIGUO A LA GASOLINERA', '24960205', 'proyectos@cableadooccidente.test', NULL);
  CALL tmp_ej_proveedor('3101900106', 'ENERGÍA Y RESPALDO ELÉCTRICO S.A.', 'SERVICIOS ELECTRICOS', '01', 'BARRIO SAN VICENTE, NAVE 2', '24960206', 'servicio@energiarespaldo.test', NULL);
  CALL tmp_ej_proveedor('3101900107', 'CONECTIVIDAD GRECIA S.A.', 'SERVICIOS DE RED', '03', 'SAN JOSÉ DE GRECIA, EDIFICIO AZUL', '24960207', 'noc@conectividadgrecia.test', 'https://www.conectividadgrecia.test');
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Proveedores nuevos: ', (SELECT COUNT(*) FROM personas WHERE es_proveedor = TRUE) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                            Equipos con su detalle                            */
/*                                                                              */
/********************************************************************************/
/* IP, MAC, líneas, IMEI, herramientas de seguridad y roles de servidor */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM equipos);
  CALL tmp_ej_equipo('X2300SOP7A21C9', 'FIREWALL', 'SOPHOS', 'SOPHOS XGS 2300', 'FW-PALACIO', 'MG-010001', NULL, NULL, NULL, NULL, NULL, NULL, 8, 2, NULL, NULL, NULL, 'SOPHOS FIREWALL OS', 'SFOS 22.0.2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900103', '2024-03-15', '2027-03-15', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.0.1", "interfaz": "LAN"}, {"direccion_ip": "203.0.113.10", "interfaz": "WAN"}]', '[{"direccion_mac": "021AB986B183", "interfaz": "PORT1"}, {"direccion_mac": "026486116FF3", "interfaz": "PORT2"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('JAD2133ASA0K', 'FIREWALL', 'CISCO', 'CISCO ASA', 'FW-RESPALDO', 'MG-010002', NULL, NULL, NULL, NULL, NULL, NULL, 8, NULL, NULL, NULL, NULL, 'CISCO ADAPTIVE SECURITY APPLIANCE SOFTWARE (ASA)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900103', '2019-06-10', '2022-06-10', 'DATO DE EJEMPLO · EQUIPO DE RESPALDO SI FALLA EL SOPHOS', NULL, '[{"direccion_ip": "10.1.0.2", "interfaz": "INSIDE"}]', '[{"direccion_mac": "0251D572A456", "interfaz": "GE0/0"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('FDO2210R4321', 'ROUTER', 'CISCO', 'CISCO 4321', 'RT-ISP-PALACIO', 'MG-010003', NULL, NULL, NULL, NULL, NULL, NULL, 2, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900107', '2021-02-01', '2024-02-01', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.0.254", "interfaz": "GI0/0/0"}, {"direccion_ip": "203.0.113.2", "interfaz": "GI0/0/1"}]', '[{"direccion_mac": "0269E8A6252B", "interfaz": "GI0/0/0"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('SB8200ARR4411', 'MODEM', 'ARRIS', 'SURFBOARD SB8200', 'MODEM-MERCADO', 'MG-010004', NULL, NULL, NULL, NULL, NULL, NULL, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'MERCADO MUNICIPAL', 'OFICINA DE ADMINISTRACIÓN DEL MERCADO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900107', '2023-08-20', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.2.0.1", "interfaz": "LAN"}]', '[{"direccion_mac": "02053EC6847A", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('CN9AHK1920S01', 'SWITCH', 'HP', 'HP 1920S', 'SW-CORE-PALACIO', 'MG-010005', NULL, NULL, NULL, NULL, NULL, NULL, 48, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900103', '2022-05-12', '2027-05-12', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.0.10", "interfaz": "VLAN1"}]', '[{"direccion_mac": "02E04500BC7D", "interfaz": "MGMT"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('QBDG3120P1A01', 'SWITCH', 'DLINK', 'DLINK DGS 3120 48PC', 'SW-PISO1', 'MG-010006', NULL, NULL, NULL, NULL, NULL, NULL, 48, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PRIMER PISO, GABINETE DE PASILLO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2020-11-03', NULL, 'DATO DE EJEMPLO', TRUE, '[{"direccion_ip": "10.1.0.11", "interfaz": "VLAN1"}]', '[{"direccion_mac": "025DDBA60C65", "interfaz": "MGMT"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('QBDG3120P2A02', 'SWITCH', 'DLINK', 'DLINK DGS 3120 48PC', 'SW-PISO2', 'MG-010007', NULL, NULL, NULL, NULL, NULL, NULL, 48, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'SEGUNDO PISO, GABINETE DE PASILLO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2020-11-03', NULL, 'DATO DE EJEMPLO', TRUE, '[{"direccion_ip": "10.1.0.12", "interfaz": "VLAN1"}]', '[{"direccion_mac": "028941C45B70", "interfaz": "MGMT"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('QBDE1200M0301', 'SWITCH', 'DLINK', 'DLINK DES 1200 24PC', 'SW-MERCADO', 'MG-010008', NULL, NULL, NULL, NULL, NULL, NULL, 24, 2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'MERCADO MUNICIPAL', 'OFICINA DE ADMINISTRACIÓN DEL MERCADO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2021-04-22', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.2.0.10", "interfaz": "VLAN1"}]', '[{"direccion_mac": "02488FD937F4", "interfaz": "MGMT"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('CN3226ARB0901', 'SWITCH', 'ARUBA', 'ARUBA 3226', 'SW-PLANTEL', 'MG-010009', NULL, NULL, NULL, NULL, NULL, NULL, 24, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PLANTEL MUNICIPAL', 'BODEGA DEL PLANTEL, RACK DE PARED', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900103', '2023-01-30', '2028-01-30', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.3.0.10", "interfaz": "VLAN1"}]', '[{"direccion_mac": "029009EC92DD", "interfaz": "MGMT"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('U6PRO0A1B2C01', 'ACCESS POINT', 'UBIQUITI', 'U6 PRO', 'AP-PALACIO-P1', 'MG-010010', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, 2, NULL, NULL, NULL, 'UBIQUITI 6.6', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PRIMER PISO, CIELO DEL PASILLO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2024-02-14', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.0.41", "interfaz": "ETH0"}]', '[{"direccion_mac": "02BAD83175F6", "interfaz": "ETH0"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('U6PRO0A1B2C02', 'ACCESS POINT', 'UBIQUITI', 'U6 PRO', 'AP-PALACIO-P2', 'MG-010011', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, 2, NULL, NULL, NULL, 'UBIQUITI 6.6', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'SEGUNDO PISO, SALA DE SESIONES', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2024-02-14', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.0.42", "interfaz": "ETH0"}]', '[{"direccion_mac": "0201C960B0DE", "interfaz": "ETH0"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('U6PRO0A1B2C03', 'ACCESS POINT', 'UBIQUITI', 'U6 PRO', 'AP-MERCADO', 'MG-010012', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, 2, NULL, NULL, NULL, 'UBIQUITI 6.6', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'MERCADO MUNICIPAL', 'PASILLO CENTRAL DEL MERCADO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2024-02-14', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.2.0.41", "interfaz": "ETH0"}]', '[{"direccion_mac": "0295248AAD8C", "interfaz": "ETH0"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('8XK2PR740DC1', 'SERVER', 'DELL', 'POWEREDGE R740', 'SRV-DC01', 'MG-020001', 'INTEL XEON SILVER 4210', 64, 2000, 'SSD', NULL, 4, 4, NULL, NULL, NULL, NULL, 'WINDOWS SERVER', 'SERVER 2022', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900102', '2022-07-01', '2027-07-01', 'DATO DE EJEMPLO · CONTROLADOR DE DOMINIO, DHCP, DNS Y NTP', NULL, '[{"direccion_ip": "10.1.1.10", "interfaz": "LAN"}]', '[{"direccion_mac": "02BEE57157FA", "interfaz": "NIC1"}, {"direccion_mac": "021513096022", "interfaz": "IDRAC"}]', NULL, NULL, '[2, 3, 4, 5]', '[2, 3]');
  CALL tmp_ej_equipo('9JF3PR650AR1', 'SERVER', 'DELL', 'POWEREDGE R650', 'SRV-ARCHIVOS', 'MG-020002', 'INTEL XEON SILVER 4314', 128, 8000, 'HDD', NULL, 4, 4, NULL, NULL, NULL, NULL, 'WINDOWS SERVER', 'SERVER 2019', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900102', '2023-03-20', '2028-03-20', 'DATO DE EJEMPLO · CARPETAS COMPARTIDAS DE LOS DEPARTAMENTOS', NULL, '[{"direccion_ip": "10.1.1.11", "interfaz": "LAN"}]', '[{"direccion_mac": "024AB21719B3", "interfaz": "NIC1"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('CZJ0451DL380', 'SERVER', 'HP', 'PROLIANT DL380 GEN10', 'SRV-SISTEMAS', 'MG-020003', 'INTEL XEON SILVER 4210', 96, 4000, 'SSD', NULL, 4, 4, NULL, NULL, NULL, NULL, 'LINUX DEBIAN 12', 'DEBIAN 12.7', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900102', '2021-09-15', '2026-09-15', 'DATO DE EJEMPLO · SISTEMA TRIBUTARIO Y BASE DE DATOS', NULL, '[{"direccion_ip": "10.1.1.12", "interfaz": "ENO1"}]', '[{"direccion_mac": "02F86DEAF1D6", "interfaz": "ENO1"}]', NULL, NULL, NULL, '[3]');
  CALL tmp_ej_equipo('7HZ8PR740VM1', 'SERVER', 'DELL', 'POWEREDGE R740', 'SRV-VIRTUAL01', 'MG-020004', 'INTEL XEON SILVER 4314', 256, 6000, 'SSD', NULL, 4, 4, NULL, NULL, NULL, NULL, 'VMWARE ESXI', 'ESXI 8.0 U2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900102', '2024-01-10', '2029-01-10', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.1.20", "interfaz": "VMNIC0"}]', '[{"direccion_mac": "02B4CADEDD76", "interfaz": "VMNIC0"}, {"direccion_mac": "02C5B5F8DDA1", "interfaz": "IDRAC"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('2190QBR920NAS', 'NAS', 'SYNOLOGY', 'DS920+', 'NAS-RESPALDOS', 'MG-020005', NULL, 8, 16000, 'HDD', NULL, 2, 2, NULL, NULL, NULL, NULL, NULL, 'DSM 7.2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900102', '2023-03-20', NULL, 'DATO DE EJEMPLO · RESPALDOS DIARIOS DE LOS SERVIDORES', NULL, '[{"direccion_ip": "10.1.1.30", "interfaz": "LAN1"}]', '[{"direccion_mac": "02FB645D2EBF", "interfaz": "LAN1"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('PF3XK7A1', 'LAPTOP', 'LENOVO', 'THINKPAD T14 GEN 3', 'LAP-TI-01', 'MG-030001', 'INTEL CORE I7-1255U', 16, 512, 'NVME', NULL, 3, 1, NULL, 1, 1, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, 14, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'OFICINA DE TI', 2, 'TECNOLOGÍAS DE INFORMACIÓN', '901110101', '3101900101', '2023-05-08', '2026-05-08', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.10", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02F6F50434C5", "interfaz": "ETHERNET"}, {"direccion_mac": "02FB82EDE2B1", "interfaz": "WI-FI"}]', NULL, NULL, NULL, '[2, 3, 4]');
  CALL tmp_ej_equipo('5CG3412LAT5440', 'LAPTOP', 'DELL', 'LATITUDE 5440', 'LAP-TI-02', 'MG-030002', 'INTEL CORE I5-1335U', 16, 512, 'NVME', NULL, 3, 1, NULL, 1, 1, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, 14, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'OFICINA DE TI', 2, 'TECNOLOGÍAS DE INFORMACIÓN', '901110102', '3101900101', '2024-04-02', '2027-04-02', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.11", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02B00E692E5E", "interfaz": "ETHERNET"}, {"direccion_mac": "02D99D684F80", "interfaz": "WI-FI"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('5CD2049PB450', 'LAPTOP', 'HP', 'PROBOOK 450 G9', 'LAP-TI-03', 'MG-030003', 'INTEL CORE I5-1335U', 16, 512, 'NVME', NULL, 3, 1, NULL, 1, 1, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, 15.6, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'OFICINA DE TI', 2, 'TECNOLOGÍAS DE INFORMACIÓN', '901110103', '3101900101', '2023-05-08', '2026-05-08', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.12", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "0228A4D73758", "interfaz": "ETHERNET"}, {"direccion_mac": "0237671C7F6E", "interfaz": "WI-FI"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('7MTX3K3OPT01', 'COMPUTADORA DE ESCRITORIO', 'DELL', 'OPTIPLEX 7010', 'PC-RRHH-01', 'MG-030004', 'INTEL CORE I5-12500', 16, 512, 'SSD', NULL, 6, 1, NULL, NULL, NULL, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'RECURSOS HUMANOS, ESCRITORIO 1', 2, 'RECURSOS HUMANOS', '901110104', '3101900102', '2023-10-11', '2026-10-11', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.20", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02C121FDC8B7", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('MXL1092PD400', 'COMPUTADORA DE ESCRITORIO', 'HP', 'PRODESK 400 G7', 'PC-PROV-01', 'MG-030005', 'INTEL CORE I5-10500', 8, 256, 'SSD', NULL, 6, 1, NULL, NULL, NULL, NULL, 'WINDOWS', '10 PRO 22H2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PROVEEDURÍA', 2, 'PROVEEDURÍA', '901110105', '3101900102', '2021-03-18', '2024-03-18', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.21", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "028A1A42A451", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('7MTX3K3OPT02', 'COMPUTADORA DE ESCRITORIO', 'DELL', 'OPTIPLEX 7010', 'PC-TESO-01', 'MG-030006', 'INTEL CORE I5-12500', 16, 512, 'SSD', NULL, 6, 1, NULL, NULL, NULL, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'TESORERÍA, CAJA 1', 2, 'TESORERÍA', '901110107', '3101900102', '2023-10-11', '2026-10-11', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.22", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02EC3FE4682F", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, '[2, 3, 4]');
  CALL tmp_ej_equipo('S1H0M70SLN01', 'COMPUTADORA DE ESCRITORIO', 'LENOVO', 'THINKCENTRE M70S', 'PC-CONTA-01', 'MG-030007', 'INTEL CORE I5-12500', 16, 512, 'SSD', NULL, 6, 1, NULL, NULL, NULL, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CONTABILIDAD', 2, 'CONTABILIDAD', '901110108', '3101900101', '2024-06-03', '2027-06-03', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.23", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02EE510582AD", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, '[2]');
  CALL tmp_ej_equipo('4QWZ3000OPT03', 'COMPUTADORA DE ESCRITORIO', 'DELL', 'OPTIPLEX 3000', 'PC-CATA-01', 'MG-030008', 'INTEL CORE I3-12100', 8, 256, 'SSD', NULL, 6, 1, NULL, NULL, NULL, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CATASTRO, MESA DE PLANOS', 2, 'CATASTRO', '901110109', '3101900102', '2022-08-25', '2025-08-25', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.24", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02063A2AAB37", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('4QWZ3000OPT04', 'COMPUTADORA DE ESCRITORIO', 'DELL', 'OPTIPLEX 3000', 'PC-INGE-01', 'MG-030009', 'INTEL CORE I5-12500', 32, 1000, 'SSD', NULL, 6, 1, NULL, NULL, NULL, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'INGENIERÍA, ESCRITORIO 2', 2, 'INGENIERÍA Y CONTROL URBANO', '901110110', '3101900102', '2022-08-25', '2025-08-25', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.25", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02F89C1015DA", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('8CC3201PO440', 'TODO EN UNO', 'HP', 'PROONE 440 G9', 'PC-PLAT-01', 'MG-030010', 'INTEL CORE I5-12500', 16, 512, 'SSD', NULL, 5, 1, NULL, 1, 1, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, 23.8, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PLATAFORMA DE SERVICIOS, VENTANILLA 1', 2, 'PLATAFORMA DE SERVICIOS', '901110113', '3101900101', '2024-02-20', '2027-02-20', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.26", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "0241A514E8B9", "interfaz": "ETHERNET"}, {"direccion_mac": "02A7E39EB2BC", "interfaz": "WI-FI"}]', NULL, NULL, NULL, '[2, 3]');
  CALL tmp_ej_equipo('PF4E14LNV01', 'LAPTOP', 'LENOVO', 'THINKPAD E14', 'LAP-ALCA-01', 'MG-030011', 'AMD RYZEN 5 5625U', 16, 512, 'NVME', NULL, 3, 1, NULL, 1, 1, NULL, 'WINDOWS', '11 PRO 23H2', NULL, NULL, NULL, NULL, 14, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'DESPACHO DE LA ALCALDÍA', 2, 'ALCALDÍA MUNICIPAL', '901110106', '3101900101', '2023-01-16', '2026-01-16', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.11.27", "interfaz": "WI-FI"}]', '[{"direccion_mac": "02957E1D053B", "interfaz": "ETHERNET"}, {"direccion_mac": "029A51EDAEF5", "interfaz": "WI-FI"}]', NULL, NULL, NULL, '[2, 3, 4]');
  CALL tmp_ej_equipo('9VTC3490LAT', 'LAPTOP', 'DELL', 'LATITUDE 3490', 'LAP-PATE-01', 'MG-030012', 'INTEL CORE I5-8250U', 8, 256, 'SSD', NULL, 3, 1, NULL, 1, 1, NULL, 'WINDOWS', '10 PRO 22H2', NULL, NULL, NULL, NULL, 14, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PATENTES', 2, 'PATENTES', '901110112', '3101900101', '2018-07-09', '2021-07-09', 'DATO DE EJEMPLO', NULL, NULL, '[{"direccion_mac": "029DF0763763", "interfaz": "ETHERNET"}, {"direccion_mac": "0228DB7F2FDC", "interfaz": "WI-FI"}]', NULL, NULL, NULL, '[2]');
  CALL tmp_ej_equipo('CN0P2422HD01', 'MONITOR', 'DELL', 'P2422H', 'MON-INGE-01', 'MG-030013', NULL, NULL, NULL, NULL, NULL, 4, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 24, '1920X1080', NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'INGENIERÍA, ESCRITORIO 2', 2, 'INGENIERÍA Y CONTROL URBANO', '901110110', '3101900102', '2022-08-25', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('104NTKF27MP01', 'MONITOR', 'LG', '27MP400', 'MON-CATA-01', 'MG-030014', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 27, '1920X1080', NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CATASTRO, MESA DE PLANOS', 2, 'CATASTRO', '901110109', '3101900102', '2022-08-25', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('PHBQK04DN01', 'PRINTER', 'HP', 'LASERJET PRO M404DN', 'IMP-TESO-01', 'MG-040001', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'LÁSER', FALSE, 'TÓNER HP 58A', NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'TESORERÍA', 2, 'TESORERÍA', NULL, '3101900102', '2022-02-10', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.20.10", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "029FB9189369", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('X8NY032501', 'PRINTER', 'EPSON', 'ECOTANK L3250', 'IMP-RRHH-01', 'MG-040002', NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, 'TINTA CONTINUA', TRUE, 'TINTA EPSON 544', NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'RECURSOS HUMANOS', 2, 'RECURSOS HUMANOS', NULL, '3101900102', '2023-06-01', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.20.11", "interfaz": "WI-FI"}]', '[{"direccion_mac": "028FC5AC592C", "interfaz": "WI-FI"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('3110R430F001', 'PRINTER/SCANNER', 'RICOH', 'IM 430F', 'MF-PLAT-01', 'MG-040003', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'LÁSER', FALSE, 'TÓNER RICOH IM 430', NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PLATAFORMA DE SERVICIOS', 2, 'PLATAFORMA DE SERVICIOS', NULL, '3101900102', '2023-09-14', '2026-09-14', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.20.20", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "0259537D4512", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('R4P3655KY01', 'PRINTER/SCANNER', 'KYOCERA', 'ECOSYS M3655IDN', 'MF-PROV-01', 'MG-040004', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'LÁSER', FALSE, 'TÓNER KYOCERA TK-3182', NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PROVEEDURÍA', 2, 'PROVEEDURÍA', NULL, '3101900102', '2021-11-30', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.20.21", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "02441CCE26AF", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('CN2T650DJ01', 'PLOTTER', 'HP', 'DESIGNJET T650', 'PLT-INGE-01', 'MG-040005', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, 1, NULL, NULL, NULL, NULL, NULL, 'TINTA', TRUE, 'CARTUCHOS HP 712', NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'INGENIERÍA', 2, 'INGENIERÍA Y CONTROL URBANO', NULL, '3101900102', '2022-04-05', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.20.30", "interfaz": "ETHERNET"}]', '[{"direccion_mac": "0286FC193D51", "interfaz": "ETHERNET"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('A1FI8170CAT', 'SCANNER', 'FUJITSU', 'FI-8170', 'ESC-CATA-01', 'MG-040006', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CATASTRO', 2, 'CATASTRO', NULL, '3101900102', '2023-02-27', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('801T46U00101', 'IP PHONE', 'YEALINK', 'T46U', 'TEL-2101', 'MG-050001', NULL, NULL, NULL, NULL, NULL, NULL, 2, NULL, NULL, NULL, NULL, NULL, NULL, '2101', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'DESPACHO DE LA ALCALDÍA', 2, 'ALCALDÍA MUNICIPAL', '901110106', '3101900104', '2022-10-03', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.30.101", "interfaz": "LAN"}]', '[{"direccion_mac": "02F7FA4C5FA2", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('GRP2614A0205', 'IP PHONE', 'GRANDSTREAM', 'GRP2614', 'TEL-2205', 'MG-050002', NULL, NULL, NULL, NULL, NULL, NULL, 2, NULL, NULL, NULL, NULL, NULL, NULL, '2205', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'RECURSOS HUMANOS', 2, 'RECURSOS HUMANOS', '901110104', '3101900104', '2022-10-03', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.30.105", "interfaz": "LAN"}]', '[{"direccion_mac": "02499FFA30F7", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('801T33G00310', 'IP PHONE', 'YEALINK', 'T33G', 'TEL-2310', 'MG-050003', NULL, NULL, NULL, NULL, NULL, NULL, 2, NULL, NULL, NULL, NULL, NULL, NULL, '2310', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PLATAFORMA DE SERVICIOS, VENTANILLA 1', 2, 'PLATAFORMA DE SERVICIOS', '901110113', '3101900104', '2022-10-03', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.30.110", "interfaz": "LAN"}]', '[{"direccion_mac": "02AF179BF3A8", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('UCM6304GS001', 'CENTRAL TELEFÓNICA', 'GRANDSTREAM', 'UCM6304', 'PBX-PALACIO', 'MG-050004', NULL, NULL, NULL, NULL, NULL, 2, 2, NULL, NULL, NULL, NULL, NULL, 'UCM 1.0.27', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900104', '2022-10-03', '2025-10-03', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.1.40", "interfaz": "LAN"}]', '[{"direccion_mac": "0265638EA88E", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('R58W10A54GR', 'MOBILE PHONE', 'SAMSUNG', 'GALAXY A54', 'CEL-ALCALDIA', 'MG-060001', NULL, 8, 256, 'EMMC', NULL, 1, NULL, NULL, 1, 1, 2, 'ANDROID', 'ANDROID 14', NULL, NULL, NULL, NULL, 6.4, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'DESPACHO DE LA ALCALDÍA', 2, 'ALCALDÍA MUNICIPAL', '901110106', '3101900101', '2024-01-22', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, '[{"num_movil": "8810-2001", "operador": "KÖLBI"}]', '[{"dir_imei": "356938035643809"}, {"dir_imei": "356938035643817"}]', NULL, NULL);
  CALL tmp_ej_equipo('F2LXQ13IPH', 'MOBILE PHONE', 'APPLE', 'IPHONE 13', 'CEL-JEFATURA-TI', 'MG-060002', NULL, 4, 128, NULL, NULL, 1, NULL, NULL, 1, 1, 1, 'IOS', 'IOS 17.5', NULL, NULL, NULL, NULL, 6.1, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'OFICINA DE TI', 2, 'TECNOLOGÍAS DE INFORMACIÓN', '901110101', '3101900101', '2023-03-01', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, '[{"num_movil": "8810-2002", "operador": "KÖLBI"}]', '[{"dir_imei": "353322114455661"}, {"dir_imei": "353322114455679"}]', NULL, NULL);
  CALL tmp_ej_equipo('R58X20A15PM', 'MOBILE PHONE', 'SAMSUNG', 'GALAXY A15', 'CEL-POLICIA-01', 'MG-060003', NULL, 4, 128, 'EMMC', NULL, 1, NULL, NULL, 1, 1, 2, 'ANDROID', 'ANDROID 14', NULL, NULL, NULL, NULL, 6.5, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'PATRULLA 2', 2, 'POLICÍA MUNICIPAL', '901110114', '3101900101', '2024-07-15', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, '[{"num_movil": "8810-2003", "operador": "CLARO"}]', '[{"dir_imei": "351009771234560"}]', NULL, NULL);
  CALL tmp_ej_equipo('R9TW30TABA9', 'TABLET', 'SAMSUNG', 'GALAXY TAB A9', 'TAB-AMBIENTE-01', 'MG-060004', NULL, 4, 64, 'EMMC', NULL, 1, NULL, NULL, 1, 1, 1, 'ANDROID', 'ANDROID 14', NULL, NULL, NULL, NULL, 8.7, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'GESTIÓN AMBIENTAL, INSPECCIONES DE CAMPO', 2, 'GESTIÓN AMBIENTAL', '901110111', '3101900101', '2024-05-06', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, '[{"num_movil": "8810-2004", "operador": "LIBERTY"}]', '[{"dir_imei": "354876120098715"}]', NULL, NULL);
  CALL tmp_ej_equipo('AS2245SRT3K1', 'UPS', 'APC', 'SMART-UPS SRT 3000', 'UPS-RACK1', 'MG-070001', NULL, NULL, NULL, NULL, NULL, 1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 3000, 25, NULL, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900106', '2022-07-01', '2025-07-01', 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.0.50", "interfaz": "NMC"}]', '[{"direccion_mac": "02CD1367223E", "interfaz": "NMC"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('CDP1510RS088', 'UPS', 'CDP', 'R-SMART 1510', 'UPS-PLATAFORMA', 'MG-070002', NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1500, 10, NULL, 'PALACIO MUNICIPAL', 'PLATAFORMA DE SERVICIOS', 2, 'PLATAFORMA DE SERVICIOS', NULL, '3101900106', '2023-04-17', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('HKDS2143PAL1', 'CÁMARA IP', 'HIKVISION', 'DS-2CD2143G2-I', 'CAM-PALACIO-ENTRADA', 'MG-080001', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'ENTRADA PRINCIPAL DEL PALACIO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2023-11-08', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.40.11", "interfaz": "LAN"}]', '[{"direccion_mac": "0290F2FDDD57", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('HKDS2143MER1', 'CÁMARA IP', 'HIKVISION', 'DS-2CD2143G2-I', 'CAM-MERCADO-NORTE', 'MG-080002', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'MERCADO MUNICIPAL', 'ENTRADA NORTE DEL MERCADO', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2023-11-08', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.2.40.11", "interfaz": "LAN"}]', '[{"direccion_mac": "0238EBE665AB", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('HKDS2143PLA1', 'CÁMARA IP', 'HIKVISION', 'DS-2CD2143G2-I', 'CAM-PLANTEL-PORTON', 'MG-080003', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PLANTEL MUNICIPAL', 'PORTÓN DE VEHÍCULOS', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2023-11-08', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.3.40.11", "interfaz": "LAN"}]', '[{"direccion_mac": "024E549C6547", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('HKDS7608NVR1', 'GRABADOR NVR', 'HIKVISION', 'DS-7608NI-K2', 'NVR-PALACIO', 'MG-080004', NULL, NULL, 4000, 'HDD', NULL, 2, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 8, 'PALACIO MUNICIPAL', 'CUARTO DE SERVIDORES, RACK 1', 2, 'TECNOLOGÍAS DE INFORMACIÓN', NULL, '3101900105', '2023-11-08', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.40.2", "interfaz": "LAN"}]', '[{"direccion_mac": "0269A7F5A018", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('ZKSFV5L00019', 'RELOJ MARCADOR', 'ZKTECO', 'SPEEDFACE V5L', 'RELOJ-PALACIO', 'MG-080005', NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'ENTRADA DE FUNCIONARIOS', 2, 'RECURSOS HUMANOS', NULL, '3101900101', '2024-03-04', NULL, 'DATO DE EJEMPLO', NULL, '[{"direccion_ip": "10.1.40.50", "interfaz": "LAN"}]', '[{"direccion_mac": "02A3FBFDF3F0", "interfaz": "LAN"}]', NULL, NULL, NULL, NULL);
  CALL tmp_ej_equipo('X4PLE20CONC1', 'PROYECTOR', 'EPSON', 'POWERLITE E20', 'PROY-CONCEJO', 'MG-080006', NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '1024X768', NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'SALA DE SESIONES DEL CONCEJO', 2, 'CONCEJO MUNICIPAL', NULL, '3101900102', '2022-12-12', NULL, 'DATO DE EJEMPLO', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Equipos nuevos: ', (SELECT COUNT(*) FROM equipos) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                        Historial: cambios y una baja                         */
/*                                                                              */
/********************************************************************************/
/* Una laptop vieja pasa a otro funcionario y después se da de baja; una impresora cambia de lugar */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM aud_auditorias WHERE tabla = 'equipos' AND accion <> 'INSERTAR');
  IF (SELECT id_estado FROM equipos WHERE id = fn_ej_equipo('9VTC3490LAT')) = 2 THEN
    CALL tmp_ej_cambio('9VTC3490LAT', 'LAPTOP', 'DELL', 'LATITUDE 3490', 'LAP-PATE-01', 'MG-030012', 'INTEL CORE I5-8250U', 8, 256, 'SSD', NULL, 3, 1, NULL, 1, 1, NULL, 'WINDOWS', '10 PRO 22H2', NULL, NULL, NULL, NULL, 14, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'SERVICIOS GENERALES', 2, 'SERVICIOS GENERALES', '901110115', '3101900101', '2018-07-09', '2021-07-09', 'DATO DE EJEMPLO · SE PASÓ A SERVICIOS GENERALES: LA BATERÍA YA NO CARGA', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
    CALL sp_equipos_eliminar(fn_ej_equipo('9VTC3490LAT'));
  END IF;
  IF (SELECT ubicacion FROM equipos WHERE id = fn_ej_equipo('X8NY032501')) = 'RECURSOS HUMANOS' THEN
    CALL tmp_ej_cambio('X8NY032501', 'PRINTER', 'EPSON', 'ECOTANK L3250', 'IMP-RRHH-01', 'MG-040002', NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, 1, NULL, NULL, NULL, NULL, NULL, 'TINTA CONTINUA', TRUE, 'TINTA EPSON 544', NULL, NULL, NULL, NULL, NULL, 'PALACIO MUNICIPAL', 'RECURSOS HUMANOS, ARCHIVO', 2, 'RECURSOS HUMANOS', NULL, '3101900102', '2023-06-01', NULL, 'DATO DE EJEMPLO · SE PASÓ AL ARCHIVO DE RECURSOS HUMANOS', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  END IF;
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Cambios nuevos en el historial: ', (SELECT COUNT(*) FROM aud_auditorias WHERE tabla = 'equipos' AND accion <> 'INSERTAR') - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                           Puertos de los switches                            */
/*                                                                              */
/********************************************************************************/
/* Qué equipo está conectado en cada puerto, su VLAN y los puertos fuera de uso */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM puertos_switch);
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 1, 'X2300SOP7A21C9', NULL, '1', 'ENLACE LAN DEL FIREWALL');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 2, '8XK2PR740DC1', NULL, '10', 'SERVIDOR DE DOMINIO');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 3, '9JF3PR650AR1', NULL, '10', 'SERVIDOR DE ARCHIVOS');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 4, 'CZJ0451DL380', NULL, '10', 'SISTEMA TRIBUTARIO');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 5, '7HZ8PR740VM1', NULL, '10', 'HOST DE VIRTUALIZACIÓN');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 6, '2190QBR920NAS', NULL, '10', 'RESPALDOS');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 7, 'UCM6304GS001', NULL, '30', 'CENTRAL TELEFÓNICA');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 8, 'AS2245SRT3K1', NULL, '1', 'TARJETA DE RED DE LA UPS');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 9, 'HKDS7608NVR1', NULL, '40', 'GRABADOR DE CÁMARAS');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 10, 'FDO2210R4321', NULL, '1', 'ROUTER DEL PROVEEDOR DE INTERNET');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'T', 24, NULL, 'DANADO', NULL, 'NO ENCIENDE EL LED DE ENLACE');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'F', 1, 'QBDG3120P1A01', NULL, '1,10,20,30,40', 'TRONCAL POR FIBRA AL PRIMER PISO');
  CALL tmp_ej_puerto('CN9AHK1920S01', 'F', 2, 'QBDG3120P2A02', NULL, '1,10,20,30,40', 'TRONCAL POR FIBRA AL SEGUNDO PISO');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 1, '7MTX3K3OPT01', NULL, '20', 'RECURSOS HUMANOS');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 2, 'MXL1092PD400', NULL, '20', 'PROVEEDURÍA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 3, '7MTX3K3OPT02', NULL, '20', 'TESORERÍA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 4, 'PHBQK04DN01', NULL, '20', 'IMPRESORA DE TESORERÍA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 5, '3110R430F001', NULL, '20', 'MULTIFUNCIONAL DE PLATAFORMA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 6, '8CC3201PO440', NULL, '20', 'PLATAFORMA VENTANILLA 1');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 7, 'GRP2614A0205', NULL, '30', 'TELÉFONO DE RECURSOS HUMANOS');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 8, '801T33G00310', NULL, '30', 'TELÉFONO DE PLATAFORMA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 9, 'U6PRO0A1B2C01', NULL, '1', 'ACCESS POINT DEL PRIMER PISO');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 10, 'ZKSFV5L00019', NULL, '40', 'RELOJ MARCADOR');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 11, 'HKDS2143PAL1', NULL, '40', 'CÁMARA DE LA ENTRADA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'T', 20, NULL, 'DESHABILITADO', NULL, 'OFICINA DESOCUPADA');
  CALL tmp_ej_puerto('QBDG3120P1A01', 'F', 1, 'CN9AHK1920S01', NULL, '1,10,20,30,40', 'TRONCAL POR FIBRA AL SWITCH CENTRAL');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 1, 'S1H0M70SLN01', NULL, '20', 'CONTABILIDAD');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 2, '4QWZ3000OPT03', NULL, '20', 'CATASTRO');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 3, '4QWZ3000OPT04', NULL, '20', 'INGENIERÍA');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 4, 'CN2T650DJ01', NULL, '20', 'PLOTTER DE INGENIERÍA');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 5, 'R4P3655KY01', NULL, '20', 'MULTIFUNCIONAL DE PROVEEDURÍA');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 6, '801T46U00101', NULL, '30', 'TELÉFONO DE LA ALCALDÍA');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'T', 7, 'U6PRO0A1B2C02', NULL, '1', 'ACCESS POINT DEL SEGUNDO PISO');
  CALL tmp_ej_puerto('QBDG3120P2A02', 'F', 1, 'CN9AHK1920S01', NULL, '1,10,20,30,40', 'TRONCAL POR FIBRA AL SWITCH CENTRAL');
  CALL tmp_ej_puerto('QBDE1200M0301', 'T', 1, 'SB8200ARR4411', NULL, '1', 'MODEM DEL MERCADO');
  CALL tmp_ej_puerto('QBDE1200M0301', 'T', 2, 'U6PRO0A1B2C03', NULL, '1', 'ACCESS POINT DEL MERCADO');
  CALL tmp_ej_puerto('QBDE1200M0301', 'T', 3, 'HKDS2143MER1', NULL, '40', 'CÁMARA NORTE');
  CALL tmp_ej_puerto('CN3226ARB0901', 'T', 1, 'HKDS2143PLA1', NULL, '40', 'CÁMARA DEL PORTÓN');
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Puertos nuevos: ', (SELECT COUNT(*) FROM puertos_switch) - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                   Historial: un funcionario que se retiró                    */
/*                                                                              */
/********************************************************************************/
/* Se desactiva el funcionario que tenía la laptop dada de baja: queda en el sistema como inactivo y en la auditoría */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM aud_auditorias WHERE tabla = 'personas' AND accion = 'ACTUALIZAR');
  IF (SELECT activo FROM personas WHERE id = fn_ej_persona('901110115')) = TRUE
     AND NOT EXISTS (SELECT 1 FROM aud_auditorias WHERE tabla = 'personas' AND accion = 'ACTUALIZAR'
                      AND llave = CAST(fn_ej_persona('901110115') AS CHAR)) THEN
    CALL sp_personas_eliminar(fn_ej_persona('901110115'));
  END IF;
  SELECT '***********************************************************************************************' AS ''
   UNION ALL SELECT CONCAT('¡Cambios nuevos en el historial de personas: ', (SELECT COUNT(*) FROM aud_auditorias WHERE tabla = 'personas' AND accion = 'ACTUALIZAR') - v_antes, '!')
   UNION ALL SELECT '***********************************************************************************************';
END $$
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                     Borrar los procedimientos auxiliares                     */
/*                                                                              */
/********************************************************************************/
DROP PROCEDURE IF EXISTS tmp_ej_funcionario;
DROP PROCEDURE IF EXISTS tmp_ej_proveedor;
DROP PROCEDURE IF EXISTS tmp_ej_modelo;
DROP PROCEDURE IF EXISTS tmp_ej_equipo;
DROP PROCEDURE IF EXISTS tmp_ej_cambio;
DROP PROCEDURE IF EXISTS tmp_ej_puerto;
DROP FUNCTION IF EXISTS fn_ej_modelo;
DROP FUNCTION IF EXISTS fn_ej_marca;
DROP FUNCTION IF EXISTS fn_ej_tipo;
DROP FUNCTION IF EXISTS fn_ej_equipo;
DROP FUNCTION IF EXISTS fn_ej_persona;
DROP FUNCTION IF EXISTS fn_ej_depto;
SET @muni_sin_auditoria = 0;

SELECT CONCAT_WS(' | ',
  CONCAT((SELECT COUNT(*) FROM personas WHERE es_proveedor = FALSE), ' personas'),
  CONCAT((SELECT COUNT(*) FROM personas WHERE es_proveedor = TRUE), ' proveedores'),
  CONCAT((SELECT COUNT(*) FROM equipos), ' equipos'),
  CONCAT((SELECT COUNT(*) FROM dir_ips), ' IP'),
  CONCAT((SELECT COUNT(*) FROM dir_macs), ' MAC'),
  CONCAT((SELECT COUNT(*) FROM puertos_switch), ' puertos'),
  CONCAT((SELECT COUNT(*) FROM aud_auditorias), ' registros de historial')) AS 'Así quedó la base';
