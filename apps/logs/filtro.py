"""Filtro de eventos al estilo Wireshark.

Ejemplos:
    ip.src == 10.1.10.154
    ip == 10.1.12.0/24 and accion == denegado
    dominio contains google or dominio contains microsoft
    puerto_destino in {80 443} and not tipo == "Firewall"
    src_ip == 10.1.10.172 && log_subtype == Denied      (nombres de Sophos)
    datos.hb_status == "No Heartbeat"                   (cualquier campo original)
    fecha >= "2026-10-22 15:00" and fecha < 2026-10-23
    equipo_origen                                       (el origen es un equipo del inventario)
    not equipo_origen and ip_origen == 10.0.0.0/8       (IP internas que no están en el inventario)
    google                                              (texto suelto: busca en todo)

Operadores: == != > < >= <= (también eq ne gt lt ge le), contains,
matches (expresión regular), in {a b c}; and / && , or / || , not / !
y paréntesis. Un campo solo (sin operador) = que tenga dato.

El resultado es un pedazo de WHERE para log_eventos (alias e). Solo usa
columnas de esta lista y los valores van escapados: el usuario no puede
escribir SQL. Los procedimientos sp_log_eventos_* lo reciben armado.
"""
import ipaddress
import re
from datetime import datetime

from .esquema import ALIAS_FILTRO, CAMPO, CAMPOS_AMBOS, NOMBRES


class ErrorFiltro(ValueError):
    def __init__(self, mensaje, posicion=0):
        super().__init__(mensaje)
        self.mensaje = mensaje
        self.posicion = posicion


# ------------------------------------------------------------- tokens
_TOKEN = re.compile(r"""
    \s*(?:
      (?P<str>"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')
    | (?P<op>==|!=|>=|<=|&&|\|\||[()<>{},!~=])
    | (?P<pal>[^\s(){},!=<>~"']+)
    )""", re.X)

PALABRAS_OP = {"eq": "==", "ne": "!=", "gt": ">", "lt": "<", "ge": ">=", "le": "<=",
               "contains": "contains", "matches": "matches", "in": "in"}


def _tokens(texto):
    pos, salida = 0, []
    while pos < len(texto):
        if not texto[pos:].strip():
            break
        m = _TOKEN.match(texto, pos)
        if not m or m.end() == pos:
            raise ErrorFiltro(f"No entiendo «{texto[pos:].strip()[:15]}».", pos)
        inicio = m.start(m.lastgroup)
        if m.group("str") is not None:
            crudo = m.group("str")
            # Solo se quitan las barras de \" \' y \\ (las de una expresión regular quedan)
            valor = re.sub(r"\\([\"'\\])", r"\1", crudo[1:-1])
            salida.append(("str", valor, inicio))
        elif m.group("op") is not None:
            op = m.group("op")
            salida.append(("op", "==" if op == "=" else op, inicio))
        else:
            pal = m.group("pal")
            baja = pal.lower()
            if baja in ("and", "or", "not"):
                salida.append((baja, baja, inicio))
            elif baja in PALABRAS_OP:
                salida.append(("op", PALABRAS_OP[baja], inicio))
            else:
                salida.append(("pal", pal, inicio))
        pos = m.end()
    return salida


# ------------------------------------------------------- campos válidos
VIRTUALES = {
    "equipo_origen": "Origen es un equipo del inventario (por IP o MAC)",
    "equipo_destino": "Destino es un equipo del inventario (por IP, IP de NAT o MAC)",
    "equipo": "Origen o destino es un equipo del inventario",
    "persona": "El usuario del log es una persona del sistema",
    "con_agente": "El origen tiene el agente de Microclaudia (por IP o MAC, en el último listado importado)",
}


def resolver_campo(nombre, alias_fuente=None):
    """Nombre escrito -> (clase, dato). clase: columna | ambos | datos | virtual | importacion."""
    n = nombre.lower()
    if n in CAMPO:
        return "columna", n
    if n in CAMPOS_AMBOS:
        return "ambos", CAMPOS_AMBOS[n]
    if n in ALIAS_FILTRO:
        return "columna", ALIAS_FILTRO[n]
    if n in VIRTUALES:
        return "virtual", n
    if n in ("importacion", "id_importacion"):
        return "importacion", n
    if n in ("fuente", "programa"):
        return "fuente", n
    if n in ("id_evento", "evento"):
        return "evento", n
    if n.startswith("datos."):
        clave = n[6:]
        if not re.fullmatch(r"[a-z0-9_.\-]{1,64}", clave):
            return None
        return "datos", clave
    if alias_fuente and n in alias_fuente:
        return "columna", alias_fuente[n]
    return None


# ------------------------------------------------------------- literales
def lit(valor):
    """Literal SQL escapado. Los procedimientos de logs se crean sin
    NO_BACKSLASH_ESCAPES, así que la barra invertida se escapa."""
    if isinstance(valor, bool):
        return "TRUE" if valor else "FALSE"
    if isinstance(valor, int):
        return str(valor)
    texto = str(valor).replace("\x00", "")
    texto = texto.replace("\\", "\\\\").replace("'", "''").replace("\n", "\\n").replace("\r", "\\r").replace("\x1a", "\\Z")
    return f"'{texto}'"


def _like(valor):
    return lit("%" + str(valor).replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%")


ACCIONES = {
    "permitido": "PERMITIDO", "permitidos": "PERMITIDO", "allowed": "PERMITIDO", "allow": "PERMITIDO",
    "accept": "PERMITIDO", "aceptado": "PERMITIDO",
    "denegado": "DENEGADO", "denegados": "DENEGADO", "denied": "DENEGADO", "deny": "DENEGADO",
    "bloqueado": "DENEGADO", "blocked": "DENEGADO", "drop": "DENEGADO", "reject": "DENEGADO", "rechazado": "DENEGADO",
    "otro": "OTRO", "otros": "OTRO",
}
SI = {"si", "sí", "true", "1", "yes", "verdadero"}
NO = {"no", "false", "0", "falso"}

TEXTO_LIBRE = ["dominio", "url", "regla_nombre", "usuario", "categoria", "aplicacion", "tipo", "politica_web",
               "ip_origen", "ip_destino", "id_conexion", "motivo", "actividad", "interfaz_entrada", "interfaz_salida",
               "nombre_equipo", "sistema_operativo"]


class _Analizador:
    def __init__(self, texto, alias_fuente=None):
        self.texto = texto
        self.t = _tokens(texto)
        self.i = 0
        self.alias = alias_fuente or {}
        self.usados = set()

    # ----------------------------------------------------------- utilidades
    def ver(self, k=0):
        j = self.i + k
        return self.t[j] if j < len(self.t) else None

    def pos(self):
        tok = self.ver()
        return tok[2] if tok else len(self.texto)

    def tomar(self, clase=None, valor=None):
        tok = self.ver()
        if tok is None or (clase and tok[0] != clase) or (valor and tok[1] != valor):
            esperado = valor or {"pal": "un valor", "op": "un operador"}.get(clase, clase)
            hay = f"«{tok[1]}»" if tok else "el final"
            raise ErrorFiltro(f"Se esperaba {esperado} y hay {hay}.", self.pos())
        self.i += 1
        return tok

    # ------------------------------------------------------------- gramática
    def analizar(self):
        if not self.t:
            return None
        sql = self.o()
        if self.ver() is not None:
            tok = self.ver()
            raise ErrorFiltro(f"Sobra «{tok[1]}»: una con otra se unen con and / or.", tok[2])
        return sql

    def o(self):
        partes = [self.y()]
        while self.ver() and (self.ver()[0] == "or" or self.ver()[1] == "||"):
            self.i += 1
            partes.append(self.y())
        return partes[0] if len(partes) == 1 else "(" + " OR ".join(partes) + ")"

    def y(self):
        partes = [self.no()]
        while self.ver() and (self.ver()[0] == "and" or self.ver()[1] == "&&"):
            self.i += 1
            partes.append(self.no())
        return partes[0] if len(partes) == 1 else "(" + " AND ".join(partes) + ")"

    def no(self):
        tok = self.ver()
        if tok and (tok[0] == "not" or (tok[0] == "op" and tok[1] == "!")):
            self.i += 1
            # COALESCE: un campo vacío (NULL) cuenta como "no cumple", así
            # not dominio == x también trae los eventos sin dominio (como Wireshark)
            return f"NOT COALESCE(({self.no()}), FALSE)"
        return self.primario()

    def primario(self):
        tok = self.ver()
        if tok is None:
            raise ErrorFiltro("El filtro está incompleto.", len(self.texto))
        if tok[0] == "op" and tok[1] == "(":
            self.i += 1
            sql = self.o()
            self.tomar("op", ")")
            return sql
        if tok[0] not in ("pal", "str"):
            raise ErrorFiltro(f"No se esperaba «{tok[1]}».", tok[2])
        siguiente = self.ver(1)
        es_comparacion = siguiente and siguiente[0] == "op" and siguiente[1] in ("==", "!=", ">", "<", ">=", "<=", "contains", "matches", "in", "~")
        if tok[0] == "pal":
            campo = resolver_campo(tok[1], self.alias)
            if campo:
                self.i += 1
                # Se anota el campo común (ip.src y src_ip -> ip_origen)
                clase, dato = campo
                if clase == "columna":
                    self.usados.add(dato)
                elif clase == "ambos":
                    self.usados.update(dato)
                elif clase == "datos":
                    self.usados.add(f"datos.{dato}")
                else:
                    self.usados.add(tok[1].lower())
                if es_comparacion:
                    op = self.tomar("op")[1]
                    return self.comparacion(campo, tok, "matches" if op == "~" else op)
                return self.existe(campo)
            if es_comparacion:
                raise ErrorFiltro(f"No existe el campo «{tok[1]}». Vea la lista de campos.", tok[2])
        self.i += 1
        return self.texto_libre(tok[1])

    # ------------------------------------------------------------ valores
    def valor(self):
        tok = self.ver()
        if tok is None or tok[0] not in ("pal", "str"):
            raise ErrorFiltro("Falta el valor.", self.pos())
        self.i += 1
        return tok[1], tok[2]

    def lista(self):
        self.tomar("op", "{")
        valores = []
        while self.ver() and not (self.ver()[0] == "op" and self.ver()[1] == "}"):
            if self.ver()[0] == "op" and self.ver()[1] == ",":
                self.i += 1
                continue
            valores.append(self.valor())
        self.tomar("op", "}")
        if not valores:
            raise ErrorFiltro("La lista { } está vacía.", self.pos())
        return valores

    # -------------------------------------------------------- comparaciones
    def existe(self, campo):
        clase, dato = campo
        if clase == "columna":
            return f"e.{dato} IS NOT NULL"
        if clase == "ambos":
            return "(" + " OR ".join(f"e.{c} IS NOT NULL" for c in dato) + ")"
        if clase == "datos":
            return f"JSON_VALUE(e.datos, '$.\"{dato}\"') IS NOT NULL"
        if clase == "virtual":
            return _virtual(dato)
        return "TRUE"

    def comparacion(self, campo, tok_campo, op):
        clase, dato = campo
        if op == "in":
            valores = self.lista()
            partes = [self.una(clase, dato, "==", v, p) for v, p in valores]
            return "(" + " OR ".join(partes) + ")"
        v, p = self.valor()
        return self.una(clase, dato, op, v, p)

    def una(self, clase, dato, op, valor, posicion):
        if clase == "ambos":
            partes = [self.una("columna", c, "==" if op == "!=" else op, valor, posicion) for c in dato]
            # ip / mac también buscan en todas las direcciones del evento
            # (los equipos de Microclaudia tienen varias IP y MAC)
            tipo_dir = "IP" if "ip_origen" in dato else "MAC" if "mac_origen" in dato else None
            if tipo_dir:
                cond = (self.ip if tipo_dir == "IP" else self.mac)("d.direccion", "==" if op == "!=" else op, valor, posicion)
                partes.append(f"EXISTS (SELECT 1 FROM log_direcciones d WHERE d.id_evento = e.id_evento"
                              f" AND d.tipo = '{tipo_dir}' AND {cond})")
            sql = "(" + " OR ".join(partes) + ")"
            return f"NOT COALESCE({sql}, FALSE)" if op == "!=" else sql
        if clase == "virtual":
            if op not in ("==", "!="):
                raise ErrorFiltro("Con este campo use == si / == no.", posicion)
            sí = valor.lower() in SI
            if not sí and valor.lower() not in NO:
                raise ErrorFiltro("Escriba si o no.", posicion)
            sql = _virtual(dato)
            return sql if sí == (op == "==") else f"NOT {sql}"
        if clase == "fuente":
            if op not in ("==", "!="):
                raise ErrorFiltro("Con el programa use == o != (sophos, microclaudia).", posicion)
            return f"e.fuente {'=' if op == '==' else '<>'} {lit(valor.strip().upper())}"
        if clase in ("importacion", "evento"):
            col = "e.id_importacion" if clase == "importacion" else "e.id_evento"
            return self.numerica(col, op, valor, posicion)
        if clase == "datos":
            expr = f"JSON_VALUE(e.datos, '$.\"{dato}\"')"
            return self.textual(expr, op, valor, posicion)
        tipo = CAMPO[dato][3]
        col = f"e.{dato}"
        if tipo == "ip":
            return self.ip(col, op, valor, posicion)
        if tipo == "mac":
            return self.mac(col, op, valor, posicion)
        if tipo in ("puerto", "numero"):
            return self.numerica(col, op, valor, posicion)
        if tipo == "fecha":
            return self.fecha(col, op, valor, posicion)
        if tipo == "accion":
            if op not in ("==", "!="):
                raise ErrorFiltro("Con acción use == o != (permitido, denegado u otro).", posicion)
            a = ACCIONES.get(valor.lower())
            if not a:
                raise ErrorFiltro(f"«{valor}» no es una acción: use permitido, denegado u otro.", posicion)
            return f"e.accion {'=' if op == '==' else '<>'} {lit(a)}"
        return self.textual(col, op, valor, posicion)

    def textual(self, col, op, valor, posicion):
        if op == "contains":
            return f"{col} LIKE {_like(valor)}"
        if op == "matches":
            if not valor:
                raise ErrorFiltro("La expresión regular está vacía.", posicion)
            return f"{col} REGEXP {lit(valor)}"
        sql_op = {"==": "=", "!=": "<>", ">": ">", "<": "<", ">=": ">=", "<=": "<="}[op]
        if op == "!=":
            return f"({col} IS NULL OR {col} <> {lit(valor)})"
        return f"{col} {sql_op} {lit(valor)}"

    def numerica(self, col, op, valor, posicion):
        if op in ("contains", "matches"):
            return f"CAST({col} AS CHAR) LIKE {_like(valor)}"
        if not re.fullmatch(r"-?\d{1,18}", valor.replace(",", "")):
            raise ErrorFiltro(f"«{valor}» no es un número.", posicion)
        n = int(valor.replace(",", ""))
        sql_op = {"==": "=", "!=": "<>", ">": ">", "<": "<", ">=": ">=", "<=": "<="}[op]
        if op == "!=":
            return f"({col} IS NULL OR {col} <> {n})"
        return f"{col} {sql_op} {n}"

    def ip(self, col, op, valor, posicion):
        if op in ("contains", "matches"):
            return self.textual(col, op, valor, posicion)
        if "/" in valor:
            try:
                red = ipaddress.ip_network(valor, strict=False)
            except ValueError:
                raise ErrorFiltro(f"«{valor}» no es una red (ejemplo: 10.1.10.0/24).", posicion) from None
            if red.version != 4:
                raise ErrorFiltro("Las redes con / solo se pueden usar con IPv4.", posicion)
            if op not in ("==", "!="):
                raise ErrorFiltro("Con una red use == o !=.", posicion)
            dentro = (f"(INET_ATON({col}) BETWEEN {int(red.network_address)} AND {int(red.broadcast_address)})")
            return dentro if op == "==" else f"({col} IS NULL OR NOT {dentro})"
        try:
            dir_ip = ipaddress.ip_address(valor)
        except ValueError:
            raise ErrorFiltro(f"«{valor}» no es una dirección IP. Para buscar un pedazo use contains.", posicion) from None
        if op in (">", "<", ">=", "<="):
            if dir_ip.version != 4:
                raise ErrorFiltro("Solo se comparan con > o < las IPv4.", posicion)
            sql_op = op
            return f"INET_ATON({col}) {sql_op} {int(dir_ip)}"
        return self.textual(col, op, str(dir_ip), posicion)

    def mac(self, col, op, valor, posicion):
        hexa = re.sub(r"[^0-9A-Fa-f]", "", valor).upper()
        if op == "contains":
            return f"{col} LIKE {_like(hexa)}"
        if op == "matches":
            return self.textual(col, op, valor, posicion)
        if len(hexa) != 12 or not re.fullmatch(r"[0-9A-Fa-f:.\-]+", valor):
            raise ErrorFiltro(f"«{valor}» no es una MAC (ejemplo: 00:1A:8C:12:34:56).", posicion)
        if op not in ("==", "!="):
            raise ErrorFiltro("Con una MAC use == o !=.", posicion)
        return self.textual(col, op, hexa, posicion)

    def fecha(self, col, op, valor, posicion):
        texto = valor.strip().replace("T", " ")
        for formato, solo_dia in (("%Y-%m-%d %H:%M:%S", False), ("%Y-%m-%d %H:%M", False), ("%Y-%m-%d", True)):
            try:
                f = datetime.strptime(texto, formato)
                break
            except ValueError:
                continue
        else:
            raise ErrorFiltro(f"«{valor}» no es una fecha (ejemplo: 2026-10-22 o \"2026-10-22 15:30\").", posicion)
        if op in ("contains", "matches"):
            raise ErrorFiltro("Con la fecha use == > < >= <=.", posicion)
        if solo_dia and op in ("==", "!="):
            sql = f"DATE({col}) = {lit(f.strftime('%Y-%m-%d'))}"
            return sql if op == "==" else f"NOT ({sql})"
        sql_op = {"==": "=", "!=": "<>", ">": ">", "<": "<", ">=": ">=", "<=": "<="}[op]
        return f"{col} {sql_op} {lit(f.strftime('%Y-%m-%d %H:%M:%S'))}"

    def texto_libre(self, valor):
        """Texto sin campo: busca en los campos de texto más comunes."""
        partes = [f"e.{c} LIKE {_like(valor)}" for c in TEXTO_LIBRE]
        hexa = re.sub(r"[^0-9A-Fa-f]", "", valor)
        if len(hexa) >= 4 and re.fullmatch(r"[0-9A-Fa-f:.\-]+", valor):
            partes += [f"e.mac_origen LIKE {_like(hexa.upper())}", f"e.mac_destino LIKE {_like(hexa.upper())}"]
        return "(" + " OR ".join(partes) + ")"


def _virtual(nombre):
    origen = ("(EXISTS (SELECT 1 FROM equipos q WHERE q.direccion_ip = e.ip_origen)"
              " OR EXISTS (SELECT 1 FROM red_macs_dispositivos qm WHERE qm.direccion_mac = e.mac_origen))")
    # Destino: también la IP traducida por NAT de destino (el servidor interno real)
    destino = ("(EXISTS (SELECT 1 FROM equipos q WHERE q.direccion_ip IN (e.ip_destino, e.ip_destino_nat))"
               " OR EXISTS (SELECT 1 FROM red_macs_dispositivos qm WHERE qm.direccion_mac = e.mac_destino))")
    if nombre == "equipo_origen":
        return origen
    if nombre == "equipo_destino":
        return destino
    if nombre == "equipo":
        return f"({origen} OR {destino})"
    if nombre == "con_agente":
        return ("EXISTS (SELECT 1 FROM log_direcciones d WHERE d.id_importacion = "
                "(SELECT MAX(i.id_importacion) FROM log_importaciones i WHERE i.fuente = 'MICROCLAUDIA')"
                " AND ((d.tipo = 'IP' AND d.direccion = e.ip_origen) OR (d.tipo = 'MAC' AND d.direccion = e.mac_origen)))")
    return ("EXISTS (SELECT 1 FROM usr_usuarios u WHERE u.usuario_red = e.usuario AND u.es_proveedor = FALSE)")


def a_sql(texto, alias_fuente=None):
    """Filtro escrito -> (WHERE sin la palabra WHERE, campos usados).
    Filtro vacío -> ("", set()). Lanza ErrorFiltro con la posición del problema."""
    texto = (texto or "").strip()
    if len(texto) > 2000:
        raise ErrorFiltro("El filtro es demasiado largo (máximo 2000 caracteres).", 2000)
    a = _Analizador(texto, alias_fuente)
    sql = a.analizar()
    return (sql or ""), a.usados


def unir(*partes):
    """Une varios WHERE con AND (los vacíos no cuentan)."""
    partes = [p for p in partes if p]
    if not partes:
        return ""
    return partes[0] if len(partes) == 1 else " AND ".join(f"({p})" for p in partes)


def campos_conocidos():
    return sorted(set(NOMBRES) | set(CAMPOS_AMBOS) | set(ALIAS_FILTRO) | set(VIRTUALES) | {"importacion", "fuente"})
