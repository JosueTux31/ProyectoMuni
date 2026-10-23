"""Validación de los datos que llegan a las APIs de dispositivos de red."""
import ipaddress
import re

from rest_framework import serializers

from apps.proveedores.serializers import OPCIONAL, TEXTO_OPCIONAL, normalizar_mapa

PUERTOS = {"min_value": 0, "max_value": 9999, "required": False, "allow_null": True}

_SOLO_MAC = re.compile(r"[0-9A-Fa-f:.\-\s]+")


def normalizar_mac(valor):
    """Devuelve la MAC entera, sin separadores (AABBCCDDEEFF), venga como
    venga: aabb.ccdd.eeff de Cisco, AA-BB-CC-DD-EE-FF de Windows,
    AA:BB:CC:DD:EE:FF... La página la muestra con guiones.
    Vacía = None. Lanza ValueError si no es una MAC."""
    if valor is None:
        return None
    texto = str(valor).strip()
    if not texto:
        return None
    hexa = re.sub(r"[^0-9A-Fa-f]", "", texto).upper()
    if len(hexa) != 12 or not _SOLO_MAC.fullmatch(texto):
        raise ValueError("Escriba la MAC con 12 dígitos hexadecimales, por ejemplo AA-BB-CC-DD-EE-FF, "
                         "AA:BB:CC:DD:EE:FF o aabb.ccdd.eeff.")
    return hexa


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
    # Coordenadas del edificio para el mapa. Se acepta un enlace de Google
    # Maps; se guarda solo "latitud,longitud".
    gps = serializers.CharField(max_length=2000, **TEXTO_OPCIONAL)

    def validate_otras_senas(self, valor):
        return _texto_o_nulo(valor)

    def validate_gps(self, valor):
        return normalizar_mapa(valor)


# ---------------------------------------------------------- dispositivos
MAX_DIRECCIONES = 50   # IP o MAC por dispositivo

# Campos que mandaba la página de versiones anteriores. Si llegan, el
# navegador tiene guardada una página vieja: se rechaza en vez de perder
# en silencio las IP, MAC o coordenadas que el usuario escribió.
CAMPOS_VIEJOS = ("direccion_ip", "direccion_mac", "gps", "id_edificio")
MENSAJE_PAGINA_VIEJA = (
    "Esta página es de una versión anterior del sistema y sus datos no se guardaron. "
    "Recargue la página con Ctrl+Shift+R (o Ctrl+F5) y vuelva a guardar. Las IP y MAC "
    "van en la sección Direcciones de red y las coordenadas se ponen en el edificio."
)


def _validar_direcciones(filas, clase, campo, nombre, mostrar=str):
    """Valida la lista de IP o MAC que llega con el dispositivo:
    [{"num_linea": 1, "direccion_ip": "...", "interfaz": "LAN"}, {...}].
    num_linea va en las que ya existían (se modifican); las que no lo
    traen se agregan y las que no vienen se borran. Devuelve la lista
    normalizada o lanza los errores por fila, igual que DRF."""
    if filas is None:
        return None
    if len(filas) > MAX_DIRECCIONES:
        raise serializers.ValidationError(f"Máximo {MAX_DIRECCIONES} direcciones {nombre} por dispositivo.")
    limpias, errores, vistas = [], [], set()
    for fila in filas:
        error = {}
        validador = clase(data=fila)
        if validador.is_valid():
            dato = dict(validador.validated_data)
        else:
            dato, error = {}, dict(validador.errors)
        num_linea = fila.get("num_linea")
        if num_linea not in (None, ""):
            try:
                num_linea = int(num_linea)
                if num_linea < 1:
                    raise ValueError
            except (TypeError, ValueError):
                error["num_linea"] = ["Número de línea inválido."]
        else:
            num_linea = None
        valor = dato.get(campo)
        if valor is not None:
            if valor in vistas:
                error[campo] = [f"La {nombre} {mostrar(valor)} está repetida."]
            vistas.add(valor)
        errores.append(error)
        limpias.append({"num_linea": num_linea, **dato})
    if any(errores):
        raise serializers.ValidationError(errores)
    return limpias


def mac_con_guiones(mac):
    return "-".join(mac[i:i + 2] for i in range(0, 12, 2)) if mac and len(mac) == 12 else mac


class DispositivoSerializer(serializers.Serializer):
    serie = serializers.CharField(max_length=100)
    tipo_disp = serializers.IntegerField()
    id_marca = serializers.IntegerField()
    id_modelo = serializers.IntegerField(**OPCIONAL)
    cant_ptos_ethernet = serializers.IntegerField(**PUERTOS)
    cant_ptos_sfp = serializers.IntegerField(**PUERTOS)
    id_os = serializers.IntegerField(**OPCIONAL)            # vacío = N/D
    id_predio = serializers.IntegerField(**OPCIONAL)        # edificio (su mapa es el del edificio)
    ubicacion = serializers.CharField(max_length=255, **TEXTO_OPCIONAL)
    id_proveedor = serializers.IntegerField(**OPCIONAL)
    # Todas las IP y MAC del dispositivo; se guardan junto con él. Si no
    # vienen (o vienen en null) no se tocan las que ya tiene.
    ips = serializers.ListField(child=serializers.DictField(), required=False, allow_null=True)
    macs = serializers.ListField(child=serializers.DictField(), required=False, allow_null=True)

    def validate_serie(self, valor):
        valor = valor.strip()
        if not valor:
            raise serializers.ValidationError("Escriba la serie del dispositivo.")
        return valor

    def validate_ubicacion(self, valor):
        return _texto_o_nulo(valor)

    def validate_ips(self, filas):
        return _validar_direcciones(filas, IpSerializer, "direccion_ip", "IP")

    def validate_macs(self, filas):
        return _validar_direcciones(filas, MacSerializer, "direccion_mac", "MAC", mac_con_guiones)

    def validate(self, datos):
        viejos = [c for c in CAMPOS_VIEJOS if c in (self.initial_data or {})]
        if viejos:
            raise serializers.ValidationError(MENSAJE_PAGINA_VIEJA)
        return datos


class DispositivoFiltrosSerializer(serializers.Serializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)
    tipo_disp = serializers.IntegerField(**OPCIONAL)
    id_marca = serializers.IntegerField(**OPCIONAL)
    id_predio = serializers.IntegerField(**OPCIONAL)
    id_proveedor = serializers.IntegerField(**OPCIONAL)
    buscar = serializers.CharField(max_length=150, **TEXTO_OPCIONAL)


class HistorialSerializer(serializers.Serializer):
    limite = serializers.IntegerField(min_value=1, max_value=200, default=20)
    desplazamiento = serializers.IntegerField(min_value=0, default=0)


# ------------------------------------------------- direcciones IP y MAC
class IpSerializer(serializers.Serializer):
    direccion_ip = serializers.CharField(max_length=45)
    interfaz = serializers.CharField(max_length=50, **TEXTO_OPCIONAL)   # WAN, LAN, GESTIÓN...

    def validate_direccion_ip(self, valor):
        try:
            ip = normalizar_ip(valor)
        except ValueError as e:
            raise serializers.ValidationError(str(e))
        if ip is None:
            raise serializers.ValidationError("Escriba la dirección IP.")
        return ip

    def validate_interfaz(self, valor):
        return _texto_o_nulo(valor)


class MacSerializer(serializers.Serializer):
    # Se acepta con o sin separadores; se guarda entera (AABBCCDDEEFF)
    direccion_mac = serializers.CharField(max_length=30)
    interfaz = serializers.CharField(max_length=50, **TEXTO_OPCIONAL)

    def validate_direccion_mac(self, valor):
        try:
            mac = normalizar_mac(valor)
        except ValueError as e:
            raise serializers.ValidationError(str(e))
        if mac is None:
            raise serializers.ValidationError("Escriba la dirección MAC.")
        return mac

    def validate_interfaz(self, valor):
        return _texto_o_nulo(valor)


# ------------------------------------------------------------ documentos
class DocumentoSerializer(serializers.Serializer):
    """El archivo llega aparte, en el campo "archivo" (multipart/form-data)."""
    id_doc = serializers.IntegerField()


class DocumentoFiltrosSerializer(serializers.Serializer):
    id_doc = serializers.IntegerField(**OPCIONAL)
