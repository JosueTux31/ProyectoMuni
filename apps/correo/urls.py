from django.urls import path

from . import views as v

app_name = "correo"

CONFIG = v.ConfiguracionViewSet
ENVIO = v.EnvioViewSet
LISTA = v.ListaViewSet

urlpatterns = [
    # Cuenta institucional
    path("configuracion/", CONFIG.as_view({"get": "obtener", "put": "guardar"}), name="configuracion"),
    path("configuracion/prueba/", CONFIG.as_view({"post": "prueba"}), name="configuracion-prueba"),

    # Personal con correo y avisos
    path("personal/", ENVIO.as_view({"get": "personal"}), name="personal"),
    path("envios/", ENVIO.as_view({"get": "list", "post": "create"}), name="envios-lista"),
    path("envios/prueba/", ENVIO.as_view({"post": "prueba"}), name="envios-prueba"),
    path("envios/<int:id_envio>/", ENVIO.as_view({"get": "retrieve", "delete": "destroy"}), name="envios-detalle"),
    path("envios/<int:id_envio>/enviar/", ENVIO.as_view({"post": "enviar"}), name="envios-enviar"),
    path("envios/<int:id_envio>/reintentar/", ENVIO.as_view({"post": "reintentar"}), name="envios-reintentar"),
    path("envios/<int:id_envio>/cancelar/", ENVIO.as_view({"post": "cancelar"}), name="envios-cancelar"),
    path("envios/<int:id_envio>/adjuntos/<int:num_linea>/", ENVIO.as_view({"get": "adjunto"}), name="envios-adjunto"),

    # Listas de correos importadas (comparación con el personal)
    path("listas/", LISTA.as_view({"get": "list", "post": "create"}), name="listas-lista"),
    path("listas/<int:id_lista>/", LISTA.as_view({"get": "retrieve", "put": "update", "delete": "destroy"}),
         name="listas-detalle"),

    # Control de licencias de correo (Google Workspace y Sophos Email)
    path("licencias/", LISTA.as_view({"get": "licencias"}), name="licencias"),
]
