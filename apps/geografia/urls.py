from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    # ... tus otras vistas ...
    PaisViewSet, ProvinciaViewSet, CantonViewSet, DistritoViewSet
)

router = DefaultRouter()

# (Tus catálogos anteriores)

# Geografía
router.register(r'paises', PaisViewSet, basename='pais')
router.register(r'provincias', ProvinciaViewSet, basename='provincia')
router.register(r'cantones', CantonViewSet, basename='canton')
router.register(r'distritos', DistritoViewSet, basename='distrito')

urlpatterns = [
    path('', include(router.urls)),
]