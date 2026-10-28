"""Envío de correos con la cuenta institucional configurada en el sistema.

La función del sistema para enviar un correo desde cualquier módulo es
``enviar_correo``:

    from apps.correo.servicio import enviar_correo, ErrorCorreo
    try:
        enviar_correo("ana.mora@grecia.go.cr", "Mantenimiento de la red",
                      "El sábado no habrá internet de 8:00 a 12:00.", nombre="ANA MORA")
    except ErrorCorreo as e:
        ...  # e.mensaje explica qué pasó, en palabras

Usa la cuenta de Correo institucional > Configuración (servidor SMTP,
usuario y clave cifrada). Los avisos al personal (cor_envios) se envían de
a lotes con ``enviar_lote``: un correo por persona, así cada uno sabe que
el aviso es para él y queda el resultado de cada envío.
"""
import html
import logging
import mimetypes
import re
import smtplib
import socket
import ssl
from email.utils import formataddr, parseaddr

from django.core.mail import EmailMultiAlternatives, get_connection
from django.core.mail.backends.smtp import EmailBackend

from apps.core.archivos import almacen
from apps.core.db import llamar_sp

from .cifrado import ClaveIlegible, descifrar

logger = logging.getLogger(__name__)

TAMANO_LOTE = 20          # correos por llamada a enviar_lote (la pantalla repite hasta terminar)
ESPERA_SEGUNDOS = 25      # tiempo máximo de espera del servidor de correo

# Cuentas comunes (la pantalla de configuración las ofrece de ejemplo)
PROVEEDORES = {
    "google": {"nombre": "Google Workspace (Gmail)", "servidor": "smtp.gmail.com", "puerto": 587, "seguridad": "STARTTLS"},
    "microsoft": {"nombre": "Microsoft 365 (Outlook)", "servidor": "smtp.office365.com", "puerto": 587, "seguridad": "STARTTLS"},
}


class ErrorCorreo(Exception):
    """Error al enviar, con un mensaje en palabras. ``de_conexion`` = el
    problema es de la cuenta o del servidor (no de un destinatario): no
    tiene sentido seguir con los demás."""

    def __init__(self, mensaje, de_conexion=True):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.de_conexion = de_conexion


# --------------------------------------------------------------- configuración
def configuracion():
    filas, _ = llamar_sp("sp_cor_configuracion_obtener", [])
    return filas[0] if filas else None


def publica(cfg):
    """La configuración sin la clave (lo que sale por la API)."""
    if not cfg:
        return {"configurada": False, "proveedores": PROVEEDORES}
    salida = {k: v for k, v in cfg.items() if k != "clave_cifrada"}
    salida["tiene_clave"] = bool(cfg.get("clave_cifrada"))
    salida["activo"] = bool(cfg.get("activo"))
    salida["prueba_ok"] = None if cfg.get("prueba_ok") is None else bool(cfg["prueba_ok"])
    salida["configurada"] = True
    salida["remitente"] = remitente(cfg)
    salida["proveedores"] = PROVEEDORES
    salida["enviados_hoy"] = enviados_hoy()
    return salida


def remitente(cfg):
    return formataddr((cfg.get("nombre_remitente") or "", cfg["correo_remitente"]))


def conexion(cfg):
    """Conexión SMTP de Django con los datos de la cuenta institucional."""
    clave = None
    if cfg.get("clave_cifrada"):
        try:
            clave = descifrar(cfg["clave_cifrada"])
        except ClaveIlegible as e:
            raise ErrorCorreo(str(e))
    return get_connection(
        "django.core.mail.backends.smtp.EmailBackend",
        host=cfg["servidor"], port=int(cfg["puerto"]),
        username=cfg.get("usuario") or None, password=clave,
        use_tls=cfg["seguridad"] == "STARTTLS", use_ssl=cfg["seguridad"] == "SSL",
        timeout=ESPERA_SEGUNDOS, fail_silently=False,
    )


def texto_error(e, cfg=None):
    """Error del servidor de correo -> (mensaje en palabras, de_conexion)."""
    donde = f"{cfg['servidor']}:{cfg['puerto']}" if cfg else "el servidor de correo"
    if isinstance(e, ErrorCorreo):
        return e.mensaje, e.de_conexion
    if isinstance(e, smtplib.SMTPAuthenticationError):
        return ("El servidor de correo no aceptó el usuario o la clave. En Google Workspace use una contraseña de "
                "aplicación (la cuenta debe tener la verificación en dos pasos)."), True
    if isinstance(e, smtplib.SMTPSenderRefused):
        return f"El servidor no permite enviar como {e.sender}: {_respuesta(e.smtp_error)}", True
    if isinstance(e, smtplib.SMTPRecipientsRefused):
        detalle = "; ".join(f"{parseaddr(c)[1] or c}: {_respuesta(r[1])}" for c, r in list(e.recipients.items())[:2])
        return f"El servidor rechazó la dirección ({detalle}).", False
    if isinstance(e, smtplib.SMTPDataError):
        detalle = _respuesta(e.smtp_error)
        if re.search(r"quota|limit|rate|too many", detalle, re.I):
            return f"La cuenta llegó al límite de envío del servidor de correo: {e.smtp_code} {detalle}", True
        return f"El servidor rechazó el mensaje: {e.smtp_code} {detalle}", e.smtp_code in (421, 451, 454)
    if isinstance(e, smtplib.SMTPNotSupportedError):
        return (f"{donde} no acepta esa forma de conexión. Revise la seguridad: STARTTLS va con el puerto 587 y "
                "SSL con el 465."), True
    if isinstance(e, smtplib.SMTPServerDisconnected):
        return f"{donde} cerró la conexión. Revise el puerto y la seguridad (STARTTLS 587 o SSL 465).", True
    if isinstance(e, ssl.SSLError):
        return (f"Falló la conexión segura con {donde}. Revise la seguridad: STARTTLS va con el puerto 587 y SSL "
                "con el 465."), True
    if isinstance(e, (socket.timeout, TimeoutError)):
        return f"{donde} no respondió a tiempo. Revise el servidor, el puerto y que el firewall permita la salida.", True
    if isinstance(e, socket.gaierror):
        return f"No se encontró el servidor {cfg['servidor'] if cfg else ''}. Revise el nombre.", True
    if isinstance(e, ConnectionRefusedError):
        return f"{donde} rechazó la conexión. Revise el puerto.", True
    if isinstance(e, OSError):
        return f"No se pudo conectar con {donde}: {e.strerror or e}.", True
    if isinstance(e, smtplib.SMTPException):
        return f"El servidor de correo respondió con un error: {e}", True
    return f"No se pudo enviar: {e}", True


def _respuesta(r):
    return r.decode("utf-8", "replace") if isinstance(r, bytes) else str(r)


# --------------------------------------------------------------- el mensaje
_URL = re.compile(r"(https?://[^\s<]+[^\s<.,;:!?)\]])")


def _parrafos_html(texto):
    bloques = [b.strip("\n") for b in re.split(r"\n\s*\n", (texto or "").replace("\r\n", "\n")) if b.strip()]
    salida = []
    for b in bloques:
        b = _URL.sub(r'<a href="\1" style="color:#1E5C45">\1</a>', html.escape(b)).replace("\n", "<br>")
        salida.append(f'<p style="margin:0 0 14px;line-height:1.5">{b}</p>')
    return "".join(salida)


def primer_nombre(nombre):
    """'ANA LUCÍA MORA SOLÍS' -> 'Ana' (para el saludo {nombre})"""
    partes = (nombre or "").split()
    return partes[0].capitalize() if partes else ""


def personalizar(texto, nombre):
    return (texto or "").replace("{nombre_completo}", (nombre or "").title()).replace("{nombre}", primer_nombre(nombre))


def armar_mensaje(cfg, para, asunto, texto, *, nombre=None, adjuntos=(), conexion_smtp=None):
    """EmailMultiAlternatives con el texto y una versión HTML sencilla.
    ``adjuntos``: [(nombre_archivo, contenido_bytes, tipo)]."""
    texto = personalizar(texto, nombre)
    firma = (cfg.get("firma") or "").strip()
    cuerpo = texto.rstrip() + (f"\n\n-- \n{firma}" if firma else "")
    institucion = html.escape(cfg.get("nombre_remitente") or cfg["correo_remitente"])
    cuerpo_html = (
        '<div style="font-family:Segoe UI,Arial,sans-serif;font-size:15px;color:#17201C;max-width:640px">'
        f'<div style="border-top:4px solid #1E5C45;padding:14px 0 6px;font-weight:700;color:#1E5C45">{institucion}</div>'
        f'<div style="padding:8px 0">{_parrafos_html(texto)}</div>'
        + (f'<div style="border-top:1px solid #D8DFDA;padding-top:10px;color:#44514B;font-size:13px">{_parrafos_html(firma)}</div>'
           if firma else "")
        + '</div>')
    m = EmailMultiAlternatives(
        subject=asunto, body=cuerpo, from_email=remitente(cfg),
        to=[formataddr(((nombre or "").title(), para))],
        reply_to=[cfg["responder_a"]] if cfg.get("responder_a") else None,
        connection=conexion_smtp,
        headers={"X-Mailer": "Gestion Municipal"},
    )
    m.attach_alternative(cuerpo_html, "text/html")
    for nombre_archivo, contenido, tipo in adjuntos:
        m.attach(nombre_archivo, contenido, tipo or mimetypes.guess_type(nombre_archivo)[0] or "application/octet-stream")
    return m


def _cfg_lista(cfg):
    if not cfg:
        raise ErrorCorreo("Todavía no se ha configurado la cuenta de correo institucional "
                          "(Correo institucional > Configuración).")
    if not cfg.get("activo"):
        raise ErrorCorreo("El envío de correos está pausado en la configuración de la cuenta institucional.")
    return cfg


def enviar_correo(para, asunto, texto, *, nombre=None, adjuntos=(), cfg=None):
    """La función del sistema para enviar un correo con la cuenta
    institucional. ``para``: un correo. Lanza ErrorCorreo si no se pudo."""
    cfg = _cfg_lista(cfg or configuracion())
    try:
        with conexion(cfg) as smtp:
            armar_mensaje(cfg, para, asunto, texto, nombre=nombre, adjuntos=adjuntos, conexion_smtp=smtp).send()
    except Exception as e:  # noqa: BLE001 - se traduce a un mensaje claro
        mensaje, de_conexion = texto_error(e, cfg)
        logger.warning("No se pudo enviar el correo a %s: %s", para, e)
        raise ErrorCorreo(mensaje, de_conexion)


def probar(para):
    """Envía el correo de prueba de la configuración y guarda el resultado."""
    cfg = configuracion()
    if not cfg:
        raise ErrorCorreo("Guarde primero la configuración de la cuenta.")
    texto = ("Este es un correo de prueba del sistema de gestión municipal.\n\n"
             "Si lo recibió, la cuenta institucional quedó bien configurada y el sistema ya puede enviar avisos "
             "al personal.")
    try:
        enviar_correo(para, "Correo de prueba del sistema", texto, cfg={**cfg, "activo": True})
    except ErrorCorreo as e:
        llamar_sp("sp_cor_configuracion_resultado_prueba", [False, e.mensaje])
        raise
    llamar_sp("sp_cor_configuracion_resultado_prueba", [True, f"Se envió un correo de prueba a {para}."])


# --------------------------------------------------------------- avisos
def leer_adjuntos(id_envio):
    filas, _ = llamar_sp("sp_cor_envios_adjuntos_listar", [id_envio])
    salida = []
    for a in filas:
        try:
            with almacen().open(a["ruta"], "rb") as f:
                salida.append((a["nombre_archivo"], f.read(), a["tipo"]))
        except (FileNotFoundError, OSError):
            raise ErrorCorreo(f"No se encontró en el servidor el adjunto «{a['nombre_archivo']}».")
    return salida


def enviados_hoy():
    return int(llamar_sp("sp_cor_enviados_hoy", [])[0][0]["total"])


def enviar_lote(id_envio, limite=TAMANO_LOTE):
    """Envía los siguientes destinatarios pendientes de un aviso, un correo
    por persona, por una sola conexión. Devuelve (enviados_ahora, error):
    error es None o el mensaje que detuvo el lote (los que faltan quedan
    pendientes para continuar después)."""
    filas, _ = llamar_sp("sp_cor_envios_obtener", [id_envio])
    if not filas:
        raise ErrorCorreo("El aviso no existe.")
    envio = filas[0]
    cfg = _cfg_lista(configuracion())
    disponibles = int(cfg["limite_diario"]) - enviados_hoy()
    if disponibles <= 0:
        return 0, (f"Ya se enviaron hoy los {cfg['limite_diario']} correos que permite el límite diario de la cuenta. "
                   "Los que faltan quedan pendientes: continúe mañana.")
    pendientes, _ = llamar_sp("sp_cor_envios_pendientes", [id_envio, min(limite, disponibles)])
    if not pendientes:
        llamar_sp("sp_cor_envios_recalcular", [id_envio])
        return 0, None
    adjuntos = leer_adjuntos(id_envio)
    enviados = 0
    try:
        smtp = conexion(cfg)
        smtp.open()
    except Exception as e:  # noqa: BLE001
        return 0, texto_error(e, cfg)[0]
    try:
        for d in pendientes:
            try:
                armar_mensaje(cfg, d["correo"], envio["asunto"], envio["mensaje"], nombre=d["nombre"],
                              adjuntos=adjuntos, conexion_smtp=smtp).send()
            except Exception as e:  # noqa: BLE001
                mensaje, de_conexion = texto_error(e, cfg)
                if de_conexion:
                    # Problema de la cuenta o del servidor: se detiene y los demás quedan pendientes
                    return enviados, mensaje
                llamar_sp("sp_cor_envios_marcar", [id_envio, d["num_linea"], False, mensaje])
                continue
            llamar_sp("sp_cor_envios_marcar", [id_envio, d["num_linea"], True, None])
            enviados += 1
    finally:
        try:
            smtp.close()
        except Exception:  # noqa: BLE001
            pass
    return enviados, None


def obtener_envio(id_envio):
    filas, _ = llamar_sp("sp_cor_envios_obtener", [id_envio])
    return filas[0] if filas else None


# --------------------------------------------------------------- destinatarios
def personal(solo_activos=True):
    filas, _ = llamar_sp("sp_cor_personal_listar", [solo_activos])
    salida = []
    for p in filas:
        correos = []
        for parte in filter(None, (p.get("correos") or "").split(";")):
            correo, _, tipo = parte.partition("|")
            if correo.strip():
                correos.append({"correo": correo.strip().lower(), "tipo": tipo or None})
        salida.append({"id": p["id"], "nombre": p["nombre_completo"], "cod_departamento": p["cod_departamento"],
                       "departamento": p["departamento"], "activo": bool(p["activo"]), "usuario_red": p["usuario_red"],
                       "correo": correos[0]["correo"] if correos else None, "correos": correos})
    return salida


def resolver_destinatarios(todos=False, departamentos=(), personas=()):
    """Personal activo elegido -> (con_correo, sin_correo, texto en palabras)."""
    gente = personal(True)
    departamentos = {int(d) for d in departamentos}
    personas = {int(p) for p in personas}
    dep = lambda p: p["cod_departamento"] or 0       # 0 = sin departamento
    elegidos = [p for p in gente if todos or dep(p) in departamentos or p["id"] in personas]
    con = [p for p in elegidos if p["correo"]]
    sin = [p for p in elegidos if not p["correo"]]
    if todos:
        texto = "Todo el personal"
    else:
        nombres_dep = sorted({p["departamento"] or "Sin departamento" for p in gente if dep(p) in departamentos})
        sueltos = [p for p in gente if p["id"] in personas and dep(p) not in departamentos]
        partes = list(nombres_dep)
        if len(sueltos) == 1:
            partes.append(sueltos[0]["nombre"])
        elif sueltos:
            partes.append(f"{len(sueltos)} personas")
        texto = ", ".join(partes[:-1]) + (" y " if len(partes) > 1 else "") + partes[-1] if partes else ""
    return con, sin, texto[:255]
