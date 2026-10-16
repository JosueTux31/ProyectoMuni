import mimetypes
import os

from django.core.exceptions import SuspiciousFileOperation
from django.http import FileResponse
from rest_framework import status
from rest_framework.exceptions import NotFound
from rest_framework.response import Response

from apps.core.db import llamar_sp
from apps.core.viewsets import SPViewSet
from apps.usuarios.views import CorreoViewSet, PaginaWebViewSet, TelefonoViewSet

from . import archivos
from . import serializers as s

CAMPOS_PROVEEDOR = (
    "cod_tipo_identificacion", "dni", "nombre", "apellido1", "apellido2",
    "cod_pais", "cod_provincia", "cod_canton", "cod_distrito",
    "otras_senas", "mapa", "cod_categoria",
)


class ProveedorViewSet(SPViewSet):
    """CRUD de proveedores (sp_prv_proveedores_*).

    Los proveedores se guardan en usr_usuarios con es_proveedor = TRUE y
    no pueden iniciar sesión. Consultar: cualquier usuario con sesión.
    Modificar: solo administradores.

    - DELETE desactiva. DELETE /proveedores/<id>/eliminar-fisico/ lo borra.
    - Imagen y catálogo de servicios: GET (descargar), POST (subir, campo
      "archivo" en multipart/form-data) y DELETE (quitar) en
      /proveedores/<id>/imagen/ y /proveedores/<id>/catalogo/.
    """
    sp = "sp_prv_proveedores"
    campos_pk = ("id",)
    campos_insertar = CAMPOS_PROVEEDOR
    campos_actualizar = CAMPOS_PROVEEDOR + ("activo",)
    filtros_listar = ("activo", "cod_categoria", "buscar")
    insertar_devuelve_codigo = True
    campos_bool = ("activo", "es_proveedor")

    serializer_class = s.ProveedorSerializer
    serializer_actualizar_class = s.ProveedorActualizarSerializer
    serializer_filtros_class = s.ProveedorFiltrosSerializer

    # "imagen" o "catalogo"; lo fija cada ruta de archivos en urls.py
    tipo_archivo = None

    def perform_content_negotiation(self, request, force=False):
        # Las descargas devuelven el archivo, no JSON: no exigir Accept: application/json
        return super().perform_content_negotiation(request, force=force or self.action == "descargar")

    # POST /proveedores/<id>/activar/
    def activar(self, request, id):
        llamar_sp("sp_prv_proveedores_activar", [id])
        return Response(self.salida(self._obtener([id])))

    # DELETE /proveedores/<id>/eliminar-fisico/
    def eliminar_fisico(self, request, id):
        proveedor = self._obtener([id])
        llamar_sp("sp_prv_proveedores_eliminar_fisico", [id])
        for conf in archivos.TIPOS.values():
            archivos.borrar(proveedor.get(conf["campo"]))
        return Response(status=status.HTTP_204_NO_CONTENT)

    # ---------------------------------------------------- imagen y catálogo
    def _conf(self):
        return archivos.TIPOS[self.tipo_archivo]

    def descargar(self, request, id):
        conf = self._conf()
        ruta = self._obtener([id]).get(conf["campo"])
        if not ruta:
            raise NotFound(f"El proveedor no tiene {conf['nombre']}.")
        try:
            archivo = archivos.almacen().open(ruta, "rb")
        except (FileNotFoundError, SuspiciousFileOperation):
            raise NotFound(f"No se encontró el archivo del {conf['nombre']} en el servidor.")
        return FileResponse(
            archivo,
            as_attachment=not conf["en_linea"],
            filename=os.path.basename(ruta),
            content_type=mimetypes.guess_type(ruta)[0] or "application/octet-stream",
        )

    def subir(self, request, id):
        conf = self._conf()
        archivo = request.FILES.get("archivo")
        extension = archivos.validar(conf, archivo)
        anterior = self._obtener([id]).get(conf["campo"])  # 404 si no existe

        ruta = archivos.guardar(conf, id, archivo, extension)
        try:
            llamar_sp(conf["sp"], [id, ruta])
        except Exception:
            archivos.borrar(ruta)
            raise
        if anterior and anterior != ruta:
            archivos.borrar(anterior)
        return Response(self.salida(self._obtener([id])), status=status.HTTP_201_CREATED)

    def quitar(self, request, id):
        conf = self._conf()
        anterior = self._obtener([id]).get(conf["campo"])
        llamar_sp(conf["sp"], [id, None])
        archivos.borrar(anterior)
        return Response(self.salida(self._obtener([id])))


class _SoloDeProveedores:
    """Las rutas /proveedores/<id>/telefonos/ etc. solo aceptan ids de proveedores."""

    def initial(self, request, *args, **kwargs):
        super().initial(request, *args, **kwargs)
        filas, _ = llamar_sp("sp_prv_proveedores_obtener", [kwargs["id_usuario"]])
        if not filas:
            raise NotFound("El proveedor no existe.")


class TelefonoProveedorViewSet(_SoloDeProveedores, TelefonoViewSet):
    pass


class CorreoProveedorViewSet(_SoloDeProveedores, CorreoViewSet):
    pass


class PaginaWebProveedorViewSet(_SoloDeProveedores, PaginaWebViewSet):
    pass
