from django.urls import path

from . import views as v

app_name = "logs"

IMPORTACION = v.ImportacionViewSet
EVENTO = v.EventoViewSet
ANALISIS = v.AnalisisViewSet

urlpatterns = [
    # Importaciones (cada archivo importado)
    path("importaciones/sophos/", IMPORTACION.as_view({"post": "importar"}), {"fuente": "SOPHOS"},
         name="importar-sophos"),
    path("importaciones/microclaudia/", IMPORTACION.as_view({"post": "importar"}), {"fuente": "MICROCLAUDIA"},
         name="importar-microclaudia"),
    path("importaciones/dhcp/", IMPORTACION.as_view({"post": "importar"}), {"fuente": "DHCP"},
         name="importar-dhcp"),
    path("importaciones/", IMPORTACION.as_view({"get": "list"}), name="importaciones-lista"),
    path("importaciones/<int:id_importacion>/",
         IMPORTACION.as_view({"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}),
         name="importaciones-detalle"),

    # Eventos
    path("eventos/", EVENTO.as_view({"get": "list"}), name="eventos-lista"),
    path("eventos/tablero/", EVENTO.as_view({"get": "tablero"}), name="eventos-tablero"),
    path("eventos/top/", EVENTO.as_view({"get": "top"}), name="eventos-top"),
    path("eventos/exportar/", EVENTO.as_view({"get": "exportar"}), name="eventos-exportar"),
    path("eventos/<int:id_evento>/", EVENTO.as_view({"get": "retrieve"}), name="eventos-detalle"),

    # Filtro, campos, comparación e inventario
    path("filtro/", ANALISIS.as_view({"get": "validar"}), name="filtro"),
    path("campos/", ANALISIS.as_view({"get": "campos"}), name="campos"),
    path("comparar/", ANALISIS.as_view({"post": "comparar"}), name="comparar"),
    path("inventario/", ANALISIS.as_view({"get": "inventario"}), name="inventario"),

    # Agente de Microclaudia: tablero del listado y cobertura
    path("agentes/", ANALISIS.as_view({"get": "agentes"}), name="agentes"),
    path("cobertura/", ANALISIS.as_view({"get": "cobertura"}), name="cobertura"),

    # DHCP: concesiones comparadas por MAC con el inventario (intrusos en la red)
    path("intrusos/", ANALISIS.as_view({"get": "intrusos"}), name="intrusos"),

    # Control de licencias de Microclaudia (inventario contra el listado y el check de cada equipo)
    path("licencias/", ANALISIS.as_view({"get": "licencias"}), name="licencias"),

    # Un equipo del inventario en la red: DHCP, Microclaudia y Sophos (su ficha, pestaña «En la red»)
    path("equipos/<int:id_disp>/", ANALISIS.as_view({"get": "equipo"}), name="equipo-en-la-red"),

    # Alias de los campos de cada programa
    path("mapeo/", v.MapeoViewSet.as_view({"get": "list", "post": "create"}), name="mapeo-lista"),
    path("mapeo/<str:fuente>/<str:campo_origen>/",
         v.MapeoViewSet.as_view({"get": "retrieve", "put": "update", "delete": "destroy"}), name="mapeo-detalle"),
]
