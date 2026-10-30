"""Validación de los datos que llegan a las APIs de equipos municipales
(antes dispositivos de red)."""
import datetime
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


class TipoDispositivoSerializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=100)
    # Categoría (decide qué datos se piden a sus equipos). Vacía al crear:
    # la que dice el nombre (LAPTOP -> computadoras) o «otros equipos»;
    # vacía al modificar: se queda la que tenía.
    id_categoria = serializers.IntegerField(min_value=1, **OPCIONAL)


class TipoFiltrosSerializer(serializers.Serializer):
    id_categoria = serializers.IntegerField(**OPCIONAL)


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


# Valores de las listas del formulario (iguales a los que acepta la base)
TECNOLOGIAS_IMPRESION = ["LÁSER", "TINTA", "TINTA CONTINUA", "TÉRMICA", "MATRIZ DE PUNTO"]
TIPOS_ALMACENAMIENTO = ["SSD", "NVME", "HDD", "EMMC"]
# Nombre en la red: como lo muestra el DHCP o Microclaudia (puede llevar espacios: «FILAS - KIOSCO»)
_NOMBRE_RED = re.compile(r"[A-Za-z0-9][A-Za-z0-9 ._-]*")
_TELEFONO = re.compile(r"\+?[0-9][0-9 -]{3,18}")


def _entero(maximo, minimo=1):
    return {"min_value": minimo, "max_value": maximo, "required": False, "allow_null": True}


def imei_valido(texto):
    """Los 15 dígitos del IMEI (sin espacios ni guiones). El último es un
    dígito verificador (Luhn), así se detecta un número mal copiado.
    Vacío = None. Lanza ValueError si no es un IMEI."""
    texto = (texto or "").strip()
    if not texto:
        return None
    digitos = re.sub(r"[\s-]", "", texto)
    if not re.fullmatch(r"[0-9]{15}", digitos):
        raise ValueError("El IMEI tiene 15 dígitos (en el celular: marque *#06#).")
    suma = 0
    for i, c in enumerate(digitos[:14]):
        n = int(c) * (2 if i % 2 else 1)
        suma += n - 9 if n > 9 else n
    if (10 - suma % 10) % 10 != int(digitos[14]):
        raise ValueError("Ese IMEI no es válido: revise que los 15 dígitos estén bien copiados.")
    return digitos


class DispositivoSerializer(serializers.Serializer):
    serie = serializers.CharField(max_length=100)
    tipo_disp = serializers.IntegerField()
    id_marca = serializers.IntegerField()
    id_modelo = serializers.IntegerField(**OPCIONAL)
    # Identificación: nombre en la red (se compara con el DHCP y
    # Microclaudia) y placa (número de activo)
    nombre_equipo = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)
    placa = serializers.CharField(max_length=50, **TEXTO_OPCIONAL)
    # Equipos de red y servidores
    cant_ptos_ethernet = serializers.IntegerField(**PUERTOS)
    cant_ptos_sfp = serializers.IntegerField(**PUERTOS)
    # Sistema operativo (vacío = N/D) y su versión o la del firmware
    id_os = serializers.IntegerField(**OPCIONAL)
    version_os = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)
    # Computadoras, servidores y móviles
    procesador = serializers.CharField(max_length=150, **TEXTO_OPCIONAL)
    memoria_gb = serializers.IntegerField(**_entero(4096))
    almacenamiento_gb = serializers.IntegerField(**_entero(1_000_000))
    tipo_almacenamiento = serializers.ChoiceField(TIPOS_ALMACENAMIENTO, **TEXTO_OPCIONAL)
    # Móviles y telefonía
    imei = serializers.CharField(max_length=30, **TEXTO_OPCIONAL)
    imei2 = serializers.CharField(max_length=30, **TEXTO_OPCIONAL)
    numero_linea = serializers.CharField(max_length=20, **TEXTO_OPCIONAL)
    operador = serializers.CharField(max_length=50, **TEXTO_OPCIONAL)
    extension = serializers.CharField(max_length=10, **TEXTO_OPCIONAL)
    # Impresión
    tecnologia_impresion = serializers.ChoiceField(TECNOLOGIAS_IMPRESION, **TEXTO_OPCIONAL)
    a_color = serializers.BooleanField(**OPCIONAL)
    consumible = serializers.CharField(max_length=100, **TEXTO_OPCIONAL)
    # Pantallas, cámaras, UPS y grabadores
    pulgadas = serializers.DecimalField(max_digits=4, decimal_places=1, min_value=1, max_value=150, **OPCIONAL)
    resolucion = serializers.CharField(max_length=20, **TEXTO_OPCIONAL)
    capacidad_va = serializers.IntegerField(**_entero(1_000_000))
    autonomia_min = serializers.IntegerField(**_entero(9999))
    canales = serializers.IntegerField(**_entero(512))
    # Ubicación, asignación y soporte
    id_predio = serializers.IntegerField(**OPCIONAL)        # edificio (su mapa es el del edificio)
    ubicacion = serializers.CharField(max_length=255, **TEXTO_OPCIONAL)
    cod_departamento = serializers.IntegerField(**OPCIONAL)
    id_asignado = serializers.IntegerField(**OPCIONAL)      # funcionario responsable
    id_proveedor = serializers.IntegerField(**OPCIONAL)
    fecha_compra = serializers.DateField(**OPCIONAL)
    garantia_hasta = serializers.DateField(**OPCIONAL)
    observaciones = serializers.CharField(max_length=500, **TEXTO_OPCIONAL)
    # Licencia de Microclaudia (la marca el administrador). Sin mandar = no cambia
    tiene_microclaudia = serializers.BooleanField(**OPCIONAL)
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

    def validate_nombre_equipo(self, valor):
        valor = re.sub(r"\s+", " ", _texto_o_nulo(valor) or "") or None
        if valor and not _NOMBRE_RED.fullmatch(valor):
            raise serializers.ValidationError(
                "El nombre en la red lleva letras, números, espacios, guion, punto o guion bajo (por ejemplo PC-FIN-01).")
        return valor

    def validate_imei(self, valor):
        try:
            return imei_valido(valor)
        except ValueError as e:
            raise serializers.ValidationError(str(e))

    validate_imei2 = validate_imei

    def validate_numero_linea(self, valor):
        valor = _texto_o_nulo(valor)
        if valor and not _TELEFONO.fullmatch(valor):
            raise serializers.ValidationError("Escriba el número de la línea con sus dígitos (por ejemplo 8888-8888).")
        return valor

    def validate_extension(self, valor):
        valor = _texto_o_nulo(valor)
        if valor and not valor.isdigit():
            raise serializers.ValidationError("La extensión lleva solo números.")
        return valor

    def validate_resolucion(self, valor):
        valor = _texto_o_nulo(valor)
        # 1920 x 1080 -> 1920X1080
        return re.sub(r"\s*[xX×]\s*", "X", valor) if valor else valor

    def validate_fecha_compra(self, valor):
        if valor and valor > datetime.date.today():
            raise serializers.ValidationError("La fecha de compra no puede ser posterior a hoy.")
        return valor

    def validate_ips(self, filas):
        return _validar_direcciones(filas, IpSerializer, "direccion_ip", "IP")

    def validate_macs(self, filas):
        return _validar_direcciones(filas, MacSerializer, "direccion_mac", "MAC", mac_con_guiones)

    def validate(self, datos):
        viejos = [c for c in CAMPOS_VIEJOS if c in (self.initial_data or {})]
        if viejos:
            raise serializers.ValidationError(MENSAJE_PAGINA_VIEJA)
        # Textos vacíos = NULL; las listas en mayúscula (la base las guarda así)
        for campo in ("placa", "version_os", "procesador", "operador", "consumible", "observaciones"):
            if campo in datos:
                datos[campo] = _texto_o_nulo(datos[campo])
        for campo in ("tipo_almacenamiento", "tecnologia_impresion"):
            if campo in datos:
                datos[campo] = datos[campo] or None
        errores = {}
        if datos.get("imei") and datos.get("imei") == datos.get("imei2"):
            errores["imei2"] = ["El segundo IMEI es igual al primero."]
        compra, garantia = datos.get("fecha_compra"), datos.get("garantia_hasta")
        if compra and garantia and garantia < compra:
            errores["garantia_hasta"] = ["La garantía no puede terminar antes de la fecha de compra."]
        if errores:
            raise serializers.ValidationError(errores)
        return datos


class DispositivoFiltrosSerializer(serializers.Serializer):
    activo = serializers.BooleanField(default=None, **OPCIONAL)
    id_categoria = serializers.IntegerField(**OPCIONAL)
    tipo_disp = serializers.IntegerField(**OPCIONAL)
    id_marca = serializers.IntegerField(**OPCIONAL)
    id_predio = serializers.IntegerField(**OPCIONAL)
    cod_departamento = serializers.IntegerField(**OPCIONAL)
    id_asignado = serializers.IntegerField(**OPCIONAL)
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
