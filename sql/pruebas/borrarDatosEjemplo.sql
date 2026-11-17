-- =====================================================================
--  borrarDatosEjemplo.sql - quita los datos de poblarDatosEjemplo.sql
--  Módulo de usuarios y proveedores - gestion_redes
-- ---------------------------------------------------------------------
--  Borra definitivamente los funcionarios y proveedores de ejemplo, con
--  sus teléfonos, correos, páginas web y claves. Los departamentos y los
--  catálogos se quedan: sirven igual para los datos reales. El historial
--  también se queda.
--  Uso:  mariadb -u admin_db -p < pruebas/borrarDatosEjemplo.sql
-- =====================================================================

USE gestion_redes;
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;
SET @muni_usuario_id = NULL, @muni_usuario_nombre = 'CARGA DE DATOS DE EJEMPLO', @muni_ip = '127.0.0.1';

SELECT COUNT(*) AS personas_de_ejemplo_que_se_borran FROM personas WHERE dni IN ('901110101', '901110102', '901110103', '901110104', '901110105', '901110106', '901110107', '901110108', '901110109', '901110110', '901110111', '901110112', '901110113', '901110114', '901110115', '901110116', '901110117', '3101900101', '3101900102', '3101900103', '3101900104', '3101900105', '3101900106', '3101900107');
DELETE FROM personas WHERE dni IN ('901110101', '901110102', '901110103', '901110104', '901110105', '901110106', '901110107', '901110108', '901110109', '901110110', '901110111', '901110112', '901110113', '901110114', '901110115', '901110116', '901110117', '3101900101', '3101900102', '3101900103', '3101900104', '3101900105', '3101900106', '3101900107');
SELECT CONCAT((SELECT COUNT(*) FROM personas), ' personas') AS 'Así quedó la base';
