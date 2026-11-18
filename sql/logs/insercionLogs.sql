-- =====================================================================
--  insercionLogs.sql - módulo de análisis de logs
--  gestion_redes (MariaDB 10.2.7 o superior)
-- ---------------------------------------------------------------------
--  Paso 3 de 3. Alias de los campos (101): cada nombre que usa cada programa
--  (Sophos 85, Microclaudia 11, DHCP 5) y el campo común al que corresponde.
--  Solo agrega los que faltan (no cambia los que usted haya modificado).
--
--  Orden de instalación (después de los scripts de instalacion y de
--  dispositivos; reinstalar_base.sh los ejecuta todos en orden):
--     1. creacionLogs.sql         tablas
--     2. procedimientosLogs.sql   procedimientos y disparadores
--     3. insercionLogs.sql        alias de los campos (Sophos, Microclaudia y DHCP)
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

-- Sophos Firewall (85 alias)
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'device_name', 'dispositivo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'device_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'device', 'dispositivo', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'device');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'messageid', 'id_mensaje', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'messageid');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'message_id', 'id_mensaje', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'message_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'log_id', 'id_mensaje', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'log_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'log_type', 'tipo_log', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'log_type');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'log_component', 'componente', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'log_component');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'log_subtype', 'subtipo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'log_subtype');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'status', 'subtipo', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'status');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'severity', 'severidad', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'severity');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'priority', 'severidad', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'priority');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'fw_rule_id', 'regla_id', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'fw_rule_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'rule_id', 'regla_id', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'rule_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'firewall_rule_id', 'regla_id', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'firewall_rule_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'fw_rule_name', 'regla_nombre', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'fw_rule_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'rule_name', 'regla_nombre', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'rule_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'firewall_rule_name', 'regla_nombre', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'firewall_rule_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'fw_rule_section', 'regla_seccion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'fw_rule_section');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'nat_rule_id', 'nat_regla_id', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'nat_rule_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'nat_rule_name', 'nat_regla', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'nat_rule_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'web_policy', 'politica_web', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'web_policy');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'activity_name', 'actividad', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'activity_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'reason', 'motivo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'reason');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'message', 'motivo', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'message');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'user', 'usuario', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'user');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'user_name', 'usuario', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'user_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'username', 'usuario', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'username');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'user_group', 'grupo_usuario', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'user_group');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'usergroupname', 'grupo_usuario', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'usergroupname');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_ip', 'ip_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'source_ip', 'ip_origen', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'source_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_port', 'puerto_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_port');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'source_port', 'puerto_origen', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'source_port');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_mac', 'mac_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_mac');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_country', 'pais_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_country');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_country_code', 'pais_origen', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_country_code');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_zone', 'zona_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_zone');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_zone_type', 'zona_origen', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_zone_type');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'in_display_interface', 'interfaz_entrada', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'in_display_interface');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'in_interface', 'interfaz_entrada', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'in_interface');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'src_trans_ip', 'ip_origen_nat', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'src_trans_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'tran_src_ip', 'ip_origen_nat', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'tran_src_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_ip', 'ip_destino', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'destination_ip', 'ip_destino', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'destination_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_port', 'puerto_destino', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_port');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'destination_port', 'puerto_destino', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'destination_port');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_mac', 'mac_destino', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_mac');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_country', 'pais_destino', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_country');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_country_code', 'pais_destino', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_country_code');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_zone', 'zona_destino', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_zone');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_zone_type', 'zona_destino', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_zone_type');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'out_display_interface', 'interfaz_salida', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'out_display_interface');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'out_interface', 'interfaz_salida', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'out_interface');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'dst_trans_ip', 'ip_destino_nat', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'dst_trans_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'tran_dst_ip', 'ip_destino_nat', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'tran_dst_ip');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'domain', 'dominio', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'domain');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'sni', 'dominio', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'sni');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'fqdn', 'dominio', 3 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'fqdn');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'host', 'dominio', 4 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'host');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'url', 'url', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'url');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'category', 'categoria', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'category');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'category_type', 'categoria_tipo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'category_type');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'status_code', 'codigo_http', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'status_code');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'http_status', 'codigo_http', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'http_status');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'content_type', 'tipo_contenido', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'content_type');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'user_agent', 'navegador', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'user_agent');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'app_name', 'aplicacion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'app_name');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'application', 'aplicacion', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'application');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'app_category', 'aplicacion_categoria', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'app_category');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'app_risk', 'aplicacion_riesgo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'app_risk');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'tls_version', 'version_tls', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'tls_version');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'cipher_suite', 'cifrado', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'cipher_suite');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'protocol', 'protocolo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'protocol');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'bytes_sent', 'bytes_enviados', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'bytes_sent');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'sent_bytes', 'bytes_enviados', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'sent_bytes');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'bytes_received', 'bytes_recibidos', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'bytes_received');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'recv_bytes', 'bytes_recibidos', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'recv_bytes');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'packets_sent', 'paquetes_enviados', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'packets_sent');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'sent_pkts', 'paquetes_enviados', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'sent_pkts');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'packets_received', 'paquetes_recibidos', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'packets_received');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'recv_pkts', 'paquetes_recibidos', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'recv_pkts');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'con_duration', 'duracion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'con_duration');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'duration', 'duracion', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'duration');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'con_id', 'id_conexion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'con_id');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'SOPHOS', 'connection_id', 'id_conexion', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'SOPHOS' AND campo_origen = 'connection_id');

-- Microclaudia (listado de equipos con el agente) (11 alias)
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'nombre', 'nombre_equipo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'nombre');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'hostname', 'nombre_equipo', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'hostname');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'sist_operativo', 'sistema_operativo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'sist_operativo');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'sistema_operativo', 'sistema_operativo', 2 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'sistema_operativo');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'version', 'version_agente', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'version');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'total_vacunas_aplicadas', 'vacunas_aplicadas', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'total_vacunas_aplicadas');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'total_vacunas_pendientes', 'vacunas_pendientes', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'total_vacunas_pendientes');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'total_vacunas_error', 'vacunas_error', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'total_vacunas_error');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'ip_principal', 'ip_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'ip_principal');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'mac_principal', 'mac_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'mac_principal');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'MICROCLAUDIA', 'producto', 'aplicacion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'MICROCLAUDIA' AND campo_origen = 'producto');

-- Servidor DHCP de Windows (concesiones y reservas) (5 alias)
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'DHCP', 'nombre', 'nombre_equipo', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'DHCP' AND campo_origen = 'nombre');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'DHCP', 'descripcion', 'descripcion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'DHCP' AND campo_origen = 'descripcion');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'DHCP', 'ip_principal', 'ip_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'DHCP' AND campo_origen = 'ip_principal');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'DHCP', 'mac_principal', 'mac_origen', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'DHCP' AND campo_origen = 'mac_principal');
INSERT INTO log_mapeo_campos (fuente, campo_origen, campo, prioridad)
    SELECT 'DHCP', 'producto', 'aplicacion', 1 FROM DUAL
     WHERE NOT EXISTS (SELECT 1 FROM log_mapeo_campos WHERE fuente = 'DHCP' AND campo_origen = 'producto');

SET @muni_sin_auditoria = 0;

-- Revisión: alias por programa
SELECT fuente, COUNT(*) AS alias FROM log_mapeo_campos GROUP BY fuente ORDER BY fuente;
