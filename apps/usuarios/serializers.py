from rest_framework import serializers

OPCIONAL = {"required": False, "allow_null": True}
TEXTO_OPCIONAL = {"required": False, "allow_null": True, "allow_blank": True}


# -------------------------------------------------------------- Usuarios
class UsuarioBaseSerializer(serializers.Serializer):
    cod_rol = serializers.IntegerField()
    cod_tipo_auth = serializers.IntegerField()
    cod_tipo_identificacion = serializers.IntegerField()
    dni = serializers.CharField(max_length=30)

    nombre = serializers.CharField(max_length=150)
    apellido1 = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)
    apellido2 = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)

    cod_pais = serializers.CharField(max_length=10)
    cod_provincia = serializers.CharField(max_length=10)
    cod_canton = serializers.CharField(max_length=10)
    cod_distrito = serializers.CharField(max_length=10)
    otras_senas = serializers.CharField(**TEXTO_OPCIONAL)
    # La foto se sube aparte en /usuarios/<id>/foto/

    cod_departamento = serializers.IntegerField(**OPCIONAL)
    # Sin allow_blank: la columna es UNIQUE y dos '' chocarían; use null.
    usuario_red = serializers.CharField(max_length=50, **OPCIONAL)


class UsuarioCrearSerializer(UsuarioBaseSerializer):
    # Se recibe la clave en texto plano y el servidor guarda el hash.
    # Omitirla (o null) para usuarios que se autentican por Active Directory.
    password = serializers.CharField(write_only=True, min_length=8, max_length=128,
                                     trim_whitespace=False, style={"input_type": "password"},
                                     **OPCIONAL)


class UsuarioActualizarSerializer(UsuarioBaseSerializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)


class UsuarioFiltrosSerializer(serializers.Serializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)
    cod_rol = serializers.IntegerField(**OPCIONAL)
    cod_departamento = serializers.IntegerField(**OPCIONAL)
    buscar = serializers.CharField(max_length=150, **TEXTO_OPCIONAL)


class CambiarClaveSerializer(serializers.Serializer):
    # Obligatoria cuando el usuario cambia su propia clave
    password_actual = serializers.CharField(max_length=128, trim_whitespace=False,
                                            style={"input_type": "password"}, **TEXTO_OPCIONAL)
    password = serializers.CharField(min_length=8, max_length=128, trim_whitespace=False,
                                     style={"input_type": "password"})
    # Cuántas claves anteriores no se pueden reutilizar (0 = sin validar)
    historial_bloqueo = serializers.IntegerField(min_value=0, max_value=50, default=5)


class CredencialesSerializer(serializers.Serializer):
    usuario_red = serializers.CharField(max_length=50)
    password = serializers.CharField(max_length=128, trim_whitespace=False,
                                     style={"input_type": "password"})


# ------------------------------------------------------------- Detalles
class TelefonoSerializer(serializers.Serializer):
    cod_telefono = serializers.IntegerField()
    telefono = serializers.CharField(max_length=25)
    es_whatsapp = serializers.BooleanField(required=False, default=False)


class CorreoSerializer(serializers.Serializer):
    cod_correo = serializers.IntegerField()
    correo = serializers.EmailField(max_length=150)


class PaginaWebSerializer(serializers.Serializer):
    url_web = serializers.URLField(max_length=255)


class HistorialClaveSerializer(serializers.Serializer):
    password = serializers.CharField(write_only=True, min_length=8, max_length=128,
                                     trim_whitespace=False, style={"input_type": "password"})


class HistorialClaveFiltrosSerializer(serializers.Serializer):
    limite = serializers.IntegerField(min_value=1, **OPCIONAL)
