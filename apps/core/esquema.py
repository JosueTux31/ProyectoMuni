"""Le explica a Swagger (drf-spectacular) cómo se autentica la API,
para que el botón Authorize acepte el token del login."""
from drf_spectacular.extensions import OpenApiAuthenticationExtension


class TokenMuniEsquema(OpenApiAuthenticationExtension):
    target_class = "apps.core.autenticacion.TokenMuniAutenticacion"
    name = "TokenMuni"

    def get_security_definition(self, auto_schema):
        return {
            "type": "http",
            "scheme": "bearer",
            "description": "Token devuelto por POST /api/usuarios/login/",
        }
