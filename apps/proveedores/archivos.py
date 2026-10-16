"""Guardado de la imagen y del catálogo de servicios de cada proveedor.

Los archivos se guardan en MEDIA_ROOT/proveedores/... con un nombre que
genera el servidor; en la base solo queda la ruta relativa. No se publican
por una URL directa: se descargan por la API, con sesión iniciada.
"""
import logging
import os
import uuid

from django.conf import settings
from django.core.exceptions import SuspiciousFileOperation
from django.core.files.storage import FileSystemStorage
from django.utils.text import slugify
from rest_framework.exceptions import ValidationError

logger = logging.getLogger(__name__)

TIPOS = {
    "catalogo": {
        "nombre": "catálogo de servicios",
        "carpeta": "proveedores/catalogos",
        "campo": "archivo_path",
        "sp": "sp_prv_proveedores_actualizar_archivo",
        "extensiones": {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx"},
        "ajuste_max_mb": "MUNI_MAX_MB_CATALOGO",
        "max_mb_defecto": 20,
        "en_linea": False,  # se descarga
    },
    "imagen": {
        "nombre": "imagen",
        "carpeta": "proveedores/imagenes",
        "campo": "imagen_path",
        "sp": "sp_prv_proveedores_actualizar_imagen",
        "extensiones": {".jpg", ".jpeg", ".png", ".webp"},
        "ajuste_max_mb": "MUNI_MAX_MB_IMAGEN",
        "max_mb_defecto": 5,
        "en_linea": True,   # se muestra en la página
    },
}

# Primeros bytes de cada formato de imagen, para no aceptar un archivo
# de otro tipo con la extensión cambiada.
_FIRMAS_IMAGEN = {
    ".jpg": [b"\xff\xd8\xff"],
    ".jpeg": [b"\xff\xd8\xff"],
    ".png": [b"\x89PNG\r\n\x1a\n"],
    ".webp": [b"RIFF"],
}


def almacen():
    return FileSystemStorage(location=settings.MEDIA_ROOT)


def max_mb(conf):
    return getattr(settings, conf["ajuste_max_mb"], conf["max_mb_defecto"])


def validar(conf, archivo):
    if archivo is None:
        raise ValidationError({"archivo": ["Seleccione un archivo."]})

    extension = os.path.splitext(archivo.name)[1].lower()
    if extension not in conf["extensiones"]:
        permitidas = ", ".join(sorted(e.lstrip(".") for e in conf["extensiones"]))
        raise ValidationError({"archivo": [f"Formato no permitido. Use: {permitidas}."]})

    limite = max_mb(conf)
    if archivo.size > limite * 1024 * 1024:
        raise ValidationError({"archivo": [f"El archivo pesa más de {limite} MB."]})

    if extension in _FIRMAS_IMAGEN:
        inicio = archivo.read(12)
        archivo.seek(0)
        firmas = _FIRMAS_IMAGEN[extension]
        es_valida = any(inicio.startswith(f) for f in firmas)
        if extension == ".webp":
            es_valida = es_valida and inicio[8:12] == b"WEBP"
        if not es_valida:
            raise ValidationError({"archivo": ["El archivo no es una imagen válida."]})
    return extension


def guardar(conf, id_proveedor, archivo, extension):
    """Guarda el archivo y devuelve su ruta relativa."""
    base = slugify(os.path.splitext(archivo.name)[0])[:50] or "archivo"
    nombre = f"{conf['carpeta']}/{id_proveedor}-{base}-{uuid.uuid4().hex[:8]}{extension}"
    return almacen().save(nombre, archivo)


def borrar(ruta):
    """Borra un archivo guardado. Si no existe o la ruta no es válida, solo lo registra."""
    if not ruta:
        return
    try:
        almacen().delete(ruta)
    except (OSError, SuspiciousFileOperation):
        logger.warning("No se pudo borrar el archivo %s", ruta, exc_info=True)
