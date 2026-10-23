// Catálogos y división territorial compartidos por varias pantallas.
import { api, ruta } from "./api.js";
import { esc } from "./ui.js";

/* ------------------------------------------------------------ Catálogos */
export const CATALOGOS = {
  roles: {
    titulo: "Roles", singular: "rol", llave: "cod_rol", max: 50, icono: "escudo",
    descripcion: "Definen qué puede hacer cada usuario. El rol Administrador puede modificar todo; los demás solo consultan.",
  },
  departamentos: {
    titulo: "Departamentos", singular: "departamento", llave: "cod_departamento", max: 120, icono: "edificio",
    descripcion: "Dependencias municipales a las que pertenecen los usuarios.",
  },
  "tipos-identificaciones": {
    titulo: "Tipos de identificación", singular: "tipo de identificación", llave: "cod_tipo_identificacion", max: 50, icono: "cedula",
    descripcion: "Cédula física, jurídica, DIMEX, pasaporte y otros documentos aceptados.",
  },
  "tipos-autenticaciones": {
    titulo: "Formas de inicio de sesión", singular: "forma de inicio de sesión", llave: "cod_tipo_auth", max: 80, icono: "llave",
    descripcion: "Cómo se autentica cada usuario: con la clave del sistema o con Active Directory.",
  },
  "tipos-telefonos": {
    titulo: "Tipos de teléfono", singular: "tipo de teléfono", llave: "cod_telefono", max: 50, icono: "telefono",
    descripcion: "Celular, casa, oficina u otros, para clasificar los teléfonos de los usuarios.",
  },
  "tipos-correos": {
    titulo: "Tipos de correo", singular: "tipo de correo", llave: "cod_correo", max: 50, icono: "correo",
    descripcion: "Clasificación de los correos electrónicos de usuarios y proveedores.",
  },
  "categorias-proveedores": {
    titulo: "Categorías de proveedores", singular: "categoría", llave: "cod_categoria", max: 150, icono: "proveedor",
    descripcion: "Tipo de bien o servicio que ofrece cada proveedor. Cada proveedor tiene una categoría.",
  },

  // Módulo de dispositivos de red (api = ruta propia; modulo = dónde se administra)
  "tipos-dispositivos": {
    titulo: "Tipos de dispositivo", singular: "tipo de dispositivo", llave: "tipo_disp", max: 100, icono: "red",
    descripcion: "Modem, firewall, router, switch… Cada marca y cada dispositivo pertenecen a un tipo.",
    api: "dispositivos/tipos", modulo: "red", grupo: "Catálogos de red",
    enUso: "Si tiene marcas o dispositivos, no se podrá eliminar.",
  },
  "sistemas-operativos": {
    titulo: "Sistemas operativos", singular: "sistema operativo", llave: "id_os", max: 100, icono: "sistema",
    descripcion: "Sistema operativo de cada dispositivo. N/D es para los que no aplica o no se conoce.",
    api: "dispositivos/sistemas-operativos", modulo: "red", grupo: "Catálogos de red",
    enUso: "Si algún dispositivo lo usa, no se podrá eliminar.",
  },
  "tipos-documentos": {
    titulo: "Tipos de documento", singular: "tipo de documento", llave: "id_doc", max: 100, icono: "documento",
    descripcion: "Clasificación de los archivos de cada dispositivo: manuales, imágenes, firmware, respaldos y configuración.",
    api: "dispositivos/tipos-documentos", modulo: "red", grupo: "Catálogos de red",
    enUso: "Si algún dispositivo tiene documentos de este tipo, no se podrá eliminar.",
  },
  // Solo para mostrar nombres (tienen su propia pantalla)
  marcas: { titulo: "Marcas", llave: "id_marca", api: "dispositivos/marcas", modulo: "red", soloDatos: true },
  edificios: { titulo: "Edificios", llave: "id_predio", api: "dispositivos/edificios", modulo: "red", soloDatos: true },
};

/** Ruta de la API de un catálogo: catalogos/<slug> o la propia del módulo. */
export const apiCatalogo = (slug) => CATALOGOS[slug]?.api || `catalogos/${slug}`;

const cache = new Map();

/** Filas de un catálogo (con caché durante la sesión). */
export async function filasCatalogo(slug) {
  if (!cache.has(slug)) cache.set(slug, api(`${apiCatalogo(slug)}/`).catch((e) => { cache.delete(slug); throw e; }));
  return cache.get(slug);
}

export function olvidarCatalogo(slug) { cache.delete(slug); }

/** Opciones {valor, texto} para un <select>. */
export async function opcionesCatalogo(slug) {
  const { llave } = CATALOGOS[slug];
  const filas = await filasCatalogo(slug);
  return filas.map((f) => ({ valor: f[llave], texto: f.descripcion }));
}

/* ------------------------------------------------------------ Territorio */
export const NIVELES_GEO = [
  { campo: "cod_pais", nombre: "nombre_pais", slug: "paises", titulo: "País" },
  { campo: "cod_provincia", nombre: "nombre_provincia", slug: "provincias", titulo: "Provincia" },
  { campo: "cod_canton", nombre: "nombre_canton", slug: "cantones", titulo: "Cantón" },
  { campo: "cod_distrito", nombre: "nombre_distrito", slug: "distritos", titulo: "Distrito" },
];

/**
 * Enlaza selects en cascada: país → provincia → cantón → distrito.
 *   selects:  [selectPais, selectProvincia, ...] (de 1 a 4)
 *   valores:  { cod_pais: "CR", ... } para preseleccionar
 *   todos:    true = primera opción "Todos" (para filtros)
 *   bloqueado: true = solo lectura
 *   alCambiar: se llama cuando el usuario cambia cualquier nivel
 *   codigoPostal: <input> donde se escribe solo el código postal del distrito elegido
 * Devuelve una promesa que termina cuando todo quedó cargado.
 */
export function cascadaGeo(selects, { valores = {}, todos = false, bloqueado = false, alCambiar, codigoPostal } = {}) {
  const primera = todos ? "Todos" : "Seleccione…";
  const selDistrito = selects[3];

  function mostrarCodigoPostal() {
    if (!codigoPostal) return;
    const opcion = selDistrito?.selectedOptions[0];
    codigoPostal.value = opcion?.dataset.cp || "";
    codigoPostal.placeholder = selDistrito?.value ? "Sin código postal" : "Se asigna al elegir el distrito";
  }

  async function llenar(i, preseleccion) {
    const sel = selects[i];
    const nivel = NIVELES_GEO[i];
    const query = {};
    for (let k = 0; k < i; k++) {
      if (!selects[k].value) {
        sel.innerHTML = `<option value="">${primera}</option>`;
        sel.disabled = true;
        if (sel === selDistrito) mostrarCodigoPostal();
        return;
      }
      query[NIVELES_GEO[k].campo] = selects[k].value;
    }

    sel.disabled = true;
    sel.innerHTML = `<option value="">Cargando…</option>`;
    let filas = [];
    try {
      filas = await api(`geografia/${nivel.slug}/`, { query });
    } catch {
      sel.innerHTML = `<option value="">No se pudo cargar</option>`;
      return;
    }
    sel.innerHTML = `<option value="">${primera}</option>` + filas
      .map((f) => `<option value="${esc(f[nivel.campo])}"${f.codigo_postal ? ` data-cp="${esc(f.codigo_postal)}"` : ""}>${esc(f[nivel.nombre])}</option>`)
      .join("");
    if (preseleccion && filas.some((f) => f[nivel.campo] === preseleccion)) sel.value = preseleccion;
    else if (filas.length === 1 && i === 0) sel.value = filas[0][nivel.campo]; // un solo país: se elige solo
    sel.disabled = bloqueado;
    if (sel === selDistrito) mostrarCodigoPostal();
  }

  selects.forEach((sel, i) => {
    sel.addEventListener("change", async () => {
      for (let j = i + 1; j < selects.length; j++) await llenar(j, null);
      if (sel === selDistrito) mostrarCodigoPostal();
      alCambiar?.();
    });
  });

  return (async () => {
    for (let i = 0; i < selects.length; i++) await llenar(i, valores[NIVELES_GEO[i].campo]);
    mostrarCodigoPostal();
  })();
}

export const rutaGeo = (slug, ...codigos) => ruta(`geografia/${slug}`, ...codigos);
