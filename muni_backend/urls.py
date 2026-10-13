"""
URL configuration for muni_backend project.
"""

from django.contrib import admin
from django.urls import include, path
from rest_framework.routers import DefaultRouter
from .views import home

from apps.catalogos.views import (
    TipoIdentificacionViewSet,
    RolUsuarioViewSet,
    TipoAutenticacionViewSet,
    DepartamentoViewSet,
    TipoTelefonoViewSet,
    TipoCorreoViewSet,
)

from apps.geografia.views import (
    PaisViewSet,
    ProvinciaViewSet,
    CantonViewSet,
    DistritoViewSet,
)

from apps.usuarios.views import (
    UsuarioViewSet,
    UsuarioTelefonoViewSet,
    UsuarioCorreoViewSet,
    UsuarioPaginaWebViewSet,
)


# Enrutador principal de la API
router = DefaultRouter()


# Catálogos
router.register(
    r"tipos-identificacion",
    TipoIdentificacionViewSet,
    basename="tipo-identificacion",
)

router.register(
    r"roles-usuarios",
    RolUsuarioViewSet,
    basename="rol-usuario",
)

router.register(
    r"tipos-autenticacion",
    TipoAutenticacionViewSet,
    basename="tipo-autenticacion",
)

router.register(
    r"departamentos",
    DepartamentoViewSet,
    basename="departamento",
)

router.register(
    r"tipos-telefonos",
    TipoTelefonoViewSet,
    basename="tipo-telefono",
)

router.register(
    r"tipos-correos",
    TipoCorreoViewSet,
    basename="tipo-correo",
)


# Geografía
router.register(
    r"paises",
    PaisViewSet,
    basename="pais",
)

router.register(
    r"provincias",
    ProvinciaViewSet,
    basename="provincia",
)

router.register(
    r"cantones",
    CantonViewSet,
    basename="canton",
)

router.register(
    r"distritos",
    DistritoViewSet,
    basename="distrito",
)


# Usuarios
router.register(
    r"usuarios",
    UsuarioViewSet,
    basename="usuario",
)

router.register(
    r"usuarios-telefonos",
    UsuarioTelefonoViewSet,
    basename="usuario-telefono",
)

router.register(
    r"usuarios-correos",
    UsuarioCorreoViewSet,
    basename="usuario-correo",
)

router.register(
    r"usuarios-webs",
    UsuarioPaginaWebViewSet,
    basename="usuario-web",
)


urlpatterns = [
    path("", home, name="home"),
    path("admin/", admin.site.urls),
    path("api/", include(router.urls)),
]