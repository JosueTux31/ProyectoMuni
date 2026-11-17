-- =====================================================================
--  insercionDispositivos.sql - módulo de equipos municipales
--  gestion_redes (MariaDB 10.3 o superior)
-- ---------------------------------------------------------------------
--  Paso 6. Datos que el módulo necesita para funcionar: los de las tablas
--  catálogo de la especificación, con sus mismos códigos (tipos,
--  marcas, modelos, procesadores, sistemas operativos, firmwares,
--  edificios, estados, roles, herramientas y tipos de archivo), y los
--  que el sistema ya usaba (más tipos de equipo y sus marcas comunes),
--  que se buscan por nombre. Todo va en MAYÚSCULA, igual que lo guardan
--  los disparadores.
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

-- La carga inicial no se registra en la auditoría
SET @muni_sin_auditoria = 1;

-- Categorías de equipo (fijas: la página sabe qué datos pide cada una)
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 1, 'EQUIPOS DE RED', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 1);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 2, 'COMPUTADORAS', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 2);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 3, 'SERVIDORES Y ALMACENAMIENTO', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 3);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 4, 'DISPOSITIVOS MÓVILES', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 4);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 5, 'TELEFONÍA', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 5);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 6, 'IMPRESIÓN Y ESCANEO', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 6);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 7, 'PANTALLAS Y PROYECCIÓN', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 7);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 8, 'ENERGÍA', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 8);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 9, 'VIDEOVIGILANCIA Y ASISTENCIA', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 9);
INSERT INTO categoria_equipos (id_categoria, descripcion, lleva_agente)
    SELECT 10, 'OTROS EQUIPOS', 0 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM categoria_equipos WHERE id_categoria = 10);

-- Tabla tipo_equipos: los 13 de la especificación, con sus códigos
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 1, 'MODEM', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 1 OR descripcion = 'MODEM');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 2, 'FIREWALL', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 2 OR descripcion = 'FIREWALL');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 3, 'ROUTER', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 3 OR descripcion = 'ROUTER');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 4, 'SWITCH', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 4 OR descripcion = 'SWITCH');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 5, 'SERVER', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 5 OR descripcion = 'SERVER');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 6, 'WORKSTATION', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 6 OR descripcion = 'WORKSTATION');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 7, 'LAPTOP', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 7 OR descripcion = 'LAPTOP');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 8, 'PRINTER', 6 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 8 OR descripcion = 'PRINTER');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 9, 'SCANNER', 6 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 9 OR descripcion = 'SCANNER');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 10, 'PRINTER/SCANNER', 6 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 10 OR descripcion = 'PRINTER/SCANNER');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 11, 'IP PHONE', 5 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 11 OR descripcion = 'IP PHONE');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 12, 'TABLET', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 12 OR descripcion = 'TABLET');
INSERT INTO tipo_equipos (tipo_equipo, descripcion, id_categoria)
    SELECT 13, 'MOBILE PHONE', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE tipo_equipo = 13 OR descripcion = 'MOBILE PHONE');

-- Los demás tipos de equipo que usa el sistema, cada uno en su categoría
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'ACCESS POINT', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'ACCESS POINT');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'COMPUTADORA DE ESCRITORIO', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'COMPUTADORA DE ESCRITORIO');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'TODO EN UNO', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'TODO EN UNO');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'MINI PC', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'MINI PC');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'NAS', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'NAS');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'CENTRAL TELEFÓNICA', 5 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'CENTRAL TELEFÓNICA');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'PLOTTER', 6 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'PLOTTER');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'MONITOR', 7 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'MONITOR');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'PROYECTOR', 7 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'PROYECTOR');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'TELEVISOR', 7 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'TELEVISOR');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'UPS', 8 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'UPS');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'CÁMARA IP', 9 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'CÁMARA IP');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'GRABADOR NVR', 9 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'GRABADOR NVR');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'RELOJ MARCADOR', 9 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'RELOJ MARCADOR');
INSERT INTO tipo_equipos (descripcion, id_categoria)
    SELECT 'OTRO EQUIPO', 10 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_equipos WHERE descripcion = 'OTRO EQUIPO');

-- Tabla marcas: las de la especificación (cada una de su tipo de equipo)
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 1, 'ARRIS', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 1 OR (tipo_equipo = 1 AND descripcion = 'ARRIS'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 2, 'CISCO', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 2 OR (tipo_equipo = 2 AND descripcion = 'CISCO'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 3, 'SOPHOS', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 3 OR (tipo_equipo = 2 AND descripcion = 'SOPHOS'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 4, 'WATCHGUARD', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 4 OR (tipo_equipo = 2 AND descripcion = 'WATCHGUARD'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 5, 'CISCO', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 5 OR (tipo_equipo = 3 AND descripcion = 'CISCO'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 6, 'CISCO', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 6 OR (tipo_equipo = 4 AND descripcion = 'CISCO'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 7, 'DLINK', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 7 OR (tipo_equipo = 4 AND descripcion = 'DLINK'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 8, 'HP', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 8 OR (tipo_equipo = 4 AND descripcion = 'HP'));
INSERT INTO marcas (id_marca, descripcion, tipo_equipo)
    SELECT 9, 'ARUBA', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM marcas WHERE id_marca = 9 OR (tipo_equipo = 4 AND descripcion = 'ARUBA'));

-- Marcas comunes de los demás tipos de equipo
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'SERVER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'SERVER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'SERVER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'WORKSTATION'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'WORKSTATION'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'WORKSTATION'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'LAPTOP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'LAPTOP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'LAPTOP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ACER' FROM tipo_equipos t
     WHERE t.descripcion = 'LAPTOP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ACER');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ASUS' FROM tipo_equipos t
     WHERE t.descripcion = 'LAPTOP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ASUS');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'APPLE' FROM tipo_equipos t
     WHERE t.descripcion = 'LAPTOP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'APPLE');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'EPSON' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'EPSON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'BROTHER' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'BROTHER');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CANON' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CANON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LEXMARK' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LEXMARK');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ZEBRA' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ZEBRA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'FUJITSU' FROM tipo_equipos t
     WHERE t.descripcion = 'SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'FUJITSU');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'EPSON' FROM tipo_equipos t
     WHERE t.descripcion = 'SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'EPSON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CANON' FROM tipo_equipos t
     WHERE t.descripcion = 'SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CANON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'EPSON' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'EPSON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'BROTHER' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'BROTHER');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CANON' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CANON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'KYOCERA' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'KYOCERA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'RICOH' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'RICOH');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'XEROX' FROM tipo_equipos t
     WHERE t.descripcion = 'PRINTER/SCANNER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'XEROX');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CISCO' FROM tipo_equipos t
     WHERE t.descripcion = 'IP PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CISCO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'YEALINK' FROM tipo_equipos t
     WHERE t.descripcion = 'IP PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'YEALINK');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'GRANDSTREAM' FROM tipo_equipos t
     WHERE t.descripcion = 'IP PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'GRANDSTREAM');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'POLYCOM' FROM tipo_equipos t
     WHERE t.descripcion = 'IP PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'POLYCOM');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'SAMSUNG' FROM tipo_equipos t
     WHERE t.descripcion = 'TABLET'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'SAMSUNG');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'APPLE' FROM tipo_equipos t
     WHERE t.descripcion = 'TABLET'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'APPLE');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'TABLET'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'SAMSUNG' FROM tipo_equipos t
     WHERE t.descripcion = 'MOBILE PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'SAMSUNG');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'APPLE' FROM tipo_equipos t
     WHERE t.descripcion = 'MOBILE PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'APPLE');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'MOTOROLA' FROM tipo_equipos t
     WHERE t.descripcion = 'MOBILE PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'MOTOROLA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'XIAOMI' FROM tipo_equipos t
     WHERE t.descripcion = 'MOBILE PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'XIAOMI');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HUAWEI' FROM tipo_equipos t
     WHERE t.descripcion = 'MOBILE PHONE'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HUAWEI');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'UBIQUITI' FROM tipo_equipos t
     WHERE t.descripcion = 'ACCESS POINT'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'UBIQUITI');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ARUBA' FROM tipo_equipos t
     WHERE t.descripcion = 'ACCESS POINT'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ARUBA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CISCO' FROM tipo_equipos t
     WHERE t.descripcion = 'ACCESS POINT'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CISCO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'TP-LINK' FROM tipo_equipos t
     WHERE t.descripcion = 'ACCESS POINT'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'TP-LINK');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'COMPUTADORA DE ESCRITORIO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'COMPUTADORA DE ESCRITORIO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'COMPUTADORA DE ESCRITORIO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ACER' FROM tipo_equipos t
     WHERE t.descripcion = 'COMPUTADORA DE ESCRITORIO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ACER');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ASUS' FROM tipo_equipos t
     WHERE t.descripcion = 'COMPUTADORA DE ESCRITORIO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ASUS');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'TODO EN UNO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'TODO EN UNO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'TODO EN UNO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'APPLE' FROM tipo_equipos t
     WHERE t.descripcion = 'TODO EN UNO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'APPLE');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'MINI PC'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'MINI PC'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'MINI PC'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'INTEL' FROM tipo_equipos t
     WHERE t.descripcion = 'MINI PC'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'INTEL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'SYNOLOGY' FROM tipo_equipos t
     WHERE t.descripcion = 'NAS'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'SYNOLOGY');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'QNAP' FROM tipo_equipos t
     WHERE t.descripcion = 'NAS'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'QNAP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CISCO' FROM tipo_equipos t
     WHERE t.descripcion = 'CENTRAL TELEFÓNICA'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CISCO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'GRANDSTREAM' FROM tipo_equipos t
     WHERE t.descripcion = 'CENTRAL TELEFÓNICA'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'GRANDSTREAM');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'PANASONIC' FROM tipo_equipos t
     WHERE t.descripcion = 'CENTRAL TELEFÓNICA'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'PANASONIC');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'PLOTTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'EPSON' FROM tipo_equipos t
     WHERE t.descripcion = 'PLOTTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'EPSON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CANON' FROM tipo_equipos t
     WHERE t.descripcion = 'PLOTTER'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CANON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DELL' FROM tipo_equipos t
     WHERE t.descripcion = 'MONITOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DELL');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HP' FROM tipo_equipos t
     WHERE t.descripcion = 'MONITOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LENOVO' FROM tipo_equipos t
     WHERE t.descripcion = 'MONITOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LENOVO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'SAMSUNG' FROM tipo_equipos t
     WHERE t.descripcion = 'MONITOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'SAMSUNG');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LG' FROM tipo_equipos t
     WHERE t.descripcion = 'MONITOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LG');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ACER' FROM tipo_equipos t
     WHERE t.descripcion = 'MONITOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ACER');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'EPSON' FROM tipo_equipos t
     WHERE t.descripcion = 'PROYECTOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'EPSON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'BENQ' FROM tipo_equipos t
     WHERE t.descripcion = 'PROYECTOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'BENQ');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'VIEWSONIC' FROM tipo_equipos t
     WHERE t.descripcion = 'PROYECTOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'VIEWSONIC');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'SAMSUNG' FROM tipo_equipos t
     WHERE t.descripcion = 'TELEVISOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'SAMSUNG');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'LG' FROM tipo_equipos t
     WHERE t.descripcion = 'TELEVISOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'LG');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'SONY' FROM tipo_equipos t
     WHERE t.descripcion = 'TELEVISOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'SONY');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'APC' FROM tipo_equipos t
     WHERE t.descripcion = 'UPS'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'APC');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'CDP' FROM tipo_equipos t
     WHERE t.descripcion = 'UPS'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'CDP');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'EATON' FROM tipo_equipos t
     WHERE t.descripcion = 'UPS'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'EATON');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'FORZA' FROM tipo_equipos t
     WHERE t.descripcion = 'UPS'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'FORZA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HIKVISION' FROM tipo_equipos t
     WHERE t.descripcion = 'CÁMARA IP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HIKVISION');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DAHUA' FROM tipo_equipos t
     WHERE t.descripcion = 'CÁMARA IP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DAHUA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'AXIS' FROM tipo_equipos t
     WHERE t.descripcion = 'CÁMARA IP'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'AXIS');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'HIKVISION' FROM tipo_equipos t
     WHERE t.descripcion = 'GRABADOR NVR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'HIKVISION');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'DAHUA' FROM tipo_equipos t
     WHERE t.descripcion = 'GRABADOR NVR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'DAHUA');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'ZKTECO' FROM tipo_equipos t
     WHERE t.descripcion = 'RELOJ MARCADOR'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'ZKTECO');
INSERT INTO marcas (tipo_equipo, descripcion)
    SELECT t.tipo_equipo, 'GENÉRICA' FROM tipo_equipos t
     WHERE t.descripcion = 'OTRO EQUIPO'
       AND NOT EXISTS (SELECT 1 FROM marcas m WHERE m.tipo_equipo = t.tipo_equipo AND m.descripcion = 'GENÉRICA');

-- Tabla modelos
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 1, 'CISCO ASA', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 1 OR (id_marca = 2 AND descripcion = 'CISCO ASA'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 2, 'CISCO SECURE FIREWALL', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 2 OR (id_marca = 2 AND descripcion = 'CISCO SECURE FIREWALL'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 3, 'SOPHOS XGS 2300', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 3 OR (id_marca = 3 AND descripcion = 'SOPHOS XGS 2300'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 4, 'CISCO 4321', 5 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 4 OR (id_marca = 5 AND descripcion = 'CISCO 4321'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 5, 'CISCO RV215W', 5 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 5 OR (id_marca = 5 AND descripcion = 'CISCO RV215W'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 6, 'DLINK DGS 3120 48PC', 7 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 6 OR (id_marca = 7 AND descripcion = 'DLINK DGS 3120 48PC'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 7, 'DLINK DES 1200 24PC', 7 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 7 OR (id_marca = 7 AND descripcion = 'DLINK DES 1200 24PC'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 8, 'HP 1920S', 8 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 8 OR (id_marca = 8 AND descripcion = 'HP 1920S'));
INSERT INTO modelos (id_modelo, descripcion, id_marca)
    SELECT 9, 'ARUBA 3226', 9 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM modelos WHERE id_modelo = 9 OR (id_marca = 9 AND descripcion = 'ARUBA 3226'));

-- Tabla procesadores
INSERT INTO procesadores (id_proc, descripcion)
    SELECT 1, 'AMD RYZEN R1606G' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM procesadores WHERE id_proc = 1 OR descripcion = 'AMD RYZEN R1606G');
INSERT INTO procesadores (id_proc, descripcion)
    SELECT 2, 'INTEL ATOM C2718' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM procesadores WHERE id_proc = 2 OR descripcion = 'INTEL ATOM C2718');

-- Tabla sis_operativos: los de la especificación y los que el sistema ya usaba
INSERT INTO sis_operativos (id_so, descripcion)
    SELECT 1, 'N/D' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE id_so = 1 OR descripcion = 'N/D');
INSERT INTO sis_operativos (id_so, descripcion)
    SELECT 2, 'LINUX DEBIAN 12' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE id_so = 2 OR descripcion = 'LINUX DEBIAN 12');
INSERT INTO sis_operativos (id_so, descripcion)
    SELECT 3, 'WINDOWS 10' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE id_so = 3 OR descripcion = 'WINDOWS 10');
INSERT INTO sis_operativos (id_so, descripcion)
    SELECT 4, 'SOPHOS FIREWALL OS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE id_so = 4 OR descripcion = 'SOPHOS FIREWALL OS');
INSERT INTO sis_operativos (id_so, descripcion)
    SELECT 5, 'CISCO ADAPTIVE SECURITY APPLIANCE SOFTWARE (ASA)' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE id_so = 5 OR descripcion = 'CISCO ADAPTIVE SECURITY APPLIANCE SOFTWARE (ASA)');
INSERT INTO sis_operativos (descripcion)
    SELECT 'LINUX' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'LINUX');
INSERT INTO sis_operativos (descripcion)
    SELECT 'WINDOWS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'WINDOWS');
INSERT INTO sis_operativos (descripcion)
    SELECT 'WINDOWS SERVER' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'WINDOWS SERVER');
INSERT INTO sis_operativos (descripcion)
    SELECT 'MACOS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'MACOS');
INSERT INTO sis_operativos (descripcion)
    SELECT 'ANDROID' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'ANDROID');
INSERT INTO sis_operativos (descripcion)
    SELECT 'IOS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'IOS');
INSERT INTO sis_operativos (descripcion)
    SELECT 'IPADOS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'IPADOS');
INSERT INTO sis_operativos (descripcion)
    SELECT 'CHROMEOS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'CHROMEOS');
INSERT INTO sis_operativos (descripcion)
    SELECT 'VMWARE ESXI' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'VMWARE ESXI');
INSERT INTO sis_operativos (descripcion)
    SELECT 'FIRMWARE DEL FABRICANTE' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM sis_operativos WHERE descripcion = 'FIRMWARE DEL FABRICANTE');

-- Tabla firmwares
INSERT INTO firmwares (id_firmw, descripcion)
    SELECT 1, 'N/D' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM firmwares WHERE id_firmw = 1 OR descripcion = 'N/D');
INSERT INTO firmwares (id_firmw, descripcion)
    SELECT 2, 'SFOS 22.0.2' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM firmwares WHERE id_firmw = 2 OR descripcion = 'SFOS 22.0.2');

-- Tabla edificios (Costa Rica, Alajuela, Grecia, Grecia)
INSERT INTO edificios (descripcion, id_pais, id_provincia, id_canton, id_distrito, ubicacion)
    SELECT 'PALACIO MUNICIPAL', 'CR', '2', '03', '01', '10.073361,-84.312170' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM edificios WHERE descripcion = 'PALACIO MUNICIPAL');
-- si ya existía sin dirección o sin coordenadas, se completa
UPDATE edificios
   SET id_pais = 'CR', id_provincia = '2', id_canton = '03', id_distrito = '01'
 WHERE descripcion = 'PALACIO MUNICIPAL' AND id_pais IS NULL;
UPDATE edificios SET ubicacion = '10.073361,-84.312170' WHERE descripcion = 'PALACIO MUNICIPAL' AND ubicacion IS NULL;
INSERT INTO edificios (descripcion, id_pais, id_provincia, id_canton, id_distrito, ubicacion)
    SELECT 'MERCADO MUNICIPAL', 'CR', '2', '03', '01', '10.072832,-84.313207' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM edificios WHERE descripcion = 'MERCADO MUNICIPAL');
-- si ya existía sin dirección o sin coordenadas, se completa
UPDATE edificios
   SET id_pais = 'CR', id_provincia = '2', id_canton = '03', id_distrito = '01'
 WHERE descripcion = 'MERCADO MUNICIPAL' AND id_pais IS NULL;
UPDATE edificios SET ubicacion = '10.072832,-84.313207' WHERE descripcion = 'MERCADO MUNICIPAL' AND ubicacion IS NULL;
INSERT INTO edificios (descripcion, id_pais, id_provincia, id_canton, id_distrito, ubicacion)
    SELECT 'PLANTEL MUNICIPAL', 'CR', '2', '03', '01', '10.073423,-84.314644' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM edificios WHERE descripcion = 'PLANTEL MUNICIPAL');
-- si ya existía sin dirección o sin coordenadas, se completa
UPDATE edificios
   SET id_pais = 'CR', id_provincia = '2', id_canton = '03', id_distrito = '01'
 WHERE descripcion = 'PLANTEL MUNICIPAL' AND id_pais IS NULL;
UPDATE edificios SET ubicacion = '10.073423,-84.314644' WHERE descripcion = 'PLANTEL MUNICIPAL' AND ubicacion IS NULL;
INSERT INTO edificios (descripcion, id_pais, id_provincia, id_canton, id_distrito, ubicacion)
    SELECT 'CEMENTERIO MUNICIPAL', 'CR', '2', '03', '01', '10.067026,-84.313785' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM edificios WHERE descripcion = 'CEMENTERIO MUNICIPAL');
-- si ya existía sin dirección o sin coordenadas, se completa
UPDATE edificios
   SET id_pais = 'CR', id_provincia = '2', id_canton = '03', id_distrito = '01'
 WHERE descripcion = 'CEMENTERIO MUNICIPAL' AND id_pais IS NULL;
UPDATE edificios SET ubicacion = '10.067026,-84.313785' WHERE descripcion = 'CEMENTERIO MUNICIPAL' AND ubicacion IS NULL;

-- Tabla estado_equipos
INSERT INTO estado_equipos (id_estado, descripcion)
    SELECT 1, 'N/D' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM estado_equipos WHERE id_estado = 1 OR descripcion = 'N/D');
INSERT INTO estado_equipos (id_estado, descripcion)
    SELECT 2, 'ACTIVO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM estado_equipos WHERE id_estado = 2 OR descripcion = 'ACTIVO');
INSERT INTO estado_equipos (id_estado, descripcion)
    SELECT 3, 'INACTIVO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM estado_equipos WHERE id_estado = 3 OR descripcion = 'INACTIVO');

-- Tabla tipo_roles
INSERT INTO tipo_roles (id_rol, descripcion)
    SELECT 1, 'N/D' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = 1 OR descripcion = 'N/D');
INSERT INTO tipo_roles (id_rol, descripcion)
    SELECT 2, 'SERVIDOR DE DOMINIO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = 2 OR descripcion = 'SERVIDOR DE DOMINIO');
INSERT INTO tipo_roles (id_rol, descripcion)
    SELECT 3, 'SERVIDOR DHCP' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = 3 OR descripcion = 'SERVIDOR DHCP');
INSERT INTO tipo_roles (id_rol, descripcion)
    SELECT 4, 'SERVIDOR DNS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = 4 OR descripcion = 'SERVIDOR DNS');
INSERT INTO tipo_roles (id_rol, descripcion)
    SELECT 5, 'SERVIDOR NTP' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_roles WHERE id_rol = 5 OR descripcion = 'SERVIDOR NTP');

-- Tabla tipo_herramientas
INSERT INTO tipo_herramientas (id_herram, descripcion)
    SELECT 1, 'N/D' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_herramientas WHERE id_herram = 1 OR descripcion = 'N/D');
INSERT INTO tipo_herramientas (id_herram, descripcion)
    SELECT 2, 'BITDEFENDER' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_herramientas WHERE id_herram = 2 OR descripcion = 'BITDEFENDER');
INSERT INTO tipo_herramientas (id_herram, descripcion)
    SELECT 3, 'MICROCLAUDIA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_herramientas WHERE id_herram = 3 OR descripcion = 'MICROCLAUDIA');
INSERT INTO tipo_herramientas (id_herram, descripcion)
    SELECT 4, 'CISCO UMBRELLA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_herramientas WHERE id_herram = 4 OR descripcion = 'CISCO UMBRELLA');

-- Tabla tipo_archivos: los de la especificación y los que el sistema ya usaba
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 1, 'N/D' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 1 OR descripcion = 'N/D');
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 2, 'MANUAL' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 2 OR descripcion = 'MANUAL');
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 3, 'GARANTÍA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 3 OR descripcion = 'GARANTÍA');
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 4, 'SOPORTE' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 4 OR descripcion = 'SOPORTE');
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 5, 'CONFIGURACIÓN' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 5 OR descripcion = 'CONFIGURACIÓN');
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 6, 'BACKUP' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 6 OR descripcion = 'BACKUP');
INSERT INTO tipo_archivos (tipo_arch, descripcion)
    SELECT 7, 'NOTA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE tipo_arch = 7 OR descripcion = 'NOTA');
INSERT INTO tipo_archivos (descripcion)
    SELECT 'IMAGEN DE DISPOSITIVO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE descripcion = 'IMAGEN DE DISPOSITIVO');
INSERT INTO tipo_archivos (descripcion)
    SELECT 'ARCHIVOS DE FIRMWARE' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE descripcion = 'ARCHIVOS DE FIRMWARE');
INSERT INTO tipo_archivos (descripcion)
    SELECT 'ACTA DE ENTREGA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM tipo_archivos WHERE descripcion = 'ACTA DE ENTREGA');

SET @muni_sin_auditoria = 0;

-- =====================================================================
-- Revisión: en una base nueva debe dar
-- categoria_equipos 10 | tipo_equipos 28 | marcas 98 | modelos 9 | procesadores 2 | sis_operativos 15 | firmwares 2 | edificios 4 | estado_equipos 3 | tipo_roles 5 | tipo_herramientas 4 | tipo_archivos 10
-- (si ya tenía datos puede haber más)
-- =====================================================================
SELECT (SELECT COUNT(*) FROM categoria_equipos) AS categoria_equipos,
       (SELECT COUNT(*) FROM tipo_equipos) AS tipo_equipos,
       (SELECT COUNT(*) FROM marcas) AS marcas,
       (SELECT COUNT(*) FROM modelos) AS modelos,
       (SELECT COUNT(*) FROM procesadores) AS procesadores,
       (SELECT COUNT(*) FROM sis_operativos) AS sis_operativos,
       (SELECT COUNT(*) FROM firmwares) AS firmwares,
       (SELECT COUNT(*) FROM edificios) AS edificios,
       (SELECT COUNT(*) FROM estado_equipos) AS estado_equipos,
       (SELECT COUNT(*) FROM tipo_roles) AS tipo_roles,
       (SELECT COUNT(*) FROM tipo_herramientas) AS tipo_herramientas,
       (SELECT COUNT(*) FROM tipo_archivos) AS tipo_archivos;

-- =====================================================================
-- Ejemplo (comentado): el firewall SOPHOS XGS 2300 de la especificación,
-- con dos IP, una MAC, la herramienta Cisco Umbrella y dos archivos,
-- usando los procedimientos. Para probar, quite los "-- " de las líneas.
-- Los parámetros de sp_equipos_insertar van en el orden de la tabla
-- equipos (vea la lista en procedimientosDispositivos.sql) y al final las
-- listas JSON: IP, MAC, líneas móviles, IMEI, roles, herramientas, el
-- check de Microclaudia y el OUT con el código.
-- =====================================================================
-- SET @ips  = '[{"direccion_ip": "192.168.10.1", "interfaz": "LAN"}, {"direccion_ip": "201.200.10.5", "interfaz": "WAN"}]';
-- SET @macs = '[{"direccion_mac": "00:1A:8C:12:34:56", "interfaz": "LAN"}]';   -- se guarda 001A8C123456
-- CALL sp_equipos_insertar('658429', 2, 3, 3, 'FW-PALACIO', 'MG-000123',
--                          NULL, NULL, NULL, NULL,              -- procesador, memoria, almacenamiento y su tipo
--                          1, 0, 10, 2, 0, 0, 0,                -- puertos serie, USB, Ethernet, SFP, wireless, bluetooth, celular
--                          4, 2,                                -- SOPHOS FIREWALL OS, SFOS 22.0.2
--                          NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
--                          1, 'CUARTO DE COMUNICACIONES', 2,    -- PALACIO MUNICIPAL, ubicación, ACTIVO
--                          NULL, NULL, NULL, '2024-03-15', '2027-03-15', NULL, FALSE,
--                          @ips, @macs, NULL, NULL, NULL, '[4]', NULL, @id);
-- CALL sp_dir_ips_insertar(@id, '10.10.10.1', 'GESTION', @linea);        -- o una por una
-- CALL sp_archivos_insertar(@id, 2, 'dispositivos/658429/manual.pdf', @linea);
-- CALL sp_archivos_insertar(@id, 5, 'dispositivos/658429/configuracion.conf', @linea);
-- CALL sp_equipos_obtener(@id);
-- CALL sp_dir_ips_listar(@id);
-- CALL sp_dir_macs_listar(@id);
-- CALL sp_archivos_listar(@id, NULL);
