from django.db import connection, DatabaseError, transaction
from django.db.models import ProtectedError

from rest_framework import filters, status, viewsets
from rest_framework.permissions import AllowAny
from rest_framework.response import Response

from .models import (
    TipoIdentificacion,
    RolUsuario,
    TipoAutenticacion,
    Departamento,
    TipoTelefono,
    TipoCorreo,
)

from .serializers import (
    TipoIdentificacionSerializer,
    RolUsuarioSerializer,
    TipoAutenticacionSerializer,
    DepartamentoSerializer,
    TipoTelefonoSerializer,
    TipoCorreoSerializer,
)


class ProcedimientoCatalogoMixin:
    """
    Mixin común para los catálogos.

    - CREATE utiliza el procedimiento almacenado configurado.
    - UPDATE utiliza el ORM de Django.
    - DELETE utiliza el ORM de Django.
    """

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        descripcion = serializer.validated_data["descripcion"]

        try:
            with transaction.atomic():
                with connection.cursor() as cursor:
                    # Inicializar parámetro OUT
                    cursor.execute(
                        f"SET @{self.out_param_name} = 0;"
                    )

                    # Ejecutar procedimiento almacenado
                    cursor.execute(
                        f"CALL {self.sp_insert}(%s, @{self.out_param_name});",
                        [descripcion],
                    )

                    # Obtener el ID generado
                    cursor.execute(
                        f"SELECT @{self.out_param_name};"
                    )

                    resultado = cursor.fetchone()

                    if not resultado:
                        raise DatabaseError(
                            "El procedimiento no devolvió el ID generado."
                        )

                    nuevo_id = resultado[0]

            pk_field = self.queryset.model._meta.pk.name

            return Response(
                {
                    pk_field: nuevo_id,
                    "descripcion": descripcion,
                },
                status=status.HTTP_201_CREATED,
            )

        except DatabaseError as error:
            return Response(
                {
                    "error": "No fue posible crear el registro.",
                    "detalle": str(error),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

    def update(self, request, *args, **kwargs):
        """
        Actualización genérica utilizando el ORM de Django.
        Funciona para todos los catálogos.
        """
        partial = kwargs.pop("partial", False)
        instancia = self.get_object()

        serializer = self.get_serializer(
            instancia,
            data=request.data,
            partial=partial,
        )

        serializer.is_valid(raise_exception=True)

        try:
            instancia_actualizada = serializer.save()

            return Response(
                self.get_serializer(instancia_actualizada).data,
                status=status.HTTP_200_OK,
            )

        except DatabaseError as error:
            return Response(
                {
                    "error": "No fue posible actualizar el registro.",
                    "detalle": str(error),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

    def destroy(self, request, *args, **kwargs):
        """
        Eliminación genérica utilizando el ORM de Django.
        """
        instancia = self.get_object()

        try:
            instancia.delete()

            return Response(
                status=status.HTTP_204_NO_CONTENT
            )

        except ProtectedError:
            return Response(
                {
                    "error": (
                        "No se puede eliminar este registro porque "
                        "está siendo utilizado por otros datos."
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        except DatabaseError as error:
            return Response(
                {
                    "error": "No fue posible eliminar el registro.",
                    "detalle": str(error),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )


class BaseCatalogoViewSet(
    ProcedimientoCatalogoMixin,
    viewsets.ModelViewSet,
):
    """
    ViewSet base para todos los catálogos.
    """

    permission_classes = [AllowAny]

    filter_backends = [
        filters.SearchFilter,
        filters.OrderingFilter,
    ]

    search_fields = ["descripcion"]
    ordering_fields = ["descripcion"]
    ordering = ["descripcion"]


class TipoIdentificacionViewSet(BaseCatalogoViewSet):
    queryset = TipoIdentificacion.objects.all()
    serializer_class = TipoIdentificacionSerializer

    sp_insert = "sp_cat_insert_tipo_identificacion"
    out_param_name = "p_cod_tipo_identificacion"


class RolUsuarioViewSet(BaseCatalogoViewSet):
    queryset = RolUsuario.objects.all()
    serializer_class = RolUsuarioSerializer

    sp_insert = "sp_cat_insert_rol_usuario"
    out_param_name = "p_cod_rol"


class TipoAutenticacionViewSet(BaseCatalogoViewSet):
    queryset = TipoAutenticacion.objects.all()
    serializer_class = TipoAutenticacionSerializer

    sp_insert = "sp_cat_insert_tipo_autenticacion"
    out_param_name = "p_cod_tipo_auth"


class DepartamentoViewSet(BaseCatalogoViewSet):
    queryset = Departamento.objects.all()
    serializer_class = DepartamentoSerializer

    sp_insert = "sp_cat_insert_departamento"
    out_param_name = "p_cod_departamento"


class TipoTelefonoViewSet(BaseCatalogoViewSet):
    queryset = TipoTelefono.objects.all()
    serializer_class = TipoTelefonoSerializer

    sp_insert = "sp_cat_insert_tipo_telefono"
    out_param_name = "p_cod_telefono"


class TipoCorreoViewSet(BaseCatalogoViewSet):
    queryset = TipoCorreo.objects.all()
    serializer_class = TipoCorreoSerializer

    sp_insert = "sp_cat_insert_tipo_correo"
    out_param_name = "p_cod_correo"