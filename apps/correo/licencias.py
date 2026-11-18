"""Control de licencias de correo: las cuentas de Google Workspace y las de
Sophos Email comparadas con el personal registrado en el sistema.

Con una lista importada (cor_listas, origen GOOGLE o SOPHOS) responde:
  - cuántos correos faltan: personal activo sin cuenta en la lista
  - licencias de personal retirado: personas inactivas con la cuenta activa
  - cuentas suspendidas (siguen ocupando la licencia hasta borrarlas o archivarlas)
  - cuentas sin uso: nunca iniciaron sesión o no entran hace N días
  - cuentas que no son de ninguna persona registrada (de uso común o por revisar)
  - los buzones más grandes
y, para Sophos Email, la comparación con la última lista de Google:
correos de Google sin licencia de Sophos y licencias de Sophos de cuentas
que ya no están en Google o están suspendidas."""
from datetime import datetime

from . import listas as lst

ORIGENES = {"GOOGLE": "Google Workspace", "SOPHOS": "Sophos Email", "OTRA": "Otra lista"}
DIAS_SIN_USO = (30, 60, 90, 180, 365)


def _texto_fecha(f):
    return f if isinstance(f, datetime) else None


def _cuenta(x, referencia, dias):
    """Una cuenta de la lista con su uso: días sin entrar y si se considera sin uso."""
    acceso = _texto_fecha(x.get("ultimo_acceso"))
    nunca = bool(x.get("nunca_entro")) if x.get("nunca_entro") is not None else False
    dias_sin = (referencia - acceso).days if acceso and referencia else None
    suspendida = lst.estado_cuenta(x.get("estado")) == "suspendida"
    return {
        "correo": x["correo"],
        "nombre": " ".join(filter(None, (x.get("nombre"), x.get("apellidos")))) or None,
        "estado": x.get("estado"),
        "suspendida": suspendida,
        "ultimo_acceso": acceso,
        "nunca_entro": nunca,
        "dias_sin_entrar": dias_sin,
        "uso_gb": float(x["uso_gb"]) if x.get("uso_gb") is not None else None,
        "sin_uso": (not suspendida) and (nunca or (dias_sin is not None and dias_sin > dias)),
    }


def analizar(lista, correos, personal, dias=90, google=None, correos_google=None):
    """lista: fila de cor_listas; correos: sus cuentas (sp_cor_listas_correos_listar);
    personal: sp_cor_personal_listar(FALSE) preparado con listas.preparar_personal.
    google/correos_google: la lista de Google para comparar una de Sophos."""
    comp = lst.comparar(correos, personal)
    # Momento del listado: el último inicio de sesión más reciente (si no trae, hoy)
    accesos = [x["ultimo_acceso"] for x in correos if isinstance(x.get("ultimo_acceso"), datetime)]
    referencia = max(accesos) if accesos else datetime.now()
    trae_uso = any(x.get("ultimo_acceso") or x.get("nunca_entro") is not None for x in correos)
    trae_tamano = any(x.get("uso_gb") is not None for x in correos)

    cuentas = {x["correo"]: _cuenta(x, referencia, dias) for x in correos}
    persona_de = {c["correo"]: c["persona"] for c in comp["coinciden"]}
    sugerencias = {s["correo"]: s for s in comp["solo_lista"]}
    for correo, c in cuentas.items():
        c["persona"] = persona_de.get(correo)
        s = sugerencias.get(correo)
        c["sugerencias"] = s["sugerencias"] if s else []
        c["generica"] = bool(s and s["generica"])

    lista_cuentas = sorted(cuentas.values(), key=lambda c: c["correo"])
    retirados = [c for c in lista_cuentas if c["persona"] and not c["persona"]["activo"] and not c["suspendida"]]
    suspendidas = [c for c in lista_cuentas if c["suspendida"]]
    sin_uso = sorted((c for c in lista_cuentas if c["sin_uso"]),
                     key=lambda c: (not c["nunca_entro"], -(c["dias_sin_entrar"] or 0)))
    sin_persona = [c for c in lista_cuentas if not c["persona"]]
    sin_persona.sort(key=lambda c: (not c["sugerencias"], c["generica"], c["correo"]))
    mayores = sorted((c for c in lista_cuentas if c["uso_gb"] is not None), key=lambda c: -c["uso_gb"])[:10]

    salida = {
        "lista": lista,
        "origen": lista.get("origen"),
        "referencia": referencia if accesos else None,
        "dias": dias,
        "trae_uso": trae_uso,
        "trae_tamano": trae_tamano,
        "dominios": comp["dominios"],
        "totales": {
            "cuentas": len(lista_cuentas),
            "activas": sum(1 for c in lista_cuentas if not c["suspendida"]),
            "suspendidas": len(suspendidas),
            "nunca_entraron": sum(1 for c in lista_cuentas if c["nunca_entro"] and not c["suspendida"]),
            "sin_uso": len(sin_uso),
            "uso_total_gb": round(sum(c["uso_gb"] or 0 for c in lista_cuentas), 2) if trae_tamano else None,
            "personal_activo": comp["totales"]["personal_activo"],
            "personal_con_cuenta": sum(1 for c in comp["coinciden"] if c["persona"]["activo"]),
            "faltan": len(comp["sin_correo"]),
            "retirados": len(retirados),
            "sin_persona": len(sin_persona),
            "genericas": sum(1 for c in sin_persona if c["generica"]),
            "con_sugerencia": sum(1 for c in sin_persona if c["sugerencias"]),
            "solo_sistema": len(comp["solo_sistema"]),
        },
        "faltan": comp["sin_correo"],
        "retirados": retirados,
        "suspendidas": suspendidas,
        "sin_uso": sin_uso,
        "sin_persona": sin_persona,
        "solo_sistema": comp["solo_sistema"],
        "mayores": mayores,
        "cuentas": lista_cuentas,
        "google": None,
    }

    if google is not None and correos_google is not None:
        en_google = {x["correo"]: x for x in correos_google}
        activas_google = {c for c, x in en_google.items() if lst.estado_cuenta(x.get("estado")) != "suspendida"}
        persona_correo = {}
        for p in personal:
            for c, _ in p["_correos"]:
                persona_correo.setdefault(c, lst._persona(p))
        sin_licencia = []
        for correo in sorted(activas_google - set(cuentas)):
            g = en_google[correo]
            sin_licencia.append({
                "correo": correo, "nombre": " ".join(filter(None, (g.get("nombre"), g.get("apellidos")))) or None,
                "estado": g.get("estado"), "persona": persona_correo.get(correo),
            })
        # Con persona activa primero: son las que más falta hacen
        sin_licencia.sort(key=lambda c: (not (c["persona"] and c["persona"]["activo"]), c["correo"]))
        no_en_google = [c for c in lista_cuentas if c["correo"] not in en_google]
        suspendida_en_google = [c for c in lista_cuentas if c["correo"] in en_google and c["correo"] not in activas_google]
        de_retirados = [c for c in lista_cuentas if c["persona"] and not c["persona"]["activo"]]
        salida["google"] = {
            "lista": google,
            "totales": {
                "google": len(en_google), "google_activas": len(activas_google),
                "sin_licencia": len(sin_licencia), "no_en_google": len(no_en_google),
                "suspendida_en_google": len(suspendida_en_google), "de_retirados": len(de_retirados),
                "sobran": len(no_en_google) + len(suspendida_en_google) + sum(
                    1 for c in de_retirados if c["correo"] in activas_google),
            },
            "sin_licencia": sin_licencia,
            "no_en_google": no_en_google,
            "suspendida_en_google": suspendida_en_google,
        }
    return salida
