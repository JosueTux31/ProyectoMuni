from django.contrib import admin
from django.urls import include, path
from django.views.generic import RedirectView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from apps.core.consultas import ConsultaCedulaView
from apps.core.frontend import servir_frontend

urlpatterns = [
    # Página web
    path("", RedirectView.as_view(url="/app/", permanent=False)),
    path("app/", servir_frontend),
    path("app/<path:ruta>", servir_frontend),

    path("admin/", admin.site.urls),

    # APIs
    path("api/geografia/", include("apps.geografia.urls")),
    path("api/catalogos/", include("apps.catalogos.urls")),
    path("api/usuarios/", include("apps.usuarios.urls")),
    path("api/proveedores/", include("apps.proveedores.urls")),
    path("api/auditoria/", include("apps.auditoria.urls")),
    path("api/consultas/cedula/<str:numero>/", ConsultaCedulaView.as_view(), name="consulta-cedula"),

    # Documentación Swagger
    path("api/schema/", SpectacularAPIView.as_view(), name="schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="schema"), name="docs"),
]
