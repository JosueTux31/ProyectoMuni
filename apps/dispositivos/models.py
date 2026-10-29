"""Módulo de equipos municipales (antes dispositivos de red): catálogos,
edificios, equipos de todo tipo y sus documentos. managed = False: el esquema vive en MariaDB
(sql/dispositivos/creacionDispositivo.sql). Las escrituras de la API pasan
por los procedimientos sp_* de procedimientosDispositivos.sql."""
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
        db_table = "cat_categorias_dispositivos"
        verbose_name = "categoría de equipo"
        verbose_name_plural = "categorías de equipos"


class TipoDispositivo(CatalogoBase):
    tipo_disp = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)
    categoria = models.ForeignKey(CategoriaDispositivo, on_delete=models.DO_NOTHING, db_column="id_categoria",
                                  related_name="tipos")

    class Meta(CatalogoBase.Meta):
        db_table = "cat_tipos_dispositivos"
        verbose_name = "tipo de dispositivo"
        verbose_name_plural = "tipos de dispositivos"


class Marca(CatalogoBase):
    """Cada marca pertenece a un tipo de dispositivo (CISCO de firewall y
    CISCO de router son marcas distintas, cada una con sus modelos)."""
    id_marca = models.AutoField(primary_key=True)
    tipo_dispositivo = models.ForeignKey(TipoDispositivo, on_delete=models.DO_NOTHING, db_column="tipo_disp",
                                         related_name="marcas")
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_marcas"
        verbose_name = "marca"
        verbose_name_plural = "marcas"
        ordering = ["tipo_dispositivo_id", "descripcion"]


class Modelo(models.Model):
    """Modelos de cada marca. id_modelo y num_linea se numeran 1, 2, 3...
    dentro de cada marca; num_linea es el orden en que se muestran."""
    pk = models.CompositePrimaryKey("tipo_dispositivo_id", "marca_id", "id_modelo")
    tipo_dispositivo = models.ForeignKey(TipoDispositivo, on_delete=models.DO_NOTHING, db_column="tipo_disp",
                                         related_name="+")
    marca = models.ForeignKey(Marca, on_delete=models.DO_NOTHING, db_column="id_marca", related_name="modelos")
    num_linea = models.IntegerField()
    id_modelo = models.IntegerField()
    descripcion = models.CharField(max_length=150)

    class Meta:
        managed = False
        db_table = "cat_modelos"
        verbose_name = "modelo"
        verbose_name_plural = "modelos"
        ordering = ["tipo_dispositivo_id", "marca_id", "num_linea"]

    def __str__(self):
        return self.descripcion


class SistemaOperativo(CatalogoBase):
    id_os = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_sistemas_operativos"
        verbose_name = "sistema operativo"
        verbose_name_plural = "sistemas operativos"


class TipoDocumento(CatalogoBase):
    id_doc = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_tipos_documentos"
        verbose_name = "tipo de documento"
        verbose_name_plural = "tipos de documentos"


class Edificio(CatalogoBase):
    """Edificio donde están los dispositivos. Sus coordenadas son el mapa de
    cada dispositivo que está en él."""
    id_predio = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=150)     # nombre del edificio
    otras_senas = models.TextField(null=True, blank=True)
    gps = models.CharField(max_length=100, null=True, blank=True)          # "latitud,longitud"

    class Meta(CatalogoBase.Meta):
        db_table = "cat_edificios"
        verbose_name = "edificio"
        verbose_name_plural = "edificios"


class Dispositivo(models.Model):
    """Equipo municipal (tabla equiposMuni, antes red_dispositivos): de red,
    computadora, servidor, móvil, teléfono, impresora, pantalla, UPS,
    cámara... Se liga a su edificio, a su departamento, al funcionario que
    lo tiene asignado y a su proveedor de soporte (usr_usuarios con
    es_proveedor = TRUE). El modelo se identifica con tipo + marca +
    id_modelo (cat_modelos). Los datos de cada categoría son opcionales.
    Sus direcciones IP y MAC están en IpDispositivo y MacDispositivo."""
    id_disp = models.AutoField(primary_key=True)
    serie = models.CharField(max_length=100)
    tipo_dispositivo = models.ForeignKey(TipoDispositivo, on_delete=models.DO_NOTHING, db_column="tipo_disp",
                                         related_name="dispositivos")
    marca = models.ForeignKey(Marca, on_delete=models.DO_NOTHING, db_column="id_marca", related_name="dispositivos")
    id_modelo = models.IntegerField(null=True, blank=True)
    nombre_equipo = models.CharField(max_length=100, null=True, blank=True)    # nombre en la red (hostname)
    placa = models.CharField(max_length=50, null=True, blank=True)             # número de activo
    cant_ptos_ethernet = models.PositiveSmallIntegerField(default=0)
    cant_ptos_sfp = models.PositiveSmallIntegerField(default=0)
    sistema_operativo = models.ForeignKey(SistemaOperativo, on_delete=models.DO_NOTHING, db_column="id_os",
                                          related_name="dispositivos")
    version_os = models.CharField(max_length=100, null=True, blank=True)
    procesador = models.CharField(max_length=150, null=True, blank=True)
    memoria_gb = models.PositiveSmallIntegerField(null=True, blank=True)
    almacenamiento_gb = models.PositiveIntegerField(null=True, blank=True)
    tipo_almacenamiento = models.CharField(max_length=10, null=True, blank=True)
    imei = models.CharField(max_length=15, null=True, blank=True)
    imei2 = models.CharField(max_length=15, null=True, blank=True)
    numero_linea = models.CharField(max_length=20, null=True, blank=True)
    operador = models.CharField(max_length=50, null=True, blank=True)
    extension = models.CharField(max_length=10, null=True, blank=True)
    tecnologia_impresion = models.CharField(max_length=20, null=True, blank=True)
    a_color = models.BooleanField(null=True, blank=True)
    consumible = models.CharField(max_length=100, null=True, blank=True)
    pulgadas = models.DecimalField(max_digits=4, decimal_places=1, null=True, blank=True)
    resolucion = models.CharField(max_length=20, null=True, blank=True)
    capacidad_va = models.PositiveIntegerField(null=True, blank=True)
    autonomia_min = models.PositiveSmallIntegerField(null=True, blank=True)
    canales = models.PositiveSmallIntegerField(null=True, blank=True)
    edificio = models.ForeignKey(Edificio, on_delete=models.DO_NOTHING, db_column="id_predio",
                                 null=True, blank=True, related_name="dispositivos")
    ubicacion = models.CharField(max_length=255, null=True, blank=True)    # piso, oficina, rack
    departamento = models.ForeignKey("catalogos.Departamento", on_delete=models.DO_NOTHING, db_column="cod_departamento",
                                     null=True, blank=True, related_name="equipos")
    asignado = models.ForeignKey("usuarios.Usuario", on_delete=models.DO_NOTHING, db_column="id_asignado",
                                 null=True, blank=True, related_name="equipos_asignados")
    proveedor = models.ForeignKey("proveedores.Proveedor", on_delete=models.DO_NOTHING, db_column="id_proveedor",
                                  null=True, blank=True, related_name="dispositivos")
    fecha_compra = models.DateField(null=True, blank=True)
    garantia_hasta = models.DateField(null=True, blank=True)
    observaciones = models.CharField(max_length=500, null=True, blank=True)
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(editable=False)
    actualizado_en = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "equiposMuni"        # antes red_dispositivos
        verbose_name = "equipo municipal"
        verbose_name_plural = "equipos municipales"
        ordering = ["tipo_dispositivo_id", "marca_id", "serie"]

    def __str__(self):
        return self.serie


class IpDispositivo(models.Model):
    pk = models.CompositePrimaryKey("dispositivo_id", "num_linea")
    dispositivo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id_disp",
                                    related_name="ips")
    num_linea = models.IntegerField()
    direccion_ip = models.CharField(max_length=45)                          # IPv4 o IPv6
    interfaz = models.CharField(max_length=50, null=True, blank=True)       # WAN, LAN, GESTIÓN...

    class Meta:
        managed = False
        db_table = "equipos"            # antes red_ips_dispositivos
        verbose_name = "dirección IP"
        verbose_name_plural = "direcciones IP"
        ordering = ["dispositivo_id", "num_linea"]

    def __str__(self):
        return self.direccion_ip


class MacDispositivo(models.Model):
    """La MAC se guarda entera, sin separadores (AABBCCDDEEFF)."""
    pk = models.CompositePrimaryKey("dispositivo_id", "num_linea")
    dispositivo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id_disp",
                                    related_name="macs")
    num_linea = models.IntegerField()
    direccion_mac = models.CharField(max_length=12)
    interfaz = models.CharField(max_length=50, null=True, blank=True)

    class Meta:
        managed = False
        db_table = "red_macs_dispositivos"
        verbose_name = "dirección MAC"
        verbose_name_plural = "direcciones MAC"
        ordering = ["dispositivo_id", "num_linea"]

    def __str__(self):
        return "-".join(self.direccion_mac[i:i + 2] for i in range(0, 12, 2))


class DocumentoDispositivo(models.Model):
    """Manuales, imagen, firmware, respaldos y configuración de cada
    dispositivo. El archivo vive en MEDIA_ROOT; path_docs guarda su ruta."""
    pk = models.CompositePrimaryKey("dispositivo_id", "num_linea")
    dispositivo = models.ForeignKey(Dispositivo, on_delete=models.CASCADE, db_column="id_disp",
                                    related_name="documentos")
    num_linea = models.IntegerField()
    tipo_documento = models.ForeignKey(TipoDocumento, on_delete=models.DO_NOTHING, db_column="id_doc",
                                       related_name="+")
    path_docs = models.CharField(max_length=255)
    creado_en = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "red_documentos_dispositivos"
        verbose_name = "documento de dispositivo"
        verbose_name_plural = "documentos de dispositivos"
        ordering = ["dispositivo_id", "num_linea"]

    def __str__(self):
        return self.path_docs
