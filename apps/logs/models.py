"""Módulo de análisis de logs. managed = False: el esquema vive en MariaDB
(sql/logs/creacionLogs.sql) y todo pasa por los procedimientos sp_log_*.
log_eventos guarda los campos comunes en columnas (apps/logs/esquema.py)
y todos los originales en la columna datos (JSON)."""
from django.db import models


class Importacion(models.Model):
    id_importacion = models.AutoField(primary_key=True)
    fuente = models.CharField(max_length=30)
    nombre_archivo = models.CharField(max_length=255)
    descripcion = models.CharField(max_length=255, null=True, blank=True)
    total_leidos = models.IntegerField(default=0)
    total_eventos = models.IntegerField(default=0)
    repetidos = models.IntegerField(default=0)
    permitidos = models.IntegerField(default=0)
    denegados = models.IntegerField(default=0)
    avisos = models.IntegerField(default=0)
    fecha_desde = models.DateTimeField(null=True, blank=True)
    fecha_hasta = models.DateTimeField(null=True, blank=True)
    id_usuario = models.IntegerField(null=True, blank=True)
    creado_en = models.DateTimeField(null=True, blank=True)

    class Meta:
        managed = False
        db_table = "log_importaciones"
        verbose_name = "importación de logs"
        verbose_name_plural = "importaciones de logs"


class Evento(models.Model):
    """Solo las columnas principales; el resto está en la base y en datos (JSON)."""
    id_evento = models.BigAutoField(primary_key=True)
    importacion = models.ForeignKey(Importacion, on_delete=models.CASCADE, db_column="id_importacion",
                                    related_name="eventos")
    fuente = models.CharField(max_length=30)
    huella = models.CharField(max_length=32)
    fecha = models.DateTimeField(null=True, blank=True)
    tipo = models.CharField(max_length=60, null=True, blank=True)
    accion = models.CharField(max_length=12, null=True, blank=True)
    ip_origen = models.CharField(max_length=45, null=True, blank=True)
    ip_destino = models.CharField(max_length=45, null=True, blank=True)
    dominio = models.CharField(max_length=255, null=True, blank=True)
    id_conexion = models.CharField(max_length=30, null=True, blank=True)
    datos = models.TextField()

    class Meta:
        managed = False
        db_table = "log_eventos"
        verbose_name = "evento de log"
        verbose_name_plural = "eventos de logs"


class MapeoCampo(models.Model):
    pk = models.CompositePrimaryKey("fuente", "campo_origen")
    fuente = models.CharField(max_length=30)
    campo_origen = models.CharField(max_length=64)
    campo = models.CharField(max_length=64)
    prioridad = models.SmallIntegerField(default=1)

    class Meta:
        managed = False
        db_table = "log_mapeo_campos"
        verbose_name = "alias de campo"
        verbose_name_plural = "alias de campos"
