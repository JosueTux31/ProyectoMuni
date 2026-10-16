from apps.core.viewsets import SPViewSet

from .serializers import (
    Descripcion50Serializer, Descripcion80Serializer, Descripcion120Serializer, Descripcion150Serializer,
)


class CatalogoViewSet(SPViewSet):
    """Base de los catálogos: un código autoincremental y una descripción.
    _insertar devuelve el código nuevo en su parámetro OUT."""
    campos_insertar = ("descripcion",)
    campos_actualizar = ("descripcion",)
    insertar_devuelve_codigo = True
    serializer_class = Descripcion50Serializer


class TipoIdentificacionViewSet(CatalogoViewSet):
    sp = "sp_cat_tipos_identificaciones"
    campos_pk = ("cod_tipo_identificacion",)


class RolUsuarioViewSet(CatalogoViewSet):
    sp = "sp_cat_roles_usuarios"
    campos_pk = ("cod_rol",)


class TipoAutenticacionViewSet(CatalogoViewSet):
    sp = "sp_cat_tipos_autenticaciones"
    campos_pk = ("cod_tipo_auth",)
    serializer_class = Descripcion80Serializer


class DepartamentoViewSet(CatalogoViewSet):
    sp = "sp_cat_departamentos"
    campos_pk = ("cod_departamento",)
    serializer_class = Descripcion120Serializer


class TipoTelefonoViewSet(CatalogoViewSet):
    sp = "sp_cat_tipos_telefonos"
    campos_pk = ("cod_telefono",)


class TipoCorreoViewSet(CatalogoViewSet):
    sp = "sp_cat_tipos_correos"
    campos_pk = ("cod_correo",)


class CategoriaProveedorViewSet(CatalogoViewSet):
    sp = "sp_cat_categorias_proveedores"
    campos_pk = ("cod_categoria",)
    serializer_class = Descripcion150Serializer
