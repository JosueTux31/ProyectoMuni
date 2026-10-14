"""ViewSet genérico que implementa el CRUD llamando a los procedimientos
``<sp>_listar``, ``<sp>_obtener``, ``<sp>_insertar``, ``<sp>_actualizar`` y
``<sp>_eliminar``. Cada recurso solo declara sus nombres de campos.
"""
from rest_framework import status, viewsets
from rest_framework.exceptions import NotFound
from rest_framework.response import Response

from .db import llamar_sp


class SPViewSet(viewsets.GenericViewSet):
    # Prefijo de los procedimientos, p. ej. "sp_geo_paises"
    sp = ""

    # Llave primaria en el orden de la firma de _obtener/_actualizar/_eliminar.
    # Los nombres deben coincidir con los parámetros de la URL de detalle.
    campos_pk = ()

    # Parámetros de la URL que se anteponen en _insertar y _listar
    # (p. ej. "id_usuario" en /usuarios/5/telefonos/).
    campos_padre = ()

    # Campos del cuerpo, en el orden de los parámetros IN del SP.
    campos_insertar = ()
    campos_actualizar = ()

    # Filtros de ?query_string para _listar, en orden del SP.
    filtros_listar = ()

    # True si _insertar tiene un último parámetro OUT con el código generado.
    insertar_devuelve_codigo = False

    # Columnas TINYINT(1) que se devuelven como true/false en el JSON.
    campos_bool = ()

    # Columnas que nunca salen en la respuesta.
    campos_ocultos = ("password_hash",)

    serializer_class = None             # Validación al crear (y al actualizar si no hay otro)
    serializer_actualizar_class = None  # Validación al actualizar
    serializer_filtros_class = None     # Validación de los filtros de listar

    pagination_class = None
    filter_backends = ()

    # ------------------------------------------------------------------ hooks
    def get_serializer_class(self):
        if self.action in ("update", "partial_update") and self.serializer_actualizar_class:
            return self.serializer_actualizar_class
        return self.serializer_class

    def preparar_datos(self, datos, accion):
        """Permite transformar los datos validados antes del SP
        (p. ej. convertir una clave en hash). ``accion``: insertar | actualizar."""
        return datos

    def salida(self, fila):
        fila = {k: v for k, v in fila.items() if k not in self.campos_ocultos}
        for campo in self.campos_bool:
            if fila.get(campo) is not None:
                fila[campo] = bool(fila[campo])
        return fila

    # ---------------------------------------------------------------- helpers
    def _valores_pk(self, kwargs):
        return [kwargs[c] for c in self.campos_pk]

    def _valores_padre(self, kwargs):
        return [kwargs[c] for c in self.campos_padre]

    def _obtener(self, valores_pk):
        filas, _ = llamar_sp(f"{self.sp}_obtener", valores_pk)
        if not filas:
            raise NotFound("El registro no existe.")
        return filas[0]

    def _validar(self, clase, datos):
        serializer = clase(data=datos)
        serializer.is_valid(raise_exception=True)
        return dict(serializer.validated_data)

    # ------------------------------------------------------------------- CRUD
    def list(self, request, **kwargs):
        params = self._valores_padre(kwargs)
        if self.filtros_listar:
            filtros = self._validar(self.serializer_filtros_class, request.query_params)
            params += [filtros.get(c) for c in self.filtros_listar]
        filas, _ = llamar_sp(f"{self.sp}_listar", params)
        return Response([self.salida(f) for f in filas])

    def retrieve(self, request, **kwargs):
        return Response(self.salida(self._obtener(self._valores_pk(kwargs))))

    def create(self, request, **kwargs):
        datos = self._validar(self.serializer_class, request.data)
        datos = self.preparar_datos(datos, "insertar")

        params = self._valores_padre(kwargs) + [datos.get(c) for c in self.campos_insertar]
        _, codigo = llamar_sp(f"{self.sp}_insertar", params,
                              con_salida=self.insertar_devuelve_codigo)

        # La llave del nuevo registro sale de la URL, del cuerpo o del OUT del SP.
        pk = []
        for campo in self.campos_pk:
            if campo in kwargs:
                pk.append(kwargs[campo])
            elif campo in datos:
                pk.append(datos[campo])
            else:
                pk.append(codigo)

        return Response(self.salida(self._obtener(pk)), status=status.HTTP_201_CREATED)

    def update(self, request, partial=False, **kwargs):
        pk = self._valores_pk(kwargs)
        entrada = request.data
        if partial:
            # PATCH: se completa con los valores actuales, porque el SP
            # _actualizar recibe todos los campos.
            entrada = {**self._obtener(pk), **request.data}

        clase = self.serializer_actualizar_class or self.serializer_class
        datos = self.preparar_datos(self._validar(clase, entrada), "actualizar")

        llamar_sp(f"{self.sp}_actualizar", pk + [datos.get(c) for c in self.campos_actualizar])
        return Response(self.salida(self._obtener(pk)))

    def partial_update(self, request, **kwargs):
        return self.update(request, partial=True, **kwargs)

    def destroy(self, request, **kwargs):
        llamar_sp(f"{self.sp}_eliminar", self._valores_pk(kwargs))
        return Response(status=status.HTTP_204_NO_CONTENT)
