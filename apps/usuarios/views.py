from django.contrib.auth.hashers import check_password, make_password
from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.core.autenticacion import es_rol_admin, generar_token, horas_token
from apps.core.db import llamar_sp
from apps.core.permisos import Autenticado, SoloAdmin
from apps.core.viewsets import SPViewSet

from . import serializers as s

CAMPOS_USUARIO = (
    "cod_rol", "cod_tipo_auth", "cod_tipo_identificacion", "dni",
    "nombre", "apellido1", "apellido2",
    "cod_pais", "cod_provincia", "cod_canton", "cod_distrito",
    "otras_senas", "imagen_path", "cod_departamento", "usuario_red",
)


class UsuarioViewSet(SPViewSet):
    """CRUD de usuarios (sp_usr_usuarios_*).

    - Consultar: cualquier usuario con sesión. Modificar: solo administradores.
    - DELETE desactiva (eliminación lógica). Para borrar de verdad use
      DELETE /usuarios/<id>/eliminar-fisico/.
    - La clave se recibe en texto plano y se guarda como hash de Django.
    """
    sp = "sp_usr_usuarios"
    campos_pk = ("id",)
    campos_insertar = CAMPOS_USUARIO + ("password_hash",)
    campos_actualizar = CAMPOS_USUARIO + ("activo",)
    filtros_listar = ("activo", "cod_rol", "cod_departamento", "buscar")
    insertar_devuelve_codigo = True
    campos_bool = ("activo",)

    serializer_class = s.UsuarioCrearSerializer
    serializer_actualizar_class = s.UsuarioActualizarSerializer
    serializer_filtros_class = s.UsuarioFiltrosSerializer

    def get_serializer_class(self):
        if self.action == "cambiar_clave":
            return s.CambiarClaveSerializer
        if self.action == "login":
            return s.CredencialesSerializer
        return super().get_serializer_class()

    def get_permissions(self):
        if self.action == "login":
            return [AllowAny()]
        if self.action in ("yo", "cambiar_clave"):
            return [Autenticado()]
        return super().get_permissions()

    def _es_propio(self, id_usuario):
        return int(id_usuario) == self.request.user.id

    def preparar_datos(self, datos, accion):
        if accion == "insertar":
            password = datos.pop("password", None)
            datos["password_hash"] = make_password(password) if password else None

        if accion == "actualizar" and self._es_propio(self.kwargs["id"]):
            # Evita que un administrador se bloquee a sí mismo.
            if datos.get("activo") is False:
                raise ValidationError({"activo": ["No puede desactivar su propio usuario."]})
            filas, _ = llamar_sp("sp_cat_roles_usuarios_obtener", [datos["cod_rol"]])
            if filas and not es_rol_admin(filas[0]["descripcion"]):
                raise ValidationError({"cod_rol": ["No puede quitarse a sí mismo el rol de administrador."]})
        return datos

    def destroy(self, request, **kwargs):
        if self._es_propio(kwargs["id"]):
            raise ValidationError({"detail": "No puede desactivar su propio usuario."})
        return super().destroy(request, **kwargs)

    # POST /usuarios/login/  (también /usuarios/validar-credenciales/)
    def login(self, request):
        datos = self._validar(s.CredencialesSerializer, request.data)
        filas, _ = llamar_sp("sp_usr_usuarios_obtener_por_login", [datos["usuario_red"]])

        if not filas:
            make_password(datos["password"])  # mismo tiempo de respuesta exista o no el usuario
            raise AuthenticationFailed("Usuario o clave incorrectos.")

        usuario = filas[0]
        if not usuario["password_hash"]:
            raise ValidationError({"detail": "Este usuario se autentica por Active Directory."})
        if not check_password(datos["password"], usuario["password_hash"]):
            raise AuthenticationFailed("Usuario o clave incorrectos.")
        if not usuario["activo"]:
            raise PermissionDenied("El usuario está inactivo. Contacte a un administrador.")

        perfil = self.salida(usuario)
        perfil["es_admin"] = es_rol_admin(usuario["rol"])
        return Response({
            "token": generar_token(usuario["id"]),
            "expira_en_horas": horas_token(),
            "usuario": perfil,
        })

    # GET /usuarios/yo/
    def yo(self, request):
        perfil = self.salida(self._obtener([request.user.id]))
        perfil["es_admin"] = request.user.es_admin
        return Response(perfil)

    # POST /usuarios/<id>/activar/
    def activar(self, request, id):
        llamar_sp("sp_usr_usuarios_activar", [id])
        return Response(self.salida(self._obtener([id])))

    # DELETE /usuarios/<id>/eliminar-fisico/
    def eliminar_fisico(self, request, id):
        if self._es_propio(id):
            raise ValidationError({"detail": "No puede eliminar su propio usuario."})
        llamar_sp("sp_usr_usuarios_eliminar_fisico", [id])
        return Response(status=status.HTTP_204_NO_CONTENT)

    # POST /usuarios/<id>/cambiar-clave/
    # Un administrador puede cambiar la clave de cualquiera; un usuario
    # normal solo la suya y debe indicar la clave actual.
    def cambiar_clave(self, request, id):
        propio = self._es_propio(id)
        if not propio and not request.user.es_admin:
            raise PermissionDenied("Solo puede cambiar su propia clave.")

        datos = self._validar(s.CambiarClaveSerializer, request.data)
        password = datos["password"]
        self._obtener([id])  # 404 si no existe

        if propio:
            actual = datos.get("password_actual")
            if not actual:
                raise ValidationError({"password_actual": ["Indique su clave actual."]})
            filas, _ = llamar_sp("sp_usr_usuarios_obtener_por_login", [request.user.usuario_red])
            if not filas or not check_password(actual, filas[0]["password_hash"] or ""):
                raise ValidationError({"password_actual": ["La clave actual no es correcta."]})

        # Los hashes de Django llevan sal aleatoria, así que la comparación
        # contra el historial se hace aquí y no dentro del procedimiento.
        if datos["historial_bloqueo"]:
            previas, _ = llamar_sp("sp_usr_historiales_claves_listar", [id, datos["historial_bloqueo"]])
            if any(check_password(password, f["password_hash"]) for f in previas):
                raise ValidationError({"password": ["La clave ya fue utilizada recientemente."]})

        llamar_sp("sp_usr_usuarios_cambiar_clave", [id, make_password(password), 0])
        return Response({"detail": "Clave actualizada."})


class DetalleUsuarioViewSet(SPViewSet):
    """Base de las tablas de detalle: llave (id_usuario, num_linea);
    num_linea lo genera el procedimiento _insertar."""
    campos_pk = ("id_usuario", "num_linea")
    campos_padre = ("id_usuario",)
    insertar_devuelve_codigo = True


class TelefonoViewSet(DetalleUsuarioViewSet):
    sp = "sp_usr_telefonos"
    campos_insertar = ("cod_telefono", "telefono", "es_whatsapp")
    campos_actualizar = ("cod_telefono", "telefono", "es_whatsapp")
    campos_bool = ("es_whatsapp",)
    serializer_class = s.TelefonoSerializer


class CorreoViewSet(DetalleUsuarioViewSet):
    sp = "sp_usr_correos"
    campos_insertar = ("cod_correo", "correo")
    campos_actualizar = ("cod_correo", "correo")
    serializer_class = s.CorreoSerializer


class PaginaWebViewSet(DetalleUsuarioViewSet):
    sp = "sp_usr_paginas_webs"
    campos_insertar = ("url_web",)
    campos_actualizar = ("url_web",)
    serializer_class = s.PaginaWebSerializer


class HistorialClaveViewSet(DetalleUsuarioViewSet):
    """Solo administradores. El hash nunca sale en la respuesta. Para cambiar
    la clave de un usuario use /usuarios/<id>/cambiar-clave/."""
    sp = "sp_usr_historiales_claves"
    campos_insertar = ("password_hash",)
    campos_actualizar = ("password_hash",)
    filtros_listar = ("limite",)
    serializer_class = s.HistorialClaveSerializer
    serializer_filtros_class = s.HistorialClaveFiltrosSerializer
    permission_classes = [SoloAdmin]

    def preparar_datos(self, datos, accion):
        datos["password_hash"] = make_password(datos.pop("password"))
        return datos
