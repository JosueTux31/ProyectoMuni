-- =====================================================================
--  reparar_letras.sql - corrige tildes dañadas en catálogos y territorio
-- ---------------------------------------------------------------------
--  Si alguna vez un script se ejecutó con un programa que leía el
--  archivo como latin1 en vez de UTF-8, las tildes quedaron dañadas:
--  ESTÃNDAR en vez de ESTÁNDAR, CÃ‰DULA FÃSICA en vez de CÉDULA FÍSICA.
--  Este script las devuelve a como deben ser.
--
--  Solo toca las tablas de catálogos (cat_... y las tablas catálogo de
--  equipos: tipo_equipos, marcas, modelos, procesadores...) y de
--  territorio (geo_...),
--  y en ellas solo las filas que tienen ese daño (Ã o Â), que en esos
--  textos nunca son letras de verdad. Si no hay nada dañado no cambia nada.
--  Los datos de personas y equipos no se tocan (revisar_base.sql los
--  señala para corregirlos en la página).
--
--  Lo ejecuta reinstalar_base.sh después de los scripts. A mano:
--     mariadb -u admin_db -p < reparar_letras.sql
-- =====================================================================

USE gestion_redes;

SET NAMES utf8mb4;
SET @muni_sin_auditoria = 1;     -- la corrección no se registra en la auditoría
SET @reparar_filas = 0;
SET @reparar_choques = NULL;

DELIMITER $$
BEGIN NOT ATOMIC
    DECLARE v_fin     INT DEFAULT 0;
    DECLARE v_tabla   VARCHAR(64);
    DECLARE v_columna VARCHAR(64);
    DECLARE c_texto CURSOR FOR
        SELECT c.TABLE_NAME, c.COLUMN_NAME
          FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = DATABASE()
           AND (c.TABLE_NAME LIKE 'cat\_%' OR c.TABLE_NAME LIKE 'geo\_%'
                OR c.TABLE_NAME IN ('categoria_equipos', 'tipo_equipos', 'marcas', 'modelos', 'procesadores',
                                    'sis_operativos', 'firmwares', 'edificios', 'estado_equipos', 'tipo_roles',
                                    'tipo_herramientas', 'tipo_archivos'))
           AND c.DATA_TYPE IN ('char', 'varchar', 'text')
         ORDER BY c.TABLE_NAME, c.COLUMN_NAME;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;
    -- Si al corregir una fila queda igual a otra que ya estaba bien, no se
    -- cambia esa tabla y se avisa al final
    DECLARE CONTINUE HANDLER FOR 1062
        SET @reparar_choques = CONCAT_WS(', ', @reparar_choques, CONCAT(v_tabla, '.', v_columna));

    OPEN c_texto;
    leer: LOOP
        FETCH c_texto INTO v_tabla, v_columna;
        IF v_fin = 1 THEN
            LEAVE leer;
        END IF;
        EXECUTE IMMEDIATE CONCAT(
            'UPDATE `', v_tabla, '` SET `', v_columna, '` = ',
            'CONVERT(CAST(CONVERT(`', v_columna, '` USING latin1) AS BINARY) USING utf8mb4) ',
            'WHERE `', v_columna, '` LIKE BINARY ''%Ã%'' OR `', v_columna, '` LIKE BINARY ''%Â%''');
        SET @reparar_filas = @reparar_filas + ROW_COUNT();
    END LOOP;
    CLOSE c_texto;
END$$
DELIMITER ;

SET @muni_sin_auditoria = 0;

SELECT CONCAT(IF(@reparar_filas = 0, 'Tildes: no había nada dañado en catálogos ni territorio.',
                 CONCAT('Tildes: se corrigieron ', @reparar_filas, ' fila(s) de catálogos y territorio.')),
              IF(@reparar_choques IS NULL, '',
                 CONCAT(' No se pudo en ', @reparar_choques, ': ya existe la misma fila bien escrita; borre la dañada en la página.')))
       AS reparar_letras;
