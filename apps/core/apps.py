from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = "apps.core"
    label = "core"
    verbose_name = "Núcleo (llamadas a procedimientos almacenados)"

    def ready(self):
        # Registra el esquema de autenticación en Swagger
        from . import esquema  # noqa: F401
