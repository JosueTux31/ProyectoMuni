from django.urls import path

from apps.core.rutas import rutas_crud

from . import views as v

app_name = "dispositivos"

DISPOSITIVO = "<int:id_disp>/"
DOCUMENTO = DISPOSITIVO + "documentos/<int:num_linea>/"

urlpatterns = [
    # Catálogos del módulo (las categorías son fijas: solo se consultan)
    path("categorias/", v.CategoriaDispositivoViewSet.as_view({"get": "list"}), name="categorias-lista"),
    path("categorias/<int:id_categoria>/", v.CategoriaDispositivoViewSet.as_view({"get": "retrieve"}),
         name="categorias-detalle"),
    *rutas_crud("tipos/", "<int:tipo_disp>/", v.TipoDispositivoViewSet, "tipos"),
    *rutas_crud("marcas/", "<int:id_marca>/", v.MarcaViewSet, "marcas"),
    *rutas_crud("modelos/", "<int:id_marca>/<int:id_modelo>/", v.ModeloViewSet, "modelos"),
    *rutas_crud("sistemas-operativos/", "<int:id_os>/", v.SistemaOperativoViewSet, "sistemas-operativos"),
    *rutas_crud("tipos-documentos/", "<int:id_doc>/", v.TipoDocumentoViewSet, "tipos-documentos"),
    *rutas_crud("edificios/", "<int:id_predio>/", v.EdificioViewSet, "edificios"),
    *rutas_crud("procesadores/", "<int:id_proc>/", v.ProcesadorViewSet, "procesadores"),
    *rutas_crud("firmwares/", "<int:id_firmw>/", v.FirmwareViewSet, "firmwares"),
    *rutas_crud("estados/", "<int:id_estado>/", v.EstadoEquipoViewSet, "estados"),
    *rutas_crud("roles/", "<int:id_rol>/", v.TipoRolViewSet, "roles"),
    *rutas_crud("herramientas/", "<int:id_herram>/", v.TipoHerramientaViewSet, "herramientas"),

    # Acciones especiales de los dispositivos
    path(DISPOSITIVO + "activar/",
         v.DispositivoViewSet.as_view({"post": "activar"}), name="dispositivos-activar"),
    path(DISPOSITIVO + "eliminar-fisico/",
         v.DispositivoViewSet.as_view({"delete": "eliminar_fisico"}), name="dispositivos-eliminar-fisico"),
    path(DISPOSITIVO + "historial/",
         v.DispositivoViewSet.as_view({"get": "historial"}), name="dispositivos-historial"),

    # Puertos de los switches: qué equipo está conectado a cada uno
    path("switches/", v.PuertoSwitchViewSet.as_view({"get": "equipos"}), name="switches"),
    path(DISPOSITIVO + "puertos/", v.PuertoSwitchViewSet.as_view({"get": "listar_puertos"}), name="puertos-lista"),
    path(DISPOSITIVO + "puertos/<str:tipo_puerto>/<int:num_puerto>/",
         v.PuertoSwitchViewSet.as_view({"put": "guardar", "delete": "liberar"}), name="puertos-detalle"),
    path(DISPOSITIVO + "conexiones/", v.PuertoSwitchViewSet.as_view({"get": "conexiones"}), name="conexiones"),

    # Archivo de cada documento
    path(DOCUMENTO + "archivo/",
         v.DocumentoDispositivoViewSet.as_view({"get": "descargar"}), name="documentos-archivo"),
    path(DOCUMENTO + "vista-previa/",
         v.DocumentoDispositivoViewSet.as_view({"get": "vista_previa"}), name="documentos-vista-previa"),

    # CRUD de equipos y de sus tablas de detalle: IP, MAC, líneas, IMEI y documentos
    *rutas_crud("", DISPOSITIVO, v.DispositivoViewSet, "dispositivos"),
    *rutas_crud(DISPOSITIVO + "ips/", "<int:num_linea>/", v.IpDispositivoViewSet, "ips"),
    *rutas_crud(DISPOSITIVO + "macs/", "<int:num_linea>/", v.MacDispositivoViewSet, "macs"),
    *rutas_crud(DISPOSITIVO + "moviles/", "<int:num_linea>/", v.MovilDispositivoViewSet, "moviles"),
    *rutas_crud(DISPOSITIVO + "imeis/", "<int:num_linea>/", v.ImeiDispositivoViewSet, "imeis"),
    *rutas_crud(DISPOSITIVO + "documentos/", "<int:num_linea>/", v.DocumentoDispositivoViewSet, "documentos"),
]
