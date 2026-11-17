-- =====================================================================
--  revisar_base.sql - ¿La base gestion_redes está como debe?
-- ---------------------------------------------------------------------
--  Módulo de usuarios y proveedores. Compara la base con lo que crean
--  los scripts de la carpeta instalacion:
--    - 18 tablas con sus 89 columnas
--    - 98 procedimientos (parámetros y contenido) y 1 función
--    - 82 disparadores
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
    ('DATOS', 'cat_categorias_proveedores', NULL, '8', '03_datos.sql', NULL),
    ('DATOS', 'cat_departamentos', NULL, '1', '03_datos.sql', NULL),
    ('DATOS', 'cat_roles_usuarios', NULL, '2', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_autenticaciones', NULL, '2', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_correos', NULL, '3', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_identificaciones', NULL, '5', '03_datos.sql', NULL),
    ('DATOS', 'cat_tipos_telefonos', NULL, '4', '03_datos.sql', NULL),
    ('DATOS', 'geo_cantones', NULL, '84', '03_datos.sql', NULL),
    ('DATOS', 'geo_distritos', NULL, '491', '03_datos.sql', NULL),
    ('DATOS', 'geo_paises', NULL, '1', '03_datos.sql', NULL),
    ('DATOS', 'geo_provincias', NULL, '7', '03_datos.sql', NULL),
    ('DISPARADOR', 'trg_aud_auditorias_sin_cambios', 'aud_auditorias', NULL, '02_procedimientos.sql', 'd3d7772e734dbc8b05a50d394411f82b');

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
   -- Solo los de este módulo: si la base también tiene otros módulos, los
   -- procedimientos de esos no se cuentan aquí.
   AND r.ROUTINE_NAME REGEXP '^(sp_(personas|usr|cat|geo|prv|aud|pad)_|fn_formato_telefono$)'
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
   -- Solo los de las tablas de este módulo
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
