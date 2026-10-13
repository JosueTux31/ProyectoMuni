# urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    TipoIdentificacionViewSet,
    RolUsuarioViewSet,
    TipoAutenticacionViewSet,
    DepartamentoViewSet,
    TipoTelefonoViewSet,
    TipoCorreoViewSet,
)

router = DefaultRouter()
router.register(r'tipos-identificacion', TipoIdentificacionViewSet, basename='tipo-identificacion')
router.register(r'roles-usuarios', RolUsuarioViewSet, basename='rol-usuario')
router.register(r'tipos-autenticacion', TipoAutenticacionViewSet, basename='tipo-autenticacion')
router.register(r'departamentos', DepartamentoViewSet, basename='departamento')
router.register(r'tipos-telefonos', TipoTelefonoViewSet, basename='tipo-telefono')
router.register(r'tipos-correos', TipoCorreoViewSet, basename='tipo-correo')

urlpatterns = [
    path('', include(router.urls)),
]