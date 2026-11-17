"""Módulo de equipos municipales con el modelo de datos de la especificación
«2 - Sistema - Tablas»: tablas catálogo (tipo_equipos, marcas, modelos,
procesadores, sis_operativos, firmwares, edificios, estado_equipos,
tipo_roles, tipo_herramientas, tipo_archivos), la tabla equipos y sus tablas
de detalle (roles, herramientas, dir_macs, dir_ips, num_moviles, dir_imeis,
archivos), más las categorías y los puertos de los switches.

managed = False: el esquema vive en MariaDB (sql/dispositivos/creacionDispositivo.sql).
Las escrituras de la API pasan por los procedimientos sp_* de
procedimientosDispositivos.sql."""
from django.db import models

from apps.catalogos.models import CatalogoBase


class CategoriaDispositivo(CatalogoBase):
    """Categorías fijas: equipos de red, computadoras, servidores, móviles,
    telefonía, impresión, pantallas, energía, videovigilancia y otros.
    Deciden qué datos se piden al registrar cada equipo."""
    id_categoria = models.IntegerField(primary_key=True)
    descripcion = models.CharField(max_length=100)
    lleva_agente = models.BooleanField(default=False)    # se espera el agente de Microclaudia

    class Meta(CatalogoBase.Meta):
        db_table = "categoria_equipos"
        verbose_name = "categoría de equipo"
        verbose_name_plural = "categorías de equipos"


class TipoDispositivo(CatalogoBase):
    """Tabla catálogo tipo_equipos: modem, firewall, router, switch, server..."""
    tipo_equipo = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)
    categoria = models.ForeignKey(CategoriaDispositivo, on_delete=models.DO_NOTHING, db_column="id_categoria",
                                  related_name="tipos")

    class Meta(CatalogoBase.Meta):
        db_table = "tipo_equipos"
        verbose_name = "tipo de equipo"
        verbose_name_plural = "tipos de equipos"


class Marca(CatalogoBase):
    """Tabla catálogo marcas. Cada marca es de un tipo de equipo (CISCO de
    firewall y CISCO de router son marcas distintas, cada una con sus modelos)."""
    id_marca = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)
    tipo_dispositivo = models.ForeignKey(TipoDispositivo, on_delete=models.DO_NOTHING, db_column="tipo_equipo",
                                         related_name="marcas")

    class Meta(CatalogoBase.Meta):
        db_table = "marcas"
        verbose_name = "marca"
        verbose_name_plural = "marcas"
        ordering = ["tipo_dispositivo_id", "descripcion"]


class Modelo(CatalogoBase):
    """Tabla catálogo modelos: cada modelo es de una marca."""
    id_modelo = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=150)
    marca = models.ForeignKey(Marca, on_delete=models.DO_NOTHING, db_column="id_marca", related_name="modelos")

    class Meta(CatalogoBase.Meta):
        db_table = "modelos"
        verbose_name = "modelo"
        verbose_name_plural = "modelos"
        ordering = ["marca_id", "id_modelo"]


class Procesador(CatalogoBase):
    id_proc = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=150)

    class Meta(CatalogoBase.Meta):
        db_table = "procesadores"
        verbose_name = "procesador"
        verbose_name_plural = "procesadores"


class SistemaOperativo(CatalogoBase):
    id_so = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "sis_operativos"
        verbose_name = "sistema operativo"
        verbose_name_plural = "sistemas operativos"


class Firmware(CatalogoBase):
    """Versión del sistema o firmware: N/D, SFOS 22.0.2..."""
    id_firmw = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "firmwares"
        verbose_name = "firmware"
        verbose_name_plural = "firmwares"


class Edificio(CatalogoBase):
    """Edificios de la municipalidad. País, provincia, cantón y distrito son
    los de la división territorial; ubicacion son las coordenadas del mapa."""
    id_predio = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=150)
    id_pais = models.CharField(max_length=10, null=True, blank=True)
    id_provincia = models.CharField(max_length=10, null=True, blank=True)
    id_canton = models.CharField(max_length=10, null=True, blank=True)
    id_distrito = models.CharField(max_length=10, null=True, blank=True)
    ubicacion = models.CharField(max_length=100, null=True, blank=True)     # "latitud,longitud"
    otras_senas = models.TextField(null=True, blank=True)

    class Meta(CatalogoBase.Meta):
        db_table = "edificios"
        verbose_name = "edificio"
        verbose_name_plural = "edificios"


class EstadoEquipo(CatalogoBase):
    """N/D (1), ACTIVO (2) e INACTIVO (3): los usa el sistema."""
    id_estado = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    class Meta(CatalogoBase.Meta):
        db_table = "estado_equipos"
        verbose_name = "estado de equipo"
        verbose_name_plural = "estados de equipos"


class TipoRol(CatalogoBase):
    """Roles de un servidor: de dominio, DHCP, DNS, NTP..."""
    id_rol = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "tipo_roles"
        verbose_name = "tipo de rol"
        verbose_name_plural = "tipos de roles"


class TipoHerramienta(CatalogoBase):
    """Herramientas de seguridad: Bitdefender, Microclaudia (3), Cisco Umbrella..."""
    id_herram = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "tipo_herramientas"
        verbose_name = "tipo de herramienta"
        verbose_name_plural = "tipos de herramientas"


class TipoDocumento(CatalogoBase):
    """Tabla catálogo tipo_archivos: manual, garantía, soporte, configuración..."""
    tipo_arch = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "tipo_archivos"
        verbose_name = "tipo de archivo"
        verbose_name_plural = "tipos de archivos"


class Dispositivo(models.Model):
    """Tabla equipos: firewall, router, switch, servidor, workstation,
    laptop, teléfono IP, impresora, scanner, tablet, teléfono móvil...
    Se liga a su edificio, a su departamento, al funcionario que lo usa
    (id_usuario) y a su proveedor de soporte (tabla personas). Sus IP, MAC,
    líneas, IMEI, roles, herramientas y archivos están en sus tablas."""
    id = models.AutoField(primary_key=True)
    tipo_dispositivo = models.ForeignKey(TipoDispositivo, on_delete=models.DO_NOTHING, db_column="tipo_equipo",
                                         related_name="dispositivos")
    serie = models.CharField(max_length=100)
    marca = models.ForeignKey(Marca, on_delete=models.DO_NOTHING, db_column="id_marca", related_name="dispositivos")
    modelo = models.ForeignKey(Modelo, on_delete=models.DO_NOTHING, db_column="id_modelo", null=True, blank=True,
                               related_name="dispositivos")
    nombre_equipo = models.CharField(max_length=100, null=True, blank=True)    # nombre en la red (hostname)
    placa_equipo = models.CharField(max_length=50, null=True, blank=True)      # número de activo
    procesador = models.ForeignKey(Procesador, on_delete=models.DO_NOTHING, db_column="id_proces", null=True,
                                   blank=True, related_name="dispositivos")
    cant_mem = models.PositiveSmallIntegerField(null=True, blank=True)         # GB
    cant_almac = models.PositiveIntegerField(null=True, blank=True)            # GB
    cant_ptos_serie = models.PositiveSmallIntegerField(default=0)
    cant_ptos_usb = models.PositiveSmallIntegerField(default=0)
    cant_ptos_eth = models.PositiveSmallIntegerField(default=0)
    cant_ptos_sfp = models.PositiveSmallIntegerField(default=0)
    cant_ptos_wireless = models.PositiveSmallIntegerField(default=0)
    cant_ptos_bluetooth = models.PositiveSmallIntegerField(default=0)
    cant_ptos_celular = models.PositiveSmallIntegerField(default=0)
    sistema_operativo = models.ForeignKey(SistemaOperativo, on_delete=models.DO_NOTHING, db_column="id_so",
                                          related_name="dispositivos")
    firmware = models.ForeignKey(Firmware, on_delete=models.DO_NOTHING, db_column="id_firmw",
                                 related_name="dispositivos")
    edificio = models.ForeignKey(Edificio, on_delete=models.DO_NOTHING, db_column="id_predio",
                                 null=True, blank=True, related_name="dispositivos")
    ubicacion = models.CharField(max_length=255, null=True, blank=True)    # piso, oficina, rack
    estado = models.ForeignKey(EstadoEquipo, on_delete=models.DO_NOTHING, db_column="id_estado",
                               related_name="dispositivos")
    usuario = models.ForeignKey("usuarios.Usuario", on_delete=models.DO_NOTHING, db_column="id_usuario",
                                null=True, blank=True, related_name="equipos_asignados")
    proveedor = models.ForeignKey("proveedores.Proveedor", on_delete=models.DO_NOTHING, db_column="id_proveedor",
                                  null=True, blank=True, related_name="dispositivos")
    tipo_almacenamiento = models.CharField(max_length=10, null=True, blank=True)
    extension = models.CharField(max_length=10, null=True, blank=True)
    tecnologia_impresion = models.CharField(max_length=20, null=True, blank=True)
    a_color = models.BooleanField(null=True, blank=True)
    consumible = models.CharField(max_length=100, null=True, blank=True)
    pulgadas = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    resolucion = models.CharField(max_length=20, null=True, blank=True)
    capacidad_va = models.PositiveIntegerField(null=True, blank=True)
    autonomia_min = models.PositiveSmallIntegerField(null=True, blank=True)
    canales = models.PositiveSmallIntegerField(null=True, blank=True)
    departamento = models.ForeignKey("catalogos.Departamento", on_delete=models.DO_NOTHING, db_column="cod_departamento",
                                     null=True, blank=True, related_name="equipos")
    fecha_compra = models.DateField(null=True, blank=True)
    garantia_hasta = models.DateField(null=True, blank=True)
    observaciones = models.CharField(max_length=500, null=True, blank=True)
    sfp_combo = models.BooleanField(default=False)              # switches: 45F comparte número con 45T
    creado_en = models.DateTimeField(editable=False)
    actualizado_en = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "equipos"            # antes equiposMuni
        verbose_name = "equipo municipal"
        verbose_name_plural = "equipos municipales"
        ordering = ["tipo_dispositivo_id", "marca_id", "serie"]

    def __str__(self):
        return self.serie


class _Detalle(models.Model):
    """Tabla de detalle de un equipo: id (del equipo) + num_linea."""
    pk = models.CompositePrimaryKey("equipo_id", "num_linea")
    num_linea = models.IntegerField()

    class Meta:
        abstract = True
        managed = False
        ordering = ["equipo_id", "num_linea"]


class RolDispositivo(_Detalle):
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="roles")
    rol = models.ForeignKey(TipoRol, on_delete=models.DO_NOTHING, db_column="id_rol", related_name="+")

    class Meta(_Detalle.Meta):
        db_table = "roles"
        verbose_name = "rol del equipo"
        verbose_name_plural = "roles de los equipos"


class HerramientaDispositivo(_Detalle):
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="herramientas")
    herramienta = models.ForeignKey(TipoHerramienta, on_delete=models.DO_NOTHING, db_column="id_herram",
                                    related_name="+")

    class Meta(_Detalle.Meta):
        db_table = "herramientas"
        verbose_name = "herramienta del equipo"
        verbose_name_plural = "herramientas de los equipos"


class MacDispositivo(_Detalle):
    """La MAC se guarda entera, sin separadores (AABBCCDDEEFF)."""
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="macs")
    dir_mac = models.CharField(max_length=12)
    interfaz = models.CharField(max_length=50, null=True, blank=True)

    class Meta(_Detalle.Meta):
        db_table = "dir_macs"
        verbose_name = "dirección MAC"
        verbose_name_plural = "direcciones MAC"

    def __str__(self):
        return "-".join(self.dir_mac[i:i + 2] for i in range(0, 12, 2))


class IpDispositivo(_Detalle):
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="ips")
    dir_ip = models.CharField(max_length=45)                                # IPv4 o IPv6
    interfaz = models.CharField(max_length=50, null=True, blank=True)       # WAN, LAN, GESTIÓN...

    class Meta(_Detalle.Meta):
        db_table = "dir_ips"
        verbose_name = "dirección IP"
        verbose_name_plural = "direcciones IP"

    def __str__(self):
        return self.dir_ip


class MovilDispositivo(_Detalle):
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="moviles")
    num_movil = models.CharField(max_length=20)
    operador = models.CharField(max_length=50, null=True, blank=True)       # KÖLBI, CLARO, LIBERTY...

    class Meta(_Detalle.Meta):
        db_table = "num_moviles"
        verbose_name = "línea móvil"
        verbose_name_plural = "líneas móviles"

    def __str__(self):
        return self.num_movil


class ImeiDispositivo(_Detalle):
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="imeis")
    dir_imei = models.CharField(max_length=15)

    class Meta(_Detalle.Meta):
        db_table = "dir_imeis"
        verbose_name = "IMEI"
        verbose_name_plural = "IMEI"

    def __str__(self):
        return self.dir_imei


class DocumentoDispositivo(_Detalle):
    """Archivos de cada equipo (manual, garantía, configuración...). El
    archivo vive en MEDIA_ROOT; path_arch guarda su ruta."""
    equipo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id", related_name="documentos")
    tipo_documento = models.ForeignKey(TipoDocumento, on_delete=models.DO_NOTHING, db_column="tipo_arch",
                                       related_name="+")
    path_arch = models.CharField(max_length=255)
    creado_en = models.DateTimeField(editable=False)

    class Meta(_Detalle.Meta):
        db_table = "archivos"
        verbose_name = "archivo de equipo"
        verbose_name_plural = "archivos de equipos"

    def __str__(self):
        return self.path_arch


class PuertoSwitch(models.Model):
    """Qué equipo está conectado a cada puerto de un switch, con su estado,
    VLAN y nota. Solo se guardan los puertos con algún dato (los demás
    están libres). tipo_puerto T = cobre (1..cant_ptos_eth), F = SFP
    (1..cant_ptos_sfp); el rótulo (12, 45T, 45F, 49) depende de sfp_combo."""
    ESTADOS = [("EN_USO", "En uso"), ("LIBRE", "Libre"), ("DESHABILITADO", "Deshabilitado"), ("DANADO", "Dañado")]

    pk = models.CompositePrimaryKey("switch_id", "tipo_puerto", "num_puerto")
    switch = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id_switch",
                               related_name="puertos")
    tipo_puerto = models.CharField(max_length=1, choices=[("T", "Cobre"), ("F", "SFP")])
    num_puerto = models.PositiveSmallIntegerField()
    equipo = models.ForeignKey(Dispositivo, on_delete=models.SET_NULL, db_column="id_equipo", null=True, blank=True,
                               related_name="conexiones")
    estado = models.CharField(max_length=15, choices=ESTADOS, default="LIBRE")
    vlan = models.CharField(max_length=30, null=True, blank=True)       # 10, 10,20 o 1-100
    nota = models.CharField(max_length=255, null=True, blank=True)      # rótulo del cable, patch panel...
    actualizado_en = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "puertos_switch"
        verbose_name = "puerto de switch"
        verbose_name_plural = "puertos de switches"
        ordering = ["switch_id", "-tipo_puerto", "num_puerto"]
