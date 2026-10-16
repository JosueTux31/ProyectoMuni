"""Ejecución de procedimientos almacenados de MariaDB.

Todas las APIs pasan por aquí: ninguna vista escribe SQL contra las tablas.
"""
import re

from django.db import connection

from .auditoria import contexto_actual

_NOMBRE_SP_VALIDO = re.compile(r"^sp_[a-z0-9_]+$")


def llamar_sp(nombre, params=(), con_salida=False):
    """Ejecuta ``CALL nombre(params[, @sp_salida])``.

    - ``params``: valores IN en el mismo orden que la firma del procedimiento.
    - ``con_salida``: True si el procedimiento tiene un último parámetro OUT
      (por ejemplo el código generado en ``_insertar``).

    Antes de cada llamada fija @muni_usuario_id, @muni_usuario_nombre y
    @muni_ip, que usan los disparadores de auditoría.

    Devuelve ``(filas, salida)``: ``filas`` es una lista de diccionarios con
    el primer conjunto de resultados (vacía si el SP no hace SELECT) y
    ``salida`` el valor del parámetro OUT (o None).
    """
    if not _NOMBRE_SP_VALIDO.match(nombre):
        raise ValueError(f"Nombre de procedimiento inválido: {nombre!r}")

    params = list(params)
    marcadores = ["%s"] * len(params)
    if con_salida:
        marcadores.append("@sp_salida")

    ctx = contexto_actual()
    filas = []
    salida = None
    with connection.cursor() as cursor:
        cursor.execute(
            "SET @muni_usuario_id = %s, @muni_usuario_nombre = %s, @muni_ip = %s",
            [ctx.usuario_id, ctx.usuario_nombre, ctx.ip],
        )
        cursor.execute(f"CALL {nombre}({', '.join(marcadores)})", params)

        # Un CALL devuelve uno o más conjuntos de resultados; hay que
        # consumirlos todos antes de ejecutar otra sentencia en la conexión
        # (si no, MariaDB responde "Commands out of sync").
        primer_conjunto = True
        while True:
            if cursor.description:
                registros = cursor.fetchall()
                if primer_conjunto:
                    columnas = [col[0] for col in cursor.description]
                    filas = [dict(zip(columnas, fila)) for fila in registros]
                    primer_conjunto = False
            if not cursor.nextset():
                break

        if con_salida:
            cursor.execute("SELECT @sp_salida")
            salida = cursor.fetchone()[0]

    return filas, salida
