# admin.py
from django.contrib import admin
from .models import Usuario, UsuarioTelefono, UsuarioCorreo, UsuarioPaginaWeb

class TelefonoInline(admin.TabularInline):
    # Configuración de elementos en línea
    model = UsuarioTelefono
    extra = 1

class CorreoInline(admin.TabularInline):
    # Configuración de elementos en línea
    model = UsuarioCorreo
    extra = 1

class PaginaWebInline(admin.TabularInline):
    # Configuración de elementos en línea
    model = UsuarioPaginaWeb
    extra = 1

@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    # Visualización principal de la tabla
    list_display = ('dni', 'nombre', 'apellido1', 'cod_rol', 'usuario_red', 'activo')
    
    # Opciones de búsqueda y filtrado
    list_filter = ('cod_rol', 'activo', 'cod_departamento')
    search_fields = ('dni', 'nombre', 'apellido1', 'usuario_red')
    
    # Formularios relacionados anidados
    inlines = [TelefonoInline, CorreoInline, PaginaWebInline]