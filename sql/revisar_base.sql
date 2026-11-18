-- =====================================================================
--  revisar_base.sql - ¿La base gestion_redes está como debe?
-- ---------------------------------------------------------------------
--  Módulos de usuarios y proveedores, de equipos municipales, de
--  análisis de logs y de correo institucional. Compara la base con lo
--  que crean los scripts de las carpetas instalacion, dispositivos, logs
--  y correo:
--    - 49 tablas con sus 344 columnas
--    - 250 procedimientos (parámetros y contenido) y 4 funciones
--    - 213 disparadores
--    - los datos iniciales de los catálogos y el usuario administrador
--  No cambia nada en la base: solo lee.
--
--  Ejecutar en el servidor, desde la carpeta sql:
--     mariadb -u admin_db -p --table < revisar_base.sql
--  (lo ejecuta también reinstalar_base.sh al terminar).
--
--  Al final dice TODO BIEN, o muestra cada problema con el script que
--  lo arregla. ERROR = el sistema puede fallar; AVISO = conviene revisarlo.
-- =====================================================================

USE gestion_redes;

SET NAMES utf8mb4;
SET SESSION group_concat_max_len = 1000000;

-- ------------------------------------------------- lo que debe existir
-- tipo, nombre, detalle (columna / tabla), valor (tipo de columna,
-- parámetros o filas mínimas), archivo que lo crea
DROP TEMPORARY TABLE IF EXISTS rev_esperado;
CREATE TEMPORARY TABLE rev_esperado (
    tipo    VARCHAR(20)   NOT NULL,
    nombre  VARCHAR(64)   NOT NULL,
    detalle VARCHAR(64)   NULL,
    valor   VARCHAR(4000) NULL,
    archivo VARCHAR(64)   NOT NULL,
    huella  CHAR(32)      NULL
) CHARACTER SET utf8 COLLATE utf8_general_ci;

INSERT INTO rev_esperado (tipo, nombre, detalle, valor, archivo, huella) VALUES
    ('TABLA', 'geo_paises', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_paises', 'cod_pais', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_paises', 'nombre_pais', 'varchar:100', '01_estructura.sql', NULL),
    ('TABLA', 'geo_provincias', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_provincias', 'cod_pais', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_provincias', 'cod_provincia', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_provincias', 'nombre_provincia', 'varchar:100', '01_estructura.sql', NULL),
    ('TABLA', 'geo_cantones', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_cantones', 'cod_pais', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_cantones', 'cod_provincia', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_cantones', 'cod_canton', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_cantones', 'nombre_canton', 'varchar:100', '01_estructura.sql', NULL),
    ('TABLA', 'geo_distritos', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_distritos', 'cod_pais', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_distritos', 'cod_provincia', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_distritos', 'cod_canton', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_distritos', 'cod_distrito', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_distritos', 'nombre_distrito', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'geo_distritos', 'codigo_postal', 'varchar:10', '01_estructura.sql', NULL),
    ('TABLA', 'cat_tipos_identificaciones', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_identificaciones', 'cod_tipo_identificacion', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_identificaciones', 'descripcion', 'varchar:50', '01_estructura.sql', NULL),
    ('TABLA', 'cat_roles_usuarios', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_roles_usuarios', 'cod_rol', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_roles_usuarios', 'descripcion', 'varchar:50', '01_estructura.sql', NULL),
    ('TABLA', 'cat_tipos_autenticaciones', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_autenticaciones', 'cod_tipo_auth', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_autenticaciones', 'descripcion', 'varchar:80', '01_estructura.sql', NULL),
    ('TABLA', 'cat_departamentos', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_departamentos', 'cod_departamento', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_departamentos', 'descripcion', 'varchar:120', '01_estructura.sql', NULL),
    ('TABLA', 'cat_tipos_telefonos', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_telefonos', 'cod_telefono', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_telefonos', 'descripcion', 'varchar:50', '01_estructura.sql', NULL),
    ('TABLA', 'cat_tipos_correos', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_correos', 'cod_correo', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_tipos_correos', 'descripcion', 'varchar:50', '01_estructura.sql', NULL),
    ('TABLA', 'cat_categorias_proveedores', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_categorias_proveedores', 'cod_categoria', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'cat_categorias_proveedores', 'descripcion', 'varchar:150', '01_estructura.sql', NULL),
    ('TABLA', 'personas', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'id', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'es_proveedor', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_categoria', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_rol', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_tipo_auth', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_tipo_identificacion', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'dni', 'varchar:30', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'nombre', 'varchar:150', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'apellido1', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'apellido2', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_pais', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_provincia', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_canton', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_distrito', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'codigo_postal', 'varchar:10', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'otras_senas', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'mapa', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'imagen_path', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'archivo_path', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'cod_departamento', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'usuario_red', 'varchar:50', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'password_hash', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'activo', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'creado_en', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'personas', 'actualizado_en', NULL, '01_estructura.sql', NULL),
    ('TABLA', 'usr_telefonos', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_telefonos', 'id_usuario', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_telefonos', 'num_linea', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_telefonos', 'cod_telefono', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_telefonos', 'telefono', 'varchar:25', '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_telefonos', 'es_whatsapp', NULL, '01_estructura.sql', NULL),
    ('TABLA', 'usr_correos', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_correos', 'id_usuario', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_correos', 'num_linea', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_correos', 'cod_correo', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_correos', 'correo', 'varchar:150', '01_estructura.sql', NULL),
    ('TABLA', 'usr_paginas_webs', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_paginas_webs', 'id_usuario', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_paginas_webs', 'num_linea', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_paginas_webs', 'url_web', 'varchar:255', '01_estructura.sql', NULL),
    ('TABLA', 'usr_historiales_claves', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_historiales_claves', 'id_usuario', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_historiales_claves', 'num_linea', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_historiales_claves', 'password_hash', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'usr_historiales_claves', 'fecha_registro', NULL, '01_estructura.sql', NULL),
    ('TABLA', 'aud_auditorias', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'id', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'fecha', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'id_usuario', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'nombre_usuario', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'ip', 'varchar:45', '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'accion', 'varchar:20', '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'tabla', 'varchar:64', '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'llave', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'id_persona', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'descripcion', 'varchar:255', '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'datos_antes', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'aud_auditorias', 'datos_despues', NULL, '01_estructura.sql', NULL),
    ('TABLA', 'pad_padron', NULL, NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'cedula', 'varchar:9', '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'nombre', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'apellido1', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'apellido2', 'varchar:100', '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'sexo', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'vencimiento', NULL, '01_estructura.sql', NULL),
    ('COLUMNA', 'pad_padron', 'codelec', 'varchar:6', '01_estructura.sql', NULL),
    ('TABLA', 'categoria_equipos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'categoria_equipos', 'id_categoria', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'categoria_equipos', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'categoria_equipos', 'lleva_agente', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'tipo_equipos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_equipos', 'tipo_equipo', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_equipos', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_equipos', 'id_categoria', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'marcas', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'marcas', 'id_marca', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'marcas', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'marcas', 'tipo_equipo', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'modelos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'modelos', 'id_modelo', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'modelos', 'descripcion', 'varchar:150', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'modelos', 'id_marca', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'procesadores', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'procesadores', 'id_proc', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'procesadores', 'descripcion', 'varchar:150', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'sis_operativos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'sis_operativos', 'id_so', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'sis_operativos', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'firmwares', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'firmwares', 'id_firmw', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'firmwares', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'edificios', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'id_predio', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'descripcion', 'varchar:150', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'id_pais', 'varchar:10', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'id_provincia', 'varchar:10', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'id_canton', 'varchar:10', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'id_distrito', 'varchar:10', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'ubicacion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'edificios', 'otras_senas', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'estado_equipos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'estado_equipos', 'id_estado', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'estado_equipos', 'descripcion', 'varchar:50', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'tipo_roles', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_roles', 'id_rol', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_roles', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'tipo_herramientas', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_herramientas', 'id_herram', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_herramientas', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'tipo_archivos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_archivos', 'tipo_arch', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'tipo_archivos', 'descripcion', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'equipos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'tipo_equipo', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'serie', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_marca', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_modelo', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'nombre_equipo', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'placa_equipo', 'varchar:50', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_proces', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_mem', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_almac', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_serie', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_usb', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_eth', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_sfp', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_wireless', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_bluetooth', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cant_ptos_celular', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_so', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_firmw', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_predio', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'ubicacion', 'varchar:255', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_estado', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_usuario', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'id_proveedor', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'tipo_almacenamiento', 'varchar:10', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'extension', 'varchar:10', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'tecnologia_impresion', 'varchar:20', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'a_color', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'consumible', 'varchar:100', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'pulgadas', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'resolucion', 'varchar:20', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'capacidad_va', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'autonomia_min', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'canales', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'cod_departamento', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'fecha_compra', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'garantia_hasta', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'observaciones', 'varchar:500', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'sfp_combo', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'creado_en', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'equipos', 'actualizado_en', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'roles', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'roles', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'roles', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'roles', 'id_rol', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'herramientas', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'herramientas', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'herramientas', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'herramientas', 'id_herram', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'dir_macs', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_macs', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_macs', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_macs', 'dir_mac', 'char:12', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_macs', 'interfaz', 'varchar:50', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'dir_ips', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_ips', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_ips', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_ips', 'dir_ip', 'varchar:45', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_ips', 'interfaz', 'varchar:50', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'num_moviles', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'num_moviles', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'num_moviles', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'num_moviles', 'num_movil', 'varchar:20', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'num_moviles', 'operador', 'varchar:50', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'dir_imeis', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_imeis', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_imeis', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'dir_imeis', 'dir_imei', 'varchar:15', 'creacionDispositivo.sql', NULL),
    ('TABLA', 'archivos', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'archivos', 'id', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'archivos', 'num_linea', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'archivos', 'tipo_arch', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'archivos', 'path_arch', 'varchar:255', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'archivos', 'creado_en', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'puertos_switch', NULL, NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'id_switch', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'tipo_puerto', 'char:1', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'num_puerto', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'id_equipo', NULL, 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'estado', 'varchar:15', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'vlan', 'varchar:30', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'nota', 'varchar:255', 'creacionDispositivo.sql', NULL),
    ('COLUMNA', 'puertos_switch', 'actualizado_en', NULL, 'creacionDispositivo.sql', NULL),
    ('TABLA', 'log_importaciones', NULL, NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'id_importacion', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'fuente', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'nombre_archivo', 'varchar:255', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'descripcion', 'varchar:255', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'total_leidos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'total_eventos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'repetidos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'permitidos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'denegados', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'avisos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'fecha_desde', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'fecha_hasta', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'id_usuario', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_importaciones', 'creado_en', NULL, 'creacionLogs.sql', NULL),
    ('TABLA', 'log_eventos', NULL, NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'id_evento', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'id_importacion', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'fuente', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'huella', 'char:32', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'fecha', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'tipo', 'varchar:60', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'accion', 'varchar:12', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'tipo_log', 'varchar:60', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'componente', 'varchar:60', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'subtipo', 'varchar:60', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'descripcion', 'varchar:255', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'dispositivo', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'id_mensaje', 'varchar:20', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'severidad', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'regla_id', 'varchar:20', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'regla_nombre', 'varchar:150', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'regla_seccion', 'varchar:60', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'nat_regla_id', 'varchar:20', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'nat_regla', 'varchar:150', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'politica_web', 'varchar:150', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'actividad', 'varchar:150', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'motivo', 'varchar:255', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'usuario', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'grupo_usuario', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'ip_origen', 'varchar:45', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'puerto_origen', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'mac_origen', 'char:12', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'pais_origen', 'varchar:10', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'zona_origen', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'interfaz_entrada', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'ip_origen_nat', 'varchar:45', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'nombre_equipo', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'sistema_operativo', 'varchar:150', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'ip_destino', 'varchar:45', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'puerto_destino', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'mac_destino', 'char:12', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'pais_destino', 'varchar:10', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'zona_destino', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'interfaz_salida', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'ip_destino_nat', 'varchar:45', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'dominio', 'varchar:255', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'url', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'categoria', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'categoria_tipo', 'varchar:50', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'codigo_http', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'tipo_contenido', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'navegador', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'aplicacion', 'varchar:150', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'aplicacion_categoria', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'aplicacion_riesgo', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'version_tls', 'varchar:20', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'cifrado', 'varchar:100', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'version_agente', 'varchar:50', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'vacunas_aplicadas', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'vacunas_pendientes', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'vacunas_error', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'protocolo', 'varchar:20', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'bytes_enviados', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'bytes_recibidos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'paquetes_enviados', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'paquetes_recibidos', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'duracion', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'id_conexion', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_eventos', 'datos', NULL, 'creacionLogs.sql', NULL),
    ('TABLA', 'log_direcciones', NULL, NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_direcciones', 'id_evento', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_direcciones', 'id_importacion', NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_direcciones', 'tipo', 'char:3', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_direcciones', 'direccion', 'varchar:45', 'creacionLogs.sql', NULL),
    ('TABLA', 'log_mapeo_campos', NULL, NULL, 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_mapeo_campos', 'fuente', 'varchar:30', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_mapeo_campos', 'campo_origen', 'varchar:64', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_mapeo_campos', 'campo', 'varchar:64', 'creacionLogs.sql', NULL),
    ('COLUMNA', 'log_mapeo_campos', 'prioridad', NULL, 'creacionLogs.sql', NULL),
    ('TABLA', 'cor_configuracion', NULL, NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'id_config', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'servidor', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'puerto', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'seguridad', 'varchar:10', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'usuario', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'clave_cifrada', 'varchar:1000', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'correo_remitente', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'nombre_remitente', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'responder_a', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'firma', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'limite_diario', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'activo', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'ultima_prueba', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'prueba_ok', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'resultado_prueba', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'id_usuario', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_configuracion', 'actualizado_en', NULL, 'creacionCorreo.sql', NULL),
    ('TABLA', 'cor_envios', NULL, NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'id_envio', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'asunto', 'varchar:200', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'mensaje', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'destinatarios', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'remitente', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'estado', 'varchar:12', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'total', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'enviados', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'errores', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'id_usuario', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'creado_en', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios', 'terminado_en', NULL, 'creacionCorreo.sql', NULL),
    ('TABLA', 'cor_envios_destinatarios', NULL, NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'id_envio', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'num_linea', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'id_persona', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'nombre', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'correo', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'estado', 'varchar:10', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'error', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_destinatarios', 'enviado_en', NULL, 'creacionCorreo.sql', NULL),
    ('TABLA', 'cor_envios_adjuntos', NULL, NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_adjuntos', 'id_envio', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_adjuntos', 'num_linea', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_adjuntos', 'nombre_archivo', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_adjuntos', 'ruta', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_adjuntos', 'tamano', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_envios_adjuntos', 'tipo', 'varchar:100', 'creacionCorreo.sql', NULL),
    ('TABLA', 'cor_listas', NULL, NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'id_lista', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'origen', 'varchar:10', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'nombre_archivo', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'descripcion', 'varchar:255', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'dominio', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'total', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'id_usuario', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas', 'creado_en', NULL, 'creacionCorreo.sql', NULL),
    ('TABLA', 'cor_listas_correos', NULL, NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'id_lista', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'num_linea', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'correo', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'nombre', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'apellidos', 'varchar:150', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'estado', 'varchar:30', 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'ultimo_acceso', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'nunca_entro', NULL, 'creacionCorreo.sql', NULL),
    ('COLUMNA', 'cor_listas_correos', 'uso_gb', NULL, 'creacionCorreo.sql', NULL),
    ('FUNCION', 'fn_formato_telefono', NULL, 'p_telefono', '02_procedimientos.sql', 'e81ff0d30771165129f5094de7b8edfc'),
    ('PROCEDIMIENTO', 'sp_geo_paises_insertar', NULL, 'IN p_cod_pais, IN p_nombre_pais', '02_procedimientos.sql', '3cd3eb175418d8cc224320eed5748a67'),
    ('PROCEDIMIENTO', 'sp_geo_paises_actualizar', NULL, 'IN p_cod_pais, IN p_nombre_pais', '02_procedimientos.sql', '01a79361c1a7c12aaeba9546af483cdd'),
    ('PROCEDIMIENTO', 'sp_geo_paises_eliminar', NULL, 'IN p_cod_pais', '02_procedimientos.sql', 'f62afaaea12225dbef256bdeadead1a5'),
    ('PROCEDIMIENTO', 'sp_geo_paises_obtener', NULL, 'IN p_cod_pais', '02_procedimientos.sql', '6c2c9084b224e32e500f9d0885041b2f'),
    ('PROCEDIMIENTO', 'sp_geo_paises_listar', NULL, '', '02_procedimientos.sql', 'c3940ed46154fed853af0ee7d694c480'),
    ('PROCEDIMIENTO', 'sp_geo_provincias_insertar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_nombre_provincia', '02_procedimientos.sql', '5381bcbd046548e824fe955b664ff81e'),
    ('PROCEDIMIENTO', 'sp_geo_provincias_actualizar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_nombre_provincia', '02_procedimientos.sql', '834cd1c4c90b1c5094749c188e4a2f8d'),
    ('PROCEDIMIENTO', 'sp_geo_provincias_eliminar', NULL, 'IN p_cod_pais, IN p_cod_provincia', '02_procedimientos.sql', 'cbef57813a4d50853ae1c67e47d2ad96'),
    ('PROCEDIMIENTO', 'sp_geo_provincias_obtener', NULL, 'IN p_cod_pais, IN p_cod_provincia', '02_procedimientos.sql', '9afa25eaad11ec9e654b489b259ae472'),
    ('PROCEDIMIENTO', 'sp_geo_provincias_listar', NULL, 'IN p_cod_pais', '02_procedimientos.sql', 'e92933472041aa8fae48532d056b9354'),
    ('PROCEDIMIENTO', 'sp_geo_cantones_insertar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_nombre_canton', '02_procedimientos.sql', '6d512335ed9185efb255e5354b72ff71'),
    ('PROCEDIMIENTO', 'sp_geo_cantones_actualizar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_nombre_canton', '02_procedimientos.sql', 'fac637b76830413f95ad0ef6c249eaec'),
    ('PROCEDIMIENTO', 'sp_geo_cantones_eliminar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton', '02_procedimientos.sql', '7dc125b2aa4363738d0d72323d71b733'),
    ('PROCEDIMIENTO', 'sp_geo_cantones_obtener', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton', '02_procedimientos.sql', '217bbff41eca6e75fa531171bd9509b2'),
    ('PROCEDIMIENTO', 'sp_geo_cantones_listar', NULL, 'IN p_cod_pais, IN p_cod_provincia', '02_procedimientos.sql', 'a6fe4dd69ea808187691ec5cd1af7e8f'),
    ('PROCEDIMIENTO', 'sp_geo_distritos_insertar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito, IN p_nombre_distrito, IN p_codigo_postal', '02_procedimientos.sql', '208f9d2f70ce65f61762b349775ffa34'),
    ('PROCEDIMIENTO', 'sp_geo_distritos_actualizar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito, IN p_nombre_distrito, IN p_codigo_postal', '02_procedimientos.sql', '01b43a8706efe9ee4cdc63b695ca054f'),
    ('PROCEDIMIENTO', 'sp_geo_distritos_eliminar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito', '02_procedimientos.sql', 'c2e4819fb211b767295bd927d005830d'),
    ('PROCEDIMIENTO', 'sp_geo_distritos_obtener', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito', '02_procedimientos.sql', '700baff391f59a2b67c8375129b971f0'),
    ('PROCEDIMIENTO', 'sp_geo_distritos_listar', NULL, 'IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton', '02_procedimientos.sql', '9aa69737cd8e08c6190954a43c47315f'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_identificaciones_insertar', NULL, 'IN p_descripcion, OUT p_cod_tipo_identificacion', '02_procedimientos.sql', 'be02d7645feb93ba24e153d67e4e21ab'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_identificaciones_actualizar', NULL, 'IN p_cod_tipo_identificacion, IN p_descripcion', '02_procedimientos.sql', '2d21a68deba344df97213fe75a6e87de'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_identificaciones_eliminar', NULL, 'IN p_cod_tipo_identificacion', '02_procedimientos.sql', '40f43bc2c6751fd3fcae0d75ac3fb7ad'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_identificaciones_obtener', NULL, 'IN p_cod_tipo_identificacion', '02_procedimientos.sql', 'c7b2a564d4cd37ac65f25655871ae5a4'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_identificaciones_listar', NULL, '', '02_procedimientos.sql', '915c037a1078c282b24be356d115351f'),
    ('PROCEDIMIENTO', 'sp_cat_roles_usuarios_insertar', NULL, 'IN p_descripcion, OUT p_cod_rol', '02_procedimientos.sql', '0a3e5d729df246b50c540745558c719e'),
    ('PROCEDIMIENTO', 'sp_cat_roles_usuarios_actualizar', NULL, 'IN p_cod_rol, IN p_descripcion', '02_procedimientos.sql', '1673004f45ebbe36d21230471382df7f'),
    ('PROCEDIMIENTO', 'sp_cat_roles_usuarios_eliminar', NULL, 'IN p_cod_rol', '02_procedimientos.sql', '3a23c11e0459a4dbb38f778913c60de4'),
    ('PROCEDIMIENTO', 'sp_cat_roles_usuarios_obtener', NULL, 'IN p_cod_rol', '02_procedimientos.sql', '4d7ad1e868d487fe37f0e89a472b8c66'),
    ('PROCEDIMIENTO', 'sp_cat_roles_usuarios_listar', NULL, '', '02_procedimientos.sql', '41e242b10254dbb1082346b4291d2a34'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_autenticaciones_insertar', NULL, 'IN p_descripcion, OUT p_cod_tipo_auth', '02_procedimientos.sql', '22233a97b9d88906bdcf7936abdad780'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_autenticaciones_actualizar', NULL, 'IN p_cod_tipo_auth, IN p_descripcion', '02_procedimientos.sql', 'bfce06cad7a20c82cff2c4cc2dc54e54'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_autenticaciones_eliminar', NULL, 'IN p_cod_tipo_auth', '02_procedimientos.sql', '4c519b991adc33f4089f4962a17be1ee'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_autenticaciones_obtener', NULL, 'IN p_cod_tipo_auth', '02_procedimientos.sql', 'a4406c2d87d7e96d34bfe0c01a3986ff'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_autenticaciones_listar', NULL, '', '02_procedimientos.sql', '3209f3e737a35107db84260cad604a67'),
    ('PROCEDIMIENTO', 'sp_cat_departamentos_insertar', NULL, 'IN p_descripcion, OUT p_cod_departamento', '02_procedimientos.sql', '1b8a58a3bcc9ccb0a5f7cc9a9a7fc5d4'),
    ('PROCEDIMIENTO', 'sp_cat_departamentos_actualizar', NULL, 'IN p_cod_departamento, IN p_descripcion', '02_procedimientos.sql', '95e98d30b7d8864dd94ccf6fe30a11fe'),
    ('PROCEDIMIENTO', 'sp_cat_departamentos_eliminar', NULL, 'IN p_cod_departamento', '02_procedimientos.sql', 'f10587c0e864c6664f6f43a9dcc15fd5'),
    ('PROCEDIMIENTO', 'sp_cat_departamentos_obtener', NULL, 'IN p_cod_departamento', '02_procedimientos.sql', '85a4da44268bcd4e859437ddad5d8b21'),
    ('PROCEDIMIENTO', 'sp_cat_departamentos_listar', NULL, '', '02_procedimientos.sql', 'a32c72d165bac882c044444259f764a7'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_telefonos_insertar', NULL, 'IN p_descripcion, OUT p_cod_telefono', '02_procedimientos.sql', '71301c4c7429e5066c93b704c6f1c658'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_telefonos_actualizar', NULL, 'IN p_cod_telefono, IN p_descripcion', '02_procedimientos.sql', '528f0a7b53c2ada131ed1eccea7ebb7a'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_telefonos_eliminar', NULL, 'IN p_cod_telefono', '02_procedimientos.sql', '9155ab04874e78a6ec069fb4469d6c73'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_telefonos_obtener', NULL, 'IN p_cod_telefono', '02_procedimientos.sql', 'cf6034d79906e40f27fd38549df1b62f'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_telefonos_listar', NULL, '', '02_procedimientos.sql', '7a012aca2e00cd4ad79534aebe056d78'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_correos_insertar', NULL, 'IN p_descripcion, OUT p_cod_correo', '02_procedimientos.sql', 'f6a48405e1269a294a2100e76ffc1929'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_correos_actualizar', NULL, 'IN p_cod_correo, IN p_descripcion', '02_procedimientos.sql', 'ba0ceb52686eafe9e2648c7f165c4ffb'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_correos_eliminar', NULL, 'IN p_cod_correo', '02_procedimientos.sql', 'bdbe476cd2001af5e2478cd66ff9350f'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_correos_obtener', NULL, 'IN p_cod_correo', '02_procedimientos.sql', 'a85fa8771853f6f470f7b464556a0abc'),
    ('PROCEDIMIENTO', 'sp_cat_tipos_correos_listar', NULL, '', '02_procedimientos.sql', '5e745d782eb8f6c83a2063c5dc7d9a8c'),
    ('PROCEDIMIENTO', 'sp_cat_categorias_proveedores_insertar', NULL, 'IN p_descripcion, OUT p_cod_categoria', '02_procedimientos.sql', '12bb1a63f12b5e76e04b996da1e493cf'),
    ('PROCEDIMIENTO', 'sp_cat_categorias_proveedores_actualizar', NULL, 'IN p_cod_categoria, IN p_descripcion', '02_procedimientos.sql', '816bbd950a8a69a85e798cb5dcc56ee9'),
    ('PROCEDIMIENTO', 'sp_cat_categorias_proveedores_eliminar', NULL, 'IN p_cod_categoria', '02_procedimientos.sql', 'de60a491d4b58d579b5a3b81191a0093'),
    ('PROCEDIMIENTO', 'sp_cat_categorias_proveedores_obtener', NULL, 'IN p_cod_categoria', '02_procedimientos.sql', '96706ff69d1cf2a482ffc5e870b96670'),
    ('PROCEDIMIENTO', 'sp_cat_categorias_proveedores_listar', NULL, '', '02_procedimientos.sql', '3bbf4a61004cc328296f42c009c08b27'),
    ('PROCEDIMIENTO', 'sp_personas_insertar', NULL, 'IN p_cod_rol, IN p_cod_tipo_auth, IN p_cod_tipo_identificacion, IN p_dni, IN p_nombre, IN p_apellido1, IN p_apellido2, IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito, IN p_otras_senas, IN p_imagen_path, IN p_cod_departamento, IN p_usuario_red, IN p_password_hash, OUT p_id', '02_procedimientos.sql', 'dc5160d605e2225151f8a3d999339438'),
    ('PROCEDIMIENTO', 'sp_personas_actualizar', NULL, 'IN p_id, IN p_cod_rol, IN p_cod_tipo_auth, IN p_cod_tipo_identificacion, IN p_dni, IN p_nombre, IN p_apellido1, IN p_apellido2, IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito, IN p_otras_senas, IN p_cod_departamento, IN p_usuario_red, IN p_activo', '02_procedimientos.sql', 'f348076c10c04dbeb7090f6e7841cc00'),
    ('PROCEDIMIENTO', 'sp_personas_cambiar_clave', NULL, 'IN p_id, IN p_password_hash, IN p_historial_bloqueo', '02_procedimientos.sql', '2a2f0964400b49b609ffce0d1b3ff603'),
    ('PROCEDIMIENTO', 'sp_personas_eliminar', NULL, 'IN p_id', '02_procedimientos.sql', 'e97c2e081f5f595d8f5814aff9709898'),
    ('PROCEDIMIENTO', 'sp_personas_activar', NULL, 'IN p_id', '02_procedimientos.sql', 'bd7e91fc051ab4d50daee627a8798326'),
    ('PROCEDIMIENTO', 'sp_personas_eliminar_fisico', NULL, 'IN p_id', '02_procedimientos.sql', 'f13d206eaee4591f63caf3bdcf5f96a8'),
    ('PROCEDIMIENTO', 'sp_personas_obtener', NULL, 'IN p_id', '02_procedimientos.sql', '36a001549d5a42e1628ff3bf3c89f8bd'),
    ('PROCEDIMIENTO', 'sp_personas_obtener_por_login', NULL, 'IN p_usuario_red', '02_procedimientos.sql', '25cc53dda758c5b6d853b8ba618c52a5'),
    ('PROCEDIMIENTO', 'sp_personas_listar', NULL, 'IN p_activo, IN p_cod_rol, IN p_cod_departamento, IN p_buscar', '02_procedimientos.sql', '2ba43298d7dd989cc8fdf8bfc9170a75'),
    ('PROCEDIMIENTO', 'sp_personas_actualizar_imagen', NULL, 'IN p_id, IN p_imagen_path', '02_procedimientos.sql', '9a285c49dbcfedc3d929f876f6cf891f'),
    ('PROCEDIMIENTO', 'sp_usr_telefonos_insertar', NULL, 'IN p_id_usuario, IN p_cod_telefono, IN p_telefono, IN p_es_whatsapp, OUT p_num_linea', '02_procedimientos.sql', 'c404c14d23dd3fe42bacff0c48da5ab0'),
    ('PROCEDIMIENTO', 'sp_usr_telefonos_actualizar', NULL, 'IN p_id_usuario, IN p_num_linea, IN p_cod_telefono, IN p_telefono, IN p_es_whatsapp', '02_procedimientos.sql', 'a632b0e4c5f5dc98dbee4052e51b1213'),
    ('PROCEDIMIENTO', 'sp_usr_telefonos_eliminar', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', '5d23aa55501235dbd569b69d9a16e3d7'),
    ('PROCEDIMIENTO', 'sp_usr_telefonos_obtener', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', 'ff6b3f5b851bf332f6e1a3ade4d1caaf'),
    ('PROCEDIMIENTO', 'sp_usr_telefonos_listar', NULL, 'IN p_id_usuario', '02_procedimientos.sql', 'fd382b8c598f652a9616825c7bc7f57f'),
    ('PROCEDIMIENTO', 'sp_usr_correos_insertar', NULL, 'IN p_id_usuario, IN p_cod_correo, IN p_correo, OUT p_num_linea', '02_procedimientos.sql', 'ed0438c8c5ce94daed9ea242aaf6bcd0'),
    ('PROCEDIMIENTO', 'sp_usr_correos_actualizar', NULL, 'IN p_id_usuario, IN p_num_linea, IN p_cod_correo, IN p_correo', '02_procedimientos.sql', 'a489de3ae5f3ab18751dbbdbfe01407b'),
    ('PROCEDIMIENTO', 'sp_usr_correos_eliminar', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', 'ebb2be9c56e46aa520f542b890fc1ed4'),
    ('PROCEDIMIENTO', 'sp_usr_correos_obtener', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', 'c699ab3b7e2f350c597c426b791a9d13'),
    ('PROCEDIMIENTO', 'sp_usr_correos_listar', NULL, 'IN p_id_usuario', '02_procedimientos.sql', '4153145e9f34b017829ee93b6d2d83b8'),
    ('PROCEDIMIENTO', 'sp_usr_paginas_webs_insertar', NULL, 'IN p_id_usuario, IN p_url_web, OUT p_num_linea', '02_procedimientos.sql', '01c9d0b510453f41ea0d44b2123f0f26'),
    ('PROCEDIMIENTO', 'sp_usr_paginas_webs_actualizar', NULL, 'IN p_id_usuario, IN p_num_linea, IN p_url_web', '02_procedimientos.sql', '491d0df4b3f8e1e023f361ec302b8ee6'),
    ('PROCEDIMIENTO', 'sp_usr_paginas_webs_eliminar', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', '93d8b2dc27fb90dbf074efb000754c16'),
    ('PROCEDIMIENTO', 'sp_usr_paginas_webs_obtener', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', 'fd896a71d5f23911fe029aba365effb3'),
    ('PROCEDIMIENTO', 'sp_usr_paginas_webs_listar', NULL, 'IN p_id_usuario', '02_procedimientos.sql', '19005648955a5a80f1662e8b43f9db65'),
    ('PROCEDIMIENTO', 'sp_usr_historiales_claves_insertar', NULL, 'IN p_id_usuario, IN p_password_hash, OUT p_num_linea', '02_procedimientos.sql', 'ec444f49949230f7fcae2c576ed5121d'),
    ('PROCEDIMIENTO', 'sp_usr_historiales_claves_actualizar', NULL, 'IN p_id_usuario, IN p_num_linea, IN p_password_hash', '02_procedimientos.sql', 'ceab7eceade05edb4b9074dd0b84c4de'),
    ('PROCEDIMIENTO', 'sp_usr_historiales_claves_eliminar', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', 'd0a2e925b046f19665c2ca517a872a69'),
    ('PROCEDIMIENTO', 'sp_usr_historiales_claves_obtener', NULL, 'IN p_id_usuario, IN p_num_linea', '02_procedimientos.sql', 'f5b7c34be94859fc9bfed768f6eb52d4'),
    ('PROCEDIMIENTO', 'sp_usr_historiales_claves_listar', NULL, 'IN p_id_usuario, IN p_limite', '02_procedimientos.sql', '0dc3fb4b81ff1595e109902d2f99c514'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_insertar', NULL, 'IN p_cod_tipo_identificacion, IN p_dni, IN p_nombre, IN p_apellido1, IN p_apellido2, IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito, IN p_otras_senas, IN p_mapa, IN p_cod_categoria, OUT p_id', '02_procedimientos.sql', '028c67369aaea96c60188606a512f80b'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_actualizar', NULL, 'IN p_id, IN p_cod_tipo_identificacion, IN p_dni, IN p_nombre, IN p_apellido1, IN p_apellido2, IN p_cod_pais, IN p_cod_provincia, IN p_cod_canton, IN p_cod_distrito, IN p_otras_senas, IN p_mapa, IN p_cod_categoria, IN p_activo', '02_procedimientos.sql', 'f8cbfe9d3244861fbe0888bd9e2d67d5'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_actualizar_imagen', NULL, 'IN p_id, IN p_imagen_path', '02_procedimientos.sql', '6357512fdbc0d5facf426aa0f081ad18'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_actualizar_archivo', NULL, 'IN p_id, IN p_archivo_path', '02_procedimientos.sql', '7c98f53849782389e660f4f54c962421'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_eliminar', NULL, 'IN p_id', '02_procedimientos.sql', '62fe591475829a1faa57a18b6695104d'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_activar', NULL, 'IN p_id', '02_procedimientos.sql', '8fb5ff08f23d59dfa605424642f97d61'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_eliminar_fisico', NULL, 'IN p_id', '02_procedimientos.sql', '712dc1e79d3072673dfa1fe18beb3e12'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_obtener', NULL, 'IN p_id', '02_procedimientos.sql', '8d973286252d929a77ef540ebbf3c8c0'),
    ('PROCEDIMIENTO', 'sp_prv_proveedores_listar', NULL, 'IN p_activo, IN p_cod_categoria, IN p_buscar', '02_procedimientos.sql', '5de21f868f4d28fc81641a24eb1f486c'),
    ('PROCEDIMIENTO', 'sp_aud_auditorias_registrar', NULL, 'IN p_accion, IN p_tabla, IN p_llave, IN p_id_persona, IN p_descripcion, IN p_detalle', '02_procedimientos.sql', '9b87452ad10afb08e74d91f1653bb268'),
    ('PROCEDIMIENTO', 'sp_aud_auditorias_listar', NULL, 'IN p_id_usuario, IN p_id_persona, IN p_tabla, IN p_accion, IN p_desde, IN p_hasta, IN p_buscar, IN p_limite, IN p_desplazamiento', '02_procedimientos.sql', '0f63d89d5daa55daead47994efb31bb3'),
    ('PROCEDIMIENTO', 'sp_pad_padron_consultar', NULL, 'IN p_cedula', '02_procedimientos.sql', 'a4105d56f270250acebe29bcdff77672'),
    ('PROCEDIMIENTO', 'sp_pad_padron_resumen', NULL, '', '02_procedimientos.sql', '5432023f6df549deef9f3e0db456af0f'),
    ('FUNCION', 'fn_formato_mac', NULL, 'p_mac', 'procedimientosDispositivos.sql', '80f91bf9986310e8dcd4f4d67a73e8b6'),
    ('FUNCION', 'fn_categoria_por_nombre', NULL, 'p_descripcion, p_defecto', 'procedimientosDispositivos.sql', '477a4dd512ab5df63500d16e390c0cb7'),
    ('FUNCION', 'fn_rotulo_puerto', NULL, 'p_tipo, p_num, p_eth, p_sfp, p_combo', 'procedimientosDispositivos.sql', 'f1e32768d779014285ae315469e5eab6'),
    ('PROCEDIMIENTO', 'sp_categoria_equipos_obtener', NULL, 'IN p_id_categoria', 'procedimientosDispositivos.sql', 'd3a6e917de8f161b85b280c539ceb192'),
    ('PROCEDIMIENTO', 'sp_categoria_equipos_listar', NULL, '', 'procedimientosDispositivos.sql', '03f38a2c8c90d546310d990720a45966'),
    ('PROCEDIMIENTO', 'sp_tipo_equipos_insertar', NULL, 'IN p_descripcion, IN p_id_categoria, OUT p_tipo_disp', 'procedimientosDispositivos.sql', '587372ebac4f227c68b38dca5bc58954'),
    ('PROCEDIMIENTO', 'sp_tipo_equipos_actualizar', NULL, 'IN p_tipo_disp, IN p_descripcion, IN p_id_categoria', 'procedimientosDispositivos.sql', 'f29425f8f3e74964ce1538d33e230bd9'),
    ('PROCEDIMIENTO', 'sp_tipo_equipos_eliminar', NULL, 'IN p_tipo_disp', 'procedimientosDispositivos.sql', '81da10ec90f369ac4c415a3cf030a6d1'),
    ('PROCEDIMIENTO', 'sp_tipo_equipos_obtener', NULL, 'IN p_tipo_disp', 'procedimientosDispositivos.sql', '5fc4e208a26046420f1cf9a0fe6f94dc'),
    ('PROCEDIMIENTO', 'sp_tipo_equipos_listar', NULL, 'IN p_id_categoria', 'procedimientosDispositivos.sql', '5cc12bdec07b9fe96f6f26826122ef68'),
    ('PROCEDIMIENTO', 'sp_marcas_insertar', NULL, 'IN p_tipo_equipo, IN p_descripcion, OUT p_id_marca', 'procedimientosDispositivos.sql', 'cadb67387dacefeb1f9aa22683cb9913'),
    ('PROCEDIMIENTO', 'sp_marcas_actualizar', NULL, 'IN p_id_marca, IN p_tipo_equipo, IN p_descripcion', 'procedimientosDispositivos.sql', '1e18b677534c9f3f6ffa0c278c846c4e'),
    ('PROCEDIMIENTO', 'sp_marcas_eliminar', NULL, 'IN p_id_marca', 'procedimientosDispositivos.sql', '3c79a02fc6d0e0f55bff013942674c4d'),
    ('PROCEDIMIENTO', 'sp_marcas_obtener', NULL, 'IN p_id_marca', 'procedimientosDispositivos.sql', 'fdac18dbfda34aa3c427abb8dd56424e'),
    ('PROCEDIMIENTO', 'sp_marcas_listar', NULL, 'IN p_tipo_equipo', 'procedimientosDispositivos.sql', '1e019d0ffa46ef77e8bc6a7d4611789d'),
    ('PROCEDIMIENTO', 'sp_modelos_insertar', NULL, 'IN p_id_marca, IN p_descripcion, OUT p_id_modelo', 'procedimientosDispositivos.sql', '164c62546a8b53b04e622b6810d60287'),
    ('PROCEDIMIENTO', 'sp_modelos_actualizar', NULL, 'IN p_id_marca, IN p_id_modelo, IN p_descripcion', 'procedimientosDispositivos.sql', '19bce566dd356f361bd56be5737b1fe3'),
    ('PROCEDIMIENTO', 'sp_modelos_eliminar', NULL, 'IN p_id_marca, IN p_id_modelo', 'procedimientosDispositivos.sql', 'f97b67c4b135b7bda1c0aa9d3e0cdab6'),
    ('PROCEDIMIENTO', 'sp_modelos_obtener', NULL, 'IN p_id_marca, IN p_id_modelo', 'procedimientosDispositivos.sql', 'd583846e52070ca93ae6ced12fb30e32'),
    ('PROCEDIMIENTO', 'sp_modelos_listar', NULL, 'IN p_tipo_equipo, IN p_id_marca', 'procedimientosDispositivos.sql', '1ffa57a49ee82646eff0526c22fa18fd'),
    ('PROCEDIMIENTO', 'sp_procesadores_insertar', NULL, 'IN p_descripcion, OUT p_id_proc', 'procedimientosDispositivos.sql', '198d4eee7d51bf552756875a968620cf'),
    ('PROCEDIMIENTO', 'sp_procesadores_actualizar', NULL, 'IN p_id_proc, IN p_descripcion', 'procedimientosDispositivos.sql', 'f338e70b3e27d5194f50ad9fcef47492'),
    ('PROCEDIMIENTO', 'sp_procesadores_eliminar', NULL, 'IN p_id_proc', 'procedimientosDispositivos.sql', 'c81c634b8586be7f3cb54e013f7dc06e'),
    ('PROCEDIMIENTO', 'sp_procesadores_obtener', NULL, 'IN p_id_proc', 'procedimientosDispositivos.sql', '5411095a3155b02cd14178f23c90fd9d'),
    ('PROCEDIMIENTO', 'sp_procesadores_listar', NULL, '', 'procedimientosDispositivos.sql', '1ae80c05c821bda97c0279fb8faf583c'),
    ('PROCEDIMIENTO', 'sp_sis_operativos_insertar', NULL, 'IN p_descripcion, OUT p_id_so', 'procedimientosDispositivos.sql', 'f0fb258b86bb917a58c09c5c8a8ec8d1'),
    ('PROCEDIMIENTO', 'sp_sis_operativos_actualizar', NULL, 'IN p_id_so, IN p_descripcion', 'procedimientosDispositivos.sql', 'b03704e16e4045ff4a5cf4324e3ebc7f'),
    ('PROCEDIMIENTO', 'sp_sis_operativos_eliminar', NULL, 'IN p_id_so', 'procedimientosDispositivos.sql', 'dffcbd617ba3055d34efed2c70f1b905'),
    ('PROCEDIMIENTO', 'sp_sis_operativos_obtener', NULL, 'IN p_id_so', 'procedimientosDispositivos.sql', '5c1f00457f5fa9bce65f10c98d53018c'),
    ('PROCEDIMIENTO', 'sp_sis_operativos_listar', NULL, '', 'procedimientosDispositivos.sql', 'b5d49b2b4fc22ee526fb4c0fa6db3b1b'),
    ('PROCEDIMIENTO', 'sp_firmwares_insertar', NULL, 'IN p_descripcion, OUT p_id_firmw', 'procedimientosDispositivos.sql', '8c2c4f3d3a177cd3460fa2ad15ed53c3'),
    ('PROCEDIMIENTO', 'sp_firmwares_actualizar', NULL, 'IN p_id_firmw, IN p_descripcion', 'procedimientosDispositivos.sql', 'af43b34e1d32f5438b424fb7cc61f89c'),
    ('PROCEDIMIENTO', 'sp_firmwares_eliminar', NULL, 'IN p_id_firmw', 'procedimientosDispositivos.sql', '8f265295bd87cf3f4046f890ecc3b21e'),
    ('PROCEDIMIENTO', 'sp_firmwares_obtener', NULL, 'IN p_id_firmw', 'procedimientosDispositivos.sql', '865e4c522fb07e32fe19d560674634be'),
    ('PROCEDIMIENTO', 'sp_firmwares_listar', NULL, '', 'procedimientosDispositivos.sql', '5231fad4f9ab0ca3c3d3afef129ea3a1'),
    ('PROCEDIMIENTO', 'sp_edificios_insertar', NULL, 'IN p_descripcion, IN p_otras_senas, IN p_gps, IN p_id_pais, IN p_id_provincia, IN p_id_canton, IN p_id_distrito, OUT p_id_predio', 'procedimientosDispositivos.sql', '35d1b1aa5336f707e962c635d01a536c'),
    ('PROCEDIMIENTO', 'sp_edificios_actualizar', NULL, 'IN p_id_predio, IN p_descripcion, IN p_otras_senas, IN p_gps, IN p_id_pais, IN p_id_provincia, IN p_id_canton, IN p_id_distrito', 'procedimientosDispositivos.sql', 'c06d321b00c9425c43677355646870d2'),
    ('PROCEDIMIENTO', 'sp_edificios_validar', NULL, 'IN p_id_pais, IN p_id_provincia, IN p_id_canton, IN p_id_distrito', 'procedimientosDispositivos.sql', '2c37af39defb566eda7b5f890ff61367'),
    ('PROCEDIMIENTO', 'sp_edificios_eliminar', NULL, 'IN p_id_predio', 'procedimientosDispositivos.sql', '905fc7f5cb12ea09dca76e997d3e506d'),
    ('PROCEDIMIENTO', 'sp_edificios_obtener', NULL, 'IN p_id_predio', 'procedimientosDispositivos.sql', 'cc71278cf4f5e46d00be498dec4645cd'),
    ('PROCEDIMIENTO', 'sp_edificios_listar', NULL, '', 'procedimientosDispositivos.sql', 'bbc6b4a76b36237bc22458b6f13bbb9d'),
    ('PROCEDIMIENTO', 'sp_estado_equipos_insertar', NULL, 'IN p_descripcion, OUT p_id_estado', 'procedimientosDispositivos.sql', 'bc00d18d2f81d31590eee7ac5b892c6b'),
    ('PROCEDIMIENTO', 'sp_estado_equipos_actualizar', NULL, 'IN p_id_estado, IN p_descripcion', 'procedimientosDispositivos.sql', '0b389c933bae7dde01429069427d53eb'),
    ('PROCEDIMIENTO', 'sp_estado_equipos_eliminar', NULL, 'IN p_id_estado', 'procedimientosDispositivos.sql', '48435728d5652d7f1e280aeb2e1a7747'),
    ('PROCEDIMIENTO', 'sp_estado_equipos_obtener', NULL, 'IN p_id_estado', 'procedimientosDispositivos.sql', 'a909a61e19b39cafd430f73f9ebced94'),
    ('PROCEDIMIENTO', 'sp_estado_equipos_listar', NULL, '', 'procedimientosDispositivos.sql', '796bb74a0b86ea91d335217db9deea22'),
    ('PROCEDIMIENTO', 'sp_tipo_roles_insertar', NULL, 'IN p_descripcion, OUT p_id_rol', 'procedimientosDispositivos.sql', 'daccf1b3eeb82c11dc85c98d5aca36d9'),
    ('PROCEDIMIENTO', 'sp_tipo_roles_actualizar', NULL, 'IN p_id_rol, IN p_descripcion', 'procedimientosDispositivos.sql', 'cdf6b78bd97e3538219fe0eb9327f030'),
    ('PROCEDIMIENTO', 'sp_tipo_roles_eliminar', NULL, 'IN p_id_rol', 'procedimientosDispositivos.sql', '58ee23cbd01fa160f9d81f92c500f5a9'),
    ('PROCEDIMIENTO', 'sp_tipo_roles_obtener', NULL, 'IN p_id_rol', 'procedimientosDispositivos.sql', '388c44e0dcc97a75e4fdbeaa84481b23'),
    ('PROCEDIMIENTO', 'sp_tipo_roles_listar', NULL, '', 'procedimientosDispositivos.sql', 'b78b625aa760cb7fd369b9893bc5360b'),
    ('PROCEDIMIENTO', 'sp_tipo_herramientas_insertar', NULL, 'IN p_descripcion, OUT p_id_herram', 'procedimientosDispositivos.sql', '06e2dec9974cf29194a2bfcb37739758'),
    ('PROCEDIMIENTO', 'sp_tipo_herramientas_actualizar', NULL, 'IN p_id_herram, IN p_descripcion', 'procedimientosDispositivos.sql', 'e892ce08aaf96184315f316f3b116d36'),
    ('PROCEDIMIENTO', 'sp_tipo_herramientas_eliminar', NULL, 'IN p_id_herram', 'procedimientosDispositivos.sql', '565ac01242b01d09417b51b347ef83a1'),
    ('PROCEDIMIENTO', 'sp_tipo_herramientas_obtener', NULL, 'IN p_id_herram', 'procedimientosDispositivos.sql', '0229be8e6de67c6dc4a820800c5d6e40'),
    ('PROCEDIMIENTO', 'sp_tipo_herramientas_listar', NULL, '', 'procedimientosDispositivos.sql', '692cb9d3ba5198658f305be0c57ea398'),
    ('PROCEDIMIENTO', 'sp_tipo_archivos_insertar', NULL, 'IN p_descripcion, OUT p_tipo_arch', 'procedimientosDispositivos.sql', '9c59773927a1596c4cf5e02172fc4392'),
    ('PROCEDIMIENTO', 'sp_tipo_archivos_actualizar', NULL, 'IN p_tipo_arch, IN p_descripcion', 'procedimientosDispositivos.sql', 'dc28be18835399e18460cf1c217d846e'),
    ('PROCEDIMIENTO', 'sp_tipo_archivos_eliminar', NULL, 'IN p_tipo_arch', 'procedimientosDispositivos.sql', 'b54a48e47008c5e8486b3ef5404058f0'),
    ('PROCEDIMIENTO', 'sp_tipo_archivos_obtener', NULL, 'IN p_tipo_arch', 'procedimientosDispositivos.sql', '5f331a61212af24f8ed010497fc4de75'),
    ('PROCEDIMIENTO', 'sp_tipo_archivos_listar', NULL, '', 'procedimientosDispositivos.sql', '71cebfaf831eac15d8103bbfc385f98a'),
    ('PROCEDIMIENTO', 'sp_equipos_validar', NULL, 'IN p_id, IN p_serie, IN p_tipo_equipo, IN p_id_marca, IN p_id_modelo, IN p_nombre_equipo, IN p_placa_equipo, IN p_id_estado, IN p_cant_ptos_serie, IN p_cant_ptos_usb, IN p_cant_ptos_eth, IN p_cant_ptos_sfp, IN p_cant_ptos_wireless, IN p_cant_ptos_bluetooth, IN p_cant_ptos_celular, IN p_tipo_almacenamiento, IN p_tecnologia_impresion, IN p_pulgadas, IN p_cod_departamento', 'procedimientosDispositivos.sql', '40b06ee30a351377b73f8e470115a0a4'),
    ('PROCEDIMIENTO', 'sp_equipos_guardar_detalle', NULL, 'IN p_id, IN p_ips, IN p_macs, IN p_moviles, IN p_imeis, IN p_roles, IN p_herramientas, IN p_tiene_microclaudia', 'procedimientosDispositivos.sql', '0b6cb04749494747d0e501aae905b29c'),
    ('PROCEDIMIENTO', 'sp_equipos_insertar', NULL, 'IN p_serie, IN p_tipo_equipo, IN p_id_marca, IN p_id_modelo, IN p_nombre_equipo, IN p_placa_equipo, IN p_id_proces, IN p_cant_mem, IN p_cant_almac, IN p_tipo_almacenamiento, IN p_cant_ptos_serie, IN p_cant_ptos_usb, IN p_cant_ptos_eth, IN p_cant_ptos_sfp, IN p_cant_ptos_wireless, IN p_cant_ptos_bluetooth, IN p_cant_ptos_celular, IN p_id_so, IN p_id_firmw, IN p_extension, IN p_tecnologia_impresion, IN p_a_color, IN p_consumible, IN p_pulgadas, IN p_resolucion, IN p_capacidad_va, IN p_autonomia_min, IN p_canales, IN p_id_predio, IN p_ubicacion, IN p_id_estado, IN p_cod_departamento, IN p_id_usuario, IN p_id_proveedor, IN p_fecha_compra, IN p_garantia_hasta, IN p_observaciones, IN p_sfp_combo, IN p_ips, IN p_macs, IN p_moviles, IN p_imeis, IN p_roles, IN p_herramientas, IN p_tiene_microclaudia, OUT p_id', 'procedimientosDispositivos.sql', '0dc729506ac886753975e55f833e80ba'),
    ('PROCEDIMIENTO', 'sp_equipos_actualizar', NULL, 'IN p_id, IN p_serie, IN p_tipo_equipo, IN p_id_marca, IN p_id_modelo, IN p_nombre_equipo, IN p_placa_equipo, IN p_id_proces, IN p_cant_mem, IN p_cant_almac, IN p_tipo_almacenamiento, IN p_cant_ptos_serie, IN p_cant_ptos_usb, IN p_cant_ptos_eth, IN p_cant_ptos_sfp, IN p_cant_ptos_wireless, IN p_cant_ptos_bluetooth, IN p_cant_ptos_celular, IN p_id_so, IN p_id_firmw, IN p_extension, IN p_tecnologia_impresion, IN p_a_color, IN p_consumible, IN p_pulgadas, IN p_resolucion, IN p_capacidad_va, IN p_autonomia_min, IN p_canales, IN p_id_predio, IN p_ubicacion, IN p_id_estado, IN p_cod_departamento, IN p_id_usuario, IN p_id_proveedor, IN p_fecha_compra, IN p_garantia_hasta, IN p_observaciones, IN p_sfp_combo, IN p_ips, IN p_macs, IN p_moviles, IN p_imeis, IN p_roles, IN p_herramientas, IN p_tiene_microclaudia', 'procedimientosDispositivos.sql', '2ded4c694f83af1df63178de89748d2b'),
    ('PROCEDIMIENTO', 'sp_equipos_eliminar', NULL, 'IN p_id', 'procedimientosDispositivos.sql', 'dd3df31b89bbb6d99da85b148815e35f'),
    ('PROCEDIMIENTO', 'sp_equipos_activar', NULL, 'IN p_id', 'procedimientosDispositivos.sql', 'd3c422cf0567647a5163d267a63f5e67'),
    ('PROCEDIMIENTO', 'sp_equipos_eliminar_fisico', NULL, 'IN p_id', 'procedimientosDispositivos.sql', '156f63339cfcc9428815edb269b88c08'),
    ('PROCEDIMIENTO', 'sp_equipos_obtener', NULL, 'IN p_id', 'procedimientosDispositivos.sql', 'fa4c5e3bcdd4e794c4ad53f68174cd56'),
    ('PROCEDIMIENTO', 'sp_equipos_listar', NULL, 'IN p_activo, IN p_id_categoria, IN p_tipo_equipo, IN p_id_marca, IN p_id_predio, IN p_cod_departamento, IN p_id_usuario, IN p_id_proveedor, IN p_buscar', 'procedimientosDispositivos.sql', 'f58a0526390f9585db9293f2bd0e0dd6'),
    ('PROCEDIMIENTO', 'sp_equipos_historial', NULL, 'IN p_id, IN p_limite, IN p_desplazamiento', 'procedimientosDispositivos.sql', '99de08b2c364343747ba8c3c6e282735'),
    ('PROCEDIMIENTO', 'sp_dir_ips_insertar', NULL, 'IN p_id, IN p_dir_ip, IN p_interfaz, OUT p_num_linea', 'procedimientosDispositivos.sql', '213e5fe1878384988de327cec2ae5415'),
    ('PROCEDIMIENTO', 'sp_dir_ips_actualizar', NULL, 'IN p_id, IN p_num_linea, IN p_dir_ip, IN p_interfaz', 'procedimientosDispositivos.sql', '249706a50b260de6900abf4b747b1b89'),
    ('PROCEDIMIENTO', 'sp_dir_ips_eliminar', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', '7258631efc41450207847dad650d5e69'),
    ('PROCEDIMIENTO', 'sp_dir_ips_obtener', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', '59ec65703fcbf6904956994815f8c798'),
    ('PROCEDIMIENTO', 'sp_dir_ips_listar', NULL, 'IN p_id', 'procedimientosDispositivos.sql', '13d7db1f3cf477e96208de189510b730'),
    ('PROCEDIMIENTO', 'sp_dir_macs_insertar', NULL, 'IN p_id, IN p_dir_mac, IN p_interfaz, OUT p_num_linea', 'procedimientosDispositivos.sql', 'a188ba3bcb9a3e15f6f9f7a2de789997'),
    ('PROCEDIMIENTO', 'sp_dir_macs_actualizar', NULL, 'IN p_id, IN p_num_linea, IN p_dir_mac, IN p_interfaz', 'procedimientosDispositivos.sql', '3be3886e7a9d9f24b11bbc695024f238'),
    ('PROCEDIMIENTO', 'sp_dir_macs_eliminar', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', 'c9d392bb88c652aff6fe8e4ede881c20'),
    ('PROCEDIMIENTO', 'sp_dir_macs_obtener', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', 'd668e1d101dbf31963ec09a60b7c8882'),
    ('PROCEDIMIENTO', 'sp_dir_macs_listar', NULL, 'IN p_id', 'procedimientosDispositivos.sql', '2ca261c8c3d35381b2c3c19e0c15ae35'),
    ('PROCEDIMIENTO', 'sp_num_moviles_insertar', NULL, 'IN p_id, IN p_num_movil, IN p_operador, OUT p_num_linea', 'procedimientosDispositivos.sql', '97cb596c1074c6f0a4bba7c1ebda452f'),
    ('PROCEDIMIENTO', 'sp_num_moviles_actualizar', NULL, 'IN p_id, IN p_num_linea, IN p_num_movil, IN p_operador', 'procedimientosDispositivos.sql', 'ac7502425c38d7981d64402811808d63'),
    ('PROCEDIMIENTO', 'sp_num_moviles_eliminar', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', '037a3574a1b5886a65041efa119f0971'),
    ('PROCEDIMIENTO', 'sp_num_moviles_obtener', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', '01ca3ecc58ea961f65bc7e02318da289'),
    ('PROCEDIMIENTO', 'sp_num_moviles_listar', NULL, 'IN p_id', 'procedimientosDispositivos.sql', '57d9cdbe7c76aa7043cdf56c5338cb17'),
    ('PROCEDIMIENTO', 'sp_dir_imeis_insertar', NULL, 'IN p_id, IN p_dir_imei, OUT p_num_linea', 'procedimientosDispositivos.sql', '1f9478f8cc5c7fc2b0d057b9c598b826'),
    ('PROCEDIMIENTO', 'sp_dir_imeis_actualizar', NULL, 'IN p_id, IN p_num_linea, IN p_dir_imei', 'procedimientosDispositivos.sql', 'e9fe9e6577f3dc6510d3b03b6657a734'),
    ('PROCEDIMIENTO', 'sp_dir_imeis_eliminar', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', 'f0a840df9ee09e1e0f2f6849ab366684'),
    ('PROCEDIMIENTO', 'sp_dir_imeis_obtener', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', '6af7a83671f7f8e8e4fdd112b85fd9ad'),
    ('PROCEDIMIENTO', 'sp_dir_imeis_listar', NULL, 'IN p_id', 'procedimientosDispositivos.sql', 'ead54922a4526cdd110a1ed1489fe135'),
    ('PROCEDIMIENTO', 'sp_archivos_insertar', NULL, 'IN p_id, IN p_tipo_arch, IN p_path_arch, OUT p_num_linea', 'procedimientosDispositivos.sql', 'c9da6e06164bf97ff20dbf62fd287ecc'),
    ('PROCEDIMIENTO', 'sp_archivos_actualizar', NULL, 'IN p_id, IN p_num_linea, IN p_tipo_arch, IN p_path_arch', 'procedimientosDispositivos.sql', '10d47c752209fd6e8eecbda54c709eef'),
    ('PROCEDIMIENTO', 'sp_archivos_eliminar', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', 'a2b2f4199a7c4f59fa556eb4c01e0ef1'),
    ('PROCEDIMIENTO', 'sp_archivos_obtener', NULL, 'IN p_id, IN p_num_linea', 'procedimientosDispositivos.sql', 'c9d541edf2ac42e173333d8ec6c56aaf'),
    ('PROCEDIMIENTO', 'sp_archivos_listar', NULL, 'IN p_id, IN p_tipo_arch', 'procedimientosDispositivos.sql', '51ecbb94d8471df94940b67442c11225'),
    ('PROCEDIMIENTO', 'sp_puertos_switch_listar', NULL, 'IN p_id_switch', 'procedimientosDispositivos.sql', 'e058db30e393ea4711196937c36cf3d4'),
    ('PROCEDIMIENTO', 'sp_puertos_switch_equipos', NULL, 'IN p_activo', 'procedimientosDispositivos.sql', 'e320c6f260e2edb7413e9d6dfb724e62'),
    ('PROCEDIMIENTO', 'sp_puertos_switch_de_equipo', NULL, 'IN p_id_equipo', 'procedimientosDispositivos.sql', '7356786ac2c8d6d25c3e3793ec4fecb6'),
    ('PROCEDIMIENTO', 'sp_puertos_switch_guardar', NULL, 'IN p_id_switch, IN p_tipo_puerto, IN p_num_puerto, IN p_id_equipo, IN p_estado, IN p_vlan, IN p_nota', 'procedimientosDispositivos.sql', 'c0b4f7b73871473223d3b8fdb0ef6bc8'),
    ('PROCEDIMIENTO', 'sp_puertos_switch_eliminar', NULL, 'IN p_id_switch, IN p_tipo_puerto, IN p_num_puerto', 'procedimientosDispositivos.sql', '5597e8413c2e220ec4e8d4f76a81b1a7'),
    ('PROCEDIMIENTO', 'sp_log_importaciones_insertar', NULL, 'IN p_fuente, IN p_nombre_archivo, IN p_descripcion, IN p_id_usuario, OUT p_id_importacion', 'procedimientosLogs.sql', '66dca78260bbb85636538feb0d9c4195'),
    ('PROCEDIMIENTO', 'sp_log_importaciones_cerrar', NULL, 'IN p_id_importacion, IN p_leidos, IN p_avisos', 'procedimientosLogs.sql', '8afec1cfa4e8f0948910f90eab1a931d'),
    ('PROCEDIMIENTO', 'sp_log_importaciones_actualizar', NULL, 'IN p_id_importacion, IN p_descripcion', 'procedimientosLogs.sql', '3feb5bbe191f6b4297688ef92f551ed1'),
    ('PROCEDIMIENTO', 'sp_log_importaciones_eliminar', NULL, 'IN p_id_importacion', 'procedimientosLogs.sql', '1efebb41635be7ffdfb39a8fa38aad0e'),
    ('PROCEDIMIENTO', 'sp_log_importaciones_obtener', NULL, 'IN p_id_importacion', 'procedimientosLogs.sql', 'f010dd1360bf9827be419e5885455652'),
    ('PROCEDIMIENTO', 'sp_log_importaciones_listar', NULL, 'IN p_fuente', 'procedimientosLogs.sql', 'a90b48f72df1db3c462f12ad19c274dc'),
    ('PROCEDIMIENTO', 'sp_log_eventos_insertar', NULL, 'IN p_id_importacion, IN p_evento, IN p_datos', 'procedimientosLogs.sql', '2147862ffcf079fc9450365981aa43a7'),
    ('PROCEDIMIENTO', 'sp_log_eventos_obtener', NULL, 'IN p_id_evento', 'procedimientosLogs.sql', '424812b7d81947201288b8a45d1c29fe'),
    ('PROCEDIMIENTO', 'sp_log_eventos_buscar', NULL, 'IN p_filtro, IN p_orden, IN p_limite, IN p_desplazamiento', 'procedimientosLogs.sql', 'e0bc7d3ee4348e80db5bfd26c3223cef'),
    ('PROCEDIMIENTO', 'sp_log_eventos_contar', NULL, 'IN p_filtro', 'procedimientosLogs.sql', '05be23e4efe808ddab12bbe9bf675c1b'),
    ('PROCEDIMIENTO', 'sp_log_eventos_resumen', NULL, 'IN p_filtro', 'procedimientosLogs.sql', '86c5e90073297cb686359398bbc879fb'),
    ('PROCEDIMIENTO', 'sp_log_eventos_top', NULL, 'IN p_filtro, IN p_campo, IN p_limite', 'procedimientosLogs.sql', '486065b4fe10759a2a9f4eabdc66c24e'),
    ('PROCEDIMIENTO', 'sp_log_eventos_linea_tiempo', NULL, 'IN p_filtro, IN p_segundos', 'procedimientosLogs.sql', '04dc42a5459dc06a4d481bc5de7eea16'),
    ('PROCEDIMIENTO', 'sp_log_eventos_conexion', NULL, 'IN p_id_conexion', 'procedimientosLogs.sql', '71ad06d7da2d5e8412bfafaf652cdb3d'),
    ('PROCEDIMIENTO', 'sp_log_eventos_correlacionados', NULL, 'IN p_filtro, IN p_limite', 'procedimientosLogs.sql', '4a6ec0676bafef2ea4de271f8794611e'),
    ('PROCEDIMIENTO', 'sp_log_eventos_huellas', NULL, 'IN p_filtro, IN p_limite', 'procedimientosLogs.sql', 'dda6a47407eca3c79575890eee03014d'),
    ('PROCEDIMIENTO', 'sp_log_eventos_exportar', NULL, 'IN p_filtro, IN p_limite, IN p_desplazamiento', 'procedimientosLogs.sql', '62d3bf2989beaeab766814ce99533d76'),
    ('PROCEDIMIENTO', 'sp_log_inventario_ips', NULL, 'IN p_filtro, IN p_limite', 'procedimientosLogs.sql', 'd448ee73bbae9365f8cca9b462883733'),
    ('PROCEDIMIENTO', 'sp_log_inventario_macs', NULL, 'IN p_filtro, IN p_limite', 'procedimientosLogs.sql', '1eb8ccd1a9debf6b47eea2ac9cfcb5dd'),
    ('PROCEDIMIENTO', 'sp_log_inventario_usuarios', NULL, 'IN p_filtro, IN p_limite', 'procedimientosLogs.sql', '6e957c65097859eed76f429d3a5f7a54'),
    ('PROCEDIMIENTO', 'sp_log_agentes_listar', NULL, 'IN p_id_importacion', 'procedimientosLogs.sql', '57e0c8bc25f8089ec67d03a5b67c61e2'),
    ('PROCEDIMIENTO', 'sp_log_cobertura_ips', NULL, 'IN p_filtro, IN p_id_agentes, IN p_limite', 'procedimientosLogs.sql', 'ba7b45f0010dd187b4711635171ce4a6'),
    ('PROCEDIMIENTO', 'sp_log_cobertura_inventario', NULL, 'IN p_id_agentes', 'procedimientosLogs.sql', 'b8dcd895296af00f490c0a7905d79bfc'),
    ('PROCEDIMIENTO', 'sp_log_dhcp_listar', NULL, 'IN p_id_importacion', 'procedimientosLogs.sql', '4e2d9886dde69d21b07d1e9cf31d915f'),
    ('PROCEDIMIENTO', 'sp_log_red_inventario', NULL, '', 'procedimientosLogs.sql', '1feed7a80e98cd0c8794844c6393ef89'),
    ('PROCEDIMIENTO', 'sp_log_mapeo_campos_validar', NULL, 'IN p_campo_origen, IN p_campo', 'procedimientosLogs.sql', '277800fbca727398f77b4794410fafa2'),
    ('PROCEDIMIENTO', 'sp_log_mapeo_campos_insertar', NULL, 'IN p_fuente, IN p_campo_origen, IN p_campo, IN p_prioridad', 'procedimientosLogs.sql', '13c5f95aed63d1f50e7639497a9a1ef9'),
    ('PROCEDIMIENTO', 'sp_log_mapeo_campos_actualizar', NULL, 'IN p_fuente, IN p_campo_origen, IN p_campo, IN p_prioridad', 'procedimientosLogs.sql', 'd83ef0b4f3263d10133861d1033c286e'),
    ('PROCEDIMIENTO', 'sp_log_mapeo_campos_eliminar', NULL, 'IN p_fuente, IN p_campo_origen', 'procedimientosLogs.sql', '182f31c684f03d45a5d704e22605af8c'),
    ('PROCEDIMIENTO', 'sp_log_mapeo_campos_obtener', NULL, 'IN p_fuente, IN p_campo_origen', 'procedimientosLogs.sql', '94ed8e4527ae8176f13d79ee3b08e880'),
    ('PROCEDIMIENTO', 'sp_log_mapeo_campos_listar', NULL, 'IN p_fuente', 'procedimientosLogs.sql', 'e621da7ee9460b85593fa2f1b740fe75'),
    ('PROCEDIMIENTO', 'sp_cor_configuracion_obtener', NULL, '', 'procedimientosCorreo.sql', '3e7393b4e9caccd1c9ad3e5f08714ff3'),
    ('PROCEDIMIENTO', 'sp_cor_configuracion_guardar', NULL, 'IN p_servidor, IN p_puerto, IN p_seguridad, IN p_usuario, IN p_cambiar_clave, IN p_clave_cifrada, IN p_correo_remitente, IN p_nombre_remitente, IN p_responder_a, IN p_firma, IN p_limite_diario, IN p_activo, IN p_id_usuario', 'procedimientosCorreo.sql', '0d8bb096585b91d176aed764c7f1f88f'),
    ('PROCEDIMIENTO', 'sp_cor_configuracion_resultado_prueba', NULL, 'IN p_ok, IN p_resultado', 'procedimientosCorreo.sql', 'de6c892ef51779280ab361b6d878666a'),
    ('PROCEDIMIENTO', 'sp_cor_personal_listar', NULL, 'IN p_solo_activos', 'procedimientosCorreo.sql', '1bed4a30b38e0b3f5e92091ec1787413'),
    ('PROCEDIMIENTO', 'sp_cor_envios_insertar', NULL, 'IN p_asunto, IN p_mensaje, IN p_destinatarios, IN p_remitente, IN p_id_usuario, IN p_lista, OUT p_id_envio', 'procedimientosCorreo.sql', 'cb65145e0d01f58bcee40d6a2d8cd0c3'),
    ('PROCEDIMIENTO', 'sp_cor_envios_adjuntos_insertar', NULL, 'IN p_id_envio, IN p_nombre_archivo, IN p_ruta, IN p_tamano, IN p_tipo', 'procedimientosCorreo.sql', '59dea366bcc101db2f75e33ae0b38f8e'),
    ('PROCEDIMIENTO', 'sp_cor_envios_adjuntos_listar', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', 'e67a3c37efd7ac418d8aab42baa8e9b0'),
    ('PROCEDIMIENTO', 'sp_cor_envios_obtener', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', '86b0ce968b7dab57904c13fe8352842b'),
    ('PROCEDIMIENTO', 'sp_cor_envios_listar', NULL, 'IN p_buscar', 'procedimientosCorreo.sql', '97b3af173a628d4065e6c2709d5c4074'),
    ('PROCEDIMIENTO', 'sp_cor_envios_destinatarios_listar', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', '5cccd1275abd98005a8e8816866d1fe3'),
    ('PROCEDIMIENTO', 'sp_cor_envios_pendientes', NULL, 'IN p_id_envio, IN p_limite', 'procedimientosCorreo.sql', 'e18d3cfe0fc6e1c3046f5cde677be436'),
    ('PROCEDIMIENTO', 'sp_cor_envios_recalcular', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', '93f55b7ede08cd1478d64156732cfb15'),
    ('PROCEDIMIENTO', 'sp_cor_envios_marcar', NULL, 'IN p_id_envio, IN p_num_linea, IN p_ok, IN p_error', 'procedimientosCorreo.sql', '6aa739785c13e3ce963737b0f1396a66'),
    ('PROCEDIMIENTO', 'sp_cor_envios_reintentar', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', '44d560ce23a4f218164f5721375af6f5'),
    ('PROCEDIMIENTO', 'sp_cor_envios_cancelar', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', '9396d9de0bf61495b606a5b2659617d8'),
    ('PROCEDIMIENTO', 'sp_cor_envios_eliminar', NULL, 'IN p_id_envio', 'procedimientosCorreo.sql', 'd0fb59bdd0448e0d6d035760ee588c30'),
    ('PROCEDIMIENTO', 'sp_cor_enviados_hoy', NULL, '', 'procedimientosCorreo.sql', 'fe1bb01f7228cf0e3e9bd68e0f067d2a'),
    ('PROCEDIMIENTO', 'sp_cor_listas_insertar', NULL, 'IN p_nombre_archivo, IN p_descripcion, IN p_dominio, IN p_id_usuario, IN p_origen, IN p_correos, OUT p_id_lista', 'procedimientosCorreo.sql', '5b6603493cb1832cfc270522882828cd'),
    ('PROCEDIMIENTO', 'sp_cor_listas_obtener', NULL, 'IN p_id_lista', 'procedimientosCorreo.sql', 'e965d8aa21e26c174b1ac2a7b6005039'),
    ('PROCEDIMIENTO', 'sp_cor_listas_listar', NULL, 'IN p_origen', 'procedimientosCorreo.sql', '0d381bd3b6c394e9f0382bdba76d78fb'),
    ('PROCEDIMIENTO', 'sp_cor_listas_correos_listar', NULL, 'IN p_id_lista', 'procedimientosCorreo.sql', '0958967c3dd433de1a3c4fb5cbe38669'),
    ('PROCEDIMIENTO', 'sp_cor_listas_actualizar', NULL, 'IN p_id_lista, IN p_descripcion', 'procedimientosCorreo.sql', '16fa5be47c9ecf4dce844ed207210a87'),
    ('PROCEDIMIENTO', 'sp_cor_listas_eliminar', NULL, 'IN p_id_lista', 'procedimientosCorreo.sql', '8e4fd023aeeb3c76374c30baedfe16a1'),
    ('DISPARADOR', 'trg_geo_distritos_cp_ins', 'geo_distritos', NULL, '02_procedimientos.sql', '7929e142782918ab014c6bd8704efa9a'),
    ('DISPARADOR', 'trg_geo_distritos_cp_upd', 'geo_distritos', NULL, '02_procedimientos.sql', 'db352b806638fa82908a1e5b689756dc'),
    ('DISPARADOR', 'trg_personas_cp_ins', 'personas', NULL, '02_procedimientos.sql', 'f70a525df46dd3e4fdd8f9ebb64fa5b4'),
    ('DISPARADOR', 'trg_personas_cp_upd', 'personas', NULL, '02_procedimientos.sql', '9de908ce9ea8a05bdb333e0e73ba9899'),
    ('DISPARADOR', 'trg_mayus_geo_paises_ins', 'geo_paises', NULL, '02_procedimientos.sql', '11ad881de50be87fc5b2cf41b727c7c0'),
    ('DISPARADOR', 'trg_mayus_geo_paises_upd', 'geo_paises', NULL, '02_procedimientos.sql', '11ad881de50be87fc5b2cf41b727c7c0'),
    ('DISPARADOR', 'trg_mayus_geo_provincias_ins', 'geo_provincias', NULL, '02_procedimientos.sql', '9c73eb31e89c4a2a6ba633e721cca539'),
    ('DISPARADOR', 'trg_mayus_geo_provincias_upd', 'geo_provincias', NULL, '02_procedimientos.sql', '9c73eb31e89c4a2a6ba633e721cca539'),
    ('DISPARADOR', 'trg_mayus_geo_cantones_ins', 'geo_cantones', NULL, '02_procedimientos.sql', 'd742a37b04e5fc227ec4f3c94d58bded'),
    ('DISPARADOR', 'trg_mayus_geo_cantones_upd', 'geo_cantones', NULL, '02_procedimientos.sql', 'd742a37b04e5fc227ec4f3c94d58bded'),
    ('DISPARADOR', 'trg_mayus_geo_distritos_ins', 'geo_distritos', NULL, '02_procedimientos.sql', '6dcd4ca0e1b4fda3f5fd9034568cb2c5'),
    ('DISPARADOR', 'trg_mayus_geo_distritos_upd', 'geo_distritos', NULL, '02_procedimientos.sql', '6dcd4ca0e1b4fda3f5fd9034568cb2c5'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_identificaciones_ins', 'cat_tipos_identificaciones', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_identificaciones_upd', 'cat_tipos_identificaciones', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_roles_usuarios_ins', 'cat_roles_usuarios', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_roles_usuarios_upd', 'cat_roles_usuarios', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_autenticaciones_ins', 'cat_tipos_autenticaciones', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_autenticaciones_upd', 'cat_tipos_autenticaciones', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_departamentos_ins', 'cat_departamentos', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_departamentos_upd', 'cat_departamentos', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_telefonos_ins', 'cat_tipos_telefonos', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_telefonos_upd', 'cat_tipos_telefonos', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_correos_ins', 'cat_tipos_correos', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_tipos_correos_upd', 'cat_tipos_correos', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_categorias_proveedores_ins', 'cat_categorias_proveedores', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_cat_categorias_proveedores_upd', 'cat_categorias_proveedores', NULL, '02_procedimientos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_personas_ins', 'personas', NULL, '02_procedimientos.sql', 'e6fa2c7953a525d2b292e8f25f5f0cf1'),
    ('DISPARADOR', 'trg_mayus_personas_upd', 'personas', NULL, '02_procedimientos.sql', 'e6fa2c7953a525d2b292e8f25f5f0cf1'),
    ('DISPARADOR', 'trg_formato_usr_telefonos_ins', 'usr_telefonos', NULL, '02_procedimientos.sql', 'ee85c2598f4ce275580a1eb71f81f7eb'),
    ('DISPARADOR', 'trg_formato_usr_telefonos_upd', 'usr_telefonos', NULL, '02_procedimientos.sql', 'ee85c2598f4ce275580a1eb71f81f7eb'),
    ('DISPARADOR', 'trg_formato_usr_correos_ins', 'usr_correos', NULL, '02_procedimientos.sql', 'ceaf6ab1b84daa7f30cad1bf7f8e3849'),
    ('DISPARADOR', 'trg_formato_usr_correos_upd', 'usr_correos', NULL, '02_procedimientos.sql', 'ceaf6ab1b84daa7f30cad1bf7f8e3849'),
    ('DISPARADOR', 'trg_aud_auditorias_sin_borrar', 'aud_auditorias', NULL, '02_procedimientos.sql', 'd255fae9eebe3addfe58b42cf3c3159c'),
    ('DISPARADOR', 'trg_aud_geo_paises_ins', 'geo_paises', NULL, '02_procedimientos.sql', '1b4616a300d1cc2bfbfb343fd8ba3cf1'),
    ('DISPARADOR', 'trg_aud_geo_paises_upd', 'geo_paises', NULL, '02_procedimientos.sql', '6fb0038f8ba853736940f98b54ea66e8'),
    ('DISPARADOR', 'trg_aud_geo_paises_del', 'geo_paises', NULL, '02_procedimientos.sql', '09784049f3276487eb41feb9e8902f5e'),
    ('DISPARADOR', 'trg_aud_geo_provincias_ins', 'geo_provincias', NULL, '02_procedimientos.sql', '42efc7b72df7dce5733a7abe601d118a'),
    ('DISPARADOR', 'trg_aud_geo_provincias_upd', 'geo_provincias', NULL, '02_procedimientos.sql', 'facc39abb1fa1d38184cc6459acc3ba8'),
    ('DISPARADOR', 'trg_aud_geo_provincias_del', 'geo_provincias', NULL, '02_procedimientos.sql', '94d9418eeac8356b5f19673a181b5b2f'),
    ('DISPARADOR', 'trg_aud_geo_cantones_ins', 'geo_cantones', NULL, '02_procedimientos.sql', 'dbdd50ba6c5662e4a307cb48fcc1b60a'),
    ('DISPARADOR', 'trg_aud_geo_cantones_upd', 'geo_cantones', NULL, '02_procedimientos.sql', '7e5fa47536016936be5e7c297588ff64'),
    ('DISPARADOR', 'trg_aud_geo_cantones_del', 'geo_cantones', NULL, '02_procedimientos.sql', '2f1798db0964d440b67d5eacfeaa7422'),
    ('DISPARADOR', 'trg_aud_geo_distritos_ins', 'geo_distritos', NULL, '02_procedimientos.sql', '9b1681309db51de6e14a22f0fed1a4c9'),
    ('DISPARADOR', 'trg_aud_geo_distritos_upd', 'geo_distritos', NULL, '02_procedimientos.sql', '09482a7175dc11f1168073fb072b8f22'),
    ('DISPARADOR', 'trg_aud_geo_distritos_del', 'geo_distritos', NULL, '02_procedimientos.sql', '5abe9b7671f99223a503999d1b22e389'),
    ('DISPARADOR', 'trg_aud_cat_tipos_identificaciones_ins', 'cat_tipos_identificaciones', NULL, '02_procedimientos.sql', '0f814b46024add3ba2da8ed6492a8f95'),
    ('DISPARADOR', 'trg_aud_cat_tipos_identificaciones_upd', 'cat_tipos_identificaciones', NULL, '02_procedimientos.sql', 'efd7a0a9e5d69a48d5aa86a4f4177965'),
    ('DISPARADOR', 'trg_aud_cat_tipos_identificaciones_del', 'cat_tipos_identificaciones', NULL, '02_procedimientos.sql', 'f4eed813b69a6afea160d3368df61983'),
    ('DISPARADOR', 'trg_aud_cat_roles_usuarios_ins', 'cat_roles_usuarios', NULL, '02_procedimientos.sql', '64dfe6de1055dd15df2aa9ed640b0678'),
    ('DISPARADOR', 'trg_aud_cat_roles_usuarios_upd', 'cat_roles_usuarios', NULL, '02_procedimientos.sql', '0395961a75b6aba052b9d1f6eeeddd1f'),
    ('DISPARADOR', 'trg_aud_cat_roles_usuarios_del', 'cat_roles_usuarios', NULL, '02_procedimientos.sql', '6469ad46b2010bac94c4ead29722f317'),
    ('DISPARADOR', 'trg_aud_cat_tipos_autenticaciones_ins', 'cat_tipos_autenticaciones', NULL, '02_procedimientos.sql', '8de20b0519eb50228c85ce6cc70738f3'),
    ('DISPARADOR', 'trg_aud_cat_tipos_autenticaciones_upd', 'cat_tipos_autenticaciones', NULL, '02_procedimientos.sql', '603002f1c997b2edf74469efd17eaec5'),
    ('DISPARADOR', 'trg_aud_cat_tipos_autenticaciones_del', 'cat_tipos_autenticaciones', NULL, '02_procedimientos.sql', 'c2e9e3eb1fd2701f2f0c0461617324a1'),
    ('DISPARADOR', 'trg_aud_cat_departamentos_ins', 'cat_departamentos', NULL, '02_procedimientos.sql', '1539f1dbd9a752f010d05e29bd7e25dc'),
    ('DISPARADOR', 'trg_aud_cat_departamentos_upd', 'cat_departamentos', NULL, '02_procedimientos.sql', '4e9fb9ce6c127d26b03299cf171ed32b'),
    ('DISPARADOR', 'trg_aud_cat_departamentos_del', 'cat_departamentos', NULL, '02_procedimientos.sql', '77557db4fe8176537ebb292a3cf5a262'),
    ('DISPARADOR', 'trg_aud_cat_tipos_telefonos_ins', 'cat_tipos_telefonos', NULL, '02_procedimientos.sql', '779393a84452bda980f44118393c015c'),
    ('DISPARADOR', 'trg_aud_cat_tipos_telefonos_upd', 'cat_tipos_telefonos', NULL, '02_procedimientos.sql', '7595e73c72b6af3e33137a138df6b7ae'),
    ('DISPARADOR', 'trg_aud_cat_tipos_telefonos_del', 'cat_tipos_telefonos', NULL, '02_procedimientos.sql', 'f8b5c4590f10708c19cf4541936796b8'),
    ('DISPARADOR', 'trg_aud_cat_tipos_correos_ins', 'cat_tipos_correos', NULL, '02_procedimientos.sql', '142abf3893eee5ef789fbf83abf9631c'),
    ('DISPARADOR', 'trg_aud_cat_tipos_correos_upd', 'cat_tipos_correos', NULL, '02_procedimientos.sql', '0b0296265b67fa4870d0555b8bac7f49'),
    ('DISPARADOR', 'trg_aud_cat_tipos_correos_del', 'cat_tipos_correos', NULL, '02_procedimientos.sql', '0e99945e801f2433f98bdbca6206959b'),
    ('DISPARADOR', 'trg_aud_cat_categorias_proveedores_ins', 'cat_categorias_proveedores', NULL, '02_procedimientos.sql', 'da33bf0a5edfdf600057ae100f6dc710'),
    ('DISPARADOR', 'trg_aud_cat_categorias_proveedores_upd', 'cat_categorias_proveedores', NULL, '02_procedimientos.sql', 'bae09058aeb7167f16d18bf72be7d9cc'),
    ('DISPARADOR', 'trg_aud_cat_categorias_proveedores_del', 'cat_categorias_proveedores', NULL, '02_procedimientos.sql', '0653271c14b651d5958be9a9b8e53f53'),
    ('DISPARADOR', 'trg_aud_personas_ins', 'personas', NULL, '02_procedimientos.sql', '4f95ee1027eca38707fa38217690d1c6'),
    ('DISPARADOR', 'trg_aud_personas_upd', 'personas', NULL, '02_procedimientos.sql', '50359db0bbbb0a25e40869b462210201'),
    ('DISPARADOR', 'trg_aud_personas_del', 'personas', NULL, '02_procedimientos.sql', 'b291d0bdadd82eb17d3acf2117ab2a90'),
    ('DISPARADOR', 'trg_aud_usr_telefonos_ins', 'usr_telefonos', NULL, '02_procedimientos.sql', '8a52f3757671b17643d22728d1e5bc4e'),
    ('DISPARADOR', 'trg_aud_usr_telefonos_upd', 'usr_telefonos', NULL, '02_procedimientos.sql', '946a80cbb6726c959bb0ac62f0049267'),
    ('DISPARADOR', 'trg_aud_usr_telefonos_del', 'usr_telefonos', NULL, '02_procedimientos.sql', 'd9b11f0542f73199408e10c31d0ae96b'),
    ('DISPARADOR', 'trg_aud_usr_correos_ins', 'usr_correos', NULL, '02_procedimientos.sql', 'f00d1518476535b3d48f8163bf47eb75'),
    ('DISPARADOR', 'trg_aud_usr_correos_upd', 'usr_correos', NULL, '02_procedimientos.sql', '28e273390e9fab9a0a48756868f84b43'),
    ('DISPARADOR', 'trg_aud_usr_correos_del', 'usr_correos', NULL, '02_procedimientos.sql', '3ee6ae36ef3355cf0dd748fb7d353892'),
    ('DISPARADOR', 'trg_aud_usr_paginas_webs_ins', 'usr_paginas_webs', NULL, '02_procedimientos.sql', '9b1f211d801bd7bb0e085b40f7606242'),
    ('DISPARADOR', 'trg_aud_usr_paginas_webs_upd', 'usr_paginas_webs', NULL, '02_procedimientos.sql', 'a32745ac7c69fb88038c93562f8dd259'),
    ('DISPARADOR', 'trg_aud_usr_paginas_webs_del', 'usr_paginas_webs', NULL, '02_procedimientos.sql', '7e7ce9fb9c34332c36ae6bafe55beb52'),
    ('DISPARADOR', 'trg_aud_usr_historiales_claves_ins', 'usr_historiales_claves', NULL, '02_procedimientos.sql', 'f8768447dd19ab8ed2f6d40abfdd128b'),
    ('DISPARADOR', 'trg_aud_usr_historiales_claves_upd', 'usr_historiales_claves', NULL, '02_procedimientos.sql', '21a93a748b01c006b7ae35b0baa3b394'),
    ('DISPARADOR', 'trg_aud_usr_historiales_claves_del', 'usr_historiales_claves', NULL, '02_procedimientos.sql', '73b3723af2600682537227845d7c81a1'),
    ('DISPARADOR', 'trg_aud_auditorias_sin_cambios', 'aud_auditorias', NULL, '02_procedimientos.sql', 'd3d7772e734dbc8b05a50d394411f82b'),
    ('DISPARADOR', 'trg_mayus_tipo_equipos_ins', 'tipo_equipos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_equipos_upd', 'tipo_equipos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_marcas_ins', 'marcas', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_marcas_upd', 'marcas', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_modelos_ins', 'modelos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_modelos_upd', 'modelos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_procesadores_ins', 'procesadores', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_procesadores_upd', 'procesadores', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_sis_operativos_ins', 'sis_operativos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_sis_operativos_upd', 'sis_operativos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_firmwares_ins', 'firmwares', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_firmwares_upd', 'firmwares', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_estado_equipos_ins', 'estado_equipos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_estado_equipos_upd', 'estado_equipos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_roles_ins', 'tipo_roles', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_roles_upd', 'tipo_roles', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_herramientas_ins', 'tipo_herramientas', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_herramientas_upd', 'tipo_herramientas', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_archivos_ins', 'tipo_archivos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_tipo_archivos_upd', 'tipo_archivos', NULL, 'procedimientosDispositivos.sql', '4eb56eebcefd8e85fc329a08b0d9572b'),
    ('DISPARADOR', 'trg_mayus_edificios_ins', 'edificios', NULL, 'procedimientosDispositivos.sql', '547775fcd5a7a7183767d9b86cabaae9'),
    ('DISPARADOR', 'trg_mayus_edificios_upd', 'edificios', NULL, 'procedimientosDispositivos.sql', '547775fcd5a7a7183767d9b86cabaae9'),
    ('DISPARADOR', 'trg_mayus_equipos_ins', 'equipos', NULL, 'procedimientosDispositivos.sql', '9f31d1c362385b771c4b9534d003e096'),
    ('DISPARADOR', 'trg_mayus_equipos_upd', 'equipos', NULL, 'procedimientosDispositivos.sql', '9f31d1c362385b771c4b9534d003e096'),
    ('DISPARADOR', 'trg_mayus_dir_ips_ins', 'dir_ips', NULL, 'procedimientosDispositivos.sql', 'd0e74c0f3bd4992371a785b7c07f9de1'),
    ('DISPARADOR', 'trg_mayus_dir_ips_upd', 'dir_ips', NULL, 'procedimientosDispositivos.sql', 'd0e74c0f3bd4992371a785b7c07f9de1'),
    ('DISPARADOR', 'trg_mayus_dir_macs_ins', 'dir_macs', NULL, 'procedimientosDispositivos.sql', 'd0e74c0f3bd4992371a785b7c07f9de1'),
    ('DISPARADOR', 'trg_mayus_dir_macs_upd', 'dir_macs', NULL, 'procedimientosDispositivos.sql', 'd0e74c0f3bd4992371a785b7c07f9de1'),
    ('DISPARADOR', 'trg_mayus_num_moviles_ins', 'num_moviles', NULL, 'procedimientosDispositivos.sql', '42ffc3f729e66d480272341a53d7106f'),
    ('DISPARADOR', 'trg_mayus_num_moviles_upd', 'num_moviles', NULL, 'procedimientosDispositivos.sql', '42ffc3f729e66d480272341a53d7106f'),
    ('DISPARADOR', 'trg_mayus_puertos_switch_ins', 'puertos_switch', NULL, 'procedimientosDispositivos.sql', '2a058913ca323d98c7f97030e359ba01'),
    ('DISPARADOR', 'trg_mayus_puertos_switch_upd', 'puertos_switch', NULL, 'procedimientosDispositivos.sql', '2a058913ca323d98c7f97030e359ba01'),
    ('DISPARADOR', 'trg_formato_edificios_ins', 'edificios', NULL, 'procedimientosDispositivos.sql', 'f6d5c0afbf82416ab0c98c333a6ed283'),
    ('DISPARADOR', 'trg_formato_edificios_upd', 'edificios', NULL, 'procedimientosDispositivos.sql', 'f6d5c0afbf82416ab0c98c333a6ed283'),
    ('DISPARADOR', 'trg_formato_equipos_ins', 'equipos', NULL, 'procedimientosDispositivos.sql', '122c93e14938f6e51052a7d83adbfb84'),
    ('DISPARADOR', 'trg_formato_equipos_upd', 'equipos', NULL, 'procedimientosDispositivos.sql', '122c93e14938f6e51052a7d83adbfb84'),
    ('DISPARADOR', 'trg_formato_dir_ips_ins', 'dir_ips', NULL, 'procedimientosDispositivos.sql', '95b315bff6ebf98241f74053d1e4c6d4'),
    ('DISPARADOR', 'trg_formato_dir_ips_upd', 'dir_ips', NULL, 'procedimientosDispositivos.sql', '95b315bff6ebf98241f74053d1e4c6d4'),
    ('DISPARADOR', 'trg_formato_dir_macs_ins', 'dir_macs', NULL, 'procedimientosDispositivos.sql', 'f55c50883591a1d1c2288ce58defa269'),
    ('DISPARADOR', 'trg_formato_dir_macs_upd', 'dir_macs', NULL, 'procedimientosDispositivos.sql', 'f55c50883591a1d1c2288ce58defa269'),
    ('DISPARADOR', 'trg_formato_num_moviles_ins', 'num_moviles', NULL, 'procedimientosDispositivos.sql', '07838074f61f308df8baca8fb792cd9c'),
    ('DISPARADOR', 'trg_formato_num_moviles_upd', 'num_moviles', NULL, 'procedimientosDispositivos.sql', '07838074f61f308df8baca8fb792cd9c'),
    ('DISPARADOR', 'trg_formato_dir_imeis_ins', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', '3f9d28f10cb90ba236f31629f1c6af38'),
    ('DISPARADOR', 'trg_formato_dir_imeis_upd', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', '3f9d28f10cb90ba236f31629f1c6af38'),
    ('DISPARADOR', 'trg_valida_equipos_ins', 'equipos', NULL, 'procedimientosDispositivos.sql', '3665b1dac62974d4127cf15d96961e89'),
    ('DISPARADOR', 'trg_valida_equipos_upd', 'equipos', NULL, 'procedimientosDispositivos.sql', '3665b1dac62974d4127cf15d96961e89'),
    ('DISPARADOR', 'trg_valida_dir_ips_ins', 'dir_ips', NULL, 'procedimientosDispositivos.sql', '376b30b1ae7636ba66dff3cc901278f2'),
    ('DISPARADOR', 'trg_valida_dir_ips_upd', 'dir_ips', NULL, 'procedimientosDispositivos.sql', '376b30b1ae7636ba66dff3cc901278f2'),
    ('DISPARADOR', 'trg_valida_dir_macs_ins', 'dir_macs', NULL, 'procedimientosDispositivos.sql', '57dbc7fb7adb24b3711761937085bad6'),
    ('DISPARADOR', 'trg_valida_dir_macs_upd', 'dir_macs', NULL, 'procedimientosDispositivos.sql', '57dbc7fb7adb24b3711761937085bad6'),
    ('DISPARADOR', 'trg_valida_num_moviles_ins', 'num_moviles', NULL, 'procedimientosDispositivos.sql', 'd0ab0d9d7e1eab583c5e298e33fc10c4'),
    ('DISPARADOR', 'trg_valida_num_moviles_upd', 'num_moviles', NULL, 'procedimientosDispositivos.sql', 'd0ab0d9d7e1eab583c5e298e33fc10c4'),
    ('DISPARADOR', 'trg_valida_dir_imeis_ins', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', '5e19deb47cb16eb0fb32914b1239c658'),
    ('DISPARADOR', 'trg_valida_dir_imeis_upd', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', '5e19deb47cb16eb0fb32914b1239c658'),
    ('DISPARADOR', 'trg_aud_tipo_equipos_ins', 'tipo_equipos', NULL, 'procedimientosDispositivos.sql', 'e258461e3c688638c693f1d81647c9ed'),
    ('DISPARADOR', 'trg_aud_tipo_equipos_upd', 'tipo_equipos', NULL, 'procedimientosDispositivos.sql', '252e09e7c3ec91f0ad9d06656b95b14d'),
    ('DISPARADOR', 'trg_aud_tipo_equipos_del', 'tipo_equipos', NULL, 'procedimientosDispositivos.sql', '07f0e16665dafe67da6a83978d6e7e31'),
    ('DISPARADOR', 'trg_aud_marcas_ins', 'marcas', NULL, 'procedimientosDispositivos.sql', 'a845a7ae428ef9bd1ce5be1d250d80bf'),
    ('DISPARADOR', 'trg_aud_marcas_upd', 'marcas', NULL, 'procedimientosDispositivos.sql', 'a6e21dc77b12b193b9e233aff3847f68'),
    ('DISPARADOR', 'trg_aud_marcas_del', 'marcas', NULL, 'procedimientosDispositivos.sql', '84bad8b3ca4430967ad41e14a9716d9f'),
    ('DISPARADOR', 'trg_aud_modelos_ins', 'modelos', NULL, 'procedimientosDispositivos.sql', '744d83c1991318129efee629c3d1e76c'),
    ('DISPARADOR', 'trg_aud_modelos_upd', 'modelos', NULL, 'procedimientosDispositivos.sql', '17f247c661d1e163e2ec5d234d5a496f'),
    ('DISPARADOR', 'trg_aud_modelos_del', 'modelos', NULL, 'procedimientosDispositivos.sql', '59b0250358282279efe559e6a63bf226'),
    ('DISPARADOR', 'trg_aud_procesadores_ins', 'procesadores', NULL, 'procedimientosDispositivos.sql', 'da9373eb32cac7c67de0d5ec6e45ecc7'),
    ('DISPARADOR', 'trg_aud_procesadores_upd', 'procesadores', NULL, 'procedimientosDispositivos.sql', '3f02a0d80cb321e02ff05bea76d11148'),
    ('DISPARADOR', 'trg_aud_procesadores_del', 'procesadores', NULL, 'procedimientosDispositivos.sql', 'cee9a811d5bd04350f8cf7c585a04c40'),
    ('DISPARADOR', 'trg_aud_sis_operativos_ins', 'sis_operativos', NULL, 'procedimientosDispositivos.sql', 'ee479c39ed58ab174e07327aeca2a752'),
    ('DISPARADOR', 'trg_aud_sis_operativos_upd', 'sis_operativos', NULL, 'procedimientosDispositivos.sql', '40be5854ef04a6c6b15b6a7e2995a881'),
    ('DISPARADOR', 'trg_aud_sis_operativos_del', 'sis_operativos', NULL, 'procedimientosDispositivos.sql', 'f81adb54b1696a5465c1ab865891d00e'),
    ('DISPARADOR', 'trg_aud_firmwares_ins', 'firmwares', NULL, 'procedimientosDispositivos.sql', '579ad77f188abc4feda739a8c574cd5f'),
    ('DISPARADOR', 'trg_aud_firmwares_upd', 'firmwares', NULL, 'procedimientosDispositivos.sql', '08a64acac16eb3066930704958f695d6'),
    ('DISPARADOR', 'trg_aud_firmwares_del', 'firmwares', NULL, 'procedimientosDispositivos.sql', '0913119de50ee738719a9b743f9bb9cf'),
    ('DISPARADOR', 'trg_aud_edificios_ins', 'edificios', NULL, 'procedimientosDispositivos.sql', 'de9da42620a18e2d2f811efbad42bfc5'),
    ('DISPARADOR', 'trg_aud_edificios_upd', 'edificios', NULL, 'procedimientosDispositivos.sql', '0697fa7a3658950a10fde3f34ccf465a'),
    ('DISPARADOR', 'trg_aud_edificios_del', 'edificios', NULL, 'procedimientosDispositivos.sql', '436b22ca8eda4c2612c0b9a6590c76ed'),
    ('DISPARADOR', 'trg_aud_estado_equipos_ins', 'estado_equipos', NULL, 'procedimientosDispositivos.sql', '9a80031cc9a2243cfd5a00e8b2806edf'),
    ('DISPARADOR', 'trg_aud_estado_equipos_upd', 'estado_equipos', NULL, 'procedimientosDispositivos.sql', 'afeb96c6deee001db2a02e75d7fd4053'),
    ('DISPARADOR', 'trg_aud_estado_equipos_del', 'estado_equipos', NULL, 'procedimientosDispositivos.sql', 'f2c6cbc6b815b380b8ffe112f81e68c1'),
    ('DISPARADOR', 'trg_aud_tipo_roles_ins', 'tipo_roles', NULL, 'procedimientosDispositivos.sql', 'a6c3fc898e62efc82fe2d93496340598'),
    ('DISPARADOR', 'trg_aud_tipo_roles_upd', 'tipo_roles', NULL, 'procedimientosDispositivos.sql', '40e5545d9de88fa374719379614ee949'),
    ('DISPARADOR', 'trg_aud_tipo_roles_del', 'tipo_roles', NULL, 'procedimientosDispositivos.sql', 'cb69fe85de5f5a2d49716e803959415f'),
    ('DISPARADOR', 'trg_aud_tipo_herramientas_ins', 'tipo_herramientas', NULL, 'procedimientosDispositivos.sql', '8472e6e8d3da83e4de3202ef946dce6e'),
    ('DISPARADOR', 'trg_aud_tipo_herramientas_upd', 'tipo_herramientas', NULL, 'procedimientosDispositivos.sql', '9708b31f3e7ccd3a0ba4b43106bb420e'),
    ('DISPARADOR', 'trg_aud_tipo_herramientas_del', 'tipo_herramientas', NULL, 'procedimientosDispositivos.sql', '2e6e8b5e046dc88e5cdbccd9a1cac86d'),
    ('DISPARADOR', 'trg_aud_tipo_archivos_ins', 'tipo_archivos', NULL, 'procedimientosDispositivos.sql', '8879d04d7c70e6b2aeb182f457da96cb'),
    ('DISPARADOR', 'trg_aud_tipo_archivos_upd', 'tipo_archivos', NULL, 'procedimientosDispositivos.sql', '9dd00c3c957515fa36bf4a677d37cefd'),
    ('DISPARADOR', 'trg_aud_tipo_archivos_del', 'tipo_archivos', NULL, 'procedimientosDispositivos.sql', 'd2a110c452df6257c3cdcdab1dc1d58e'),
    ('DISPARADOR', 'trg_aud_equipos_ins', 'equipos', NULL, 'procedimientosDispositivos.sql', 'c53c984ba5c79403438c91c3ee6d9ebd'),
    ('DISPARADOR', 'trg_aud_equipos_upd', 'equipos', NULL, 'procedimientosDispositivos.sql', 'df8452e8a344fcbb93d5e5a59461ba8f'),
    ('DISPARADOR', 'trg_aud_equipos_del', 'equipos', NULL, 'procedimientosDispositivos.sql', 'a0a53681768f54d231653285f15f4c78'),
    ('DISPARADOR', 'trg_aud_dir_ips_ins', 'dir_ips', NULL, 'procedimientosDispositivos.sql', 'd54deb0507c5ac9b8d82d956f0b64a96'),
    ('DISPARADOR', 'trg_aud_dir_ips_upd', 'dir_ips', NULL, 'procedimientosDispositivos.sql', '0dd830246470739d49fb823de07ec7ec'),
    ('DISPARADOR', 'trg_aud_dir_ips_del', 'dir_ips', NULL, 'procedimientosDispositivos.sql', '54b665478974f56c0a7b50a4a3af4a00'),
    ('DISPARADOR', 'trg_aud_dir_macs_ins', 'dir_macs', NULL, 'procedimientosDispositivos.sql', 'b0b62d536a7db7fbbcc63f909ed3ad05'),
    ('DISPARADOR', 'trg_aud_dir_macs_upd', 'dir_macs', NULL, 'procedimientosDispositivos.sql', '8d764999df7aef8617635d1ad1723186'),
    ('DISPARADOR', 'trg_aud_dir_macs_del', 'dir_macs', NULL, 'procedimientosDispositivos.sql', 'd725a9ab8247e51d2d12934eecbbcaf0'),
    ('DISPARADOR', 'trg_aud_num_moviles_ins', 'num_moviles', NULL, 'procedimientosDispositivos.sql', 'f4bc4e760d9ff5976bc522fac440be6e'),
    ('DISPARADOR', 'trg_aud_num_moviles_upd', 'num_moviles', NULL, 'procedimientosDispositivos.sql', 'cbf0e5baa667e5d8bd595fd5205a773d'),
    ('DISPARADOR', 'trg_aud_num_moviles_del', 'num_moviles', NULL, 'procedimientosDispositivos.sql', '73da39709f33c3edca40d3cefd45a1e6'),
    ('DISPARADOR', 'trg_aud_dir_imeis_ins', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', 'a5dfad54569970d2f687b7033adefa53'),
    ('DISPARADOR', 'trg_aud_dir_imeis_upd', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', 'f73001bb9cd42d8e97233a128ccc87bd'),
    ('DISPARADOR', 'trg_aud_dir_imeis_del', 'dir_imeis', NULL, 'procedimientosDispositivos.sql', 'f2899dbab54d2be3dde4a6729b55538a'),
    ('DISPARADOR', 'trg_aud_roles_ins', 'roles', NULL, 'procedimientosDispositivos.sql', 'e82727d9d036be578d771ba82f9b9ab7'),
    ('DISPARADOR', 'trg_aud_roles_upd', 'roles', NULL, 'procedimientosDispositivos.sql', 'fbb9be1fcc5fca4e534c753bc8d41487'),
    ('DISPARADOR', 'trg_aud_roles_del', 'roles', NULL, 'procedimientosDispositivos.sql', 'da1c40705e1acc7137193bb2d191bee8'),
    ('DISPARADOR', 'trg_aud_herramientas_ins', 'herramientas', NULL, 'procedimientosDispositivos.sql', '01938c9014ef04d3bdfe0e75dcd97b90'),
    ('DISPARADOR', 'trg_aud_herramientas_upd', 'herramientas', NULL, 'procedimientosDispositivos.sql', 'a7e860cbad36ce1f08c8f46af9e55947'),
    ('DISPARADOR', 'trg_aud_herramientas_del', 'herramientas', NULL, 'procedimientosDispositivos.sql', '00a0d91d81e5dff6b92e6688b6bc01e3'),
    ('DISPARADOR', 'trg_aud_archivos_ins', 'archivos', NULL, 'procedimientosDispositivos.sql', '7597856fd9b6413a4ddd2290cc1c23f2'),
    ('DISPARADOR', 'trg_aud_archivos_upd', 'archivos', NULL, 'procedimientosDispositivos.sql', '4a47ef7f3091ccdd79bdd32206f6b4cd'),
    ('DISPARADOR', 'trg_aud_archivos_del', 'archivos', NULL, 'procedimientosDispositivos.sql', 'ad2931758d55103c060ac38f8bdd0abf'),
    ('DISPARADOR', 'trg_aud_puertos_switch_ins', 'puertos_switch', NULL, 'procedimientosDispositivos.sql', 'bfcc141e08740e91036f0ded58eb64e3'),
    ('DISPARADOR', 'trg_aud_puertos_switch_upd', 'puertos_switch', NULL, 'procedimientosDispositivos.sql', '89198a7aa693a1d0aafd36c42bf40452'),
    ('DISPARADOR', 'trg_aud_puertos_switch_del', 'puertos_switch', NULL, 'procedimientosDispositivos.sql', '8c549e668b6324af6f315d292a5a5fcc'),
    ('DISPARADOR', 'trg_formato_log_mapeo_campos_ins', 'log_mapeo_campos', NULL, 'procedimientosLogs.sql', '9c234c3c4c06da82eada946da3bc9b23'),
    ('DISPARADOR', 'trg_formato_log_mapeo_campos_upd', 'log_mapeo_campos', NULL, 'procedimientosLogs.sql', '9c234c3c4c06da82eada946da3bc9b23'),
    ('DISPARADOR', 'trg_aud_log_importaciones_ins', 'log_importaciones', NULL, 'procedimientosLogs.sql', '6ecb78c160cd124070c6908fa2af40dc'),
    ('DISPARADOR', 'trg_aud_log_importaciones_del', 'log_importaciones', NULL, 'procedimientosLogs.sql', '676c11cbccdd872d28358724b103186d'),
    ('DISPARADOR', 'trg_aud_log_mapeo_campos_ins', 'log_mapeo_campos', NULL, 'procedimientosLogs.sql', '1dfdeab8ebccfbeb412ac2f2344ce229'),
    ('DISPARADOR', 'trg_aud_log_mapeo_campos_upd', 'log_mapeo_campos', NULL, 'procedimientosLogs.sql', '2863896fede5263d8527b03cefcf5cc5'),
    ('DISPARADOR', 'trg_aud_log_mapeo_campos_del', 'log_mapeo_campos', NULL, 'procedimientosLogs.sql', '6a26ec92fd48a91fc3eec0ce6139df2e'),
    ('DISPARADOR', 'trg_formato_cor_envios_destinatarios_ins', 'cor_envios_destinatarios', NULL, 'procedimientosCorreo.sql', 'bfe6a233e284cc7573f8c3592b2b6ba8'),
    ('DISPARADOR', 'trg_formato_cor_listas_correos_ins', 'cor_listas_correos', NULL, 'procedimientosCorreo.sql', 'bfe6a233e284cc7573f8c3592b2b6ba8'),
    ('DISPARADOR', 'trg_aud_cor_configuracion_ins', 'cor_configuracion', NULL, 'procedimientosCorreo.sql', '1cd8bd3c54f83f850295b02047f32ac7'),
    ('DISPARADOR', 'trg_aud_cor_configuracion_upd', 'cor_configuracion', NULL, 'procedimientosCorreo.sql', '2ce31783ab4f274572b2fe3de86b9667'),
    ('DISPARADOR', 'trg_aud_cor_envios_ins', 'cor_envios', NULL, 'procedimientosCorreo.sql', '7a7e9bf6bef8166c4aa8513ec7a191ec'),
    ('DISPARADOR', 'trg_aud_cor_envios_upd', 'cor_envios', NULL, 'procedimientosCorreo.sql', '4c428b4ccb877f30b40548dad042dfdc'),
    ('DISPARADOR', 'trg_aud_cor_envios_del', 'cor_envios', NULL, 'procedimientosCorreo.sql', '5d2826f14b0a811bbee649c06943e284'),
    ('DISPARADOR', 'trg_aud_cor_listas_ins', 'cor_listas', NULL, 'procedimientosCorreo.sql', '96f1288c9029b3b806a3cefa2b8c3be6'),
    ('DISPARADOR', 'trg_aud_cor_listas_upd', 'cor_listas', NULL, 'procedimientosCorreo.sql', 'd4b6ab5884cdaaa92d5b06334c6841ee'),
    ('DISPARADOR', 'trg_aud_cor_listas_del', 'cor_listas', NULL, 'procedimientosCorreo.sql', 'e239112ad187153dc7f457ef132071a7'),
    ('INDICE', 'idx_aud_tabla_llave', 'aud_auditorias', NULL, 'creacionDispositivo.sql', NULL),
    ('INDICE', 'idx_logev_nombre_equipo', 'log_eventos', NULL, 'creacionLogs.sql', NULL),
    ('INDICE', 'idx_corlis_origen', 'cor_listas', NULL, 'creacionCorreo.sql', NULL),
    ('DATOS', 'cat_categorias_proveedores', NULL, '8', '03_datos.sql', NULL),
    ('DATOS', 'cat_departamentos', NULL, '1', '03_datos.sql', NULL),
    ('DATOS', 'cat_roles_usuarios', NULL, '2', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_autenticaciones', NULL, '2', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_correos', NULL, '3', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_identificaciones', NULL, '5', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_telefonos', NULL, '4', '03_datos.sql', NULL),
    ('DATOS', 'categoria_equipos', NULL, '10', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'edificios', NULL, '4', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'estado_equipos', NULL, '3', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'firmwares', NULL, '2', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'geo_cantones', NULL, '84', '03_datos.sql', NULL),
    ('DATOS', 'geo_distritos', NULL, '491', '03_datos.sql', NULL),
    ('DATOS', 'geo_paises', NULL, '1', '03_datos.sql', NULL),
    ('DATOS', 'geo_provincias', NULL, '7', '03_datos.sql', NULL),
    ('DATOS', 'log_mapeo_campos', NULL, '101', 'insercionLogs.sql', NULL),
    ('DATOS', 'marcas', NULL, '98', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'modelos', NULL, '9', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'procesadores', NULL, '2', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'sis_operativos', NULL, '15', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'tipo_archivos', NULL, '10', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'tipo_equipos', NULL, '28', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'tipo_herramientas', NULL, '4', 'insercionDispositivos.sql', NULL),
    ('DATOS', 'tipo_roles', NULL, '5', 'insercionDispositivos.sql', NULL);

DROP TEMPORARY TABLE IF EXISTS rev_problemas;
CREATE TEMPORARY TABLE rev_problemas (
    n            INT AUTO_INCREMENT PRIMARY KEY,
    gravedad     VARCHAR(10)  NOT NULL,
    objeto       VARCHAR(200) NOT NULL,
    problema     VARCHAR(300) NOT NULL,
    como_arreglar VARCHAR(300) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Contenido de un procedimiento o disparador sin comentarios ni espacios,
-- para saber si es la misma versión que la de los scripts.
-- (Se calcula igual al generar este archivo.)

-- ------------------------------------------------------------ servidor
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Servidor ', VERSION()), 'Se necesita MariaDB 10.2.7 o superior.', 'Actualice MariaDB.'
  FROM DUAL
 WHERE VERSION() NOT LIKE '%MariaDB%'
    OR CAST(SUBSTRING_INDEX(VERSION(), '.', 1) AS UNSIGNED) * 10000
       + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(VERSION(), '.', 2), '.', -1) AS UNSIGNED) * 100
       + CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING_INDEX(VERSION(), '-', 1), '.', 3), '.', -1) AS UNSIGNED) < 100207;

-- ------------------------------------- scripts que no se han ejecutado
-- Si no existe NADA de lo que crea un script (por ejemplo, nunca se
-- ejecutó 02_procedimientos.sql), se muestra una sola fila por script en lugar
-- de una por cada tabla, procedimiento o disparador.
DROP TEMPORARY TABLE IF EXISTS rev_existe;
CREATE TEMPORARY TABLE rev_existe CHARACTER SET utf8 COLLATE utf8_general_ci AS
SELECT IF(e.tipo = 'FUNCION', 'PROCEDIMIENTO', e.tipo) AS grupo, e.archivo,
       CASE e.tipo
           WHEN 'TABLA' THEN EXISTS (SELECT 1 FROM information_schema.TABLES t
                                      WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = e.nombre)
           WHEN 'DISPARADOR' THEN EXISTS (SELECT 1 FROM information_schema.TRIGGERS g
                                           WHERE g.TRIGGER_SCHEMA = DATABASE() AND g.TRIGGER_NAME = e.nombre)
           ELSE EXISTS (SELECT 1 FROM information_schema.ROUTINES r
                         WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = e.nombre)
       END AS existe
  FROM rev_esperado e
 WHERE e.tipo IN ('TABLA', 'PROCEDIMIENTO', 'FUNCION', 'DISPARADOR');

DROP TEMPORARY TABLE IF EXISTS rev_sin_ejecutar;
CREATE TEMPORARY TABLE rev_sin_ejecutar CHARACTER SET utf8 COLLATE utf8_general_ci AS
SELECT grupo, archivo, COUNT(*) AS cantidad
  FROM rev_existe
 GROUP BY grupo, archivo
HAVING COUNT(*) > 1 AND SUM(existe) = 0;

INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR',
       CONCAT(CASE grupo WHEN 'TABLA' THEN 'Tablas' WHEN 'DISPARADOR' THEN 'Disparadores' ELSE 'Procedimientos' END,
              ' de ', archivo, ' (', cantidad, ')'),
       CONCAT('No existe ', IF(grupo = 'TABLA', 'ninguna', 'ninguno'), ': el script no se ha ejecutado en esta base.'),
       CONCAT('Ejecute ', archivo, '.')
  FROM rev_sin_ejecutar
 ORDER BY FIELD(grupo, 'TABLA', 'PROCEDIMIENTO', 'DISPARADOR'), archivo;

-- ------------------------------------------------------------- tablas
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Tabla ', e.nombre), 'No existe.', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
 WHERE e.tipo = 'TABLA'
   AND NOT EXISTS (SELECT 1 FROM information_schema.TABLES t
                    WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = e.nombre)
   AND NOT EXISTS (SELECT 1 FROM rev_sin_ejecutar x WHERE x.grupo = 'TABLA' AND x.archivo = e.archivo);

-- Tablas con el nombre de una versión anterior (sus datos están ahí)
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Tabla ', e.nombre), CONCAT('Es del modelo de datos anterior (ahora: ', e.detalle, ').'),
       CONCAT('Ejecute bash reinstalar_base.sh (', e.archivo, '): pasa sus datos al modelo nuevo.')
  FROM rev_esperado e
 WHERE e.tipo = 'TABLA_VIEJA'
   AND EXISTS (SELECT 1 FROM information_schema.TABLES t
                WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = e.nombre);

-- Columnas que faltan (en tablas que sí existen)
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Columna ', e.nombre, '.', e.detalle), 'No existe: la tabla es de una versión anterior.',
       CASE e.archivo
           WHEN 'creacionDispositivo.sql' THEN 'Ejecute bash reinstalar_base.sh: pasa la base al modelo nuevo sin borrar datos.'
           WHEN 'creacionLogs.sql' THEN 'Ejecute creacionLogs.sql: agrega las columnas nuevas sin borrar datos.'
           WHEN 'creacionCorreo.sql' THEN 'Ejecute creacionCorreo.sql.'
           ELSE CONCAT('Falta un script de actualización para esta tabla (compárela con ', e.archivo, ').')
       END
  FROM rev_esperado e
 WHERE e.tipo = 'COLUMNA'
   AND EXISTS (SELECT 1 FROM information_schema.TABLES t
                WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = e.nombre)
   AND NOT EXISTS (SELECT 1 FROM information_schema.COLUMNS c
                    WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = e.nombre AND c.COLUMN_NAME = e.detalle);

-- Columnas de texto con otro tipo o largo (por ejemplo la MAC en CHAR(12))
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'AVISO', CONCAT('Columna ', e.nombre, '.', e.detalle),
       CONCAT('Es ', c.COLUMN_TYPE, ' y debe ser ', UPPER(SUBSTRING_INDEX(e.valor, ':', 1)), '(', SUBSTRING_INDEX(e.valor, ':', -1), ').'),
       IF(e.archivo = 'creacionDispositivo.sql', 'Ejecute bash reinstalar_base.sh.',
          CONCAT('Compare la tabla con ', e.archivo, '.'))
  FROM rev_esperado e
  JOIN information_schema.COLUMNS c
    ON c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = e.nombre AND c.COLUMN_NAME = e.detalle
 WHERE e.tipo = 'COLUMNA' AND e.valor IS NOT NULL
   AND CONCAT(c.DATA_TYPE, ':', c.CHARACTER_MAXIMUM_LENGTH) <> e.valor;

-- Columnas de versiones anteriores que ya no deben estar
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Columna ', e.nombre, '.', e.detalle), 'Es de una versión anterior y ya no debe estar.', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
 WHERE e.tipo = 'VIEJA'
   AND EXISTS (SELECT 1 FROM information_schema.COLUMNS c
                WHERE c.TABLE_SCHEMA = DATABASE() AND c.TABLE_NAME = e.nombre AND c.COLUMN_NAME = e.detalle);

-- Índices
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'AVISO', CONCAT('Índice ', e.nombre, ' de ', e.detalle), 'No existe (las búsquedas del historial son más lentas).', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
 WHERE e.tipo = 'INDICE'
   AND EXISTS (SELECT 1 FROM information_schema.TABLES t
                WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = e.detalle)
   AND NOT EXISTS (SELECT 1 FROM information_schema.STATISTICS s
                    WHERE s.TABLE_SCHEMA = DATABASE() AND s.TABLE_NAME = e.detalle AND s.INDEX_NAME = e.nombre);

-- ------------------------------------------- procedimientos y funciones
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT(IF(e.tipo = 'FUNCION', 'Función ', 'Procedimiento '), e.nombre), 'No existe.', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
 WHERE e.tipo IN ('PROCEDIMIENTO', 'FUNCION')
   AND NOT EXISTS (SELECT 1 FROM information_schema.ROUTINES r
                    WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = e.nombre
                      AND r.ROUTINE_TYPE = IF(e.tipo = 'FUNCION', 'FUNCTION', 'PROCEDURE'))
   AND NOT EXISTS (SELECT 1 FROM rev_sin_ejecutar x WHERE x.grupo = 'PROCEDIMIENTO' AND x.archivo = e.archivo);

-- Parámetros distintos: es una versión anterior (como "expected 11, got 13")
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Procedimiento ', e.nombre),
       CONCAT('Versión anterior: tiene ', COALESCE(f.cuantos, 0), ' parámetros y debe tener ',
              IF(COALESCE(e.valor, '') = '', 0, LENGTH(e.valor) - LENGTH(REPLACE(e.valor, ',', '')) + 1), '.'),
       CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
  JOIN information_schema.ROUTINES r
    ON r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = e.nombre AND r.ROUTINE_TYPE = 'PROCEDURE'
  LEFT JOIN (SELECT p.SPECIFIC_NAME AS nombre, COUNT(*) AS cuantos,
                    GROUP_CONCAT(CONCAT(p.PARAMETER_MODE, ' ', p.PARAMETER_NAME) ORDER BY p.ORDINAL_POSITION SEPARATOR ', ') AS firma
               FROM information_schema.PARAMETERS p
              WHERE p.SPECIFIC_SCHEMA = DATABASE() AND p.ROUTINE_TYPE = 'PROCEDURE' AND p.ORDINAL_POSITION > 0
              GROUP BY p.SPECIFIC_NAME) f
    ON f.nombre = e.nombre
 WHERE e.tipo = 'PROCEDIMIENTO'
   AND COALESCE(f.firma, '') <> COALESCE(e.valor, '');

-- Mismos parámetros pero otro contenido: también es otra versión
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT(IF(e.tipo = 'FUNCION', 'Función ', 'Procedimiento '), e.nombre),
       'Su contenido es de otra versión (no coincide con el script).', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
  JOIN information_schema.ROUTINES r
    ON r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_NAME = e.nombre
   AND r.ROUTINE_TYPE = IF(e.tipo = 'FUNCION', 'FUNCTION', 'PROCEDURE')
 WHERE e.tipo IN ('PROCEDIMIENTO', 'FUNCION') AND e.huella IS NOT NULL AND r.ROUTINE_DEFINITION IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM rev_problemas x WHERE x.objeto = CONCAT('Procedimiento ', e.nombre))
   AND MD5(REGEXP_REPLACE(REGEXP_REPLACE(r.ROUTINE_DEFINITION, '--[^\\n]*', ''), '[ \\t\\r\\n]+', '')) <> e.huella;

-- Sin permiso para leer el contenido (los creó otro usuario de la base)
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'AVISO', CONCAT(COUNT(*), ' procedimientos y funciones'),
       CONCAT('Los creó otro usuario (', MIN(r.DEFINER), ') y con este no se puede revisar su contenido.'),
       'Al ejecutar los scripts con este usuario se vuelven a crear y quedan a su nombre.'
  FROM information_schema.ROUTINES r
 WHERE r.ROUTINE_SCHEMA = DATABASE() AND r.ROUTINE_DEFINITION IS NULL
HAVING COUNT(*) > 0;

-- Procedimientos y funciones que los scripts ya no crean
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'AVISO', CONCAT(IF(r.ROUTINE_TYPE = 'FUNCTION', 'Función ', 'Procedimiento '), r.ROUTINE_NAME),
       'Los scripts ya no lo crean (de una versión anterior; no hace daño).',
       CONCAT('Si quiere, bórrelo: DROP ', r.ROUTINE_TYPE, ' ', r.ROUTINE_NAME, ';')
  FROM information_schema.ROUTINES r
 WHERE r.ROUTINE_SCHEMA = DATABASE()
   -- Solo los de estos módulos: si la base tiene otros, de una versión
   -- anterior del modelo de datos, no se cuentan aquí.
   AND r.ROUTINE_NAME REGEXP '^(sp_(personas|usr|cat|geo|prv|aud|pad|equipos|archivos|categoria|dir|edificios|estado|firmwares|marcas|modelos|num|procesadores|puertos|sis|tipo|log|cor)_|fn_(formato_telefono|formato_mac|categoria_por_nombre|rotulo_puerto)$)'
   AND NOT EXISTS (SELECT 1 FROM rev_esperado e
                    WHERE e.tipo IN ('PROCEDIMIENTO', 'FUNCION') AND e.nombre = r.ROUTINE_NAME);

-- --------------------------------------------------------- disparadores
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Disparador ', e.nombre, ' (', e.detalle, ')'), 'No existe.', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
 WHERE e.tipo = 'DISPARADOR'
   AND NOT EXISTS (SELECT 1 FROM information_schema.TRIGGERS g
                    WHERE g.TRIGGER_SCHEMA = DATABASE() AND g.TRIGGER_NAME = e.nombre)
   AND NOT EXISTS (SELECT 1 FROM rev_sin_ejecutar x WHERE x.grupo = 'DISPARADOR' AND x.archivo = e.archivo);

INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Disparador ', e.nombre, ' (', e.detalle, ')'),
       'Su contenido es de otra versión (no coincide con el script).', CONCAT('Ejecute ', e.archivo, '.')
  FROM rev_esperado e
  JOIN information_schema.TRIGGERS g
    ON g.TRIGGER_SCHEMA = DATABASE() AND g.TRIGGER_NAME = e.nombre
 WHERE e.tipo = 'DISPARADOR' AND e.huella IS NOT NULL
   AND (g.EVENT_OBJECT_TABLE <> e.detalle
        OR MD5(REGEXP_REPLACE(REGEXP_REPLACE(g.ACTION_STATEMENT, '--[^\\n]*', ''), '[ \\t\\r\\n]+', '')) <> e.huella);

-- Disparadores que los scripts ya no crean: se ejecutan en cada cambio y
-- pueden usar columnas que ya no existen
INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
SELECT 'ERROR', CONCAT('Disparador ', g.TRIGGER_NAME, ' (', g.EVENT_OBJECT_TABLE, ')'),
       'Es de una versión anterior: los scripts ya no lo crean.',
       CONCAT('Bórrelo: DROP TRIGGER ', g.TRIGGER_NAME, ';')
  FROM information_schema.TRIGGERS g
 WHERE g.TRIGGER_SCHEMA = DATABASE()
   -- Solo los de las tablas de estos módulos
   AND g.EVENT_OBJECT_TABLE IN (SELECT nombre FROM rev_esperado WHERE tipo = 'TABLA')
   AND NOT EXISTS (SELECT 1 FROM rev_esperado e WHERE e.tipo = 'DISPARADOR' AND e.nombre = g.TRIGGER_NAME);

-- ------------------------------------------------- datos y administrador
-- (consultas armadas en el momento: la tabla podría no existir)
DELIMITER $$
BEGIN NOT ATOMIC
    DECLARE v_fin     INT DEFAULT 0;
    DECLARE v_tabla   VARCHAR(64);
    DECLARE v_minimo  INT;
    DECLARE v_archivo VARCHAR(64);
    DECLARE v_columna VARCHAR(64);
    DECLARE c_texto CURSOR FOR
        SELECT c.TABLE_NAME, c.COLUMN_NAME
          FROM information_schema.COLUMNS c
         WHERE c.TABLE_SCHEMA = DATABASE()
           AND c.DATA_TYPE IN ('char', 'varchar', 'text')
           AND (c.TABLE_NAME IN (SELECT e.nombre FROM rev_esperado e WHERE e.tipo = 'DATOS')
                OR c.TABLE_NAME IN ('personas', 'edificios', 'equipos'))
           AND c.COLUMN_NAME NOT LIKE '%path%' AND c.COLUMN_NAME NOT LIKE '%hash%';
    DECLARE c_datos CURSOR FOR
        SELECT e.nombre, CAST(e.valor AS UNSIGNED), e.archivo
          FROM rev_esperado e
         WHERE e.tipo = 'DATOS'
           AND EXISTS (SELECT 1 FROM information_schema.TABLES t
                        WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = e.nombre);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fin = 1;

    OPEN c_datos;
    leer: LOOP
        FETCH c_datos INTO v_tabla, v_minimo, v_archivo;
        IF v_fin = 1 THEN
            LEAVE leer;
        END IF;
        EXECUTE IMMEDIATE CONCAT('SELECT COUNT(*) INTO @rev_filas FROM `', v_tabla, '`');
        IF @rev_filas = 0 THEN
            INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
            VALUES ('ERROR', CONCAT('Datos de ', v_tabla),
                    CONCAT('Está vacía; la carga inicial trae ', v_minimo, ' filas.'),
                    CONCAT('Ejecute ', v_archivo, '.'));
        ELSEIF @rev_filas < v_minimo THEN
            INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
            VALUES ('AVISO', CONCAT('Datos de ', v_tabla),
                    CONCAT('Tiene ', @rev_filas, ' filas y la carga inicial trae ', v_minimo, ' (¿se borró alguna?).'),
                    CONCAT('Si faltan, ejecute ', v_archivo, ': solo agrega las que no están.'));
        END IF;
    END LOOP;
    CLOSE c_datos;

    -- Letras dañadas: texto cargado con un programa en otra codificación
    -- (latin1), que se ve como ESTÃNDAR o CÃ‰DULA en vez de ESTÁNDAR o CÉDULA
    SET v_fin = 0;
    OPEN c_texto;
    texto: LOOP
        FETCH c_texto INTO v_tabla, v_columna;
        IF v_fin = 1 THEN
            LEAVE texto;
        END IF;
        EXECUTE IMMEDIATE CONCAT('SELECT COUNT(*), MIN(`', v_columna, '`) INTO @rev_filas, @rev_ejemplo FROM `', v_tabla,
                                 '` WHERE `', v_columna, '` LIKE BINARY ''%Ã%'' OR `', v_columna, '` LIKE BINARY ''%Â%''');
        IF @rev_filas > 0 THEN
            INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
            VALUES ('ERROR', CONCAT('Datos de ', v_tabla, '.', v_columna),
                    LEFT(CONCAT(@rev_filas, ' fila(s) con letras dañadas, por ejemplo "', @rev_ejemplo, '".'), 300),
                    IF(v_tabla LIKE 'cat\\_%' OR v_tabla LIKE 'geo\\_%' OR v_tabla IN ('categoria_equipos', 'tipo_equipos', 'marcas', 'modelos', 'procesadores', 'sis_operativos', 'firmwares', 'edificios', 'estado_equipos', 'tipo_roles', 'tipo_herramientas', 'tipo_archivos'),
                       'Se cargaron leyendo el archivo como latin1. Ejecute bash reinstalar_base.sh: las corrige.',
                       'Se guardaron leyendo el texto como latin1. Son datos de personas o equipos: corríjalos en la página.'));
        END IF;
    END LOOP;
    CLOSE c_texto;

    IF EXISTS (SELECT 1 FROM information_schema.TABLES t
                WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'personas') THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) INTO @rev_filas FROM personas WHERE es_proveedor = FALSE AND activo = TRUE AND password_hash IS NOT NULL';
        IF @rev_filas = 0 THEN
            INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
            VALUES ('ERROR', 'Usuarios', 'No hay ningún usuario activo con clave: nadie puede entrar al sistema.',
                    'En el servidor: python manage.py inicializar --usuario admin');
        END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.TABLES t
                WHERE t.TABLE_SCHEMA = DATABASE() AND t.TABLE_NAME = 'pad_padron') THEN
        EXECUTE IMMEDIATE 'SELECT COUNT(*) INTO @rev_filas FROM (SELECT 1 FROM pad_padron LIMIT 1) x';
        IF @rev_filas = 0 THEN
            INSERT INTO rev_problemas (gravedad, objeto, problema, como_arreglar)
            VALUES ('AVISO', 'Padrón del TSE', 'Está vacío: al escribir una cédula no se llenan nombre y apellidos.',
                    'Opcional: cargue el padrón del TSE en la tabla pad_padron; sin él, el nombre se escribe a mano.');
        END IF;
    END IF;

END$$
DELIMITER ;

-- ------------------------------------------------------------ resultado
SELECT ROW_NUMBER() OVER (ORDER BY gravedad = 'AVISO', n) AS '#', gravedad, objeto, problema, como_arreglar
  FROM rev_problemas
 ORDER BY gravedad = 'AVISO', n;

SELECT CASE
           WHEN SUM(gravedad = 'ERROR') > 0 THEN CONCAT('HAY ', SUM(gravedad = 'ERROR'), ' ERROR(ES) y ', SUM(gravedad = 'AVISO'), ' aviso(s): arréglelos en el orden de la lista.')
           WHEN COUNT(*) > 0 THEN CONCAT('TODO BIEN, con ', COUNT(*), ' aviso(s).')
           ELSE 'TODO BIEN: la base está como debe.'
       END AS resultado,
       (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE()) AS tablas,
       (SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE') AS procedimientos,
       (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE()) AS disparadores,
       VERSION() AS servidor
  FROM rev_problemas;

DROP TEMPORARY TABLE IF EXISTS rev_problemas;
DROP TEMPORARY TABLE IF EXISTS rev_esperado;
