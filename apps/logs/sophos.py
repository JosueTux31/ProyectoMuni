"""Lector de logs de Sophos Firewall.

Entiende lo que sale al copiar o exportar los logs del Log Viewer:

    Web filter                      <- título (tipo de log)
    2026-10-22 08:19:16             <- fecha y hora
    device_name="fw.mgrecia.net"    <- campos clave="valor"
    messageid="16001" ...

- Un evento en varias líneas, con líneas en blanco, tabulaciones y
  espacios de más, o todo en una sola línea.
- Valores partidos en dos líneas: app_name="Secure
  Socket Layer Protocol" se lee como "Secure Socket Layer Protocol".
- Varios campos en la misma línea: hb_status="No Heartbeat" message="".
- La comilla final que falta: flags="0 al final del archivo.
- También el formato de syslog (una línea por evento, sin título, con
  date=2026-10-22 time=15:58:10 y valores con o sin comillas).

Devuelve cada evento como {"titulo", "fecha", "campos": {nombre: valor},
"texto": texto original} sin interpretar los valores; normalizar.py los
pasa a los campos comunes.
"""
import re
from datetime import datetime

_FECHA = re.compile(r"^\s*(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})\s*$")
_CLAVE = re.compile(r"\s*([A-Za-z_][A-Za-z0-9_.\-]*)=")
# Comilla que cierra un valor: la sigue otro campo o el final del evento
_CIERRE = re.compile(r'"(?=\s+[A-Za-z_][A-Za-z0-9_.\-]*=|\s*\Z)')
# Inicio del siguiente campo (para valores con la comilla sin cerrar)
_SIGUIENTE = re.compile(r'\s+[A-Za-z_][A-Za-z0-9_.\-]*="')
_SIN_COMILLAS = re.compile(r"\S*")
_HAY_CAMPO = re.compile(r'[A-Za-z_][A-Za-z0-9_.\-]*=')
# Título pegado al final de una línea de campos: ...="valor" Web filter
_TITULO_PEGADO = re.compile(r'"[ \t]+([A-Za-z][^"=]{0,60}?)[ \t]*$')


def limpiar(valor):
    """Colapsa espacios, tabulaciones y saltos de línea en un solo espacio."""
    return " ".join(valor.split())


def leer_campos(texto):
    """Lee los pares clave="valor" de un evento. Devuelve (campos, basura)
    donde basura es el texto que no se pudo interpretar."""
    campos, basura = {}, []
    pos, n = 0, len(texto)
    while pos < n:
        m = _CLAVE.match(texto, pos)
        if not m:
            # Texto suelto: se salta hasta el siguiente campo
            sig = _HAY_CAMPO.search(texto, pos)
            fin = sig.start() if sig else n
            if texto[pos:fin].strip():
                basura.append(texto[pos:fin].strip())
            if not sig:
                break
            pos = fin
            continue
        clave, pos = m.group(1), m.end()
        if pos < n and texto[pos] == '"':
            cierre = _CIERRE.search(texto, pos + 1)
            if cierre:
                valor, pos = texto[pos + 1:cierre.start()], cierre.end()
            else:
                # Comilla sin cerrar (flags="0): hasta el siguiente campo o el final
                sig = _SIGUIENTE.search(texto, pos + 1)
                fin = sig.start() if sig else n
                valor, pos = texto[pos + 1:fin].rstrip().rstrip('"'), fin
        else:
            m2 = _SIN_COMILLAS.match(texto, pos)
            valor, pos = m2.group(), m2.end()
        clave = clave.lower()
        if clave not in campos:          # si se repite, vale el primero
            campos[clave] = limpiar(valor)
    return campos, basura


def _fecha_de(texto_fecha, campos):
    """Fecha del encabezado; si no hay, la de los campos date/time o timestamp."""
    if texto_fecha:
        m = _FECHA.match(texto_fecha)
        return datetime.strptime(f"{m.group(1)} {m.group(2)}", "%Y-%m-%d %H:%M:%S")
    fecha, hora = campos.get("date"), campos.get("time")
    if fecha and hora:
        try:
            return datetime.strptime(f"{fecha} {hora[:8]}", "%Y-%m-%d %H:%M:%S")
        except ValueError:
            pass
    marca = campos.get("timestamp") or campos.get("log_time") or ""
    m = re.match(r"(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})", marca)
    if m:
        return datetime.strptime(f"{m.group(1)} {m.group(2)}", "%Y-%m-%d %H:%M:%S")
    return None


def leer(texto):
    """Lee todo el archivo. Devuelve (eventos, avisos)."""
    texto = texto.replace("\r\n", "\n").replace("\r", "\n").replace("﻿", "")
    lineas = texto.split("\n")
    eventos, avisos = [], []

    marcas = [i for i, ln in enumerate(lineas) if _FECHA.match(ln)]
    if not marcas:
        # Formato syslog: un evento por línea
        for num, ln in enumerate(lineas, 1):
            if not _HAY_CAMPO.search(ln):
                if ln.strip():
                    avisos.append(f"Línea {num}: no tiene campos clave=valor.")
                continue
            campos, basura = leer_campos(ln)
            if basura:
                avisos.append(f"Línea {num}: texto sin interpretar: {basura[0][:80]}")
            eventos.append({"titulo": None, "fecha": _fecha_de(None, campos), "campos": campos,
                            "texto": ln.strip(), "linea": num})
        return eventos, avisos

    # Formato del visor: título, fecha y campos.
    # encabezados: (línea donde empieza el evento, línea de la fecha, título)
    # Si el título quedó pegado al final de la línea anterior (dos archivos
    # unidos sin salto de línea: ...web_policy="X" Web filter), se separa.
    encabezados = []
    for t in marcas:
        h = t - 1
        while h >= 0 and not lineas[h].strip():
            h -= 1
        titulo, inicio = None, t
        if h >= 0 and (not encabezados or h > encabezados[-1][1]) and not _FECHA.match(lineas[h]):
            if not _HAY_CAMPO.search(lineas[h]):
                titulo, inicio = limpiar(lineas[h]), h
            else:
                pegado = _TITULO_PEGADO.search(lineas[h])
                if pegado:
                    titulo = limpiar(pegado.group(1))
                    lineas[h] = lineas[h][:pegado.start() + 1]
                    inicio = h + 1
        encabezados.append((inicio, t, titulo))

    if _HAY_CAMPO.search("\n".join(lineas[:encabezados[0][0]])):
        avisos.append("Hay campos antes del primer evento (sin título ni fecha); no se leyeron.")

    for k, (h, t, titulo) in enumerate(encabezados):
        fin = encabezados[k + 1][0] if k + 1 < len(encabezados) else len(lineas)
        cuerpo = "\n".join(lineas[t + 1:fin])
        campos, basura = leer_campos(cuerpo)
        h = h if titulo else None
        if not campos:
            avisos.append(f"Línea {t + 1}: el evento {titulo or ''} no tiene campos.".replace("  ", " "))
            continue
        if basura:
            avisos.append(f"Línea {t + 1}: texto sin interpretar: {basura[0][:80]}")
        texto_evento = "\n".join(lineas[(h if h is not None else t):fin]).strip()
        eventos.append({"titulo": titulo, "fecha": _fecha_de(lineas[t], campos), "campos": campos,
                        "texto": texto_evento, "linea": (h if h is not None else t) + 1})
    return eventos, avisos
