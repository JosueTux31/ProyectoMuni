# admin.py
from django.contrib import admin
from .models import (
    TipoIdentificacion, RolUsuario, TipoAutenticacion,
    Departamento, TipoTelefono, TipoCorreo
)

@admin.register(TipoIdentificacion)
class TipoIdentificacionAdmin(admin.ModelAdmin):
    # Configuración de visualización
    list_display = ('cod_tipo_identificacion', 'descripcion')

@admin.register(RolUsuario)
class RolUsuarioAdmin(admin.ModelAdmin):
    # Configuración de visualización
    list_display = ('cod_rol', 'descripcion')

@admin.register(TipoAutenticacion)
class TipoAutenticacionAdmin(admin.ModelAdmin):
    # Configuración de visualización
    list_display = ('cod_tipo_auth', 'descripcion')

@admin.register(Departamento)
class DepartamentoAdmin(admin.ModelAdmin):
    # Configuración de visualización
    list_display = ('cod_departamento', 'descripcion')

@admin.register(TipoTelefono)
class TipoTelefonoAdmin(admin.ModelAdmin):
    # Configuración de visualización
    list_display = ('cod_telefono', 'descripcion')

@admin.register(TipoCorreo)
class TipoCorreoAdmin(admin.ModelAdmin):
    # Configuración de visualización
    list_display = ('cod_correo', 'descripcion')