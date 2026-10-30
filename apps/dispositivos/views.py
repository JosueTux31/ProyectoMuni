"""APIs del módulo de equipos municipales (antes dispositivos de red): equipos
de red, computadoras, servidores, móviles, telefonía, impresión, pantallas,
UPS, cámaras... en la tabla equiposMuni.

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
from apps.catalogos.serializers import Descripcion150Serializer
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
    """Categorías de equipo (sp_cat_categorias_dispositivos_*): equipos de red,
    computadoras, servidores, móviles, telefonía, impresión... Son fijas
    (la página sabe qué datos pide cada una): solo se consultan.
    lleva_agente: se espera que sus equipos tengan el agente de Microclaudia."""
    sp = "sp_cat_categorias_dispositivos"
    campos_pk = ("id_categoria",)
    campos_bool = ("lleva_agente",)


class TipoDispositivoViewSet(SPViewSet):
    """Modem, firewall, laptop, impresora, celular... (sp_cat_tipos_dispositivos_*).
    Cada tipo es de una categoría (id_categoria). Al crear sin categoría se
    toma la que dice el nombre (LAPTOP -> computadoras) o «otros equipos».
    GET /tipos/?id_categoria=2 lista solo los de esa categoría."""
    sp = "sp_cat_tipos_dispositivos"
    campos_pk = ("tipo_disp",)
    campos_insertar = ("descripcion", "id_categoria")
    campos_actualizar = ("descripcion", "id_categoria")
    filtros_listar = ("id_categoria",)
    insertar_devuelve_codigo = True
    campos_bool = ("lleva_agente",)
    serializer_class = s.TipoDispositivoSerializer
    serializer_filtros_class = s.TipoFiltrosSerializer


class SistemaOperativoViewSet(CatalogoViewSet):
    """N/D, Linux, Windows... (sp_cat_sistemas_operativos_*)."""
    sp = "sp_cat_sistemas_operativos"
    campos_pk = ("id_os",)
    serializer_class = s.Descripcion100Serializer


class TipoDocumentoViewSet(CatalogoViewSet):
    """Manuales, imagen, firmware, respaldo, configuración... (sp_cat_tipos_documentos_*)."""
    sp = "sp_cat_tipos_documentos"
    campos_pk = ("id_doc",)
    serializer_class = s.Descripcion100Serializer


class MarcaViewSet(SPViewSet):
    """Marcas, cada una de un tipo de dispositivo (sp_cat_marcas_*).
    GET /marcas/?tipo_disp=2 lista solo las de ese tipo."""
    sp = "sp_cat_marcas"
    campos_pk = ("id_marca",)
    campos_insertar = ("tipo_disp", "descripcion")
    campos_actualizar = ("tipo_disp", "descripcion")
    filtros_listar = ("tipo_disp",)
    insertar_devuelve_codigo = True
    serializer_class = s.MarcaSerializer
    serializer_filtros_class = s.MarcaFiltrosSerializer


class ModeloViewSet(SPViewSet):
    """Modelos de cada marca (sp_cat_modelos_*). Se identifican con
    /modelos/<id_marca>/<id_modelo>/; el tipo de dispositivo sale de la marca.
    GET /modelos/?tipo_disp=2&id_marca=3 filtra (los dos son opcionales)."""
    sp = "sp_cat_modelos"
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
    el mapa (sp_cat_edificios_*). El mapa de cada dispositivo es el de su
    edificio. Cada uno trae cantidad_dispositivos (dispositivos activos)."""
    sp = "sp_cat_edificios"
    campos_pk = ("id_predio",)
    campos_insertar = ("descripcion", "otras_senas", "gps")
    campos_actualizar = ("descripcion", "otras_senas", "gps")
    insertar_devuelve_codigo = True
    serializer_class = s.EdificioSerializer


# =====================================================================
# Equipos (tabla equiposMuni)
# =====================================================================
# En el orden de los parámetros de sp_equiposMuni_insertar / _actualizar
CAMPOS_DISPOSITIVO = (
    "serie", "tipo_disp", "id_marca", "id_modelo", "nombre_equipo", "placa",
    "cant_ptos_ethernet", "cant_ptos_sfp", "id_os", "version_os",
    "procesador", "memoria_gb", "almacenamiento_gb", "tipo_almacenamiento",
    "imei", "imei2", "numero_linea", "operador", "extension",
    "tecnologia_impresion", "a_color", "consumible", "pulgadas", "resolucion",
    "capacidad_va", "autonomia_min", "canales",
    "id_predio", "ubicacion", "cod_departamento", "id_asignado", "id_proveedor",
    "fecha_compra", "garantia_hasta", "observaciones", "tiene_microclaudia",
    "ips", "macs",
)
DIRECCIONES = ("ips", "macs")


def lista_json(filas):
    """Lista de IP o MAC validada -> texto JSON para el procedimiento.
    Las llaves sin valor no se mandan (NULL en la base)."""
    if filas is None:
        return None
    return json.dumps([{k: v for k, v in f.items() if v is not None} for f in filas], ensure_ascii=False)


class DispositivoViewSet(SPViewSet):
    """CRUD de equipos municipales (sp_equiposMuni_*).

    - Cada equipo es de un tipo, y el tipo de una categoría (red,
      computadoras, móviles, impresión...): la página pide los datos de su
      categoría (puertos; procesador, memoria y disco; IMEI y línea;
      impresión; pulgadas; VA...). Los que no aplican van vacíos.
    - La base valida que la marca sea del tipo, el modelo de la marca, el
      proveedor sea un proveedor, la persona asignada un funcionario, y que
      no se repitan la serie (por marca), la placa, el IMEI ni el nombre en
      la red entre los equipos activos.
    - Las IP y MAC se guardan con el dispositivo, en la misma transacción:
      POST y PUT reciben "ips" y "macs" como listas
        "ips":  [{"num_linea": 1, "direccion_ip": "192.168.1.1", "interfaz": "LAN"},
                 {"direccion_ip": "10.0.0.1"}]
        "macs": [{"direccion_mac": "AA-BB-CC-DD-EE-FF", "interfaz": "WAN"}]
      Las que traen num_linea se modifican, las que no lo traen se agregan
      y las que ya no vienen se borran. Si no se mandan, no se tocan.
      También se pueden manejar una por una en /dispositivos/<id>/ips/ y
      /dispositivos/<id>/macs/.
    - Cada dispositivo trae "ips" y "macs" (todas, separadas por coma; la
      MAC sin separadores) y "gps_edificio" (las coordenadas de su
      edificio, para el mapa: el GPS se pone en el edificio).
    - "tiene_microclaudia": el check de la licencia de Microclaudia, que marca
      el administrador. Si no se manda (o va en null) se conserva el que tenía;
      PATCH {"tiene_microclaudia": true} cambia solo el check.
    - DELETE desactiva. POST /<id>/activar/ lo activa de nuevo.
      DELETE /<id>/eliminar-fisico/ lo borra con sus documentos y archivos.
    - GET /<id>/historial/ (solo administradores): quién lo registró y
      modificó, y los cambios a sus documentos.
    """
    sp = "sp_equiposMuni"
    campos_pk = ("id_disp",)
    campos_insertar = CAMPOS_DISPOSITIVO
    campos_actualizar = CAMPOS_DISPOSITIVO
    filtros_listar = ("activo", "id_categoria", "tipo_disp", "id_marca", "id_predio", "cod_departamento",
                      "id_asignado", "id_proveedor", "buscar")
    insertar_devuelve_codigo = True
    campos_bool = ("activo", "a_color", "lleva_agente", "tiene_microclaudia")

    serializer_class = s.DispositivoSerializer
    serializer_filtros_class = s.DispositivoFiltrosSerializer

    def get_permissions(self):
        if self.action == "historial":
            return [SoloAdmin()]
        return super().get_permissions()

    def preparar_datos(self, datos, accion):
        for campo in DIRECCIONES:
            datos[campo] = lista_json(datos.get(campo))
        return datos

    def update(self, request, partial=False, **kwargs):
        pk = self._valores_pk(kwargs)
        entrada = request.data
        if partial:
            # PATCH: se completa con los datos actuales. Las IP y MAC de la
            # lectura vienen como texto ("a, b"): si no se mandan, no se tocan.
            actual = {k: v for k, v in self._obtener(pk).items() if k not in DIRECCIONES}
            entrada = {**actual, **request.data}
        datos = self.preparar_datos(self._validar(self.serializer_class, entrada), "actualizar")
        llamar_sp(f"{self.sp}_actualizar", pk + [datos.get(c) for c in self.campos_actualizar])
        return Response(self.salida(self._obtener(pk)))

    # POST /dispositivos/<id>/activar/
    def activar(self, request, id_disp):
        llamar_sp("sp_equiposMuni_activar", [id_disp])
        return Response(self.salida(self._obtener([id_disp])))

    # DELETE /dispositivos/<id>/eliminar-fisico/
    def eliminar_fisico(self, request, id_disp):
        self._obtener([id_disp])  # 404 si no existe
        documentos, _ = llamar_sp("sp_red_documentos_dispositivos_listar", [id_disp, None])
        llamar_sp("sp_equiposMuni_eliminar_fisico", [id_disp])
        for d in documentos:
            archivos.borrar(d.get("path_docs"))
        return Response(status=status.HTTP_204_NO_CONTENT)

    # GET /dispositivos/<id>/historial/?limite=20&desplazamiento=0
    def historial(self, request, id_disp):
        f = self._validar(s.HistorialSerializer, request.query_params)
        limite = f["limite"]
        filas, _ = llamar_sp("sp_equiposMuni_historial", [
            id_disp, limite + 1, f["desplazamiento"],  # uno de más para saber si hay otra página
        ])
        return Response({
            "resultados": [formatear(x) for x in filas[:limite]],
            "hay_mas": len(filas) > limite,
        })


# =====================================================================
# Direcciones IP y MAC de los dispositivos (puede tener varias)
# =====================================================================
class IpDispositivoViewSet(SPViewSet):
    """Direcciones IP de un dispositivo: tabla equipos (sp_equipos_*).
    IPv4 o IPv6; "interfaz" es opcional (WAN, LAN, GESTIÓN...)."""
    sp = "sp_equipos"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    campos_insertar = ("direccion_ip", "interfaz")
    campos_actualizar = ("direccion_ip", "interfaz")
    insertar_devuelve_codigo = True
    serializer_class = s.IpSerializer


class MacDispositivoViewSet(SPViewSet):
    """Direcciones MAC de un dispositivo (sp_red_macs_dispositivos_*).
    Se reciben con o sin separadores y se guardan enteras (AABBCCDDEEFF);
    la página las muestra con guiones. Una MAC no se repite en el inventario."""
    sp = "sp_red_macs_dispositivos"
    campos_padre = ("id_disp",)
    campos_pk = ("id_disp", "num_linea")
    campos_insertar = ("direccion_mac", "interfaz")
    campos_actualizar = ("direccion_mac", "interfaz")
    insertar_devuelve_codigo = True
    serializer_class = s.MacSerializer


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
    """Documentos de un dispositivo (sp_red_documentos_dispositivos_*).

    - POST (multipart/form-data): "archivo" + "id_doc" (tipo de documento).
    - PUT/PATCH: cambia el tipo; si trae "archivo", reemplaza el archivo.
    - DELETE borra el registro y el archivo del servidor.
    - GET .../<num_linea>/archivo/      descarga el archivo.
    - GET .../<num_linea>/vista-previa/ PDF, imagen o texto para verlo en la página
      (Word, Excel y PowerPoint se convierten a PDF con LibreOffice).
    Las imágenes traen "imagen_url", un enlace firmado que sirve en un <img>.
    """
    sp = "sp_red_documentos_dispositivos"
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
        filas, _ = llamar_sp("sp_equiposMuni_obtener", [id_disp])
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
