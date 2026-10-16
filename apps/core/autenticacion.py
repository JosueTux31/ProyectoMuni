"""Inicio de sesión con los usuarios de usr_usuarios.

Al hacer login, la API entrega un token firmado con SECRET_KEY (no se
guarda en ninguna tabla). Cada petición lo envía en el encabezado
``Authorization: Bearer <token>``; aquí se verifica la firma, la
vigencia y que el usuario siga existiendo y activo.
"""
from django.conf import settings
from django.core import signing
from rest_framework import authentication, exceptions

from .auditoria import fijar_usuario
from .db import llamar_sp

SAL_TOKEN = "muni.api.token"


def horas_token():
    return getattr(settings, "MUNI_TOKEN_HORAS", 8)


def roles_admin():
    """Descripciones de cat_roles_usuarios que se consideran administrador."""
    return {r.strip().lower() for r in getattr(settings, "MUNI_ROLES_ADMIN", ["administrador"])}


def es_rol_admin(descripcion_rol):
    return (descripcion_rol or "").strip().lower() in roles_admin()


def generar_token(id_usuario):
    return signing.dumps({"uid": id_usuario}, salt=SAL_TOKEN, compress=True)


class UsuarioSesion:
    """Usuario autenticado disponible en ``request.user`` dentro de las vistas."""

    is_authenticated = True
    is_anonymous = False

    def __init__(self, fila):
        self.id = fila["id"]
        self.usuario_red = fila.get("usuario_red")
        self.nombre = fila.get("nombre")
        self.apellido1 = fila.get("apellido1")
        self.apellido2 = fila.get("apellido2")
        self.cod_rol = fila.get("cod_rol")
        self.rol = fila.get("rol")
        self.es_admin = es_rol_admin(self.rol)

    @property
    def nombre_completo(self):
        return " ".join(p for p in (self.nombre, self.apellido1, self.apellido2) if p)

    def __str__(self):
        return self.usuario_red or str(self.id)


class TokenMuniAutenticacion(authentication.BaseAuthentication):
    def authenticate(self, request):
        partes = authentication.get_authorization_header(request).split()
        if not partes or partes[0].lower() != b"bearer":
            return None
        if len(partes) != 2:
            raise exceptions.AuthenticationFailed("Encabezado Authorization inválido.")

        token = partes[1].decode()
        try:
            datos = signing.loads(token, salt=SAL_TOKEN, max_age=horas_token() * 3600)
        except signing.SignatureExpired:
            raise exceptions.AuthenticationFailed("La sesión expiró. Inicie sesión de nuevo.")
        except signing.BadSignature:
            raise exceptions.AuthenticationFailed("Sesión inválida. Inicie sesión de nuevo.")

        filas, _ = llamar_sp("sp_usr_usuarios_obtener", [datos.get("uid")])
        if not filas or not filas[0]["activo"]:
            raise exceptions.AuthenticationFailed("El usuario no existe o está inactivo.")

        usuario = UsuarioSesion(filas[0])
        # A partir de aquí cada cambio queda auditado a nombre de este usuario
        fijar_usuario(usuario.id, usuario.nombre_completo)
        return usuario, token

    def authenticate_header(self, request):
        # Hace que DRF responda 401 (no 403) cuando falta la sesión.
        return 'Bearer realm="api"'
