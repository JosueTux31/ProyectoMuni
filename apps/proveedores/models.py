"""Los proveedores viven en la misma tabla usr_usuarios (es_proveedor = True).
Proveedor es un modelo proxy: misma tabla, pero Proveedor.objects solo
devuelve proveedores. Las escrituras de la API pasan por los procedimientos
sp_prv_proveedores_*."""
from django.db import models

from apps.usuarios.models import Usuario


class SoloProveedoresManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(es_proveedor=True)


class Proveedor(Usuario):
    objects = SoloProveedoresManager()

    class Meta:
        proxy = True
        verbose_name = "proveedor"
        verbose_name_plural = "proveedores"
        ordering = ["nombre", "apellido1", "apellido2"]
