from django.db import models

# Create your models here.
"""Catálogos del sistema (tablas cat_*). managed = False: el esquema vive en MariaDB."""
from django.db import models


class CatalogoBase(models.Model):
    def __str__(self):
        return self.descripcion

    class Meta:
        abstract = True
        managed = False
        ordering = ["descripcion"]


class TipoIdentificacion(CatalogoBase):
    cod_tipo_identificacion = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_tipos_identificaciones"
        verbose_name = "tipo de identificación"
        verbose_name_plural = "tipos de identificaciones"


class RolUsuario(CatalogoBase):
    cod_rol = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_roles_usuarios"
        verbose_name = "rol de usuario"
        verbose_name_plural = "roles de usuarios"


class TipoAutenticacion(CatalogoBase):
    cod_tipo_auth = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=80)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_tipos_autenticaciones"
        verbose_name = "tipo de autenticación"
        verbose_name_plural = "tipos de autenticaciones"


class Departamento(CatalogoBase):
    cod_departamento = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=120)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_departamentos"
        verbose_name = "departamento"
        verbose_name_plural = "departamentos"


class TipoTelefono(CatalogoBase):
    cod_telefono = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_tipos_telefonos"
        verbose_name = "tipo de teléfono"
        verbose_name_plural = "tipos de teléfonos"


class TipoCorreo(CatalogoBase):
    cod_correo = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    class Meta(CatalogoBase.Meta):
        db_table = "cat_tipos_correos"
        verbose_name = "tipo de correo"
        verbose_name_plural = "tipos de correos"
