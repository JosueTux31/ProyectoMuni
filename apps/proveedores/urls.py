from django.urls import path

from apps.core.rutas import rutas_crud

from . import views as v

app_name = "proveedores"

DETALLE = "<int:id_usuario>/"
ACCIONES_ARCHIVO = {"get": "descargar", "post": "subir", "delete": "quitar"}

urlpatterns = [
    # Acciones especiales
    path("<int:id>/activar/",
         v.ProveedorViewSet.as_view({"post": "activar"}), name="proveedores-activar"),
    path("<int:id>/eliminar-fisico/",
         v.ProveedorViewSet.as_view({"delete": "eliminar_fisico"}), name="proveedores-eliminar-fisico"),

    # Imagen y catálogo de servicios
    path("<int:id>/imagen/",
         v.ProveedorViewSet.as_view(ACCIONES_ARCHIVO, tipo_archivo="imagen"), name="proveedores-imagen"),
    path("<int:id>/catalogo/",
         v.ProveedorViewSet.as_view(ACCIONES_ARCHIVO, tipo_archivo="catalogo"), name="proveedores-catalogo"),

    # CRUD de proveedores
    *rutas_crud("", "<int:id>/", v.ProveedorViewSet, "proveedores"),

    # Contactos (mismas tablas que los usuarios)
    *rutas_crud(DETALLE + "telefonos/", "<int:num_linea>/", v.TelefonoProveedorViewSet, "telefonos"),
    *rutas_crud(DETALLE + "correos/", "<int:num_linea>/", v.CorreoProveedorViewSet, "correos"),
    *rutas_crud(DETALLE + "paginas-webs/", "<int:num_linea>/", v.PaginaWebProveedorViewSet, "paginas-webs"),
]
