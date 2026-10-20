"""Módulo de dispositivos de red: catálogos, edificios, dispositivos y sus
documentos. managed = False: el esquema vive en MariaDB
(sql/dispositivos/creacionDispositivo.sql). Las escrituras de la API pasan
por los procedimientos sp_* de procedimientosDispositivos.sql."""
from django.db import models

from apps.catalogos.models import CatalogoBase


class TipoDispositivo(CatalogoBase):
    tipo_disp = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=100)

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
    id_edificio = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=150)     # nombre del edificio
    otras_senas = models.TextField(null=True, blank=True)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_edificios"
        verbose_name = "edificio"
        verbose_name_plural = "edificios"


class Dispositivo(models.Model):
    """Dispositivo de red. Se liga a su edificio y a su proveedor de soporte
    (usr_usuarios con es_proveedor = TRUE). El modelo se identifica con
    tipo + marca + id_modelo (cat_modelos)."""
    id_disp = models.AutoField(primary_key=True)
    serie = models.CharField(max_length=100)
    tipo_dispositivo = models.ForeignKey(TipoDispositivo, on_delete=models.DO_NOTHING, db_column="tipo_disp",
                                         related_name="dispositivos")
    marca = models.ForeignKey(Marca, on_delete=models.DO_NOTHING, db_column="id_marca", related_name="dispositivos")
    id_modelo = models.IntegerField(null=True, blank=True)
    cant_ptos_ethernet = models.PositiveSmallIntegerField(default=0)
    cant_ptos_sfp = models.PositiveSmallIntegerField(default=0)
    sistema_operativo = models.ForeignKey(SistemaOperativo, on_delete=models.DO_NOTHING, db_column="id_os",
                                          related_name="dispositivos")
    gps = models.CharField(max_length=100, null=True, blank=True)          # "latitud,longitud"
    edificio = models.ForeignKey(Edificio, on_delete=models.DO_NOTHING, db_column="id_edificio",
                                 null=True, blank=True, related_name="dispositivos")
    ubicacion = models.CharField(max_length=255, null=True, blank=True)    # piso, cuarto, rack
    proveedor = models.ForeignKey("proveedores.Proveedor", on_delete=models.DO_NOTHING, db_column="id_proveedor",
                                  null=True, blank=True, related_name="dispositivos")
    direccion_ip = models.CharField(max_length=45, null=True, blank=True)
    direccion_mac = models.CharField(max_length=17, null=True, blank=True)  # AA:BB:CC:DD:EE:FF
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(editable=False)
    actualizado_en = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "red_dispositivos"
        verbose_name = "dispositivo de red"
        verbose_name_plural = "dispositivos de red"
        ordering = ["tipo_dispositivo_id", "marca_id", "serie"]

    def __str__(self):
        return self.serie


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
