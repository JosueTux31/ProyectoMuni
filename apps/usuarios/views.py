from django.contrib.auth.hashers import check_password, make_password
from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.core import archivos
from apps.core.auditoria import fijar_usuario, registrar_evento
from apps.core.autenticacion import es_rol_admin, generar_token, horas_token
from apps.core.db import llamar_sp
from apps.core.permisos import Autenticado, SoloAdmin
from apps.core.viewsets import SPViewSet

from . import serializers as s

CAMPOS_USUARIO = (
    "cod_rol", "cod_tipo_auth", "cod_tipo_identificacion", "dni",
    "nombre", "apellido1", "apellido2",
    "cod_pais", "cod_provincia", "cod_canton", "cod_distrito",
    "otras_senas",
)
# El procedimiento de inserción recibe la ruta de la foto (siempre NULL al
# crear: la foto se sube después por /usuarios/<id>/foto/).
CAMPOS_INSERTAR = CAMPOS_USUARIO + ("imagen_path", "cod_departamento", "usuario_red", "password_hash")
CAMPOS_ACTUALIZAR = CAMPOS_USUARIO + ("cod_departamento", "usuario_red", "activo")


def _nombre(fila):
    return " ".join(p for p in (fila.get("nombre"), fila.get("apellido1"), fila.get("apellido2")) if p)


class UsuarioViewSet(archivos.ArchivosMixin, SPViewSet):
    """CRUD de usuarios (sp_personas_*).

    - Consultar: cualquier usuario con sesión. Modificar: solo administradores.
    - DELETE desactiva (eliminación lógica). Para borrar de verdad use
      DELETE /usuarios/<id>/eliminar-fisico/.
    - La clave se recibe en texto plano y se guarda como hash de Django.
    - Foto: GET/POST/DELETE /usuarios/<id>/foto/. La puede cambiar un
      administrador o la misma persona. Cada usuario trae "foto_url", un
      enlace firmado que sirve directo en un <img>.
    - El código postal lo asigna la base de datos según el distrito.
    """
    sp = "sp_personas"
    campos_pk = ("id",)
    campos_insertar = CAMPOS_INSERTAR
    campos_actualizar = CAMPOS_ACTUALIZAR
    filtros_listar = ("activo", "cod_rol", "cod_departamento", "buscar")
    insertar_devuelve_codigo = True
    campos_bool = ("activo",)

    serializer_class = s.UsuarioCrearSerializer
    serializer_actualizar_class = s.UsuarioActualizarSerializer
    serializer_filtros_class = s.UsuarioFiltrosSerializer

    recurso_archivos = "usuarios"
    tipos_archivo = {
        "foto": {
            "nombre": "foto", "carpeta": "usuarios/fotos", "campo": "imagen_path",
            "sp": "sp_personas_actualizar_imagen", "extensiones": archivos.EXT_IMAGEN,
            "ajuste_max_mb": "MUNI_MAX_MB_FOTO", "max_mb_defecto": 5,
            "en_linea": True, "firmable": True,
        },
    }

    def salida(self, fila):
        fila = super().salida(fila)
        fila["foto_url"] = archivos.url_firmada("usuarios", "foto", fila.get("id"), fila.get("imagen_path"))
        return fila

    def puede_modificar_archivo(self, request, id_registro):
        # Cada persona puede cambiar su propia foto
        return request.user.es_admin or self._es_propio(id_registro)

    def get_serializer_class(self):
        if self.action == "cambiar_clave":
            return s.CambiarClaveSerializer
        if self.action == "login":
            return s.CredencialesSerializer
        return super().get_serializer_class()

    def get_permissions(self):
        if self.action == "login":
            return [AllowAny()]
        if self.action in ("yo", "cambiar_clave", "logout", "subir", "quitar"):
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
        filas, _ = llamar_sp("sp_personas_obtener_por_login", [datos["usuario_red"]])

        def fallido(motivo, id_persona=None):
            registrar_evento("INICIO_FALLIDO", tabla="personas", llave=datos["usuario_red"],
                             id_persona=id_persona, descripcion=f"Usuario de red: {datos['usuario_red']}",
                             detalle={"motivo": motivo})

        if not filas:
            make_password(datos["password"])  # mismo tiempo de respuesta exista o no el usuario
            fallido("El usuario no existe")
            raise AuthenticationFailed("Usuario o clave incorrectos.")

        usuario = filas[0]
        if not usuario["password_hash"]:
            raise ValidationError({"detail": "Este usuario se autentica por Active Directory."})
        if not check_password(datos["password"], usuario["password_hash"]):
            fallido("Clave incorrecta", usuario["id"])
            raise AuthenticationFailed("Usuario o clave incorrectos.")
        if not usuario["activo"]:
            fallido("Usuario inactivo", usuario["id"])
            raise PermissionDenied("El usuario está inactivo. Contacte a un administrador.")

        fijar_usuario(usuario["id"], _nombre(usuario))
        registrar_evento("INICIO_SESION", tabla="personas", llave=usuario["id"],
                         id_persona=usuario["id"], descripcion=_nombre(usuario))

        perfil = self.salida(usuario)
        perfil["es_admin"] = es_rol_admin(usuario["rol"])
        return Response({
            "token": generar_token(usuario["id"]),
            "expira_en_horas": horas_token(),
            "usuario": perfil,
        })

    # POST /usuarios/logout/  (registra el cierre de sesión en la auditoría)
    def logout(self, request):
        registrar_evento("CIERRE_SESION", tabla="personas", llave=request.user.id,
                         id_persona=request.user.id, descripcion=request.user.nombre_completo)
        return Response(status=status.HTTP_204_NO_CONTENT)

    # GET /usuarios/yo/
    def yo(self, request):
        perfil = self.salida(self._obtener([request.user.id]))
        perfil["es_admin"] = request.user.es_admin
        return Response(perfil)

    # POST /usuarios/<id>/activar/
    def activar(self, request, id):
        llamar_sp("sp_personas_activar", [id])
        return Response(self.salida(self._obtener([id])))

    # DELETE /usuarios/<id>/eliminar-fisico/
    def eliminar_fisico(self, request, id):
        if self._es_propio(id):
            raise ValidationError({"detail": "No puede eliminar su propio usuario."})
        usuario = self._obtener([id])
        llamar_sp("sp_personas_eliminar_fisico", [id])
        archivos.borrar(usuario.get("imagen_path"))
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
            filas, _ = llamar_sp("sp_personas_obtener_por_login", [request.user.usuario_red])
            if not filas or not check_password(actual, filas[0]["password_hash"] or ""):
                raise ValidationError({"password_actual": ["La clave actual no es correcta."]})

        # Los hashes de Django llevan sal aleatoria, así que la comparación
        # contra el historial se hace aquí y no dentro del procedimiento.
        if datos["historial_bloqueo"]:
            previas, _ = llamar_sp("sp_usr_historiales_claves_listar", [id, datos["historial_bloqueo"]])
            if any(check_password(password, f["password_hash"]) for f in previas):
                raise ValidationError({"password": ["La clave ya fue utilizada recientemente."]})

        llamar_sp("sp_personas_cambiar_clave", [id, make_password(password), 0])
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
