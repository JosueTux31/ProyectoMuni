from django.urls import path

from apps.core.rutas import rutas_crud

from . import views as v

app_name = "dispositivos"

DISPOSITIVO = "<int:id_disp>/"
DOCUMENTO = DISPOSITIVO + "documentos/<int:num_linea>/"

urlpatterns = [
    # Catálogos del módulo
    *rutas_crud("tipos/", "<int:tipo_disp>/", v.TipoDispositivoViewSet, "tipos"),
    *rutas_crud("marcas/", "<int:id_marca>/", v.MarcaViewSet, "marcas"),
    *rutas_crud("modelos/", "<int:id_marca>/<int:id_modelo>/", v.ModeloViewSet, "modelos"),
    *rutas_crud("sistemas-operativos/", "<int:id_os>/", v.SistemaOperativoViewSet, "sistemas-operativos"),
    *rutas_crud("tipos-documentos/", "<int:id_doc>/", v.TipoDocumentoViewSet, "tipos-documentos"),
    *rutas_crud("edificios/", "<int:id_edificio>/", v.EdificioViewSet, "edificios"),

    # Acciones especiales de los dispositivos
    path(DISPOSITIVO + "activar/",
         v.DispositivoViewSet.as_view({"post": "activar"}), name="dispositivos-activar"),
    path(DISPOSITIVO + "eliminar-fisico/",
         v.DispositivoViewSet.as_view({"delete": "eliminar_fisico"}), name="dispositivos-eliminar-fisico"),
    path(DISPOSITIVO + "historial/",
         v.DispositivoViewSet.as_view({"get": "historial"}), name="dispositivos-historial"),

    # Archivo de cada documento
    path(DOCUMENTO + "archivo/",
         v.DocumentoDispositivoViewSet.as_view({"get": "descargar"}), name="documentos-archivo"),
    path(DOCUMENTO + "vista-previa/",
         v.DocumentoDispositivoViewSet.as_view({"get": "vista_previa"}), name="documentos-vista-previa"),

    # CRUD de dispositivos y de sus documentos
    *rutas_crud("", DISPOSITIVO, v.DispositivoViewSet, "dispositivos"),
    *rutas_crud(DISPOSITIVO + "documentos/", "<int:num_linea>/", v.DocumentoDispositivoViewSet, "documentos"),
]
