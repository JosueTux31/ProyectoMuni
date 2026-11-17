from rest_framework import status
from rest_framework.exceptions import NotFound
from rest_framework.response import Response

from apps.core import archivos
from apps.core.db import llamar_sp
from apps.core.viewsets import SPViewSet
from apps.usuarios.views import CorreoViewSet, PaginaWebViewSet, TelefonoViewSet

from . import serializers as s

CAMPOS_PROVEEDOR = (
    "cod_tipo_identificacion", "dni", "nombre", "apellido1", "apellido2",
    "cod_pais", "cod_provincia", "cod_canton", "cod_distrito",
    "otras_senas", "mapa", "cod_categoria",
)


class ProveedorViewSet(archivos.ArchivosMixin, SPViewSet):
    """CRUD de proveedores (sp_prv_proveedores_*).

    Los proveedores se guardan en personas con es_proveedor = TRUE y
    no pueden iniciar sesión. Consultar: cualquier usuario con sesión.
    Modificar: solo administradores. El código postal lo asigna la base
    de datos según el distrito.

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

    recurso_archivos = "proveedores"
    tipos_archivo = {
        "imagen": {
            "nombre": "imagen", "carpeta": "proveedores/imagenes", "campo": "imagen_path",
            "sp": "sp_prv_proveedores_actualizar_imagen", "extensiones": archivos.EXT_IMAGEN,
            "ajuste_max_mb": "MUNI_MAX_MB_IMAGEN", "max_mb_defecto": 5,
            "en_linea": True, "firmable": True,
        },
        "catalogo": {
            "nombre": "catálogo de servicios", "carpeta": "proveedores/catalogos", "campo": "archivo_path",
            "sp": "sp_prv_proveedores_actualizar_archivo", "extensiones": archivos.EXT_DOCUMENTO,
            "ajuste_max_mb": "MUNI_MAX_MB_CATALOGO", "max_mb_defecto": 20,
            "en_linea": False, "firmable": False,
        },
    }

    def salida(self, fila):
        fila = super().salida(fila)
        fila["imagen_url"] = archivos.url_firmada("proveedores", "imagen", fila.get("id"), fila.get("imagen_path"))
        return fila

    # POST /proveedores/<id>/activar/
    def activar(self, request, id):
        llamar_sp("sp_prv_proveedores_activar", [id])
        return Response(self.salida(self._obtener([id])))

    # DELETE /proveedores/<id>/eliminar-fisico/
    def eliminar_fisico(self, request, id):
        proveedor = self._obtener([id])
        llamar_sp("sp_prv_proveedores_eliminar_fisico", [id])
        for conf in self.tipos_archivo.values():
            archivos.borrar(proveedor.get(conf["campo"]))
        return Response(status=status.HTTP_204_NO_CONTENT)


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
