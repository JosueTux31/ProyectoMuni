from apps.core.viewsets import SPViewSet

from . import serializers as s


class PaisViewSet(SPViewSet):
    """CRUD de países (sp_geo_paises_*)."""
    sp = "sp_geo_paises"
    campos_pk = ("cod_pais",)
    campos_insertar = ("cod_pais", "nombre_pais")
    campos_actualizar = ("nombre_pais",)
    serializer_class = s.PaisSerializer
    serializer_actualizar_class = s.PaisActualizarSerializer


class ProvinciaViewSet(SPViewSet):
    """CRUD de provincias (sp_geo_provincias_*). Filtro: ?cod_pais="""
    sp = "sp_geo_provincias"
    campos_pk = ("cod_pais", "cod_provincia")
    campos_insertar = ("cod_pais", "cod_provincia", "nombre_provincia")
    campos_actualizar = ("nombre_provincia",)
    filtros_listar = ("cod_pais",)
    serializer_class = s.ProvinciaSerializer
    serializer_actualizar_class = s.ProvinciaActualizarSerializer
    serializer_filtros_class = s.ProvinciaFiltrosSerializer


class CantonViewSet(SPViewSet):
    """CRUD de cantones (sp_geo_cantones_*). Filtros: ?cod_pais=&cod_provincia="""
    sp = "sp_geo_cantones"
    campos_pk = ("cod_pais", "cod_provincia", "cod_canton")
    campos_insertar = ("cod_pais", "cod_provincia", "cod_canton", "nombre_canton")
    campos_actualizar = ("nombre_canton",)
    filtros_listar = ("cod_pais", "cod_provincia")
    serializer_class = s.CantonSerializer
    serializer_actualizar_class = s.CantonActualizarSerializer
    serializer_filtros_class = s.CantonFiltrosSerializer


class DistritoViewSet(SPViewSet):
    """CRUD de distritos (sp_geo_distritos_*), con su código postal. Filtros: ?cod_pais=&cod_provincia=&cod_canton="""
    sp = "sp_geo_distritos"
    campos_pk = ("cod_pais", "cod_provincia", "cod_canton", "cod_distrito")
    campos_insertar = ("cod_pais", "cod_provincia", "cod_canton", "cod_distrito", "nombre_distrito", "codigo_postal")
    campos_actualizar = ("nombre_distrito", "codigo_postal")
    filtros_listar = ("cod_pais", "cod_provincia", "cod_canton")
    serializer_class = s.DistritoSerializer
    serializer_actualizar_class = s.DistritoActualizarSerializer
    serializer_filtros_class = s.DistritoFiltrosSerializer
