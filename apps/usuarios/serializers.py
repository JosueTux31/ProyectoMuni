# serializers.py
from rest_framework import serializers
from .models import Usuario, UsuarioTelefono, UsuarioCorreo, UsuarioPaginaWeb, UsuarioHistorialClave

class UsuarioTelefonoSerializer(serializers.ModelSerializer):
    class Meta:
        model = UsuarioTelefono
        fields = ['id_usuario', 'num_linea', 'cod_telefono', 'telefono', 'es_whatsapp']
        read_only_fields = ['id_usuario', 'num_linea']

class UsuarioCorreoSerializer(serializers.ModelSerializer):
    class Meta:
        model = UsuarioCorreo
        fields = ['id_usuario', 'num_linea', 'cod_correo', 'correo']
        read_only_fields = ['id_usuario', 'num_linea']

class UsuarioPaginaWebSerializer(serializers.ModelSerializer):
    class Meta:
        model = UsuarioPaginaWeb
        fields = ['id_usuario', 'num_linea', 'url_web']
        read_only_fields = ['id_usuario', 'num_linea']

class UsuarioHistorialClaveSerializer(serializers.ModelSerializer):
    class Meta:
        model = UsuarioHistorialClave
        fields = ['id_usuario', 'num_linea', 'password_hash', 'fecha_registro']
        read_only_fields = ['id_usuario', 'num_linea', 'fecha_registro']

class UsuarioSerializer(serializers.ModelSerializer):
    telefonos = UsuarioTelefonoSerializer(many=True, required=False)
    correos = UsuarioCorreoSerializer(many=True, required=False)
    paginas_web = UsuarioPaginaWebSerializer(many=True, required=False)
    
    class Meta:
        model = Usuario
        fields = [
            'id', 'cod_rol', 'cod_tipo_auth', 'cod_tipo_identificacion', 'dni',
            'nombre', 'apellido1', 'apellido2', 'cod_pais', 'cod_provincia',
            'cod_canton', 'cod_distrito', 'otras_senas', 'imagen_path',
            'cod_departamento', 'usuario_red', 'password_hash', 'activo',
            'creado_en', 'actualizado_en', 'telefonos', 'correos', 'paginas_web'
        ]
        read_only_fields = ['id', 'creado_en', 'actualizado_en']