-- =====================================================================
--  poblarDatosEjemplo.sql - datos de ejemplo del módulo de usuarios y
--  proveedores - gestion_redes (MariaDB 10.3 o superior)
-- ---------------------------------------------------------------------
--  Llena las tablas del módulo con datos de ejemplo de la Municipalidad
--  de Grecia:
--    - 17 departamentos
--    - 17 funcionarios con teléfono de oficina, celular y correo:
--      5 entran con clave del sistema (ver la clave en la entrega) y
--      los demás por Active Directory; uno queda inactivo
--    - 7 proveedores con teléfono, correo y página web
--  Todo pasa por los procedimientos del sistema: se valida igual que en
--  la página y queda en la auditoría como «CARGA DE DATOS DE EJEMPLO».
--  Las cédulas empiezan en 9 y los correos son del dominio grecia.test,
--  que no existe: no son de personas reales.
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
/*               Revisar que la base tenga las tablas del módulo                */
/*                                                                              */
/********************************************************************************/
DELIMITER $$
BEGIN NOT ATOMIC
  IF NOT EXISTS (SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'personas') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La base no tiene las tablas del módulo: ejecute primero reinstalar_base.sh.';
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
DELIMITER ;

/********************************************************************************/
/*                                                                              */
/*                      Departamentos de la municipalidad                       */
/*                                                                              */
/********************************************************************************/
/* Los departamentos a los que pertenecen los funcionarios */
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
/*                     Funcionarios y usuarios del sistema                      */
/*                                                                              */
/********************************************************************************/
/* 5 entran con clave del sistema; los demás por Active Directory */
SET @muni_sin_auditoria = 0;
DELIMITER $$
BEGIN NOT ATOMIC
  DECLARE v_antes INT DEFAULT (SELECT COUNT(*) FROM personas WHERE es_proveedor = FALSE);
  CALL tmp_ej_funcionario('901110101', 'ANDREA', 'MORA', 'VARGAS', '01', 'BARRIO LATINO, 100 M NORTE DE LA IGLESIA', 'TECNOLOGÍAS DE INFORMACIÓN', 'ADMINISTRADOR', 'amora', 'pbkdf2_sha256$1000000$Bg6MChQ1nl4MnqKcXUigrT$hTaweLT8o7jKAuKIHqlwiGtwPT9oy+5VJfekEIagois=', '24950101', '88100101', 'amora@grecia.test');
  CALL tmp_ej_funcionario('901110102', 'CARLOS', 'ALFARO', 'ROJAS', '02', 'SAN ISIDRO CENTRO, FRENTE AL PARQUE', 'TECNOLOGÍAS DE INFORMACIÓN', 'ADMINISTRADOR', 'calfaro', 'pbkdf2_sha256$1000000$htt6v2BgVYqWwrAaKTo9Cp$NOymsZpOwJeiEgrlwDcy31mfcDCpy43w2nczy5T3DCI=', '24950102', '88100102', 'calfaro@grecia.test');
  CALL tmp_ej_funcionario('901110103', 'DANIEL', 'QUESADA', 'SOLÍS', '04', 'SAN ROQUE, 200 M ESTE DE LA ESCUELA', 'TECNOLOGÍAS DE INFORMACIÓN', 'ESTÁNDAR', 'dquesada', 'pbkdf2_sha256$1000000$3K0MZKpAjV2DTLxGU32BsR$xt3xT6m0QdWgeIpaC1vGPcBzR7eIokKoZUcadUqL3E0=', '24950103', '88100103', 'dquesada@grecia.test');
  CALL tmp_ej_funcionario('901110104', 'MARÍA FERNANDA', 'CHAVES', 'ARAYA', '01', 'URBANIZACIÓN EL CEMENTERIO, CASA 12', 'RECURSOS HUMANOS', 'ESTÁNDAR', 'mchaves', 'pbkdf2_sha256$1000000$zatEJd9hWk7Fc2AZ2jymJw$LiCwQAXXLFE3sFZw8ZzIBN6U1AWvooJN1Q4d9BPPcQM=', '24950104', '88100104', 'mchaves@grecia.test');
  CALL tmp_ej_funcionario('901110105', 'LAURA', 'SALAS', 'MÉNDEZ', '05', 'TACARES NORTE, CONTIGUO AL SÚPER', 'PROVEEDURÍA', 'ESTÁNDAR', 'lsalas', 'pbkdf2_sha256$1000000$cCAKFbYHfZGAKK58vciIOn$/Hgb2P6APNHbK/uBddRYDlROsBVhDi1X1CacoWBJ150=', '24950105', '88100105', 'lsalas@grecia.test');
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
/* Empresas que le venden o dan servicios a la municipalidad */
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
/*                   Historial: un funcionario que se retiró                    */
/*                                                                              */
/********************************************************************************/
/* Se desactiva un funcionario: queda en el sistema como inactivo y en la auditoría */
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
   UNION ALL SELECT CONCAT('¡Cambios nuevos en el historial: ', (SELECT COUNT(*) FROM aud_auditorias WHERE tabla = 'personas' AND accion = 'ACTUALIZAR') - v_antes, '!')
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
DROP FUNCTION IF EXISTS fn_ej_persona;
DROP FUNCTION IF EXISTS fn_ej_depto;
SET @muni_sin_auditoria = 0;

SELECT CONCAT_WS(' | ',
  CONCAT((SELECT COUNT(*) FROM personas WHERE es_proveedor = FALSE), ' funcionarios'),
  CONCAT((SELECT COUNT(*) FROM personas WHERE es_proveedor = TRUE), ' proveedores'),
  CONCAT((SELECT COUNT(*) FROM usr_telefonos), ' teléfonos'),
  CONCAT((SELECT COUNT(*) FROM usr_correos), ' correos'),
  CONCAT((SELECT COUNT(*) FROM aud_auditorias), ' registros de historial')) AS 'Así quedó la base';
