"""Lógica del módulo de logs que usan las vistas: importar un archivo,
armar el filtro, el tablero, la comparación entre logs, el cruce con el
inventario, el tablero del agente de Microclaudia, la cobertura del
agente y los intrusos en la red (DHCP contra el inventario). Todo pasa
por los procedimientos sp_log_* (sql/logs)."""
import ipaddress
import json
import re
from collections import Counter, OrderedDict
from datetime import datetime, timedelta

from django.db import connection, transaction

from apps.core.auditoria import contexto_actual
from apps.core.db import llamar_sp

from . import filtro as flt
from . import normalizar as nz
from . import dhcp, microclaudia, sophos
from .esquema import CAMPO, CAMPOS, CAMPOS_COMPARAR, NOMBRES

# clase "logs": eventos de tráfico; clase "agentes": listado de equipos que
# tienen un agente instalado (cada fila es un equipo); clase "dhcp":
# concesiones y reservas del servidor DHCP (cada fila es una IP entregada)
FUENTES = {
    "SOPHOS": {"nombre": "Sophos Firewall", "lector": sophos.leer, "clase": "logs"},
    "MICROCLAUDIA": {"nombre": "Microclaudia", "lector": microclaudia.leer, "clase": "agentes"},
    "DHCP": {"nombre": "Servidor DHCP", "lector": dhcp.leer, "clase": "dhcp"},
}
FUENTES_AGENTES = [k for k, v in FUENTES.items() if v["clase"] == "agentes"]
FUENTES_DHCP = [k for k, v in FUENTES.items() if v["clase"] == "dhcp"]

# Tops que muestra el tablero de una importación o de un filtro
TOPS_TABLERO = ["ip_origen", "ip_destino", "dominio", "regla_nombre", "categoria", "aplicacion", "puerto_destino",
                "pais_destino", "usuario", "tipo"]


# --------------------------------------------------------------- alias
def alias(fuente="SOPHOS"):
    filas, _ = llamar_sp("sp_log_mapeo_campos_listar", [fuente])
    return nz.preparar_alias(filas or nz.alias_por_defecto(fuente))


def alias_para_filtro(fuente="SOPHOS"):
    """{nombre en el log: campo común} para que el filtro entienda src_ip, fw_rule_id..."""
    filas, _ = llamar_sp("sp_log_mapeo_campos_listar", [None])
    filas = filas or nz.alias_por_defecto(None)
    salida = {}
    for f in sorted(filas, key=lambda x: x["prioridad"]):
        salida.setdefault(f["campo_origen"].lower(), f["campo"])
    return salida


# --------------------------------------------------------------- filtro
def lista_ids(texto):
    """'1,2, 3' -> [1, 2, 3] (ignora lo que no sea número)."""
    return [int(x) for x in re.findall(r"\d+", str(texto or ""))][:50]


def armar_filtro(texto, importaciones=None):
    """Filtro del usuario + importaciones elegidas -> WHERE para los sp_log_eventos_*."""
    sql, usados = flt.a_sql(texto, alias_para_filtro())
    ids = lista_ids(importaciones) if not isinstance(importaciones, list) else importaciones
    por_importacion = f"e.id_importacion IN ({', '.join(str(int(i)) for i in ids)})" if ids else ""
    return flt.unir(sql, por_importacion), usados


# --------------------------------------------------------------- importar
def decodificar(contenido):
    for codificacion in ("utf-8-sig", "utf-16") if contenido[:2] in (b"\xff\xfe", b"\xfe\xff") else ("utf-8-sig",):
        try:
            return contenido.decode(codificacion)
        except UnicodeDecodeError:
            continue
    return contenido.decode("cp1252", errors="replace")


def insertar_eventos(id_importacion, normalizados):
    """Guarda los eventos uno por uno con sp_log_eventos_insertar, dentro de
    la transacción de la importación (rápido: un solo COMMIT al final)."""
    with connection.cursor() as cursor:
        for ev in normalizados:
            datos = json.dumps(ev.pop("datos"), ensure_ascii=False)
            cursor.execute("CALL sp_log_eventos_insertar(%s, %s, %s)",
                           [id_importacion, json.dumps(ev, ensure_ascii=False), datos])
            while cursor.nextset():
                pass


def importar(fuente, nombre_archivo, contenido, descripcion, id_usuario):
    """Lee, normaliza y guarda un archivo. Devuelve (id_importacion, leidos, avisos).
    Todo o nada: si algo falla, no queda la importación a medias."""
    lector = FUENTES[fuente]["lector"]
    eventos, avisos = lector(decodificar(contenido))
    if not eventos:
        return None, 0, avisos
    mapa = alias(fuente)
    normalizados = [nz.normalizar(e, mapa, fuente) for e in eventos]
    with transaction.atomic():
        _, id_importacion = llamar_sp("sp_log_importaciones_insertar",
                                      [fuente, nombre_archivo, descripcion, id_usuario], con_salida=True)
        insertar_eventos(id_importacion, normalizados)
        llamar_sp("sp_log_importaciones_cerrar", [id_importacion, len(eventos), len(avisos)])
    return id_importacion, len(eventos), avisos


# --------------------------------------------------------------- tablero
def intervalo_para(desde, hasta, puntos=48):
    """Segundos por barra para que la línea de tiempo tenga ~48 barras."""
    if not desde or not hasta:
        return 3600
    total = max((hasta - desde).total_seconds(), 1)
    for s in (1, 5, 10, 30, 60, 300, 600, 900, 1800, 3600, 7200, 10800, 21600, 43200, 86400, 604800):
        if total / s <= puntos:
            return s
    return 2592000


def tablero(where, tops=TOPS_TABLERO, limite_top=8):
    resumen = llamar_sp("sp_log_eventos_resumen", [where])[0][0]
    segundos = intervalo_para(resumen.get("desde"), resumen.get("hasta"))
    linea, _ = llamar_sp("sp_log_eventos_linea_tiempo", [where, segundos])
    salida_tops = {c: llamar_sp("sp_log_eventos_top", [where, c, limite_top])[0] for c in tops}
    correlacionados, _ = llamar_sp("sp_log_eventos_correlacionados", [where, 20])
    tipos, _ = llamar_sp("sp_log_eventos_top", [where, "tipo", 20])
    return {"resumen": resumen, "linea_tiempo": {"segundos": segundos, "puntos": linea},
            "tops": salida_tops, "tipos": tipos, "correlacionados": correlacionados}


# --------------------------------------------------------------- inventario
def es_interna(ip):
    try:
        d = ipaddress.ip_address(ip)
    except ValueError:
        return False
    return d.is_private or d.is_link_local


def cruce_inventario(where):
    ips, _ = llamar_sp("sp_log_inventario_ips", [where, 2000])
    macs, _ = llamar_sp("sp_log_inventario_macs", [where, 1000])
    usuarios, _ = llamar_sp("sp_log_inventario_usuarios", [where, 1000])
    inventariadas = [x for x in ips if x["id_disp"]]
    internas = [x for x in ips if not x["id_disp"] and es_interna(x["ip"])]
    externas = [x for x in ips if not x["id_disp"] and not es_interna(x["ip"])]
    # Un equipo puede tener varias IP: se agrupan por equipo
    equipos = OrderedDict()
    for x in inventariadas:
        e = equipos.setdefault(x["id_disp"], {"id_disp": x["id_disp"], "equipo": x["equipo"], "edificio": x["edificio"],
                                              "ips": [], "veces": 0, "permitidos": 0, "denegados": 0,
                                              "primera": x["primera"], "ultima": x["ultima"]})
        e["ips"].append(x["ip"])
        for k in ("veces", "permitidos", "denegados"):
            e[k] += int(x[k] or 0)
        e["primera"] = min(filter(None, [e["primera"], x["primera"]]), default=None)
        e["ultima"] = max(filter(None, [e["ultima"], x["ultima"]]), default=None)
    for m in macs:
        if m["id_disp"] and m["id_disp"] not in equipos:
            equipos[m["id_disp"]] = {"id_disp": m["id_disp"], "equipo": m["equipo"], "edificio": None, "ips": [],
                                     "veces": int(m["veces"] or 0), "permitidos": None, "denegados": None,
                                     "primera": m["primera"], "ultima": m["ultima"]}
        if m["id_disp"]:
            equipos[m["id_disp"]].setdefault("macs", []).append(m["mac"])
    return {
        "equipos": list(equipos.values()),
        "ips_internas_desconocidas": internas,
        "ips_externas": externas[:200],
        "macs": macs,
        "usuarios": usuarios,
        "totales": {"ips": len(ips), "inventariadas": len(inventariadas), "internas_desconocidas": len(internas),
                    "externas": len(externas), "macs": len(macs),
                    "macs_inventariadas": sum(1 for m in macs if m["id_disp"]),
                    "usuarios": len(usuarios), "usuarios_conocidos": sum(1 for u in usuarios if u["id_persona"])},
    }


# --------------------------------------------------------------- comparar
def comparar(conjuntos, campos=CAMPOS_COMPARAR, limite=5000):
    """conjuntos: [{"nombre", "where"}]. Compara los valores de cada campo
    entre los conjuntos (en todos, solo en uno...) y los eventos idénticos."""
    resumenes = [llamar_sp("sp_log_eventos_resumen", [c["where"]])[0][0] for c in conjuntos]
    por_campo = {}
    for campo in campos:
        valores = OrderedDict()
        for i, c in enumerate(conjuntos):
            for fila in llamar_sp("sp_log_eventos_top", [c["where"], campo, limite])[0]:
                v = valores.setdefault(str(fila["valor"]), {"valor": fila["valor"], "conteos": [0] * len(conjuntos),
                                                            "denegados": [0] * len(conjuntos)})
                v["conteos"][i] = int(fila["cantidad"])
                v["denegados"][i] = int(fila["denegados"] or 0)
        filas = list(valores.values())
        for f in filas:
            presentes = [i for i, n in enumerate(f["conteos"]) if n]
            f["en"] = presentes
            f["en_todos"] = len(presentes) == len(conjuntos)
        filas.sort(key=lambda f: (-len(f["en"]), -sum(f["conteos"]), str(f["valor"])))
        por_campo[campo] = {
            "en_todos": sum(1 for f in filas if f["en_todos"]),
            "solo": [sum(1 for f in filas if f["en"] == [i]) for i in range(len(conjuntos))],
            "valores": filas[:500],
            "total": len(filas),
        }
    huellas = [set(h["huella"] for h in llamar_sp("sp_log_eventos_huellas", [c["where"], 200000])[0]) for c in conjuntos]
    identicos = set.intersection(*huellas) if huellas else set()
    union = flt.unir(" OR ".join(f"({c['where'] or 'TRUE'})" for c in conjuntos))
    correlacionados, _ = llamar_sp("sp_log_eventos_correlacionados", [union, 200])
    return {"resumenes": resumenes, "campos": por_campo, "identicos": len(identicos),
            "correlacionados": correlacionados}


# --------------------------------------------------------------- exportar
COLUMNAS_INVENTARIO = ["equipo_origen", "equipo_destino", "persona"]


def paginas_exportar(where, maximo, tam=5000):
    hecho = 0
    while hecho < maximo:
        filas, _ = llamar_sp("sp_log_eventos_exportar", [where, min(tam, maximo - hecho), hecho])
        if not filas:
            return
        yield filas
        hecho += len(filas)
        if len(filas) < tam:
            return


def valor_exportable(v):
    if v is None:
        return ""
    if isinstance(v, datetime):
        return v.strftime("%Y-%m-%d %H:%M:%S")
    return v


def mac_guiones(m):
    return "-".join(m[i:i + 2] for i in range(0, 12, 2)) if m and len(m) == 12 else (m or "")


def fila_comun(f):
    """Una fila de exportación con los campos comunes y el inventario."""
    salida = OrderedDict([("id_evento", f["id_evento"]), ("importacion", f["id_importacion"]), ("fuente", f["fuente"])])
    for c in NOMBRES:
        v = f.get(c)
        salida[c] = mac_guiones(v) if CAMPO[c][3] == "mac" and v else valor_exportable(v)
    for c in COLUMNAS_INVENTARIO:
        salida[c] = valor_exportable(f.get(c))
    return salida


def cargar_datos(f):
    try:
        return json.loads(f.get("datos") or "{}")
    except ValueError:
        return {}


def hace(dias):
    return datetime.now() - timedelta(days=dias)


# --------------------------------------------------------------- agentes
PALABRAS_FILTRO = {"and", "or", "not", "in", "contains", "matches", "eq", "ne", "gt", "lt", "ge", "le"}


def literal(valor):
    """Valor escrito en el filtro (igual que literal() de logs_ui.js)."""
    texto = str(valor)
    if re.fullmatch(r"[^\s(){},!=<>~\"']+", texto) and texto.lower() not in PALABRAS_FILTRO:
        return texto
    return '"' + texto.replace("\\", "\\\\").replace('"', '\\"') + '"'


def ultima_importacion(fuente):
    filas, _ = llamar_sp("sp_log_importaciones_listar", [fuente])
    return filas[0] if filas else None          # ordenadas de la más nueva a la más vieja


def numero_version(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or ""))


# Sistemas que Microsoft ya no actualiza (Windows 10 terminó el 14 oct 2025)
SIN_SOPORTE = re.compile(r"windows\s+(xp|vista|7|8(\.1)?|10)\b|server\s+20(03|08|12)\b", re.I)

RED_VIRTUALBOX = "192.168.56."

# Tramos de la última conexión, contados hacia atrás desde la conexión más
# reciente del listado (el momento en que se sacó)
TRAMOS = [("24h", "Últimas 24 horas", 24), ("7d", "1 a 7 días", 24 * 7), ("30d", "8 a 30 días", 24 * 30),
          ("mas", "Más de 30 días", None)]
ALERTAS = {
    "sin_conexion": "Más de 7 días sin conectarse",
    "version": "Versión anterior del agente",
    "pendientes": "Vacunas pendientes",
    "error": "Vacunas con error",
    "soporte": "Sistema sin soporte",
    "ip_compartida": "IP repetida en otro equipo",
}


def tramo(horas):
    if horas is None:
        return "sin"
    for clave, _, limite in TRAMOS:
        if limite is None or horas <= limite:
            return clave
    return "mas"


def prefijo(nombre):
    m = re.match(r"[A-Za-z]+", nombre or "")
    return m.group().upper() if m else (nombre or "?")


def red24(ip):
    try:
        return str(ipaddress.ip_network(f"{ip}/24", strict=False)) if ip else None
    except ValueError:
        return None


def _conteo(valores, a_filtro):
    """[(valor)] -> [{"valor", "cantidad", "q"}] de mayor a menor."""
    c = Counter(v for v in valores if v)
    return [{"valor": v, "cantidad": n, "q": a_filtro(v)} for v, n in sorted(c.items(), key=lambda x: (-x[1], str(x[0])))]


def tablero_agentes(id_importacion):
    """Números y listas para el tablero de un listado de Microclaudia."""
    filas, _ = llamar_sp("sp_log_agentes_listar", [id_importacion])
    referencia = max((f["ultima_conexion"] for f in filas if f["ultima_conexion"]), default=None)
    versiones = Counter(f["version_agente"] for f in filas if f["version_agente"])
    actual = max(versiones, key=numero_version) if versiones else None

    # IP que reportan varios equipos. La red «solo anfitrión» de VirtualBox
    # (192.168.56.x) se repite en todos los equipos que lo tienen: no cuenta.
    por_ip = {}
    for f in filas:
        for ip in filter(None, (f["ips"] or "").split(",")):
            if not ip.startswith(RED_VIRTUALBOX):
                por_ip.setdefault(ip, []).append(f["nombre_equipo"])
    compartidas = {ip: nombres for ip, nombres in por_ip.items() if len(nombres) > 1}

    equipos = []
    for f in filas:
        horas = ((referencia - f["ultima_conexion"]).total_seconds() / 3600
                 if referencia and f["ultima_conexion"] else None)
        ips = [x for x in (f["ips"] or "").split(",") if x]
        t = tramo(horas)
        alertas = []
        if t in ("30d", "mas", "sin"):
            alertas.append("sin_conexion")
        if actual and f["version_agente"] and f["version_agente"] != actual:
            alertas.append("version")
        if (f["vacunas_pendientes"] or 0) > 0:
            alertas.append("pendientes")
        if (f["vacunas_error"] or 0) > 0:
            alertas.append("error")
        if SIN_SOPORTE.search(f["sistema_operativo"] or ""):
            alertas.append("soporte")
        if any(ip in compartidas for ip in ips):
            alertas.append("ip_compartida")
        equipos.append({
            "id_evento": f["id_evento"], "nombre": f["nombre_equipo"], "sistema": f["sistema_operativo"],
            "version": f["version_agente"], "ultima_conexion": f["ultima_conexion"], "fecha_alta": f["fecha_alta"],
            "horas": round(horas, 1) if horas is not None else None, "tramo": t,
            "aplicadas": f["vacunas_aplicadas"], "pendientes": f["vacunas_pendientes"], "errores": f["vacunas_error"],
            "ip": f["ip_principal"], "ips": ips, "macs": [x for x in (f["macs"] or "").split(",") if x],
            "prefijo": prefijo(f["nombre_equipo"]), "red": red24(f["ip_principal"]), "alertas": alertas,
        })

    def limite(h):
        return (referencia - timedelta(hours=h)).strftime("%Y-%m-%d %H:%M:%S")

    tramos = []
    for i, (clave, texto, horas) in enumerate(TRAMOS):
        if referencia is None:
            q = ""
        else:
            desde = f'fecha >= "{limite(horas)}"' if horas else ""
            hasta = f'fecha < "{limite(TRAMOS[i - 1][2])}"' if i else ""
            q = " and ".join(x for x in (desde, hasta) if x)
        tramos.append({"clave": clave, "valor": texto, "cantidad": sum(1 for e in equipos if e["tramo"] == clave), "q": q})
    sin_fecha = sum(1 for e in equipos if e["tramo"] == "sin")
    if sin_fecha:
        tramos.append({"clave": "sin", "valor": "Sin fecha", "cantidad": sin_fecha, "q": "not fecha"})

    cuenta = Counter(a for e in equipos for a in e["alertas"])
    return {
        "referencia": referencia,
        "total": len(equipos),
        "version_actual": actual,
        "tramos": tramos,
        "versiones": _conteo([e["version"] for e in equipos], lambda v: f"version_agente == {literal(v)}"),
        "sistemas": _conteo([e["sistema"] for e in equipos], lambda v: f"sistema_operativo == {literal(v)}"),
        "prefijos": _conteo([e["prefijo"] for e in equipos], lambda v: f'nombre_equipo matches "^{v}([^A-Za-z]|$)"'),
        "redes": _conteo([e["red"] for e in equipos], lambda v: f"ip_origen == {v}"),
        "alertas": [{"clave": k, "texto": t, "cantidad": cuenta.get(k, 0)} for k, t in ALERTAS.items()],
        "resumen": {
            "conectados_24h": sum(1 for e in equipos if e["tramo"] == "24h"),
            "sin_conexion_7d": cuenta.get("sin_conexion", 0),
            "desactualizados": cuenta.get("version", 0),
            "con_pendientes": cuenta.get("pendientes", 0),
            "con_error": cuenta.get("error", 0),
            "sin_soporte": cuenta.get("soporte", 0),
            "servidores": sum(1 for e in equipos if "server" in (e["sistema"] or "").lower()),
            "vacunas_pendientes": sum(e["pendientes"] or 0 for e in equipos),
            "ips_compartidas": len(compartidas),
        },
        "compartidas": [{"ip": ip, "equipos": n} for ip, n in sorted(compartidas.items(), key=lambda x: -len(x[1]))],
        "equipos": equipos,
    }


def _ip(texto):
    """IP escrita como la guarda log_direcciones (10.1.10.5, sin ceros de más)."""
    texto = (texto or "").strip().lower()
    try:
        return str(ipaddress.ip_address(texto))
    except ValueError:
        return texto


def nombre_corto(nombre):
    """'eacu-09.mgrecia.net' -> 'EACU-09' (para comparar nombres de equipo)."""
    return (nombre or "").strip().split(".")[0].upper() or None


def cobertura(id_agentes):
    """Equipos registrados en el sistema (equiposMuni activos) comparados por
    MAC, IP y nombre en la red con el listado de equipos que tienen el agente.

    Estado de cada equipo:
      con             una de sus MAC está en el listado, o su IP cuando no
                      tiene MAC registrada (o su IP y su nombre), o su
                      nombre en la red cuando no coincide por IP ni MAC
      revisar         su IP está en el listado, pero con otras MAC y otro
                      nombre: puede ser otro equipo que recibió esa IP del DHCP
      sin             ninguna de sus IP, MAC ni su nombre está en el listado
      sin_direcciones no tiene IP, MAC ni nombre registrados: no se puede comparar
    lleva_agente dice si por su categoría se espera que tenga el agente
    (computadoras y servidores): la página deja fuera a los demás.
    Además devuelve los equipos del listado que no son ningún equipo
    registrado (no_registrados); uno que solo coincide por una IP «por
    revisar» también se cuenta ahí."""
    agentes, _ = llamar_sp("sp_log_agentes_listar", [id_agentes])
    inventario, _ = llamar_sp("sp_log_cobertura_inventario", [id_agentes])
    referencia = max((a["ultima_conexion"] for a in agentes if a["ultima_conexion"]), default=None)

    por_ip, por_mac, por_nombre, fichas = {}, {}, {}, []
    for a in agentes:
        horas = ((referencia - a["ultima_conexion"]).total_seconds() / 3600
                 if referencia and a["ultima_conexion"] else None)
        ficha = {
            "id_evento": a["id_evento"], "nombre": a["nombre_equipo"], "sistema": a["sistema_operativo"],
            "version": a["version_agente"], "ultima_conexion": a["ultima_conexion"],
            "horas": round(horas, 1) if horas is not None else None, "tramo": tramo(horas),
            "ip": a["ip_principal"], "mac": a["mac_principal"],
            "ips": [x for x in (a["ips"] or "").split(",") if x],
            "macs": [x for x in (a["macs"] or "").split(",") if x],
        }
        fichas.append(ficha)
        for ip in ficha["ips"]:
            if not ip.startswith(RED_VIRTUALBOX):      # la comparten muchos equipos
                por_ip.setdefault(ip, []).append(ficha)
        for mac in ficha["macs"]:
            por_mac.setdefault(mac, []).append(ficha)
        if nombre_corto(ficha["nombre"]):
            por_nombre.setdefault(nombre_corto(ficha["nombre"]), []).append(ficha)

    def unicos(listas):
        """Los equipos del listado, sin repetir, del que se conectó último al más viejo."""
        vistos, salida = set(), []
        for f in sorted((f for lista in listas for f in lista),
                        key=lambda f: f["ultima_conexion"] or datetime.min, reverse=True):
            if f["id_evento"] not in vistos:
                vistos.add(f["id_evento"])
                salida.append(f)
        return salida

    dispositivos, coinciden = [], set()
    for d in inventario:
        ips = [_ip(x) for x in (d["ips"] or "").split(",") if x.strip()]
        macs = [x.strip().upper() for x in (d["macs"] or "").split(",") if x.strip()]
        nombre = d["nombre_corto"]
        por_m = unicos(por_mac.get(m, []) for m in macs)
        por_i = unicos(por_ip.get(ip, []) for ip in ips)
        por_n = unicos([por_nombre.get(nombre, [])]) if nombre else []
        candidatos = unicos([por_m, por_i, por_n])
        coinciden.update(f["id_evento"] for f in por_m)        # la MAC confirma que es ese equipo
        agente, por = None, None
        if not ips and not macs and not nombre:
            estado = "sin_direcciones"
        elif por_m:
            agente = por_m[0]
            estado = "con"
            por = "IP y MAC" if any(f["id_evento"] == agente["id_evento"] for f in por_i) else "MAC"
        elif por_i:
            mismo = next((f for f in por_i if any(f["id_evento"] == n["id_evento"] for n in por_n)), None)
            agente = mismo or por_i[0]
            estado = "revisar" if macs and not mismo else "con"
            por = "IP y nombre" if mismo else "IP"
            if estado == "con":
                coinciden.add(agente["id_evento"])
        elif por_n:
            # Mismo nombre, pero ninguna IP ni MAC en común (otra tarjeta de red o la IP cambió)
            agente = por_n[0]
            estado = "con"
            por = "nombre"
            coinciden.add(agente["id_evento"])
        else:
            estado = "sin"
        dispositivos.append({
            "id_disp": d["id_disp"], "tipo": d["tipo"], "categoria": d["categoria"],
            "lleva_agente": bool(d["lleva_agente"]), "equipo": d["equipo"], "edificio": d["edificio"],
            "nombre_equipo": d["nombre_equipo"], "asignado": d["asignado"],
            "ips": ips, "macs": macs, "estado": estado, "agente": agente, "por": por,
            "otros": [f["nombre"] for f in candidatos if agente is None or f["id_evento"] != agente["id_evento"]],
        })

    no_registrados = [f for f in fichas if f["id_evento"] not in coinciden]
    cuenta = Counter(x["estado"] for x in dispositivos)
    tipos = Counter(x["tipo"] for x in dispositivos)
    lleva = {x["tipo"]: x["lleva_agente"] for x in dispositivos}
    categoria = {x["tipo"]: x["categoria"] for x in dispositivos}
    return {
        "referencia": referencia,
        "tipos": [{"tipo": t, "total": n, "categoria": categoria[t], "lleva_agente": lleva[t]}
                  for t, n in sorted(tipos.items())],
        "totales": {
            "dispositivos": len(dispositivos), "con": cuenta.get("con", 0), "revisar": cuenta.get("revisar", 0),
            "sin": cuenta.get("sin", 0), "sin_direcciones": cuenta.get("sin_direcciones", 0),
            "agentes": len(fichas), "no_registrados": len(no_registrados),
        },
        "dispositivos": dispositivos,
        "no_registrados": no_registrados,
    }


# --------------------------------------------------------------- intrusos (DHCP)
# Prefijos de MAC (OUI) de adaptadores de máquinas virtuales
OUI_VIRTUALES = {"00155D": "Hyper-V", "080027": "VirtualBox", "0A0027": "VirtualBox", "005056": "VMware",
                 "000C29": "VMware", "001C14": "VMware", "00163E": "Xen", "525400": "QEMU/KVM"}
PRESENTES = {dhcp.CONCESION, dhcp.RESERVA_ACTIVA}
ESTADOS_INTRUSOS = {
    "registrado": "Registrado en el inventario",
    "inactivo": "Registrado como inactivo",
    "municipal": "Municipal sin registrar",
    "intruso": "Posible intruso",
    "sin_mac": "Sin MAC",
}


# Qué parece ser el equipo, por su nombre (solo para ayudar a revisar).
# El segundo valor es el tipo de equipo que se propone al registrarlo.
PARECE = [
    ("impresora", "IMPRESORA",
     re.compile(r"^(EPSON|NPI[0-9A-F]|HP[0-9A-F]{6}|BRN|BRW|KM[0-9A-F]|KONICA|RICOH|XEROX|CANON|LEXMARK|IMP[-_ ])", re.I)),
    ("teléfono IP", "TELÉFONO IP", re.compile(r"^(SEP[0-9A-F]{12}$|YEALINK|GRANDSTREAM|GXP|POLYCOM|AVAYA)", re.I)),
    ("tablet", "TABLET", re.compile(r"^(IPAD|GALAXY-?TAB|TAB[-_ ]|TABLET)|TABLET", re.I)),
    ("celular", "CELULAR",
     re.compile(r"^(ANDROID|IPHONE|GALAXY|REDMI|XIAOMI|HUAWEI|HONOR|MOTO|OPPO|VIVO|SM-|POCO)|PHONE|CELULAR", re.I)),
    ("servidor", "SERVIDOR", re.compile(r"^(IDRAC|ILO|SRV|SERVER|ESXI|NAS)|-SRV|SERVER", re.I)),
    ("cámara", "CÁMARA IP", re.compile(r"^(IPCAM|HIKVISION|DAHUA|CAM[-_ ]|AXIS)", re.I)),
    ("access point", "ACCESS POINT", re.compile(r"^(AP[-_]|UAP|U6-|UNIFI|ARUBA-?AP|EAP[0-9])", re.I)),
    ("laptop", "LAPTOP", re.compile(r"^(LAPTOP|NOTEBOOK|MACBOOK|LT[-_])|[-_]LT[-_]?[0-9]*$|LAPTOP", re.I)),
]
TIPO_PARECE = {texto: tipo for texto, tipo, _ in PARECE}


def parece(nombre, mac):
    for texto, _, patron in PARECE:
        if nombre and patron.search(nombre):
            return texto
    if mac and mac[:6] in OUI_VIRTUALES:
        return "máquina virtual"
    return None


def mac_aleatoria(mac):
    """MAC administrada localmente (segundo dígito 2, 6, A o E): la usan los
    celulares y portátiles con «dirección privada» en el Wi-Fi."""
    return bool(mac) and len(mac) == 12 and int(mac[1], 16) & 2 == 2


def partes_nombre(nombre):
    """'EACU-09.mgrecia.net' -> ('EACU-09', 'mgrecia.net')"""
    nombre = (nombre or "").strip()
    if "." in nombre and " " not in nombre:
        corto, dominio = nombre.split(".", 1)
        if re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+", dominio):
            return corto, dominio.lower()
    return nombre, None


def _dispositivo(d):
    return {"id_disp": d["id_disp"], "equipo": d["equipo"], "tipo": d["tipo"], "categoria": d["categoria"],
            "edificio": d["edificio"], "nombre_equipo": d["nombre_equipo"], "asignado": d["asignado"],
            "activo": bool(d["activo"]), "ips": d["_ips"], "macs": d["_macs"]}


def ultima_dhcp_anterior(id_dhcp):
    filas, _ = llamar_sp("sp_log_importaciones_listar", [FUENTES_DHCP[0]])
    return next((f for f in filas if f["id_importacion"] < id_dhcp), None)


def intrusos(id_dhcp, id_agentes=None):
    """Concesiones y reservas del DHCP comparadas por MAC con los equipos
    registrados en el sistema (Equipos municipales).

    Estado de cada concesión:
      registrado  su MAC es de un equipo activo del inventario
      inactivo    su MAC es de un equipo marcado como inactivo
      municipal   no está registrada, pero hay señales de que es un equipo
                  de la municipalidad: tiene el agente de Microclaudia, su
                  nombre es el de un equipo registrado o es del dominio de
                  la red, o es una reserva del DHCP
      intruso     no está registrada y no hay ninguna de esas señales
      sin_mac     el Id. exclusivo no trae una MAC
    Pistas: agente, inventario (el nombre es de un equipo registrado),
    dominio, reserva (a favor); aleatoria, sin_nombre, virtual, ip_de_otro,
    nueva (MAC que no estaba en el DHCP anterior); nombre_distinto (la MAC
    está registrada a un equipo con otro nombre en la red)."""
    filas, _ = llamar_sp("sp_log_dhcp_listar", [id_dhcp])
    inventario, _ = llamar_sp("sp_log_red_inventario", [])
    por_mac, por_ip, por_nombre = {}, {}, {}
    for d in inventario:
        d["_ips"] = [_ip(x) for x in (d["ips"] or "").split(",") if x.strip()]
        d["_macs"] = [x.strip().upper() for x in (d["macs"] or "").split(",") if x.strip()]
        for m in d["_macs"]:
            # Si la MAC está en un activo y en uno inactivo, gana el activo
            if m not in por_mac or (d["activo"] and not por_mac[m]["activo"]):
                por_mac[m] = d
        for ip in d["_ips"]:
            if ip not in por_ip or (d["activo"] and not por_ip[ip]["activo"]):
                por_ip[ip] = d
        n = d["nombre_corto"]
        if n and (n not in por_nombre or (d["activo"] and not por_nombre[n]["activo"])):
            por_nombre[n] = d

    # Equipos con el agente de Microclaudia, por MAC y por nombre
    agentes_mac, agentes_nombre = {}, {}
    if id_agentes:
        for a in llamar_sp("sp_log_agentes_listar", [id_agentes])[0]:
            ficha = {"id_evento": a["id_evento"], "nombre": a["nombre_equipo"], "ultima_conexion": a["ultima_conexion"]}
            for m in filter(None, (a["macs"] or "").split(",")):
                agentes_mac.setdefault(m, ficha)
            if a["nombre_equipo"]:
                agentes_nombre.setdefault(a["nombre_equipo"].strip().upper(), ficha)

    # La MAC estaba en la importación del DHCP anterior?
    anterior = ultima_dhcp_anterior(id_dhcp)
    macs_antes = ({f["mac"] for f in llamar_sp("sp_log_dhcp_listar", [anterior["id_importacion"]])[0] if f["mac"]}
                  if anterior else None)

    # Dominio de la red: el sufijo que más se repite en los nombres
    dominios = Counter(partes_nombre(f["nombre"])[1] for f in filas)
    dominios.pop(None, None)
    dominio = dominios.most_common(1)[0][0] if dominios else None

    concesiones, vistas = [], set()
    for f in filas:
        mac = (f["mac"] or "").upper() or None
        ip = _ip(f["ip"])
        corto, sufijo = partes_nombre(f["nombre"])
        d = por_mac.get(mac) if mac else None
        otro = por_ip.get(ip)
        tocayo = por_nombre.get(nombre_corto(corto)) if corto else None
        agente = (agentes_mac.get(mac) if mac else None) or (agentes_nombre.get(corto.upper()) if corto else None)
        reserva = f["tipo"] in (dhcp.RESERVA_ACTIVA, dhcp.RESERVA_INACTIVA)
        pistas = []
        if agente:
            pistas.append("agente")
        if tocayo and not d:
            pistas.append("inventario")
        if dominio and sufijo == dominio:
            pistas.append("dominio")
        if reserva:
            pistas.append("reserva")
        if mac_aleatoria(mac):
            pistas.append("aleatoria")
        if mac and mac[:6] in OUI_VIRTUALES:
            pistas.append("virtual")
        if not (f["nombre"] or "").strip():
            pistas.append("sin_nombre")
        if otro and (d is None or otro["id_disp"] != d["id_disp"]):
            pistas.append("ip_de_otro")
        if macs_antes is not None and mac and mac not in macs_antes and not d:
            pistas.append("nueva")
        if d and d["nombre_corto"] and corto and nombre_corto(corto) != d["nombre_corto"]:
            pistas.append("nombre_distinto")
        if not mac:
            estado = "sin_mac"
        elif d:
            estado = "registrado" if d["activo"] else "inactivo"
            vistas.add(d["id_disp"])
        elif {"agente", "inventario", "dominio", "reserva"} & set(pistas):
            estado = "municipal"
        else:
            estado = "intruso"
        concesiones.append({
            "id_evento": f["id_evento"], "tipo": f["tipo"], "presente": f["tipo"] in PRESENTES,
            "expira": f["expira"], "ip": ip, "mac": mac, "nombre": f["nombre"], "nombre_corto": corto,
            "descripcion": f["descripcion"], "tipo_cliente": f["tipo_cliente"], "estado": estado, "pistas": pistas,
            "virtual": OUI_VIRTUALES.get(mac[:6]) if mac else None,
            "parece": parece(corto, mac),
            # Tipo que se propone al registrarlo: el que dice su nombre, el
            # del equipo registrado que se llama igual, o computadora si
            # tiene el agente de Microclaudia
            "tipo_sugerido": (TIPO_PARECE.get(parece(corto, mac)) or (tocayo["tipo"] if tocayo and not d else None)
                              or ("COMPUTADORA" if agente else None)),
            "mismo_nombre": _dispositivo(tocayo) if tocayo and not d else None,
            "dispositivo": _dispositivo(d) if d else None,
            "ip_distinta": bool(d and d["_ips"] and ip not in d["_ips"]),
            "ip_de": _dispositivo(otro) if "ip_de_otro" in pistas else None,
            "agente": agente,
        })

    # Registrados activos con MAC que no aparecen en el DHCP (IP fija o apagados)
    no_vistos = [_dispositivo(d) for d in inventario if d["activo"] and d["_macs"] and d["id_disp"] not in vistas]
    cuenta = Counter(c["estado"] for c in concesiones)
    pistas = Counter(p for c in concesiones for p in c["pistas"])
    tipos = Counter(c["tipo"] for c in concesiones)
    return {
        "dominio": dominio,
        "anterior": anterior,
        "estados": ESTADOS_INTRUSOS,
        "totales": {
            "concesiones": len(concesiones),
            "presentes": sum(1 for c in concesiones if c["presente"]),
            "reservas_activas": tipos.get(dhcp.RESERVA_ACTIVA, 0),
            "reservas_inactivas": tipos.get(dhcp.RESERVA_INACTIVA, 0),
            **{k: cuenta.get(k, 0) for k in ESTADOS_INTRUSOS},
            "pistas": dict(pistas),
            "ip_distinta": sum(1 for c in concesiones if c["ip_distinta"]),
            "inventario_con_mac": sum(1 for d in inventario if d["activo"] and d["_macs"]),
            "no_vistos": len(no_vistos),
        },
        "concesiones": concesiones,
        "no_vistos": no_vistos,
    }
