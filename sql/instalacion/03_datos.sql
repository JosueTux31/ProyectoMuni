-- =====================================================================
--  03_DATOS.SQL - gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 3 de 3. Ejecutar después de 02_procedimientos.sql.
--
--  Datos que el sistema necesita para funcionar:
--    1. Catálogos básicos (roles, formas de inicio de sesión, tipos de
--       identificación, teléfono y correo, departamentos y categorías
--       de proveedores).
--    2. División territorial completa de Costa Rica: 7 provincias,
--       84 cantones y 491 distritos con su código postal
--       (provincia + cantón + distrito, p. ej. 20301 = Grecia).
--
--  Todo va en MAYÚSCULA, igual que lo guardan los disparadores.
--  Se puede ejecutar más de una vez: solo agrega lo que falta y
--  actualiza nombres y códigos postales del territorio.
--
--  Después de este script:
--    - Primer administrador:  python manage.py inicializar --usuario admin
--    - Padrón del TSE (3,5 millones de personas, para buscar nombres por
--      cédula):  python manage.py cargar_padron --descargar
-- =====================================================================

USE gestion_redes;

-- El archivo está en UTF-8 y la conexión usa la misma intercalación
-- (collation) que la base, con el programa que sea que lo ejecute: así
-- las tildes se guardan bien y nada mezcla intercalaciones distintas.
SET NAMES utf8mb4;
SET collation_connection = @@collation_database;

-- La carga inicial no se registra en la auditoría
SET @muni_sin_auditoria = 1;


-- =====================================================================
-- 1. CATÁLOGOS BÁSICOS
--    (se agrega cada valor solo si no existe; los que llevan código lo
--    conservan igual que en la base actual, los demás lo reciben solo)
-- =====================================================================

-- Roles. ADMINISTRADOR modifica todo; ESTÁNDAR solo consulta.
--  (Los roles administradores se configuran en settings.py: MUNI_ROLES_ADMIN)
INSERT INTO cat_roles_usuarios (descripcion)
    SELECT 'ADMINISTRADOR' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_roles_usuarios WHERE descripcion = 'ADMINISTRADOR');
INSERT INTO cat_roles_usuarios (descripcion)
    SELECT 'ESTÁNDAR' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_roles_usuarios WHERE descripcion = 'ESTÁNDAR');

-- Formas de iniciar sesión
INSERT INTO cat_tipos_autenticaciones (descripcion)
    SELECT 'SISTEMA APP' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_autenticaciones WHERE descripcion = 'SISTEMA APP');
INSERT INTO cat_tipos_autenticaciones (descripcion)
    SELECT 'ACTIVE DIRECTORY' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_autenticaciones WHERE descripcion = 'ACTIVE DIRECTORY');

-- Tipos de identificación (la búsqueda por cédula los elige solos por estas palabras:
--  FÍSICA, JURÍDICA, DIMEX)
INSERT INTO cat_tipos_identificaciones (cod_tipo_identificacion, descripcion)
    SELECT 1, 'CÉDULA FÍSICA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_identificaciones WHERE cod_tipo_identificacion = 1 OR descripcion = 'CÉDULA FÍSICA');
INSERT INTO cat_tipos_identificaciones (cod_tipo_identificacion, descripcion)
    SELECT 2, 'CÉDULA JURÍDICA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_identificaciones WHERE cod_tipo_identificacion = 2 OR descripcion = 'CÉDULA JURÍDICA');
INSERT INTO cat_tipos_identificaciones (cod_tipo_identificacion, descripcion)
    SELECT 3, 'DIMEX' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_identificaciones WHERE cod_tipo_identificacion = 3 OR descripcion = 'DIMEX');
INSERT INTO cat_tipos_identificaciones (cod_tipo_identificacion, descripcion)
    SELECT 4, 'PASAPORTE' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_identificaciones WHERE cod_tipo_identificacion = 4 OR descripcion = 'PASAPORTE');
INSERT INTO cat_tipos_identificaciones (cod_tipo_identificacion, descripcion)
    SELECT 5, 'SIN IDENTIFICACIÓN' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_identificaciones WHERE cod_tipo_identificacion = 5 OR descripcion = 'SIN IDENTIFICACIÓN');

-- Tipos de teléfono (con los mismos códigos de la base actual)
INSERT INTO cat_tipos_telefonos (cod_telefono, descripcion)
    SELECT 1, 'PERSONAL CELULAR' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_telefonos WHERE cod_telefono = 1 OR descripcion = 'PERSONAL CELULAR');
INSERT INTO cat_tipos_telefonos (cod_telefono, descripcion)
    SELECT 4, 'PERSONAL FIJO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_telefonos WHERE cod_telefono = 4 OR descripcion = 'PERSONAL FIJO');
INSERT INTO cat_tipos_telefonos (cod_telefono, descripcion)
    SELECT 7, 'TRABAJO CELULAR' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_telefonos WHERE cod_telefono = 7 OR descripcion = 'TRABAJO CELULAR');
INSERT INTO cat_tipos_telefonos (cod_telefono, descripcion)
    SELECT 6, 'TRABAJO FIJO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_telefonos WHERE cod_telefono = 6 OR descripcion = 'TRABAJO FIJO');

-- Tipos de correo
INSERT INTO cat_tipos_correos (cod_correo, descripcion)
    SELECT 1, 'INSTITUCIONAL' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_correos WHERE cod_correo = 1 OR descripcion = 'INSTITUCIONAL');
INSERT INTO cat_tipos_correos (cod_correo, descripcion)
    SELECT 2, 'PERSONAL' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_correos WHERE cod_correo = 2 OR descripcion = 'PERSONAL');
INSERT INTO cat_tipos_correos (cod_correo, descripcion)
    SELECT 3, 'TRABAJO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_tipos_correos WHERE cod_correo = 3 OR descripcion = 'TRABAJO');

-- Departamentos municipales (agregue los demás desde la página: Catálogos > Departamentos)
INSERT INTO cat_departamentos (descripcion)
    SELECT 'TECNOLOGÍAS DE INFORMACIÓN' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_departamentos WHERE descripcion = 'TECNOLOGÍAS DE INFORMACIÓN');

-- Categorías de proveedores
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'INFORMATICA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'INFORMATICA');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'INFRAESTRUCTURA EQUIPO DE COMPUTO - SERVERS, WORKSTATIONS, ALMACENAMIENTO E IMPRESORAS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'INFRAESTRUCTURA EQUIPO DE COMPUTO - SERVERS, WORKSTATIONS, ALMACENAMIENTO E IMPRESORAS');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'INFRAESTRUCTURA EQUIPO DE RED - FIREWALLS, ROUTERS, SWITCHES' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'INFRAESTRUCTURA EQUIPO DE RED - FIREWALLS, ROUTERS, SWITCHES');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'INFRAESTRUCTURA EQUIPO TELEFONICO - CENTRALES IP Y TELEFONOS IP' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'INFRAESTRUCTURA EQUIPO TELEFONICO - CENTRALES IP Y TELEFONOS IP');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'INFRAESTRUCTURA CABLEADO DE RED - COBRE Y FIBRA OPTICA' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'INFRAESTRUCTURA CABLEADO DE RED - COBRE Y FIBRA OPTICA');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'INFRAESTRUCTURA CABLEADO ELECTRICO' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'INFRAESTRUCTURA CABLEADO ELECTRICO');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'SERVICIOS DE RED' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'SERVICIOS DE RED');
INSERT INTO cat_categorias_proveedores (descripcion)
    SELECT 'SERVICIOS ELECTRICOS' FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM cat_categorias_proveedores WHERE descripcion = 'SERVICIOS ELECTRICOS');


-- =====================================================================
-- 2. DIVISIÓN TERRITORIAL DE COSTA RICA
--    Fuente: tabla "Districts of Costa Rica" de Wikipedia (código postal),
--    consultada el 15/10/2026.
-- =====================================================================

INSERT INTO geo_paises (cod_pais, nombre_pais) VALUES ('CR', 'COSTA RICA')
    ON DUPLICATE KEY UPDATE nombre_pais = VALUES(nombre_pais);

-- 7 provincias
INSERT INTO geo_provincias (cod_pais, cod_provincia, nombre_provincia) VALUES
    ('CR', '1', 'SAN JOSÉ'),
    ('CR', '2', 'ALAJUELA'),
    ('CR', '3', 'CARTAGO'),
    ('CR', '4', 'HEREDIA'),
    ('CR', '5', 'GUANACASTE'),
    ('CR', '6', 'PUNTARENAS'),
    ('CR', '7', 'LIMÓN')
    ON DUPLICATE KEY UPDATE nombre_provincia = VALUES(nombre_provincia);

-- 84 cantones
INSERT INTO geo_cantones (cod_pais, cod_provincia, cod_canton, nombre_canton) VALUES
    ('CR', '1', '01', 'SAN JOSÉ'),
    ('CR', '1', '02', 'ESCAZÚ'),
    ('CR', '1', '03', 'DESAMPARADOS'),
    ('CR', '1', '04', 'PURISCAL'),
    ('CR', '1', '05', 'TARRAZÚ'),
    ('CR', '1', '06', 'ASERRÍ'),
    ('CR', '1', '07', 'MORA'),
    ('CR', '1', '08', 'GOICOECHEA'),
    ('CR', '1', '09', 'SANTA ANA'),
    ('CR', '1', '10', 'ALAJUELITA'),
    ('CR', '1', '11', 'VÁZQUEZ DE CORONADO'),
    ('CR', '1', '12', 'ACOSTA'),
    ('CR', '1', '13', 'TIBÁS'),
    ('CR', '1', '14', 'MORAVIA'),
    ('CR', '1', '15', 'MONTES DE OCA'),
    ('CR', '1', '16', 'TURRUBARES'),
    ('CR', '1', '17', 'DOTA'),
    ('CR', '1', '18', 'CURRIDABAT'),
    ('CR', '1', '19', 'PÉREZ ZELEDÓN'),
    ('CR', '1', '20', 'LEÓN CORTÉS CASTRO'),
    ('CR', '2', '01', 'ALAJUELA'),
    ('CR', '2', '02', 'SAN RAMÓN'),
    ('CR', '2', '03', 'GRECIA'),
    ('CR', '2', '04', 'SAN MATEO'),
    ('CR', '2', '05', 'ATENAS'),
    ('CR', '2', '06', 'NARANJO'),
    ('CR', '2', '07', 'PALMARES'),
    ('CR', '2', '08', 'POÁS'),
    ('CR', '2', '09', 'OROTINA'),
    ('CR', '2', '10', 'SAN CARLOS'),
    ('CR', '2', '11', 'ZARCERO'),
    ('CR', '2', '12', 'SARCHÍ'),
    ('CR', '2', '13', 'UPALA'),
    ('CR', '2', '14', 'LOS CHILES'),
    ('CR', '2', '15', 'GUATUSO'),
    ('CR', '2', '16', 'RÍO CUARTO'),
    ('CR', '3', '01', 'CARTAGO'),
    ('CR', '3', '02', 'PARAÍSO'),
    ('CR', '3', '03', 'LA UNIÓN'),
    ('CR', '3', '04', 'JIMÉNEZ'),
    ('CR', '3', '05', 'TURRIALBA'),
    ('CR', '3', '06', 'ALVARADO'),
    ('CR', '3', '07', 'OREAMUNO'),
    ('CR', '3', '08', 'EL GUARCO'),
    ('CR', '4', '01', 'HEREDIA'),
    ('CR', '4', '02', 'BARVA'),
    ('CR', '4', '03', 'SANTO DOMINGO'),
    ('CR', '4', '04', 'SANTA BÁRBARA'),
    ('CR', '4', '05', 'SAN RAFAEL'),
    ('CR', '4', '06', 'SAN ISIDRO'),
    ('CR', '4', '07', 'BELÉN'),
    ('CR', '4', '08', 'FLORES'),
    ('CR', '4', '09', 'SAN PABLO'),
    ('CR', '4', '10', 'SARAPIQUÍ'),
    ('CR', '5', '01', 'LIBERIA'),
    ('CR', '5', '02', 'NICOYA'),
    ('CR', '5', '03', 'SANTA CRUZ'),
    ('CR', '5', '04', 'BAGACES'),
    ('CR', '5', '05', 'CARRILLO'),
    ('CR', '5', '06', 'CAÑAS'),
    ('CR', '5', '07', 'ABANGARES'),
    ('CR', '5', '08', 'TILARÁN'),
    ('CR', '5', '09', 'NANDAYURE'),
    ('CR', '5', '10', 'LA CRUZ'),
    ('CR', '5', '11', 'HOJANCHA'),
    ('CR', '6', '01', 'PUNTARENAS'),
    ('CR', '6', '02', 'ESPARZA'),
    ('CR', '6', '03', 'BUENOS AIRES'),
    ('CR', '6', '04', 'MONTES DE ORO'),
    ('CR', '6', '05', 'OSA'),
    ('CR', '6', '06', 'QUEPOS'),
    ('CR', '6', '07', 'GOLFITO'),
    ('CR', '6', '08', 'COTO BRUS'),
    ('CR', '6', '09', 'PARRITA'),
    ('CR', '6', '10', 'CORREDORES'),
    ('CR', '6', '11', 'GARABITO'),
    ('CR', '6', '12', 'MONTEVERDE'),
    ('CR', '6', '13', 'PUERTO JIMÉNEZ'),
    ('CR', '7', '01', 'LIMÓN'),
    ('CR', '7', '02', 'POCOCÍ'),
    ('CR', '7', '03', 'SIQUIRRES'),
    ('CR', '7', '04', 'TALAMANCA'),
    ('CR', '7', '05', 'MATINA'),
    ('CR', '7', '06', 'GUÁCIMO')
    ON DUPLICATE KEY UPDATE nombre_canton = VALUES(nombre_canton);

-- 491 distritos con código postal
INSERT INTO geo_distritos (cod_pais, cod_provincia, cod_canton, cod_distrito, nombre_distrito, codigo_postal) VALUES
    ('CR', '1', '01', '01', 'CARMEN', '10101'),
    ('CR', '1', '01', '02', 'MERCED', '10102'),
    ('CR', '1', '01', '03', 'HOSPITAL', '10103'),
    ('CR', '1', '01', '04', 'CATEDRAL', '10104'),
    ('CR', '1', '01', '05', 'ZAPOTE', '10105'),
    ('CR', '1', '01', '06', 'SAN FRANCISCO DE DOS RÍOS', '10106'),
    ('CR', '1', '01', '07', 'URUCA', '10107'),
    ('CR', '1', '01', '08', 'MATA REDONDA', '10108'),
    ('CR', '1', '01', '09', 'PAVAS', '10109'),
    ('CR', '1', '01', '10', 'HATILLO', '10110'),
    ('CR', '1', '01', '11', 'SAN SEBASTIÁN', '10111'),
    ('CR', '1', '02', '01', 'ESCAZÚ', '10201'),
    ('CR', '1', '02', '02', 'SAN ANTONIO', '10202'),
    ('CR', '1', '02', '03', 'SAN RAFAEL', '10203'),
    ('CR', '1', '03', '01', 'DESAMPARADOS', '10301'),
    ('CR', '1', '03', '02', 'SAN MIGUEL', '10302'),
    ('CR', '1', '03', '03', 'SAN JUAN DE DIOS', '10303'),
    ('CR', '1', '03', '04', 'SAN RAFAEL ARRIBA', '10304'),
    ('CR', '1', '03', '05', 'SAN ANTONIO', '10305'),
    ('CR', '1', '03', '06', 'FRAILES', '10306'),
    ('CR', '1', '03', '07', 'PATARRÁ', '10307'),
    ('CR', '1', '03', '08', 'SAN CRISTÓBAL', '10308'),
    ('CR', '1', '03', '09', 'ROSARIO', '10309'),
    ('CR', '1', '03', '10', 'DAMAS', '10310'),
    ('CR', '1', '03', '11', 'SAN RAFAEL ABAJO', '10311'),
    ('CR', '1', '03', '12', 'GRAVILIAS', '10312'),
    ('CR', '1', '03', '13', 'LOS GUIDO', '10313'),
    ('CR', '1', '04', '01', 'SANTIAGO', '10401'),
    ('CR', '1', '04', '02', 'MERCEDES SUR', '10402'),
    ('CR', '1', '04', '03', 'BARBACOAS', '10403'),
    ('CR', '1', '04', '04', 'GRIFO ALTO', '10404'),
    ('CR', '1', '04', '05', 'SAN RAFAEL', '10405'),
    ('CR', '1', '04', '06', 'CANDELARITA', '10406'),
    ('CR', '1', '04', '07', 'DESAMPARADITOS', '10407'),
    ('CR', '1', '04', '08', 'SAN ANTONIO', '10408'),
    ('CR', '1', '04', '09', 'CHIRES', '10409'),
    ('CR', '1', '05', '01', 'SAN MARCOS', '10501'),
    ('CR', '1', '05', '02', 'SAN LORENZO', '10502'),
    ('CR', '1', '05', '03', 'SAN CARLOS', '10503'),
    ('CR', '1', '06', '01', 'ASERRÍ', '10601'),
    ('CR', '1', '06', '02', 'TARBACA', '10602'),
    ('CR', '1', '06', '03', 'VUELTA DE JORCO', '10603'),
    ('CR', '1', '06', '04', 'SAN GABRIEL', '10604'),
    ('CR', '1', '06', '05', 'LEGUA', '10605'),
    ('CR', '1', '06', '06', 'MONTERREY', '10606'),
    ('CR', '1', '06', '07', 'SALITRILLOS', '10607'),
    ('CR', '1', '07', '01', 'COLÓN', '10701'),
    ('CR', '1', '07', '02', 'GUAYABO', '10702'),
    ('CR', '1', '07', '03', 'TABARCIA', '10703'),
    ('CR', '1', '07', '04', 'PIEDRAS NEGRAS', '10704'),
    ('CR', '1', '07', '05', 'PICAGRES', '10705'),
    ('CR', '1', '07', '06', 'JARIS', '10706'),
    ('CR', '1', '07', '07', 'QUITIRRISÍ', '10707'),
    ('CR', '1', '08', '01', 'GUADALUPE', '10801'),
    ('CR', '1', '08', '02', 'SAN FRANCISCO', '10802'),
    ('CR', '1', '08', '03', 'CALLE BLANCOS', '10803'),
    ('CR', '1', '08', '04', 'MATA DE PLÁTANO', '10804'),
    ('CR', '1', '08', '05', 'IPÍS', '10805'),
    ('CR', '1', '08', '06', 'RANCHO REDONDO', '10806'),
    ('CR', '1', '08', '07', 'PURRAL', '10807'),
    ('CR', '1', '09', '01', 'SANTA ANA', '10901'),
    ('CR', '1', '09', '02', 'SALITRAL', '10902'),
    ('CR', '1', '09', '03', 'POZOS', '10903'),
    ('CR', '1', '09', '04', 'URUCA', '10904'),
    ('CR', '1', '09', '05', 'PIEDADES', '10905'),
    ('CR', '1', '09', '06', 'BRASIL', '10906'),
    ('CR', '1', '10', '01', 'ALAJUELITA', '11001'),
    ('CR', '1', '10', '02', 'SAN JOSECITO', '11002'),
    ('CR', '1', '10', '03', 'SAN ANTONIO', '11003'),
    ('CR', '1', '10', '04', 'CONCEPCIÓN', '11004'),
    ('CR', '1', '10', '05', 'SAN FELIPE', '11005'),
    ('CR', '1', '11', '01', 'SAN ISIDRO', '11101'),
    ('CR', '1', '11', '02', 'SAN RAFAEL', '11102'),
    ('CR', '1', '11', '03', 'DULCE NOMBRE DE JESÚS', '11103'),
    ('CR', '1', '11', '04', 'PATALILLO', '11104'),
    ('CR', '1', '11', '05', 'CASCAJAL', '11105'),
    ('CR', '1', '12', '01', 'SAN IGNACIO', '11201'),
    ('CR', '1', '12', '02', 'GUAITIL', '11202'),
    ('CR', '1', '12', '03', 'PALMICHAL', '11203'),
    ('CR', '1', '12', '04', 'CANGREJAL', '11204'),
    ('CR', '1', '12', '05', 'SABANILLAS', '11205'),
    ('CR', '1', '13', '01', 'SAN JUAN', '11301'),
    ('CR', '1', '13', '02', 'CINCO ESQUINAS', '11302'),
    ('CR', '1', '13', '03', 'ANSELMO LLORENTE', '11303'),
    ('CR', '1', '13', '04', 'LEÓN XIII', '11304'),
    ('CR', '1', '13', '05', 'COLIMA', '11305'),
    ('CR', '1', '14', '01', 'SAN VICENTE', '11401'),
    ('CR', '1', '14', '02', 'SAN JERÓNIMO', '11402'),
    ('CR', '1', '14', '03', 'LA TRINIDAD', '11403'),
    ('CR', '1', '15', '01', 'SAN PEDRO', '11501'),
    ('CR', '1', '15', '02', 'SABANILLA', '11502'),
    ('CR', '1', '15', '03', 'MERCEDES', '11503'),
    ('CR', '1', '15', '04', 'SAN RAFAEL', '11504'),
    ('CR', '1', '16', '01', 'SAN PABLO', '11601'),
    ('CR', '1', '16', '02', 'SAN PEDRO', '11602'),
    ('CR', '1', '16', '03', 'SAN JUAN DE MATA', '11603'),
    ('CR', '1', '16', '04', 'SAN LUIS', '11604'),
    ('CR', '1', '16', '05', 'CARARA', '11605'),
    ('CR', '1', '17', '01', 'SANTA MARÍA', '11701'),
    ('CR', '1', '17', '02', 'JARDÍN', '11702'),
    ('CR', '1', '17', '03', 'COPEY', '11703'),
    ('CR', '1', '18', '01', 'CURRIDABAT', '11801'),
    ('CR', '1', '18', '02', 'GRANADILLA', '11802'),
    ('CR', '1', '18', '03', 'SÁNCHEZ', '11803'),
    ('CR', '1', '18', '04', 'TIRRASES', '11804'),
    ('CR', '1', '19', '01', 'SAN ISIDRO DE EL GENERAL', '11901'),
    ('CR', '1', '19', '02', 'EL GENERAL', '11902'),
    ('CR', '1', '19', '03', 'DANIEL FLORES', '11903'),
    ('CR', '1', '19', '04', 'RIVAS', '11904'),
    ('CR', '1', '19', '05', 'SAN PEDRO', '11905'),
    ('CR', '1', '19', '06', 'PLATANARES', '11906'),
    ('CR', '1', '19', '07', 'PEJIBAYE', '11907'),
    ('CR', '1', '19', '08', 'CAJÓN', '11908'),
    ('CR', '1', '19', '09', 'BARÚ', '11909'),
    ('CR', '1', '19', '10', 'RÍO NUEVO', '11910'),
    ('CR', '1', '19', '11', 'PÁRAMO', '11911'),
    ('CR', '1', '19', '12', 'LA AMISTAD', '11912'),
    ('CR', '1', '20', '01', 'SAN PABLO', '12001'),
    ('CR', '1', '20', '02', 'SAN ANDRÉS', '12002'),
    ('CR', '1', '20', '03', 'LLANO BONITO', '12003'),
    ('CR', '1', '20', '04', 'SAN ISIDRO', '12004'),
    ('CR', '1', '20', '05', 'SANTA CRUZ', '12005'),
    ('CR', '1', '20', '06', 'SAN ANTONIO', '12006'),
    ('CR', '2', '01', '01', 'ALAJUELA', '20101'),
    ('CR', '2', '01', '02', 'SAN JOSÉ', '20102'),
    ('CR', '2', '01', '03', 'CARRIZAL', '20103'),
    ('CR', '2', '01', '04', 'SAN ANTONIO', '20104'),
    ('CR', '2', '01', '05', 'GUÁCIMA', '20105'),
    ('CR', '2', '01', '06', 'SAN ISIDRO', '20106'),
    ('CR', '2', '01', '07', 'SABANILLA', '20107'),
    ('CR', '2', '01', '08', 'SAN RAFAEL', '20108'),
    ('CR', '2', '01', '09', 'RÍO SEGUNDO', '20109'),
    ('CR', '2', '01', '10', 'DESAMPARADOS', '20110'),
    ('CR', '2', '01', '11', 'TURRÚCARES', '20111'),
    ('CR', '2', '01', '12', 'TAMBOR', '20112'),
    ('CR', '2', '01', '13', 'GARITA', '20113'),
    ('CR', '2', '01', '14', 'SARAPIQUÍ', '20114'),
    ('CR', '2', '02', '01', 'SAN RAMÓN', '20201'),
    ('CR', '2', '02', '02', 'SANTIAGO', '20202'),
    ('CR', '2', '02', '03', 'SAN JUAN', '20203'),
    ('CR', '2', '02', '04', 'PIEDADES NORTE', '20204'),
    ('CR', '2', '02', '05', 'PIEDADES SUR', '20205'),
    ('CR', '2', '02', '06', 'SAN RAFAEL', '20206'),
    ('CR', '2', '02', '07', 'SAN ISIDRO', '20207'),
    ('CR', '2', '02', '08', 'ÁNGELES', '20208'),
    ('CR', '2', '02', '09', 'ALFARO', '20209'),
    ('CR', '2', '02', '10', 'VOLIO', '20210'),
    ('CR', '2', '02', '11', 'CONCEPCIÓN', '20211'),
    ('CR', '2', '02', '12', 'ZAPOTAL', '20212'),
    ('CR', '2', '02', '13', 'PEÑAS BLANCAS', '20213'),
    ('CR', '2', '02', '14', 'SAN LORENZO', '20214'),
    ('CR', '2', '03', '01', 'GRECIA', '20301'),
    ('CR', '2', '03', '02', 'SAN ISIDRO', '20302'),
    ('CR', '2', '03', '03', 'SAN JOSÉ', '20303'),
    ('CR', '2', '03', '04', 'SAN ROQUE', '20304'),
    ('CR', '2', '03', '05', 'TACARES', '20305'),
    ('CR', '2', '03', '07', 'PUENTE DE PIEDRA', '20307'),
    ('CR', '2', '03', '08', 'BOLÍVAR', '20308'),
    ('CR', '2', '04', '01', 'SAN MATEO', '20401'),
    ('CR', '2', '04', '02', 'DESMONTE', '20402'),
    ('CR', '2', '04', '03', 'JESÚS MARÍA', '20403'),
    ('CR', '2', '04', '04', 'LABRADOR', '20404'),
    ('CR', '2', '05', '01', 'ATENAS', '20501'),
    ('CR', '2', '05', '02', 'JESÚS', '20502'),
    ('CR', '2', '05', '03', 'MERCEDES', '20503'),
    ('CR', '2', '05', '04', 'SAN ISIDRO', '20504'),
    ('CR', '2', '05', '05', 'CONCEPCIÓN', '20505'),
    ('CR', '2', '05', '06', 'SAN JOSÉ', '20506'),
    ('CR', '2', '05', '07', 'SANTA EULALIA', '20507'),
    ('CR', '2', '05', '08', 'ESCOBAL', '20508'),
    ('CR', '2', '06', '01', 'NARANJO', '20601'),
    ('CR', '2', '06', '02', 'SAN MIGUEL', '20602'),
    ('CR', '2', '06', '03', 'SAN JOSÉ', '20603'),
    ('CR', '2', '06', '04', 'CIRRÍ SUR', '20604'),
    ('CR', '2', '06', '05', 'SAN JERÓNIMO', '20605'),
    ('CR', '2', '06', '06', 'SAN JUAN', '20606'),
    ('CR', '2', '06', '07', 'EL ROSARIO', '20607'),
    ('CR', '2', '06', '08', 'PALMITOS', '20608'),
    ('CR', '2', '07', '01', 'PALMARES', '20701'),
    ('CR', '2', '07', '02', 'ZARAGOZA', '20702'),
    ('CR', '2', '07', '03', 'BUENOS AIRES', '20703'),
    ('CR', '2', '07', '04', 'SANTIAGO', '20704'),
    ('CR', '2', '07', '05', 'CANDELARIA', '20705'),
    ('CR', '2', '07', '06', 'ESQUIPULAS', '20706'),
    ('CR', '2', '07', '07', 'LA GRANJA', '20707'),
    ('CR', '2', '08', '01', 'SAN PEDRO', '20801'),
    ('CR', '2', '08', '02', 'SAN JUAN', '20802'),
    ('CR', '2', '08', '03', 'SAN RAFAEL', '20803'),
    ('CR', '2', '08', '04', 'CARRILLOS', '20804'),
    ('CR', '2', '08', '05', 'SABANA REDONDA', '20805'),
    ('CR', '2', '09', '01', 'OROTINA', '20901'),
    ('CR', '2', '09', '02', 'EL MASTATE', '20902'),
    ('CR', '2', '09', '03', 'HACIENDA VIEJA', '20903'),
    ('CR', '2', '09', '04', 'COYOLAR', '20904'),
    ('CR', '2', '09', '05', 'LA CEIBA', '20905'),
    ('CR', '2', '10', '01', 'QUESADA', '21001'),
    ('CR', '2', '10', '02', 'FLORENCIA', '21002'),
    ('CR', '2', '10', '03', 'BUENAVISTA', '21003'),
    ('CR', '2', '10', '04', 'AGUAS ZARCAS', '21004'),
    ('CR', '2', '10', '05', 'VENECIA', '21005'),
    ('CR', '2', '10', '06', 'PITAL', '21006'),
    ('CR', '2', '10', '07', 'LA FORTUNA', '21007'),
    ('CR', '2', '10', '08', 'LA TIGRA', '21008'),
    ('CR', '2', '10', '09', 'LA PALMERA', '21009'),
    ('CR', '2', '10', '10', 'VENADO', '21010'),
    ('CR', '2', '10', '11', 'CUTRIS', '21011'),
    ('CR', '2', '10', '12', 'MONTERREY', '21012'),
    ('CR', '2', '10', '13', 'POCOSOL', '21013'),
    ('CR', '2', '11', '01', 'ZARCERO', '21101'),
    ('CR', '2', '11', '02', 'LAGUNA', '21102'),
    ('CR', '2', '11', '03', 'TAPESCO', '21103'),
    ('CR', '2', '11', '04', 'GUADALUPE', '21104'),
    ('CR', '2', '11', '05', 'PALMIRA', '21105'),
    ('CR', '2', '11', '06', 'ZAPOTE', '21106'),
    ('CR', '2', '11', '07', 'BRISAS', '21107'),
    ('CR', '2', '12', '01', 'SARCHÍ NORTE', '21201'),
    ('CR', '2', '12', '02', 'SARCHÍ SUR', '21202'),
    ('CR', '2', '12', '03', 'TORO AMARILLO', '21203'),
    ('CR', '2', '12', '04', 'SAN PEDRO', '21204'),
    ('CR', '2', '12', '05', 'RODRÍGUEZ', '21205'),
    ('CR', '2', '13', '01', 'UPALA', '21301'),
    ('CR', '2', '13', '02', 'AGUAS CLARAS', '21302'),
    ('CR', '2', '13', '03', 'SAN JOSÉ', '21303'),
    ('CR', '2', '13', '04', 'BIJAGUA', '21304'),
    ('CR', '2', '13', '05', 'DELICIAS', '21305'),
    ('CR', '2', '13', '06', 'DOS RÍOS', '21306'),
    ('CR', '2', '13', '07', 'YOLILLAL', '21307'),
    ('CR', '2', '13', '08', 'CANALETE', '21308'),
    ('CR', '2', '14', '01', 'LOS CHILES', '21401'),
    ('CR', '2', '14', '02', 'CAÑO NEGRO', '21402'),
    ('CR', '2', '14', '03', 'EL AMPARO', '21403'),
    ('CR', '2', '14', '04', 'SAN JORGE', '21404'),
    ('CR', '2', '15', '01', 'SAN RAFAEL', '21501'),
    ('CR', '2', '15', '02', 'BUENAVISTA', '21502'),
    ('CR', '2', '15', '03', 'COTE', '21503'),
    ('CR', '2', '15', '04', 'KATIRA', '21504'),
    ('CR', '2', '16', '01', 'RÍO CUARTO', '21601'),
    ('CR', '2', '16', '02', 'SANTA RITA', '21602'),
    ('CR', '2', '16', '03', 'SANTA ISABEL', '21603'),
    ('CR', '3', '01', '01', 'ORIENTAL', '30101'),
    ('CR', '3', '01', '02', 'OCCIDENTAL', '30102'),
    ('CR', '3', '01', '03', 'CARMEN', '30103'),
    ('CR', '3', '01', '04', 'SAN NICOLÁS', '30104'),
    ('CR', '3', '01', '05', 'AGUACALIENTE', '30105'),
    ('CR', '3', '01', '06', 'GUADALUPE', '30106'),
    ('CR', '3', '01', '07', 'CORRALILLO', '30107'),
    ('CR', '3', '01', '08', 'TIERRA BLANCA', '30108'),
    ('CR', '3', '01', '09', 'DULCE NOMBRE', '30109'),
    ('CR', '3', '01', '10', 'LLANO GRANDE', '30110'),
    ('CR', '3', '01', '11', 'QUEBRADILLA', '30111'),
    ('CR', '3', '02', '01', 'PARAÍSO', '30201'),
    ('CR', '3', '02', '02', 'SANTIAGO', '30202'),
    ('CR', '3', '02', '03', 'OROSI', '30203'),
    ('CR', '3', '02', '04', 'CACHÍ', '30204'),
    ('CR', '3', '02', '05', 'LLANOS DE SANTA LUCÍA', '30205'),
    ('CR', '3', '02', '06', 'BIRRISITO', '30206'),
    ('CR', '3', '03', '01', 'TRES RÍOS', '30301'),
    ('CR', '3', '03', '02', 'SAN DIEGO', '30302'),
    ('CR', '3', '03', '03', 'SAN JUAN', '30303'),
    ('CR', '3', '03', '04', 'SAN RAFAEL', '30304'),
    ('CR', '3', '03', '05', 'CONCEPCIÓN', '30305'),
    ('CR', '3', '03', '06', 'DULCE NOMBRE', '30306'),
    ('CR', '3', '03', '07', 'SAN RAMÓN', '30307'),
    ('CR', '3', '03', '08', 'RÍO AZUL', '30308'),
    ('CR', '3', '04', '01', 'JUAN VIÑAS', '30401'),
    ('CR', '3', '04', '02', 'TUCURRIQUE', '30402'),
    ('CR', '3', '04', '03', 'PEJIBAYE', '30403'),
    ('CR', '3', '04', '04', 'LA VICTORIA', '30404'),
    ('CR', '3', '05', '01', 'TURRIALBA', '30501'),
    ('CR', '3', '05', '02', 'LA SUIZA', '30502'),
    ('CR', '3', '05', '03', 'PERALTA', '30503'),
    ('CR', '3', '05', '04', 'SANTA CRUZ', '30504'),
    ('CR', '3', '05', '05', 'SANTA TERESITA', '30505'),
    ('CR', '3', '05', '06', 'PAVONES', '30506'),
    ('CR', '3', '05', '07', 'TUIS', '30507'),
    ('CR', '3', '05', '08', 'TAYUTIC', '30508'),
    ('CR', '3', '05', '09', 'SANTA ROSA', '30509'),
    ('CR', '3', '05', '10', 'TRES EQUIS', '30510'),
    ('CR', '3', '05', '11', 'LA ISABEL', '30511'),
    ('CR', '3', '05', '12', 'CHIRRIPÓ', '30512'),
    ('CR', '3', '06', '01', 'PACAYAS', '30601'),
    ('CR', '3', '06', '02', 'CERVANTES', '30602'),
    ('CR', '3', '06', '03', 'CAPELLADES', '30603'),
    ('CR', '3', '07', '01', 'SAN RAFAEL', '30701'),
    ('CR', '3', '07', '02', 'COT', '30702'),
    ('CR', '3', '07', '03', 'POTRERO CERRADO', '30703'),
    ('CR', '3', '07', '04', 'CIPRESES', '30704'),
    ('CR', '3', '07', '05', 'SANTA ROSA', '30705'),
    ('CR', '3', '08', '01', 'EL TEJAR', '30801'),
    ('CR', '3', '08', '02', 'SAN ISIDRO', '30802'),
    ('CR', '3', '08', '03', 'TOBOSI', '30803'),
    ('CR', '3', '08', '04', 'PATIO DE AGUA', '30804'),
    ('CR', '4', '01', '01', 'HEREDIA', '40101'),
    ('CR', '4', '01', '02', 'MERCEDES', '40102'),
    ('CR', '4', '01', '03', 'SAN FRANCISCO', '40103'),
    ('CR', '4', '01', '04', 'ULLOA', '40104'),
    ('CR', '4', '01', '05', 'VARABLANCA', '40105'),
    ('CR', '4', '02', '01', 'BARVA', '40201'),
    ('CR', '4', '02', '02', 'SAN PEDRO', '40202'),
    ('CR', '4', '02', '03', 'SAN PABLO', '40203'),
    ('CR', '4', '02', '04', 'SAN ROQUE', '40204'),
    ('CR', '4', '02', '05', 'SANTA LUCÍA', '40205'),
    ('CR', '4', '02', '06', 'SAN JOSÉ DE LA MONTAÑA', '40206'),
    ('CR', '4', '02', '07', 'PUENTE SALAS', '40207'),
    ('CR', '4', '03', '01', 'SANTO DOMINGO', '40301'),
    ('CR', '4', '03', '02', 'SAN VICENTE', '40302'),
    ('CR', '4', '03', '03', 'SAN MIGUEL', '40303'),
    ('CR', '4', '03', '04', 'PARACITO', '40304'),
    ('CR', '4', '03', '05', 'SANTO TOMÁS', '40305'),
    ('CR', '4', '03', '06', 'SANTA ROSA', '40306'),
    ('CR', '4', '03', '07', 'TURES', '40307'),
    ('CR', '4', '03', '08', 'PARÁ', '40308'),
    ('CR', '4', '04', '01', 'SANTA BÁRBARA', '40401'),
    ('CR', '4', '04', '02', 'SAN PEDRO', '40402'),
    ('CR', '4', '04', '03', 'SAN JUAN', '40403'),
    ('CR', '4', '04', '04', 'JESÚS', '40404'),
    ('CR', '4', '04', '05', 'SANTO DOMINGO', '40405'),
    ('CR', '4', '04', '06', 'PURABÁ', '40406'),
    ('CR', '4', '05', '01', 'SAN RAFAEL', '40501'),
    ('CR', '4', '05', '02', 'SAN JOSECITO', '40502'),
    ('CR', '4', '05', '03', 'SANTIAGO', '40503'),
    ('CR', '4', '05', '04', 'ÁNGELES', '40504'),
    ('CR', '4', '05', '05', 'CONCEPCIÓN', '40505'),
    ('CR', '4', '06', '01', 'SAN ISIDRO', '40601'),
    ('CR', '4', '06', '02', 'SAN JOSÉ', '40602'),
    ('CR', '4', '06', '03', 'CONCEPCIÓN', '40603'),
    ('CR', '4', '06', '04', 'SAN FRANCISCO', '40604'),
    ('CR', '4', '07', '01', 'SAN ANTONIO', '40701'),
    ('CR', '4', '07', '02', 'LA RIBERA', '40702'),
    ('CR', '4', '07', '03', 'LA ASUNCIÓN', '40703'),
    ('CR', '4', '08', '01', 'SAN JOAQUÍN', '40801'),
    ('CR', '4', '08', '02', 'BARRANTES', '40802'),
    ('CR', '4', '08', '03', 'LLORENTE', '40803'),
    ('CR', '4', '09', '01', 'SAN PABLO', '40901'),
    ('CR', '4', '09', '02', 'RINCÓN DE SABANILLA', '40902'),
    ('CR', '4', '10', '01', 'PUERTO VIEJO', '41001'),
    ('CR', '4', '10', '02', 'LA VIRGEN', '41002'),
    ('CR', '4', '10', '03', 'LAS HORQUETAS', '41003'),
    ('CR', '4', '10', '04', 'LLANURAS DEL GASPAR', '41004'),
    ('CR', '4', '10', '05', 'CUREÑA', '41005'),
    ('CR', '5', '01', '01', 'LIBERIA', '50101'),
    ('CR', '5', '01', '02', 'CAÑAS DULCES', '50102'),
    ('CR', '5', '01', '03', 'MAYORGA', '50103'),
    ('CR', '5', '01', '04', 'NACASCOLO', '50104'),
    ('CR', '5', '01', '05', 'CURUBANDÉ', '50105'),
    ('CR', '5', '02', '01', 'NICOYA', '50201'),
    ('CR', '5', '02', '02', 'MANSIÓN', '50202'),
    ('CR', '5', '02', '03', 'SAN ANTONIO', '50203'),
    ('CR', '5', '02', '04', 'QUEBRADA HONDA', '50204'),
    ('CR', '5', '02', '05', 'SÁMARA', '50205'),
    ('CR', '5', '02', '06', 'NOSARA', '50206'),
    ('CR', '5', '02', '07', 'BELÉN DE NOSARITA', '50207'),
    ('CR', '5', '03', '01', 'SANTA CRUZ', '50301'),
    ('CR', '5', '03', '02', 'BOLSÓN', '50302'),
    ('CR', '5', '03', '03', 'VEINTISIETE DE ABRIL', '50303'),
    ('CR', '5', '03', '04', 'TEMPATE', '50304'),
    ('CR', '5', '03', '05', 'CARTAGENA', '50305'),
    ('CR', '5', '03', '06', 'CUAJINIQUIL', '50306'),
    ('CR', '5', '03', '07', 'DIRIÁ', '50307'),
    ('CR', '5', '03', '08', 'CABO VELAS', '50308'),
    ('CR', '5', '03', '09', 'TAMARINDO', '50309'),
    ('CR', '5', '04', '01', 'BAGACES', '50401'),
    ('CR', '5', '04', '02', 'LA FORTUNA', '50402'),
    ('CR', '5', '04', '03', 'MOGOTE', '50403'),
    ('CR', '5', '04', '04', 'RÍO NARANJO', '50404'),
    ('CR', '5', '05', '01', 'FILADELFIA', '50501'),
    ('CR', '5', '05', '02', 'PALMIRA', '50502'),
    ('CR', '5', '05', '03', 'SARDINAL', '50503'),
    ('CR', '5', '05', '04', 'BELÉN', '50504'),
    ('CR', '5', '06', '01', 'CAÑAS', '50601'),
    ('CR', '5', '06', '02', 'PALMIRA', '50602'),
    ('CR', '5', '06', '03', 'SAN MIGUEL', '50603'),
    ('CR', '5', '06', '04', 'BEBEDERO', '50604'),
    ('CR', '5', '06', '05', 'POROZAL', '50605'),
    ('CR', '5', '07', '01', 'LAS JUNTAS', '50701'),
    ('CR', '5', '07', '02', 'SIERRA', '50702'),
    ('CR', '5', '07', '03', 'SAN JUAN', '50703'),
    ('CR', '5', '07', '04', 'COLORADO', '50704'),
    ('CR', '5', '08', '01', 'TILARÁN', '50801'),
    ('CR', '5', '08', '02', 'QUEBRADA GRANDE', '50802'),
    ('CR', '5', '08', '03', 'TRONADORA', '50803'),
    ('CR', '5', '08', '04', 'SANTA ROSA', '50804'),
    ('CR', '5', '08', '05', 'LÍBANO', '50805'),
    ('CR', '5', '08', '06', 'TIERRAS MORENAS', '50806'),
    ('CR', '5', '08', '07', 'ARENAL', '50807'),
    ('CR', '5', '08', '08', 'CABECERAS', '50808'),
    ('CR', '5', '09', '01', 'CARMONA', '50901'),
    ('CR', '5', '09', '02', 'SANTA RITA', '50902'),
    ('CR', '5', '09', '03', 'ZAPOTAL', '50903'),
    ('CR', '5', '09', '04', 'SAN PABLO', '50904'),
    ('CR', '5', '09', '05', 'PORVENIR', '50905'),
    ('CR', '5', '09', '06', 'BEJUCO', '50906'),
    ('CR', '5', '10', '01', 'LA CRUZ', '51001'),
    ('CR', '5', '10', '02', 'SANTA CECILIA', '51002'),
    ('CR', '5', '10', '03', 'LA GARITA', '51003'),
    ('CR', '5', '10', '04', 'SANTA ELENA', '51004'),
    ('CR', '5', '11', '01', 'HOJANCHA', '51101'),
    ('CR', '5', '11', '02', 'MONTE ROMO', '51102'),
    ('CR', '5', '11', '03', 'PUERTO CARRILLO', '51103'),
    ('CR', '5', '11', '04', 'HUACAS', '51104'),
    ('CR', '5', '11', '05', 'MATAMBÚ', '51105'),
    ('CR', '6', '01', '01', 'PUNTARENAS', '60101'),
    ('CR', '6', '01', '02', 'PITAHAYA', '60102'),
    ('CR', '6', '01', '03', 'CHOMES', '60103'),
    ('CR', '6', '01', '04', 'LEPANTO', '60104'),
    ('CR', '6', '01', '05', 'PAQUERA', '60105'),
    ('CR', '6', '01', '06', 'MANZANILLO', '60106'),
    ('CR', '6', '01', '07', 'GUACIMAL', '60107'),
    ('CR', '6', '01', '08', 'BARRANCA', '60108'),
    ('CR', '6', '01', '10', 'ISLA DEL COCO', '60110'),
    ('CR', '6', '01', '11', 'CÓBANO', '60111'),
    ('CR', '6', '01', '12', 'CHACARITA', '60112'),
    ('CR', '6', '01', '13', 'CHIRA', '60113'),
    ('CR', '6', '01', '14', 'ACAPULCO', '60114'),
    ('CR', '6', '01', '15', 'EL ROBLE', '60115'),
    ('CR', '6', '01', '16', 'ARANCIBIA', '60116'),
    ('CR', '6', '02', '01', 'ESPÍRITU SANTO', '60201'),
    ('CR', '6', '02', '02', 'SAN JUAN GRANDE', '60202'),
    ('CR', '6', '02', '03', 'MACACONA', '60203'),
    ('CR', '6', '02', '04', 'SAN RAFAEL', '60204'),
    ('CR', '6', '02', '05', 'SAN JERÓNIMO', '60205'),
    ('CR', '6', '02', '06', 'CALDERA', '60206'),
    ('CR', '6', '03', '01', 'BUENOS AIRES', '60301'),
    ('CR', '6', '03', '02', 'VOLCÁN', '60302'),
    ('CR', '6', '03', '03', 'POTRERO GRANDE', '60303'),
    ('CR', '6', '03', '04', 'BORUCA', '60304'),
    ('CR', '6', '03', '05', 'PILAS', '60305'),
    ('CR', '6', '03', '06', 'COLINAS', '60306'),
    ('CR', '6', '03', '07', 'CHÁNGUENA', '60307'),
    ('CR', '6', '03', '08', 'BIOLLEY', '60308'),
    ('CR', '6', '03', '09', 'BRUNKA', '60309'),
    ('CR', '6', '04', '01', 'MIRAMAR', '60401'),
    ('CR', '6', '04', '02', 'LA UNIÓN', '60402'),
    ('CR', '6', '04', '03', 'SAN ISIDRO', '60403'),
    ('CR', '6', '05', '01', 'PUERTO CORTÉS', '60501'),
    ('CR', '6', '05', '02', 'PALMAR', '60502'),
    ('CR', '6', '05', '03', 'SIERPE', '60503'),
    ('CR', '6', '05', '04', 'BAHÍA BALLENA', '60504'),
    ('CR', '6', '05', '05', 'PIEDRAS BLANCAS', '60505'),
    ('CR', '6', '05', '06', 'BAHÍA DRAKE', '60506'),
    ('CR', '6', '06', '01', 'QUEPOS', '60601'),
    ('CR', '6', '06', '02', 'SAVEGRE', '60602'),
    ('CR', '6', '06', '03', 'NARANJITO', '60603'),
    ('CR', '6', '07', '01', 'GOLFITO', '60701'),
    ('CR', '6', '07', '03', 'GUAYCARÁ', '60703'),
    ('CR', '6', '07', '04', 'PAVÓN', '60704'),
    ('CR', '6', '08', '01', 'SAN VITO', '60801'),
    ('CR', '6', '08', '02', 'SABALITO', '60802'),
    ('CR', '6', '08', '03', 'AGUABUENA', '60803'),
    ('CR', '6', '08', '04', 'LIMONCITO', '60804'),
    ('CR', '6', '08', '05', 'PITTIER', '60805'),
    ('CR', '6', '08', '06', 'GUTIÉRREZ BRAUN', '60806'),
    ('CR', '6', '09', '01', 'PARRITA', '60901'),
    ('CR', '6', '10', '01', 'CORREDOR', '61001'),
    ('CR', '6', '10', '02', 'LA CUESTA', '61002'),
    ('CR', '6', '10', '03', 'CANOAS', '61003'),
    ('CR', '6', '10', '04', 'LAUREL', '61004'),
    ('CR', '6', '11', '01', 'JACÓ', '61101'),
    ('CR', '6', '11', '02', 'TÁRCOLES', '61102'),
    ('CR', '6', '12', '01', 'MONTEVERDE', '61201'),
    ('CR', '6', '13', '01', 'PUERTO JIMÉNEZ', '61301'),
    ('CR', '7', '01', '01', 'LIMÓN', '70101'),
    ('CR', '7', '01', '02', 'VALLE LA ESTRELLA', '70102'),
    ('CR', '7', '01', '03', 'RÍO BLANCO', '70103'),
    ('CR', '7', '01', '04', 'MATAMA', '70104'),
    ('CR', '7', '02', '01', 'GUÁPILES', '70201'),
    ('CR', '7', '02', '02', 'JIMÉNEZ', '70202'),
    ('CR', '7', '02', '03', 'RITA', '70203'),
    ('CR', '7', '02', '04', 'ROXANA', '70204'),
    ('CR', '7', '02', '05', 'CARIARI', '70205'),
    ('CR', '7', '02', '06', 'COLORADO', '70206'),
    ('CR', '7', '02', '07', 'LA COLONIA', '70207'),
    ('CR', '7', '03', '01', 'SIQUIRRES', '70301'),
    ('CR', '7', '03', '02', 'PACUARITO', '70302'),
    ('CR', '7', '03', '03', 'FLORIDA', '70303'),
    ('CR', '7', '03', '04', 'GERMANIA', '70304'),
    ('CR', '7', '03', '05', 'EL CAIRO', '70305'),
    ('CR', '7', '03', '06', 'ALEGRÍA', '70306'),
    ('CR', '7', '03', '07', 'REVENTAZÓN', '70307'),
    ('CR', '7', '04', '01', 'BRATSI', '70401'),
    ('CR', '7', '04', '02', 'SIXAOLA', '70402'),
    ('CR', '7', '04', '03', 'CAHUITA', '70403'),
    ('CR', '7', '04', '04', 'TELIRE', '70404'),
    ('CR', '7', '05', '01', 'MATINA', '70501'),
    ('CR', '7', '05', '02', 'BATÁN', '70502'),
    ('CR', '7', '05', '03', 'CARRANDI', '70503'),
    ('CR', '7', '06', '01', 'GUÁCIMO', '70601'),
    ('CR', '7', '06', '02', 'MERCEDES', '70602'),
    ('CR', '7', '06', '03', 'POCORA', '70603'),
    ('CR', '7', '06', '04', 'RÍO JIMÉNEZ', '70604'),
    ('CR', '7', '06', '05', 'DUACARÍ', '70605')
    ON DUPLICATE KEY UPDATE nombre_distrito = VALUES(nombre_distrito),
                            codigo_postal   = VALUES(codigo_postal);

SET @muni_sin_auditoria = 0;

-- =====================================================================
-- Revisión: debe dar 7 | 84 | 491 y los catálogos con datos
-- =====================================================================
SELECT (SELECT COUNT(*) FROM geo_provincias WHERE cod_pais = 'CR') AS provincias,
       (SELECT COUNT(*) FROM geo_cantones   WHERE cod_pais = 'CR') AS cantones,
       (SELECT COUNT(*) FROM geo_distritos  WHERE cod_pais = 'CR') AS distritos,
       (SELECT COUNT(*) FROM cat_roles_usuarios)          AS roles,
       (SELECT COUNT(*) FROM cat_tipos_identificaciones)  AS tipos_identificacion,
       (SELECT COUNT(*) FROM cat_categorias_proveedores)  AS categorias_proveedores;
