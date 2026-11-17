"""Archivos subidos (fotos de usuarios, imágenes y catálogos de proveedores).

- Se guardan en MEDIA_ROOT con un nombre que genera el servidor; en la base
  solo queda la ruta relativa.
- Se descargan por la API. Las imágenes se pueden mostrar con un <img>
  normal gracias a un enlace firmado (?firma=...) que entrega la API: la
  firma depende de la ruta guardada, así que cambia sola cuando se cambia
  la foto y nadie puede adivinar la de otra persona.
- Los documentos (catálogos) exigen sesión iniciada.
- Vista previa: los PDF e imágenes se muestran tal cual; Word, Excel y
  PowerPoint se convierten a PDF con LibreOffice (si está instalado en el
  servidor) y la conversión se guarda para no repetirla.
"""
import logging
import mimetypes
import os
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path

from django.conf import settings
from django.core import signing
from django.core.exceptions import SuspiciousFileOperation
from django.core.files.storage import FileSystemStorage
from django.http import FileResponse
from django.utils.crypto import constant_time_compare
from django.utils.text import slugify
from rest_framework import status
from rest_framework.exceptions import APIException, NotAuthenticated, NotFound, PermissionDenied, ValidationError
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


def imagen_valida(archivo, extension):
    """True si los primeros bytes corresponden al formato de imagen de la
    extensión (evita un archivo de otro tipo con la extensión cambiada).
    Las extensiones que no son de imagen siempre dan True."""
    if extension not in _FIRMAS_IMAGEN:
        return True
    inicio = archivo.read(12)
    archivo.seek(0)
    valida = any(inicio.startswith(f) for f in _FIRMAS_IMAGEN[extension])
    if extension == ".webp":
        valida = valida and inicio[8:12] == b"WEBP"
    return valida


def borrar(ruta):
    """Borra un archivo guardado (y su vista previa). Si no existe, solo lo registra."""
    if not ruta:
        return
    try:
        almacen().delete(ruta)
        almacen().delete(_ruta_vista_previa(ruta))
    except (OSError, SuspiciousFileOperation):
        logger.warning("No se pudo borrar el archivo %s", ruta, exc_info=True)


# ------------------------------------------------------------- vista previa
EXT_OFFICE = {".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx"}


class VistaPreviaNoDisponible(APIException):
    status_code = 503
    default_detail = ("La vista previa de Word, Excel y PowerPoint necesita LibreOffice en el servidor "
                      "(sudo apt install libreoffice-writer libreoffice-calc libreoffice-impress). "
                      "Mientras tanto, descargue el archivo para verlo.")
    default_code = "vista_previa_no_disponible"


def _ruta_vista_previa(ruta):
    return f"vistas_previas/{Path(ruta).stem}.pdf"


def pdf_de_vista_previa(ruta):
    """Convierte un documento de Office a PDF con LibreOffice y devuelve la
    ruta relativa del PDF. Reutiliza la conversión si ya existe."""
    try:
        origen = Path(almacen().path(ruta))
    except SuspiciousFileOperation:
        raise NotFound("No se encontró el archivo en el servidor.")
    if not origen.exists():
        raise NotFound("No se encontró el archivo en el servidor.")
    relativa = _ruta_vista_previa(ruta)
    destino = Path(almacen().path(relativa))
    if destino.exists() and destino.stat().st_mtime >= origen.stat().st_mtime:
        return relativa

    programa = getattr(settings, "MUNI_LIBREOFFICE", None) or shutil.which("soffice") or shutil.which("libreoffice")
    if not programa:
        raise VistaPreviaNoDisponible()

    with tempfile.TemporaryDirectory(prefix="muni_vista_") as tmp:
        # Perfil propio por conversión: permite varias conversiones a la vez
        perfil = Path(tmp, "perfil").as_uri()
        try:
            subprocess.run(
                [programa, f"-env:UserInstallation={perfil}", "--headless", "--norestore",
                 "--convert-to", "pdf", "--outdir", tmp, str(origen)],
                capture_output=True, timeout=120, check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            logger.warning("Falló la conversión a PDF de %s", ruta, exc_info=True)
            raise VistaPreviaNoDisponible("No se pudo generar la vista previa. Descargue el archivo para verlo.")
        generado = Path(tmp, f"{origen.stem}.pdf")
        if not generado.exists():
            raise VistaPreviaNoDisponible("No se pudo generar la vista previa. Descargue el archivo para verlo.")
        destino.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(generado), destino)
    return relativa


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
        return super().perform_content_negotiation(
            request, force=force or self.action in ("descargar", "vista_previa"))

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
        if not imagen_valida(archivo, extension):
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

    def vista_previa(self, request, id):
        """Devuelve el archivo listo para mostrar dentro de la página (PDF o imagen)."""
        conf = self._conf()
        ruta = self._obtener([id]).get(conf["campo"])
        if not ruta:
            raise NotFound(f"No tiene {conf['nombre']}.")
        extension = Path(ruta).suffix.lower()
        if extension in EXT_OFFICE:
            ruta_mostrar = pdf_de_vista_previa(ruta)
        elif extension == ".pdf" or extension in EXT_IMAGEN:
            ruta_mostrar = ruta
        else:
            raise NotFound("Este tipo de archivo no tiene vista previa.")
        try:
            archivo = almacen().open(ruta_mostrar, "rb")
        except (FileNotFoundError, SuspiciousFileOperation):
            raise NotFound(f"No se encontró el archivo de {conf['nombre']} en el servidor.")
        return FileResponse(archivo, as_attachment=False, filename=Path(ruta_mostrar).name,
                            content_type=mimetypes.guess_type(ruta_mostrar)[0] or "application/pdf")

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
