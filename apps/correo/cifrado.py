"""Cifrado de la clave del servidor de correo antes de guardarla en la base.

La clave se cifra con una llave que sale de SECRET_KEY de Django (o de
MUNI_CORREO_LLAVE, si está en settings.py): quien vea la base no puede
leerla. Solo usa la biblioteca estándar de Python:
  - cifrado: HMAC-SHA256 en modo contador (un flujo que se combina con XOR)
    con un número aleatorio distinto cada vez;
  - integridad: HMAC-SHA256 del resultado (si alguien lo cambia, o si
    cambió SECRET_KEY, no se descifra).
Formato guardado: v1$<base64 de nonce(16) + cifrado + etiqueta(32)>.

Si se cambia SECRET_KEY (o MUNI_CORREO_LLAVE), la clave guardada deja de
servir: hay que volver a escribirla en Correo institucional > Configuración.
"""
import base64
import binascii
import hashlib
import hmac
import os

from django.conf import settings

VERSION = "v1"


class ClaveIlegible(Exception):
    """La clave guardada no se puede descifrar (cambió SECRET_KEY o está dañada)."""


def _llaves():
    base = getattr(settings, "MUNI_CORREO_LLAVE", None) or settings.SECRET_KEY
    maestra = hashlib.sha256(f"muni.correo:{base}".encode("utf-8")).digest()
    return (hmac.new(maestra, b"cifrar", hashlib.sha256).digest(),
            hmac.new(maestra, b"firmar", hashlib.sha256).digest())


def _flujo(llave, nonce, largo):
    salida = bytearray()
    contador = 0
    while len(salida) < largo:
        salida += hmac.new(llave, nonce + contador.to_bytes(8, "big"), hashlib.sha256).digest()
        contador += 1
    return bytes(salida[:largo])


def cifrar(texto):
    datos = texto.encode("utf-8")
    llave_cifrar, llave_firmar = _llaves()
    nonce = os.urandom(16)
    cifrado = bytes(a ^ b for a, b in zip(datos, _flujo(llave_cifrar, nonce, len(datos))))
    etiqueta = hmac.new(llave_firmar, nonce + cifrado, hashlib.sha256).digest()
    return f"{VERSION}${base64.urlsafe_b64encode(nonce + cifrado + etiqueta).decode('ascii')}"


def descifrar(guardado):
    try:
        version, b64 = (guardado or "").split("$", 1)
        crudo = base64.urlsafe_b64decode(b64.encode("ascii"))
    except (ValueError, binascii.Error, UnicodeEncodeError):
        raise ClaveIlegible("La clave guardada está dañada.")
    if version != VERSION or len(crudo) < 48:
        raise ClaveIlegible("La clave guardada está dañada.")
    nonce, cifrado, etiqueta = crudo[:16], crudo[16:-32], crudo[-32:]
    llave_cifrar, llave_firmar = _llaves()
    if not hmac.compare_digest(hmac.new(llave_firmar, nonce + cifrado, hashlib.sha256).digest(), etiqueta):
        raise ClaveIlegible("La clave guardada no se puede leer (¿cambió SECRET_KEY?). Vuelva a escribirla en la configuración.")
    return bytes(a ^ b for a, b in zip(cifrado, _flujo(llave_cifrar, nonce, len(cifrado)))).decode("utf-8")
