"""APIs del módulo de análisis de logs (/api/logs/). Solo administradores:
los logs muestran la navegación y las conexiones del personal.

- POST importaciones/sophos/      importa un archivo de Sophos (multipart: archivo, descripcion)
- POST importaciones/microclaudia/ importa el listado de equipos de Microclaudia (.csv o .txt)
- POST importaciones/dhcp/         importa las concesiones del DHCP de Windows (.txt o .csv)
- GET  importaciones/              lista; GET/PUT/DELETE importaciones/<id>/
- GET  eventos/?q=&importaciones=  busca con el filtro estilo Wireshark (paginado)
- GET  eventos/<id>/               un evento con todo, su conexión y el inventario
- GET  eventos/tablero/?q=         números, línea de tiempo y tops para los gráficos
- GET  eventos/exportar/?q=&formato=csv|json&campos=comunes|todos
- GET  filtro/?q=                  revisa el filtro mientras se escribe
- GET  campos/                     campos comunes, sus alias y los del filtro
- POST comparar/                   compara 2 a 4 conjuntos de eventos
- GET  inventario/?q=              cruce con equipos (IP/MAC) y personas
- GET  agentes/?importacion=       tablero del listado de Microclaudia (por defecto el último)
- GET  cobertura/?agentes=        equipos registrados sin el agente de Microclaudia
- GET  intrusos/?dhcp=&agentes=    concesiones del DHCP comparadas por MAC con el inventario
- GET  equipos/<id_disp>/          dónde aparece un equipo del inventario: DHCP, Microclaudia y Sophos
- CRUD mapeo/                      alias de los campos por programa
"""
import csv
import io
import json
import re
from pathlib import Path

from django.conf import settings
from django.http import StreamingHttpResponse
from rest_framework import serializers, status, viewsets
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response

from apps.core.db import llamar_sp
from apps.core.permisos import SoloAdmin
from apps.core.viewsets import SPViewSet

from . import filtro as flt
from . import servicio as srv
from .esquema import (ALIAS_FILTRO, CAMPO, CAMPOS, CAMPOS_AMBOS, CAMPOS_COMPARAR, CAMPOS_TOP, GRUPOS)

EXT_PERMITIDAS = {".txt", ".log", ".csv", ".text", ""}

# Un texto del log que empieza con = + - @ se exporta con un apóstrofo delante
# para que Excel no lo tome como fórmula (los logs traen datos de afuera:
# nombres de equipos, URL, agentes de usuario...). Los números quedan igual.
_FORMULA = re.compile(r"^[=+\-@\t\r]")
_NUMERO = re.compile(r"^(-?\d+([.,]\d+)?|-+)$")   # números y rayas solas ("-")


def _celda_csv(valor):
    if isinstance(valor, str) and _FORMULA.match(valor) and not _NUMERO.match(valor):
        return "'" + valor
    return valor


def _filtro(request, clave="q"):
    try:
        return srv.armar_filtro(request.query_params.get(clave, ""), request.query_params.get("importaciones"))
    except flt.ErrorFiltro as e:
        raise ValidationError({"detail": e.mensaje, "posicion": e.posicion, "filtro": [e.mensaje]})


def _entero(request, clave, defecto, minimo=0, maximo=None):
    try:
        v = int(request.query_params.get(clave, defecto))
    except (TypeError, ValueError):
        v = defecto
    v = max(v, minimo)
    return min(v, maximo) if maximo else v


# =====================================================================
# Importaciones
# =====================================================================
class DescripcionSerializer(serializers.Serializer):
    descripcion = serializers.CharField(max_length=255, required=False, allow_blank=True, allow_null=True)


class FiltroFuenteSerializer(serializers.Serializer):
    fuente = serializers.CharField(max_length=30, required=False, allow_null=True, default=None)


class ImportacionViewSet(SPViewSet):
    """Archivos de logs importados (sp_log_importaciones_*)."""
    sp = "sp_log_importaciones"
    campos_pk = ("id_importacion",)
    campos_actualizar = ("descripcion",)
    filtros_listar = ("fuente",)
    serializer_class = DescripcionSerializer
    serializer_filtros_class = FiltroFuenteSerializer
    permission_classes = [SoloAdmin]

    # POST importaciones/sophos/  (multipart: archivo, descripcion)
    def importar(self, request, fuente="SOPHOS"):
        archivo = request.FILES.get("archivo")
        if archivo is None:
            raise ValidationError({"archivo": ["Seleccione el archivo de logs."]})
        nombre_fuente = srv.FUENTES[fuente]["nombre"]
        clase = srv.FUENTES[fuente]["clase"]
        if Path(archivo.name).suffix.lower() not in EXT_PERMITIDAS:
            raise ValidationError({"archivo": [f"Use el archivo de texto que exporta {nombre_fuente} "
                                               f"({'.txt o .log' if clase == 'logs' else '.csv o .txt'})."]})
        max_mb = getattr(settings, "MUNI_MAX_MB_LOG", 100)
        if archivo.size > max_mb * 1024 * 1024:
            raise ValidationError({"archivo": [f"El archivo pesa más de {max_mb} MB. Divídalo en partes."]})
        descripcion = (request.data.get("descripcion") or "").strip()[:255] or None
        id_imp, leidos, avisos = srv.importar(fuente, Path(archivo.name).name[:255], archivo.read(), descripcion,
                                              getattr(request.user, "id", None))
        if id_imp is None:
            if clase == "agentes":
                mensaje = (f"No se encontró ningún equipo en el listado de {nombre_fuente}. "
                           f"{avisos[0] if avisos else ''}").strip()
            elif clase == "dhcp":
                mensaje = (f"No se encontró ninguna concesión en la lista del DHCP. "
                           f"{avisos[0] if avisos else ''}").strip()
            else:
                mensaje = ("No se encontró ningún evento de Sophos en el archivo. Debe traer el tipo "
                           "(Firewall, Web filter...), la fecha y los campos clave=\"valor\".")
            raise ValidationError({"archivo": [mensaje], "avisos": avisos[:20]})
        fila = llamar_sp("sp_log_importaciones_obtener", [id_imp])[0][0]
        return Response({**fila, "avisos_detalle": avisos[:50]}, status=status.HTTP_201_CREATED)


# =====================================================================
# Eventos
# =====================================================================
class EventoViewSet(viewsets.GenericViewSet):
    permission_classes = [SoloAdmin]
    pagination_class = None

    # GET eventos/?q=&importaciones=&orden=desc&limite=100&desplazamiento=0
    def list(self, request):
        where, usados = _filtro(request)
        limite = _entero(request, "limite", 100, 1, 1000)
        desp = _entero(request, "desplazamiento", 0)
        orden = "asc" if request.query_params.get("orden") == "asc" else "desc"
        filas, _ = llamar_sp("sp_log_eventos_buscar", [where, orden, limite, desp])
        total = llamar_sp("sp_log_eventos_contar", [where])[0][0]["total"]
        return Response({"total": total, "resultados": filas, "campos_usados": sorted(usados)})

    # GET eventos/<id>/
    def retrieve(self, request, id_evento):
        filas, _ = llamar_sp("sp_log_eventos_obtener", [id_evento])
        if not filas:
            raise NotFound("El evento no existe.")
        ev = filas[0]
        ev["datos"] = srv.cargar_datos(ev)
        ev["conexion"] = (llamar_sp("sp_log_eventos_conexion", [ev["id_conexion"]])[0]
                          if ev.get("id_conexion") else [])
        return Response(ev)

    # GET eventos/tablero/?q=&importaciones=
    def tablero(self, request):
        where, _ = _filtro(request)
        return Response(srv.tablero(where))

    # GET eventos/top/?q=&campo=ip_origen&limite=20
    def top(self, request):
        where, _ = _filtro(request)
        campo = request.query_params.get("campo", "")
        if campo not in CAMPOS_TOP:
            raise ValidationError({"campo": ["Ese campo no se puede agrupar."]})
        filas, _ = llamar_sp("sp_log_eventos_top", [where, campo, _entero(request, "limite", 20, 1, 500)])
        return Response(filas)

    # GET eventos/exportar/?q=&importaciones=&formato=csv|json&campos=comunes|todos
    def exportar(self, request):
        where, _ = _filtro(request)
        formato = request.query_params.get("formato", "csv")
        todos = request.query_params.get("campos") == "todos"
        maximo = getattr(settings, "MUNI_MAX_EXPORTAR_LOGS", 100000)
        nombre = "logs_" + srv.datetime.now().strftime("%Y%m%d_%H%M%S")

        if formato == "json":
            def generar_json():
                yield "[\n"
                primero = True
                for pagina in srv.paginas_exportar(where, maximo):
                    for f in pagina:
                        obj = srv.fila_comun(f)
                        obj["original"] = srv.cargar_datos(f)
                        yield ("" if primero else ",\n") + json.dumps(obj, ensure_ascii=False, default=str)
                        primero = False
                yield "\n]\n"
            r = StreamingHttpResponse(generar_json(), content_type="application/json; charset=utf-8")
            r["Content-Disposition"] = f'attachment; filename="{nombre}.json"'
            return r

        extras = []
        if todos:
            vistos = {}
            for pagina in srv.paginas_exportar(where, maximo):
                for f in pagina:
                    for k in srv.cargar_datos(f):
                        vistos.setdefault(k, None)
            extras = list(vistos)

        def generar_csv():
            buf = io.StringIO()
            w = csv.writer(buf, delimiter=";", lineterminator="\r\n")
            encabezado = None
            yield "﻿"          # Excel abre bien las tildes
            for pagina in srv.paginas_exportar(where, maximo):
                for f in pagina:
                    fila = srv.fila_comun(f)
                    if encabezado is None:
                        encabezado = list(fila) + [f"original.{k}" for k in extras]
                        w.writerow(encabezado)
                    datos = srv.cargar_datos(f) if extras else {}
                    w.writerow([_celda_csv(x) for x in list(fila.values()) + [datos.get(k, "") for k in extras]])
                yield buf.getvalue()
                buf.seek(0)
                buf.truncate(0)
            if encabezado is None:
                w.writerow(["sin eventos"])
                yield buf.getvalue()
        r = StreamingHttpResponse(generar_csv(), content_type="text/csv; charset=utf-8")
        r["Content-Disposition"] = f'attachment; filename="{nombre}.csv"'
        return r


# =====================================================================
# Filtro, campos, comparar e inventario
# =====================================================================
class AnalisisViewSet(viewsets.GenericViewSet):
    permission_classes = [SoloAdmin]
    pagination_class = None

    # GET filtro/?q=
    def validar(self, request):
        _, usados = _filtro(request)
        return Response({"ok": True, "campos_usados": sorted(usados)})

    # GET campos/
    def campos(self, request):
        filas, _ = llamar_sp("sp_log_mapeo_campos_listar", [None])
        alias = {}
        for f in filas:
            alias.setdefault(f["campo"], []).append({"fuente": f["fuente"], "nombre": f["campo_origen"],
                                                      "prioridad": f["prioridad"]})
        estilo_ws = {}
        for nombre, campo in ALIAS_FILTRO.items():
            estilo_ws.setdefault(campo, []).append(nombre)
        return Response({
            "grupos": GRUPOS,
            "campos": [{"campo": c, "etiqueta": e, "grupo": g, "tipo": t, "alias": alias.get(c, []),
                        "filtro": estilo_ws.get(c, [])} for c, e, g, t, _ in CAMPOS],
            "ambos": {k: list(v) for k, v in CAMPOS_AMBOS.items()},
            "virtuales": flt.VIRTUALES,
            "comparables": CAMPOS_COMPARAR,
            "fuentes": {k: v["nombre"] for k, v in srv.FUENTES.items()},
            "clases": {k: v["clase"] for k, v in srv.FUENTES.items()},
        })

    # POST comparar/  {"conjuntos": [{"nombre": "A", "importaciones": [1], "filtro": "..."}], "campos": [...]}
    def comparar(self, request):
        conjuntos = request.data.get("conjuntos") or []
        if not isinstance(conjuntos, list) or not 2 <= len(conjuntos) <= 4:
            raise ValidationError({"detail": "Elija de 2 a 4 conjuntos de logs para comparar."})
        preparados = []
        for i, c in enumerate(conjuntos):
            c = c if isinstance(c, dict) else {}
            imps = [int(x) for x in (c.get("importaciones") or []) if str(x).isdigit()][:50]
            try:
                where, _ = srv.armar_filtro(str(c.get("filtro") or ""), imps)
            except flt.ErrorFiltro as e:
                raise ValidationError({"detail": f"Conjunto {i + 1}: {e.mensaje}", "conjunto": i, "posicion": e.posicion})
            if not where:
                raise ValidationError({"detail": f"Conjunto {i + 1}: elija al menos una importación o escriba un filtro.",
                                       "conjunto": i})
            preparados.append({"nombre": str(c.get("nombre") or chr(65 + i))[:40], "where": where})
        campos = [c for c in (request.data.get("campos") or CAMPOS_COMPARAR) if c in CAMPO] or CAMPOS_COMPARAR
        resultado = srv.comparar(preparados, campos)
        resultado["conjuntos"] = [{"nombre": p["nombre"]} for p in preparados]
        return Response(resultado)

    # GET inventario/?q=&importaciones=
    def inventario(self, request):
        where, _ = _filtro(request)
        return Response(srv.cruce_inventario(where))

    def _importacion_agentes(self, request, clave):
        """La importación de agentes pedida (?clave=) o la última de Microclaudia."""
        valor = request.query_params.get(clave)
        if valor:
            filas, _ = llamar_sp("sp_log_importaciones_obtener", [_entero(request, clave, 0)])
            if not filas:
                raise NotFound("La importación no existe.")
            imp = filas[0]
            if imp["fuente"] not in srv.FUENTES_AGENTES:
                raise ValidationError({"detail": "Esa importación no es un listado de equipos con agente."})
            return imp
        return srv.ultima_importacion(srv.FUENTES_AGENTES[0])

    # GET agentes/?importacion=<id>  (sin importacion: el último listado)
    def agentes(self, request):
        imp = self._importacion_agentes(request, "importacion")
        if imp is None:
            return Response({"importacion": None})
        return Response({"importacion": imp, **srv.tablero_agentes(imp["id_importacion"])})

    # GET cobertura/?agentes=<id>  (sin agentes: el último listado). Compara los
    # equipos registrados en el sistema (dispositivos activos) con el listado.
    def cobertura(self, request):
        imp = self._importacion_agentes(request, "agentes")
        if imp is None:
            return Response({"importacion": None})
        return Response({"importacion": imp, **srv.cobertura(imp["id_importacion"])})

    # GET intrusos/?dhcp=<id>&agentes=<id>  (sin dhcp: la última lista del DHCP;
    # sin agentes: el último listado de Microclaudia; agentes=0: sin listado).
    # Compara por MAC las concesiones del DHCP con los equipos registrados.
    def intrusos(self, request):
        valor = request.query_params.get("dhcp")
        if valor:
            filas, _ = llamar_sp("sp_log_importaciones_obtener", [_entero(request, "dhcp", 0)])
            if not filas:
                raise NotFound("La importación no existe.")
            imp = filas[0]
            if imp["fuente"] not in srv.FUENTES_DHCP:
                raise ValidationError({"detail": "Esa importación no es una lista de concesiones del DHCP."})
        else:
            imp = srv.ultima_importacion(srv.FUENTES_DHCP[0])
        if imp is None:
            return Response({"importacion": None})
        agentes = None if request.query_params.get("agentes") == "0" else self._importacion_agentes(request, "agentes")
        resultado = srv.intrusos(imp["id_importacion"], agentes["id_importacion"] if agentes else None)
        return Response({"importacion": imp, "agentes": agentes, **resultado})

    # GET equipos/<id_disp>/  Dónde aparece un equipo del inventario en lo
    # importado: la última lista del DHCP, el último listado de Microclaudia y
    # su tráfico en los logs de Sophos (pestaña «En la red» de su ficha).
    def equipo(self, request, id_disp):
        resultado = srv.visto_en_red(id_disp)
        if resultado is None:
            raise NotFound("El equipo no existe.")
        return Response(resultado)


# =====================================================================
# Alias de los campos (log_mapeo_campos)
# =====================================================================
class MapeoSerializer(serializers.Serializer):
    fuente = serializers.CharField(max_length=30)
    campo_origen = serializers.RegexField(r"^[A-Za-z_][A-Za-z0-9_.\-]*$", max_length=64)
    campo = serializers.ChoiceField(choices=[c for c, *_ in CAMPOS if c not in ("fecha", "tipo", "accion")])
    prioridad = serializers.IntegerField(min_value=1, max_value=99, default=1)

    def validate_fuente(self, v):
        v = v.strip().upper()
        if v not in srv.FUENTES:
            raise serializers.ValidationError("Fuente desconocida.")
        return v


class MapeoActualizarSerializer(serializers.Serializer):
    campo = serializers.ChoiceField(choices=[c for c, *_ in CAMPOS if c not in ("fecha", "tipo", "accion")])
    prioridad = serializers.IntegerField(min_value=1, max_value=99, default=1)


class MapeoFiltroSerializer(serializers.Serializer):
    fuente = serializers.CharField(max_length=30, required=False, allow_null=True, default=None)


class MapeoViewSet(SPViewSet):
    sp = "sp_log_mapeo_campos"
    campos_pk = ("fuente", "campo_origen")
    campos_insertar = ("fuente", "campo_origen", "campo", "prioridad")
    campos_actualizar = ("campo", "prioridad")
    filtros_listar = ("fuente",)
    serializer_class = MapeoSerializer
    serializer_actualizar_class = MapeoActualizarSerializer
    serializer_filtros_class = MapeoFiltroSerializer
    permission_classes = [SoloAdmin]

    def preparar_datos(self, datos, accion):
        if "campo_origen" in datos:
            datos["campo_origen"] = datos["campo_origen"].strip().lower()
        return datos

    def create(self, request, **kwargs):
        datos = self.preparar_datos(self._validar(self.serializer_class, request.data), "insertar")
        llamar_sp("sp_log_mapeo_campos_insertar", [datos[c] for c in self.campos_insertar])
        return Response(self._obtener([datos["fuente"], datos["campo_origen"]]), status=status.HTTP_201_CREATED)

    def _valores_pk(self, kwargs):
        return [kwargs["fuente"].upper(), kwargs["campo_origen"].lower()]

