"""Carga los catálogos básicos y crea el primer usuario administrador.

Uso:
    python manage.py inicializar
    python manage.py inicializar --usuario admin --password "ClaveSegura123"

Se puede correr varias veces: solo agrega lo que falta.
"""
from getpass import getpass

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand, CommandError

from apps.core.db import llamar_sp

CATALOGOS = {
    "sp_cat_roles_usuarios": ["Administrador", "Estándar"],
    "sp_cat_tipos_autenticaciones": ["Sistema App", "Active Directory"],
    "sp_cat_tipos_identificaciones": ["Cédula Física", "Cédula Jurídica", "DIMEX", "Pasaporte", "Sin Identificación"],
    "sp_cat_tipos_telefonos": ["Personal Celular", "Personal Fijo", "Trabajo Celular", "Trabajo Fijo"],
    "sp_cat_tipos_correos": ["Institucional", "Personal", "Trabajo"],
    "sp_cat_departamentos": ["Tecnologías de Información"],
}

PROVINCIAS_CR = {
    "1": "San José", "2": "Alajuela", "3": "Cartago", "4": "Heredia",
    "5": "Guanacaste", "6": "Puntarenas", "7": "Limón",
}


class Command(BaseCommand):
    help = "Carga catálogos básicos y crea el usuario administrador inicial."

    def add_arguments(self, parser):
        parser.add_argument("--usuario", default="admin", help="Login del administrador (usuario_red).")
        parser.add_argument("--password", help="Clave del administrador (si se omite, se pregunta).")
        parser.add_argument("--nombre", default="Administrador")
        parser.add_argument("--dni", default="000000000", help="Identificación del administrador.")

    def handle(self, *args, **opts):
        codigos = {sp: self._asegurar_catalogo(sp, valores) for sp, valores in CATALOGOS.items()}
        self._asegurar_geografia()

        filas, _ = llamar_sp("sp_personas_obtener_por_login", [opts["usuario"]])
        if filas:
            self.stdout.write(f"El usuario '{opts['usuario']}' ya existe; no se modificó.")
            return

        password = opts["password"] or getpass(f"Clave para '{opts['usuario']}' (mín. 8 caracteres): ")
        if len(password) < 8:
            raise CommandError("La clave debe tener al menos 8 caracteres.")

        rol_admin = next(iter(getattr(settings, "MUNI_ROLES_ADMIN", ["Administrador"])))
        cod_rol = self._codigo(codigos["sp_cat_roles_usuarios"], rol_admin)
        if cod_rol is None:
            raise CommandError(f"No existe el rol '{rol_admin}' en cat_roles_usuarios.")

        _, nuevo_id = llamar_sp("sp_personas_insertar", [
            cod_rol,
            self._codigo(codigos["sp_cat_tipos_autenticaciones"], "Sistema App"),
            self._codigo(codigos["sp_cat_tipos_identificaciones"], "Cédula Física"),
            opts["dni"], opts["nombre"], None, None,
            "CR", "2", "03", "01", None, None,
            self._codigo(codigos["sp_cat_departamentos"], "Tecnologías de Información"),
            opts["usuario"], make_password(password),
        ], con_salida=True)

        self.stdout.write(self.style.SUCCESS(
            f"Administrador '{opts['usuario']}' creado (id {nuevo_id}). Ya puede iniciar sesión."))

    # ------------------------------------------------------------------
    def _asegurar_catalogo(self, sp, valores):
        filas, _ = llamar_sp(f"{sp}_listar")
        existentes = {f["descripcion"].strip().lower(): f for f in filas}
        for valor in valores:
            if valor.lower() not in existentes:
                llamar_sp(f"{sp}_insertar", [valor], con_salida=True)
                self.stdout.write(f"  + {sp.replace('sp_cat_', '')}: {valor}")
        filas, _ = llamar_sp(f"{sp}_listar")
        return filas

    @staticmethod
    def _codigo(filas, descripcion):
        for fila in filas:
            if fila["descripcion"].strip().lower() == descripcion.strip().lower():
                # La primera columna de cada catálogo es su código
                return next(iter(fila.values()))
        return None

    def _asegurar_geografia(self):
        if not llamar_sp("sp_geo_paises_obtener", ["CR"])[0]:
            llamar_sp("sp_geo_paises_insertar", ["CR", "Costa Rica"])
            self.stdout.write("  + país: Costa Rica")

        existentes = {f["cod_provincia"] for f in llamar_sp("sp_geo_provincias_listar", ["CR"])[0]}
        for codigo, nombre in PROVINCIAS_CR.items():
            if codigo not in existentes:
                llamar_sp("sp_geo_provincias_insertar", ["CR", codigo, nombre])
                self.stdout.write(f"  + provincia: {nombre}")

        if not llamar_sp("sp_geo_cantones_obtener", ["CR", "2", "03"])[0]:
            llamar_sp("sp_geo_cantones_insertar", ["CR", "2", "03", "Grecia"])
            self.stdout.write("  + cantón: Grecia")

        if not llamar_sp("sp_geo_distritos_obtener", ["CR", "2", "03", "01"])[0]:
            llamar_sp("sp_geo_distritos_insertar", ["CR", "2", "03", "01", "Grecia", None])
            self.stdout.write("  + distrito: Grecia")
