"""APIs del módulo de equipos municipales (antes dispositivos de red): equipos
de red, computadoras, servidores, móviles, telefonía, impresión, pantallas,
UPS, cámaras... en la tabla equipos (modelo de datos de la especificación
«2 - Sistema - Tablas»). Las respuestas conservan los nombres que usa la
página (id_disp, tipo_disp, placa...), aunque las columnas se llamen id,
tipo_equipo, placa_equipo...

Igual que el resto del sistema: cada recurso llama a sus procedimientos
almacenados sp_<tabla>_listar / _obtener / _insertar / _actualizar /
_eliminar por medio de SPViewSet. Consultar: cualquier usuario con sesión.
Crear, modificar y eliminar: solo administradores.
"""
import json
import mimetypes
import os
import re
import uuid
from pathlib import Path

from django.conf import settings
from django.core.exceptions import SuspiciousFileOperation
from django.http import FileResponse, HttpResponse
from django.utils.text import slugify
from rest_framework import status
from rest_framework.exceptions import NotAuthenticated, NotFound, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from apps.auditoria.views import formatear
from apps.catalogos.serializers import Descripcion50Serializer, Descripcion150Serializer
from apps.catalogos.views import CatalogoViewSet
from apps.core import archivos
from apps.core.db import llamar_sp
from apps.core.permisos import SoloAdmin
from apps.core.viewsets import SPViewSet

from . import serializers as s


# =====================================================================
# Catálogos del módulo
# =====================================================================
class CategoriaDispositivoViewSet(SPViewSet):
    """Categorías de equipo (sp_categoria_equipos_*): equipos de red,
    computadoras, servidores, móviles, telefonía, impresión... Son fijas
    (la página sabe qué datos pide cada una): solo se consultan.
    lleva_agente: se espera que sus equipos tengan el agente de Microclaudia."""
    sp = "sp_categoria_equipos"
    campos_pk = ("id_categoria",)
    campos_bool = ("lleva_agente",)


class TipoDispositivoViewSet(SPViewSet):
    """Modem, firewall, laptop, impresora, celular... (sp_tipo_equipos_*).
    Cada tipo es de una categoría (id_categoria). Al crear sin categoría se
    toma la que dice el nombre (LAPTOP -> computadoras) o «otros equipos».
    GET /tipos/?id_categoria=2 lista solo los de esa categoría."""
    sp = "sp_tipo_equipos"
    campos_pk = ("tipo_disp",)
    campos_insertar = ("descripcion", "id_categoria")
    campos_actualizar = ("descripcion", "id_categoria")
    filtros_listar = ("id_categoria",)
    insertar_devuelve_codigo = True
    campos_bool = ("lleva_agente",)
    serializer_class = s.TipoDispositivoSerializer
    serializer_filtros_class = s.TipoFiltrosSerializer


class SistemaOperativoViewSet(CatalogoViewSet):
    """N/D, Linux, Windows... (sp_sis_operativos_*)."""
    sp = "sp_sis_operativos"
    campos_pk = ("id_os",)
    serializer_class = s.Descripcion100Serializer


class TipoDocumentoViewSet(CatalogoViewSet):
    """Tipos de archivo: manual, garantía, soporte, configuración, backup,
    nota... (tabla tipo_archivos, sp_tipo_archivos_*)."""
    sp = "sp_tipo_archivos"
    campos_pk = ("id_doc",)
    serializer_class = s.Descripcion100Serializer


class ProcesadorViewSet(CatalogoViewSet):
    """Tabla catálogo procesadores (sp_procesadores_*)."""
    sp = "sp_procesadores"
    campos_pk = ("id_proc",)
    serializer_class = Descripcion150Serializer


class FirmwareViewSet(CatalogoViewSet):
    """Tabla catálogo firmwares: versión del sistema o firmware (sp_firmwares_*).
    El 1 (N/D) lo usa el sistema."""
    sp = "sp_firmwares"
    campos_pk = ("id_firmw",)
    serializer_class = s.Descripcion100Serializer


class EstadoEquipoViewSet(CatalogoViewSet):
    """Tabla catálogo estado_equipos (sp_estado_equipos_*): N/D, ACTIVO e
    INACTIVO los usa el sistema (dar de baja y activar)."""
    sp = "sp_estado_equipos"
    campos_pk = ("id_estado",)
    serializer_class = Descripcion50Serializer


class TipoRolViewSet(CatalogoViewSet):
    """Tabla catálogo tipo_roles: roles de un servidor (sp_tipo_roles_*)."""
    sp = "sp_tipo_roles"
    campos_pk = ("id_rol",)
    serializer_class = s.Descripcion100Serializer


class TipoHerramientaViewSet(CatalogoViewSet):
    """Tabla catálogo tipo_herramientas (sp_tipo_herramientas_*). La 3,
    MICROCLAUDIA, la usa el sistema para compararla con su listado."""
    sp = "sp_tipo_herramientas"
    campos_pk = ("id_herram",)
    serializer_class = s.Descripcion100Serializer


class MarcaViewSet(SPViewSet):
    """Marcas, cada una de un tipo de dispositivo (sp_marcas_*).
    GET /marcas/?tipo_disp=2 lista solo las de ese tipo."""
    sp = "sp_marcas"
    campos_pk = ("id_marca",)
    campos_insertar = ("tipo_disp", "descripcion")
    campos_actualizar = ("tipo_disp", "descripcion")
    filtros_listar = ("tipo_disp",)
    insertar_devuelve_codigo = True
    serializer_class = s.MarcaSerializer
    serializer_filtros_class = s.MarcaFiltrosSerializer


class ModeloViewSet(SPViewSet):
    """Modelos de cada marca (sp_modelos_*). Se identifican con
    /modelos/<id_marca>/<id_modelo>/; el tipo de dispositivo sale de la marca.
    GET /modelos/?tipo_disp=2&id_marca=3 filtra (los dos son opcionales)."""
    sp = "sp_modelos"
    campos_pk = ("id_marca", "id_modelo")
    campos_insertar = ("id_marca", "descripcion")
    campos_actualizar = ("descripcion",)
    filtros_listar = ("tipo_disp", "id_marca")
    insertar_devuelve_codigo = True
    serializer_class = s.ModeloSerializer
    serializer_actualizar_class = Descripcion150Serializer
    serializer_filtros_class = s.ModeloFiltrosSerializer


class EdificioViewSet(SPViewSet):
    """Edificios de la Municipalidad: nombre, otras señas y coordenadas para
    el mapa (sp_edificios_*). El mapa de cada dispositivo es el de su
    edificio. Cada uno trae cantidad_dispositivos (dispositivos activos)."""
    sp = "sp_edificios"
    campos_pk = ("id_predio",)
    campos_insertar = ("descripcion", "otras_senas", "gps", "id_pais", "id_provincia", "id_canton", "id_distrito")
    campos_actualizar = ("descripcion", "otras_senas", "gps", "id_pais", "id_provincia", "id_canton", "id_distrito")
    insertar_devuelve_codigo = True
    serializer_class = s.EdificioSerializer


# =====================================================================
# Equipos (tabla equipos)
# =====================================================================
# En el orden de los parámetros de sp_equipos_insertar / _actualizar
# (los nombres son los de la página; la columna de la tabla equipos va al lado
# cuando se llama distinto)
CAMPOS_DISPOSITIVO = (
    "serie", "tipo_disp",                       # tipo_equipo
    "id_marca", "id_modelo", "nombre_equipo",
    "placa",                                    # placa_equipo
    "id_proces",
    "memoria_gb", "almacenamiento_gb",          # cant_mem, cant_almac
    "tipo_almacenamiento",
    "cant_ptos_serie", "cant_ptos_usb",
    "cant_ptos_ethernet",                       # cant_ptos_eth
    "cant_ptos_sfp", "cant_ptos_wireless", "cant_ptos_bluetooth", "cant_ptos_celular",
    "id_os",                                    # id_so
    "id_firmw", "extension",
    "tecnologia_impresion", "a_color", "consumible", "pulgadas", "resolucion",
    "capacidad_va", "autonomia_min", "canales",
    "id_predio", "ubicacion", "id_estado", "cod_departamento",
    "id_asignado",                              # id_usuario
    "id_proveedor", "fecha_compra", "garantia_hasta", "observaciones", "sfp_combo",
    # listas: dir_ips, dir_macs, num_moviles, dir_imeis, roles, herramientas
    "ips", "macs", "moviles", "imeis", "roles", "herramientas", "tiene_microclaudia",
)
DIRECCIONES = ("ips", "macs", "moviles", "imeis")      # filas con num_linea
CODIGOS = ("roles", "herramientas")                    # códigos de sus catálogos
# Lo que sale al leer un equipo y no se vuelve a mandar en un PATCH: las
# listas salen como texto y el procesador o el firmware como descripción
NO_SE_REENVIA = DIRECCIONES + CODIGOS + ("tiene_microclaudia",) + s.CAMPOS_VIEJOS


def lista_json(filas):
    """Lista validada (filas o códigos) -> texto JSON para el procedimiento.
    Las llaves sin valor no se mandan (NULL en la base)."""
    if filas is None:
        return None
    return json.dumps([{k: v for k, v in f.items() if v is not None} if isinstance(f, dict) else f for f in filas],
                      ensure_ascii=False)


class DispositivoViewSet(SPViewSet):
    """CRUD de equipos municipales (tabla equipos, sp_equipos_*).

    - Cada equipo es de un tipo, y el tipo de una categoría (red,
      computadoras, móviles, impresión...): la página pide los datos de su
      categoría (puertos; procesador, memoria y disco; IMEI y línea;
      impresión; pulgadas; VA...). Los que no aplican van vacíos.
    - La base valida que la marca sea del tipo, el modelo de la marca, el
      proveedor sea un proveedor, la persona asignada un funcionario, y que
      no se repitan la serie (por marca), la placa, el IMEI ni el nombre en
      la red entre los equipos activos.
    - Las IP, MAC, líneas e IMEI (tablas dir_ips, dir_macs, num_moviles y
      dir_imeis) y los roles y herramientas se guardan con el equipo, en la
      misma transacción. POST y PUT reciben "ips", "macs", "moviles" e
      "imeis" como listas de filas, y "roles" y "herramientas" como listas
      de códigos ([2, 3]):
        "ips":  [{"num_linea": 1, "direccion_ip": "192.168.1.1", "interfaz": "LAN"},
                 {"direccion_ip": "10.0.0.1"}]
        "macs": [{"direccion_mac": "AA-BB-CC-DD-EE-FF", "interfaz": "WAN"}]
        "moviles": [{"num_movil": "8888-8888", "operador": "KÖLBI"}]
        "imeis": [{"dir_imei": "356938035643809"}]
      Las que traen num_linea se modifican, las que no lo traen se agregan
      y las que ya no vienen se borran. Si no se mandan, no se tocan.
      También se pueden manejar una por una en /dispositivos/<id>/ips/ y
      /dispositivos/<id>/macs/.
    - Cada dispositivo trae "ips" y "macs" (todas, separadas por coma; la
      MAC sin separadores) y "gps_edificio" (las coordenadas de su
      edificio, para el mapa: el GPS se pone en el edificio).
    - "tiene_microclaudia": la herramienta 3 (MICROCLAUDIA). Al leer dice si
      la tiene; PATCH {"tiene_microclaudia": true} la agrega sin tocar las
      demás herramientas. "id_estado": 1 N/D, 2 ACTIVO, 3 INACTIVO ("activo"
      sale en true mientras no esté INACTIVO).
    - "sfp_combo" (switches): los SFP comparten número con los últimos puertos
      de cobre (45F = 45T, como el D-Link DGS-3120). Igual que el anterior:
      sin mandar se conserva. Los puertos están en /dispositivos/<id>/puertos/.
    - DELETE lo deja INACTIVO. POST /<id>/activar/ lo deja ACTIVO de nuevo.
      DELETE /<id>/eliminar-fisico/ lo borra con sus documentos y archivos.
    - GET /<id>/historial/ (solo administradores): quién lo registró y
      modificó, y los cambios a sus documentos.
    """
    sp = "sp_equipos"
    campos_pk = ("id_disp",)
    campos_insertar = CAMPOS_DISPOSITIVO
    campos_actualizar = CAMPOS_DISPOSITIVO
    filtros_listar = ("activo", "id_categoria", "tipo_disp", "id_marca", "id_predio", "cod_departamento",
                      "id_asignado", "id_proveedor", "buscar")
    insertar_devuelve_codigo = True
    campos_bool = ("activo", "a_color", "lleva_agente", "tiene_microclaudia", "sfp_combo")

    serializer_class = s.DispositivoSerializer
    serializer_filtros_class = s.DispositivoFiltrosSerializer

    def get_permissions(self):
        if self.action == "historial":
            return [SoloAdmin()]
        return super().get_permissions()

    def preparar_datos(self, datos, accion):
        for campo in DIRECCIONES + CODIGOS:
            datos[campo] = lista_json(datos.get(campo))
        return datos

    def update(self, request, partial=False, **kwargs):
        pk = self._valores_pk(kwargs)
        entrada = request.data
        if partial:
            # PATCH: se completa con los datos actuales. Las listas de la
            # lectura vienen como texto ("a, b"): si no se mandan, no se tocan.
            actual = {k: v for k, v in self._obtener(pk).items() if k not in NO_SE_REENVIA}
            entrada = {**actual, **request.data}
        datos = self.preparar_datos(self._validar(self.serializer_class, entrada), "actualizar")
        llamar_sp(f"{self.sp}_actualizar", pk + [datos.get(c) for c in self.campos_actualizar])
        return Response(self.salida(self._obtener(pk)))

    # POST /dispositivos/<id>/activar/
    def activar(self, request, id_disp):
        llamar_sp("sp_equipos_activar", [id_disp])
        return Response(self.salida(self._obtener([id_disp])))

    # DELETE /dispositivos/<id>/eliminar-fisico/
    def eliminar_fisico(self, request, id_disp):
        self._obtener([id_disp])  # 404 si no existe
        documentos, _ = llamar_sp("sp_archivos_listar", [id_disp, None])
        llamar_sp("sp_equipos_eliminar_fisico", [id_disp])
        for d in documentos:
            archivos.borrar(d.get("path_docs"))
        return Response(status=status.HTTP_204_NO_CONTENT)

    # GET /dispositivos/<id>/historial/?limite=20&desplazamiento=0
    def historial(self, request, id_disp):
        f = self._validar(s.HistorialSerializer, request.query_params)
        limite = f["limite"]
        filas, _ = llamar_sp("sp_equipos_historial", [
            id_disp, limite + 1, f["desplazamiento"],  # uno de más para saber si hay otra página
        ])
        return Response({
            "resultados": [formatear(x) for x in filas[:limite]],
            "hay_mas": len(filas) > limite,
        })


# =====================================================================
# Puertos de los switches: qué equipo está conectado a cada uno
# =====================================================================
BOOL_PUERTOS = ("activo", "sfp_combo", "fuera_de_rango", "switch_activo")
CATEGORIA_RED = 1


def _bools(filas):
    for f in filas:
        for c in BOOL_PUERTOS:
            if f.get(c) is not None:
                f[c] = bool(f[c])
    return filas


def _puertos_de(id_switch=None):
    filas, _ = llamar_sp("sp_puertos_switch_listar", [id_switch])
    return _bools(filas)


class PuertoSwitchViewSet(SPViewSet):
    """Puertos de los switches y demás equipos de red con puertos
    (sp_puertos_switch_*). Solo se guardan los puertos con algún dato;
    los demás están libres. Consultar: cualquier usuario con sesión;
    asignar y liberar: solo administradores.

    - GET    /dispositivos/switches/?activo=true   equipos de red con puertos,
             cada uno con sus puertos ("puertos")
    - GET    /dispositivos/<id>/puertos/            el switch y sus puertos
    - PUT    /dispositivos/<id>/puertos/<T|F>/<n>/  {"id_disp", "estado", "vlan", "nota"}
             T = cobre (1..puertos Ethernet), F = SFP (1..puertos SFP). Con
             equipo el puerto queda EN_USO. Devuelve el switch y sus puertos.
    - DELETE /dispositivos/<id>/puertos/<T|F>/<n>/  libera el puerto (ídem)
    - GET    /dispositivos/<id>/conexiones/         dónde está conectado un equipo
    Cada puerto trae "rotulo" (12, 45T, 45F, 49: según sfp_combo del switch),
    el equipo conectado (serie, tipo, marca, modelo, nombre en la red, IP,
    MAC, persona asignada, edificio...) y "fuera_de_rango" si el switch ya
    no tiene ese puerto (se le bajó la cantidad).
    """
    sp = "sp_equipos"
    campos_pk = ("id_disp",)
    campos_bool = ("activo", "a_color", "lleva_agente", "tiene_microclaudia", "sfp_combo")

    def _switch(self, id_disp):
        sw = self.salida(self._obtener([id_disp]))
        sw["tiene_puertos"] = sw.get("id_categoria") == CATEGORIA_RED and (
            (sw.get("cant_ptos_ethernet") or 0) + (sw.get("cant_ptos_sfp") or 0)) > 0
        return sw

    def _respuesta(self, id_disp):
        return Response({"switch": self._switch(id_disp), "puertos": _puertos_de(id_disp)})

    @staticmethod
    def _tipo(tipo_puerto):
        tipo = (tipo_puerto or "").upper()
        if tipo not in ("T", "F"):
            raise NotFound("El tipo de puerto debe ser T (cobre) o F (SFP).")
        return tipo

    # GET /dispositivos/switches/
    def equipos(self, request):
        f = self._validar(s.SwitchesFiltrosSerializer, request.query_params)
        equipos, _ = llamar_sp("sp_puertos_switch_equipos", [f.get("activo")])
        _bools(equipos)
        por_switch = {}
        for p in _puertos_de(None):
            por_switch.setdefault(p["id_switch"], []).append(p)
        for e in equipos:
            e["puertos"] = por_switch.get(e["id_disp"], [])
        return Response(equipos)

    # GET /dispositivos/<id>/puertos/
    def listar_puertos(self, request, id_disp):
        return self._respuesta(id_disp)

    # PUT /dispositivos/<id>/puertos/<T|F>/<n>/
    def guardar(self, request, id_disp, tipo_puerto, num_puerto):
        tipo = self._tipo(tipo_puerto)
        self._obtener([id_disp])   # 404 si el switch no existe
        datos = self._validar(s.PuertoSerializer, request.data)
        llamar_sp("sp_puertos_switch_guardar", [
            id_disp, tipo, num_puerto, datos.get("id_disp"), datos.get("estado"), datos.get("vlan"), datos.get("nota"),
        ])
        return self._respuesta(id_disp)

    # DELETE /dispositivos/<id>/puertos/<T|F>/<n>/
    def liberar(self, request, id_disp, tipo_puerto, num_puerto):
        tipo = self._tipo(tipo_puerto)
        self._obtener([id_disp])
        llamar_sp("sp_puertos_switch_eliminar", [id_disp, tipo, num_puerto])
        return self._respuesta(id_disp)

    # GET /dispositivos/<id>/conexiones/
    def conexiones(self, request, id_disp):
        self._obtener([id_disp])
        filas, _ = llamar_sp("sp_puertos_switch_de_equipo", [id_disp])
        return Response(_bools(filas))


# =====================================================================
# Direcciones IP y MAC de los dispositivos (puede tener varias)
# =====================================================================
class IpDispositivoViewSet(SPViewSet):
    """Direcciones IP de un equipo: tabla dir_ips (sp_dir_ips_*).
    IPv4 o IPv6; "interfaz" es opcional (WAN, LAN, GESTIÓN...)."""
    sp = "sp_dir_ips"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    campos_insertar = ("direccion_ip", "interfaz")
    campos_actualizar = ("direccion_ip", "interfaz")
    insertar_devuelve_codigo = True
    serializer_class = s.IpSerializer


class MacDispositivoViewSet(SPViewSet):
    """Direcciones MAC de un equipo: tabla dir_macs (sp_dir_macs_*).
    Se reciben con o sin separadores y se guardan enteras (AABBCCDDEEFF);
    la página las muestra con guiones. Una MAC no se repite en el inventario."""
    sp = "sp_dir_macs"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    campos_insertar = ("direccion_mac", "interfaz")
    campos_actualizar = ("direccion_mac", "interfaz")
    insertar_devuelve_codigo = True
    serializer_class = s.MacSerializer


class MovilDispositivoViewSet(SPViewSet):
    """Líneas telefónicas de un equipo: tabla num_moviles (sp_num_moviles_*)."""
    sp = "sp_num_moviles"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    campos_insertar = ("num_movil", "operador")
    campos_actualizar = ("num_movil", "operador")
    insertar_devuelve_codigo = True
    serializer_class = s.MovilSerializer


class ImeiDispositivoViewSet(SPViewSet):
    """IMEI de un equipo, uno por SIM: tabla dir_imeis (sp_dir_imeis_*).
    No se repiten en el inventario."""
    sp = "sp_dir_imeis"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    campos_insertar = ("dir_imei",)
    campos_actualizar = ("dir_imei",)
    insertar_devuelve_codigo = True
    serializer_class = s.ImeiSerializer


# =====================================================================
# Documentos de los dispositivos
# =====================================================================
# Se muestran como texto en la vista previa (configuraciones y respaldos)
EXT_TEXTO = {".txt", ".cfg", ".conf", ".config", ".log", ".xml", ".json", ".ini", ".csv", ".yaml", ".yml", ".md"}
EXT_VISTA_PREVIA = archivos.EXT_IMAGEN | archivos.EXT_OFFICE | EXT_TEXTO | {".pdf"}
# Por seguridad no se guardan páginas web ni scripts que un navegador ejecutaría
EXT_BLOQUEADAS = {".html", ".htm", ".xhtml", ".svg", ".js", ".mjs", ".php", ".phtml",
                  ".asp", ".aspx", ".jsp", ".hta"}
MAX_MB_TEXTO = 5   # tamaño máximo para mostrar un archivo de texto en la vista previa

_SUFIJO = re.compile(r"-[0-9a-f]{8}(?=\.[^./]+$|$)")


def nombre_visible(ruta):
    """manual-sophos-1a2b3c4d.pdf -> manual-sophos.pdf (quita el sufijo único)."""
    return _SUFIJO.sub("", os.path.basename(ruta or ""))


def _tamano(ruta):
    try:
        return archivos.almacen().size(ruta) if ruta else None
    except (OSError, SuspiciousFileOperation):
        return None


def _abrir(ruta):
    try:
        return archivos.almacen().open(ruta, "rb")
    except (FileNotFoundError, SuspiciousFileOperation):
        raise NotFound("No se encontró el archivo en el servidor.")


def _validar_documento(archivo):
    if archivo is None:
        raise ValidationError({"archivo": ["Seleccione un archivo."]})
    extension = Path(archivo.name).suffix.lower()
    if extension in EXT_BLOQUEADAS:
        raise ValidationError({"archivo": [
            "Por seguridad no se aceptan páginas web ni scripts (.html, .svg, .js, .php…). "
            "Si necesita guardarlo, comprímalo en un .zip."]})
    limite = getattr(settings, "MUNI_MAX_MB_DOCUMENTO_RED", 1024)
    if archivo.size > limite * 1024 * 1024:
        raise ValidationError({"archivo": [f"El archivo pesa más de {limite} MB."]})
    if not archivos.imagen_valida(archivo, extension):
        raise ValidationError({"archivo": ["El archivo no es una imagen válida."]})
    return extension


def _guardar(id_disp, archivo, extension):
    base = slugify(Path(archivo.name).stem)[:60] or "documento"
    return archivos.almacen().save(f"dispositivos/{id_disp}/{base}-{uuid.uuid4().hex[:8]}{extension}", archivo)


class DocumentoDispositivoViewSet(SPViewSet):
    """Documentos de un equipo: tabla archivos (sp_archivos_*).

    - POST (multipart/form-data): "archivo" + "id_doc" (tipo de documento).
    - PUT/PATCH: cambia el tipo; si trae "archivo", reemplaza el archivo.
    - DELETE borra el registro y el archivo del servidor.
    - GET .../<num_linea>/archivo/      descarga el archivo.
    - GET .../<num_linea>/vista-previa/ PDF, imagen o texto para verlo en la página
      (Word, Excel y PowerPoint se convierten a PDF con LibreOffice).
    Las imágenes traen "imagen_url", un enlace firmado que sirve en un <img>.
    """
    sp = "sp_archivos"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    # path_docs no viene en el cuerpo: lo pone esta vista al guardar el archivo
    campos_insertar = ("id_doc", "path_docs")
    campos_actualizar = ("id_doc", "path_docs")
    filtros_listar = ("id_doc",)
    insertar_devuelve_codigo = True
    serializer_class = s.DocumentoSerializer
    serializer_filtros_class = s.DocumentoFiltrosSerializer

    recurso_archivos = "dispositivos"

    @staticmethod
    def _tipo_firma(num_linea):
        return f"documentos/{num_linea}/archivo"

    def get_permissions(self):
        if self.action == "descargar":
            return [AllowAny()]  # se revisa sesión o firma dentro de descargar()
        return super().get_permissions()

    def perform_content_negotiation(self, request, force=False):
        # Las descargas devuelven el archivo, no JSON
        return super().perform_content_negotiation(
            request, force=force or self.action in ("descargar", "vista_previa"))

    def salida(self, fila):
        fila = super().salida(fila)
        ruta = fila.get("path_docs")
        extension = Path(ruta or "").suffix.lower()
        es_imagen = extension in archivos.EXT_IMAGEN
        fila["nombre_archivo"] = nombre_visible(ruta)
        fila["extension"] = extension.lstrip(".")
        fila["tamano"] = _tamano(ruta)
        fila["es_imagen"] = es_imagen
        fila["tiene_vista_previa"] = extension in EXT_VISTA_PREVIA
        fila["imagen_url"] = (archivos.url_firmada(self.recurso_archivos, self._tipo_firma(fila["num_linea"]),
                                                   fila["id_disp"], ruta) if es_imagen else None)
        return fila

    # POST /dispositivos/<id_disp>/documentos/
    def create(self, request, **kwargs):
        id_disp = kwargs["id_disp"]
        datos = self._validar(s.DocumentoSerializer, request.data)
        archivo = request.FILES.get("archivo")
        extension = _validar_documento(archivo)
        filas, _ = llamar_sp("sp_equipos_obtener", [id_disp])
        if not filas:
            raise NotFound("El dispositivo no existe.")

        ruta = _guardar(id_disp, archivo, extension)
        try:
            _, num_linea = llamar_sp(f"{self.sp}_insertar", [id_disp, datos["id_doc"], ruta], con_salida=True)
        except Exception:
            archivos.borrar(ruta)
            raise
        return Response(self.salida(self._obtener([id_disp, num_linea])), status=status.HTTP_201_CREATED)

    # PUT / PATCH /dispositivos/<id_disp>/documentos/<num_linea>/
    def update(self, request, partial=False, **kwargs):
        pk = self._valores_pk(kwargs)
        actual = self._obtener(pk)
        entrada = {"id_doc": request.data.get("id_doc", actual["id_doc"])} if partial else request.data
        datos = self._validar(s.DocumentoSerializer, entrada)

        archivo = request.FILES.get("archivo")
        nueva = None
        if archivo is not None:
            nueva = _guardar(kwargs["id_disp"], archivo, _validar_documento(archivo))
        try:
            llamar_sp(f"{self.sp}_actualizar", pk + [datos["id_doc"], nueva or actual["path_docs"]])
        except Exception:
            archivos.borrar(nueva)
            raise
        if nueva:
            archivos.borrar(actual["path_docs"])
        return Response(self.salida(self._obtener(pk)))

    # DELETE /dispositivos/<id_disp>/documentos/<num_linea>/
    def destroy(self, request, **kwargs):
        pk = self._valores_pk(kwargs)
        actual = self._obtener(pk)
        llamar_sp(f"{self.sp}_eliminar", pk)
        archivos.borrar(actual["path_docs"])
        return Response(status=status.HTTP_204_NO_CONTENT)

    # GET /dispositivos/<id_disp>/documentos/<num_linea>/archivo/
    def descargar(self, request, id_disp, num_linea):
        autenticado = getattr(request.user, "is_authenticated", False)
        filas, _ = llamar_sp(f"{self.sp}_obtener", [id_disp, num_linea])
        ruta = filas[0]["path_docs"] if filas else None
        es_imagen = Path(ruta or "").suffix.lower() in archivos.EXT_IMAGEN

        firma = request.query_params.get("firma")
        if not autenticado and not (es_imagen and archivos.firma_valida(
                self.recurso_archivos, self._tipo_firma(num_linea), id_disp, ruta, firma)):
            raise NotAuthenticated("Inicie sesión para ver este archivo.")
        if not filas:
            raise NotFound("El documento no existe.")

        respuesta = FileResponse(
            _abrir(ruta),
            as_attachment=not es_imagen,
            filename=nombre_visible(ruta),
            content_type=mimetypes.guess_type(ruta)[0] or "application/octet-stream",
        )
        if es_imagen:
            # El enlace cambia cuando cambia el archivo, así que se puede guardar en caché
            respuesta["Cache-Control"] = "private, max-age=86400"
        return respuesta

    # GET /dispositivos/<id_disp>/documentos/<num_linea>/vista-previa/
    def vista_previa(self, request, id_disp, num_linea):
        ruta = self._obtener([id_disp, num_linea])["path_docs"]
        extension = Path(ruta).suffix.lower()

        if extension in EXT_TEXTO:
            tamano = _tamano(ruta)
            if tamano is None:
                raise NotFound("No se encontró el archivo en el servidor.")
            if tamano > MAX_MB_TEXTO * 1024 * 1024:
                raise NotFound(f"El archivo pesa más de {MAX_MB_TEXTO} MB y no se puede mostrar. Descárguelo para verlo.")
            with _abrir(ruta) as f:
                contenido = f.read()
            try:
                texto = contenido.decode("utf-8")
            except UnicodeDecodeError:
                texto = contenido.decode("cp1252", errors="replace")
            return HttpResponse(texto.encode("utf-8"), content_type="text/plain; charset=utf-8")

        if extension in archivos.EXT_OFFICE:
            mostrar = archivos.pdf_de_vista_previa(ruta)
        elif extension == ".pdf" or extension in archivos.EXT_IMAGEN:
            mostrar = ruta
        else:
            raise NotFound("Este tipo de archivo no tiene vista previa. Descárguelo para abrirlo.")
        return FileResponse(_abrir(mostrar), as_attachment=False, filename=Path(mostrar).name,
                            content_type=mimetypes.guess_type(mostrar)[0] or "application/pdf")
