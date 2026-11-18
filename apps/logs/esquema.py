"""Campos comunes (normalizados) de los logs.

Cada programa (Sophos, Microclaudia, el DHCP y, más adelante, otros) llama distinto a lo mismo:
Sophos usa fw_rule_id en el firewall y rule_id en la inspección SSL;
domain en el filtro web y sni en SSL. Aquí se define un solo nombre para
cada dato, con su etiqueta, su grupo y su tipo, y los alias de cada
fuente. Este archivo es la única definición: generar_logs.py lo usa para
crear las columnas de log_eventos y los alias iniciales de la base.
"""

# (campo, etiqueta, grupo, tipo, largo)
# tipo: fecha | texto | ip | mac | puerto | numero | accion
CAMPOS = [
    # General
    ("fecha", "Fecha y hora", "General", "fecha", None),
    ("tipo", "Tipo de log", "General", "texto", 60),
    ("accion", "Acción", "General", "accion", 12),
    ("tipo_log", "Clase", "General", "texto", 60),
    ("componente", "Componente", "General", "texto", 60),
    ("subtipo", "Resultado", "General", "texto", 60),
    ("descripcion", "Descripción", "General", "texto", 255),
    ("dispositivo", "Firewall que lo registró", "General", "texto", 100),
    ("id_mensaje", "Código del mensaje", "General", "texto", 20),
    ("severidad", "Severidad", "General", "texto", 30),
    # Regla y política
    ("regla_id", "Regla (código)", "Regla y política", "texto", 20),
    ("regla_nombre", "Regla", "Regla y política", "texto", 150),
    ("regla_seccion", "Sección de la regla", "Regla y política", "texto", 60),
    ("nat_regla_id", "Regla NAT (código)", "Regla y política", "texto", 20),
    ("nat_regla", "Regla NAT", "Regla y política", "texto", 150),
    ("politica_web", "Política web", "Regla y política", "texto", 150),
    ("actividad", "Actividad", "Regla y política", "texto", 150),
    ("motivo", "Motivo", "Regla y política", "texto", 255),
    # Usuario
    ("usuario", "Usuario", "Usuario", "texto", 100),
    ("grupo_usuario", "Grupo del usuario", "Usuario", "texto", 100),
    # Origen
    ("ip_origen", "IP de origen", "Origen", "ip", 45),
    ("puerto_origen", "Puerto de origen", "Origen", "puerto", None),
    ("mac_origen", "MAC de origen", "Origen", "mac", 12),
    ("pais_origen", "País de origen", "Origen", "texto", 10),
    ("zona_origen", "Zona de origen", "Origen", "texto", 30),
    ("interfaz_entrada", "Interfaz de entrada", "Origen", "texto", 100),
    ("ip_origen_nat", "IP de origen traducida (NAT)", "Origen", "ip", 45),
    ("nombre_equipo", "Nombre del equipo", "Origen", "texto", 100),
    ("sistema_operativo", "Sistema operativo", "Origen", "texto", 150),
    # Destino
    ("ip_destino", "IP de destino", "Destino", "ip", 45),
    ("puerto_destino", "Puerto de destino", "Destino", "puerto", None),
    ("mac_destino", "MAC de destino", "Destino", "mac", 12),
    ("pais_destino", "País de destino", "Destino", "texto", 10),
    ("zona_destino", "Zona de destino", "Destino", "texto", 30),
    ("interfaz_salida", "Interfaz de salida", "Destino", "texto", 100),
    ("ip_destino_nat", "IP de destino traducida (NAT)", "Destino", "ip", 45),
    # Web
    ("dominio", "Dominio", "Web", "texto", 255),
    ("url", "URL", "Web", "texto", None),
    ("categoria", "Categoría", "Web", "texto", 100),
    ("categoria_tipo", "Tipo de categoría", "Web", "texto", 50),
    ("codigo_http", "Código HTTP", "Web", "numero", None),
    ("tipo_contenido", "Tipo de contenido", "Web", "texto", 100),
    ("navegador", "Navegador (user agent)", "Web", "texto", None),
    # Aplicación y cifrado
    ("aplicacion", "Aplicación", "Aplicación", "texto", 150),
    ("aplicacion_categoria", "Categoría de la aplicación", "Aplicación", "texto", 100),
    ("aplicacion_riesgo", "Riesgo de la aplicación", "Aplicación", "numero", None),
    ("version_tls", "Versión TLS", "Aplicación", "texto", 20),
    ("cifrado", "Cifrado", "Aplicación", "texto", 100),
    ("version_agente", "Versión del agente", "Aplicación", "texto", 50),
    ("vacunas_aplicadas", "Vacunas aplicadas", "Aplicación", "numero", None),
    ("vacunas_pendientes", "Vacunas pendientes", "Aplicación", "numero", None),
    ("vacunas_error", "Vacunas con error", "Aplicación", "numero", None),
    # Tráfico
    ("protocolo", "Protocolo", "Tráfico", "texto", 20),
    ("bytes_enviados", "Bytes enviados", "Tráfico", "numero", None),
    ("bytes_recibidos", "Bytes recibidos", "Tráfico", "numero", None),
    ("paquetes_enviados", "Paquetes enviados", "Tráfico", "numero", None),
    ("paquetes_recibidos", "Paquetes recibidos", "Tráfico", "numero", None),
    ("duracion", "Duración (segundos)", "Tráfico", "numero", None),
    ("id_conexion", "Conexión (con_id)", "Tráfico", "texto", 30),
]
CAMPO = {c[0]: c for c in CAMPOS}
NOMBRES = [c[0] for c in CAMPOS]
GRUPOS = list(dict.fromkeys(c[2] for c in CAMPOS))

# Alias de Sophos (nombre en el log -> campo común). Si un evento trae
# varios alias del mismo campo, gana el de menor prioridad (domain antes
# que sni; la interfaz con nombre antes que el puerto físico).
ALIAS_SOPHOS = [
    ("device_name", "dispositivo", 1), ("device", "dispositivo", 2),
    ("messageid", "id_mensaje", 1), ("message_id", "id_mensaje", 2), ("log_id", "id_mensaje", 3),
    ("log_type", "tipo_log", 1),
    ("log_component", "componente", 1),
    ("log_subtype", "subtipo", 1), ("status", "subtipo", 2),
    ("severity", "severidad", 1), ("priority", "severidad", 2),
    ("fw_rule_id", "regla_id", 1), ("rule_id", "regla_id", 2), ("firewall_rule_id", "regla_id", 3),
    ("fw_rule_name", "regla_nombre", 1), ("rule_name", "regla_nombre", 2), ("firewall_rule_name", "regla_nombre", 3),
    ("fw_rule_section", "regla_seccion", 1),
    ("nat_rule_id", "nat_regla_id", 1),
    ("nat_rule_name", "nat_regla", 1),
    ("web_policy", "politica_web", 1),
    ("activity_name", "actividad", 1),
    ("reason", "motivo", 1), ("message", "motivo", 2),
    ("user", "usuario", 1), ("user_name", "usuario", 2), ("username", "usuario", 3),
    ("user_group", "grupo_usuario", 1), ("usergroupname", "grupo_usuario", 2),
    ("src_ip", "ip_origen", 1), ("source_ip", "ip_origen", 2),
    ("src_port", "puerto_origen", 1), ("source_port", "puerto_origen", 2),
    ("src_mac", "mac_origen", 1),
    ("src_country", "pais_origen", 1), ("src_country_code", "pais_origen", 2),
    ("src_zone", "zona_origen", 1), ("src_zone_type", "zona_origen", 2),
    ("in_display_interface", "interfaz_entrada", 1), ("in_interface", "interfaz_entrada", 2),
    ("src_trans_ip", "ip_origen_nat", 1), ("tran_src_ip", "ip_origen_nat", 2),
    ("dst_ip", "ip_destino", 1), ("destination_ip", "ip_destino", 2),
    ("dst_port", "puerto_destino", 1), ("destination_port", "puerto_destino", 2),
    ("dst_mac", "mac_destino", 1),
    ("dst_country", "pais_destino", 1), ("dst_country_code", "pais_destino", 2),
    ("dst_zone", "zona_destino", 1), ("dst_zone_type", "zona_destino", 2),
    ("out_display_interface", "interfaz_salida", 1), ("out_interface", "interfaz_salida", 2),
    ("dst_trans_ip", "ip_destino_nat", 1), ("tran_dst_ip", "ip_destino_nat", 2),
    ("domain", "dominio", 1), ("sni", "dominio", 2), ("fqdn", "dominio", 3), ("host", "dominio", 4),
    ("url", "url", 1),
    ("category", "categoria", 1),
    ("category_type", "categoria_tipo", 1),
    ("status_code", "codigo_http", 1), ("http_status", "codigo_http", 2),
    ("content_type", "tipo_contenido", 1),
    ("user_agent", "navegador", 1),
    ("app_name", "aplicacion", 1), ("application", "aplicacion", 2),
    ("app_category", "aplicacion_categoria", 1),
    ("app_risk", "aplicacion_riesgo", 1),
    ("tls_version", "version_tls", 1),
    ("cipher_suite", "cifrado", 1),
    ("protocol", "protocolo", 1),
    ("bytes_sent", "bytes_enviados", 1), ("sent_bytes", "bytes_enviados", 2),
    ("bytes_received", "bytes_recibidos", 1), ("recv_bytes", "bytes_recibidos", 2),
    ("packets_sent", "paquetes_enviados", 1), ("sent_pkts", "paquetes_enviados", 2),
    ("packets_received", "paquetes_recibidos", 1), ("recv_pkts", "paquetes_recibidos", 2),
    ("con_duration", "duracion", 1), ("duration", "duracion", 2),
    ("con_id", "id_conexion", 1), ("connection_id", "id_conexion", 2),
]

# Alias de Microclaudia (listado de equipos con el agente de S2 Grupo).
# ip_principal, mac_principal y producto no vienen en el archivo: los
# calcula el lector (la primera IPv4 interna y la primera MAC del equipo).
ALIAS_MICROCLAUDIA = [
    ("nombre", "nombre_equipo", 1), ("hostname", "nombre_equipo", 2),
    ("sist_operativo", "sistema_operativo", 1), ("sistema_operativo", "sistema_operativo", 2),
    ("version", "version_agente", 1),
    ("total_vacunas_aplicadas", "vacunas_aplicadas", 1),
    ("total_vacunas_pendientes", "vacunas_pendientes", 1),
    ("total_vacunas_error", "vacunas_error", 1),
    ("ip_principal", "ip_origen", 1),
    ("mac_principal", "mac_origen", 1),
    ("producto", "aplicacion", 1),
]

# Alias del DHCP de Windows (concesiones y reservas). ip_principal,
# mac_principal y producto los calcula el lector (la MAC sale del Id. exclusivo).
ALIAS_DHCP = [
    ("nombre", "nombre_equipo", 1),
    ("descripcion", "descripcion", 1),
    ("ip_principal", "ip_origen", 1),
    ("mac_principal", "mac_origen", 1),
    ("producto", "aplicacion", 1),
]

ALIAS_POR_FUENTE = {"SOPHOS": ALIAS_SOPHOS, "MICROCLAUDIA": ALIAS_MICROCLAUDIA, "DHCP": ALIAS_DHCP}

# Nombres al estilo Wireshark que también entiende el filtro
ALIAS_FILTRO = {
    "ip.src": "ip_origen", "ip.dst": "ip_destino", "eth.src": "mac_origen", "eth.dst": "mac_destino",
    "tcp.srcport": "puerto_origen", "udp.srcport": "puerto_origen", "src.port": "puerto_origen",
    "tcp.dstport": "puerto_destino", "udp.dstport": "puerto_destino", "dst.port": "puerto_destino",
    "http.host": "dominio", "tls.sni": "dominio", "tls.handshake.extensions_server_name": "dominio",
    "http.request.uri": "url", "http.user_agent": "navegador", "http.response.code": "codigo_http",
    "frame.time": "fecha", "time": "fecha", "user.name": "usuario", "rule": "regla_nombre",
    "regla": "regla_nombre", "action": "accion", "app": "aplicacion", "category": "categoria",
    "conexion": "id_conexion", "src": "ip_origen", "dst": "ip_destino",
    "host.name": "nombre_equipo", "hostname": "nombre_equipo", "equipo_nombre": "nombre_equipo",
    "os": "sistema_operativo", "agente.version": "version_agente",
}

# Campos virtuales del filtro: valen para origen o destino (ip.addr de Wireshark)
CAMPOS_AMBOS = {
    "ip": ("ip_origen", "ip_destino", "ip_origen_nat", "ip_destino_nat"),
    "ip.addr": ("ip_origen", "ip_destino", "ip_origen_nat", "ip_destino_nat"),
    "mac": ("mac_origen", "mac_destino"),
    "eth.addr": ("mac_origen", "mac_destino"),
    "puerto": ("puerto_origen", "puerto_destino"),
    "port": ("puerto_origen", "puerto_destino"),
    "tcp.port": ("puerto_origen", "puerto_destino"),
    "udp.port": ("puerto_origen", "puerto_destino"),
    "pais": ("pais_origen", "pais_destino"),
    "zona": ("zona_origen", "zona_destino"),
}

# Campos con los que se compara entre logs y con el inventario
CAMPOS_COMPARAR = ["ip_origen", "ip_destino", "dominio", "regla_nombre", "usuario", "mac_origen",
                   "categoria", "aplicacion", "puerto_destino", "id_conexion",
                   "nombre_equipo", "sistema_operativo", "version_agente"]

# Campos por los que se pueden contar los más frecuentes (tops)
CAMPOS_TOP = ["ip_origen", "ip_destino", "dominio", "regla_nombre", "categoria", "aplicacion", "usuario",
              "pais_destino", "puerto_destino", "tipo", "accion", "mac_origen", "zona_origen", "zona_destino",
              "politica_web", "protocolo", "id_conexion", "ip_origen_nat", "interfaz_entrada", "interfaz_salida",
              "categoria_tipo", "actividad", "dispositivo", "nombre_equipo", "sistema_operativo", "version_agente"]
