"""Pasa un evento leído (nombres de Sophos u otro programa) a los campos
comunes de esquema.py y lo deja listo para guardarlo.

- Cada campo común toma el valor del alias de menor prioridad que venga
  con datos (domain antes que sni).
- IP en su forma estándar; MAC entera sin separadores (AABBCCDDEEFF);
  puertos, bytes y paquetes como números; texto vacío = sin dato.
- accion: PERMITIDO, DENEGADO u OTRO, venga como venga (Allowed, Allow,
  Denied, Reject and notify, Drop...).
- dominio: si el log no lo trae, sale de la URL.
- huella: identifica el evento; el mismo evento importado dos veces en la
  misma importación se guarda una sola vez.
"""
import hashlib
import ipaddress
import json
import re
from urllib.parse import urlsplit

from .esquema import ALIAS_SOPHOS, CAMPO, NOMBRES

_MAC = re.compile(r"[0-9A-Fa-f:.\-]+")

PERMITIDO = {"allowed", "allow", "accept", "accepted", "permit", "permitted", "pass", "passed", "permitido"}
DENEGADO = {"denied", "deny", "drop", "dropped", "reject", "rejected", "block", "blocked", "denegado",
            "bloqueado", "reject and notify", "quarantined"}


def alias_por_defecto():
    return [{"campo_origen": o, "campo": c, "prioridad": p} for o, c, p in ALIAS_SOPHOS]


def preparar_alias(filas):
    """[{"campo_origen", "campo", "prioridad"}] -> {campo: [orígenes por prioridad]}"""
    por_campo = {}
    for f in sorted(filas, key=lambda x: (x["campo"], x["prioridad"], x["campo_origen"])):
        if f["campo"] in CAMPO:
            por_campo.setdefault(f["campo"], []).append(f["campo_origen"].lower())
    return por_campo


def ip(valor):
    try:
        return str(ipaddress.ip_address(valor.strip())) if valor else None
    except ValueError:
        return None


def mac(valor):
    if not valor or not _MAC.fullmatch(valor.strip()):
        return None
    hexa = re.sub(r"[^0-9A-Fa-f]", "", valor).upper()
    return hexa if len(hexa) == 12 else None


def numero(valor):
    if valor is None:
        return None
    texto = str(valor).strip().replace(",", "")
    return int(texto) if re.fullmatch(r"-?\d{1,18}", texto) else None


def accion(*valores):
    """Allowed / Allow / Denied / Reject and notify... -> PERMITIDO / DENEGADO / OTRO."""
    for v in valores:
        t = (v or "").strip().lower()
        if not t:
            continue
        if t in DENEGADO or any(p in t for p in ("deny", "denied", "reject", "block", "drop")):
            return "DENEGADO"
        if t in PERMITIDO or "allow" in t or "accept" in t:
            return "PERMITIDO"
    return "OTRO"


def normalizar(evento, alias, fuente="SOPHOS"):
    """evento: lo que devuelve sophos.leer(). alias: preparar_alias(...).
    Devuelve el diccionario que recibe sp_log_eventos_insertar."""
    crudo = evento["campos"]
    n = {}
    for campo in NOMBRES:
        if campo in ("fecha", "tipo", "accion"):
            continue
        for origen in alias.get(campo, ()):
            v = crudo.get(origen)
            if v not in (None, ""):
                n[campo] = v
                break
    tipo_campo = {c: CAMPO[c][3] for c in NOMBRES}
    for campo in list(n):
        t = tipo_campo[campo]
        if t == "ip":
            n[campo] = ip(n[campo])
        elif t == "mac":
            n[campo] = mac(n[campo])
        elif t in ("puerto", "numero"):
            n[campo] = numero(n[campo])
        else:
            largo = CAMPO[campo][4]
            n[campo] = n[campo][:largo] if largo else n[campo]
    if not n.get("dominio") and n.get("url"):
        try:
            host = urlsplit(n["url"] if "//" in n["url"] else f"//{n['url']}").hostname
        except ValueError:
            host = None
        n["dominio"] = host
    n["fecha"] = evento["fecha"].strftime("%Y-%m-%d %H:%M:%S") if evento.get("fecha") else None
    n["tipo"] = (evento.get("titulo") or crudo.get("log_component") or crudo.get("log_type") or "Sin tipo")[:60]
    n["accion"] = accion(crudo.get("log_subtype"), crudo.get("status"), crudo.get("action"))
    n = {k: v for k, v in n.items() if v not in (None, "")}

    huella = hashlib.md5(json.dumps([fuente, n.get("fecha"), n.get("tipo"), sorted(crudo.items())],
                                    ensure_ascii=False).encode("utf-8")).hexdigest()
    return {**n, "huella": huella, "datos": crudo}
