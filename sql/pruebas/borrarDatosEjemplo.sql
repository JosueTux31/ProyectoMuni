-- =====================================================================
--  borrarDatosEjemplo.sql - quita los datos de poblarDatosEjemplo.sql
--  gestion_redes (MariaDB 10.3 o superior)
-- ---------------------------------------------------------------------
--  Borra definitivamente los equipos que tienen «DATO DE EJEMPLO» en
--  observaciones (con sus IP, MAC, líneas, IMEI, herramientas, roles y
--  puertos), los funcionarios y proveedores de ejemplo (con sus
--  teléfonos, correos y claves).
--  Los departamentos, la geografía y los catálogos se quedan: sirven
--  igual para los datos reales. El historial también se queda.
--  Uso:  mariadb -u admin_db -p < pruebas/borrarDatosEjemplo.sql
-- =====================================================================

USE gestion_redes;
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;
SET @muni_usuario_id = NULL, @muni_usuario_nombre = 'CARGA DE DATOS DE EJEMPLO', @muni_ip = '127.0.0.1';

SELECT COUNT(*) AS equipos_de_ejemplo_que_se_borran FROM equipos WHERE observaciones LIKE '%DATO DE EJEMPLO%';
DELETE FROM puertos_switch WHERE id_equipo IN (SELECT id FROM equipos WHERE observaciones LIKE '%DATO DE EJEMPLO%');
DELETE FROM equipos WHERE observaciones LIKE '%DATO DE EJEMPLO%';
SELECT COUNT(*) AS personas_de_ejemplo_que_se_borran FROM personas WHERE dni IN ('901110101', '901110102', '901110103', '901110104', '901110105', '901110106', '901110107', '901110108', '901110109', '901110110', '901110111', '901110112', '901110113', '901110114', '901110115', '901110116', '901110117', '3101900101', '3101900102', '3101900103', '3101900104', '3101900105', '3101900106', '3101900107');
UPDATE equipos SET id_usuario = NULL WHERE id_usuario IN (SELECT id FROM personas WHERE dni IN ('901110101', '901110102', '901110103', '901110104', '901110105', '901110106', '901110107', '901110108', '901110109', '901110110', '901110111', '901110112', '901110113', '901110114', '901110115', '901110116', '901110117', '3101900101', '3101900102', '3101900103', '3101900104', '3101900105', '3101900106', '3101900107'));
UPDATE equipos SET id_proveedor = NULL WHERE id_proveedor IN (SELECT id FROM personas WHERE dni IN ('901110101', '901110102', '901110103', '901110104', '901110105', '901110106', '901110107', '901110108', '901110109', '901110110', '901110111', '901110112', '901110113', '901110114', '901110115', '901110116', '901110117', '3101900101', '3101900102', '3101900103', '3101900104', '3101900105', '3101900106', '3101900107'));
DELETE FROM personas WHERE dni IN ('901110101', '901110102', '901110103', '901110104', '901110105', '901110106', '901110107', '901110108', '901110109', '901110110', '901110111', '901110112', '901110113', '901110114', '901110115', '901110116', '901110117', '3101900101', '3101900102', '3101900103', '3101900104', '3101900105', '3101900106', '3101900107');
SELECT CONCAT_WS(' | ', CONCAT((SELECT COUNT(*) FROM personas), ' personas'),
  CONCAT((SELECT COUNT(*) FROM equipos), ' equipos')) AS 'Así quedó la base';
