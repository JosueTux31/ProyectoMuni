-- =====================================================================
--  borrarPruebaEquipos.sql - quita los equipos de cargaPruebaEquipos.sql
-- ---------------------------------------------------------------------
--  Borra definitivamente (con sus IP, MAC y demás detalle) los equipos que tienen en
--  Observaciones «CARGA DE PRUEBA DHCP 26/10/2026». No toca ningún otro equipo.
--     mariadb -u admin_db -p < borrarPruebaEquipos.sql
-- =====================================================================

USE gestion_redes;
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;

SELECT COUNT(*) AS equipos_de_prueba_que_se_borran FROM equipos WHERE observaciones LIKE 'CARGA DE PRUEBA DHCP 26/10/2026%';

SET @muni_sin_auditoria = 1;
DELETE FROM equipos WHERE observaciones LIKE 'CARGA DE PRUEBA DHCP 26/10/2026%';
SET @muni_sin_auditoria = 0;

SELECT COUNT(*) AS equipos_de_prueba_que_quedan FROM equipos WHERE observaciones LIKE 'CARGA DE PRUEBA DHCP 26/10/2026%';
