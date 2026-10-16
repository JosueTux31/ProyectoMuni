from rest_framework import serializers

CODIGO = {"max_length": 10}
NOMBRE = {"max_length": 100}


# ---------------------------------------------------------------- Países
class PaisSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(**CODIGO)
    nombre_pais = serializers.CharField(**NOMBRE)


class PaisActualizarSerializer(serializers.Serializer):
    nombre_pais = serializers.CharField(**NOMBRE)


# ------------------------------------------------------------ Provincias
class ProvinciaSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(**CODIGO)
    cod_provincia = serializers.CharField(**CODIGO)
    nombre_provincia = serializers.CharField(**NOMBRE)


class ProvinciaActualizarSerializer(serializers.Serializer):
    nombre_provincia = serializers.CharField(**NOMBRE)


class ProvinciaFiltrosSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(required=False, allow_null=True, **CODIGO)

00
# -------------------------------------------------------------- Cantones
class CantonSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(**CODIGO)
    cod_provincia = serializers.CharField(**CODIGO)
    cod_canton = serializers.CharField(**CODIGO)
    nombre_canton = serializers.CharField(**NOMBRE)


class CantonActualizarSerializer(serializers.Serializer):
    nombre_canton = serializers.CharField(**NOMBRE)


class CantonFiltrosSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(required=False, allow_null=True, **CODIGO)
    cod_provincia = serializers.CharField(required=False, allow_null=True, **CODIGO)


# ------------------------------------------------------------- Distritos
class DistritoSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(**CODIGO)
    cod_provincia = serializers.CharField(**CODIGO)
    cod_canton = serializers.CharField(**CODIGO)
    cod_distrito = serializers.CharField(**CODIGO)
    nombre_distrito = serializers.CharField(**NOMBRE)


class DistritoActualizarSerializer(serializers.Serializer):
    nombre_distrito = serializers.CharField(**NOMBRE)


class DistritoFiltrosSerializer(serializers.Serializer):
    cod_pais = serializers.CharField(required=False, allow_null=True, **CODIGO)
    cod_provincia = serializers.CharField(required=False, allow_null=True, **CODIGO)
    cod_canton = serializers.CharField(required=False, allow_null=True, **CODIGO)
