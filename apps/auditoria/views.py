import json

from rest_framework import serializers
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.archivos import url_firmada
from apps.core.db import llamar_sp
from apps.core.permisos import Autenticado

ACCIONES = ("INSERTAR", "ACTUALIZAR", "ELIMINAR", "INICIO_SESION", "CIERRE_SESION", "INICIO_FALLIDO")


class FiltrosSerializer(serializers.Serializer):
    id_usuario = serializers.IntegerField(required=False, allow_null=True)
    id_persona = serializers.IntegerField(required=False, allow_null=True)
    tabla = serializers.RegexField(r"^[A-Za-z_]{1,64}$", required=False, allow_blank=True)   # por si algún nombre lleva mayúscula
    accion = serializers.ChoiceField(ACCIONES, required=False, allow_blank=True)
    desde = serializers.DateField(required=False, allow_null=True)
    hasta = serializers.DateField(required=False, allow_null=True)
    buscar = serializers.CharField(max_length=150, required=False, allow_blank=True)
    limite = serializers.IntegerField(min_value=1, max_value=200, default=50)
    desplazamiento = serializers.IntegerField(min_value=0, default=0)


def _json(valor):
    if valor is None or isinstance(valor, (dict, list)):
        return valor
    try:
        return json.loads(valor)
    except (TypeError, ValueError):
        return None


def _nombre(*partes):
    return " ".join(p for p in partes if p) or None


def formatear(fila):
    actor = None
    if fila["id_usuario"] is not None or fila["nombre_usuario"]:
        actor = {
            "id": fila["id_usuario"],
            # Nombre actual; si la persona ya no existe, el que tenía cuando hizo el cambio
            "nombre": _nombre(fila["actor_nombre"], fila["actor_apellido1"]) or fila["nombre_usuario"],
            "foto_url": url_firmada("usuarios", "foto", fila["id_usuario"], fila["actor_imagen_path"]),
        }
    persona = None
    if fila["id_persona"] is not None:
        persona = {
            "id": fila["id_persona"],
            "nombre": _nombre(fila["persona_nombre"], fila["persona_apellido1"], fila["persona_apellido2"]),
            "es_proveedor": bool(fila["persona_es_proveedor"]) if fila["persona_es_proveedor"] is not None else None,
        }
    return {
        "id": fila["id"],
        "fecha": fila["fecha"],
        "accion": fila["accion"],
        "tabla": fila["tabla"],
        "llave": fila["llave"],
        "descripcion": fila["descripcion"],
        "ip": fila["ip"],
        "actor": actor,
        "persona": persona,
        "antes": _json(fila["datos_antes"]),
        "despues": _json(fila["datos_despues"]),
    }


class AuditoriaView(APIView):
    """GET /api/auditoria/ — historial de cambios, del más nuevo al más viejo.

    Filtros: id_usuario (quién lo hizo), id_persona (usuario o proveedor
    afectado), tabla, accion, desde, hasta (AAAA-MM-DD), buscar, limite,
    desplazamiento. Responde {"resultados": [...], "hay_mas": true|false}.

    Un administrador ve todo. Los demás solo su propia actividad
    (id_usuario o id_persona igual a su id).
    """
    permission_classes = [Autenticado]

    def get(self, request):
        filtros = FiltrosSerializer(data=request.query_params)
        filtros.is_valid(raise_exception=True)
        f = filtros.validated_data

        if not request.user.es_admin:
            propio = request.user.id
            if f.get("id_usuario") != propio and f.get("id_persona") != propio:
                raise PermissionDenied("Solo un administrador puede ver la auditoría completa.")

        limite = f["limite"]
        filas, _ = llamar_sp("sp_aud_auditorias_listar", [
            f.get("id_usuario"), f.get("id_persona"), f.get("tabla") or None, f.get("accion") or None,
            f.get("desde"), f.get("hasta"), f.get("buscar") or None,
            limite + 1, f["desplazamiento"],  # uno de más para saber si hay otra página
        ])
        return Response({
            "resultados": [formatear(x) for x in filas[:limite]],
            "hay_mas": len(filas) > limite,
        })
