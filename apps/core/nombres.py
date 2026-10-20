"""Separa un nombre completo en nombre, primer apellido y segundo apellido.

Hacienda devuelve el nombre de las personas físicas en un solo texto
("MARIA DE LOS ANGELES DE LA O SOLIS"). Esta función lo reparte en los
campos de la tabla:
    nombre    = MARIA DE LOS ANGELES
    apellido1 = DE LA O
    apellido2 = SOLIS

Se tienen en cuenta los apellidos compuestos con partículas (DE, DEL,
DE LA, DE LOS…). No usa Django para poder probarse sola.
"""

PARTICULAS = {"DE", "DEL", "LA", "LAS", "LOS", "SAN", "SANTA", "VAN", "VON", "DA", "DI", "MC", "MAC"}


def _palabras(texto):
    return [p for p in (texto or "").upper().replace(",", " ").split() if p]


def _apellido_desde_el_final(palabras):
    """Saca el último apellido (con sus partículas) y devuelve (apellido, resto)."""
    i = len(palabras) - 1
    while i > 0 and palabras[i - 1] in PARTICULAS:
        i -= 1
    return " ".join(palabras[i:]), palabras[:i]


def _apellido_desde_el_inicio(palabras):
    """Saca el primer apellido (con sus partículas) y devuelve (apellido, resto)."""
    i = 0
    while i < len(palabras) - 1 and palabras[i] in PARTICULAS:
        i += 1
    return " ".join(palabras[:i + 1]), palabras[i + 1:]


def separar_nombre(completo, apellidos_primero=False):
    """Devuelve {"nombre", "apellido1", "apellido2"} (los apellidos pueden ser None).

    apellidos_primero=False: "NOMBRE(S) APELLIDO1 APELLIDO2"
    apellidos_primero=True:  "APELLIDO1 APELLIDO2 NOMBRE(S)"
    """
    palabras = _palabras(completo)
    resultado = {"nombre": " ".join(palabras), "apellido1": None, "apellido2": None}
    if len(palabras) < 2:
        return resultado

    if apellidos_primero:
        apellido1, resto = _apellido_desde_el_inicio(palabras)
        apellido2 = None
        if len(resto) >= 2:  # queda al menos una palabra para el nombre
            apellido2, resto = _apellido_desde_el_inicio(resto)
        if not resto:        # no alcanzó: la última palabra es el nombre
            return separar_nombre(" ".join(palabras), apellidos_primero=False)
        return {"nombre": " ".join(resto), "apellido1": apellido1, "apellido2": apellido2}

    apellido2, resto = _apellido_desde_el_final(palabras)
    if not resto:            # todo era un solo apellido compuesto: se deja como nombre
        return resultado
    if len(resto) == 1:      # "JUAN PEREZ": nombre y un apellido
        return {"nombre": resto[0], "apellido1": apellido2, "apellido2": None}
    apellido1, resto2 = _apellido_desde_el_final(resto)
    if not resto2:           # no queda nada para el nombre: un solo apellido
        return {"nombre": " ".join(resto), "apellido1": apellido2, "apellido2": None}
    return {"nombre": " ".join(resto2), "apellido1": apellido1, "apellido2": apellido2}
