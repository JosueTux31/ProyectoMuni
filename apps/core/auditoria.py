"""Contexto de auditoría: quién hace cada petición y desde qué IP.

Los disparadores de MariaDB guardan en aud_auditorias los valores de las
variables @muni_usuario_id, @muni_usuario_nombre y @muni_ip. Django las
fija antes de cada procedimiento (ver core/db.py) con lo que hay aquí:

- El middleware abre un contexto por petición con la IP del cliente.
- La autenticación por token completa el usuario.
"""
import contextvars
import logging
from dataclasses import dataclass

from django.conf import settings
from django.db import DatabaseError

logger = logging.getLogger(__name__)


@dataclass
class Contexto:
    usuario_id: int | None = None
    usuario_nombre: str | None = None
    ip: str | None = None


_contexto: contextvars.ContextVar[Contexto | None] = contextvars.ContextVar("muni_auditoria", default=None)


def contexto_actual():
    """Contexto de la petición en curso (vacío fuera de una petición, p. ej. comandos)."""
    return _contexto.get() or Contexto()


def fijar_usuario(usuario_id, usuario_nombre):
    ctx = _contexto.get()
    if ctx is not None:
        ctx.usuario_id = usuario_id
        ctx.usuario_nombre = usuario_nombre


def ip_cliente(request):
    if getattr(settings, "MUNI_PROXY_CONFIABLE", False):
        reenviada = request.META.get("HTTP_X_FORWARDED_FOR", "")
        if reenviada:
            return reenviada.split(",")[0].strip()[:45]
    return (request.META.get("REMOTE_ADDR") or "")[:45] or None


class ContextoAuditoriaMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        token = _contexto.set(Contexto(ip=ip_cliente(request)))
        try:
            return self.get_response(request)
        finally:
            _contexto.reset(token)


def registrar_evento(accion, *, tabla=None, llave=None, id_persona=None, descripcion=None, detalle=None):
    """Registra un evento que no es un cambio de tabla (inicio de sesión, etc.).
    Si la auditoría no está instalada todavía, solo deja un aviso en el log."""
    import json

    from .db import llamar_sp

    try:
        llamar_sp("sp_aud_auditorias_registrar", [
            accion, tabla, None if llave is None else str(llave), id_persona, descripcion,
            json.dumps(detalle, ensure_ascii=False) if detalle else None,
        ])
    except DatabaseError:
        logger.warning("No se pudo registrar el evento de auditoría %s", accion, exc_info=True)
