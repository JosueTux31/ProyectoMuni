"""Tabla aud_auditorias (managed = False: la crea 04_fotos_y_auditoria.sql).
La llenan los disparadores de MariaDB; la API solo la consulta."""
from django.db import models


class Auditoria(models.Model):
    id = models.BigAutoField(primary_key=True)
    fecha = models.DateTimeField()
    id_usuario = models.IntegerField(null=True)
    nombre_usuario = models.CharField(max_length=255, null=True)
    ip = models.CharField(max_length=45, null=True)
    accion = models.CharField(max_length=20)
    tabla = models.CharField(max_length=64, null=True)
    llave = models.CharField(max_length=255, null=True)
    id_persona = models.IntegerField(null=True)
    descripcion = models.CharField(max_length=255, null=True)
    datos_antes = models.JSONField(null=True)
    datos_despues = models.JSONField(null=True)

    class Meta:
        managed = False
        db_table = "aud_auditorias"
        ordering = ["-id"]
        verbose_name = "registro de auditoría"
        verbose_name_plural = "auditoría"
