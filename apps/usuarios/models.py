# models.py
from django.db import models
from apps.catalogos.models import (
    RolUsuario, TipoAutenticacion, TipoIdentificacion, Departamento,
    TipoTelefono, TipoCorreo
)
from apps.geografia.models import Distrito

class Usuario(models.Model):
    # Llave principal
    id = models.AutoField(primary_key=True)
    
    # Clasificación y documentos
    cod_rol = models.ForeignKey(
        RolUsuario, on_delete=models.RESTRICT, db_column='cod_rol', verbose_name="Rol de Usuario"
    )
    cod_tipo_auth = models.ForeignKey(
        TipoAutenticacion, on_delete=models.RESTRICT, db_column='cod_tipo_auth', verbose_name="Tipo de Autenticación"
    )
    cod_tipo_identificacion = models.ForeignKey(
        TipoIdentificacion, on_delete=models.RESTRICT, db_column='cod_tipo_identificacion', verbose_name="Tipo Identificación"
    )
    dni = models.CharField(max_length=30, verbose_name="DNI / Cédula")
    
    # Datos personales
    nombre = models.CharField(max_length=150, verbose_name="Nombre")
    apellido1 = models.CharField(max_length=100, blank=True, null=True, verbose_name="Primer Apellido")
    apellido2 = models.CharField(max_length=100, blank=True, null=True, verbose_name="Segundo Apellido")
    
    # Ubicación geográfica
    cod_pais = models.CharField(max_length=10)
    cod_provincia = models.CharField(max_length=10)
    cod_canton = models.CharField(max_length=10)
    cod_distrito = models.ForeignKey(
        Distrito, on_delete=models.RESTRICT, db_column='cod_distrito', verbose_name="Distrito"
    )
    otras_senas = models.TextField(blank=True, null=True, verbose_name="Otras Señas")
    imagen_path = models.CharField(max_length=255, blank=True, null=True)
    
    # Colaborador / Sistema
    cod_departamento = models.ForeignKey(
        Departamento, on_delete=models.SET_NULL, null=True, blank=True, db_column='cod_departamento'
    )
    usuario_red = models.CharField(max_length=50, unique=True, blank=True, null=True)
    password_hash = models.CharField(max_length=255, blank=True, null=True)
    
    # Datos de auditoría
    activo = models.BooleanField(default=True)
    creado_en = models.DateTimeField(auto_now_add=True)
    actualizado_en = models.DateTimeField(auto_now=True)

    # Metadatos del modelo
    class Meta:
        db_table = 'usr_usuarios'
        unique_together = (('cod_tipo_identificacion', 'dni'),)
        verbose_name = 'Usuario'
        verbose_name_plural = 'Usuarios'

    # Representación en texto
    def __str__(self):
        return f"{self.dni} - {self.nombre} {self.apellido1 or ''}".strip()


# -- Tablas hijas de contacto e historial --

class UsuarioTelefono(models.Model):
    # Relación y orden
    id_usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column='id_usuario', related_name='telefonos')
    num_linea = models.IntegerField()
    
    # Datos de contacto
    cod_telefono = models.ForeignKey(TipoTelefono, on_delete=models.RESTRICT, db_column='cod_telefono')
    telefono = models.CharField(max_length=25)
    es_whatsapp = models.BooleanField(default=False)

    # Metadatos del modelo
    class Meta:
        db_table = 'usr_telefonos'
        unique_together = (('id_usuario', 'num_linea'),)
        verbose_name = 'Teléfono de Usuario'
        verbose_name_plural = 'Teléfonos de Usuarios'

    # Representación en texto
    def __str__(self):
        return f"{self.telefono} ({self.id_usuario})"


class UsuarioCorreo(models.Model):
    # Relación y orden
    id_usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column='id_usuario', related_name='correos')
    num_linea = models.IntegerField()
    
    # Datos de contacto
    cod_correo = models.ForeignKey(TipoCorreo, on_delete=models.RESTRICT, db_column='cod_correo')
    correo = models.EmailField(max_length=150)

    # Metadatos del modelo
    class Meta:
        db_table = 'usr_correos'
        unique_together = (('id_usuario', 'num_linea'),)
        verbose_name = 'Correo de Usuario'
        verbose_name_plural = 'Correos de Usuarios'

    # Representación en texto
    def __str__(self):
        return f"{self.correo} ({self.id_usuario})"


class UsuarioPaginaWeb(models.Model):
    # Relación y orden
    id_usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column='id_usuario', related_name='paginas_web')
    num_linea = models.IntegerField()
    
    # Datos del enlace
    url_web = models.URLField(max_length=255)

    # Metadatos del modelo
    class Meta:
        db_table = 'usr_paginas_web'
        unique_together = (('id_usuario', 'num_linea'),)
        verbose_name = 'Página Web'
        verbose_name_plural = 'Páginas Web'


class UsuarioHistorialClave(models.Model):
    # Relación y orden
    id_usuario = models.ForeignKey(Usuario, on_delete=models.CASCADE, db_column='id_usuario', related_name='historial_claves')
    num_linea = models.IntegerField()
    
    # Datos de seguridad y auditoría
    password_hash = models.CharField(max_length=255)
    fecha_registro = models.DateTimeField(auto_now_add=True)

    # Metadatos del modelo
    class Meta:
        db_table = 'usr_historiales_claves'
        unique_together = (('id_usuario', 'num_linea'),)
        verbose_name = 'Historial de Clave'
        verbose_name_plural = 'Historiales de Claves'