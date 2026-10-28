"""APIs del módulo de correo institucional (/api/correo/). Solo administradores.

- GET/PUT configuracion/          la cuenta institucional (la clave nunca sale)
- POST    configuracion/prueba/   envía un correo de prueba {"para": "..."}
- GET     personal/               el personal activo con su correo (para elegir destinatarios)
- GET     envios/?buscar=         historial de avisos
- POST    envios/                 crea un aviso (multipart: asunto, mensaje, todos, departamentos,
                                  personas, adjuntos). No lo envía: eso lo hace enviar/
- POST    envios/prueba/          envía el aviso solo a quien lo está escribiendo
- GET     envios/<id>/            el aviso con sus destinatarios y adjuntos
- DELETE  envios/<id>/            solo si no se le envió a nadie
- POST    envios/<id>/enviar/     envía el siguiente lote; la pantalla repite hasta terminar
- POST    envios/<id>/reintentar/ vuelve a enviar los que fallaron o se cancelaron
- POST    envios/<id>/cancelar/   detiene el envío
- GET     envios/<id>/adjuntos/<n>/  descarga un adjunto
- GET/POST listas/                listas de correos importadas (POST multipart: archivo, descripcion)
- GET/PUT/DELETE listas/<id>/     una lista con su comparación con el personal
"""
import json
import mimetypes
import os
import uuid
from pathlib import Path

from django.conf import settings
from django.db import transaction
from django.http import FileResponse
from django.utils.text import slugify
from rest_framework import serializers, status, viewsets
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response

from apps.core.archivos import almacen, borrar
from apps.core.db import llamar_sp
from apps.core.permisos import SoloAdmin

from . import listas as lst
from . import servicio as srv
from .cifrado import cifrar

# Adjuntos que no se envían (programas y páginas que se ejecutan al abrirlos)
EXT_BLOQUEADAS = {".exe", ".bat", ".cmd", ".com", ".msi", ".scr", ".ps1", ".vbs", ".vbe", ".js", ".jse", ".wsf",
                  ".wsh", ".jar", ".hta", ".lnk", ".reg", ".cpl", ".dll", ".sh", ".html", ".htm", ".svg"}
MAX_ADJUNTOS = 5
EXT_LISTAS = {".txt", ".csv", ".xlsx", ".text", ""}


def _lista_ids(valor):
    """'[1, 2]' o '1,2' o [1, 2] -> [1, 2]"""
    if isinstance(valor, (list, tuple)):
        datos = valor
    else:
        texto = str(valor or "").strip()
        try:
            datos = json.loads(texto) if texto.startswith("[") else texto.split(",")
        except ValueError:
            datos = []
    return [int(x) for x in datos if str(x).strip().isdigit()][:5000]


def _bool(valor):
    return str(valor).strip().lower() in ("1", "true", "si", "sí", "on")


# =====================================================================
# Configuración de la cuenta
# =====================================================================
class ConfiguracionSerializer(serializers.Serializer):
    servidor = serializers.CharField(max_length=150)
    puerto = serializers.IntegerField(min_value=1, max_value=65535)
    seguridad = serializers.ChoiceField(choices=["STARTTLS", "SSL", "NINGUNA"])
    usuario = serializers.CharField(max_length=150, required=False, allow_blank=True, allow_null=True)
    clave = serializers.CharField(max_length=200, required=False, allow_blank=True, allow_null=True,
                                  trim_whitespace=False, write_only=True)
    quitar_clave = serializers.BooleanField(required=False, default=False)
    correo_remitente = serializers.EmailField(max_length=150)
    nombre_remitente = serializers.CharField(max_length=150, required=False, allow_blank=True, allow_null=True)
    responder_a = serializers.EmailField(max_length=150, required=False, allow_blank=True, allow_null=True)
    firma = serializers.CharField(max_length=2000, required=False, allow_blank=True, allow_null=True)
    limite_diario = serializers.IntegerField(min_value=1, max_value=100000, required=False, default=1500)
    activo = serializers.BooleanField(required=False, default=True)


class ConfiguracionViewSet(viewsets.GenericViewSet):
    permission_classes = [SoloAdmin]
    serializer_class = ConfiguracionSerializer

    def obtener(self, request):
        return Response(srv.publica(srv.configuracion()))

    def guardar(self, request):
        s = ConfiguracionSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        clave = d.get("clave") or ""
        cambiar = bool(clave) or d.get("quitar_clave", False)
        if not srv.configuracion() and d.get("usuario") and not clave:
            raise ValidationError({"clave": ["Escriba la clave de la cuenta."]})
        llamar_sp("sp_cor_configuracion_guardar", [
            d["servidor"].strip(), d["puerto"], d["seguridad"], (d.get("usuario") or "").strip() or None,
            cambiar, cifrar(clave) if clave else None, d["correo_remitente"], d.get("nombre_remitente"),
            d.get("responder_a") or None, d.get("firma"), d.get("limite_diario", 1500), d.get("activo", True),
            getattr(request.user, "id", None),
        ])
        return Response(srv.publica(srv.configuracion()))

    def prueba(self, request):
        para = str(request.data.get("para") or "").strip()
        try:
            serializers.EmailField().run_validation(para)
        except serializers.ValidationError:
            raise ValidationError({"para": ["Escriba un correo válido para la prueba."]})
        try:
            srv.probar(para)
        except srv.ErrorCorreo as e:
            return Response({"ok": False, "detail": e.mensaje, "configuracion": srv.publica(srv.configuracion())},
                            status=status.HTTP_400_BAD_REQUEST)
        return Response({"ok": True, "detail": f"Se envió el correo de prueba a {para}.",
                         "configuracion": srv.publica(srv.configuracion())})


# =====================================================================
# Personal y avisos
# =====================================================================
class EnvioSerializer(serializers.Serializer):
    asunto = serializers.CharField(max_length=200)
    mensaje = serializers.CharField(max_length=20000, trim_whitespace=False)

    def validate_asunto(self, v):
        # El asunto va en un encabezado del correo: una sola línea
        return " ".join(v.split())


class EnvioViewSet(viewsets.GenericViewSet):
    permission_classes = [SoloAdmin]
    pagination_class = None

    def personal(self, request):
        return Response(srv.personal(True))

    def list(self, request):
        filas, _ = llamar_sp("sp_cor_envios_listar", [request.query_params.get("buscar") or None])
        return Response(filas)

    def _detalle(self, id_envio):
        envio = srv.obtener_envio(id_envio)
        if not envio:
            raise NotFound("El aviso no existe.")
        envio["destinatarios_lista"], _ = llamar_sp("sp_cor_envios_destinatarios_listar", [id_envio])
        adjuntos, _ = llamar_sp("sp_cor_envios_adjuntos_listar", [id_envio])
        envio["adjuntos_lista"] = [{k: v for k, v in a.items() if k != "ruta"} for a in adjuntos]
        return envio

    def retrieve(self, request, id_envio):
        return Response(self._detalle(id_envio))

    def _validar_adjuntos(self, request):
        archivos = request.FILES.getlist("adjuntos")
        if len(archivos) > MAX_ADJUNTOS:
            raise ValidationError({"adjuntos": [f"Adjunte {MAX_ADJUNTOS} archivos como máximo."]})
        limite = getattr(settings, "MUNI_MAX_MB_CORREO", 15)
        if sum(a.size for a in archivos) > limite * 1024 * 1024:
            raise ValidationError({"adjuntos": [f"Los adjuntos pesan más de {limite} MB en total: los servidores de correo "
                                                "los rechazan. Comparta un enlace en el mensaje."]})
        for a in archivos:
            if Path(a.name).suffix.lower() in EXT_BLOQUEADAS:
                raise ValidationError({"adjuntos": [f"«{a.name}» es un tipo de archivo que no se envía por correo "
                                                    "(programas, scripts o páginas web)."]})
        return archivos

    def prueba(self, request):
        """El aviso tal como va a llegar, solo para quien lo escribe."""
        s = EnvioSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        archivos = self._validar_adjuntos(request)
        para = str(request.data.get("para") or "").strip()
        if not para:
            yo = next((p for p in srv.personal(False) if p["id"] == getattr(request.user, "id", None)), None)
            para = yo["correo"] if yo else None
        if not para:
            raise ValidationError({"para": ["Usted no tiene un correo registrado: agréguelo en Mi perfil."]})
        nombre = getattr(request.user, "nombre", None) or ""
        try:
            srv.enviar_correo(para, f"[Prueba] {s.validated_data['asunto']}", s.validated_data["mensaje"],
                              nombre=nombre, adjuntos=[(a.name, a.read(), a.content_type) for a in archivos])
        except srv.ErrorCorreo as e:
            return Response({"ok": False, "detail": e.mensaje}, status=status.HTTP_400_BAD_REQUEST)
        return Response({"ok": True, "detail": f"Se envió la prueba a {para}."})

    def create(self, request):
        s = EnvioSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        archivos = self._validar_adjuntos(request)
        con, sin, texto = srv.resolver_destinatarios(
            todos=_bool(request.data.get("todos")),
            departamentos=_lista_ids(request.data.get("departamentos")),
            personas=_lista_ids(request.data.get("personas")),
        )
        if not con:
            raise ValidationError({"detail": "Ninguna de las personas elegidas tiene un correo registrado."
                                   if sin else "Elija a quién enviarle el aviso."})
        cfg = srv.configuracion()
        if not cfg:
            raise ValidationError({"detail": "Configure primero la cuenta de correo institucional."})
        guardados = []
        try:
            with transaction.atomic():
                _, id_envio = llamar_sp("sp_cor_envios_insertar", [
                    s.validated_data["asunto"].strip(), s.validated_data["mensaje"], texto, srv.remitente(cfg),
                    getattr(request.user, "id", None),
                    json.dumps([{"p": p["id"], "n": p["nombre"], "c": p["correo"]} for p in con], ensure_ascii=False),
                ], con_salida=True)
                for a in archivos:
                    base, ext = os.path.splitext(a.name)
                    ruta = almacen().save(f"correo/{id_envio}/{slugify(base)[:50] or 'adjunto'}-{uuid.uuid4().hex[:8]}"
                                          f"{ext.lower()}", a)
                    guardados.append(ruta)
                    llamar_sp("sp_cor_envios_adjuntos_insertar", [
                        id_envio, Path(a.name).name[:255], ruta, a.size,
                        a.content_type or mimetypes.guess_type(a.name)[0]])
        except Exception:
            for ruta in guardados:
                borrar(ruta)
            raise
        detalle = self._detalle(id_envio)
        detalle["sin_correo"] = [{"id": p["id"], "nombre": p["nombre"], "departamento": p["departamento"]} for p in sin]
        return Response(detalle, status=status.HTTP_201_CREATED)

    def enviar(self, request, id_envio):
        try:
            enviados, error = srv.enviar_lote(id_envio)
        except srv.ErrorCorreo as e:
            enviados, error = 0, e.mensaje
        envio = srv.obtener_envio(id_envio)
        if not envio:
            raise NotFound("El aviso no existe.")
        return Response({"envio": envio, "enviados_ahora": enviados, "error": error})

    def reintentar(self, request, id_envio):
        llamar_sp("sp_cor_envios_reintentar", [id_envio])
        return Response(self._detalle(id_envio))

    def cancelar(self, request, id_envio):
        llamar_sp("sp_cor_envios_cancelar", [id_envio])
        return Response(self._detalle(id_envio))

    def destroy(self, request, id_envio):
        adjuntos, _ = llamar_sp("sp_cor_envios_adjuntos_listar", [id_envio])
        llamar_sp("sp_cor_envios_eliminar", [id_envio])
        for a in adjuntos:
            borrar(a["ruta"])
        return Response(status=status.HTTP_204_NO_CONTENT)

    def perform_content_negotiation(self, request, force=False):
        return super().perform_content_negotiation(request, force=force or self.action == "adjunto")

    def adjunto(self, request, id_envio, num_linea):
        adjuntos, _ = llamar_sp("sp_cor_envios_adjuntos_listar", [id_envio])
        a = next((x for x in adjuntos if x["num_linea"] == num_linea), None)
        if not a:
            raise NotFound("El adjunto no existe.")
        try:
            archivo = almacen().open(a["ruta"], "rb")
        except (FileNotFoundError, OSError):
            raise NotFound("No se encontró el archivo en el servidor.")
        return FileResponse(archivo, as_attachment=True, filename=a["nombre_archivo"],
                            content_type=a["tipo"] or "application/octet-stream")


# =====================================================================
# Listas de correos importadas y comparación con el personal
# =====================================================================
class ListaViewSet(viewsets.GenericViewSet):
    permission_classes = [SoloAdmin]
    pagination_class = None

    def list(self, request):
        filas, _ = llamar_sp("sp_cor_listas_listar", [])
        return Response(filas)

    def _comparacion(self, id_lista, avisos=None):
        filas, _ = llamar_sp("sp_cor_listas_obtener", [id_lista])
        if not filas:
            raise NotFound("La lista no existe.")
        correos, _ = llamar_sp("sp_cor_listas_correos_listar", [id_lista])
        personal = lst.preparar_personal(llamar_sp("sp_cor_personal_listar", [False])[0])
        salida = {"lista": filas[0], **lst.comparar(correos, personal)}
        if avisos is not None:
            salida["avisos"] = avisos
        return salida

    def create(self, request):
        archivo = request.FILES.get("archivo")
        if archivo is None:
            raise ValidationError({"archivo": ["Elija el archivo con los correos."]})
        if Path(archivo.name).suffix.lower() not in EXT_LISTAS:
            raise ValidationError({"archivo": ["Use un archivo .txt, .csv o .xlsx."]})
        if archivo.size > 10 * 1024 * 1024:
            raise ValidationError({"archivo": ["El archivo pesa más de 10 MB."]})
        correos, avisos = lst.leer(archivo.read(), archivo.name)
        if not correos:
            raise ValidationError({"archivo": [avisos[-1] if avisos else "No se encontró ningún correo en el archivo."]})
        descripcion = (request.data.get("descripcion") or "").strip()[:255] or None
        _, id_lista = llamar_sp("sp_cor_listas_insertar", [
            Path(archivo.name).name[:255], descripcion, lst.dominio_principal(correos), getattr(request.user, "id", None),
            json.dumps(correos, ensure_ascii=False)], con_salida=True)
        return Response(self._comparacion(id_lista, avisos), status=status.HTTP_201_CREATED)

    def retrieve(self, request, id_lista):
        return Response(self._comparacion(id_lista))

    def update(self, request, id_lista):
        llamar_sp("sp_cor_listas_actualizar", [id_lista, (request.data.get("descripcion") or "").strip()[:255]])
        return Response(llamar_sp("sp_cor_listas_obtener", [id_lista])[0][0])

    def destroy(self, request, id_lista):
        llamar_sp("sp_cor_listas_eliminar", [id_lista])
        return Response(status=status.HTTP_204_NO_CONTENT)
