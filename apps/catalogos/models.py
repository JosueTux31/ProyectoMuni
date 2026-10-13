# models.py
from django.db import models

class TipoIdentificacion(models.Model):
    # Datos de identificación
    cod_tipo_identificacion = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    # Metadatos del modelo
    class Meta:
        db_table = 'cat_tipos_identificacion'
        verbose_name = 'Tipo de Identificación'
        verbose_name_plural = 'Tipos de Identificación'

    # Representación en texto
    def __str__(self):
        return self.descripcion

class RolUsuario(models.Model):
    # Datos de clasificación
    cod_rol = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    # Metadatos del modelo
    class Meta:
        db_table = 'cat_roles_usuarios'
        verbose_name = 'Rol de Usuario'
        verbose_name_plural = 'Roles de Usuario'

    # Representación en texto
    def __str__(self):
        return self.descripcion

class TipoAutenticacion(models.Model):
    # Datos de clasificación
    cod_tipo_auth = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=80)

    # Metadatos del modelo
    class Meta:
        db_table = 'cat_tipos_autenticacion'
        verbose_name = 'Tipo de Autenticación'
        verbose_name_plural = 'Tipos de Autenticación'

    # Representación en texto
    def __str__(self):
        return self.descripcion

class Departamento(models.Model):
    # Datos del departamento
    cod_departamento = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=120)

    # Metadatos del modelo
    class Meta:
        db_table = 'cat_departamentos'
        verbose_name = 'Departamento'
        verbose_name_plural = 'Departamentos'

    # Representación en texto
    def __str__(self):
        return self.descripcion

class TipoTelefono(models.Model):
    # Datos del tipo
    cod_telefono = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    # Metadatos del modelo
    class Meta:
        db_table = 'cat_tipos_telefonos'
        verbose_name = 'Tipo de Teléfono'
        verbose_name_plural = 'Tipos de Teléfonos'

    # Representación en texto
    def __str__(self):
        return self.descripcion

class TipoCorreo(models.Model):
    # Datos del tipo
    cod_correo = models.AutoField(primary_key=True)
    descripcion = models.CharField(max_length=50)

    # Metadatos del modelo
    class Meta:
        db_table = 'cat_tipos_correos'
        verbose_name = 'Tipo de Correo'
        verbose_name_plural = 'Tipos de Correos'

    # Representación en texto
    def __str__(self):
        return self.descripcion