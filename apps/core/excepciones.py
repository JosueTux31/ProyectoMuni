"""Traduce los errores de MariaDB a respuestas HTTP claras."""
import logging

from django.db import DatabaseError
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger(__name__)

# Códigos de error de MariaDB/MySQL
ERR_SIGNAL = 1644            # SIGNAL SQLSTATE '45000' lanzado por los procedimientos
ERR_DUPLICADO = 1062         # Llave primaria o UNIQUE repetida
ERR_FK_EN_USO = 1451         # No se puede borrar: hay registros que lo referencian
ERR_FK_NO_EXISTE = 1452      # Se referencia un código que no existe
ERR_DATOS_INVALIDOS = {1048, 1406, 1366, 1292}  # NULL, texto muy largo, tipo, fecha
ERR_CHECK = {4025, 3819}     # Regla CHECK no cumplida (MariaDB, MySQL)
# La base no tiene la misma versión que el sistema: falta un procedimiento,
# tiene otros parámetros o falta una tabla o columna.
ERR_BASE_DESACTUALIZADA = {1305, 1318, 1054, 1146}
ERR_REGEXP = 1139           # Expresión regular inválida (filtro "matches" de los logs)


def _codigo_y_mensaje(exc):
    args = getattr(exc, "args", ())
    if len(args) >= 2 and isinstance(args[0], int):
        return args[0], str(args[1])
    return None, str(exc)


def manejador_excepciones(exc, context):
    if not isinstance(exc, DatabaseError):
        return exception_handler(exc, context)

    codigo, mensaje = _codigo_y_mensaje(exc)

    if codigo == ERR_SIGNAL:
        estado = status.HTTP_404_NOT_FOUND if "no existe" in mensaje.lower() else status.HTTP_400_BAD_REQUEST
        return Response({"detail": mensaje}, status=estado)
    if codigo == ERR_DUPLICADO:
        return Response({"detail": "Ya existe un registro con esos datos.", "db": mensaje},
                        status=status.HTTP_409_CONFLICT)
    if codigo == ERR_FK_EN_USO:
        return Response({"detail": "No se puede eliminar: tiene registros relacionados."},
                        status=status.HTTP_409_CONFLICT)
    if codigo == ERR_FK_NO_EXISTE:
        return Response({"detail": "Uno de los códigos referenciados no existe.", "db": mensaje},
                        status=status.HTTP_400_BAD_REQUEST)
    if codigo in ERR_CHECK:
        return Response({"detail": "Los datos no cumplen las reglas del registro "
                                   "(por ejemplo, un proveedor debe tener categoría).", "db": mensaje},
                        status=status.HTTP_400_BAD_REQUEST)
    if codigo in ERR_DATOS_INVALIDOS:
        return Response({"detail": "Datos inválidos.", "db": mensaje},
                        status=status.HTTP_400_BAD_REQUEST)
    if codigo == ERR_REGEXP:
        return Response({"detail": "La expresión regular del filtro no es válida.", "db": mensaje},
                        status=status.HTTP_400_BAD_REQUEST)
    if codigo in ERR_BASE_DESACTUALIZADA:
        logger.error("La base de datos no está al día: %s", mensaje)
        return Response({"detail": "La base de datos no tiene la versión más reciente de las tablas o "
                                   "procedimientos. Ejecute de nuevo los scripts .sql del módulo y "
                                   f"reinicie Django. Detalle: {mensaje}", "db": mensaje},
                        status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    logger.exception("Error de base de datos no controlado")
    return Response({"detail": "Error interno de base de datos."},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR)
