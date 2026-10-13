# serializers.py
from rest_framework import serializers
from .models import (
    TipoIdentificacion,
    RolUsuario,
    TipoAutenticacion,
    Departamento,
    TipoTelefono,
    TipoCorreo,
)

class TipoIdentificacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoIdentificacion
        fields = ['cod_tipo_identificacion', 'descripcion']
        read_only_fields = ['cod_tipo_identificacion']


class RolUsuarioSerializer(serializers.ModelSerializer):
    class Meta:
        model = RolUsuario
        fields = ['cod_rol', 'descripcion']
        read_only_fields = ['cod_rol']


class TipoAutenticacionSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoAutenticacion
        fields = ['cod_tipo_auth', 'descripcion']
        read_only_fields = ['cod_tipo_auth']


class DepartamentoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Departamento
        fields = ['cod_departamento', 'descripcion']
        read_only_fields = ['cod_departamento']


class TipoTelefonoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoTelefono
        fields = ['cod_telefono', 'descripcion']
        read_only_fields = ['cod_telefono']


class TipoCorreoSerializer(serializers.ModelSerializer):
    class Meta:
        model = TipoCorreo
        fields = ['cod_correo', 'descripcion']
        read_only_fields = ['cod_correo']