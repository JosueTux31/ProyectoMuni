// Configuración de la página.
export const CONFIG = {
  // Dirección del backend Django. Vacío = el mismo servidor que sirve esta
  // página (recomendado). Si abre la página desde otro lado, ponga por
  // ejemplo "http://LD12-SRV-01:8001" y active CORS en Django.
  API_BASE: "",

  // Nombre que aparece en la barra lateral y en el inicio de sesión.
  INSTITUCION: "Municipalidad",

  // Claves anteriores que no se pueden reutilizar al cambiar la clave.
  HISTORIAL_CLAVES_BLOQUEADAS: 5,
};
