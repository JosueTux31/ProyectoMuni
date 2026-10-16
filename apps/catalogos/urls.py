from apps.core.rutas import rutas_crud

from . import views as v

app_name = "catalogos"

urlpatterns = [
    *rutas_crud("tipos-identificaciones/", "<int:cod_tipo_identificacion>/",
                v.TipoIdentificacionViewSet, "tipos-identificaciones"),
    *rutas_crud("roles/", "<int:cod_rol>/", v.RolUsuarioViewSet, "roles"),
    *rutas_crud("tipos-autenticaciones/", "<int:cod_tipo_auth>/",
                v.TipoAutenticacionViewSet, "tipos-autenticaciones"),
    *rutas_crud("departamentos/", "<int:cod_departamento>/", v.DepartamentoViewSet, "departamentos"),
    *rutas_crud("tipos-telefonos/", "<int:cod_telefono>/", v.TipoTelefonoViewSet, "tipos-telefonos"),
    *rutas_crud("tipos-correos/", "<int:cod_correo>/", v.TipoCorreoViewSet, "tipos-correos"),
    *rutas_crud("categorias-proveedores/", "<int:cod_categoria>/",
                v.CategoriaProveedorViewSet, "categorias-proveedores"),
]
