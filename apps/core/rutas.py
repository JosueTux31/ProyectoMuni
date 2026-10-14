from django.urls import path

ACCIONES_COLECCION = {"get": "list", "post": "create"}
ACCIONES_DETALLE = {
    "get": "retrieve",
    "put": "update",
    "patch": "partial_update",
    "delete": "destroy",
}


def rutas_crud(prefijo, detalle, viewset, nombre):
    """Genera las dos rutas de un recurso:

    - ``<prefijo>``            GET (listar) / POST (insertar)
    - ``<prefijo><detalle>``   GET (obtener) / PUT / PATCH (actualizar) / DELETE (eliminar)

    ``detalle`` puede tener varios parámetros para llaves compuestas,
    p. ej. ``"<str:cod_pais>/<str:cod_provincia>/"``.
    """
    return [
        path(prefijo, viewset.as_view(ACCIONES_COLECCION), name=f"{nombre}-lista"),
        path(prefijo + detalle, viewset.as_view(ACCIONES_DETALLE), name=f"{nombre}-detalle"),
    ]
