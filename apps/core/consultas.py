"""Consulta de nombre y apellidos a partir de la cédula.

1. Padrón electoral del TSE cargado en la tabla pad_padron (cédulas físicas
   de 9 dígitos): devuelve nombre, primer y segundo apellido por separado.
   Se carga con:  python manage.py cargar_padron --descargar
2. Si no está en el padrón (empresas, DIMEX, menores de edad), consulta la
   API pública de Hacienda (api.hacienda.go.cr), que devuelve el nombre o
   razón social de quienes están inscritos como contribuyentes.
   Hacienda trae el nombre de las personas en un solo texto; aquí se separa
   en nombre, primer apellido y segundo apellido (ver nombres.py).
   Se puede apagar con MUNI_CONSULTA_HACIENDA = False.
"""
import json
import logging
import re
import urllib.error
import urllib.request

from django.conf import settings
from django.core.cache import cache
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from .db import llamar_sp
from .nombres import separar_nombre
from .permisos import SoloAdmin

logger = logging.getLogger(__name__)

URL_HACIENDA = "https://api.hacienda.go.cr/fe/ae?identificacion={}"
TIPOS_HACIENDA = {"01": "fisica", "02": "juridica", "03": "dimex", "04": "nite"}


def normalizar_cedula(texto):
    """'1-234-567' -> '102340567'; '3-101-123456' -> '3101123456'; quita espacios y guiones."""
    texto = (texto or "").strip()
    partes = [p for p in re.split(r"[-\s.]+", texto) if p]
    # Formato tradicional de cédula física: provincia-tomo-asiento
    if len(partes) == 3 and all(p.isdigit() for p in partes) and len(partes[0]) == 1 \
            and len(partes[1]) <= 4 and len(partes[2]) <= 4:
        return partes[0] + partes[1].zfill(4) + partes[2].zfill(4)
    return re.sub(r"[^0-9A-Za-z]", "", texto).upper()


def consultar_padron(cedula):
    if not (len(cedula) == 9 and cedula.isdigit()):
        return None
    filas, _ = llamar_sp("sp_pad_padron_consultar", [cedula])
    if not filas:
        return None
    f = filas[0]
    return {
        "fuente": "padron", "tipo": "fisica", "cedula": cedula,
        "nombre": f["nombre"], "apellido1": f["apellido1"], "apellido2": f["apellido2"],
        "nombre_completo": " ".join(p for p in (f["nombre"], f["apellido1"], f["apellido2"]) if p),
    }


# Tipos de Hacienda que son personas (se separa nombre y apellidos)
TIPOS_PERSONA = {"fisica", "dimex", "nite"}


def consultar_hacienda(cedula):
    """Consulta Hacienda y, si es una persona, reparte el nombre en sus campos."""
    resultado = _consultar_hacienda(cedula)
    if not resultado:
        return None
    resultado = dict(resultado)
    if resultado["tipo"] in TIPOS_PERSONA:
        partes = separar_nombre(
            resultado["nombre_completo"],
            apellidos_primero=getattr(settings, "MUNI_HACIENDA_APELLIDOS_PRIMERO", False),
        )
        resultado.update(partes)
        resultado["nombre_completo"] = " ".join(
            p for p in (partes["nombre"], partes["apellido1"], partes["apellido2"]) if p)
    return resultado


def _consultar_hacienda(cedula):
    if not getattr(settings, "MUNI_CONSULTA_HACIENDA", True) or not cedula.isdigit():
        return None
    clave = f"muni.hacienda.{cedula}"
    if (guardado := cache.get(clave)) is not None:
        return guardado or None

    peticion = urllib.request.Request(URL_HACIENDA.format(cedula), headers={"User-Agent": "GestionMunicipal/1.0"})
    try:
        with urllib.request.urlopen(peticion, timeout=6) as r:
            datos = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            cache.set(clave, {}, 3600)  # no inscrito: no se vuelve a preguntar en 1 hora
        else:
            logger.warning("Hacienda respondió %s para %s", e.code, cedula)
        return None
    except (urllib.error.URLError, TimeoutError, ValueError):
        logger.warning("No se pudo consultar Hacienda para %s", cedula, exc_info=True)
        return None

    nombre = (datos.get("nombre") or "").strip().upper()
    if not nombre:
        return None
    resultado = {
        "fuente": "hacienda", "tipo": TIPOS_HACIENDA.get(datos.get("tipoIdentificacion"), "otra"),
        "cedula": cedula, "nombre": nombre, "apellido1": None, "apellido2": None,
        "nombre_completo": nombre,
    }
    cache.set(clave, resultado, 24 * 3600)
    return resultado


class ConsultaCedulaView(APIView):
    """GET /api/consultas/cedula/<numero>/ — nombre y apellidos de una cédula.

    Solo administradores (son quienes crean usuarios y proveedores).
    Responde 404 si no se encuentra en ninguna fuente.
    """
    permission_classes = [SoloAdmin]

    def get(self, request, numero):
        cedula = normalizar_cedula(numero)
        if not 9 <= len(cedula) <= 12:
            raise ValidationError({"detail": "Escriba la cédula completa (9 dígitos la física, 10 la jurídica)."})
        resultado = consultar_padron(cedula) or consultar_hacienda(cedula)
        if not resultado:
            raise NotFound("No se encontró esa cédula en el padrón ni en Hacienda. Escriba el nombre a mano.")
        return Response(resultado)
