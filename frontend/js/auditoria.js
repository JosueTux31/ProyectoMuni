// Auditoría: feed de actividad con la foto de quién hizo cada cambio,
// la página de consulta con filtros y las pestañas "Actividad" / "Historial".
import { api } from "./api.js";
import {
  avatarHTML, cargandoHTML, errorHTML, esc, icono, tiempoRelativo, vacioHTML,
} from "./ui.js";
import { CATALOGOS, filasCatalogo } from "./datos.js";

/* ------------------------------------------------------------ Vocabulario */
const TABLAS = {
  usr_usuarios: { art: "el", nom: "usuario", grupo: "Personas", filtro: "Usuarios y proveedores" },
  usr_telefonos: { art: "el", nom: "teléfono", grupo: "Personas", filtro: "Teléfonos", detalle: true },
  usr_correos: { art: "el", nom: "correo", grupo: "Personas", filtro: "Correos", detalle: true },
  usr_paginas_webs: { art: "la", nom: "página web", grupo: "Personas", filtro: "Páginas web", detalle: true },
  usr_historiales_claves: { art: "la", nom: "clave", grupo: "Personas", filtro: "Cambios de clave", detalle: true },
  cat_roles_usuarios: { art: "el", nom: "rol", grupo: "Catálogos", filtro: "Roles" },
  cat_departamentos: { art: "el", nom: "departamento", grupo: "Catálogos", filtro: "Departamentos" },
  cat_tipos_identificaciones: { art: "el", nom: "tipo de identificación", grupo: "Catálogos", filtro: "Tipos de identificación" },
  cat_tipos_autenticaciones: { art: "la", nom: "forma de inicio de sesión", grupo: "Catálogos", filtro: "Formas de inicio de sesión" },
  cat_tipos_telefonos: { art: "el", nom: "tipo de teléfono", grupo: "Catálogos", filtro: "Tipos de teléfono" },
  cat_tipos_correos: { art: "el", nom: "tipo de correo", grupo: "Catálogos", filtro: "Tipos de correo" },
  cat_categorias_proveedores: { art: "la", nom: "categoría de proveedor", grupo: "Catálogos", filtro: "Categorías de proveedores" },
  geo_paises: { art: "el", nom: "país", grupo: "Territorio", filtro: "Países" },
  geo_provincias: { art: "la", nom: "provincia", grupo: "Territorio", filtro: "Provincias" },
  geo_cantones: { art: "el", nom: "cantón", grupo: "Territorio", filtro: "Cantones" },
  geo_distritos: { art: "el", nom: "distrito", grupo: "Territorio", filtro: "Distritos" },
  red_dispositivos: { art: "el", nom: "dispositivo", grupo: "Dispositivos de red", filtro: "Dispositivos" },
  equipos: { art: "la", nom: "dirección IP", grupo: "Dispositivos de red", filtro: "Direcciones IP" },
  // Nombre anterior de la tabla equipos: solo para mostrar la auditoría vieja
  red_ips_dispositivos: { art: "la", nom: "dirección IP", grupo: "Dispositivos de red", filtro: "Direcciones IP", anterior: true },
  red_macs_dispositivos: { art: "la", nom: "dirección MAC", grupo: "Dispositivos de red", filtro: "Direcciones MAC" },
  red_documentos_dispositivos: { art: "el", nom: "documento", grupo: "Dispositivos de red", filtro: "Documentos de dispositivos" },
  cat_edificios: { art: "el", nom: "edificio", grupo: "Dispositivos de red", filtro: "Edificios" },
  cat_marcas: { art: "la", nom: "marca", grupo: "Dispositivos de red", filtro: "Marcas" },
  cat_modelos: { art: "el", nom: "modelo", grupo: "Dispositivos de red", filtro: "Modelos" },
  cat_tipos_dispositivos: { art: "el", nom: "tipo de dispositivo", grupo: "Dispositivos de red", filtro: "Tipos de dispositivo" },
  cat_sistemas_operativos: { art: "el", nom: "sistema operativo", grupo: "Dispositivos de red", filtro: "Sistemas operativos" },
  cat_tipos_documentos: { art: "el", nom: "tipo de documento", grupo: "Dispositivos de red", filtro: "Tipos de documento" },
  log_importaciones: { art: "la", nom: "importación de logs", grupo: "Análisis de logs", filtro: "Importaciones de logs" },
  log_mapeo_campos: { art: "el", nom: "alias de campo", grupo: "Análisis de logs", filtro: "Alias de campos de logs" },
  cor_configuracion: { art: "la", nom: "cuenta de correo institucional", grupo: "Correo institucional", filtro: "Cuenta de correo" },
  cor_envios: { art: "el", nom: "aviso", grupo: "Correo institucional", filtro: "Avisos al personal" },
  cor_listas: { art: "la", nom: "lista de correos", grupo: "Correo institucional", filtro: "Listas de correos" },
};

const ACCIONES = {
  INSERTAR: "Creaciones",
  ACTUALIZAR: "Modificaciones",
  ELIMINAR: "Eliminaciones",
  INICIO_SESION: "Inicios de sesión",
  CIERRE_SESION: "Cierres de sesión",
  INICIO_FALLIDO: "Intentos fallidos de inicio de sesión",
};

const ETIQUETAS = {
  es_proveedor: "Es proveedor", cod_categoria: "Categoría", cod_rol: "Rol", cod_tipo_auth: "Forma de inicio de sesión",
  cod_tipo_identificacion: "Tipo de identificación", dni: "Identificación", nombre: "Nombre",
  apellido1: "Primer apellido", apellido2: "Segundo apellido", cod_pais: "País", cod_provincia: "Provincia",
  cod_canton: "Cantón", cod_distrito: "Distrito", codigo_postal: "Código postal", otras_senas: "Otras señas",
  mapa: "Ubicación en el mapa", imagen_path: "Foto o imagen", archivo_path: "Catálogo de servicios",
  cod_departamento: "Departamento", usuario_red: "Usuario de red", activo: "Activo",
  cod_telefono: "Tipo de teléfono", telefono: "Teléfono", es_whatsapp: "WhatsApp", cod_correo: "Tipo de correo",
  correo: "Correo", url_web: "Página web", num_linea: "Línea", id_usuario: "Persona", fecha_registro: "Fecha",
  descripcion: "Descripción", nombre_pais: "Nombre", nombre_provincia: "Nombre", nombre_canton: "Nombre",
  nombre_distrito: "Nombre", motivo: "Motivo",
  serie: "Serie", tipo_disp: "Tipo de dispositivo", id_marca: "Marca", id_modelo: "Modelo",
  cant_ptos_ethernet: "Puertos Ethernet", cant_ptos_sfp: "Puertos SFP", id_os: "Sistema operativo",
  gps: "Coordenadas", id_predio: "Edificio", id_edificio: "Edificio", ubicacion: "Ubicación en el edificio",
  id_proveedor: "Proveedor", direccion_ip: "Dirección IP", direccion_mac: "Dirección MAC", interfaz: "Interfaz",
  id_doc: "Tipo de documento", path_docs: "Archivo",
  fuente: "Programa", nombre_archivo: "Archivo", total_eventos: "Eventos", id_importacion: "Importación",
  campo_origen: "Nombre en el log", campo: "Campo común", prioridad: "Prioridad",
  servidor: "Servidor", puerto: "Puerto", seguridad: "Seguridad", usuario: "Usuario de la cuenta", clave: "Clave",
  correo_remitente: "Correo del remitente", nombre_remitente: "Nombre del remitente", responder_a: "Respuestas a",
  firma: "Firma", limite_diario: "Límite diario", asunto: "Asunto", destinatarios: "Para", estado: "Estado",
  total: "Destinatarios", enviados: "Enviados", errores: "Errores", dominio: "Dominio",
};

// Campo → catálogo para mostrar la descripción en lugar del código
const CAMPO_CATALOGO = {
  cod_rol: "roles", cod_departamento: "departamentos", cod_tipo_identificacion: "tipos-identificaciones",
  cod_tipo_auth: "tipos-autenticaciones", cod_categoria: "categorias-proveedores",
  cod_telefono: "tipos-telefonos", cod_correo: "tipos-correos",
  tipo_disp: "tipos-dispositivos", id_marca: "marcas", id_os: "sistemas-operativos", id_doc: "tipos-documentos",
  id_predio: "edificios", id_edificio: "edificios",
};
const BOOLEANOS = new Set(["activo", "es_whatsapp", "es_proveedor"]);
const OCULTOS = new Set(["id", "id_usuario", "num_linea", "id_disp"]);

/** AABBCCDDEEFF (o AA:BB:...) -> AA-BB-CC-DD-EE-FF */
const macConGuiones = (m) => {
  const h = String(m ?? "").replace(/[^0-9a-f]/gi, "").toUpperCase();
  return h.length === 12 ? h.match(/../g).join("-") : String(m ?? "");
};

/** dispositivos/5/manual-1a2b3c4d.pdf -> manual.pdf */
const nombreDocumento = (r) => String(r || "").split("/").pop().replace(/-[0-9a-f]{8}(?=\.[^.]+$|$)/, "");

let catalogos = null;
async function cargarCatalogos() {
  if (catalogos) return catalogos;
  const pares = await Promise.all(Object.entries(CAMPO_CATALOGO).map(async ([campo, slug]) => {
    try {
      const filas = await filasCatalogo(slug);
      return [campo, new Map(filas.map((f) => [String(f[CATALOGOS[slug].llave]), f.descripcion]))];
    } catch {
      return [campo, new Map()];
    }
  }));
  catalogos = Object.fromEntries(pares);
  return catalogos;
}

function valorLegible(campo, valor) {
  if (valor === null || valor === undefined || valor === "") return `<span class="secundario">vacío</span>`;
  if (BOOLEANOS.has(campo)) return Number(valor) ? "Sí" : "No";
  if (catalogos?.[campo]?.has(String(valor))) return esc(catalogos[campo].get(String(valor)));
  if (campo === "imagen_path" || campo === "archivo_path") return esc(String(valor).split("/").pop());
  if (campo === "path_docs") return esc(nombreDocumento(valor));
  if (campo === "direccion_mac") return esc(macConGuiones(valor));
  if (campo === "clave") return "guardada (cifrada)";
  return esc(valor);
}

/* --------------------------------------------------------------- Frases */
const enlacePersona = (p) => {
  if (!p?.id) return "";
  const nombre = esc(p.nombre || `#${p.id}`);
  if (!p.nombre) return `<strong>${nombre}</strong>`;
  return `<a href="#/${p.es_proveedor ? "proveedores" : "usuarios"}/${p.id}">${nombre}</a>`;
};

function camposCambiados(e) {
  if (!e.antes || !e.despues) return [];
  return Object.keys({ ...e.antes, ...e.despues })
    .filter((k) => JSON.stringify(e.antes[k] ?? null) !== JSON.stringify(e.despues[k] ?? null));
}

/** Frase en lenguaje natural, sin el nombre de quien lo hizo. */
function frase(e) {
  const t = TABLAS[e.tabla] || { art: "el", nom: "registro" };
  const desc = e.descripcion ? `<strong>${esc(e.descripcion)}</strong>` : "";
  const propio = e.actor?.id && e.persona?.id && e.actor.id === e.persona.id;
  const persona = enlacePersona(e.persona);

  switch (e.accion) {
    case "INICIO_SESION": return "inició sesión";
    case "CIERRE_SESION": return "cerró sesión";
    case "INICIO_FALLIDO": {
      const motivo = e.despues?.motivo ? ` (${esc(e.despues.motivo.toLowerCase())})` : "";
      return `Intento fallido de inicio de sesión con el usuario <strong>${esc(e.llave || "")}</strong>${motivo}`;
    }
    default: break;
  }

  if (e.tabla === "usr_historiales_claves") {
    if (e.accion === "INSERTAR") return propio ? "cambió su clave" : `cambió la clave de ${persona}`;
    return `${e.accion === "ELIMINAR" ? "eliminó" : "modificó"} un registro del historial de claves de ${persona}`;
  }

  if (e.tabla === "usr_usuarios") {
    const esProveedor = Number((e.despues || e.antes)?.es_proveedor) === 1;
    const quien = esProveedor ? "el proveedor" : "el usuario";
    const destino = e.accion === "ELIMINAR" ? desc : (persona || desc);
    if (e.accion === "INSERTAR") return `registró ${quien} ${destino}`;
    if (e.accion === "ELIMINAR") return `eliminó definitivamente ${quien} ${destino}`;
    const cambios = camposCambiados(e);
    if (cambios.length === 1 && cambios[0] === "activo") {
      return `${Number(e.despues.activo) ? "activó" : "desactivó"} ${quien} ${destino}`;
    }
    if (cambios.length === 1 && cambios[0] === "imagen_path") {
      const que = esProveedor ? "la imagen" : "la foto";
      if (propio) return e.despues.imagen_path ? "cambió su foto de perfil" : "quitó su foto de perfil";
      return `${e.despues.imagen_path ? "cambió" : "quitó"} ${que} de ${destino}`;
    }
    if (cambios.length === 1 && cambios[0] === "archivo_path") {
      return `${e.despues.archivo_path ? "subió" : "quitó"} el catálogo de servicios de ${destino}`;
    }
    if (cambios.every((c) => c === "codigo_postal")) return `actualizó el código postal de ${destino}`;
    return propio ? "modificó sus datos" : `modificó ${quien} ${destino}`;
  }

  if (e.tabla === "red_dispositivos") {
    const disp = e.accion === "ELIMINAR" ? desc
      : `<a href="#/red/dispositivos/${esc(e.llave)}">${esc(e.descripcion || `N.º ${e.llave}`)}</a>`;
    if (e.accion === "INSERTAR") return `registró el dispositivo ${disp}`;
    if (e.accion === "ELIMINAR") return `eliminó definitivamente el dispositivo ${disp}`;
    const cambios = camposCambiados(e);
    if (cambios.length === 1 && cambios[0] === "activo") return `${Number(e.despues.activo) ? "activó" : "desactivó"} el dispositivo ${disp}`;
    return `modificó el dispositivo ${disp}`;
  }

  if (e.tabla === "red_documentos_dispositivos") {
    const idDisp = String(e.llave || "").split("/")[0];
    const doc = `<strong>${esc(nombreDocumento(e.descripcion))}</strong>`;
    const del = idDisp ? ` del <a href="#/red/dispositivos/${esc(idDisp)}/documentos">dispositivo N.º ${esc(idDisp)}</a>` : "";
    if (e.accion === "INSERTAR") return `subió el documento ${doc}${del}`;
    if (e.accion === "ELIMINAR") return `eliminó el documento ${doc}${del}`;
    return camposCambiados(e).includes("path_docs")
      ? `reemplazó el archivo ${doc}${del}` : `cambió el tipo del documento ${doc}${del}`;
  }

  if (e.tabla === "log_importaciones") {
    const d = e.despues || e.antes || {};
    const archivo = `<strong>${esc(d.nombre_archivo || e.descripcion || "")}</strong>`;
    const n = Number(d.total_eventos) || 0;
    const enlace = `(<a href="#/logs/importaciones/${esc(e.llave)}">importación N.º ${esc(e.llave)}</a>)`;
    if (d.fuente === "MICROCLAUDIA") {
      if (e.accion === "INSERTAR") return `importó el listado de equipos de Microclaudia ${archivo} ${enlace}`;
      if (e.accion === "ELIMINAR") return `eliminó el listado de equipos de Microclaudia ${archivo}${n ? ` con sus ${n.toLocaleString("es-CR")} equipos` : ""}`;
      return `modificó el listado de equipos de Microclaudia ${archivo}`;
    }
    if (d.fuente === "DHCP") {
      if (e.accion === "INSERTAR") return `importó las concesiones del DHCP ${archivo} ${enlace}`;
      if (e.accion === "ELIMINAR") return `eliminó la lista del DHCP ${archivo}${n ? ` con sus ${n.toLocaleString("es-CR")} concesiones` : ""}`;
      return `modificó la lista del DHCP ${archivo}`;
    }
    const fuente = d.fuente === "SOPHOS" ? " de Sophos" : "";
    if (e.accion === "INSERTAR") return `importó el archivo de logs${fuente} ${archivo} ${enlace}`;
    if (e.accion === "ELIMINAR") return `eliminó la importación de logs${fuente} ${archivo}${n ? ` con sus ${n.toLocaleString("es-CR")} eventos` : ""}`;
    return `modificó la importación de logs ${archivo}`;
  }

  if (e.tabla === "cor_configuracion") {
    if (e.accion === "INSERTAR") return `configuró la cuenta de correo institucional ${desc}`;
    const cambios = camposCambiados(e);
    if (cambios.length === 1 && cambios[0] === "clave") return `cambió la clave de la cuenta de correo institucional ${desc}`;
    if (cambios.length === 1 && cambios[0] === "activo") return `${Number(e.despues?.activo) ? "reanudó" : "pausó"} el envío de avisos`;
    return `modificó la cuenta de correo institucional ${desc}`;
  }

  if (e.tabla === "cor_envios") {
    const d = e.despues || e.antes || {};
    const enlace = `(<a href="#/correo/avisos/${esc(e.llave)}">aviso N.º ${esc(e.llave)}</a>)`;
    const para = d.destinatarios ? ` para ${esc(String(d.destinatarios).toLowerCase())}` : "";
    if (e.accion === "INSERTAR") return `escribió el aviso ${desc}${para} ${enlace}`;
    if (e.accion === "ELIMINAR") return `eliminó el aviso ${desc}, que no se había enviado`;
    const n = (k) => Number(d[k] || 0).toLocaleString("es-CR");
    switch (d.estado) {
      case "ENVIANDO": return `empezó a enviar el aviso ${desc} ${enlace}`;
      case "ENVIADO": return `terminó de enviar el aviso ${desc} a ${n("enviados")} ${Number(d.enviados) === 1 ? "persona" : "personas"} ${enlace}`;
      case "CON_ERRORES": return `envió el aviso ${desc} a ${n("enviados")} de ${n("total")}; ${n("errores")} no se pudieron enviar ${enlace}`;
      case "CANCELADO": return `detuvo el envío del aviso ${desc} (${n("enviados")} de ${n("total")} enviados) ${enlace}`;
      default: return `modificó el aviso ${desc} ${enlace}`;
    }
  }

  if (e.tabla === "cor_listas") {
    const d = e.despues || e.antes || {};
    const n = Number(d.total) || 0;
    const enlace = `(<a href="#/correo/comparar/${esc(e.llave)}">lista N.º ${esc(e.llave)}</a>)`;
    if (e.accion === "INSERTAR") return `importó la lista de correos ${desc}${n ? ` con ${n.toLocaleString("es-CR")} correos` : ""} ${enlace}`;
    if (e.accion === "ELIMINAR") return `eliminó la lista de correos ${desc}`;
    return `cambió la descripción de la lista de correos ${desc} ${enlace}`;
  }

  if (e.tabla === "log_mapeo_campos") {
    const d = e.despues || e.antes || {};
    const origen = `<strong class="dato-mono">${esc(d.campo_origen || "")}</strong>`;
    const campo = `<strong>${esc(d.campo || "")}</strong>`;
    const de = { MICROCLAUDIA: "del listado de Microclaudia", SOPHOS: "de los logs de Sophos", DHCP: "de la lista del DHCP" }[d.fuente] || "de los logs";
    if (e.accion === "INSERTAR") return `hizo que el campo ${origen} ${de} se lea como ${campo}`;
    if (e.accion === "ELIMINAR") return `quitó el alias ${origen} → ${campo} ${de}`;
    return `cambió el alias ${origen} ${de} (ahora se lee como ${campo})`;
  }

  if (e.tabla === "equipos" || e.tabla === "red_ips_dispositivos" || e.tabla === "red_macs_dispositivos") {
    const idDisp = String(e.llave || "").split("/")[0];
    const esMac = e.tabla === "red_macs_dispositivos";
    const valor = `<strong class="dato-mono">${esc(esMac ? macConGuiones(e.descripcion) : e.descripcion)}</strong>`;
    const enlace = idDisp ? `<a href="#/red/dispositivos/${esc(idDisp)}">dispositivo N.º ${esc(idDisp)}</a>` : "dispositivo";
    const que = `la dirección ${esMac ? "MAC" : "IP"} ${valor}`;
    if (e.accion === "INSERTAR") return `agregó ${que} al ${enlace}`;
    if (e.accion === "ELIMINAR") return `eliminó ${que} del ${enlace}`;
    return `modificó ${que} del ${enlace}`;
  }

  const verbo = { INSERTAR: t.detalle ? "agregó" : "creó", ACTUALIZAR: "modificó", ELIMINAR: "eliminó" }[e.accion] || "cambió";
  const de = t.detalle && persona ? ` ${propio ? "a su cuenta" : `de ${persona}`}` : "";
  return `${verbo} ${t.art} ${t.nom} ${desc}${de}`;
}

function detalleHTML(e) {
  let filas = [];
  if (e.accion === "ACTUALIZAR") {
    filas = camposCambiados(e).map((k) => [k, e.antes[k], e.despues[k], true]);
  } else {
    const datos = e.despues || e.antes || {};
    filas = Object.entries(datos).filter(([k, v]) => !OCULTOS.has(k) && v !== null && v !== "").map(([k, v]) => [k, v]);
  }
  if (!filas.length) return "";
  const conAntes = e.accion === "ACTUALIZAR";
  return `<div class="cambios"><table class="tabla tabla--compacta">
    <thead><tr><th>Campo</th>${conAntes ? "<th>Antes</th><th>Después</th>" : "<th>Valor</th>"}</tr></thead>
    <tbody>${filas.map(([k, a, d]) => `<tr><td>${esc(ETIQUETAS[k] || k)}</td>${conAntes
      ? `<td class="cambios__antes">${valorLegible(k, a)}</td><td class="cambios__despues">${valorLegible(k, d)}</td>`
      : `<td>${valorLegible(k, a)}</td>`}</tr>`).join("")}</tbody></table></div>`;
}

const ICONO_ACCION = {
  INSERTAR: "mas", ACTUALIZAR: "editar", ELIMINAR: "borrar",
  INICIO_SESION: "entrar", CIERRE_SESION: "salir", INICIO_FALLIDO: "alerta",
};

const fechaLarga = new Intl.DateTimeFormat("es-CR", { dateStyle: "full", timeStyle: "medium" });

function itemHTML(e) {
  const actor = e.actor;
  const avatar = actor
    ? avatarHTML(actor)
    : `<span class="avatar avatar--sistema" aria-hidden="true">${icono(e.accion === "INICIO_FALLIDO" ? "alerta" : "escudo")}</span>`;
  const nombreActor = actor
    ? (actor.id ? `<a class="evento__actor" href="#/usuarios/${actor.id}">${esc(actor.nombre || "Usuario")}</a>` : `<strong>${esc(actor.nombre)}</strong>`)
    : (e.accion === "INICIO_FALLIDO" ? "" : `<strong>Sistema</strong>`);
  const detalle = ["INSERTAR", "ACTUALIZAR", "ELIMINAR", "INICIO_FALLIDO"].includes(e.accion) ? detalleHTML(e) : "";
  const fecha = new Date(e.fecha);
  return `
    <li class="evento evento--${e.accion.toLowerCase()}">
      <div class="evento__avatar">${avatar}<span class="evento__insignia" aria-hidden="true">${icono(ICONO_ACCION[e.accion] || "editar")}</span></div>
      <div class="evento__cuerpo">
        <p class="evento__frase">${nombreActor} ${frase(e)}</p>
        <p class="evento__meta">
          <time datetime="${esc(e.fecha)}" title="${esc(Number.isNaN(fecha.getTime()) ? "" : fechaLarga.format(fecha))}">${esc(tiempoRelativo(e.fecha))}</time>
          ${e.ip ? `<span>IP ${esc(e.ip)}</span>` : ""}
          ${detalle ? `<button type="button" class="evento__ver" aria-expanded="false">Ver detalle</button>` : ""}
        </p>
        ${detalle ? `<div class="evento__detalle" hidden>${detalle}</div>` : ""}
      </div>
    </li>`;
}

const diaFmt = new Intl.DateTimeFormat("es-CR", { weekday: "long", day: "numeric", month: "long", year: "numeric" });
function etiquetaDia(fecha) {
  const d = new Date(fecha);
  const hoy = new Date();
  const ayer = new Date(Date.now() - 86400000);
  const mismo = (a, b) => a.toDateString() === b.toDateString();
  if (mismo(d, hoy)) return "Hoy";
  if (mismo(d, ayer)) return "Ayer";
  const t = diaFmt.format(d);
  return t.charAt(0).toUpperCase() + t.slice(1);
}

/**
 * Dibuja un feed de auditoría en `cont` con los filtros dados.
 * `ruta`: API que responde {resultados, hay_mas} (por defecto auditoria/;
 * el historial de un dispositivo usa dispositivos/<id>/historial/).
 * Devuelve { recargar(filtros) }.
 */
export async function feedAuditoria(cont, filtros = {}, {
  limite = 30, vacio = "Todavía no hay actividad registrada.", paginar = true, ruta = "auditoria/",
} = {}) {
  await cargarCatalogos();
  let actuales = { ...filtros };
  let desplazamiento = 0;
  let ultimoDia = null;
  let consulta = 0;

  cont.innerHTML = `<ol class="feed" data-feed></ol><div data-estado>${cargandoHTML()}</div>`;
  const lista = cont.querySelector("[data-feed]");
  const estado = cont.querySelector("[data-estado]");

  async function cargar(reiniciar) {
    const esta = ++consulta;
    if (reiniciar) {
      desplazamiento = 0;
      ultimoDia = null;
      lista.innerHTML = "";
      estado.innerHTML = cargandoHTML();
    } else {
      estado.innerHTML = cargandoHTML("Cargando más…");
    }
    let r;
    try {
      r = await api(ruta, { query: { ...actuales, limite, desplazamiento } });
    } catch (e) {
      if (esta === consulta) estado.innerHTML = errorHTML(e.message);
      return;
    }
    if (esta !== consulta) return;

    let html = "";
    for (const ev of r.resultados) {
      const dia = etiquetaDia(ev.fecha);
      if (dia !== ultimoDia) {
        html += `<li class="feed__dia"><span>${esc(dia)}</span></li>`;
        ultimoDia = dia;
      }
      html += itemHTML(ev);
    }
    lista.insertAdjacentHTML("beforeend", html);
    desplazamiento += r.resultados.length;

    if (!desplazamiento) estado.innerHTML = vacioHTML({ icono: "historial", titulo: vacio });
    else if (r.hay_mas && paginar) estado.innerHTML = `<div class="feed__mas"><button type="button" class="btn btn--secundario" data-mas>Cargar más actividad</button></div>`;
    else estado.innerHTML = "";
  }

  cont.addEventListener("click", (ev) => {
    if (ev.target.closest("[data-mas]")) { cargar(false); return; }
    const ver = ev.target.closest(".evento__ver");
    if (ver) {
      const detalle = ver.closest(".evento__cuerpo").querySelector(".evento__detalle");
      const abrir = detalle.hidden;
      detalle.hidden = !abrir;
      ver.setAttribute("aria-expanded", String(abrir));
      ver.textContent = abrir ? "Ocultar detalle" : "Ver detalle";
    }
  });

  await cargar(true);
  return {
    recargar(nuevos) {
      actuales = { ...nuevos };
      return cargar(true);
    },
  };
}

/* =====================================================================
   Página de auditoría (solo administradores)
   ===================================================================== */
export async function vistaAuditoria(cont, _params, ctx) {
  ctx.migas([{ texto: "Auditoría" }]);
  const grupos = {};
  for (const [tabla, t] of Object.entries(TABLAS)) if (!t.anterior) (grupos[t.grupo] ||= []).push([tabla, t.filtro]);

  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Auditoría</h1>
        <p>Todo lo que se crea, cambia o elimina en el sistema, quién lo hizo, cuándo y desde qué equipo. Los registros no se pueden modificar.</p>
      </div>
    </div>
    <section class="panel">
      <form class="filtros" role="search" id="filtros-auditoria">
        <div class="campo campo--buscar">
          <label for="a-buscar">Buscar</label>
          <div class="buscador">${icono("buscar")}<input id="a-buscar" name="buscar" type="search" placeholder="Nombre del registro o de quien lo hizo" autocomplete="off"></div>
        </div>
        <div class="campo"><label for="a-usuario">Hecho por</label><select id="a-usuario" name="id_usuario"><option value="">Cualquier persona</option></select></div>
        <div class="campo"><label for="a-tabla">Qué se cambió</label><select id="a-tabla" name="tabla"><option value="">Todo</option>
          ${Object.entries(grupos).map(([g, ops]) => `<optgroup label="${esc(g)}">${ops.map(([v, t]) => `<option value="${v}">${esc(t)}</option>`).join("")}</optgroup>`).join("")}
        </select></div>
        <div class="campo"><label for="a-accion">Acción</label><select id="a-accion" name="accion"><option value="">Todas</option>
          ${Object.entries(ACCIONES).map(([v, t]) => `<option value="${v}">${esc(t)}</option>`).join("")}
        </select></div>
        <div class="campo campo--fecha"><label for="a-desde">Desde</label><input id="a-desde" name="desde" type="date" class="control"></div>
        <div class="campo campo--fecha"><label for="a-hasta">Hasta</label><input id="a-hasta" name="hasta" type="date" class="control"></div>
      </form>
      <div class="panel__cuerpo" data-feed-auditoria></div>
    </section>`;

  const form = cont.querySelector("#filtros-auditoria");
  try {
    const usuarios = await api("usuarios/");
    if (!ctx.vigente()) return;
    form.id_usuario.insertAdjacentHTML("beforeend", usuarios
      .map((u) => `<option value="${u.id}">${esc([u.nombre, u.apellido1, u.apellido2].filter(Boolean).join(" "))}</option>`).join(""));
  } catch { /* el filtro queda solo con "Cualquier persona" */ }

  const leer = () => Object.fromEntries([...new FormData(form)].filter(([, v]) => v !== ""));
  const feed = await feedAuditoria(cont.querySelector("[data-feed-auditoria]"), leer(), {
    vacio: "No hay actividad con estos filtros.",
  });
  let espera;
  form.addEventListener("input", (ev) => {
    clearTimeout(espera);
    espera = setTimeout(() => feed.recargar(leer()), ev.target.name === "buscar" ? 350 : 0);
  });
  form.addEventListener("submit", (ev) => { ev.preventDefault(); feed.recargar(leer()); });
}

/* =====================================================================
   Pestañas de actividad en las fichas
   ===================================================================== */

/** Ficha de usuario: lo que hizo esta persona y lo que le cambiaron. */
export async function pestanaActividadUsuario(panel, u, ctx, propio) {
  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza">
        <div><h2>${propio ? "Mi actividad" : "Actividad"}</h2><p>Registro de auditoría${propio ? " de su cuenta" : ""}.</p></div>
        <div class="segmentado" role="radiogroup" aria-label="Qué actividad mostrar">
          <button type="button" role="radio" aria-checked="true" data-modo="id_usuario">${propio ? "Lo que hice" : "Lo que hizo"}</button>
          <button type="button" role="radio" aria-checked="false" data-modo="id_persona">${propio ? "Cambios a mi cuenta" : "Cambios a su cuenta"}</button>
        </div>
      </div>
      <div class="panel__cuerpo" data-feed-actividad></div>
    </section>`;
  const feed = await feedAuditoria(panel.querySelector("[data-feed-actividad]"), { id_usuario: u.id }, { limite: 20 });
  panel.querySelector(".segmentado").addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-modo]");
    if (!b || b.getAttribute("aria-checked") === "true") return;
    panel.querySelectorAll("[data-modo]").forEach((x) => x.setAttribute("aria-checked", String(x === b)));
    feed.recargar({ [b.dataset.modo]: u.id });
  });
}

/** Ficha de proveedor: todos los cambios a sus datos, contactos y documentos. */
export async function pestanaHistorialProveedor(panel, p) {
  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza"><div><h2>Historial</h2><p>Quién registró y modificó este proveedor, y cuándo.</p></div></div>
      <div class="panel__cuerpo" data-feed-historial></div>
    </section>`;
  await feedAuditoria(panel.querySelector("[data-feed-historial]"), { id_persona: p.id }, {
    limite: 20, vacio: "No hay cambios registrados para este proveedor.",
  });
}
