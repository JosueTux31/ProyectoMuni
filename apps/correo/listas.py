"""Listas de correos importadas y su comparación con los correos del
personal registrado en el sistema.

Archivos que sirven:
  - .txt con los correos separados por comas (también punto y coma,
    espacios o saltos de línea). También entiende «Nombre <correo>».
  - .csv o .txt con encabezado, por ejemplo la descarga de usuarios de
    Google Workspace: Nombre, Apellidos, Correo electrónico, Estado (o en
    inglés: First Name, Last Name, Email Address, Status).
  - .xlsx (la misma descarga abierta en Excel). Se lee la primera hoja con
    la biblioteca estándar, sin instalar nada.
"""
import csv
import io
import re
import unicodedata
import zipfile
from collections import Counter
from xml.etree import ElementTree

_CORREO = re.compile(r"[A-Za-z0-9._%+'\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")
_NOMBRE_Y_CORREO = re.compile(r"\"?([^\",;<>\n]+?)\"?\s*<\s*([^<>\s]+@[^<>\s]+)\s*>")
NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"

# Encabezados conocidos (en minúscula, sin tildes ni lo que va entre corchetes)
ENC_CORREO = ("correo", "correo electronico", "email", "e-mail", "email address", "mail", "direccion de correo",
              "primary email", "correo institucional")
ENC_NOMBRE = ("nombre", "nombres", "first name", "given name", "nombre de pila")
ENC_APELLIDOS = ("apellidos", "apellido", "last name", "family name", "surname")
ENC_ESTADO = ("estado", "status", "estado de la cuenta", "account status")

SUSPENDIDA = {"suspended", "suspendida", "suspendido", "inactiva", "inactivo", "inactive", "disabled", "deshabilitada",
              "bloqueada", "archived", "archivada"}
ACTIVA = {"active", "activa", "activo", "enabled", "habilitada"}
PALABRAS_VACIAS = {"DE", "DEL", "LA", "LAS", "LOS", "Y", "VON", "VAN"}


def sin_tildes(texto):
    return "".join(c for c in unicodedata.normalize("NFKD", texto or "") if not unicodedata.combining(c))


def _encabezado(texto):
    return re.sub(r"\s+", " ", re.sub(r"\[.*?\]", "", sin_tildes(texto).lower())).strip(" :")


def decodificar(contenido):
    if contenido[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return contenido.decode("utf-16")
    try:
        return contenido.decode("utf-8-sig")
    except UnicodeDecodeError:
        return contenido.decode("cp1252", errors="replace")


# ------------------------------------------------------------------- xlsx
def _columna(ref):
    """'C12' -> 2"""
    letras = re.match(r"[A-Z]+", ref or "")
    n = 0
    for ch in letras.group() if letras else "A":
        n = n * 26 + ord(ch) - 64
    return n - 1


def filas_xlsx(contenido):
    """Filas de la primera hoja de un .xlsx como listas de texto."""
    with zipfile.ZipFile(io.BytesIO(contenido)) as z:
        if sum(i.file_size for i in z.infolist()) > 200 * 1024 * 1024:
            raise ValueError("el archivo descomprimido es demasiado grande")
        nombres = set(z.namelist())
        compartidos = []
        if "xl/sharedStrings.xml" in nombres:
            raiz = ElementTree.fromstring(z.read("xl/sharedStrings.xml"))
            for si in raiz.iter(f"{NS}si"):
                compartidos.append("".join(t.text or "" for t in si.iter(f"{NS}t")))
        hojas = sorted(n for n in nombres if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", n))
        if not hojas:
            raise ValueError("El archivo de Excel no tiene hojas.")
        primera = "xl/worksheets/sheet1.xml" if "xl/worksheets/sheet1.xml" in nombres else hojas[0]
        raiz = ElementTree.fromstring(z.read(primera))
    filas = []
    for fila in raiz.iter(f"{NS}row"):
        celdas = {}
        for c in fila.iter(f"{NS}c"):
            tipo = c.get("t")
            v = c.find(f"{NS}v")
            if tipo == "s" and v is not None and v.text:
                valor = compartidos[int(v.text)] if int(v.text) < len(compartidos) else ""
            elif tipo == "inlineStr":
                valor = "".join(t.text or "" for t in c.iter(f"{NS}t"))
            else:
                valor = v.text if v is not None and v.text else ""
            celdas[_columna(c.get("r"))] = valor.strip()
        if celdas:
            filas.append([celdas.get(i, "") for i in range(max(celdas) + 1)])
    return filas


# ------------------------------------------------------------------- leer
def _con_encabezado(filas):
    """Busca la fila de encabezado y lee las columnas conocidas."""
    for i, fila in enumerate(filas[:10]):
        enc = [_encabezado(x) for x in fila]
        col = {}
        for k, nombres in (("c", ENC_CORREO), ("n", ENC_NOMBRE), ("a", ENC_APELLIDOS), ("e", ENC_ESTADO)):
            col[k] = next((j for j, h in enumerate(enc) if h in nombres), None)
        if col["c"] is None:
            col["c"] = next((j for j, h in enumerate(enc) if "correo" in h or "mail" in h), None)
        if col["c"] is None:
            continue
        salida = []
        for fila in filas[i + 1:]:
            def dato(k):
                j = col[k]
                return fila[j].strip() if j is not None and j < len(fila) else ""
            m = _CORREO.search(dato("c"))
            if m:
                salida.append({"c": m.group().lower(), "n": dato("n"), "a": dato("a"), "e": dato("e")})
        return salida
    return None


def _sueltos(texto):
    """Todos los correos del texto, con el nombre si viene como «Nombre <correo>»."""
    nombres = {c.lower(): n.strip() for n, c in _NOMBRE_Y_CORREO.findall(texto)}
    salida = []
    for m in _CORREO.finditer(texto):
        c = m.group().lower().strip(".")
        salida.append({"c": c, "n": nombres.get(c, ""), "a": "", "e": ""})
    return salida


def leer(contenido, nombre_archivo=""):
    """Devuelve (correos, avisos). correos: [{"c", "n", "a", "e"}] sin repetir."""
    avisos = []
    es_xlsx = contenido[:4] == b"PK\x03\x04" or nombre_archivo.lower().endswith(".xlsx")
    if es_xlsx:
        try:
            filas = filas_xlsx(contenido)
        except (zipfile.BadZipFile, ElementTree.ParseError, KeyError, ValueError) as e:
            return [], [f"No se pudo leer el archivo de Excel: {e}"]
        correos = _con_encabezado(filas)
        if correos is None:
            correos = _sueltos("\n".join(" ".join(f) for f in filas))
    else:
        texto = decodificar(contenido).replace("﻿", "")
        lineas = [ln for ln in texto.splitlines() if ln.strip()]
        correos = None
        if lineas:
            primera = lineas[0]
            sep = max(("\t", ";", ","), key=primera.count)
            if primera.count(sep) and not _CORREO.search(primera):
                correos = _con_encabezado(list(csv.reader(io.StringIO("\n".join(lineas)), delimiter=sep)))
        if correos is None:
            correos = _sueltos(texto)
    unicos, vistos = [], set()
    for x in correos:
        if x["c"] in vistos:
            continue
        vistos.add(x["c"])
        unicos.append(x)
    if len(unicos) < len(correos):
        n = len(correos) - len(unicos)
        avisos.append("1 correo estaba repetido y se tomó una sola vez." if n == 1
                      else f"{n} correos estaban repetidos y se tomaron una sola vez.")
    if not unicos:
        avisos.append("No se encontró ningún correo en el archivo.")
    return unicos, avisos


def dominio_principal(correos):
    c = Counter(x["c"].split("@")[-1] for x in correos)
    return c.most_common(1)[0][0] if c else None


# ------------------------------------------------------------------ comparar
def tokens(texto):
    limpio = re.sub(r"[^A-Z]+", " ", sin_tildes(texto).upper())
    return [t for t in limpio.split() if len(t) > 1 and t not in PALABRAS_VACIAS]


def estado_cuenta(texto):
    t = sin_tildes(texto or "").strip().lower()
    if t in SUSPENDIDA:
        return "suspendida"
    if t in ACTIVA:
        return "activa"
    return t or None


def partes_persona(p):
    return tokens(p.get("nombre")), tokens(p.get("apellido1")), tokens(p.get("apellido2"))


def puntaje(entrada, persona):
    """Qué tanto se parece una cuenta de la lista a una persona registrada:
    3 o más = nombre y primer apellido; 2 = inicial + apellido (jperez)."""
    pn, pa1, pa2 = persona["_partes"]
    if not pn or not (pa1 or pa2):
        return 0
    en, ea = tokens(entrada.get("n")), tokens(entrada.get("a"))
    local = [t for t in re.split(r"[._\-0-9]+", sin_tildes(entrada["c"].split("@")[0]).upper()) if t]
    s = 0
    if en or ea:
        nombres = set(en) if en and ea else set(en + ea)
        apellidos = set(ea) if ea else set(en + ea)
        if (set(pa1) & apellidos) and (set(pn) & nombres):
            s = 3 + (1 if pa2 and set(pa2) & apellidos else 0) + (1 if pn[0] in nombres else 0)
    if len(local) >= 2 and local[0] in pn and local[1] in pa1 + pa2:
        s = max(s, 3 + (1 if local[1] in pa1 else 0))
    if len(local) == 1 and pa1 and local[0] == pn[0][0] + pa1[0]:
        s = max(s, 2)
    return s


def _persona(p):
    return {"id": p["id"], "nombre": p["nombre_completo"], "departamento": p["departamento"], "activo": bool(p["activo"]),
            "usuario_red": p["usuario_red"], "correos": [c for c, _ in p["_correos"]]}


def preparar_personal(filas):
    for p in filas:
        p["_correos"] = []
        for parte in filter(None, (p.get("correos") or "").split(";")):
            correo, _, tipo = parte.partition("|")
            if correo.strip():
                p["_correos"].append((correo.strip().lower(), tipo))
        p["_partes"] = partes_persona(p)
    return filas


def sugerir(entrada, personal, excluir=()):
    """Las personas registradas que más se parecen a una cuenta (máximo 2)."""
    candidatos = []
    for p in personal:
        if p["id"] in excluir:
            continue
        s = puntaje(entrada, p)
        if s >= 2:
            candidatos.append((s + (1 if p["activo"] else 0), p))
    candidatos.sort(key=lambda x: -x[0])
    if not candidatos:
        return []
    mejor = candidatos[0][0]
    return [_persona(p) for s, p in candidatos if s == mejor][:2]


def comparar(lista, personal):
    """lista: filas de cor_listas_correos; personal: sp_cor_personal_listar
    ya preparado. Compara por el correo (sin distinguir mayúsculas)."""
    dominios = Counter(x["correo"].split("@")[-1] for x in lista)
    del_dominio = set(dominios)
    por_correo = {}
    for p in personal:
        for c, _ in p["_correos"]:
            por_correo.setdefault(c, p)
    en_lista = {x["correo"] for x in lista}
    # Se sugiere a quien todavía no tiene un correo de los dominios de la lista
    con_dominio = {q["id"] for q in personal if any(c.split("@")[-1] in del_dominio for c, _ in q["_correos"])}

    coinciden, solo_lista = [], []
    for x in lista:
        entrada = {"c": x["correo"], "n": x["nombre"], "a": x["apellidos"]}
        cuenta = {"correo": x["correo"], "nombre": " ".join(filter(None, (x["nombre"], x["apellidos"]))) or None,
                  "estado": x["estado"], "estado_cuenta": estado_cuenta(x["estado"])}
        p = por_correo.get(x["correo"])
        if p:
            alerta = None
            if cuenta["estado_cuenta"] == "suspendida" and p["activo"]:
                alerta = "suspendida"
            elif cuenta["estado_cuenta"] != "suspendida" and not p["activo"]:
                alerta = "inactivo"
            coinciden.append({**cuenta, "persona": _persona(p), "alerta": alerta})
        else:
            sugerencias = sugerir(entrada, personal, excluir=con_dominio)
            local = x["correo"].split("@")[0]
            solo_lista.append({**cuenta, "sugerencias": sugerencias,
                               "generica": not sugerencias and "." not in local})

    # Primero las que tienen una persona sugerida; al final las de uso común
    solo_lista.sort(key=lambda s: (not s["sugerencias"], s["generica"]))

    solo_sistema = []
    for p in personal:
        for c, tipo in p["_correos"]:
            if c.split("@")[-1] in del_dominio and c not in en_lista:
                solo_sistema.append({"correo": c, "tipo": tipo, "persona": _persona(p)})

    # Personal activo sin ningún correo de los dominios de la lista
    sugeridos = {}
    for s in solo_lista:
        for p in s["sugerencias"][:1]:
            sugeridos.setdefault(p["id"], s["correo"])
    sin_correo = []
    for p in personal:
        if p["activo"] and not any(c.split("@")[-1] in del_dominio for c, _ in p["_correos"]):
            sin_correo.append({"persona": _persona(p), "sugerencia": sugeridos.get(p["id"]),
                               "otros_correos": [c for c, _ in p["_correos"]]})

    return {
        "dominios": [{"dominio": d, "total": n} for d, n in dominios.most_common()],
        "totales": {
            "lista": len(lista),
            "coinciden": len(coinciden),
            "solo_lista": len(solo_lista),
            "solo_sistema": len(solo_sistema),
            "sin_correo": len(sin_correo),
            "con_sugerencia": sum(1 for s in solo_lista if s["sugerencias"]),
            "genericas": sum(1 for s in solo_lista if s["generica"]),
            "suspendidas": sum(1 for x in lista if estado_cuenta(x["estado"]) == "suspendida"),
            "alerta_suspendida": sum(1 for c in coinciden if c["alerta"] == "suspendida"),
            "alerta_inactivo": sum(1 for c in coinciden if c["alerta"] == "inactivo"),
            "personal": len(personal),
            "personal_activo": sum(1 for p in personal if p["activo"]),
        },
        "coinciden": coinciden,
        "solo_lista": solo_lista,
        "solo_sistema": solo_sistema,
        "sin_correo": sin_correo,
    }
