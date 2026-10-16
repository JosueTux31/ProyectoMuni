import re
from urllib.parse import unquote

from rest_framework import serializers

OPCIONAL = {"required": False, "allow_null": True}
TEXTO_OPCIONAL = {"required": False, "allow_null": True, "allow_blank": True}

_PAR = r"(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)"


def normalizar_mapa(valor):
    """Convierte la ubicación a "latitud,longitud".

    Acepta las coordenadas como las copia Google Maps ("10.07321, -84.31165")
    o un enlace de Google Maps que las incluya (.../@10.07,-84.31,17z o ?q=10.07,-84.31).
    """
    if valor is None:
        return None
    texto = valor.strip()
    if not texto:
        return None

    if re.match(r"https?://", texto, re.IGNORECASE):
        m = re.search(r"(?:@|[?&](?:q|query|ll|center|destination)=)" + _PAR, unquote(texto))
    else:
        m = re.fullmatch(_PAR, texto)
    if not m:
        raise serializers.ValidationError(
            "Escriba latitud y longitud separadas por coma (por ejemplo 10.0732, -84.3116) "
            "o pegue un enlace de Google Maps que las incluya.")

    lat, lng = float(m.group(1)), float(m.group(2))
    if not (-90 <= lat <= 90 and -180 <= lng <= 180):
        raise serializers.ValidationError("La latitud va de -90 a 90 y la longitud de -180 a 180.")
    return f"{round(lat, 6)},{round(lng, 6)}"


class ProveedorSerializer(serializers.Serializer):
    cod_tipo_identificacion = serializers.IntegerField()
    dni = serializers.CharField(max_length=30)

    # Persona física: nombre y apellidos. Empresa: razón social en "nombre".
    nombre = serializers.CharField(max_length=150)
    apellido1 = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)
    apellido2 = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)

    cod_categoria = serializers.IntegerField()

    cod_pais = serializers.CharField(max_length=10)
    cod_provincia = serializers.CharField(max_length=10)
    cod_canton = serializers.CharField(max_length=10)
    cod_distrito = serializers.CharField(max_length=10)
    otras_senas = serializers.CharField(**TEXTO_OPCIONAL)
    # Se acepta un enlace largo; se guarda solo "latitud,longitud".
    mapa = serializers.CharField(max_length=2000, **TEXTO_OPCIONAL)

    def validate_mapa(self, valor):
        return normalizar_mapa(valor)


class ProveedorActualizarSerializer(ProveedorSerializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)


class ProveedorFiltrosSerializer(serializers.Serializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)
    cod_categoria = serializers.IntegerField(**OPCIONAL)
    buscar = serializers.CharField(max_length=150, **TEXTO_OPCIONAL)
