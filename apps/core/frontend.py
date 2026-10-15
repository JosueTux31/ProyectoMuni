"""Sirve la página web (carpeta FRONTEND_DIR) desde el mismo Django,
así la página y las APIs comparten dirección y no hace falta CORS."""
from django.conf import settings
from django.views.static import serve


def servir_frontend(request, ruta=""):
    return serve(request, ruta or "index.html", document_root=settings.FRONTEND_DIR)
