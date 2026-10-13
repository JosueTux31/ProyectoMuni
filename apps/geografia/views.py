from rest_framework import viewsets, filters, status
from rest_framework.response import Response
from django.db import connection, DatabaseError

from .models import Pais, Provincia, Canton, Distrito
from .serializers import PaisSerializer, ProvinciaSerializer, CantonSerializer, DistritoSerializer

class ProcedimientoGeograficoMixin:
    """
    Mixin para catálogos geográficos.
    Usa parámetros IN (sin OUT) porque los IDs son strings provistos por el usuario.
    Tampoco permite UPDATE ni DELETE porque el DBA no definió esos procedimientos.
    """
    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        if not hasattr(self, 'sp_insert') or not self.sp_insert:
            return Response({"error": "Procedimiento de inserción no definido."}, status=status.HTTP_405_METHOD_NOT_ALLOWED)

        # Extraemos los valores en el orden exacto definido en self.sp_args
        clean_params = []
        for field in self.sp_args:
            val = serializer.validated_data.get(field)
            # Si el campo es una ForeignKey, Django devuelve la instancia del modelo. 
            # Extraemos su PK (el código string) para pasarlo a MySQL.
            if hasattr(val, 'pk'):
                clean_params.append(val.pk)
            else:
                clean_params.append(val)

        try:
            with connection.cursor() as cursor:
                # Genera los placeholders dinámicamente (%s, %s, %s...)
                placeholders = ", ".join(["%s"] * len(clean_params))
                cursor.execute(f"CALL {self.sp_insert}({placeholders});", clean_params)

            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    def update(self, request, *args, **kwargs):
        return Response({"error": "Actualización no permitida por políticas del DBA (No hay SP)."}, status=status.HTTP_405_METHOD_NOT_ALLOWED)

    def destroy(self, request, *args, **kwargs):
        return Response({"error": "Eliminación no permitida por políticas del DBA (No hay SP)."}, status=status.HTTP_405_METHOD_NOT_ALLOWED)

# =====================================================================
# VIEWSETS GEOGRÁFICOS
# =====================================================================

class PaisViewSet(ProcedimientoGeograficoMixin, viewsets.ModelViewSet):
    queryset = Pais.objects.all()
    serializer_class = PaisSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['nombre_pais', 'cod_pais']
    
    sp_insert = 'sp_geo_insert_pais'
    sp_args = ['cod_pais', 'nombre_pais']


class ProvinciaViewSet(ProcedimientoGeograficoMixin, viewsets.ModelViewSet):
    queryset = Provincia.objects.all()
    serializer_class = ProvinciaSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['nombre_provincia', 'cod_provincia']
    
    sp_insert = 'sp_geo_insert_provincia'
    sp_args = ['cod_pais', 'cod_provincia', 'nombre_provincia']


class CantonViewSet(ProcedimientoGeograficoMixin, viewsets.ModelViewSet):
    queryset = Canton.objects.all()
    serializer_class = CantonSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['nombre_canton', 'cod_canton']
    
    sp_insert = 'sp_geo_insert_canton'
    sp_args = ['cod_pais', 'cod_provincia', 'cod_canton', 'nombre_canton']


class DistritoViewSet(ProcedimientoGeograficoMixin, viewsets.ModelViewSet):
    queryset = Distrito.objects.all()
    serializer_class = DistritoSerializer
    filter_backends = [filters.SearchFilter]
    search_fields = ['nombre_distrito', 'cod_distrito']
    
    sp_insert = 'sp_geo_insert_distrito'
    sp_args = ['cod_pais', 'cod_provincia', 'cod_canton', 'cod_distrito', 'nombre_distrito']