"""Archivos subidos (fotos de usuarios, imágenes y catálogos de proveedores).

- Se guardan en MEDIA_ROOT con un nombre que genera el servidor; en la base
  solo queda la ruta relativa.
- Se descargan por la API. Las imágenes se pueden mostrar con un <img>
  normal gracias a un enlace firmado (?firma=...) que entrega la API: la
  firma depende de la ruta guardada, así que cambia sola cuando se cambia
  la foto y nadie puede adivinar la de otra persona.
- Los documentos (catálogos) exigen sesión iniciada.
"""
import logging
import mimetypes
import os
import uuid

from django.conf import settings
from django.core import signing
from django.core.exceptions import SuspiciousFileOperation
from django.core.files.storage import FileSystemStorage
from django.http import FileResponse
from django.utils.crypto import constant_time_compare
from django.utils.text import slugify
from rest_framework import status
from rest_framework.exceptions import NotAuthenticated, NotFound, PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .db import llamar_sp

logger = logging.getLogger(__name__)

EXT_IMAGEN = {".jpg", ".jpeg", ".png", ".webp"}
EXT_DOCUMENTO = {".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx"}

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


def borrar(ruta):
    """Borra un archivo guardado. Si no existe o la ruta no es válida, solo lo registra."""
    if not ruta:
        return
    try:
        almacen().delete(ruta)
    except (OSError, SuspiciousFileOperation):
        logger.warning("No se pudo borrar el archivo %s", ruta, exc_info=True)


def _firmador(recurso, tipo, id_registro):
    return signing.Signer(salt=f"muni.archivo:{recurso}:{tipo}:{id_registro}")


def url_firmada(recurso, tipo, id_registro, ruta):
    """Enlace para mostrar una imagen sin encabezado de sesión (p. ej. en un <img>)."""
    if not ruta:
        return None
    firma = _firmador(recurso, tipo, id_registro).signature(ruta)
    return f"/api/{recurso}/{id_registro}/{tipo}/?firma={firma}"


def firma_valida(recurso, tipo, id_registro, ruta, firma):
    if not (ruta and firma):
        return False
    return constant_time_compare(_firmador(recurso, tipo, id_registro).signature(ruta), firma)


class ArchivosMixin:
    """Agrega a un SPViewSet las acciones descargar, subir y quitar.

    Cada ruta fija ``tipo_archivo`` y la clase define ``tipos_archivo``:
        {"foto": {"nombre": "foto", "carpeta": "usuarios/fotos", "campo": "imagen_path",
                  "sp": "sp_..._actualizar_imagen", "extensiones": EXT_IMAGEN,
                  "ajuste_max_mb": "MUNI_MAX_MB_FOTO", "max_mb_defecto": 5,
                  "en_linea": True, "firmable": True}}
    """

    recurso_archivos = ""      # "usuarios" o "proveedores" (parte de la URL)
    tipos_archivo = {}
    tipo_archivo = None

    # ------------------------------------------------------------- hooks
    def puede_modificar_archivo(self, request, id_registro):
        return getattr(request.user, "es_admin", False)

    # ---------------------------------------------------------- internos
    def _conf(self):
        return self.tipos_archivo[self.tipo_archivo]

    def perform_content_negotiation(self, request, force=False):
        # Las descargas devuelven el archivo, no JSON
        return super().perform_content_negotiation(request, force=force or self.action == "descargar")

    def get_permissions(self):
        if self.action == "descargar":
            return [AllowAny()]  # se revisa sesión o firma dentro de descargar()
        return super().get_permissions()

    def _validar_archivo(self, conf, archivo):
        if archivo is None:
            raise ValidationError({"archivo": ["Seleccione un archivo."]})
        extension = os.path.splitext(archivo.name)[1].lower()
        if extension not in conf["extensiones"]:
            permitidas = ", ".join(sorted(e.lstrip(".") for e in conf["extensiones"]))
            raise ValidationError({"archivo": [f"Formato no permitido. Use: {permitidas}."]})
        limite = getattr(settings, conf["ajuste_max_mb"], conf["max_mb_defecto"])
        if archivo.size > limite * 1024 * 1024:
            raise ValidationError({"archivo": [f"El archivo pesa más de {limite} MB."]})
        if extension in _FIRMAS_IMAGEN:
            inicio = archivo.read(12)
            archivo.seek(0)
            es_valida = any(inicio.startswith(f) for f in _FIRMAS_IMAGEN[extension])
            if extension == ".webp":
                es_valida = es_valida and inicio[8:12] == b"WEBP"
            if not es_valida:
                raise ValidationError({"archivo": ["El archivo no es una imagen válida."]})
        return extension

    # ----------------------------------------------------------- acciones
    def descargar(self, request, id):
        conf = self._conf()
        autenticado = getattr(request.user, "is_authenticated", False)
        filas, _ = llamar_sp(f"{self.sp}_obtener", [id])
        ruta = filas[0].get(conf["campo"]) if filas else None

        firma = request.query_params.get("firma")
        if not autenticado and not (conf.get("firmable") and firma_valida(
                self.recurso_archivos, self.tipo_archivo, id, ruta, firma)):
            raise NotAuthenticated("Inicie sesión para ver este archivo.")
        if not filas:
            raise NotFound("El registro no existe.")
        if not ruta:
            raise NotFound(f"No tiene {conf['nombre']}.")
        try:
            archivo = almacen().open(ruta, "rb")
        except (FileNotFoundError, SuspiciousFileOperation):
            raise NotFound(f"No se encontró el archivo de {conf['nombre']} en el servidor.")

        respuesta = FileResponse(
            archivo,
            as_attachment=not conf["en_linea"],
            filename=os.path.basename(ruta),
            content_type=mimetypes.guess_type(ruta)[0] or "application/octet-stream",
        )
        if conf["en_linea"]:
            # El enlace cambia cuando cambia la imagen, así que se puede guardar en caché
            respuesta["Cache-Control"] = "private, max-age=86400"
        return respuesta

    def subir(self, request, id):
        if not self.puede_modificar_archivo(request, id):
            raise PermissionDenied("No tiene permiso para cambiar este archivo.")
        conf = self._conf()
        archivo = request.FILES.get("archivo")
        extension = self._validar_archivo(conf, archivo)
        anterior = self._obtener([id]).get(conf["campo"])  # 404 si no existe

        base = slugify(os.path.splitext(archivo.name)[0])[:50] or "archivo"
        ruta = almacen().save(f"{conf['carpeta']}/{id}-{base}-{uuid.uuid4().hex[:8]}{extension}", archivo)
        try:
            llamar_sp(conf["sp"], [id, ruta])
        except Exception:
            borrar(ruta)
            raise
        if anterior and anterior != ruta:
            borrar(anterior)
        return Response(self.salida(self._obtener([id])), status=status.HTTP_201_CREATED)

    def quitar(self, request, id):
        if not self.puede_modificar_archivo(request, id):
            raise PermissionDenied("No tiene permiso para quitar este archivo.")
        conf = self._conf()
        anterior = self._obtener([id]).get(conf["campo"])
        llamar_sp(conf["sp"], [id, None])
        borrar(anterior)
        return Response(self.salida(self._obtener([id])))