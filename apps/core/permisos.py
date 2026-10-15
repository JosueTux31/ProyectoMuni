from rest_framework.permissions import SAFE_METHODS, BasePermission


def _autenticado(request):
    return bool(request.user and getattr(request.user, "is_authenticated", False))


class EsAdminOSoloLectura(BasePermission):
    """Cualquier usuario con sesión puede consultar (GET);
    solo un administrador puede crear, modificar o eliminar."""

    message = "Solo un administrador puede modificar datos."

    def has_permission(self, request, view):
        if not _autenticado(request):
            return False
        if request.method in SAFE_METHODS:
            return True
        return getattr(request.user, "es_admin", False)


class SoloAdmin(BasePermission):
    message = "Solo un administrador puede acceder a esta información."

    def has_permission(self, request, view):
        return _autenticado(request) and getattr(request.user, "es_admin", False)


class Autenticado(BasePermission):
    message = "Debe iniciar sesión."

    def has_permission(self, request, view):
        return _autenticado(request)
