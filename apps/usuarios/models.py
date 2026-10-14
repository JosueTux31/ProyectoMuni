from django.db import models

# Create your models here.
"""Usuarios y sus tablas de detalle. managed = False: el esquema vive en MariaDB.

Las tablas de detalle tienen llave compuesta (id_usuario, num_linea),
declarada con models.CompositePrimaryKey (Django 5.2+).
"""
from django.db import models

from apps.geografia.models import Distrito


class Usuario(models.Model):
    id = models.AutoField(primary_key=True)

    rol = models.ForeignKey("catalogos.RolUsuario", on_delete=models.DO_NOTHING,
                            db_column="cod_rol", related_name="usuarios")
    tipo_auth = models.ForeignKey("catalogos.TipoAutenticacion", on_delete=models.DO_NOTHING,
                                  db_column="cod_tipo_auth", related_name="usuarios")
    tipo_identificacion = models.ForeignKey("catalogos.TipoIdentificacion", on_delete=models.DO_NOTHING,
                                            db_column="cod_tipo_identificacion", related_name="usuarios")
    dni = models.CharField(max_length=30)

    nombre = models.CharField(max_length=150)
    apellido1 = models.CharField(max_length=100, null=True, blank=True)
    apellido2 = models.CharField(max_length=100, null=True, blank=True)

    # La FK compuesta hacia geo_distritos existe en la base de datos;
    # en Django se maneja con los códigos y la propiedad `distrito`.
    cod_pais = models.CharField(max_length=10)
    cod_provincia = models.CharField(max_length=10)
    cod_canton = models.CharField(max_length=10)
    cod_distrito = models.CharField(max_length=10)
    otras_senas = models.TextField(null=True, blank=True)
    imagen_path = models.CharField(max_length=255, null=True, blank=True)

    departamento = models.ForeignKey("catalogos.Departamento", on_delete=models.DO_NOTHING,
                                     db_column="cod_departamento", null=True, blank=True,
                                     related_name="usuarios")
    usuario_red = models.CharField(max_length=50, null=True, blank=True, unique=True)
    password_hash = models.CharField(max_length=255, null=True, blank=True)

    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(editable=False)
    actualizado_en = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "usr_usuarios"
        verbose_name = "usuario"
        verbose_name_plural = "usuarios"
        ordering = ["nombre", "apellido1", "apellido2"]
        constraints = [
            models.UniqueConstraint(fields=["tipo_identificacion", "dni"], name="uk_usr_documento"),
        ]

    def __str__(self):
        return self.nombre_completo

    @property
    def nombre_completo(self):
        return " ".join(p for p in (self.nombre, self.apellido1, self.apellido2) if p)

    @property
    def distrito(self):
        return Distrito.objects.filter(pais_id=self.cod_pais, cod_provincia=self.cod_provincia,
                                       cod_canton=self.cod_canton,
                                       cod_distrito=self.cod_distrito).first()


class Telefono(models.Model):
    pk = models.CompositePrimaryKey("usuario_id", "num_linea")
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column="id_usuario",
                                related_name="telefonos")
    num_linea = models.IntegerField()
    tipo_telefono = models.ForeignKey("catalogos.TipoTelefono", on_delete=models.DO_NOTHING,
                                      db_column="cod_telefono", related_name="+")
    telefono = models.CharField(max_length=25)
    es_whatsapp = models.BooleanField(default=False)

    class Meta:
        managed = False
        db_table = "usr_telefonos"
        verbose_name = "teléfono"
        verbose_name_plural = "teléfonos"
        ordering = ["usuario_id", "num_linea"]

    def __str__(self):
        return self.telefono


class Correo(models.Model):
    pk = models.CompositePrimaryKey("usuario_id", "num_linea")
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column="id_usuario",
                                related_name="correos")
    num_linea = models.IntegerField()
    tipo_correo = models.ForeignKey("catalogos.TipoCorreo", on_delete=models.DO_NOTHING,
                                    db_column="cod_correo", related_name="+")
    correo = models.CharField(max_length=150)

    class Meta:
        managed = False
        db_table = "usr_correos"
        verbose_name = "correo"
        verbose_name_plural = "correos"
        ordering = ["usuario_id", "num_linea"]

    def __str__(self):
        return self.correo


class PaginaWeb(models.Model):
    pk = models.CompositePrimaryKey("usuario_id", "num_linea")
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column="id_usuario",
                                related_name="paginas_webs")
    num_linea = models.IntegerField()
    url_web = models.CharField(max_length=255)

    class Meta:
        managed = False
        db_table = "usr_paginas_webs"
        verbose_name = "página web"
        verbose_name_plural = "páginas web"
        ordering = ["usuario_id", "num_linea"]

    def __str__(self):
        return self.url_web


class HistorialClave(models.Model):
    pk = models.CompositePrimaryKey("usuario_id", "num_linea")
    usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column="id_usuario",
                                related_name="historial_claves")
    num_linea = models.IntegerField()
    password_hash = models.CharField(max_length=255)
    fecha_registro = models.DateTimeField(editable=False)

    class Meta:
        managed = False
        db_table = "usr_historiales_claves"
        verbose_name = "historial de clave"
        verbose_name_plural = "historial de claves"
        ordering = ["usuario_id", "-num_linea"]

    def __str__(self):
        return f"{self.usuario_id} #{self.num_linea}"
