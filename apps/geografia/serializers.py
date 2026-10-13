from rest_framework import serializers
from .models import Pais, Provincia, Canton, Distrito

class PaisSerializer(serializers.ModelSerializer):
    class Meta:
        model = Pais
        fields = ['cod_pais', 'nombre_pais']

class ProvinciaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Provincia
        fields = ['cod_pais', 'cod_provincia', 'nombre_provincia']

class CantonSerializer(serializers.ModelSerializer):
    class Meta:
        model = Canton
        fields = ['cod_pais', 'cod_provincia', 'cod_canton', 'nombre_canton']

class DistritoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Distrito
        fields = ['cod_pais', 'cod_provincia', 'cod_canton', 'cod_distrito', 'nombre_distrito']