from apps.core.rutas import rutas_crud

from .views import CantonViewSet, DistritoViewSet, PaisViewSet, ProvinciaViewSet

app_name = "geografia"

urlpatterns = [
    *rutas_crud("paises/", "<str:cod_pais>/", PaisViewSet, "paises"),
    *rutas_crud("provincias/", "<str:cod_pais>/<str:cod_provincia>/", ProvinciaViewSet, "provincias"),
    *rutas_crud("cantones/", "<str:cod_pais>/<str:cod_provincia>/<str:cod_canton>/",
                CantonViewSet, "cantones"),
    *rutas_crud("distritos/", "<str:cod_pais>/<str:cod_provincia>/<str:cod_canton>/<str:cod_distrito>/",
                DistritoViewSet, "distritos"),
]
