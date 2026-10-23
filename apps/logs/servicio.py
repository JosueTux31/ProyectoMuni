"""Lógica del módulo de logs que usan las vistas: importar un archivo,
armar el filtro, el tablero, la comparación entre logs y el cruce con el
inventario. Todo pasa por los procedimientos sp_log_* (sql/logs)."""
import ipaddress
import json
import re
from collections import OrderedDict
from datetime import datetime, timedelta

from django.db import connection, transaction

from apps.core.auditoria import contexto_actual
from apps.core.db import llamar_sp

from . import filtro as flt
from . import normalizar as nz
from . import sophos
from .esquema import CAMPO, CAMPOS, CAMPOS_COMPARAR, NOMBRES

FUENTES = {"SOPHOS": {"nombre": "Sophos Firewall", "lector": sophos.leer}}

# Tops que muestra el tablero de una importación o de un filtro
TOPS_TABLERO = ["ip_origen", "ip_destino", "dominio", "regla_nombre", "categoria", "aplicacion", "puerto_destino",
                "pais_destino", "usuario", "tipo"]


# --------------------------------------------------------------- alias
def alias(fuente="SOPHOS"):
    filas, _ = llamar_sp("sp_log_mapeo_campos_listar", [fuente])
    return nz.preparar_alias(filas or nz.alias_por_defecto())


def alias_para_filtro(fuente="SOPHOS"):
    """{nombre en el log: campo común} para que el filtro entienda src_ip, fw_rule_id..."""
    filas, _ = llamar_sp("sp_log_mapeo_campos_listar", [None])
    filas = filas or nz.alias_por_defecto()
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
