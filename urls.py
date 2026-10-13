"""
URL configuration for muni_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
"""
from django.contrib import admin
from django.urls import path, include
from rest_framework.routers import DefaultRouter

# 1. Importamos las vistas de la app 'catalogos' (Nombres actualizados)
from apps.catalogos.views import (
    TipoIdentificacionViewSet,
    RolUsuarioViewSet,
    TipoAutenticacionViewSet,
    DepartamentoViewSet,
    TipoTelefonoViewSet,
    TipoCorreoViewSet
)

# 2. Importamos las vistas de la app 'geografia'
from apps.geografia.views import (
    PaisViewSet,
    ProvinciaViewSet,
    CantonViewSet,
    DistritoViewSet
)

# 3. Importamos las vistas de la app 'usuarios' (Agregadas)
from apps.usuarios.views import (
    UsuarioViewSet,
    UsuarioTelefonoViewSet,
    UsuarioCorreoViewSet,
    UsuarioPaginaWebViewSet
)

# 4. Creamos UN SOLO enrutador maestro
router = DefaultRouter()

# --- Registrar endpoints de Catálogos ---
router.register(r'tipos-identificacion', TipoIdentificacionViewSet, basename='tipo-identificacion')
router.register(r'roles-usuarios', RolUsuarioViewSet, basename='rol-usuario')
router.register(r'tipos-autenticacion', TipoAutenticacionViewSet, basename='tipo-autenticacion')
router.register(r'departamentos', DepartamentoViewSet, basename='departamento')
router.register(r'tipos-telefonos', TipoTelefonoViewSet, basename='tipo-telefono')
router.register(r'tipos-correos', TipoCorreoViewSet, basename='tipo-correo')

# --- Registrar endpoints de Geografía ---
router.register(r'paises', PaisViewSet, basename='pais')
router.register(r'provincias', ProvinciaViewSet, basename='provincia')
router.register(r'cantones', CantonViewSet, basename='canton')
router.register(r'distritos', DistritoViewSet, basename='distrito')

# --- Registrar endpoints de Usuarios ---
router.register(r'usuarios', UsuarioViewSet, basename='usuario')
router.register(r'usuarios-telefonos', UsuarioTelefonoViewSet, basename='usuario-telefono')
router.register(r'usuarios-correos', UsuarioCorreoViewSet, basename='usuario-correo')
router.register(r'usuarios-webs', UsuarioPaginaWebViewSet, basename='usuario-web')

# 5. Asignamos el enrutador maestro a la ruta 'api/'
urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include(router.urls)),
]