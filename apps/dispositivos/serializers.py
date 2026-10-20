"""Validación de los datos que llegan a las APIs de dispositivos de red."""
import ipaddress
import re

from rest_framework import serializers

from apps.proveedores.serializers import OPCIONAL, TEXTO_OPCIONAL, normalizar_mapa

PUERTOS = {"min_value": 0, "max_value": 9999, "required": False, "allow_null": True}

_SOLO_MAC = re.compile(r"[0-9A-Fa-f:.\-\s]+")


def normalizar_mac(valor):
    """Devuelve la MAC como AA:BB:CC:DD:EE:FF, venga como venga
    (aabb.ccdd.eeff de Cisco, AA-BB-CC-DD-EE-FF de Windows, aabbccddeeff).
    Vacía = None. Lanza ValueError si no es una MAC."""
    if valor is None:
        return None
    texto = str(valor).strip()
    if not texto:
        return None
    hexa = re.sub(r"[^0-9A-Fa-f]", "", texto).upper()
    if len(hexa) != 12 or not _SOLO_MAC.fullmatch(texto):
        raise ValueError("Escriba la MAC con 12 dígitos hexadecimales, por ejemplo AA:BB:CC:DD:EE:FF, "
                         "AA-BB-CC-DD-EE-FF o aabb.ccdd.eeff.")
    return ":".join(hexa[i:i + 2] for i in range(0, 12, 2))


def normalizar_ip(valor):
    """Devuelve la IPv4 o IPv6 en su forma estándar. Vacía = None.
    Lanza ValueError si no es una dirección IP."""
    if valor is None:
        return None
    texto = str(valor).strip()
    if not texto:
        return None
    try:
        return str(ipaddress.ip_address(texto))
    except ValueError:
        raise ValueError("Escriba una dirección IPv4 (por ejemplo 192.168.1.1) o una IPv6 válida.") from None


def _texto_o_nulo(valor):
    valor = (valor or "").strip()
    return valor or None


# ------------------------------------------------------------- catálogos
class Descripcion100Serializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=100)


class MarcaSerializer(serializers.Serializer):
    tipo_disp = serializers.IntegerField()
    descripcion = serializers.CharField(max_length=100)


class MarcaFiltrosSerializer(serializers.Serializer):
    tipo_disp = serializers.IntegerField(**OPCIONAL)


class ModeloSerializer(serializers.Serializer):
    # El tipo de dispositivo sale de la marca
    id_marca = serializers.IntegerField()
    descripcion = serializers.CharField(max_length=150)


class ModeloFiltrosSerializer(serializers.Serializer):
    tipo_disp = serializers.IntegerField(**OPCIONAL)
    id_marca = serializers.IntegerField(**OPCIONAL)


class EdificioSerializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=150)
    otras_senas = serializers.CharField(**TEXTO_OPCIONAL)

    def validate_otras_senas(self, valor):
        return _texto_o_nulo(valor)


# ---------------------------------------------------------- dispositivos
class DispositivoSerializer(serializers.Serializer):
    serie = serializers.CharField(max_length=100)
    tipo_disp = serializers.IntegerField()
    id_marca = serializers.IntegerField()
    id_modelo = serializers.IntegerField(**OPCIONAL)
    cant_ptos_ethernet = serializers.IntegerField(**PUERTOS)
    cant_ptos_sfp = serializers.IntegerField(**PUERTOS)
    id_os = serializers.IntegerField(**OPCIONAL)            # vacío = N/D
    # Se acepta un enlace de Google Maps; se guarda solo "latitud,longitud".
    gps = serializers.CharField(max_length=2000, **TEXTO_OPCIONAL)
    id_edificio = serializers.IntegerField(**OPCIONAL)
    ubicacion = serializers.CharField(max_length=255, **TEXTO_OPCIONAL)
    id_proveedor = serializers.IntegerField(**OPCIONAL)
    direccion_ip = serializers.CharField(max_length=45, **TEXTO_OPCIONAL)
    direccion_mac = serializers.CharField(max_length=30, **TEXTO_OPCIONAL)

    def validate_serie(self, valor):
        valor = valor.strip()
        if not valor:
            raise serializers.ValidationError("Escriba la serie del dispositivo.")
        return valor

    def validate_gps(self, valor):
        return normalizar_mapa(valor)

    def validate_ubicacion(self, valor):
        return _texto_o_nulo(valor)

    def validate_direccion_ip(self, valor):
        try:
            return normalizar_ip(valor)
        except ValueError as e:
            raise serializers.ValidationError(str(e))

    def validate_direccion_mac(self, valor):
        try:
            return normalizar_mac(valor)
        except ValueError as e:
            raise serializers.ValidationError(str(e))


class DispositivoFiltrosSerializer(serializers.Serializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)
    tipo_disp = serializers.IntegerField(**OPCIONAL)
    id_marca = serializers.IntegerField(**OPCIONAL)
    id_edificio = serializers.IntegerField(**OPCIONAL)
    id_proveedor = serializers.IntegerField(**OPCIONAL)
    buscar = serializers.CharField(max_length=150, **TEXTO_OPCIONAL)


class HistorialSerializer(serializers.Serializer):
    limite = serializers.IntegerField(min_value=1, max_value=200, default=20)
    desplazamiento = serializers.IntegerField(min_value=0, default=0)


# ------------------------------------------------------------ documentos
class DocumentoSerializer(serializers.Serializer):
    """El archivo llega aparte, en el campo "archivo" (multipart/form-data)."""
    id_doc = serializers.IntegerField()


class DocumentoFiltrosSerializer(serializers.Serializer):
    id_doc = serializers.IntegerField(**OPCIONAL)
