# views.py
from rest_framework import viewsets, status
from rest_framework.response import Response
from django.db import connection, DatabaseError
from .models import Usuario, UsuarioTelefono, UsuarioCorreo, UsuarioPaginaWeb
from .serializers import (
    UsuarioSerializer, UsuarioTelefonoSerializer, UsuarioCorreoSerializer, UsuarioPaginaWebSerializer
)

class UsuarioViewSet(viewsets.ModelViewSet):
    queryset = Usuario.objects.all()
    serializer_class = UsuarioSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            with connection.cursor() as cursor:
                # 1. Insertar el Usuario
                cursor.execute("""
                    CALL sp_usr_insert_usuario(
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, @p_id_usuario
                    );
                """, [
                    data.get('cod_rol').pk,
                    data.get('cod_tipo_auth').pk,
                    data.get('cod_tipo_identificacion').pk,
                    data.get('dni'),
                    data.get('nombre'),
                    data.get('apellido1'),
                    data.get('apellido2'),
                    data.get('cod_pais'),
                    data.get('cod_provincia'),
                    data.get('cod_canton'),
                    data.get('cod_distrito').pk,
                    data.get('otras_senas'),
                    data.get('imagen_path'),
                    data.get('cod_departamento').pk if data.get('cod_departamento') else None,
                    data.get('usuario_red'),
                    data.get('password_hash')
                ])

                # Obtener el ID generado
                cursor.execute("SELECT @p_id_usuario;")
                usuario_id = cursor.fetchone()[0]

                # 2. Insertar Teléfonos (si vienen)
                telefonos_data = request.data.get('telefonos', [])
                for tel in telefonos_data:
                    cursor.execute("""
                        CALL sp_usr_insert_telefono(%s, %s, %s, %s, @p_num_linea);
                    """, [
                        usuario_id, 
                        tel.get('cod_telefono'), 
                        tel.get('telefono'), 
                        tel.get('es_whatsapp', False)
                    ])

                # 3. Insertar Correos (si vienen)
                correos_data = request.data.get('correos', [])
                for cor in correos_data:
                    cursor.execute("""
                        CALL sp_usr_insert_correo(%s, %s, %s, @p_num_linea);
                    """, [
                        usuario_id,
                        cor.get('cod_correo'),
                        cor.get('correo')
                    ])
                    
                # 4. Insertar Páginas Web (si vienen)
                webs_data = request.data.get('paginas_web', [])
                for web in webs_data:
                    cursor.execute("""
                        CALL sp_usr_insert_pagina_web(%s, %s, @p_num_linea);
                    """, [
                        usuario_id,
                        web.get('url_web')
                    ])

                # Si venía password, insertamos en el historial
                if data.get('password_hash'):
                     cursor.execute("""
                        CALL sp_usr_insert_historial_clave(%s, %s, @p_num_linea);
                    """, [
                        usuario_id,
                        data.get('password_hash')
                    ])

            # Retornar los datos insertados (podríamos hacer un refetch para tener las inlines completas)
            nuevo_usuario = Usuario.objects.get(id=usuario_id)
            return Response(UsuarioSerializer(nuevo_usuario).data, status=status.HTTP_201_CREATED)

        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=kwargs.get('partial', False))
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        try:
            with connection.cursor() as cursor:
                cursor.execute("""
                    CALL sp_usr_update_usuario(
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    );
                """, [
                    instance.id,
                    data.get('cod_rol', instance.cod_rol).pk,
                    data.get('cod_tipo_auth', instance.cod_tipo_auth).pk,
                    data.get('cod_tipo_identificacion', instance.cod_tipo_identificacion).pk,
                    data.get('dni', instance.dni),
                    data.get('nombre', instance.nombre),
                    data.get('apellido1', instance.apellido1),
                    data.get('apellido2', instance.apellido2),
                    data.get('cod_pais', instance.cod_pais),
                    data.get('cod_provincia', instance.cod_provincia),
                    data.get('cod_canton', instance.cod_canton),
                    data.get('cod_distrito', instance.cod_distrito).pk,
                    data.get('otras_senas', instance.otras_senas),
                    data.get('imagen_path', instance.imagen_path),
                    data.get('cod_departamento', instance.cod_departamento).pk if data.get('cod_departamento') else None,
                    data.get('usuario_red', instance.usuario_red),
                    data.get('password_hash', instance.password_hash)
                ])

            actualizado = Usuario.objects.get(id=instance.id)
            return Response(UsuarioSerializer(actualizado).data)

        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            with connection.cursor() as cursor:
                # Usar sp_usr_delete_usuario_fisico para eliminación real o sp_usr_desactivar_usuario para lógica
                cursor.execute("CALL sp_usr_delete_usuario_fisico(%s);", [instance.id])
            return Response(status=status.HTTP_204_NO_CONTENT)
        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class UsuarioTelefonoViewSet(viewsets.ModelViewSet):
    queryset = UsuarioTelefono.objects.all()
    serializer_class = UsuarioTelefonoSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=kwargs.get('partial', False))
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        
        try:
             with connection.cursor() as cursor:
                 cursor.execute("""
                     CALL sp_usr_update_telefono(%s, %s, %s, %s, %s);
                 """, [
                     instance.id_usuario_id,
                     instance.num_linea,
                     data.get('cod_telefono', instance.cod_telefono).pk,
                     data.get('telefono', instance.telefono),
                     data.get('es_whatsapp', instance.es_whatsapp)
                 ])
             return Response(serializer.data)
        except DatabaseError as e:
             return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
             
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            with connection.cursor() as cursor:
                cursor.execute("CALL sp_usr_delete_telefono(%s, %s);", [instance.id_usuario_id, instance.num_linea])
            return Response(status=status.HTTP_204_NO_CONTENT)
        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class UsuarioCorreoViewSet(viewsets.ModelViewSet):
    queryset = UsuarioCorreo.objects.all()
    serializer_class = UsuarioCorreoSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=kwargs.get('partial', False))
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        
        try:
             with connection.cursor() as cursor:
                 cursor.execute("""
                     CALL sp_usr_update_correo(%s, %s, %s, %s);
                 """, [
                     instance.id_usuario_id,
                     instance.num_linea,
                     data.get('cod_correo', instance.cod_correo).pk,
                     data.get('correo', instance.correo)
                 ])
             return Response(serializer.data)
        except DatabaseError as e:
             return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
             
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            with connection.cursor() as cursor:
                cursor.execute("CALL sp_usr_delete_correo(%s, %s);", [instance.id_usuario_id, instance.num_linea])
            return Response(status=status.HTTP_204_NO_CONTENT)
        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

class UsuarioPaginaWebViewSet(viewsets.ModelViewSet):
    queryset = UsuarioPaginaWeb.objects.all()
    serializer_class = UsuarioPaginaWebSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=kwargs.get('partial', False))
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        
        try:
             with connection.cursor() as cursor:
                 cursor.execute("""
                     CALL sp_usr_update_pagina_web(%s, %s, %s);
                 """, [
                     instance.id_usuario_id,
                     instance.num_linea,
                     data.get('url_web', instance.url_web)
                 ])
             return Response(serializer.data)
        except DatabaseError as e:
             return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)
             
    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        try:
            with connection.cursor() as cursor:
                cursor.execute("CALL sp_usr_delete_pagina_web(%s, %s);", [instance.id_usuario_id, instance.num_linea])
            return Response(status=status.HTTP_204_NO_CONTENT)
        except DatabaseError as e:
            return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)