"""Sirve la página web (carpeta FRONTEND_DIR) desde el mismo Django,
así la página y las APIs comparten dirección y no hace falta CORS."""
from django.conf import settings
from django.views.static import serve


def servir_frontend(request, ruta=""):
    respuesta = serve(request, ruta or "index.html", document_root=settings.FRONTEND_DIR)
    # La página cambia con cada versión del sistema: el navegador debe
    # preguntar siempre si hay una más nueva antes de usar la que guardó.
    # Si el archivo no cambió, Django responde 304 y no se vuelve a bajar.
    respuesta["Cache-Control"] = "no-cache"
    return respuesta
