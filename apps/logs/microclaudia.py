"""Lector del listado de equipos de Microclaudia (agente de S2 Grupo).

El portal de Microclaudia exporta los equipos que tienen el agente en dos
formatos con las mismas columnas:
  - .txt separado por tabulaciones, fechas 23/10/2026 20:35
  - .csv separado por punto y coma (con BOM), fechas 23-10-2026 20:35:08
Columnas: NOMBRE, ORGANISMO, SIST_OPERATIVO, VERSION, ULTIMA_CONEXION,
FECHA_ALTA, TOTAL_VACUNAS_APLICADAS, TOTAL_VACUNAS_PENDIENTES,
TOTAL_VACUNAS_ERROR, IPADDRESS ([ip, ip...]), MACADDRESS ([mac, mac...]), TAGS.

Cada fila es un «evento» de tipo «Equipo con agente» cuya fecha es la
última conexión. Además de los campos originales (en minúscula) devuelve:
  - derivados: ip_principal (la primera IPv4 de la red interna),
    mac_principal y producto (Microclaudia). No se guardan como campos
    originales; se asignan a ip_origen, mac_origen y aplicacion.
  - direcciones: todas las IPv4 y MAC del equipo, para cruzarlo por
    cualquiera de ellas (log_direcciones). Se dejan fuera las 169.254.x
    (sin DHCP), 127.x y las MAC de adaptadores virtuales que comparten
    muchos equipos (VirtualBox 0A:00:27).
"""
import csv
import io
import ipaddress
import re
from datetime import datetime

FORMATOS_FECHA = ("%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M", "%d-%m-%Y %H:%M:%S", "%d-%m-%Y %H:%M",
                  "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%dT%H:%M:%S", "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d")
_MAC = re.compile(r"[0-9A-Fa-f]{2}(?:[:\-.]?[0-9A-Fa-f]{2}){5}")
MAC_VIRTUALES = ("0A0027",)        # adaptador «solo anfitrión» de VirtualBox (igual en muchos equipos)
# Adaptadores virtuales (Hyper-V, VirtualBox, VMware): se guardan, pero no se
# usan como MAC principal del equipo
MAC_DE_VIRTUALES = ("00155D", "080027", "005056", "000C29", "001C14")
RED_VIRTUALBOX = ipaddress.ip_network("192.168.56.0/24")
TIPO = "Equipo con agente"


def nombre_columna(texto):
    """'SIST_OPERATIVO ' -> 'sist_operativo'"""
    return re.sub(r"[^a-z0-9_.\-]+", "_", texto.strip().lower()).strip("_")


def fecha(texto):
    texto = (texto or "").strip()
    if not texto:
        return None
    for formato in FORMATOS_FECHA:
        try:
            return datetime.strptime(texto, formato)
        except ValueError:
            continue
    return None


def separador(linea):
    """Tabulación, punto y coma o coma: el que más aparece en el encabezado."""
    cuentas = {sep: linea.count(sep) for sep in ("\t", ";", ",")}
    sep = max(cuentas, key=cuentas.get)
    return sep if cuentas[sep] else "\t"


def lista(texto):
    """'[a, b, c]' -> ['a', 'b', 'c']"""
    texto = (texto or "").strip().strip("[]")
    return [x.strip().strip("'\"") for x in re.split(r"[,;\s]+", texto) if x.strip().strip("'\"")]


def ipv4_utiles(valores):
    """IPv4 que sirven para cruzar, en el orden del archivo."""
    salida = []
    for v in valores:
        try:
            d = ipaddress.ip_address(v)
        except ValueError:
            continue
        if d.version != 4 or d.is_link_local or d.is_loopback or d.is_unspecified or d.is_multicast:
            continue
        if str(d) not in salida:
            salida.append(str(d))
    return salida


def ip_principal(ips):
    """La IP con la que el equipo sale a la red municipal: primero 10.x,
    luego 172.16-31.x, luego 192.168.x (sin la red de VirtualBox)."""
    def prioridad(ip):
        d = ipaddress.ip_address(ip)
        if d in ipaddress.ip_network("10.0.0.0/8"):
            return 0
        if d in ipaddress.ip_network("172.16.0.0/12"):
            return 1
        if d in ipaddress.ip_network("192.168.0.0/16") and d not in RED_VIRTUALBOX:
            return 2
        return 3
    return min(ips, key=lambda ip: (prioridad(ip), ips.index(ip))) if ips else None


def macs_utiles(valores):
    salida = []
    for v in valores:
        if not _MAC.fullmatch(v):
            continue
        hexa = re.sub(r"[^0-9A-Fa-f]", "", v).upper()
        if hexa in ("000000000000", "FFFFFFFFFFFF") or hexa.startswith(MAC_VIRTUALES) or hexa in salida:
            continue
        salida.append(hexa)
    return salida


def leer(texto):
    """Lee el listado. Devuelve (eventos, avisos) como sophos.leer()."""
    texto = texto.replace("﻿", "").replace("\r\n", "\n").replace("\r", "\n")
    lineas = [ln for ln in texto.split("\n") if ln.strip()]
    if not lineas:
        return [], ["El archivo está vacío."]
    sep = separador(lineas[0])
    filas = list(csv.reader(io.StringIO("\n".join(lineas)), delimiter=sep))
    encabezado = [nombre_columna(h) for h in filas[0]]
    if "nombre" not in encabezado or not {"ipaddress", "macaddress", "ultima_conexion"} & set(encabezado):
        return [], ["No parece un listado de equipos de Microclaudia: el encabezado debe traer NOMBRE, "
                    "ULTIMA_CONEXION, IPADDRESS y MACADDRESS."]

    eventos, avisos = [], []
    for num, fila in enumerate(filas[1:], 2):
        if len(fila) > len(encabezado):
            avisos.append(f"Línea {num}: trae más columnas que el encabezado; se usaron las primeras {len(encabezado)}.")
        fila = (fila + [""] * len(encabezado))[:len(encabezado)]
        campos = {k: " ".join(v.split()) for k, v in zip(encabezado, fila) if k}
        if not campos.get("nombre"):
            avisos.append(f"Línea {num}: no tiene NOMBRE; se omitió.")
            continue
        ips = ipv4_utiles(lista(campos.get("ipaddress")))
        macs = macs_utiles(lista(campos.get("macaddress")))
        cuando = fecha(campos.get("ultima_conexion"))
        if campos.get("ultima_conexion") and cuando is None:
            avisos.append(f"Línea {num}: la fecha «{campos['ultima_conexion']}» no se entendió.")
        eventos.append({
            "titulo": TIPO,
            "fecha": cuando,
            "campos": campos,
            "texto": sep.join(fila),
            "linea": num,
            "derivados": {"ip_principal": ip_principal(ips),
                          "mac_principal": next((m for m in macs if not m.startswith(MAC_DE_VIRTUALES)),
                                                macs[0] if macs else None),
                          "producto": "Microclaudia"},
            "direcciones": [("IP", ip) for ip in ips] + [("MAC", m) for m in macs],
        })
    if not eventos and not avisos:
        avisos.append("El listado no trae equipos (solo el encabezado).")
    return eventos, avisos
