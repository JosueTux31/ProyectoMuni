// Cliente de las APIs de Django: agrega el token de sesión y traduce errores.
import { CONFIG } from "./config.js";

const CLAVE_SESION = "muni.sesion";

export const sesion = {
  leer() {
    try { return JSON.parse(sessionStorage.getItem(CLAVE_SESION)); } catch { return null; }
  },
  guardar(datos) {
    try { sessionStorage.setItem(CLAVE_SESION, JSON.stringify(datos)); } catch { /* sin almacenamiento */ }
  },
  borrar() {
    try { sessionStorage.removeItem(CLAVE_SESION); } catch { /* sin almacenamiento */ }
  },
};

export class ErrorApi extends Error {
  constructor(mensaje, estado = 0, campos = {}) {
    super(mensaje);
    this.estado = estado;
    this.campos = campos; // { nombre_campo: "mensaje" }
  }
}

let alExpirarSesion = () => {};
export function cuandoExpireSesion(fn) { alExpirarSesion = fn; }

const ETIQUETAS = {
  descripcion: "Descripción", dni: "Identificación", usuario_red: "Usuario de red",
  cod_categoria: "Categoría", mapa: "Ubicación en el mapa", archivo: "Archivo",
  password: "Clave", password_actual: "Clave actual", correo: "Correo", url_web: "Página web",
  telefono: "Teléfono", cod_rol: "Rol", activo: "Estado",
  serie: "Serie", tipo_disp: "Tipo de dispositivo", id_marca: "Marca", id_modelo: "Modelo", id_doc: "Tipo de documento",
  direccion_ip: "Dirección IP", direccion_mac: "Dirección MAC", gps: "Ubicación GPS",
  cant_ptos_ethernet: "Puertos Ethernet", cant_ptos_sfp: "Puertos SFP", otras_senas: "Otras señas",
};

function textoDe(valor) {
  if (Array.isArray(valor)) return valor.map(textoDe).join(" ");
  if (valor && typeof valor === "object") return Object.values(valor).map(textoDe).join(" ");
  return String(valor ?? "");
}

function interpretarError(cuerpo, estado) {
  const campos = {};
  let mensaje = "";

  if (cuerpo && typeof cuerpo === "object" && !Array.isArray(cuerpo)) {
    for (const [clave, valor] of Object.entries(cuerpo)) {
      if (clave === "detail" || clave === "non_field_errors") mensaje = textoDe(valor);
      else if (clave !== "db") campos[clave] = textoDe(valor);
    }
    if (!mensaje && Object.keys(campos).length) {
      const [clave, texto] = Object.entries(campos)[0];
      mensaje = `${ETIQUETAS[clave] || clave}: ${texto}`;
    }
  }

  if (!mensaje) {
    mensaje = {
      400: "Los datos enviados no son válidos.",
      401: "Su sesión no es válida. Inicie sesión de nuevo.",
      403: "No tiene permiso para hacer esto.",
      404: "El registro no existe.",
      409: "La operación entra en conflicto con otros datos.",
    }[estado] || `El servidor respondió con un error (${estado}). Revise la consola de Django.`;
  }
  const error = new ErrorApi(mensaje, estado, campos);
  error.db = cuerpo?.db || "";
  return error;
}

/**
 * Llama a /api/<ruta>.
 *   api("catalogos/roles/")
 *   api("usuarios/", { query: { activo: true } })
 *   api("usuarios/5/", { metodo: "PUT", datos: {...} })
 */
export async function api(ruta, { metodo = "GET", datos, query, formulario, comoArchivo = false } = {}) {
  let url = `${CONFIG.API_BASE}/api/${ruta.replace(/^\/+/, "")}`;

  if (query) {
    const params = new URLSearchParams();
    for (const [k, v] of Object.entries(query)) {
      if (v !== null && v !== undefined && v !== "") params.append(k, v);
    }
    const qs = params.toString();
    if (qs) url += `?${qs}`;
  }

  const headers = { Accept: comoArchivo ? "*/*" : "application/json" };
  const actual = sesion.leer();
  const esLogin = ruta.startsWith("usuarios/login");
  if (actual?.token && !esLogin) headers.Authorization = `Bearer ${actual.token}`;
  if (datos !== undefined) headers["Content-Type"] = "application/json";
  // Con FormData (subida de archivos) el navegador pone el Content-Type solo.
  const cuerpoPeticion = formulario ?? (datos !== undefined ? JSON.stringify(datos) : undefined);

  let respuesta;
  try {
    respuesta = await fetch(url, { method: metodo, headers, body: cuerpoPeticion });
  } catch {
    throw new ErrorApi("No hay conexión con el servidor. Verifique que Django esté corriendo.", 0);
  }

  if (respuesta.status === 204) return null;
  if (comoArchivo && respuesta.ok) return respuesta.blob();

  let cuerpo = null;
  const texto = await respuesta.text();
  if (texto) {
    try { cuerpo = JSON.parse(texto); } catch { cuerpo = null; }
  }

  if (!respuesta.ok) {
    if (respuesta.status === 413) throw new ErrorApi("El archivo es demasiado grande para el servidor.", 413);
    const error = interpretarError(cuerpo, respuesta.status);
    if (respuesta.status === 401 && !esLogin) alExpirarSesion(error.message);
    throw error;
  }
  return cuerpo;
}

/**
 * Sube un archivo (FormData) mostrando el avance, para archivos grandes
 * como el firmware de un dispositivo.
 *   apiSubir("dispositivos/5/documentos/", datos, { alProgreso: (0..1) => ... })
 */
export function apiSubir(ruta, formulario, { metodo = "POST", alProgreso } = {}) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open(metodo, `${CONFIG.API_BASE}/api/${ruta.replace(/^\/+/, "")}`);
    xhr.setRequestHeader("Accept", "application/json");
    const actual = sesion.leer();
    if (actual?.token) xhr.setRequestHeader("Authorization", `Bearer ${actual.token}`);
    if (alProgreso) {
      xhr.upload.addEventListener("progress", (ev) => { if (ev.lengthComputable) alProgreso(ev.loaded / ev.total); });
    }
    xhr.addEventListener("error", () => reject(new ErrorApi("No hay conexión con el servidor. Verifique que Django esté corriendo.", 0)));
    xhr.addEventListener("load", () => {
      let cuerpo = null;
      try { cuerpo = xhr.responseText ? JSON.parse(xhr.responseText) : null; } catch { cuerpo = null; }
      if (xhr.status >= 200 && xhr.status < 300) { resolve(cuerpo); return; }
      if (xhr.status === 413) { reject(new ErrorApi("El archivo es demasiado grande para el servidor.", 413)); return; }
      const error = interpretarError(cuerpo, xhr.status);
      if (xhr.status === 401) alExpirarSesion(error.message);
      reject(error);
    });
    xhr.send(formulario);
  });
}

/** Arma una ruta escapando cada segmento: ruta("geografia/provincias", "CR", "2") */
export function ruta(base, ...partes) {
  return [base.replace(/\/+$/, ""), ...partes.map((p) => encodeURIComponent(p))].join("/") + "/";
}
