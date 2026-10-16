from django.urls import path

from apps.core.rutas import rutas_crud

from . import views as v

app_name = "usuarios"

DETALLE = "<int:id_usuario>/"

urlpatterns = [
    # Sesión
    path("login/", v.UsuarioViewSet.as_view({"post": "login"}), name="login"),
    path("validar-credenciales/", v.UsuarioViewSet.as_view({"post": "login"}),
         name="validar-credenciales"),
    path("yo/", v.UsuarioViewSet.as_view({"get": "yo"}), name="yo"),
    path("logout/", v.UsuarioViewSet.as_view({"post": "logout"}), name="logout"),

    # Acciones especiales de usuarios
    path("<int:id>/activar/",
         v.UsuarioViewSet.as_view({"post": "activar"}), name="usuarios-activar"),
    path("<int:id>/cambiar-clave/",
         v.UsuarioViewSet.as_view({"post": "cambiar_clave"}), name="usuarios-cambiar-clave"),
    path("<int:id>/eliminar-fisico/",
         v.UsuarioViewSet.as_view({"delete": "eliminar_fisico"}), name="usuarios-eliminar-fisico"),
    path("<int:id>/foto/",
         v.UsuarioViewSet.as_view({"get": "descargar", "post": "subir", "delete": "quitar"}, tipo_archivo="foto"),
         name="usuarios-foto"),

    # CRUD de usuarios
    *rutas_crud("", "<int:id>/", v.UsuarioViewSet, "usuarios"),

    # Detalles del usuario
    *rutas_crud(DETALLE + "telefonos/", "<int:num_linea>/", v.TelefonoViewSet, "telefonos"),
    *rutas_crud(DETALLE + "correos/", "<int:num_linea>/", v.CorreoViewSet, "correos"),
    *rutas_crud(DETALLE + "paginas-webs/", "<int:num_linea>/", v.PaginaWebViewSet, "paginas-webs"),
    *rutas_crud(DETALLE + "historial-claves/", "<int:num_linea>/", v.HistorialClaveViewSet,
                "historial-claves"),
]
