"""Lector de las concesiones del servidor DHCP de Windows.

Sirven tres formas de sacar la lista:
  1. Consola DHCP > ámbito > Concesiones de direcciones > Exportar lista:
     .txt separado por tabulaciones (o .csv separado por comas). Columnas:
     Dirección IP del cliente, Nombre, Expiración de cesión, Tipo,
     Id. exclusivo, Descripción, Protección de acceso a redes, Expiración
     del período de prueba, Perfil de filtro, Directiva (o las mismas en
     inglés: Client IP Address, Name, Lease Expiration, Type, Unique ID...).
  2. Las filas copiadas y pegadas desde la consola. Al pegarlas, las
     tabulaciones quedan corridas (el nombre puede caer en otra columna):
     por eso cada fila se lee por su contenido y no por la posición.
  3. PowerShell: Get-DhcpServerv4Lease -ScopeId 10.1.10.0 | Export-Csv
     (columnas IPAddress, ClientId, HostName, AddressState...).

Cada fila es un «evento»: una concesión o una reserva con su IP, su MAC
(sale del Id. exclusivo) y el nombre del equipo. La fecha es la
expiración de la concesión; las reservas no tienen fecha.
"""
import csv
import io
import ipaddress
import re
from datetime import datetime

_IPV4 = re.compile(r"^\d{1,3}(?:\.\d{1,3}){3}$")
_HEXA = re.compile(r"^[0-9A-Fa-f]{2}(?:[-:.\s]?[0-9A-Fa-f]{2}){4,}$")
_FECHA = re.compile(r"^(\d{1,4})[/.\-](\d{1,2})[/.\-](\d{1,4})[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap])?", re.I)

# Tipo de cliente (columna Tipo)
TIPOS_CLIENTE = {"dhcp", "bootp", "dhcp/bootp", "ambos", "both", "ninguno", "none", "unspecified"}
# Protección de acceso a redes (NAP): marca dónde termina la descripción
PROTECCION = {"acceso completo", "full access", "acceso restringido", "restricted access", "período de prueba",
              "periodo de prueba", "probation"}

CONCESION = "Concesión DHCP"
RESERVA_ACTIVA = "Reserva DHCP activa"
RESERVA_INACTIVA = "Reserva DHCP inactiva"
# AddressState de PowerShell
ESTADOS_POWERSHELL = {
    "active": CONCESION, "activereservation": RESERVA_ACTIVA, "inactivereservation": RESERVA_INACTIVA,
    "reservation": RESERVA_ACTIVA, "declined": "Dirección rechazada", "expired": "Concesión vencida",
    "offered": "Dirección ofrecida",
}
# Columnas de Export-Csv de PowerShell -> nombre que se guarda
COLUMNAS_POWERSHELL = {
    "ipaddress": "ip_cliente", "hostname": "nombre", "clientid": "id_exclusivo", "addressstate": "estado",
    "leaseexpirytime": "expiracion_cesion", "clienttype": "tipo", "description": "descripcion",
    "scopeid": "ambito", "policyname": "directiva", "napstatus": "proteccion_acceso",
}


def _texto(v):
    return " ".join((v or "").replace("\xa0", " ").split())


def _es_ip(v):
    if not _IPV4.match(v):
        return False
    try:
        ipaddress.IPv4Address(v)
        return True
    except ValueError:
        return False


def _es_expiracion(v):
    t = v.lower()
    return bool(_FECHA.match(v)) or t.startswith(("reserva", "reservation", "inactiv"))


def mac_de_id(id_exclusivo):
    """MAC (AABBCCDDEEFF) que trae el Id. exclusivo del cliente:
       - 208810dd6f64 o 20-88-10-dd-6f-64: la MAC tal cual
       - 01208810dd6f64: tipo de hardware 01 (Ethernet) + MAC
       - un DUID (equipos con IPv6 o Linux): la MAC va después de 00010001 + 4 bytes
         de fecha (DUID-LLT) o después de 00030001 (DUID-LL)."""
    h = re.sub(r"[^0-9a-f]", "", (id_exclusivo or "").lower())
    mac = None
    if len(h) == 12:
        mac = h
    elif len(h) == 14 and h.startswith("01"):
        mac = h[2:]
    elif len(h) > 14:
        for marca, salto in (("00010001", 16), ("00030001", 8)):
            i = h.find(marca)
            while i >= 0:
                if i % 2 == 0 and len(h) >= i + salto + 12:
                    mac = h[i + salto:i + salto + 12]
                    break
                i = h.find(marca, i + 1)
            if mac:
                break
    if not mac or mac in ("000000000000", "ffffffffffff"):
        return None
    return mac.upper()


def orden_fechas(textos, ingles=False):
    """'dma' (26/10/2026) o 'mda' (10/26/2026) según las fechas del archivo."""
    for t in textos:
        m = _FECHA.match(t)
        if m and len(m.group(1)) <= 2:
            a, b = int(m.group(1)), int(m.group(2))
            if a > 12 >= b:
                return "dma"
            if b > 12 >= a:
                return "mda"
    return "mda" if ingles else "dma"


def fecha(texto, orden="dma"):
    t = re.sub(r"([ap])\.?\s*m\.?", lambda x: x.group(1) + "m", (texto or "").strip(), flags=re.I)
    m = _FECHA.match(t)
    if not m:
        return None
    p1, p2, p3, hora, minuto, segundo, ampm = m.groups()
    if len(p1) == 4:
        anio, mes, dia = int(p1), int(p2), int(p3)
    elif orden == "mda":
        mes, dia, anio = int(p1), int(p2), int(p3)
    else:
        dia, mes, anio = int(p1), int(p2), int(p3)
    hora = int(hora)
    if ampm:
        hora = hora % 12 + (12 if ampm.lower() == "p" else 0)
    try:
        return datetime(anio, mes, dia, hora, int(minuto), int(segundo or 0))
    except ValueError:
        return None


def separador(linea):
    cuentas = {sep: linea.count(sep) for sep in ("\t", ";", ",")}
    sep = max(cuentas, key=cuentas.get)
    return sep if cuentas[sep] else "\t"


def _fila_consola(celdas):
    """Una fila de la consola DHCP leída por su contenido. Devuelve el
    diccionario de campos o None si la fila no trae una IP."""
    celdas = [_texto(c) for c in celdas]
    pos_ip = next((i for i, c in enumerate(celdas) if _es_ip(c)), None)
    if pos_ip is None:
        return None
    resto = celdas[pos_ip + 1:]

    def buscar(desde, prueba):
        return next((i for i in range(desde, len(resto)) if resto[i] and prueba(resto[i])), None)

    p_exp = buscar(0, _es_expiracion)
    desde = 0 if p_exp is None else p_exp + 1
    p_id = buscar(desde, lambda v: bool(_HEXA.match(v)))
    # El tipo va entre la expiración y el Id. exclusivo («Ninguno» también es
    # un valor del perfil de filtro, que va después)
    p_tipo = next((i for i in range(desde, len(resto) if p_id is None else p_id)
                   if resto[i].lower() in TIPOS_CLIENTE), None)
    fin_nombre = min([p for p in (p_exp, p_tipo, p_id) if p is not None], default=len(resto))
    campos = {
        "ip_cliente": celdas[pos_ip],
        "nombre": " ".join(c for c in resto[:fin_nombre] if c),
        "expiracion_cesion": resto[p_exp] if p_exp is not None else "",
        "tipo": resto[p_tipo] if p_tipo is not None else "",
        "id_exclusivo": resto[p_id] if p_id is not None else "",
    }
    if p_id is not None:
        despues = resto[p_id + 1:]
        p_nap = next((i for i, c in enumerate(despues) if c.lower() in PROTECCION), None)
        if p_nap is None:
            campos["descripcion"] = " ".join(c for c in despues if c and c.upper() not in ("N/D", "N/A"))
        else:
            campos["descripcion"] = " ".join(c for c in despues[:p_nap] if c)
            campos["proteccion_acceso"] = despues[p_nap]
            extra = [c for c in despues[p_nap + 1:] if c]
            for clave, valor in zip(("expiracion_prueba", "perfil_filtro", "directiva"), extra):
                campos[clave] = valor
    return {k: v for k, v in campos.items() if v}


def tipo_evento(campos):
    estado = re.sub(r"[^a-z]", "", (campos.get("estado") or "").lower())
    if estado in ESTADOS_POWERSHELL:
        return ESTADOS_POWERSHELL[estado]
    exp = (campos.get("expiracion_cesion") or "").lower()
    if exp.startswith(("reserva", "reservation")):
        return RESERVA_INACTIVA if "inactiv" in exp else RESERVA_ACTIVA
    return CONCESION


def leer(texto):
    """Lee la lista de concesiones. Devuelve (eventos, avisos) como sophos.leer()."""
    texto = texto.replace("﻿", "").replace("\r\n", "\n").replace("\r", "\n")
    lineas = [ln for ln in texto.split("\n") if ln.strip()]
    if not lineas:
        return [], ["El archivo está vacío."]

    # Encabezado: la primera línea que no empieza con una IP
    primera = lineas[0]
    con_encabezado = not any(_es_ip(_texto(c)) for c in re.split(r"[\t;,]", primera)[:3])
    sep = separador(primera if con_encabezado else "\n".join(lineas[:5]))
    filas = list(csv.reader(io.StringIO("\n".join(lineas)), delimiter=sep))
    encabezado = [_texto(h).lower() for h in filas[0]] if con_encabezado else []
    datos = filas[1:] if con_encabezado else filas
    plano = [re.sub(r"[^a-z]", "", h) for h in encabezado]
    powershell = "ipaddress" in plano and ("clientid" in plano or "hostname" in plano)
    ingles = any(h.startswith(("client ip", "name", "lease")) for h in encabezado) or powershell
    if con_encabezado and not powershell and not any("ip" in h for h in encabezado):
        return [], ["No parece una lista de concesiones del DHCP: el encabezado debe traer la dirección IP del cliente "
                    "(Dirección IP del cliente o IPAddress)."]

    leidas, avisos = [], []
    for num, fila in enumerate(datos, 2 if con_encabezado else 1):
        if powershell:
            campos = {}
            for h, v in zip(plano, fila):
                clave = COLUMNAS_POWERSHELL.get(h)
                if clave and _texto(v):
                    campos[clave] = _texto(v)
            if not _es_ip(campos.get("ip_cliente", "")):
                campos = None
        else:
            campos = _fila_consola(fila)
        if not campos:
            if any(_texto(c) for c in fila):
                avisos.append(f"Línea {num}: no trae una dirección IPv4; se omitió.")
            continue
        leidas.append((num, fila, campos))

    if not leidas:
        if not avisos:
            avisos.append("La lista no trae concesiones (solo el encabezado).")
        return [], avisos

    orden = orden_fechas([c.get("expiracion_cesion", "") for _, _, c in leidas], ingles)
    eventos = []
    for num, fila, campos in leidas:
        mac = mac_de_id(campos.get("id_exclusivo"))
        if campos.get("id_exclusivo") and not mac:
            avisos.append(f"Línea {num}: del Id. exclusivo «{campos['id_exclusivo']}» no se pudo sacar la MAC.")
        cuando = fecha(campos.get("expiracion_cesion"), orden)
        exp = (campos.get("expiracion_cesion") or "").lower()
        if exp and cuando is None and not exp.startswith(("reserva", "reservation", "inactiv")):
            avisos.append(f"Línea {num}: la fecha «{campos['expiracion_cesion']}» no se entendió.")
        nombre = campos.get("nombre", "")
        eventos.append({
            "titulo": tipo_evento(campos),
            "fecha": cuando,
            "campos": campos,
            "texto": sep.join(fila),
            "linea": num,
            "derivados": {"ip_principal": str(ipaddress.IPv4Address(campos["ip_cliente"])), "mac_principal": mac,
                          "producto": "Servidor DHCP"},
            "direcciones": [("IP", campos["ip_cliente"])] + ([("MAC", mac)] if mac else []),
            "nombre": nombre,
        })
    return eventos, avisos
