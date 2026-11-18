// Módulo de equipos municipales (antes dispositivos de red): inicio del
// módulo, lista, registro, ficha (datos, documentos e historial), marcas y
// modelos, y edificios. Equipos de red, computadoras, servidores, móviles,
// telefonía, impresión, pantallas, UPS, cámaras... en la tabla equipos:
// cada tipo es de una categoría y el formulario pide los datos de esa
// categoría. Todo pasa por las APIs de /api/dispositivos/ (procedimientos
// almacenados).
import { api, apiSubir, ErrorApi, ruta } from "./api.js";
import {
  abrirFormulario, botonCargando, botonesFila, camposHTML, cargandoHTML, confirmar, debounce, errorHTML, esc, eventoFila,
  fecha, icono, leerCampos, limpiarErrores, mostrarErrores, nombreCompleto, tablaHTML, toast, urlApi, vacioHTML,
} from "./ui.js";
import { filasCatalogo, olvidarCatalogo, cascadaGeo, NIVELES_GEO } from "./datos.js";
import { pastillaEstado, todosLosCampos } from "./usuarios.js";
import { coordenadas, embebidoMaps, enlaceMaps, enlazarCampoMapa, validarMapaLocal } from "./proveedores.js";
import { feedAuditoria } from "./auditoria.js";
import { abrirVisor, abrirVistaPrevia } from "./zoom.js";
import { abrirEvento, descargarTexto, fechaLog, marcaArchivo, num, rangoFechas, rutaLogs, textoCsv } from "./logs_ui.js";
import { conexionesHTML, enlazarDisenoSwitch, pestanaPuertos, tienePuertos } from "./switch.js";

const RECURSO = "dispositivos";
const MAX_MB_DOCUMENTO = 1024;   // igual que MUNI_MAX_MB_DOCUMENTO_RED en settings.py
const EXT_BLOQUEADAS = [".html", ".htm", ".xhtml", ".svg", ".js", ".mjs", ".php", ".phtml", ".asp", ".aspx", ".jsp", ".hta"];

/* =====================================================================
   Utilidades
   ===================================================================== */
const normalizar = (s) => String(s ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();

/* Categorías de equipo (códigos fijos de cat_categorias_dispositivos) */
export const CAT = { RED: 1, COMPUTO: 2, SERVIDOR: 3, MOVIL: 4, TELEFONIA: 5, IMPRESION: 6, PANTALLA: 7, ENERGIA: 8, VIDEO: 9, OTRO: 10 };
const ICONO_CATEGORIA = {
  1: "red", 2: "escritorio", 3: "servidor", 4: "celular", 5: "telefono-ip", 6: "impresora", 7: "monitor", 8: "ups", 9: "cctv", 10: "equipo",
};
// Ícono por el nombre del tipo (el primero que coincide); si no, el de su categoría
const ICONOS_TIPO = [
  [/modem/, "modem"], [/firewall/, "firewall"], [/router|enrutador/, "router"], [/switch/, "switch"],
  [/access point|punto de acceso|antena|wi-?fi|inalambric|(^|[^a-z])ap([^a-z]|$)/, "wifi"],
  [/laptop|portatil|notebook/, "laptop"], [/todo en uno|all in one/, "monitor"],
  [/computador|escritorio|desktop|workstation|estacion de trabajo|mini pc|(^|[^a-z])pc([^a-z]|$)|cpu/, "escritorio"],
  [/servidor|server/, "servidor"], [/(^|[^a-z])nas([^a-z]|$)|almacenamiento|storage/, "disco"],
  [/tablet|ipad/, "tablet"], [/celular|smartphone|movil/, "celular"],
  [/central|pbx|planta telef/, "central"], [/telefono/, "telefono-ip"],
  [/impresora|multifuncional|plotter|fotocopiadora/, "impresora"], [/escaner|scanner/, "escaner"],
  [/proyector/, "proyector"], [/televisor|(^|[^a-z])tv([^a-z]|$)|pantalla/, "tv"], [/monitor/, "monitor"],
  [/(^|[^a-z])ups([^a-z]|$)|no ?break|regulador|inversor/, "ups"],
  [/camara|cctv/, "cctv"], [/nvr|dvr|grabador/, "disco"], [/reloj|marcador|biometric/, "reloj"],
];

/** Ícono según el tipo de equipo (o su categoría si el nombre no dice nada). */
export function iconoTipo(descripcion, idCategoria) {
  const n = normalizar(descripcion);
  return ICONOS_TIPO.find(([patron]) => patron.test(n))?.[1] || ICONO_CATEGORIA[idCategoria] || "red";
}

export const insigniaTipo = (d, tam = "") =>
  `<span class="insignia-tipo${tam ? ` insignia-tipo--${tam}` : ""}" aria-hidden="true">${icono(iconoTipo(d.tipo_dispositivo, d.id_categoria))}</span>`;

/** Nombre del equipo: el modelo (ya incluye la marca) o la marca si no tiene modelo. */
export const tituloDispositivo = (d) => d.modelo || d.marca || `Dispositivo ${d.id_disp}`;

/** La marca solo se agrega si el modelo no la trae ya (CISCO ASA ya dice CISCO). */
export const marcaAparte = (d) => (d.modelo && !normalizar(d.modelo).startsWith(normalizar(d.marca)) ? d.marca : "");

const extension = (nombre) => (String(nombre).match(/\.[^.]+$/)?.[0] || "").toLowerCase();

function tamanoLegible(bytes) {
  if (bytes === null || bytes === undefined) return "";
  if (bytes < 1024) return `${bytes} B`;
  const unidades = ["KB", "MB", "GB"];
  let v = bytes / 1024;
  let i = 0;
  while (v >= 1024 && i < unidades.length - 1) { v /= 1024; i += 1; }
  return `${v.toLocaleString("es-CR", { maximumFractionDigits: v < 10 ? 1 : 0 })} ${unidades[i]}`;
}

const opciones = (filas, llave, texto = (f) => f.descripcion) => filas.map((f) => ({ valor: f[llave], texto: texto(f) }));

/** La MAC se guarda entera (AABBCCDDEEFF) y se muestra con guiones: AA-BB-CC-DD-EE-FF. */
export function formatearMac(mac) {
  const hex = String(mac ?? "").replace(/[^0-9a-f]/gi, "").toUpperCase();
  return hex.length === 12 ? hex.match(/../g).join("-") : String(mac ?? "");
}

/** "a, b, c" (como las devuelve la base) -> ["a", "b", "c"] */
const lista = (texto) => String(texto || "").split(",").map((x) => x.trim()).filter(Boolean);

/** Primera dirección y cuántas más hay: "192.168.1.1 +2" */
function resumenDirecciones(texto, formato = (x) => x) {
  const todas = lista(texto);
  if (!todas.length) return "";
  return `${esc(formato(todas[0]))}${todas.length > 1 ? ` <span class="mas-direcciones" title="${esc(todas.map(formato).join(", "))}">+${todas.length - 1}</span>` : ""}`;
}

/* --------------------------------------- Validación de IP y MAC (igual que el servidor) */
const OCTETO = "(25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)";
const IPV4 = new RegExp(`^${OCTETO}(\\.${OCTETO}){3}$`);

export function ipValida(ip) {
  const texto = String(ip || "").trim();
  if (IPV4.test(texto)) return true;
  if (!texto.includes(":") || !/^[0-9a-f:.]+$/i.test(texto)) return false;
  try { new URL(`http://[${texto}]/`); return true; } catch { return false; }
}

export function macValida(mac) {
  const texto = String(mac || "").trim();
  return /^[0-9a-f:.\-\s]+$/i.test(texto) && texto.replace(/[^0-9a-f]/gi, "").length === 12;
}

const MENSAJE_IP = "Escriba una dirección IPv4 (por ejemplo 192.168.1.1) o una IPv6 válida.";
const MENSAJE_MAC = "Escriba la MAC con 12 dígitos hexadecimales, por ejemplo AA-BB-CC-DD-EE-FF.";

const MAX_DIRECCIONES = 50;   // filas de cada lista por equipo (igual que el servidor)
const MENSAJE_LINEA = "Escriba el número de la línea con sus dígitos (por ejemplo 8888-8888).";
const MENSAJE_IMEI = "El IMEI tiene 15 dígitos (en el celular: marque *#06#).";
const INTERFAZ = { campo: "interfaz", etiqueta: "Interfaz", max: 50, placeholder: "WAN, LAN, GESTIÓN…" };

/* Listas de filas del equipo (tablas dir_ips, dir_macs, num_moviles y
   dir_imeis). seccion: las que van en otra sección (no en Direcciones de
   red); cats: categorías que las piden; segundo: el dato que acompaña. */
const DIRECCIONES = {
  ips: {
    titulo: "Direcciones IP", etiqueta: "Dirección IP", singular: "dirección IP", plural: "direcciones IP", corto: "IP",
    la: "la", esta: "Esta", otra: "otra", campo: "direccion_ip", icono: "web", placeholder: "192.168.1.1", max: 45,
    valida: ipValida, mensaje: MENSAJE_IP, segundo: INTERFAZ,
    mostrar: (x) => x, normalizar: (x) => String(x || "").trim().toLowerCase(),
  },
  macs: {
    titulo: "Direcciones MAC", etiqueta: "Dirección MAC", singular: "dirección MAC", plural: "direcciones MAC", corto: "MAC",
    la: "la", esta: "Esta", otra: "otra", campo: "direccion_mac", icono: "puertos", placeholder: "AA-BB-CC-DD-EE-FF", max: 30,
    valida: macValida, mensaje: MENSAJE_MAC, segundo: INTERFAZ, mayus: true,
    mostrar: formatearMac, normalizar: (x) => String(x || "").replace(/[^0-9a-f]/gi, "").toUpperCase(),
  },
  moviles: {
    titulo: "Líneas móviles", etiqueta: "Número de línea", singular: "línea", plural: "líneas", corto: "línea",
    la: "la", esta: "Esta", otra: "otra", campo: "num_movil", icono: "telefono", placeholder: "8888-8888", max: 20,
    valida: (x) => /^\+?[0-9][0-9 -]{3,18}$/.test(String(x || "").trim()), mensaje: MENSAJE_LINEA,
    segundo: { campo: "operador", etiqueta: "Operador", max: 50, placeholder: "KÖLBI, CLARO, LIBERTY…" },
    seccion: "linea", cats: [CAT.MOVIL, CAT.TELEFONIA],
    mostrar: (x) => x, normalizar: (x) => String(x || "").replace(/[^0-9+]/g, ""),
  },
  imeis: {
    titulo: "IMEI", etiqueta: "IMEI", singular: "IMEI", plural: "IMEI", corto: "IMEI",
    la: "el", esta: "Este", otra: "otro", campo: "dir_imei", icono: "telefono", placeholder: "15 dígitos", max: 20,
    valida: (x) => /^[0-9]{15}$/.test(String(x || "").replace(/[\s-]/g, "")), mensaje: MENSAJE_IMEI, segundo: null,
    seccion: "linea", cats: [CAT.MOVIL],
    mostrar: (x) => x, normalizar: (x) => String(x || "").replace(/[\s-]/g, ""),
  },
};

function validarArchivo(archivo) {
  if (EXT_BLOQUEADAS.includes(extension(archivo.name))) {
    return "Por seguridad no se aceptan páginas web ni scripts (.html, .svg, .js, .php…). Si necesita guardarlo, comprímalo en un .zip.";
  }
  if (archivo.size > MAX_MB_DOCUMENTO * 1024 * 1024) return `El archivo pesa más de ${MAX_MB_DOCUMENTO} MB.`;
  return null;
}

/** Los mensajes de la base (SIGNAL) se muestran en el campo que corresponde. */
function precisarError(e) {
  if (Object.keys(e.campos || {}).length) return e;
  const m = e.message || "";
  if (e.estado === 409 && /uk_equipos_placa/.test(e.db)) e.campos = { placa: "Esa placa ya la tiene otro equipo." };
  else if (e.estado === 409 && /uk_dir_imeis_imei/.test(e.db)) e.campos = { dir_imei: "Ese IMEI ya está registrado en otro equipo." };
  else if (/placa/i.test(m)) e.campos = { placa: m };
  else if (/IMEI/.test(m)) e.campos = { dir_imei: m };
  else if (/\bl[ií]nea\b/i.test(m) && !/direcci/i.test(m)) e.campos = { num_movil: m };
  else if (/herramienta/i.test(m)) e.campos = { herramientas: m };
  else if (/\brol\b/i.test(m)) e.campos = { roles: m };
  else if (/estado/i.test(m)) e.campos = { id_estado: m };
  else if (/nombre de equipo/i.test(m)) e.campos = { nombre_equipo: m };
  else if (/asignad/i.test(m)) e.campos = { id_asignado: m };
  else if (/garant/i.test(m)) e.campos = { garantia_hasta: m };
  else if (/departamento/i.test(m)) e.campos = { cod_departamento: m };
  else if (/almacenamiento/i.test(m)) e.campos = { tipo_almacenamiento: m };
  else if (/impresi/i.test(m)) e.campos = { tecnologia_impresion: m };
  else if (/pulgadas/i.test(m)) e.campos = { pulgadas: m };
  else if (e.estado === 409 && /uk_equipos_serie/.test(e.db)) e.campos = { serie: "Ya hay otro dispositivo de esa marca con la misma serie." };
  else if (e.estado === 409 && /uk_dir_macs_mac/.test(e.db)) e.campos = { direccion_mac: "Esa dirección MAC ya está registrada en un dispositivo." };
  else if (e.estado === 409 && /uk_dir_ips_equipo/.test(e.db)) e.campos = { direccion_ip: "El dispositivo ya tiene esa dirección IP." };
  else {
    const campo = /serie/i.test(m) ? "serie" : /\bMAC\b/.test(m) ? "direccion_mac" : /\bIP\b/.test(m) ? "direccion_ip"
      : /proveedor/i.test(m) ? "id_proveedor" : /modelo/i.test(m) ? "id_modelo" : /marca/i.test(m) ? "id_marca"
        : /puertos/i.test(m) ? "cant_ptos_ethernet" : null;
    if (campo) e.campos = { [campo]: m };
  }
  return e;
}

/* ------------------------------------------------- Datos compartidos */
const modelosPorMarca = new Map();

function modelosDe(idMarca) {
  if (!idMarca) return Promise.resolve([]);
  const clave = String(idMarca);
  if (!modelosPorMarca.has(clave)) {
    modelosPorMarca.set(clave, api(`${RECURSO}/modelos/`, { query: { id_marca: idMarca } })
      .catch((e) => { modelosPorMarca.delete(clave); throw e; }));
  }
  return modelosPorMarca.get(clave);
}

/** Después de cambiar marcas o modelos, las listas se vuelven a pedir. */
function olvidarMarcasYModelos() {
  olvidarCatalogo("marcas");
  modelosPorMarca.clear();
}

async function datosBase() {
  const [tipos, marcas, sistemas, edificios, categorias, departamentos, procesadores, firmwares, estados, roles, herramientas] =
    await Promise.all([
      filasCatalogo("tipos-dispositivos"), filasCatalogo("marcas"),
      filasCatalogo("sistemas-operativos"), filasCatalogo("edificios"),
      filasCatalogo("categorias-dispositivos"), filasCatalogo("departamentos"),
      filasCatalogo("procesadores"), filasCatalogo("firmwares"), filasCatalogo("estados-equipos"),
      filasCatalogo("roles-equipos"), filasCatalogo("herramientas"),
    ]);
  return { tipos, marcas, sistemas, edificios, categorias, departamentos, procesadores, firmwares, estados, roles, herramientas };
}

/** Categoría de un tipo de equipo (por su código). */
const categoriaDe = (base, tipoDisp) => base.tipos.find((t) => t.tipo_disp === Number(tipoDisp))?.id_categoria || null;

/** <option> de los tipos de equipo agrupados por categoría (con <optgroup>). */
function opcionesTiposHTML(tipos, categorias, elegido = null) {
  const opcion = (t) => `<option value="${t.tipo_disp}"${t.tipo_disp === Number(elegido) ? " selected" : ""}>${esc(t.descripcion)}</option>`;
  const orden = (a, b) => a.descripcion.localeCompare(b.descripcion, "es");
  return [...categorias].sort((a, b) => a.id_categoria - b.id_categoria).map((c) => {
    const suyos = tipos.filter((t) => t.id_categoria === c.id_categoria).sort(orden);
    return suyos.length ? `<optgroup label="${esc(nombreCategoria(c.descripcion))}">${suyos.map(opcion).join("")}</optgroup>` : "";
  }).join("") + tipos.filter((t) => !categorias.some((c) => c.id_categoria === t.id_categoria)).sort(orden).map(opcion).join("");
}

/** EQUIPOS DE RED -> Equipos de red */
const nombreCategoria = (texto) => String(texto || "").charAt(0) + String(texto || "").slice(1).toLowerCase();
// Nombre de un lugar (vienen en mayúscula): «SAN ISIDRO» -> «San Isidro»
const nombreLugar = (texto) => String(texto || "").toLowerCase().replace(/(^|[\s-])(\p{L})/gu, (_, a, l) => a + l.toUpperCase());
/** Estado del equipo (tabla estado_equipos): Activo, Inactivo, N/D… */
const nombreEstado = (d) => (d.estado ? (d.estado === "N/D" ? "N/D" : nombreCategoria(d.estado)) : (d.activo ? "Activo" : "Inactivo"));

/* ------------------------------------------------------------ Garantía */
const DIAS_AVISO_GARANTIA = 90;   // «por vencer»: vence dentro de estos días
const FORMATO_DIA = new Intl.DateTimeFormat("es-CR", { day: "numeric", month: "short", year: "numeric" });

/** "2027-03-15" -> Date local de ese día (sin correrse por la zona horaria). */
function diaLocal(texto) {
  const [a, m, d] = String(texto || "").slice(0, 10).split("-").map(Number);
  return a && m && d ? new Date(a, m - 1, d) : null;
}

/** "2027-03-15" -> "15 mar 2027" */
const fechaDia = (texto) => { const d = diaLocal(texto); return d ? FORMATO_DIA.format(d) : "—"; };

/** Estado de la garantía según «Garantía hasta»: vencida, por vencer (en
 *  DIAS_AVISO_GARANTIA días o menos) o vigente. null si no tiene la fecha. */
function estadoGarantia(garantiaHasta, hoy = new Date()) {
  const fin = diaLocal(garantiaHasta);
  if (!fin) return null;
  const dias = Math.round((fin - new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate())) / 86400000);
  const dia = FORMATO_DIA.format(fin);
  if (dias < 0) return { clave: "vencida", dias, texto: "Garantía vencida", detalle: `Venció el ${dia}` };
  if (dias <= DIAS_AVISO_GARANTIA) {
    return { clave: "por-vencer", dias, texto: dias === 0 ? "La garantía vence hoy" : `Garantía: vence en ${dias} ${dias === 1 ? "día" : "días"}`, detalle: `Vence el ${dia}` };
  }
  return { clave: "vigente", dias, texto: `En garantía hasta ${dia}`, detalle: `Vence el ${dia}` };
}

const pastillaGarantia = (d) => {
  const g = estadoGarantia(d.garantia_hasta);
  return g ? `<span class="pastilla pastilla--sin-punto pastilla--garantia-${g.clave}" title="${esc(g.detalle)}">${icono("escudo", "ic--sm")}${esc(g.texto)}</span>` : "";
};

/* =====================================================================
   Inicio del módulo
   ===================================================================== */
export async function vistaInicioRed(cont, _params, ctx) {
  ctx.migas([{ texto: "Inicio" }]);
  cont.innerHTML = `
    <div class="saludo">
      <h1>Equipos municipales</h1>
      <p>Equipos de red, computadoras, servidores, celulares, teléfonos, impresoras, pantallas, UPS y cámaras de la municipalidad: a quién están asignados, dónde están, quién les da soporte y sus archivos.</p>
    </div>
    ${ctx.esAdmin ? "" : `<div class="aviso aviso--ocre" style="margin-top:18px">${icono("candado")}<span>Su rol permite consultar los equipos y descargar sus documentos. Los cambios los hace un administrador.</span></div>`}
    <div id="resumen-red">${cargandoHTML()}</div>
    <div class="dos-columnas">
      <section class="panel">
        <div class="panel__cabeza"><div><h2>Registrados recientemente</h2></div><a class="btn btn--fantasma btn--sm" href="#/red/dispositivos">Ver todos</a></div>
        <div id="recientes-red">${cargandoHTML()}</div>
      </section>
      <section class="panel">
        <div class="panel__cabeza"><h2>Accesos rápidos</h2></div>
        <ul class="atajos">${atajosRed(ctx).join("")}</ul>
      </section>
    </div>
    <div id="garantias-red"></div>
    ${ctx.esAdmin ? `
    <section class="panel" style="margin-top:20px">
      <div class="panel__cabeza"><div><h2>Actividad reciente</h2><p>Últimos cambios a los equipos.</p></div><a class="btn btn--fantasma btn--sm" href="#/red/auditoria">Ver toda la auditoría</a></div>
      <div class="panel__cuerpo" id="actividad-red"></div>
    </section>` : ""}`;

  if (ctx.esAdmin) {
    feedAuditoria(cont.querySelector("#actividad-red"), { tabla: "equipos" }, {
      limite: 8, paginar: false, vacio: "Todavía no hay cambios en los equipos.",
    }).catch((e) => { cont.querySelector("#actividad-red").innerHTML = errorHTML(e.message); });
  }

  const [dispositivos, categorias] = await Promise.all([
    api(`${RECURSO}/`, { query: { activo: true } }),
    filasCatalogo("categorias-dispositivos"),
  ]);
  if (!ctx.vigente()) return;

  const ordenadas = [...categorias].sort((a, b) => a.id_categoria - b.id_categoria);
  const cuantos = (c) => dispositivos.filter((d) => d.id_categoria === c.id_categoria).length;
  cont.querySelector("#resumen-red").outerHTML = `
    <h2 class="resumen__titulo" id="titulo-resumen-red">Equipos activos por categoría</h2>
    <nav class="resumen resumen--iconos resumen--categorias" aria-labelledby="titulo-resumen-red" style="--columnas:${Math.min(Math.max(ordenadas.length, 1), 5)}">
      ${ordenadas.map((c) => `<a href="#/red/dispositivos?id_categoria=${c.id_categoria}">${icono(ICONO_CATEGORIA[c.id_categoria] || "equipo")}<b>${cuantos(c)}</b><span>${esc(nombreCategoria(c.descripcion))}</span></a>`).join("")}
    </nav>`;

  pintarGarantias(cont.querySelector("#garantias-red"), dispositivos);

  const recientes = [...dispositivos].sort((a, b) => String(b.creado_en).localeCompare(String(a.creado_en))).slice(0, 6);
  const caja = cont.querySelector("#recientes-red");
  if (!recientes.length) {
    caja.innerHTML = vacioHTML({
      icono: "red", titulo: "Todavía no hay equipos",
      boton: ctx.esAdmin ? `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar el primero</a>` : "",
    });
    return;
  }
  caja.innerHTML = tablaHTML({
    clicable: true,
    filas: recientes,
    columnas: [
      { titulo: "Equipo", html: (d) => celdaDispositivo(d) },
      { titulo: "Registrado", html: (d) => `<span class="secundario">${esc(fecha(d.creado_en))}</span>` },
    ],
  });
  caja.addEventListener("click", (ev) => {
    const r = eventoFila(ev, recientes);
    if (r && !ev.target.closest("a")) location.hash = `#/red/dispositivos/${r.fila.id_disp}`;
  });
}

function atajosRed(ctx) {
  const item = (href, ic, titulo, texto) =>
    `<li><a href="${href}">${icono(ic)}<span><strong>${esc(titulo)}</strong><small>${esc(texto)}</small></span>${icono("derecha")}</a></li>`;
  return [
    ctx.esAdmin
      ? item("#/red/dispositivos/nuevo", "mas", "Registrar un equipo", "Laptop, impresora, celular, switch… con los datos de cada uno")
      : item("#/red/dispositivos", "red", "Buscar un equipo", "Por serie, placa, nombre en la red, responsable, IP o MAC"),
    item("#/red/switches", "switch", "Switches y puertos", "Qué equipo está conectado a cada puerto"),
    item("#/red/edificios", "edificio", "Edificios", "Dónde están los equipos"),
    item("#/red/marcas", "etiqueta", "Marcas y modelos", "Por tipo de equipo"),
    item("#/red/catalogos/tipos-dispositivos", "equipo", "Tipos de equipo", "Cada uno en su categoría"),
    item("#/red/catalogos/tipos-documentos", "documento", "Tipos de archivo", "Manual, garantía, configuración, backup…"),
  ];
}

/** Inicio: los equipos activos cuya garantía vence pronto (solo si hay alguno). */
function pintarGarantias(caja, dispositivos) {
  const conEstado = dispositivos.map((d) => ({ d, g: estadoGarantia(d.garantia_hasta) })).filter((x) => x.g);
  const porVencer = conEstado.filter((x) => x.g.clave === "por-vencer").sort((a, b) => a.g.dias - b.g.dias);
  if (!porVencer.length) return;
  const vencidas = conEstado.filter((x) => x.g.clave === "vencida").length;
  const filas = porVencer.map((x) => x.d);
  caja.innerHTML = `
    <section class="panel panel--garantias" style="margin-top:20px">
      <div class="panel__cabeza"><div><h2>${icono("escudo")} Garantías por vencer (${porVencer.length})</h2>
        <p>Equipos activos cuya garantía vence en los próximos ${DIAS_AVISO_GARANTIA} días: revise con el proveedor si conviene extenderla.
          ${vencidas === 1 ? "Otro equipo activo ya tiene la garantía vencida." : vencidas ? `Otros ${vencidas} equipos activos ya tienen la garantía vencida.` : ""}</p></div></div>
      ${tablaHTML({
        clicable: true,
        filas,
        columnas: [
          { titulo: "Equipo", html: (d) => celdaDispositivo(d) },
          {
            titulo: "Vence",
            html: (d) => { const g = estadoGarantia(d.garantia_hasta); return `${esc(fechaDia(d.garantia_hasta))}<span class="secundario">${g.dias === 0 ? "Hoy" : `En ${g.dias} ${g.dias === 1 ? "día" : "días"}`}</span>`; },
          },
          {
            titulo: "Proveedor de soporte", clase: "col-opcional",
            html: (d) => (d.proveedor ? `<a href="#/proveedores/${d.id_proveedor}">${esc(d.proveedor)}</a>` : `<span class="secundario">Sin proveedor</span>`),
          },
        ],
      })}
    </section>`;
  caja.addEventListener("click", (ev) => {
    const r = eventoFila(ev, filas);
    if (r && !ev.target.closest("a")) location.hash = `#/red/dispositivos/${r.fila.id_disp}`;
  });
}

const celdaDispositivo = (d) => `
  <div class="persona">${insigniaTipo(d)}<div>
    <a href="#/red/dispositivos/${d.id_disp}"><strong>${esc(tituloDispositivo(d))}</strong></a>
    <span class="secundario">${esc([marcaAparte(d), d.nombre_equipo, `Serie ${d.serie}`].filter(Boolean).join(" · "))}</span>
  </div></div>`;

/* =====================================================================
   Lista de equipos
   ===================================================================== */
const FILTROS_LISTA = ["buscar", "id_categoria", "tipo_disp", "id_marca", "id_predio", "cod_departamento", "id_proveedor", "activo"];

/* Columnas del CSV de la lista: todos los datos del equipo (los que no lleva su categoría quedan vacíos) */
const decimal = (v) => (v === null || v === undefined || v === "" ? "" : Number(v).toLocaleString("es-CR", { maximumFractionDigits: 2, useGrouping: false }));
const COLUMNAS_CSV = [
  ["Serie", (d) => d.serie], ["Placa", (d) => d.placa], ["Categoría", (d) => nombreCategoria(d.categoria)],
  ["Tipo", (d) => d.tipo_dispositivo], ["Marca", (d) => d.marca], ["Modelo", (d) => d.modelo], ["Nombre en la red", (d) => d.nombre_equipo],
  ["Sistema operativo", (d) => d.sistema_operativo], ["Firmware o versión", (d) => (d.id_firmw > 1 ? d.firmware : "")], ["Procesador", (d) => d.procesador],
  ["Memoria RAM (GB)", (d) => d.memoria_gb], ["Almacenamiento (GB)", (d) => d.almacenamiento_gb],
  ["Tipo de disco", (d) => ALMACENAMIENTOS.find(([v]) => v === d.tipo_almacenamiento)?.[1] || d.tipo_almacenamiento],
  ["Pantalla (pulgadas)", (d) => decimal(d.pulgadas)], ["Resolución", (d) => d.resolucion],
  ["Puertos serie", (d) => d.cant_ptos_serie], ["Puertos USB", (d) => d.cant_ptos_usb],
  ["Puertos Ethernet", (d) => d.cant_ptos_ethernet], ["Puertos SFP", (d) => d.cant_ptos_sfp],
  ["Puertos inalámbricos", (d) => d.cant_ptos_wireless], ["Puertos Bluetooth", (d) => d.cant_ptos_bluetooth],
  ["Puertos celular (SIM)", (d) => d.cant_ptos_celular],
  ["SFP combinados", (d) => (d.id_categoria === CAT.RED && d.cant_ptos_sfp ? (d.sfp_combo ? "Sí" : "No") : "")], ["Canales de video", (d) => d.canales],
  ["IMEI", (d) => lista(d.imeis).join(" ")], ["Líneas móviles", (d) => d.moviles],
  ["Extensión", (d) => d.extension], ["Tecnología de impresión", (d) => d.tecnologia_impresion],
  ["Imprime a color", (d) => (d.id_categoria === CAT.IMPRESION ? (d.a_color ? "Sí" : "No") : "")], ["Tóner o cartucho", (d) => d.consumible],
  ["Capacidad (VA)", (d) => d.capacidad_va], ["Autonomía (minutos)", (d) => d.autonomia_min],
  ["Direcciones IP", (d) => lista(d.ips).join(" ")], ["Direcciones MAC", (d) => lista(d.macs).map(formatearMac).join(" ")],
  ["Edificio", (d) => d.edificio], ["Ubicación en el edificio", (d) => d.ubicacion], ["Departamento", (d) => d.departamento],
  ["Funcionario responsable", (d) => d.asignado], ["Proveedor de soporte", (d) => d.proveedor],
  ["Fecha de compra", (d) => (d.fecha_compra ? String(d.fecha_compra).slice(0, 10) : "")],
  ["Garantía hasta", (d) => (d.garantia_hasta ? String(d.garantia_hasta).slice(0, 10) : "")],
  ["Garantía", (d) => {
    const g = estadoGarantia(d.garantia_hasta);
    if (!g) return "";
    if (g.clave !== "por-vencer") return g.clave === "vencida" ? "Vencida" : "Vigente";
    return g.dias === 0 ? "Vence hoy" : `Vence en ${g.dias} ${g.dias === 1 ? "día" : "días"}`;
  }],
  ["Tiene Microclaudia", (d) => ([CAT.COMPUTO, CAT.SERVIDOR].includes(d.id_categoria) || d.tiene_microclaudia ? (d.tiene_microclaudia ? "Sí" : "No") : "")],
  ["Herramientas de seguridad", (d) => d.herramientas_texto], ["Roles", (d) => d.roles_texto],
  ["Documentos", (d) => d.cantidad_documentos || 0], ["Observaciones", (d) => d.observaciones],
  ["Estado", (d) => nombreEstado(d)], ["Registrado", (d) => (d.creado_en ? String(d.creado_en).slice(0, 10) : "")],
];

/** Todos los datos de un equipo que tienen valor: [[etiqueta, texto], ...] (los
    mismos del CSV). Los usa el detalle del equipo conectado a un puerto. */
export const datosCompletos = (d) => COLUMNAS_CSV
  .map(([t, f]) => [t, f(d)])
  .filter(([t, v]) => v !== null && v !== undefined && v !== "" && !(["Documentos", "Puertos Ethernet", "Puertos SFP"].includes(t) && !Number(v)));

/** La lista de equipos (con los filtros aplicados) en un CSV para Excel. */
const csvEquipos = (filas) => textoCsv([COLUMNAS_CSV.map(([t]) => t), ...filas.map((d) => COLUMNAS_CSV.map(([, f]) => f(d) ?? ""))]);

export async function vistaDispositivos(cont, _params, ctx) {
  ctx.migas([{ texto: "Equipos" }]);
  const q = ctx.query || new URLSearchParams();
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Equipos</h1>
        <p>Inventario de equipos municipales: de red, computadoras, servidores, móviles, telefonía, impresión y más, con su responsable, ubicación, proveedor de soporte y documentos.</p>
      </div>
      <div class="encabezado__acciones">
        <button type="button" class="btn btn--secundario" data-exportar-equipos disabled title="Descarga los equipos de la lista, con los filtros aplicados">${icono("descargar")}Exportar (CSV)</button>
        ${ctx.esAdmin ? `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Nuevo equipo</a>` : ""}
      </div>
    </div>
    <section class="panel">
      <div data-asignado-filtro hidden></div>
      <form class="filtros" role="search" id="filtros-dispositivos">
        <div class="campo campo--buscar">
          <label for="d-buscar">Buscar</label>
          <div class="buscador">${icono("buscar")}<input id="d-buscar" name="buscar" type="search" placeholder="Serie, placa, nombre en la red, responsable, IP o MAC" autocomplete="off"></div>
        </div>
        <div class="campo"><label for="d-categoria">Categoría</label><select id="d-categoria" name="id_categoria"><option value="">Todas</option></select></div>
        <div class="campo"><label for="d-tipo">Tipo</label><select id="d-tipo" name="tipo_disp"><option value="">Todos</option></select></div>
        <div class="campo"><label for="d-marca">Marca</label><select id="d-marca" name="id_marca"><option value="">Todas</option></select></div>
        <div class="campo"><label for="d-edificio">Edificio</label><select id="d-edificio" name="id_predio"><option value="">Todos</option></select></div>
        <div class="campo"><label for="d-departamento">Departamento</label><select id="d-departamento" name="cod_departamento"><option value="">Todos</option></select></div>
        <div class="campo campo--ancho"><label for="d-proveedor">Proveedor</label><select id="d-proveedor" name="id_proveedor"><option value="">Todos</option></select></div>
        <div class="campo">
          <label for="d-activo">Estado</label>
          <select id="d-activo" name="activo">
            <option value="true">Activos</option><option value="false">Inactivos</option><option value="">Todos</option>
          </select>
        </div>
        <span class="filtros__total" id="total-dispositivos" aria-live="polite"></span>
      </form>
      <div id="lista-dispositivos">${cargandoHTML()}</div>
    </section>`;

  const form = cont.querySelector("#filtros-dispositivos");
  const lista = cont.querySelector("#lista-dispositivos");
  const total = cont.querySelector("#total-dispositivos");
  const avisoAsignado = cont.querySelector("[data-asignado-filtro]");
  const exportar = cont.querySelector("[data-exportar-equipos]");
  let filas = [];
  // Desde la ficha de una persona: #/red/dispositivos?id_asignado=5
  let idAsignado = q.get("id_asignado") || "";

  const [base, proveedores] = await Promise.all([datosBase(), api("proveedores/", { query: { activo: "" } })]);
  if (!ctx.vigente()) return;
  const opcionesHTML = (lista2) => lista2.map((o) => `<option value="${esc(o.valor)}">${esc(o.texto)}</option>`).join("");
  form.id_categoria.insertAdjacentHTML("beforeend", opcionesHTML(opciones([...base.categorias].sort((a, b) => a.id_categoria - b.id_categoria),
    "id_categoria", (c) => nombreCategoria(c.descripcion))));
  form.id_predio.insertAdjacentHTML("beforeend", opcionesHTML(opciones(base.edificios, "id_predio")));
  form.cod_departamento.insertAdjacentHTML("beforeend", opcionesHTML(opciones(base.departamentos, "cod_departamento")));
  form.id_proveedor.insertAdjacentHTML("beforeend", opcionesHTML(opciones(proveedores, "id", nombreCompleto)));

  function llenarTipos() {
    const cat = Number(form.id_categoria.value);
    const anterior = form.tipo_disp.value;
    const tipos = base.tipos.filter((t) => !cat || t.id_categoria === cat);
    form.tipo_disp.innerHTML = `<option value="">Todos</option>${cat ? opcionesHTML(opciones([...tipos].sort((a, b) => a.descripcion.localeCompare(b.descripcion, "es")), "tipo_disp"))
      : opcionesTiposHTML(tipos, base.categorias)}`;
    if (tipos.some((t) => String(t.tipo_disp) === anterior)) form.tipo_disp.value = anterior;
  }

  function llenarMarcas() {
    const tipo = Number(form.tipo_disp.value);
    const cat = Number(form.id_categoria.value);
    const anterior = form.id_marca.value;
    const marcas = base.marcas.filter((m) => (tipo ? m.tipo_disp === tipo : !cat || categoriaDe(base, m.tipo_disp) === cat));
    form.id_marca.innerHTML = `<option value="">Todas</option>${opcionesHTML(opciones(marcas, "id_marca", (m) => (tipo ? m.descripcion : `${m.descripcion} (${m.tipo_dispositivo.toLowerCase()})`)))}`;
    if (marcas.some((m) => String(m.id_marca) === anterior)) form.id_marca.value = anterior;
  }

  // Filtros que vienen en la dirección (#/red/dispositivos?id_categoria=2)
  for (const nombre of ["buscar", "id_categoria", "id_predio", "cod_departamento", "id_proveedor", "activo"]) {
    if (q.has(nombre)) form[nombre].value = q.get(nombre);
  }
  llenarTipos();
  if (q.has("tipo_disp")) form.tipo_disp.value = q.get("tipo_disp");
  llenarMarcas();
  if (q.has("id_marca")) form.id_marca.value = q.get("id_marca");

  function pintarAvisoAsignado() {
    avisoAsignado.hidden = !idAsignado;
    if (!idAsignado) return;
    avisoAsignado.innerHTML = `<div class="aviso aviso--info filtro-persona">${icono("usuario")}<span>Equipos asignados a <strong data-nombre-asignado>la persona N.º ${esc(idAsignado)}</strong>.</span>
      <a class="btn btn--fantasma btn--sm" href="#/usuarios/${esc(idAsignado)}">Ver su ficha</a>
      <button type="button" class="btn btn--fantasma btn--sm" data-quitar-asignado>${icono("cerrar")}Quitar este filtro</button></div>`;
    api(ruta("usuarios", idAsignado)).then((u) => {
      const el = avisoAsignado.querySelector("[data-nombre-asignado]");
      if (el) el.textContent = nombreCompleto(u);
    }).catch(() => {});
  }
  avisoAsignado.addEventListener("click", (ev) => {
    if (!ev.target.closest("[data-quitar-asignado]")) return;
    idAsignado = "";
    pintarAvisoAsignado();
    cargar();
  });
  pintarAvisoAsignado();

  let consulta = 0;
  async function cargar() {
    const esta = ++consulta;
    const query = { ...Object.fromEntries(FILTROS_LISTA.map((n) => [n, form[n].value.trim()])), id_asignado: idAsignado };
    // La dirección guarda los filtros para volver a la misma lista
    const qs = new URLSearchParams(Object.entries(query).filter(([n, v]) => v !== "" && !(n === "activo" && v === "true"))).toString();
    history.replaceState(null, "", `#/red/dispositivos${qs ? `?${qs}` : ""}`);
    lista.innerHTML = cargandoHTML();
    exportar.disabled = true;
    try {
      filas = await api(`${RECURSO}/`, { query });
    } catch (e) {
      if (esta === consulta) { filas = []; lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`; }
      return;
    }
    if (esta !== consulta || !ctx.vigente()) return;
    total.textContent = `${filas.length} ${filas.length === 1 ? "equipo" : "equipos"}`;
    exportar.disabled = !filas.length;

    if (!filas.length) {
      const hayFiltros = idAsignado || FILTROS_LISTA.some((n) => n !== "activo" && form[n].value);
      lista.innerHTML = vacioHTML({
        icono: "red",
        titulo: hayFiltros ? "Ningún equipo coincide con la búsqueda" : "No hay equipos en este estado",
        texto: hayFiltros ? "Pruebe con otro texto o quite los filtros." : "",
        boton: ctx.esAdmin && !hayFiltros ? `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar el primero</a>` : "",
      });
      return;
    }

    lista.innerHTML = tablaHTML({
      clicable: true,
      filas,
      columnas: [
        { titulo: "Equipo", html: celdaDispositivo },
        { titulo: "Tipo", html: (d) => `${esc(d.tipo_dispositivo)}<span class="secundario">${esc(nombreCategoria(d.categoria))}</span>` },
        {
          titulo: "Responsable", clase: "col-opcional",
          html: (d) => (d.asignado || d.departamento
            ? `${d.asignado ? `<a href="#/usuarios/${d.id_asignado}">${esc(d.asignado)}</a>` : `<span class="secundario">Sin persona asignada</span>`}<span class="secundario">${esc(d.departamento || "")}</span>`
            : `<span class="secundario">Sin asignar</span>`),
        },
        {
          titulo: "Ubicación", clase: "col-opcional",
          html: (d) => (d.edificio || d.ubicacion
            ? `${esc(d.edificio || "Sin edificio")}<span class="secundario">${esc(d.ubicacion || "")}</span>`
            : `<span class="secundario">Sin ubicación</span>`),
        },
        {
          titulo: "Red", clase: "col-opcional",
          html: (d) => (d.ips || d.macs
            ? `<span class="dato-mono">${d.ips ? resumenDirecciones(d.ips) : "Sin IP"}</span><span class="secundario dato-mono">${resumenDirecciones(d.macs, formatearMac)}</span>`
            : `<span class="secundario">Sin direcciones</span>`),
        },
        {
          titulo: "Documentos", clase: "col-opcional col-numero",
          html: (d) => (d.cantidad_documentos ? `${icono("documento", "ic--sm")} ${d.cantidad_documentos}` : `<span class="secundario">—</span>`),
        },
        { titulo: "Estado", html: (d) => pastillaEstado(d.activo) },
      ],
    });
  }

  lista.addEventListener("click", (ev) => {
    const r = eventoFila(ev, filas);
    if (r && !ev.target.closest("a")) location.hash = `#/red/dispositivos/${r.fila.id_disp}`;
  });
  exportar.addEventListener("click", () => {
    if (!filas.length) return;
    descargarTexto(csvEquipos(filas), `equipos_${marcaArchivo()}.csv`);
    toast(`Se descargó el archivo con ${filas.length} ${filas.length === 1 ? "equipo" : "equipos"}.`);
  });
  form.addEventListener("submit", (ev) => { ev.preventDefault(); cargar(); });
  form.buscar.addEventListener("input", debounce(cargar, 300));
  form.id_categoria.addEventListener("change", () => { llenarTipos(); llenarMarcas(); cargar(); });
  form.tipo_disp.addEventListener("change", () => { llenarMarcas(); cargar(); });
  ["id_marca", "id_predio", "cod_departamento", "id_proveedor", "activo"].forEach((n) => form[n].addEventListener("change", cargar));

  await cargar();
}

/* =====================================================================
   Formulario del equipo (crear y editar)
   ===================================================================== */
// Cada dato se pide solo en las categorías de «cats» (sin «cats»: en todas)
const SIN_PANTALLA = [CAT.RED, CAT.COMPUTO, CAT.SERVIDOR, CAT.MOVIL, CAT.TELEFONIA, CAT.IMPRESION, CAT.ENERGIA, CAT.VIDEO, CAT.OTRO];
const FIRMWARE = { [CAT.RED]: "Versión del firmware", [CAT.TELEFONIA]: "Versión del firmware", [CAT.IMPRESION]: "Versión del firmware",
  [CAT.ENERGIA]: "Versión del firmware", [CAT.VIDEO]: "Versión del firmware" };
const TECNOLOGIAS = ["LÁSER", "TINTA", "TINTA CONTINUA", "TÉRMICA", "MATRIZ DE PUNTO"];
// Herramientas de seguridad (Bitdefender, Microclaudia, Cisco Umbrella…): equipos con sistema operativo
const HERRAMIENTAS = [CAT.RED, CAT.COMPUTO, CAT.SERVIDOR, CAT.MOVIL, CAT.OTRO];
const ALMACENAMIENTOS = [["SSD", "SSD"], ["NVME", "SSD NVMe"], ["HDD", "Disco duro (HDD)"], ["EMMC", "eMMC"]];

/** Personas para «Funcionario responsable»: el personal activo (y la asignada, aunque esté inactiva). */
function opcionesPersonal(personal, valores) {
  const ops = [...personal].sort((a, b) => nombreCompleto(a).localeCompare(nombreCompleto(b), "es"))
    .map((u) => ({ valor: u.id, texto: nombreCompleto(u) }));
  if (valores.id_asignado && !ops.some((o) => o.valor === valores.id_asignado)) {
    ops.push({ valor: valores.id_asignado, texto: `${valores.asignado || `Persona ${valores.id_asignado}`} (inactiva)` });
  }
  return ops;
}

function seccionesDispositivo(base, proveedores, personal, valores = {}) {
  const provOpciones = opciones(proveedores, "id", nombreCompleto);
  if (valores.id_proveedor && !provOpciones.some((o) => o.valor === valores.id_proveedor)) {
    provOpciones.push({ valor: valores.id_proveedor, texto: `${valores.proveedor || `Proveedor ${valores.id_proveedor}`} (inactivo)` });
  }
  const numero = (nombre, etiqueta, cats, extra = {}) => ({ nombre, etiqueta, tipo: "number", entero: true, minimo: 1, cats, ...extra });
  const PUERTO = { minimo: 0, maximo: 9999, placeholder: "0" };
  return [
    {
      clave: "equipo", titulo: "Equipo", icono: "red",
      texto: "El tipo decide qué datos se piden. La marca depende del tipo y el modelo depende de la marca.",
      campos: [
        { nombre: "tipo_disp", etiqueta: "Tipo de equipo", tipo: "select", opciones: [], requerido: true, entero: true },
        { nombre: "id_marca", etiqueta: "Marca", tipo: "select", opciones: [], requerido: true, entero: true },
        { nombre: "id_modelo", etiqueta: "Modelo", tipo: "select", opciones: [], entero: true, vacioTexto: "Sin modelo" },
        { nombre: "serie", etiqueta: "Número de serie", requerido: true, max: 100, placeholder: "658429" },
        { nombre: "placa", etiqueta: "Placa (número de activo)", max: 50, placeholder: "MG-000123" },
        {
          nombre: "nombre_equipo", etiqueta: "Nombre en la red", max: 100, placeholder: "PC-FIN-01", cats: SIN_PANTALLA,
          ayuda: "El nombre del equipo en la red (hostname): se compara con el DHCP y con Microclaudia.",
        },
        {
          nombre: "id_estado", etiqueta: "Estado", tipo: "select", opciones: opciones(base.estados, "id_estado", (e) => (e.descripcion === "N/D" ? "N/D" : nombreCategoria(e.descripcion))),
          entero: true, sinVacio: true, ayuda: "INACTIVO es un equipo dado de baja: no se compara con la red ni se puede conectar a un switch.",
        },
      ],
    },
    {
      clave: "sistema", titulo: "Sistema", icono: "sistema",
      texto: "Sistema operativo o firmware y su versión.",
      campos: [
        {
          nombre: "id_os", etiqueta: "Sistema operativo", tipo: "select", opciones: opciones(base.sistemas, "id_os"), entero: true, sinVacio: true,
          cats: [CAT.RED, CAT.COMPUTO, CAT.SERVIDOR, CAT.MOVIL, CAT.TELEFONIA, CAT.IMPRESION, CAT.VIDEO, CAT.OTRO],
        },
        {
          nombre: "id_firmw", etiqueta: "Versión del sistema", tipo: "select", opciones: opciones(base.firmwares, "id_firmw"), entero: true,
          sinVacio: true, cats: SIN_PANTALLA, etiquetas: FIRMWARE,
          ayuda: "Si no está en la lista, agréguela en Catálogos › Firmwares.",
        },
      ],
    },
    {
      clave: "seguridad", titulo: "Herramientas y roles", icono: "escudo",
      texto: "Herramientas de seguridad instaladas y, en servidores y equipos de red, los roles que cumple.",
      campos: [
        {
          nombre: "herramientas", etiqueta: "Herramientas de seguridad", tipo: "casillas", cats: HERRAMIENTAS,
          opciones: opciones(base.herramientas.filter((h) => h.id_herram !== 1), "id_herram"),
          ayuda: "MICROCLAUDIA es el agente del antivirus: en Licencias y reportes se compara con el listado de Microclaudia.",
        },
        {
          nombre: "roles", etiqueta: "Roles del servidor", tipo: "casillas", cats: [CAT.SERVIDOR, CAT.RED],
          opciones: opciones(base.roles.filter((r) => r.id_rol !== 1), "id_rol"),
        },
      ],
    },
    {
      clave: "hardware", titulo: "Características", icono: "equipo",
      texto: "Procesador, memoria, disco y pantalla.",
      campos: [
        {
          nombre: "id_proces", etiqueta: "Procesador", tipo: "select", opciones: opciones(base.procesadores, "id_proc"), entero: true,
          vacioTexto: "Sin indicar", cats: [CAT.COMPUTO, CAT.SERVIDOR, CAT.RED], ayuda: "Si no está en la lista, agréguelo en Catálogos › Procesadores.",
        },
        numero("memoria_gb", "Memoria RAM (GB)", [CAT.COMPUTO, CAT.SERVIDOR, CAT.MOVIL], { maximo: 4096, placeholder: "16" }),
        numero("almacenamiento_gb", "Almacenamiento (GB)", [CAT.COMPUTO, CAT.SERVIDOR, CAT.MOVIL, CAT.VIDEO], { maximo: 1000000, placeholder: "512" }),
        {
          nombre: "tipo_almacenamiento", etiqueta: "Tipo de disco", tipo: "select", vacioTexto: "Sin indicar",
          opciones: ALMACENAMIENTOS.map(([valor, texto]) => ({ valor, texto })), cats: [CAT.COMPUTO, CAT.SERVIDOR],
        },
        {
          nombre: "pulgadas", etiqueta: "Pantalla (pulgadas)", tipo: "number", minimo: 1, maximo: 150, paso: "0.1", placeholder: "14",
          cats: [CAT.COMPUTO, CAT.MOVIL, CAT.PANTALLA],
        },
        { nombre: "resolucion", etiqueta: "Resolución", max: 20, placeholder: "1920X1080", cats: [CAT.PANTALLA, CAT.VIDEO] },
      ],
    },
    {
      clave: "puertos", titulo: "Puertos", icono: "puertos",
      texto: "Cantidad de puertos del equipo.",
      campos: [
        numero("cant_ptos_ethernet", "Puertos Ethernet", [CAT.RED, CAT.COMPUTO, CAT.SERVIDOR, CAT.TELEFONIA, CAT.IMPRESION, CAT.VIDEO], PUERTO),
        numero("cant_ptos_sfp", "Puertos SFP", [CAT.RED, CAT.SERVIDOR], PUERTO),
        numero("cant_ptos_serie", "Puertos serie o consola", [CAT.RED, CAT.COMPUTO, CAT.SERVIDOR, CAT.ENERGIA], PUERTO),
        numero("cant_ptos_usb", "Puertos USB", [CAT.RED, CAT.COMPUTO, CAT.SERVIDOR, CAT.MOVIL, CAT.IMPRESION, CAT.PANTALLA, CAT.VIDEO], PUERTO),
        numero("cant_ptos_wireless", "Puertos inalámbricos (radios)", [CAT.RED, CAT.COMPUTO, CAT.MOVIL, CAT.TELEFONIA, CAT.IMPRESION], PUERTO),
        numero("cant_ptos_bluetooth", "Puertos Bluetooth", [CAT.COMPUTO, CAT.MOVIL, CAT.TELEFONIA], PUERTO),
        numero("cant_ptos_celular", "Puertos celular (SIM)", [CAT.RED, CAT.COMPUTO, CAT.MOVIL], PUERTO),
        {
          nombre: "sfp_combo", etiqueta: "SFP combinados (45F comparte número con 45T)", tipo: "checkbox", cats: [CAT.RED], completo: true,
          ayuda: "Márquelo si los SFP comparten número con los últimos puertos de cobre, como el D-Link DGS-3120 (45F a 48F). Si no, los SFP siguen la numeración (49, 50…). Así se dibujan en la pestaña Puertos.",
        },
        numero("canales", "Canales de video", [CAT.VIDEO], { maximo: 512, placeholder: "16" }),
      ],
    },
    {
      clave: "linea", titulo: "Línea telefónica", icono: "telefono",
      texto: "Las líneas que usa el equipo con su operador, el IMEI de cada SIM (en el celular: marque *#06#) y la extensión del teléfono IP.",
      campos: [
        { nombre: "extension", etiqueta: "Extensión", max: 10, placeholder: "1234", mayus: false, cats: [CAT.TELEFONIA] },
      ],
      listas: ["moviles", "imeis"],
    },
    {
      clave: "impresion", titulo: "Impresión", icono: "impresora",
      texto: "Cómo imprime y qué consumible usa.",
      campos: [
        {
          nombre: "tecnologia_impresion", etiqueta: "Tecnología", tipo: "select", vacioTexto: "Sin indicar",
          opciones: TECNOLOGIAS.map((t) => ({ valor: t, texto: nombreCategoria(t) })), cats: [CAT.IMPRESION],
        },
        { nombre: "consumible", etiqueta: "Tóner o cartucho", max: 100, placeholder: "HP 58A", cats: [CAT.IMPRESION] },
        { nombre: "a_color", etiqueta: "Imprime a color", tipo: "checkbox", cats: [CAT.IMPRESION] },
      ],
    },
    {
      clave: "energia", titulo: "Energía", icono: "ups",
      texto: "Capacidad de la UPS y cuánto dura con la batería.",
      campos: [
        numero("capacidad_va", "Capacidad (VA)", [CAT.ENERGIA], { maximo: 1000000, placeholder: "1500" }),
        numero("autonomia_min", "Autonomía (minutos)", [CAT.ENERGIA], { maximo: 9999, placeholder: "15" }),
      ],
    },
    {
      clave: "ubicacion", titulo: "Ubicación", icono: "punto", despues: true,
      texto: "Edificio donde está el equipo y el lugar exacto dentro de él. La ubicación GPS se toma del edificio.",
      campos: [
        { nombre: "id_predio", etiqueta: "Edificio", tipo: "select", opciones: opciones(base.edificios, "id_predio"), entero: true, vacioTexto: "Sin edificio" },
        { nombre: "ubicacion", etiqueta: "Ubicación en el edificio", max: 255, placeholder: "Piso 2, oficina de contabilidad, rack 1" },
      ],
    },
    {
      clave: "asignacion", titulo: "Asignación", icono: "usuario", despues: true,
      texto: "Departamento que usa el equipo y el funcionario responsable.",
      campos: [
        {
          nombre: "cod_departamento", etiqueta: "Departamento", tipo: "select", entero: true, vacioTexto: "Sin departamento",
          opciones: opciones([...base.departamentos].sort((a, b) => a.descripcion.localeCompare(b.descripcion, "es")), "cod_departamento"),
        },
        { nombre: "id_asignado", etiqueta: "Funcionario responsable", tipo: "select", opciones: opcionesPersonal(personal, valores), entero: true, vacioTexto: "Sin asignar" },
      ],
    },
    {
      clave: "soporte", titulo: "Compra y soporte", icono: "proveedor", despues: true,
      texto: "Proveedor que le da soporte, fechas de compra y de garantía, y observaciones.",
      campos: [
        { nombre: "id_proveedor", etiqueta: "Proveedor de soporte", tipo: "select", opciones: provOpciones, entero: true, vacioTexto: "Sin proveedor", completo: true },
        { nombre: "fecha_compra", etiqueta: "Fecha de compra", tipo: "date" },
        { nombre: "garantia_hasta", etiqueta: "Garantía hasta", tipo: "date" },
        { nombre: "observaciones", etiqueta: "Observaciones", tipo: "textarea", max: 500, completo: true },
      ],
    },
  ];
}

const seccionEquipoHTML = (s, valores, soloLectura) => `
  <section class="seccion-form" data-seccion="${s.clave}">
    <h3>${icono(s.icono)}${esc(s.titulo)}</h3>
    <p>${esc(s.texto)}</p>
    <div class="rejilla">${camposHTML(s.campos, valores, { soloLectura })}</div>
    ${(s.listas || []).map((clave) => repetibleHTML(clave, soloLectura)).join("")}
  </section>`;

/** Las secciones del equipo, las direcciones de red y las de ubicación, asignación y soporte. */
const formularioEquipoHTML = (secciones, valores, soloLectura) =>
  secciones.filter((s) => !s.despues).map((s) => seccionEquipoHTML(s, valores, soloLectura)).join("")
  + seccionDireccionesHTML(soloLectura)
  + secciones.filter((s) => s.despues).map((s) => seccionEquipoHTML(s, valores, soloLectura)).join("");

const pideCampo = (c, idCategoria) => !c.cats || (idCategoria !== null && c.cats.includes(idCategoria));

/** Muestra solo los datos que lleva la categoría del tipo elegido (sin tipo:
 *  solo los comunes). Los demás se ocultan y no se mandan. */
function aplicarCategoria(form, secciones, idCategoria, soloLectura) {
  for (const s of secciones) {
    let alguno = false;
    for (const clave of s.listas || []) {
      const ver = pideCampo(DIRECCIONES[clave], idCategoria);
      const caja = form.querySelector(`[data-repetible="${clave}"]`);
      if (caja) caja.hidden = !ver;
      alguno ||= ver;
    }
    for (const c of s.campos) {
      const caja = form.querySelector(`.campo[data-campo="${c.nombre}"]`);
      if (!caja) continue;
      const ver = pideCampo(c, idCategoria);
      caja.hidden = !ver;
      alguno ||= ver;
      const controles = c.tipo === "casillas" ? [...caja.querySelectorAll("input[type=checkbox]")] : [form.elements.namedItem(c.nombre)];
      if (c.cats && !soloLectura) controles.filter(Boolean).forEach((x) => { x.disabled = !ver; });
      if (c.etiquetas) {
        const etiqueta = caja.querySelector("label");
        if (etiqueta) etiqueta.textContent = c.etiquetas[idCategoria] || c.etiqueta;
      }
    }
    const seccion = form.querySelector(`[data-seccion="${s.clave}"]`);
    if (seccion) seccion.hidden = !alguno;
  }
}

/** Datos del formulario: los que no lleva la categoría van vacíos (las
 *  casillas, sin ninguna marcada). */
function leerEquipo(form, campos, idCategoria) {
  const datos = leerCampos(form, campos);
  for (const c of campos) if (!pideCampo(c, idCategoria)) datos[c.nombre] = c.tipo === "casillas" ? [] : null;
  return datos;
}

/** Tipo → marca → modelo en cascada, con los tipos agrupados por categoría.
 *  alCambiarTipo(idCategoria) se llama al elegir otro tipo. Termina cuando
 *  los modelos quedaron cargados. */
async function enlazarEquipo(form, base, valores = {}, bloqueado = false, alCambiarTipo = () => {}) {
  const selTipo = form.elements.namedItem("tipo_disp");
  const selMarca = form.elements.namedItem("id_marca");
  const selModelo = form.elements.namedItem("id_modelo");
  const opcion = (v, t, elegida) => `<option value="${esc(v)}"${elegida ? " selected" : ""}>${esc(t)}</option>`;
  selTipo.innerHTML = `<option value="">Seleccione…</option>${opcionesTiposHTML(base.tipos, base.categorias, valores.tipo_disp)}`;

  function llenarMarcas(preseleccion) {
    const tipo = Number(selTipo.value);
    const marcas = base.marcas.filter((m) => m.tipo_disp === tipo).sort((a, b) => a.descripcion.localeCompare(b.descripcion, "es"));
    const primera = !tipo ? "Elija primero el tipo" : marcas.length ? "Seleccione…" : "Este tipo no tiene marcas";
    selMarca.innerHTML = `<option value="">${primera}</option>${marcas.map((m) => opcion(m.id_marca, m.descripcion, m.id_marca === preseleccion)).join("")}`;
    selMarca.disabled = bloqueado || !marcas.length;
  }

  let pedido = 0;
  async function llenarModelos(preseleccion) {
    const marca = Number(selMarca.value);
    const este = ++pedido;
    selModelo.disabled = true;
    if (!marca) { selModelo.innerHTML = `<option value="">Elija primero la marca</option>`; return; }
    selModelo.innerHTML = `<option value="">Cargando…</option>`;
    let modelos;
    try {
      modelos = await modelosDe(marca);
    } catch {
      selModelo.innerHTML = `<option value="">No se pudieron cargar los modelos</option>`;
      return;
    }
    if (este !== pedido) return;
    selModelo.innerHTML = `<option value="">${modelos.length ? "Sin modelo" : "Esta marca no tiene modelos"}</option>${modelos.map((m) => opcion(m.id_modelo, m.descripcion, m.id_modelo === preseleccion)).join("")}`;
    selModelo.disabled = bloqueado || !modelos.length;
  }

  selTipo.addEventListener("change", () => { llenarMarcas(null); llenarModelos(null); alCambiarTipo(categoriaDe(base, selTipo.value)); });
  selMarca.addEventListener("change", () => llenarModelos(null));
  llenarMarcas(valores.id_marca ?? null);
  alCambiarTipo(categoriaDe(base, selTipo.value));
  await llenarModelos(valores.id_modelo ?? null);
}

/** Al elegir el funcionario responsable, el departamento se llena con el suyo si estaba vacío. */
function enlazarAsignacion(form, personal) {
  const persona = form.elements.namedItem("id_asignado");
  const depto = form.elements.namedItem("cod_departamento");
  persona?.addEventListener("change", () => {
    const u = personal.find((x) => String(x.id) === persona.value);
    if (u?.cod_departamento && depto && !depto.value) depto.value = String(u.cod_departamento);
  });
}

/** Formulario de un edificio (tabla edificios): nombre, provincia, cantón y
 *  distrito, otras señas y ubicación GPS. Lo usan la lista de edificios y el
 *  formulario del dispositivo. Devuelve el edificio guardado (o null si se
 *  cancela). */
const GEO_EDIFICIO = ["id_pais", "id_provincia", "id_canton", "id_distrito"];
export async function formularioEdificio(fila) {
  const r = await abrirFormulario({
    titulo: fila ? "Editar edificio" : "Agregar edificio",
    campos: [
      { nombre: "descripcion", etiqueta: "Nombre del edificio", requerido: true, max: 150, placeholder: "PALACIO MUNICIPAL" },
      ...GEO_EDIFICIO.map((nombre, i) => ({ nombre, etiqueta: NIVELES_GEO[i].titulo, tipo: "select" })),
      { nombre: "otras_senas", etiqueta: "Otras señas", tipo: "textarea", placeholder: "Opcional: dirección o referencias" },
      {
        nombre: "gps", etiqueta: "Ubicación GPS", max: 2000, mayus: false, placeholder: "10.0732, -84.3116",
        ayuda: "En Google Maps, haga clic derecho sobre el edificio y copie las coordenadas, o pegue el enlace del lugar. Todos los dispositivos del edificio toman esta ubicación.",
      },
    ],
    valores: fila || {},
    textoGuardar: fila ? "Guardar cambios" : "Agregar",
    alAbrir: (form) => {
      enlazarCampoMapa(form, "gps");
      // País → provincia → cantón → distrito (sin distrito no se guarda la dirección)
      cascadaGeo(GEO_EDIFICIO.map((n) => form.elements.namedItem(n)), {
        valores: Object.fromEntries(NIVELES_GEO.map((nivel, i) => [nivel.campo, fila?.[GEO_EDIFICIO[i]] || (i === 0 ? "CR" : null)])),
      });
    },
    alGuardar: (datos, form) => {
      if (!datos.id_distrito) for (const n of GEO_EDIFICIO) datos[n] = null;
      if (!validarMapaLocal(form, "gps")) throw new ErrorApi("", 400, { gps: "Escriba latitud y longitud separadas por coma (por ejemplo 10.0732, -84.3116) o pegue un enlace de Google Maps que las incluya." });
      return api(fila ? ruta(`${RECURSO}/edificios`, fila.id_predio) : `${RECURSO}/edificios/`, {
        metodo: fila ? "PUT" : "POST", datos,
      });
    },
  });
  if (r) olvidarCatalogo("edificios");
  return r;
}

let contadorFilas = 0;

/** Ubicación GPS del dispositivo: se llena sola, de solo lectura, con la del
 *  edificio elegido, y muestra su mapa. La GPS se pide en el edificio: un
 *  administrador la agrega o la cambia ahí mismo sin salir del formulario. */
function enlazarEdificio(form, edificios, esAdmin) {
  const select = form.elements.namedItem("id_predio");
  if (!select) return;
  const editable = esAdmin && !select.disabled;
  const campoSelect = select.closest(".campo");
  const n = ++contadorFilas;

  const gps = document.createElement("div");
  gps.className = "campo campo--completo campo-gps";
  gps.dataset.campo = "gps_edificio";
  gps.innerHTML = `
    <label for="gps-edificio-${n}">Ubicación GPS <span class="etiqueta-nota">(la del edificio)</span></label>
    <div class="campo-gps__fila">
      <input id="gps-edificio-${n}" class="dato-mono" readonly aria-describedby="gps-ayuda-${n}">
      <div class="campo-gps__acciones" data-gps-acciones></div>
    </div>
    <p class="ayuda" id="gps-ayuda-${n}" data-gps-ayuda></p>
    <div data-gps-mapa></div>`;
  campoSelect.parentElement.appendChild(gps);
  if (editable) {
    campoSelect.insertAdjacentHTML("beforeend",
      `<button type="button" class="enlace-mapa enlace-boton" data-nuevo-edificio>${icono("mas", "ic--sm")}<span>Nuevo edificio</span></button>`);
  }

  const input = gps.querySelector("input");
  const acciones = gps.querySelector("[data-gps-acciones]");
  const ayuda = gps.querySelector("[data-gps-ayuda]");
  const mapa = gps.querySelector("[data-gps-mapa]");
  let mapaActual = "";

  function actualizar() {
    const e = edificios.find((x) => String(x.id_predio) === select.value);
    const c = e && coordenadas(e.gps);
    input.value = c ? c.texto : "";
    input.placeholder = e ? "El edificio no tiene ubicación GPS" : "Se llena al elegir el edificio";
    acciones.innerHTML = `
      ${c ? `<a class="btn btn--secundario btn--sm" href="${esc(enlaceMaps(c))}" target="_blank" rel="noopener noreferrer">${icono("externo")}Google Maps</a>` : ""}
      ${e && editable ? `<button type="button" class="btn btn--fantasma btn--sm" data-editar-edificio>${icono(c ? "editar" : "punto")}${c ? "Cambiar en el edificio" : "Agregar GPS al edificio"}</button>` : ""}`;
    ayuda.textContent = !e ? "Elija el edificio: la ubicación GPS se toma de él."
      : c ? `Es la ubicación de ${e.descripcion}; la comparten todos sus dispositivos.`
        : `${e.descripcion} todavía no tiene ubicación GPS.${editable ? " Agréguela al edificio y quedará para todos sus dispositivos." : ""}`;
    const src = c ? embebidoMaps(c) : "";
    if (src !== mapaActual) {
      mapaActual = src;
      mapa.innerHTML = c ? `<iframe class="mapa mapa--formulario" title="Mapa de ${esc(e.descripcion)}" src="${esc(src)}" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>` : "";
    }
  }

  /** Vuelve a poner los edificios en la lista (con el nuevo o el cambiado). */
  function ponerOpciones() {
    const vacia = select.querySelector('option[value=""]');
    select.replaceChildren(...(vacia ? [vacia] : []));
    [...edificios].sort((a, b) => a.descripcion.localeCompare(b.descripcion, "es"))
      .forEach((e) => select.insertAdjacentHTML("beforeend", `<option value="${esc(e.id_predio)}">${esc(e.descripcion)}</option>`));
  }

  form.addEventListener("click", async (ev) => {
    const editar = ev.target.closest("[data-editar-edificio]");
    if (!editar && !ev.target.closest("[data-nuevo-edificio]")) return;
    const actual = editar ? edificios.find((x) => String(x.id_predio) === select.value) : null;
    const r = await formularioEdificio(actual);
    if (!r) return;
    const i = edificios.findIndex((x) => x.id_predio === r.id_predio);
    if (i >= 0) edificios[i] = { ...edificios[i], ...r };
    else edificios.push(r);
    ponerOpciones();
    select.value = String(r.id_predio);
    actualizar();
    toast(editar ? `Se guardó la ubicación de ${r.descripcion}.` : `Se agregó el edificio ${r.descripcion}.`);
  });
  select.addEventListener("change", actualizar);
  actualizar();
}

/* --------------------------------------- Direcciones IP y MAC del formulario */
/** Sección con varias IP y varias MAC. Se guardan con el botón del formulario. */
/** Una lista de filas (IP, MAC, líneas o IMEI) con su botón para agregar. */
function repetibleHTML(clave, soloLectura) {
  const def = DIRECCIONES[clave];
  return `
    <div class="repetible" data-repetible="${clave}">
      <p class="repetible__titulo">${icono(def.icono, "ic--sm")}${esc(def.titulo)}</p>
      <div class="repetible__filas"></div>
      <p class="repetible__vacio" data-vacio hidden>Sin ${esc(def.plural)}.</p>
      ${soloLectura ? "" : `<div><button type="button" class="btn btn--fantasma btn--sm" data-agregar-dir="${clave}">${icono("mas")}Agregar ${def.otra} ${def.corto}</button></div>`}
    </div>`;
}

const seccionDireccionesHTML = (soloLectura) => `
  <section class="seccion-form" data-seccion-direcciones>
    <h3>${icono("web")}Direcciones de red</h3>
    <p>${soloLectura ? "Direcciones IP y MAC del equipo."
    : "Puede agregar varias IP y varias MAC; las filas vacías no se guardan. La MAC se escribe con o sin separadores, se guarda entera y se muestra como AA-BB-CC-DD-EE-FF."}</p>
    ${Object.keys(DIRECCIONES).filter((clave) => !DIRECCIONES[clave].seccion).map((clave) => repetibleHTML(clave, soloLectura)).join("")}
  </section>`;

function filaDireccion(clave, valores = {}, soloLectura = false) {
  const def = DIRECCIONES[clave];
  const n = ++contadorFilas;
  const fila = document.createElement("div");
  fila.className = "repetible__fila repetible__fila--direccion";
  if (valores.num_linea) fila.dataset.numLinea = valores.num_linea;
  const valor = valores[def.campo] ? def.mostrar(valores[def.campo]) : "";
  const bloqueo = soloLectura ? " disabled" : "";
  const seg = def.segundo;
  if (!seg) fila.classList.add("repetible__fila--uno");
  fila.innerHTML = `
    <div class="campo" data-campo="${clave}-${n}"><label for="${clave}-dir-${n}">${esc(def.etiqueta)}</label>
      <input id="${clave}-dir-${n}" data-k="${def.campo}" value="${esc(valor)}" maxlength="${def.max}" placeholder="${soloLectura ? "" : esc(def.placeholder)}" class="dato-mono${def.mayus ? " mayus" : ""}" autocomplete="off" spellcheck="false"${clave === "moviles" ? ' inputmode="tel"' : clave === "imeis" ? ' inputmode="numeric"' : ""}${bloqueo}><p class="error-campo" hidden></p></div>
    ${seg ? `<div class="campo"><label for="${clave}-seg-${n}">${esc(seg.etiqueta)}</label>
      <input id="${clave}-seg-${n}" data-k="${seg.campo}" value="${esc(valores[seg.campo] || "")}" maxlength="${seg.max}" placeholder="${soloLectura ? "" : esc(seg.placeholder)}" class="mayus" autocomplete="off"${bloqueo}></div>` : ""}
    ${soloLectura ? "" : `<button type="button" class="btn-icono btn-icono--peligro" data-quitar-dir aria-label="Quitar ${def.esta.toLowerCase()} ${esc(def.singular)}">${icono("cerrar")}</button>`}`;
  return fila;
}

/** Pone las IP y MAC en el formulario. Sin direcciones: una fila vacía para escribir. */
function pintarDirecciones(form, valores, soloLectura) {
  for (const clave of Object.keys(DIRECCIONES)) {
    const caja = form.querySelector(`[data-repetible="${clave}"]`);
    if (!caja) continue;
    const filas = caja.querySelector(".repetible__filas");
    filas.replaceChildren(...(valores[clave] || []).map((v) => filaDireccion(clave, v, soloLectura)));
    if (!soloLectura && !filas.children.length) filas.appendChild(filaDireccion(clave));
    caja.querySelector("[data-vacio]").hidden = filas.children.length > 0;
  }
}

function enlazarDirecciones(form) {
  form.addEventListener("click", (ev) => {
    const agregar = ev.target.closest("[data-agregar-dir]");
    if (agregar) {
      const clave = agregar.dataset.agregarDir;
      const filas = form.querySelector(`[data-repetible="${clave}"] .repetible__filas`);
      if (filas.children.length >= MAX_DIRECCIONES) {
        toast(`Un equipo puede tener hasta ${MAX_DIRECCIONES} ${DIRECCIONES[clave].plural}.`, "error");
        return;
      }
      const fila = filaDireccion(clave);
      filas.appendChild(fila);
      fila.querySelector("input").focus();
      return;
    }
    const quitar = ev.target.closest("[data-quitar-dir]");
    if (quitar) quitar.closest(".repetible__fila").remove();
  });
  form.addEventListener("input", (ev) => {
    const campo = ev.target.closest?.("[data-repetible] .campo.con-error");
    if (!campo) return;
    campo.classList.remove("con-error");
    const p = campo.querySelector(".error-campo");
    if (p) { p.hidden = true; p.textContent = ""; }
  });
  // La MAC se ve con guiones apenas se termina de escribir
  form.addEventListener("focusout", (ev) => {
    const input = ev.target.closest?.('[data-k="direccion_mac"]');
    if (input && macValida(input.value)) input.value = formatearMac(input.value);
  });
}

/** Lee y revisa las filas de IP, MAC, líneas e IMEI (las vacías se ignoran).
 *  Devuelve { datos: {ips, macs, moviles, imeis}, filas: {...}, errores }
 *  donde filas son los elementos en el mismo orden que datos, para ubicar
 *  los errores. Las listas que no están en el formulario no se mandan. */
function leerDirecciones(form) {
  const datos = {};
  const filas = {};
  const errores = {};
  for (const [clave, def] of Object.entries(DIRECCIONES)) {
    if (!form.querySelector(`[data-repetible="${clave}"]`)) continue;
    datos[clave] = [];
    filas[clave] = [];
    const vistas = new Set();
    form.querySelectorAll(`[data-repetible="${clave}"] .repetible__fila`).forEach((fila) => {
      const input = fila.querySelector(`[data-k="${def.campo}"]`);
      const campo = input.closest(".campo").dataset.campo;
      const valor = input.value.trim();
      const segundo = def.segundo ? fila.querySelector(`[data-k="${def.segundo.campo}"]`).value.trim().toUpperCase() : "";
      if (!valor && !segundo) return;
      if (!valor) { errores[campo] = `Escriba ${def.la} ${def.singular} o quite la fila.`; return; }
      if (!def.valida(valor)) { errores[campo] = def.mensaje; return; }
      const llave = def.normalizar(valor);
      if (vistas.has(llave)) { errores[campo] = `${def.esta} ${def.singular} ya está en la lista.`; return; }
      vistas.add(llave);
      const item = { [def.campo]: valor };
      if (def.segundo) item[def.segundo.campo] = segundo || null;
      if (fila.dataset.numLinea) item.num_linea = Number(fila.dataset.numLinea);
      datos[clave].push(item);
      filas[clave].push(fila);
    });
  }
  return { datos, filas, errores };
}

/** Errores del servidor en las IP y MAC, en la fila que corresponde: los de
 *  cada fila (validación de Django) o el mensaje de la base que nombra la
 *  dirección ("La dirección MAC AA-BB-… ya está registrada…"). */
function erroresDirecciones(e, filas) {
  const campos = {};
  const texto = `${e.message || ""} ${e.db || ""}`.toUpperCase();
  for (const [clave, def] of Object.entries(DIRECCIONES)) {
    if (!filas[clave]) continue;
    const campoDe = (fila) => fila.querySelector(".campo[data-campo]").dataset.campo;
    const porFila = e.cuerpo?.[clave];
    if (Array.isArray(porFila)) {
      porFila.forEach((err, i) => {
        if (err && typeof err === "object" && filas[clave][i]) {
          const msg = Object.values(err).flat().join(" ");
          if (msg) campos[campoDe(filas[clave][i])] = msg;
        }
      });
    }
    for (const fila of filas[clave]) {
      const v = def.normalizar(fila.querySelector(`[data-k="${def.campo}"]`).value);
      if (!v) continue;
      const nombrada = texto.includes(def.mostrar(v).toUpperCase()) || (clave === "macs" && texto.includes(v));
      if (nombrada && !campos[campoDe(fila)]) {
        campos[campoDe(fila)] = e.estado === 409 ? REPETIDO[clave] : e.message;
      }
    }
  }
  return campos;
}

// Mensaje cuando la base dice que el valor ya existe (409)
const REPETIDO = {
  ips: "Esa dirección IP está repetida.",
  macs: "Esa dirección MAC ya está registrada en otro dispositivo.",
  moviles: "Esa línea está repetida.",
  imeis: "Ese IMEI ya está registrado en otro equipo.",
};

/** El servidor devuelve las IP, MAC, líneas e IMEI que quedaron guardadas.
 *  Si no coinciden con las que se mandaron, el backend o la base no son de
 *  esta versión. */
function direccionesNoGuardadas(respuesta, datos) {
  const faltan = Object.entries(DIRECCIONES)
    .filter(([clave]) => datos[clave] && String(respuesta?.[clave] || "").length < 1000
      && lista(respuesta?.[clave]).length !== datos[clave].length)
    .map(([, def]) => def.plural);
  return faltan.length
    ? `El servidor no guardó ${faltan.join(" ni ")}. Copie de nuevo apps/dispositivos (serializers.py y views.py), ejecute bash reinstalar_base.sh y reinicie Django.`
    : "";
}

/** Muestra un error del servidor al guardar el dispositivo. */
function mostrarErrorDispositivo(form, e, caja, filas) {
  const enDirecciones = erroresDirecciones(e, filas);
  if (Object.keys(enDirecciones).length) mostrarErrores(form, new ErrorApi(e.message, e.estado, enDirecciones), caja);
  else mostrarErrores(form, precisarError(e), caja);
  caja.scrollIntoView({ behavior: "smooth", block: "center" });
}

/** Mínimo, máximo y paso de cada número (decimales solo en las pulgadas). */
function prepararNumeros(form, campos) {
  for (const c of campos) {
    if (c.tipo !== "number") continue;
    const input = form.elements.namedItem(c.nombre);
    if (!input) continue;
    input.min = String(c.minimo ?? 0);
    input.max = String(c.maximo ?? 9999);
    input.step = c.paso || "1";
    input.inputMode = c.paso ? "decimal" : "numeric";
  }
}

/** Tipo de equipo que corresponde a una sugerencia (IMPRESORA, COMPUTADORA…), si hay uno solo claro. */
function tipoSugerido(tipos, texto) {
  const buscado = normalizar(texto);
  if (!buscado) return null;
  return tipos.find((t) => normalizar(t.descripcion) === buscado)
    || [...tipos].sort((a, b) => a.descripcion.length - b.descripcion.length).find((t) => normalizar(t.descripcion).includes(buscado))
    || null;
}

/* «Registrar uno igual»: lo que se copia de otro equipo. No se copia lo que
   es de cada equipo: serie, placa, nombre en la red, IMEI, líneas,
   extensión, responsable, estado, IP, MAC, documentos ni observaciones. */
const CAMPOS_COPIA = [
  "tipo_disp", "id_marca", "id_modelo", "id_os", "id_firmw", "id_proces", "memoria_gb", "almacenamiento_gb", "tipo_almacenamiento",
  "pulgadas", "resolucion", "cant_ptos_serie", "cant_ptos_usb", "cant_ptos_ethernet", "cant_ptos_sfp", "cant_ptos_wireless",
  "cant_ptos_bluetooth", "cant_ptos_celular", "sfp_combo", "canales", "tecnologia_impresion", "a_color", "consumible",
  "herramientas", "roles",
  "capacidad_va", "autonomia_min", "id_predio", "ubicacion", "cod_departamento", "id_proveedor", "fecha_compra", "garantia_hasta",
];

function datosCopia(origen, proveedores) {
  const v = Object.fromEntries(CAMPOS_COPIA.filter((c) => origen[c] !== null && origen[c] !== undefined).map((c) => [c, origen[c]]));
  // A un equipo nuevo no se le pone un proveedor inactivo
  if (v.id_proveedor && !proveedores.some((p) => p.id === v.id_proveedor)) delete v.id_proveedor;
  return v;
}

/* =====================================================================
   Nuevo dispositivo
   ===================================================================== */
export async function vistaDispositivoNuevo(cont, _params, ctx) {
  ctx.migas([{ texto: "Equipos", href: "#/red/dispositivos" }, { texto: "Nuevo equipo" }]);
  cont.innerHTML = cargandoHTML();

  // Desde los logs (equipos sin agente, intrusos del DHCP):
  // #/red/dispositivos/nuevo?ip=&mac=&equipo=&tipo= trae la IP, la MAC, el
  // nombre en la red y el tipo que parece; desde la ficha de una persona, ?asignado=;
  // desde la ficha de otro equipo («Registrar uno igual»), ?copiar=<id_disp>
  const q = ctx.query || new URLSearchParams();
  const idCopia = /^\d+$/.test(q.get("copiar") || "") ? q.get("copiar") : null;
  const [base, proveedores, tiposDoc, personal, copia] = await Promise.all([
    datosBase(), api("proveedores/", { query: { activo: true } }), filasCatalogo("tipos-documentos"),
    api("usuarios/", { query: { activo: true } }),
    idCopia ? api(ruta(RECURSO, idCopia)).catch((e) => { if (e instanceof ErrorApi) return { error: e.message }; throw e; }) : null,
  ]);
  if (!ctx.vigente()) return;

  const copiados = copia && !copia.error ? datosCopia(copia, proveedores) : {};
  const previas = {
    ips: q.get("ip") ? [{ direccion_ip: q.get("ip") }] : [],
    macs: q.get("mac") ? [{ direccion_mac: q.get("mac") }] : [],
    moviles: [],
    imeis: [],
  };
  const deListado = q.get("equipo");
  const sugerido = tipoSugerido(base.tipos, q.get("tipo"));
  const asignado = personal.find((u) => String(u.id) === q.get("asignado"));
  const valores = {
    id_os: base.sistemas.some((s) => s.id_os === 1) ? 1 : undefined,
    id_firmw: 1,      // N/D
    ...copiados,
    id_estado: 2,     // ACTIVO
    nombre_equipo: deListado ? deListado.split(".")[0].toUpperCase() : undefined,
    tipo_disp: sugerido?.tipo_disp ?? copiados.tipo_disp,
    id_asignado: asignado?.id,
    cod_departamento: asignado?.cod_departamento || copiados.cod_departamento || undefined,
  };
  const secciones = seccionesDispositivo(base, proveedores, personal, valores);
  const opcionesDoc = [...tiposDoc].sort((a, b) => a.id_doc - b.id_doc)
    .map((t) => `<option value="${t.id_doc}">${esc(t.descripcion)}</option>`).join("");

  cont.innerHTML = `
    <a class="volver" href="#/red/dispositivos">${icono("atras")}Volver a equipos</a>
    <div class="encabezado"><div><h1>Nuevo equipo</h1><p>Los campos con * son obligatorios. Al elegir el tipo aparecen los datos que lleva ese equipo.</p></div></div>
    ${deListado ? `<div class="aviso aviso--info">${icono("enlace")}<span>${previas.ips.length || previas.macs.length ? "El nombre en la red, la IP y la MAC vienen" : "El nombre en la red viene"} del equipo
      <strong>${esc(deListado)}</strong> de los logs${sugerido ? ` (tipo sugerido: ${esc(sugerido.descripcion)})` : ""}. Revise el tipo y complete la marca y la serie.</span></div>` : ""}
    ${asignado ? `<div class="aviso aviso--info">${icono("usuario")}<span>El equipo queda asignado a <strong>${esc(nombreCompleto(asignado))}</strong>.</span></div>` : ""}
    ${copia && !copia.error ? `<div class="aviso aviso--info" data-aviso-copia>${icono("capas")}<span>Se copiaron los datos de
      <a href="#/red/dispositivos/${copia.id_disp}">${esc(tituloDispositivo(copia))} (serie ${esc(copia.serie)})</a>: tipo, marca, modelo, características,
      ubicación, departamento, proveedor y fechas. Escriba la serie, la placa y el nombre en la red de este equipo; el responsable, las IP y las MAC
      son de cada equipo y no se copian.</span></div>` : ""}
    ${copia?.error ? `<div class="aviso aviso--ocre">${icono("alerta")}<span>No se pudieron copiar los datos del equipo N.º ${esc(idCopia)}: ${esc(copia.error)}</span></div>` : ""}
    <form class="panel" id="form-dispositivo" novalidate>
      <div class="panel__cuerpo">
        <div data-error hidden style="margin-bottom:18px"></div>
        ${formularioEquipoHTML(secciones, valores, false)}
        <section class="seccion-form">
          <h3>${icono("documento")}Documentos</h3>
          <p>Opcional. Manuales, imagen, firmware, respaldos, configuración, facturas o actas de entrega, hasta ${MAX_MB_DOCUMENTO / 1024} GB cada uno. También se pueden subir después desde la ficha.</p>
          <div class="repetible" data-repetible="documentos">
            <div class="repetible__filas"></div>
            <div><button type="button" class="btn btn--fantasma btn--sm" data-agregar-doc>${icono("mas")}Agregar documento</button></div>
          </div>
        </section>
      </div>
      <div class="panel__pie">
        <span class="progreso-texto" data-progreso aria-live="polite"></span>
        <a class="btn btn--secundario" href="#/red/dispositivos">Cancelar</a>
        <button class="btn btn--primario" type="submit">${icono("check")}Registrar equipo</button>
      </div>
    </form>`;

  const form = cont.querySelector("#form-dispositivo");
  const caja = form.querySelector("[data-error]");
  const campos = todosLosCampos(secciones);
  const filasDoc = form.querySelector('[data-repetible="documentos"] .repetible__filas');
  let categoria = null;
  prepararNumeros(form, campos);
  enlazarEdificio(form, base.edificios, ctx.esAdmin);
  enlazarAsignacion(form, personal);
  pintarDirecciones(form, previas, false);
  enlazarDirecciones(form);
  // Switches: botones de tamaño y vista previa del frente
  const diseno = enlazarDisenoSwitch(form);
  await enlazarEquipo(form, base, valores, false, (cat) => { categoria = cat; aplicarCategoria(form, secciones, cat, false); diseno.categoria(cat); });

  let contador = 0;
  form.addEventListener("click", (ev) => {
    if (ev.target.closest("[data-agregar-doc]")) {
      contador += 1;
      const fila = document.createElement("div");
      fila.className = "repetible__fila repetible__fila--2";
      fila.innerHTML = `
        <div class="campo"><label for="doc-tipo-${contador}">Tipo</label><select id="doc-tipo-${contador}" data-k="id_doc" required><option value="">Seleccione…</option>${opcionesDoc}</select></div>
        <div class="campo" data-campo="doc-${contador}"><label for="doc-archivo-${contador}">Archivo</label><input id="doc-archivo-${contador}" data-k="archivo" type="file" class="control-archivo" required><p class="error-campo" hidden></p></div>
        <button type="button" class="btn-icono btn-icono--peligro" data-quitar-doc aria-label="Quitar documento">${icono("cerrar")}</button>`;
      filasDoc.appendChild(fila);
      fila.querySelector("select").focus();
    }
    const quitar = ev.target.closest("[data-quitar-doc]");
    if (quitar) quitar.closest(".repetible__fila").remove();
  });

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity()) return;

    // Revisa las direcciones y los archivos antes de crear nada
    const direcciones = leerDirecciones(form);
    const documentos = [];
    const erroresArchivo = { ...direcciones.errores };
    filasDoc.querySelectorAll(".repetible__fila").forEach((fila) => {
      const input = fila.querySelector('[data-k="archivo"]');
      const problema = validarArchivo(input.files[0]);
      if (problema) erroresArchivo[input.closest(".campo").dataset.campo] = problema;
      else documentos.push({ id_doc: fila.querySelector('[data-k="id_doc"]').value, archivo: input.files[0] });
    });
    if (Object.keys(erroresArchivo).length) {
      mostrarErrores(form, new ErrorApi("", 400, erroresArchivo), caja);
      return;
    }

    const boton = form.querySelector("[type=submit]");
    const progreso = form.querySelector("[data-progreso]");
    botonCargando(boton, true);
    let creado;
    try {
      // El dispositivo, sus IP y sus MAC se guardan juntos (todo o nada)
      creado = await api(`${RECURSO}/`, { metodo: "POST", datos: { ...leerEquipo(form, campos, categoria), ...direcciones.datos } });
    } catch (e) {
      botonCargando(boton, false);
      if (!(e instanceof ErrorApi)) throw e;
      mostrarErrorDispositivo(form, e, caja, direcciones.filas);
      return;
    }

    const fallos = [];
    const sinDirecciones = direccionesNoGuardadas(creado, direcciones.datos);
    if (sinDirecciones) fallos.push(sinDirecciones);
    for (const [i, doc] of documentos.entries()) {
      const datos = new FormData();
      datos.append("id_doc", doc.id_doc);
      datos.append("archivo", doc.archivo);
      try {
        await apiSubir(ruta(RECURSO, creado.id_disp, "documentos"), datos, {
          alProgreso: (p) => { progreso.textContent = `Subiendo documento ${i + 1} de ${documentos.length}: ${Math.round(p * 100)} %`; },
        });
      } catch (e) {
        fallos.push(`${doc.archivo.name}: ${e.message}`);
      }
    }

    toast(`Se registró el equipo ${tituloDispositivo(creado)} (serie ${creado.serie}).`);
    if (fallos.length) toast(`Algunos datos no se guardaron. ${fallos.join(" ")}`, "error");
    location.hash = `#/red/dispositivos/${creado.id_disp}${documentos.length && !sinDirecciones ? "/documentos" : ""}`;
  });
}

/* =====================================================================
   Ficha del dispositivo
   ===================================================================== */
const PESTANAS = [
  { clave: "datos", titulo: "Datos generales", icono: "red" },
  { clave: "documentos", titulo: "Documentos", icono: "documento" },
  // Switches y demás equipos de red con puertos: qué está conectado a cada uno
  { clave: "puertos", titulo: "Puertos", icono: "switch", si: tienePuertos },
  // Lo importado en el módulo de logs (solo administradores, como ese módulo)
  { clave: "en-la-red", titulo: "En la red", icono: "web", soloAdmin: true },
  { clave: "historial", titulo: "Historial", icono: "historial", soloAdmin: true },
];

export async function vistaDispositivo(cont, [id, pestanaInicial], ctx) {
  ctx.migas([{ texto: "Equipos", href: "#/red/dispositivos" }]);
  cont.innerHTML = cargandoHTML();

  const d = await api(ruta(RECURSO, id));
  if (!ctx.vigente()) return;
  const titulo = tituloDispositivo(d);
  ctx.migas([{ texto: "Equipos", href: "#/red/dispositivos" }, { texto: `${titulo} · ${d.serie}` }]);

  const base = `#/red/dispositivos/${d.id_disp}`;
  const pestanas = PESTANAS.filter((t) => (!t.soloAdmin || ctx.esAdmin) && (!t.si || t.si(d)));
  let actual = pestanas.find((t) => t.clave === pestanaInicial)?.clave || "datos";
  const recargar = (pestana = actual) => vistaDispositivo(cont, [String(d.id_disp), pestana], ctx);
  const marca = marcaAparte(d);

  cont.innerHTML = `
    <a class="volver" href="#/red/dispositivos">${icono("atras")}Volver a equipos</a>
    <div class="ficha">
      ${insigniaTipo(d, "grande")}
      <div class="ficha__texto">
        <h1>${esc(titulo)}</h1>
        <div class="ficha__datos">
          ${pastillaEstado(d.activo)}
          ${d.activo ? pastillaGarantia(d) : ""}
          ${[CAT.COMPUTO, CAT.SERVIDOR].includes(d.id_categoria) || d.tiene_microclaudia
            ? `<span class="pastilla pastilla--sin-punto ${d.tiene_microclaudia ? "pastilla--agente" : "pastilla--inactivo"}" title="Herramienta MICROCLAUDIA (se marca en Datos generales, Herramientas y roles)">${icono(d.tiene_microclaudia ? "check" : "agente", "ic--sm")}${d.tiene_microclaudia ? "Con Microclaudia" : "Sin Microclaudia"}</span>` : ""}
          ${d.id_estado === 1 ? `<span class="pastilla pastilla--sin-punto pastilla--inactivo" title="Estado del equipo">Estado N/D</span>` : ""}
          <span>${esc(d.tipo_dispositivo)}${marca ? ` · ${esc(marca)}` : ""}</span>
          <span class="dato-mono">Serie ${esc(d.serie)}</span>
          ${d.placa ? `<span class="dato-mono" title="Placa (número de activo)">Placa ${esc(d.placa)}</span>` : ""}
          ${d.nombre_equipo ? `<span class="ficha__dato-icono dato-mono" title="Nombre en la red">${icono("red", "ic--sm")}${esc(d.nombre_equipo)}</span>` : ""}
          ${d.asignado ? `<a class="ficha__dato-icono" href="#/usuarios/${d.id_asignado}" title="Funcionario responsable">${icono("usuario", "ic--sm")}${esc(d.asignado)}</a>` : ""}
          ${d.edificio ? `<span class="ficha__dato-icono">${icono("edificio", "ic--sm")}${esc(d.edificio)}</span>` : ""}
          ${d.ips ? `<span class="ficha__dato-icono dato-mono" title="Direcciones IP">${icono("web", "ic--sm")}${resumenDirecciones(d.ips)}</span>` : ""}
          ${d.macs ? `<span class="ficha__dato-icono dato-mono" title="Direcciones MAC">${icono("puertos", "ic--sm")}${resumenDirecciones(d.macs, formatearMac)}</span>` : ""}
          <span class="ficha__conexiones" data-conexiones></span>
        </div>
      </div>
      <div class="ficha__acciones">
        ${ctx.esAdmin ? `<a class="btn btn--secundario" href="#/red/dispositivos/nuevo?copiar=${d.id_disp}" data-copiar
          title="Abre el formulario de un equipo nuevo con los datos de este: tipo, marca, modelo, características, ubicación, proveedor y fechas">${icono("capas")}Registrar uno igual</a>` : ""}
        ${ctx.esAdmin ? (d.activo
          ? `<button type="button" class="btn btn--secundario" data-estado>${icono("encender")}Desactivar</button>`
          : `<button type="button" class="btn btn--primario" data-estado>${icono("encender")}Activar</button>`) : ""}
      </div>
    </div>
    <div class="pestanas" role="tablist" aria-label="Información del equipo">
      ${pestanas.map((t) => `<button type="button" role="tab" id="tab-${t.clave}" aria-controls="panel-pestana" data-pestana="${t.clave}" aria-selected="${t.clave === actual}">${icono(t.icono)}${esc(t.titulo)}${t.clave === "documentos" ? `<span class="contador">${d.cantidad_documentos || 0}</span>` : ""}</button>`).join("")}
    </div>
    <div id="panel-pestana" role="tabpanel"></div>`;

  cont.querySelector("[data-estado]")?.addEventListener("click", () => cambiarEstado(d, () => recargar()));
  // A qué switch y puerto está conectado (si se registró en la pestaña Puertos del switch)
  conexionesHTML(d.id_disp).then((html) => {
    const caja = cont.querySelector("[data-conexiones]");
    if (caja && ctx.vigente()) caja.innerHTML = html;
  }).catch(() => {});

  const panel = cont.querySelector("#panel-pestana");
  async function mostrar(clave) {
    actual = clave;
    cont.querySelectorAll("[data-pestana]").forEach((b) => b.setAttribute("aria-selected", String(b.dataset.pestana === clave)));
    // En el celular las pestañas no caben: se corre la tira para que se vea la elegida
    const tira = cont.querySelector("[role=tablist]");
    const elegida = tira?.querySelector(`[data-pestana="${clave}"]`);
    if (elegida && tira.scrollWidth > tira.clientWidth) {
      const r = elegida.getBoundingClientRect();
      const rt = tira.getBoundingClientRect();
      if (r.left < rt.left || r.right > rt.right) tira.scrollLeft += r.left + r.width / 2 - (rt.left + rt.width / 2);
    }
    panel.setAttribute("aria-labelledby", `tab-${clave}`);
    history.replaceState(null, "", clave === "datos" ? base : `${base}/${clave}`);
    const caja = document.createElement("div");
    caja.innerHTML = cargandoHTML();
    panel.replaceChildren(caja);
    try {
      if (clave === "datos") await pestanaDatos(caja, d, ctx, recargar);
      else if (clave === "documentos") await pestanaDocumentos(caja, d, ctx, recargar);
      else if (clave === "puertos") await pestanaPuertos(caja, d, ctx);
      else if (clave === "en-la-red") await pestanaEnLaRed(caja, d, ctx, recargar);
      else if (clave === "historial") await pestanaHistorial(caja, d);
    } catch (e) {
      if (!ctx.vigente()) return;
      caja.innerHTML = errorHTML(e instanceof ErrorApi ? e.message : "No se pudo mostrar esta sección.");
      if (!(e instanceof ErrorApi)) console.error(e);
    }
  }

  const tabs = cont.querySelector("[role=tablist]");
  tabs.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-pestana]");
    if (b && b.dataset.pestana !== actual) mostrar(b.dataset.pestana);
  });
  tabs.addEventListener("keydown", (ev) => {
    if (!["ArrowLeft", "ArrowRight"].includes(ev.key)) return;
    const botones = [...tabs.querySelectorAll("[data-pestana]")];
    const i = botones.findIndex((b) => b.dataset.pestana === actual);
    const sig = botones[(i + (ev.key === "ArrowRight" ? 1 : -1) + botones.length) % botones.length];
    sig.focus();
    mostrar(sig.dataset.pestana);
  });

  await mostrar(actual);
}

async function cambiarEstado(d, alTerminar) {
  const nombre = `${tituloDispositivo(d)} (serie ${d.serie})`;
  if (d.activo) {
    const ok = await confirmar({
      titulo: "Desactivar dispositivo",
      mensaje: `${nombre} dejará de aparecer entre los dispositivos activos. Sus datos y documentos se conservan y se puede activar de nuevo.`,
      textoBoton: "Desactivar",
      accion: () => api(ruta(RECURSO, d.id_disp), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se desactivó ${nombre}.`); alTerminar(); }
    return;
  }
  try {
    await api(ruta(RECURSO, d.id_disp, "activar"), { metodo: "POST" });
    toast(`Se activó ${nombre}.`);
    alTerminar();
  } catch (e) {
    toast(e.message, "error");
  }
}

/* --------------------------------------------------------- Datos generales */
async function pestanaDatos(panel, d, ctx, recargar) {
  const [base, proveedores, ips, macs, moviles, imeis, personal] = await Promise.all([
    datosBase(), api("proveedores/", { query: { activo: true } }),
    api(ruta(RECURSO, d.id_disp, "ips")), api(ruta(RECURSO, d.id_disp, "macs")),
    api(ruta(RECURSO, d.id_disp, "moviles")), api(ruta(RECURSO, d.id_disp, "imeis")),
    api("usuarios/", { query: { activo: true } }),
  ]);
  const secciones = seccionesDispositivo(base, proveedores, personal, d);
  const soloLectura = !ctx.esAdmin;
  const campos = todosLosCampos(secciones);

  panel.innerHTML = `
    <form class="panel" novalidate>
      <div class="panel__cuerpo">
        ${soloLectura ? `<div class="aviso aviso--ocre" style="margin-bottom:18px">${icono("candado")}<span>Solo un administrador puede modificar estos datos.</span></div>` : ""}
        <div data-error hidden style="margin-bottom:18px"></div>
        ${formularioEquipoHTML(secciones, d, soloLectura)}
        <section class="seccion-form">
          <h3>${icono("etiqueta")}Registro</h3>
          <dl class="lista-datos">
            <div><dt>Registrado</dt><dd>${esc(fecha(d.creado_en))}</dd></div>
            <div><dt>Última modificación</dt><dd>${esc(fecha(d.actualizado_en))}</dd></div>
          </dl>
        </section>
      </div>
      ${soloLectura ? "" : `<div class="panel__pie"><button type="submit" class="btn btn--primario">${icono("check")}Guardar cambios</button></div>`}
    </form>
    ${ctx.esAdmin ? `
    <section class="panel zona-riesgo">
      <div class="panel__cabeza"><h2>Acciones sobre el equipo</h2></div>
      <div class="fila-riesgo">
        <div><strong>Eliminar definitivamente</strong>
          <p>Borra el equipo con sus direcciones IP y MAC, sus líneas, IMEI, roles, herramientas, documentos y archivos. No se puede deshacer. Si solo se retiró de servicio, use Desactivar.</p></div>
        <button type="button" class="btn btn--peligro-suave" data-eliminar>${icono("borrar")}Eliminar equipo</button>
      </div>
    </section>` : ""}`;

  const form = panel.querySelector("form");
  const caja = form.querySelector("[data-error]");
  let categoria = d.id_categoria || null;
  prepararNumeros(form, campos);
  enlazarEdificio(form, base.edificios, ctx.esAdmin);
  if (!soloLectura) enlazarAsignacion(form, personal);
  pintarDirecciones(form, { ips, macs, moviles, imeis }, soloLectura);
  if (!soloLectura) enlazarDirecciones(form);
  const diseno = enlazarDisenoSwitch(form, { soloLectura });
  await enlazarEquipo(form, base, d, soloLectura, (cat) => { categoria = cat; aplicarCategoria(form, secciones, cat, soloLectura); diseno.categoria(cat); });

  // Enlace a la ficha del proveedor (módulo de usuarios y proveedores)
  if (d.id_proveedor) {
    const campoProv = form.querySelector('[data-campo="id_proveedor"]');
    campoProv?.insertAdjacentHTML("beforeend", `<a class="enlace-mapa" href="#/proveedores/${d.id_proveedor}">${icono("proveedor", "ic--sm")}<span>Ver ficha de ${esc(d.proveedor || "el proveedor")}</span></a>`);
  }

  panel.querySelector("[data-eliminar]")?.addEventListener("click", async () => {
    const nombre = `${tituloDispositivo(d)} (serie ${d.serie})`;
    const ok = await confirmar({
      titulo: "Eliminar dispositivo definitivamente",
      mensaje: `Se borrarán ${nombre} y sus ${d.cantidad_documentos || 0} documentos. Si solo se retiró de servicio, use Desactivar.`,
      textoBoton: "Eliminar definitivamente",
      accion: () => api(ruta(RECURSO, d.id_disp, "eliminar-fisico"), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se eliminó ${nombre}.`); location.hash = "#/red/dispositivos"; }
  });

  if (soloLectura) return;

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity()) return;
    const direcciones = leerDirecciones(form);
    if (Object.keys(direcciones.errores).length) {
      mostrarErrores(form, new ErrorApi("", 400, direcciones.errores), caja);
      return;
    }
    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    let r;
    try {
      // Los datos, las IP y las MAC se guardan juntos (todo o nada)
      r = await api(ruta(RECURSO, d.id_disp), { metodo: "PUT", datos: { ...leerEquipo(form, campos, categoria), ...direcciones.datos } });
    } catch (e) {
      botonCargando(boton, false);
      if (!(e instanceof ErrorApi)) throw e;
      mostrarErrorDispositivo(form, e, caja, direcciones.filas);
      return;
    }
    const sinDirecciones = direccionesNoGuardadas(r, direcciones.datos);
    if (sinDirecciones) {
      botonCargando(boton, false);
      mostrarErrores(form, new ErrorApi(sinDirecciones, 500), caja);
      caja.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }
    toast("Se guardaron los cambios.");
    recargar("datos");
  });
}

async function descargar(d, doc) {
  const blob = await api(ruta(RECURSO, d.id_disp, "documentos", doc.num_linea, "archivo"), { comoArchivo: true });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = doc.nombre_archivo;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}

function verDocumento(d, doc) {
  abrirVistaPrevia({
    titulo: doc.tipo_documento,
    nombre: doc.nombre_archivo,
    obtener: () => api(ruta(RECURSO, d.id_disp, "documentos", doc.num_linea, "vista-previa"), { comoArchivo: true }),
    alDescargar: () => descargar(d, doc).catch((e) => toast(e.message, "error")),
  });
}

async function pestanaDocumentos(panel, d, ctx, recargar) {
  const admin = ctx.esAdmin;
  const [docs, tiposCatalogo] = await Promise.all([
    api(ruta(RECURSO, d.id_disp, "documentos")), filasCatalogo("tipos-documentos"),
  ]);
  const tipos = [...tiposCatalogo].sort((a, b) => a.id_doc - b.id_doc);

  const filaDoc = (doc) => `
    <li class="doc-red" data-num="${doc.num_linea}">
      ${doc.es_imagen && doc.imagen_url
        ? `<button type="button" class="doc-red__vista doc-red__vista--imagen" data-visor aria-label="Ver ${esc(doc.nombre_archivo)}"><img src="${esc(urlApi(doc.imagen_url))}" alt="" loading="lazy"></button>`
        : `<span class="doc-red__vista" aria-hidden="true">${icono("documento")}<span>${esc((doc.extension || "archivo").slice(0, 5).toUpperCase())}</span></span>`}
      <div class="doc-red__texto">
        <strong>${esc(doc.nombre_archivo)}</strong>
        <span class="secundario">${esc([tamanoLegible(doc.tamano), `Subido ${fecha(doc.creado_en)}`].filter(Boolean).join(" · "))}</span>
      </div>
      <div class="doc-red__acciones">
        ${doc.tiene_vista_previa ? `<button type="button" class="btn btn--secundario btn--sm" data-ver>${icono("buscar")}Vista previa</button>` : ""}
        <button type="button" class="btn btn--secundario btn--sm" data-descargar>${icono("descargar")}Descargar</button>
        ${admin ? `
        <button type="button" class="btn-icono" data-editar aria-label="Cambiar tipo o reemplazar ${esc(doc.nombre_archivo)}" title="Cambiar tipo o reemplazar">${icono("editar")}</button>
        <button type="button" class="btn-icono btn-icono--peligro" data-borrar aria-label="Eliminar ${esc(doc.nombre_archivo)}" title="Eliminar">${icono("borrar")}</button>` : ""}
      </div>
    </li>`;

  const grupos = tipos.map((t) => ({ tipo: t, docs: docs.filter((x) => x.id_doc === t.id_doc) })).filter((g) => g.docs.length);
  const opcionesTipo = tipos.map((t) => `<option value="${t.id_doc}">${esc(t.descripcion)}</option>`).join("");

  panel.innerHTML = `
    ${admin ? `
    <section class="panel subida" data-zona-soltar>
      <div class="panel__cabeza"><div><h2>Agregar documentos</h2><p>Elija el tipo y uno o varios archivos, o arrástrelos aquí. Hasta ${MAX_MB_DOCUMENTO / 1024} GB por archivo.</p></div></div>
      <form class="panel__cuerpo" novalidate>
        <div data-error hidden style="margin-bottom:14px"></div>
        <div class="subida__campos">
          <div class="campo" data-campo="id_doc"><label for="sd-tipo">Tipo de documento <span class="req" aria-hidden="true">*</span></label>
            <select id="sd-tipo" name="id_doc" required><option value="">Seleccione…</option>${opcionesTipo}</select><p class="error-campo" hidden></p></div>
          <div class="campo" data-campo="archivo"><label for="sd-archivo">Archivos <span class="req" aria-hidden="true">*</span></label>
            <input id="sd-archivo" name="archivo" type="file" class="control-archivo" multiple required><p class="error-campo" hidden></p></div>
          <button type="submit" class="btn btn--primario">${icono("subir")}Subir</button>
        </div>
        <div class="progreso" data-progreso hidden>
          <div class="progreso__barra"><span></span></div>
          <span class="progreso__texto" aria-live="polite"></span>
        </div>
      </form>
    </section>` : ""}
    ${grupos.length ? grupos.map((g) => `
      <section class="panel">
        <div class="panel__cabeza"><div><h2>${esc(g.tipo.descripcion)}</h2><p>${g.docs.length} ${g.docs.length === 1 ? "archivo" : "archivos"}</p></div></div>
        <ul class="docs-red">${g.docs.map(filaDoc).join("")}</ul>
      </section>`).join("") : `
      <section class="panel">${vacioHTML({
        icono: "documento", titulo: "Este dispositivo no tiene documentos",
        texto: admin ? "Suba sus manuales, imagen, firmware, respaldos o configuración." : "Un administrador puede subir sus manuales, firmware, respaldos y configuración.",
      })}</section>`}`;

  const buscarDoc = (el) => docs.find((x) => String(x.num_linea) === el.closest("[data-num]")?.dataset.num);

  panel.addEventListener("click", async (ev) => {
    const doc = buscarDoc(ev.target);
    if (!doc) return;
    if (ev.target.closest("[data-visor]")) {
      abrirVisor(urlApi(doc.imagen_url), { titulo: doc.nombre_archivo, alt: doc.nombre_archivo });
      return;
    }
    if (ev.target.closest("[data-ver]")) { verDocumento(d, doc); return; }
    const botonDescargar = ev.target.closest("[data-descargar]");
    if (botonDescargar) {
      botonCargando(botonDescargar, true);
      try { await descargar(d, doc); } catch (e) { toast(e.message, "error"); }
      botonCargando(botonDescargar, false);
      return;
    }
    if (ev.target.closest("[data-editar]")) {
      const r = await abrirFormulario({
        titulo: "Cambiar documento",
        descripcion: doc.nombre_archivo,
        campos: [
          { nombre: "id_doc", etiqueta: "Tipo de documento", tipo: "select", requerido: true, entero: true, opciones: opciones(tipos, "id_doc") },
          { nombre: "archivo", etiqueta: "Reemplazar el archivo", tipo: "file", mayus: false, ayuda: "Opcional. Déjelo vacío para conservar el archivo actual." },
        ],
        valores: { id_doc: doc.id_doc },
        textoGuardar: "Guardar cambios",
        alGuardar: (datos, form) => {
          const archivo = form.elements.namedItem("archivo").files[0];
          if (archivo) {
            const problema = validarArchivo(archivo);
            if (problema) throw new ErrorApi(problema, 400, { archivo: problema });
          }
          const fd = new FormData();
          fd.append("id_doc", datos.id_doc);
          if (archivo) fd.append("archivo", archivo);
          return apiSubir(ruta(RECURSO, d.id_disp, "documentos", doc.num_linea), fd, { metodo: "PATCH" });
        },
      });
      if (r) { toast("Se guardaron los cambios del documento."); recargar("documentos"); }
      return;
    }
    if (ev.target.closest("[data-borrar]")) {
      const ok = await confirmar({
        titulo: "Eliminar documento",
        mensaje: `Se borrará ${doc.nombre_archivo} (${doc.tipo_documento.toLowerCase()}) del dispositivo y del servidor.`,
        textoBoton: "Eliminar",
        accion: () => api(ruta(RECURSO, d.id_disp, "documentos", doc.num_linea), { metodo: "DELETE" }),
      });
      if (ok) { toast(`Se eliminó ${doc.nombre_archivo}.`); recargar("documentos"); }
    }
  });

  if (!admin) return;

  /* ---- subir */
  const zona = panel.querySelector("[data-zona-soltar]");
  const form = zona.querySelector("form");
  const caja = form.querySelector("[data-error]");
  const input = form.elements.namedItem("archivo");
  const progreso = form.querySelector("[data-progreso]");
  const barra = progreso.querySelector(".progreso__barra span");
  const textoProgreso = progreso.querySelector(".progreso__texto");

  ["dragenter", "dragover"].forEach((t) => zona.addEventListener(t, (ev) => {
    if (![...(ev.dataTransfer?.types || [])].includes("Files")) return;
    ev.preventDefault();
    zona.classList.add("subida--encima");
  }));
  ["dragleave", "drop"].forEach((t) => zona.addEventListener(t, (ev) => {
    if (t === "dragleave" && zona.contains(ev.relatedTarget)) return;
    zona.classList.remove("subida--encima");
  }));
  zona.addEventListener("drop", (ev) => {
    if (!ev.dataTransfer?.files.length) return;
    ev.preventDefault();
    input.files = ev.dataTransfer.files;
    if (!form.id_doc.value) form.id_doc.focus();
  });

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity()) return;
    const archivosElegidos = [...input.files];
    const problemas = archivosElegidos.map((a) => validarArchivo(a) && `${a.name}: ${validarArchivo(a)}`).filter(Boolean);
    if (problemas.length) {
      mostrarErrores(form, new ErrorApi("", 400, { archivo: problemas.join(" ") }), caja);
      return;
    }
    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    progreso.hidden = false;
    const fallos = [];
    let subidos = 0;
    for (const [i, archivo] of archivosElegidos.entries()) {
      const fd = new FormData();
      fd.append("id_doc", form.id_doc.value);
      fd.append("archivo", archivo);
      try {
        await apiSubir(ruta(RECURSO, d.id_disp, "documentos"), fd, {
          alProgreso: (p) => {
            barra.style.width = `${Math.round(((i + p) / archivosElegidos.length) * 100)}%`;
            textoProgreso.textContent = `${archivo.name}: ${Math.round(p * 100)} %${archivosElegidos.length > 1 ? ` (archivo ${i + 1} de ${archivosElegidos.length})` : ""}`;
          },
        });
        subidos += 1;
      } catch (e) {
        fallos.push(`${archivo.name}: ${e.message}`);
      }
    }
    if (subidos) toast(subidos === 1 ? "Se subió el documento." : `Se subieron ${subidos} documentos.`);
    if (fallos.length && !subidos) {
      botonCargando(boton, false);
      progreso.hidden = true;
      mostrarErrores(form, new ErrorApi("", 400, { archivo: fallos.join(" ") }), caja);
      return;
    }
    if (fallos.length) toast(`No se pudieron subir: ${fallos.join(" ")}`, "error");
    recargar("documentos");
  });
}

/* --------------------------------------------------------------- En la red
   Dónde aparece el equipo en lo último que se importó en el módulo de logs
   (GET logs/equipos/<id>/): la lista del DHCP, el listado de Microclaudia y
   su tráfico en los logs de Sophos, por sus IP, sus MAC y su nombre en la red. */
const POR_RED = {
  MAC: { texto: "Por su MAC", clase: "activo" },
  nombre: { texto: "Por el nombre", clase: "aviso" },
  IP: { texto: "Solo por la IP", clase: "aviso" },
};
const porRedHTML = (por) => `<span class="pastilla pastilla--${POR_RED[por]?.clase || "neutra"}">${esc(POR_RED[por]?.texto || por)}</span>`;
const tipoConcesion = (c) => (c.tipo === "Reserva DHCP activa" ? "Reserva activa" : c.tipo === "Reserva DHCP inactiva" ? "Reserva inactiva"
  : c.expira ? `Concesión hasta ${fechaLog(c.expira)}` : c.tipo || "—");

/** Cabeza de cada fuente: insignia, título, de qué importación sale y su estado. */
const cabezaRed = (clase, ic, titulo, texto, estado) => `
  <div class="panel__cabeza">
    <div class="en-red__titulo"><span class="insignia-log insignia-log--sm${clase ? ` insignia-log--${clase}` : ""}">${icono(ic)}</span>
      <div><h2>${esc(titulo)}</h2><p>${texto}</p></div></div>
    ${estado}
  </div>`;
const estadoRed = (clase, texto) => `<span class="pastilla pastilla--${clase}">${esc(texto)}</span>`;
const notaRed = (html) => `<div class="panel__cuerpo"><p class="en-red__nota">${html}</p></div>`;

function redDhcpHTML(r) {
  const imp = r.dhcp.importacion;
  const lista = r.dhcp.concesiones;
  const eq = r.equipo;
  const texto = imp
    ? `Última lista: <a href="${rutaLogs("intrusos", { dhcp: imp.id_importacion })}">${esc(imp.nombre_archivo)}</a> (importada el ${esc(fecha(imp.creado_en))})`
    : "Las direcciones que entrega el servidor DHCP.";
  if (!imp) {
    return `<section class="panel en-red__fuente">${cabezaRed("dhcp", "dhcp", "Servidor DHCP", texto, estadoRed("inactivo", "Sin lista"))}
      ${notaRed(`Todavía no se ha importado una lista del DHCP. <a href="#/logs/importar/dhcp">Importar las concesiones</a>`)}</section>`;
  }
  if (!lista.length) {
    return `<section class="panel en-red__fuente">${cabezaRed("dhcp", "dhcp", "Servidor DHCP", texto, estadoRed("inactivo", "No aparece"))}
      ${notaRed(eq.macs.length || eq.nombre_equipo
        ? "Ni su MAC ni su nombre aparecen en la última lista: tiene IP fija, estaba apagado, está en otra red o la MAC registrada no es la de la tarjeta que usa."
        : "Sin MAC ni nombre en la red registrados no se puede buscar en el DHCP.")}</section>`;
  }
  const conectado = lista.some((c) => c.presente);
  // «Agregar MAC» solo si la MAC no es de otro equipo del inventario
  const agregable = (c) => c.por === "nombre" && c.mac && !c.mac_de;
  const estado = conectado ? estadoRed("activo", lista.some((c) => c.presente && c.por === "MAC") ? "Con IP del DHCP" : "Con IP, por el nombre")
    : estadoRed("inactivo", "Solo reserva o vencida");
  const filas = lista.map((c) => `
    <tr class="clicable${c.presente ? "" : " fila-ausente"}" data-evento="${c.id_evento}" tabindex="0">
      <td class="en-red__dir"><span class="dato-mono">${esc(c.ip || "—")}</span><span class="secundario dato-mono">${c.mac ? esc(formatearMac(c.mac)) : "Sin MAC"}</span>
        ${c.ip && !c.ip_registrada && eq.ips.length ? `<span class="secundario" title="IP registradas: ${esc(eq.ips.join(", "))}">No es la IP registrada</span>` : ""}</td>
      <td><strong>${esc(c.nombre || "Sin nombre")}</strong>${c.descripcion ? `<span class="secundario">${esc(c.descripcion)}</span>` : ""}</td>
      <td class="col-opcional"><span class="${c.presente ? "" : "sin-dato"}">${esc(tipoConcesion(c))}</span></td>
      <td>${porRedHTML(c.por)}${c.por !== "nombre" ? "" : c.mac_de
        ? `<span class="secundario">Esa MAC es de <a href="#/red/dispositivos/${c.mac_de.id_disp}">${esc(c.mac_de.equipo || `Dispositivo N.º ${c.mac_de.id_disp}`)}</a></span>`
        : `<span class="secundario">Esa MAC no está registrada</span>`}</td>
      <td class="col-acciones">${agregable(c)
        ? `<button type="button" class="btn btn--secundario btn--sm" data-agregar-mac="${esc(c.mac)}" title="Agregar la MAC ${esc(formatearMac(c.mac))} a este equipo">${icono("mas")}Agregar MAC</button>` : ""}</td>
    </tr>`).join("");
  return `<section class="panel en-red__fuente">${cabezaRed("dhcp", "dhcp", "Servidor DHCP", texto, estado)}
    <div class="tabla-envoltura"><table class="tabla tabla--compacta">
      <thead><tr><th>IP y MAC</th><th>Nombre en el DHCP</th><th class="col-opcional">Concesión</th><th>Coincide</th><th class="col-acciones"><span class="visualmente-oculto">Acciones</span></th></tr></thead>
      <tbody>${filas}</tbody></table></div>
    ${lista.some(agregable) ? `<p class="en-red__pie">Una concesión que se llama como este equipo pero con otra MAC suele ser otra tarjeta de red del mismo equipo (por ejemplo la Wi-Fi): <strong>Agregar MAC</strong> la suma a sus direcciones.</p>` : ""}
  </section>`;
}

/** Direcciones del agente sin partirlas; en negrita las que tiene registradas el equipo. */
const dirsAgente = (lista_, registradas, formato) => lista_.map((x) => (registradas.includes(x)
  ? `<strong class="sin-corte" title="Registrada en el equipo">${esc(formato(x))}</strong>` : `<span class="sin-corte">${esc(formato(x))}</span>`)).join(", ");

function redAgenteHTML(r) {
  const imp = r.agentes.importacion;
  const lista = r.agentes.equipos;
  const eq = r.equipo;
  const texto = imp
    ? `Último listado: <a href="${rutaLogs("cobertura", { agentes: imp.id_importacion })}">${esc(imp.nombre_archivo)}</a> (importado el ${esc(fecha(imp.creado_en))})`
    : "Los equipos que tienen el agente instalado.";
  if (!imp) {
    return `<section class="panel en-red__fuente">${cabezaRed("agente", "agente", "Agente de Microclaudia", texto, estadoRed("inactivo", "Sin listado"))}
      ${notaRed(`Todavía no se ha importado un listado de Microclaudia. <a href="#/logs/importar/microclaudia">Importar el listado</a>`)}</section>`;
  }
  if (!lista.length) {
    return `<section class="panel en-red__fuente">${cabezaRed("agente", "agente", "Agente de Microclaudia", texto,
      eq.lleva_agente ? estadoRed("aviso", "Sin el agente") : estadoRed("inactivo", "No lleva agente"))}
      ${notaRed(eq.lleva_agente
        ? "No aparece en el último listado de Microclaudia (por MAC, nombre ni IP): puede que no tenga el agente instalado o que no se haya conectado."
        : `Los equipos de la categoría ${esc(nombreCategoria(eq.categoria))} no llevan el agente de Microclaudia.`)}</section>`;
  }
  const seguro = lista.some((a) => a.por !== "IP");
  const filas = lista.map((a) => `
    <tr class="clicable" data-evento="${a.id_evento}" tabindex="0">
      <td><strong>${esc(a.nombre || "Sin nombre")}</strong><span class="secundario">${esc(a.sistema || "Sistema sin dato")}</span></td>
      <td class="col-opcional">${esc(a.version || "—")}</td>
      <td>${esc(fechaLog(a.ultima_conexion))}</td>
      <td class="dato-mono col-opcional en-red__dirs">${dirsAgente(a.ips, eq.ips, (x) => x) || "—"}<span class="secundario">${dirsAgente(a.macs, eq.macs, formatearMac)}</span></td>
      <td>${porRedHTML(a.por)}${a.por === "IP" ? `<span class="secundario">Puede ser otro equipo que usó esa IP</span>` : ""}</td>
    </tr>`).join("");
  return `<section class="panel en-red__fuente">${cabezaRed("agente", "agente", "Agente de Microclaudia", texto,
    seguro ? `<span class="pastilla pastilla--agente">${icono("check", "ic--sm")}Con el agente</span>` : estadoRed("aviso", "Solo coincide la IP"))}
    <div class="tabla-envoltura"><table class="tabla tabla--compacta">
      <thead><tr><th>Equipo en Microclaudia</th><th class="col-opcional">Versión del agente</th><th>Última conexión</th><th class="col-opcional">IP y MAC</th><th>Coincide</th></tr></thead>
      <tbody>${filas}</tbody></table></div>
  </section>`;
}

function redSophosHTML(r) {
  const s = r.sophos;
  const texto = "El tráfico de sus IP y MAC en los logs del firewall que se importaron.";
  if (!r.hay_logs) {
    return `<section class="panel en-red__fuente">${cabezaRed("", "firewall", "Firewall Sophos", texto, estadoRed("inactivo", "Sin logs"))}
      ${notaRed(`Todavía no se han importado logs de Sophos. <a href="#/logs/importar/sophos">Importar logs</a>`)}</section>`;
  }
  if (!s) {
    return `<section class="panel en-red__fuente">${cabezaRed("", "firewall", "Firewall Sophos", texto, estadoRed("inactivo", "Sin IP ni MAC"))}
      ${notaRed("Para buscar su tráfico el equipo necesita una IPv4 o una MAC registrada.")}</section>`;
  }
  if (!s.total) {
    return `<section class="panel en-red__fuente">${cabezaRed("", "firewall", "Firewall Sophos", texto, estadoRed("inactivo", "Sin tráfico"))}
      ${notaRed("Ningún log importado tiene tráfico de sus IP o MAC.")}</section>`;
  }
  const cifra = (valor, etiqueta, clase = "") => `<div class="cifra${clase ? ` ${clase}` : ""}"><b>${esc(num(valor))}</b><span>${esc(etiqueta)}</span></div>`;
  return `<section class="panel en-red__fuente">${cabezaRed("", "firewall", "Firewall Sophos", texto, estadoRed("activo", "Con tráfico"))}
    <div class="panel__cuerpo">
      <div class="en-red__cifras">
        ${cifra(s.total, s.total === 1 ? "Evento" : "Eventos")}
        ${cifra(s.permitidos, "Permitidos", "cifra--ok")}
        ${cifra(s.denegados, "Denegados", s.denegados ? "cifra--sin" : "")}
        ${cifra(s.dominios, "Sitios distintos")}
      </div>
      <p class="en-red__nota">${esc(rangoFechas(s.desde, s.hasta))}, en ${esc(num(s.importaciones))} ${s.importaciones === 1 ? "importación" : "importaciones"}.
        Filtro: <code>${esc(s.filtro)}</code></p>
      <div class="en-red__acciones">
        <a class="btn btn--secundario btn--sm" href="${rutaLogs("eventos", { q: s.filtro })}">${icono("filtro")}Ver sus eventos</a>
        <a class="btn btn--secundario btn--sm" href="${rutaLogs("tablero", { q: s.filtro })}">${icono("grafico")}Ver su tablero</a>
      </div>
    </div>
  </section>`;
}

async function pestanaEnLaRed(panel, d, ctx, recargar) {
  const r = await api(`logs/equipos/${d.id_disp}/`);
  const eq = r.equipo;
  const claves = [
    eq.nombre_equipo && `<span class="chip-dir" title="Nombre en la red">${esc(eq.nombre_equipo)}</span>`,
    ...eq.ips.map((ip) => `<span class="chip-dir" title="IP registrada">${esc(ip)}</span>`),
    ...eq.macs.map((m) => `<span class="chip-dir" title="MAC registrada">${esc(formatearMac(m))}</span>`),
  ].filter(Boolean);
  panel.innerHTML = `
    <div class="en-red">
      <div class="en-red__claves"><span class="etiqueta-dir">Se busca por</span>${claves.join("")
        || `<span class="sin-dato">nada todavía</span>`}</div>
      ${claves.length ? "" : `<div class="aviso aviso--ocre">${icono("alerta")}<span>El equipo no tiene nombre en la red, IP ni MAC registrados.
        Agréguelos en Datos generales para encontrarlo en el DHCP, en Microclaudia y en los logs.</span></div>`}
      ${redDhcpHTML(r)}
      ${redAgenteHTML(r)}
      ${redSophosHTML(r)}
    </div>`;

  const abrir = (tr) => abrirEvento(Number(tr.dataset.evento));
  panel.addEventListener("click", async (ev) => {
    const boton = ev.target.closest("[data-agregar-mac]");
    if (boton) {
      const mac = boton.dataset.agregarMac;
      const nombre = `${tituloDispositivo(d)} (serie ${d.serie})`;
      const ok = await confirmar({
        titulo: "Agregar la MAC al equipo",
        mensaje: `Se agregará la MAC ${formatearMac(mac)} a las direcciones de ${nombre}. Hágalo si esa concesión del DHCP es de este equipo (otra tarjeta de red, por ejemplo la Wi-Fi).`,
        textoBoton: "Agregar MAC", peligro: false,
        accion: () => api(ruta(RECURSO, d.id_disp, "macs"), { metodo: "POST", datos: { direccion_mac: mac } }),
      });
      if (ok) { toast(`Se agregó la MAC ${formatearMac(mac)}.`); recargar("en-la-red"); }
      return;
    }
    const tr = ev.target.closest("tr[data-evento]");
    if (tr && !ev.target.closest("a, button")) abrir(tr);
  });
  panel.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest?.("tr[data-evento]");
    if (tr && ev.target === tr && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); abrir(tr); }
  });
}

/* ----------------------------------------------------------------- Historial */
async function pestanaHistorial(panel, d) {
  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza"><div><h2>Historial</h2><p>Quién registró y modificó este dispositivo y sus documentos, y cuándo.</p></div></div>
      <div class="panel__cuerpo" data-feed-historial></div>
    </section>`;
  await feedAuditoria(panel.querySelector("[data-feed-historial]"), {}, {
    ruta: ruta(RECURSO, d.id_disp, "historial"), limite: 20, vacio: "No hay cambios registrados para este dispositivo.",
  });
}

/* =====================================================================
   Marcas y modelos
   ===================================================================== */
export async function vistaMarcas(cont, _params, ctx) {
  ctx.migas([{ texto: "Marcas y modelos" }]);
  const admin = ctx.esAdmin;
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Marcas y modelos</h1>
        <p>Cada marca pertenece a un tipo de equipo y tiene sus propios modelos. Una marca que fabrica varios tipos (por ejemplo DELL: laptops, monitores, servidores) se registra una vez por cada tipo.</p></div>
      ${admin ? `<div class="encabezado__acciones"><button type="button" class="btn btn--primario" data-agregar-marca>${icono("mas")}Agregar marca</button></div>` : ""}
    </div>
    <div class="maestro-detalle">
      <section class="panel">
        <form class="filtros" role="search" onsubmit="return false">
          <div class="campo"><label for="m-tipo">Tipo</label><select id="m-tipo"><option value="">Todos</option></select></div>
          <div class="campo campo--buscar"><label for="m-buscar">Buscar</label><div class="buscador">${icono("buscar")}<input id="m-buscar" type="search" placeholder="Marca" autocomplete="off"></div></div>
        </form>
        <div data-marcas>${cargandoHTML()}</div>
      </section>
      <section class="panel" data-modelos aria-live="polite"></section>
    </div>`;

  const selTipo = cont.querySelector("#m-tipo");
  const buscar = cont.querySelector("#m-buscar");
  const cajaMarcas = cont.querySelector("[data-marcas]");
  const cajaModelos = cont.querySelector("[data-modelos]");
  let marcas = [];
  let modelos = [];
  let visibles = [];
  let modelosVisibles = [];
  let elegida = Number(ctx.query?.get("id_marca")) || null;

  const [tipos, categorias] = await Promise.all([filasCatalogo("tipos-dispositivos"), filasCatalogo("categorias-dispositivos")]);
  if (!ctx.vigente()) return;
  selTipo.insertAdjacentHTML("beforeend", opcionesTiposHTML(tipos, categorias));
  if (ctx.query?.get("tipo_disp")) selTipo.value = ctx.query.get("tipo_disp");

  const modelosDeMarca = (m) => modelos.filter((x) => x.id_marca === m.id_marca).sort((a, b) => a.num_linea - b.num_linea);

  function pintarMarcas() {
    const tipo = Number(selTipo.value);
    const texto = normalizar(buscar.value.trim());
    visibles = marcas.filter((m) => (!tipo || m.tipo_disp === tipo) && (!texto || normalizar(m.descripcion).includes(texto)));
    if (!visibles.some((m) => m.id_marca === elegida)) elegida = visibles[0]?.id_marca ?? null;
    const qs = new URLSearchParams(Object.entries({ tipo_disp: selTipo.value, id_marca: elegida ?? "" }).filter(([, v]) => v)).toString();
    history.replaceState(null, "", `#/red/marcas${qs ? `?${qs}` : ""}`);

    if (!visibles.length) {
      cajaMarcas.innerHTML = vacioHTML({
        icono: "etiqueta", titulo: marcas.length ? "Ninguna marca coincide" : "Todavía no hay marcas",
        boton: admin && !marcas.length ? `<button type="button" class="btn btn--primario" data-agregar-marca>${icono("mas")}Agregar marca</button>` : "",
      });
    } else {
      const columnas = [
        {
          titulo: "Marca",
          html: (m) => `<button type="button" class="enlace-fila" data-elegir aria-pressed="${m.id_marca === elegida}"><strong>${esc(m.descripcion)}</strong></button><span class="secundario">${esc(m.tipo_dispositivo)}</span>`,
        },
        { titulo: "Modelos", clase: "col-numero", html: (m) => String(modelosDeMarca(m).length) },
      ];
      if (admin) columnas.push({ titulo: "", clase: "col-acciones", html: (m) => botonesFila({ etiqueta: m.descripcion }) });
      cajaMarcas.innerHTML = tablaHTML({ columnas, filas: visibles, clicable: true });
      const i = visibles.findIndex((m) => m.id_marca === elegida);
      cajaMarcas.querySelector(`tr[data-i="${i}"]`)?.classList.add("seleccionada");
    }
    pintarModelos();
  }

  function pintarModelos() {
    const m = marcas.find((x) => x.id_marca === elegida);
    modelosVisibles = m ? modelosDeMarca(m) : [];
    if (!m) {
      cajaModelos.innerHTML = vacioHTML({ icono: "etiqueta", titulo: "Elija una marca", texto: "Sus modelos aparecen aquí." });
      return;
    }
    const lista = modelosVisibles;
    cajaModelos.innerHTML = `
      <div class="panel__cabeza">
        <div><h2>Modelos de ${esc(m.descripcion)}</h2><p>${esc(m.tipo_dispositivo)} · ${lista.length} ${lista.length === 1 ? "modelo" : "modelos"}</p></div>
        ${admin ? `<button type="button" class="btn btn--secundario btn--sm" data-agregar-modelo>${icono("mas")}Agregar modelo</button>` : ""}
      </div>
      ${lista.length ? tablaHTML({
        filas: lista,
        columnas: [
          { titulo: "Línea", clase: "col-codigo", html: (x) => esc(x.num_linea) },
          { titulo: "Modelo", html: (x) => `<strong>${esc(x.descripcion)}</strong>` },
          { titulo: "", clase: "col-acciones", html: (x) => `<a class="btn btn--fantasma btn--sm" href="#/red/dispositivos?id_marca=${x.id_marca}&tipo_disp=${x.tipo_disp}" title="Ver equipos de esta marca">${icono("red")}<span class="visualmente-oculto">Equipos</span></a>${admin ? botonesFila({ etiqueta: x.descripcion }) : ""}` },
        ],
      }) : vacioHTML({
        icono: "etiqueta", titulo: "Esta marca no tiene modelos",
        boton: admin ? `<button type="button" class="btn btn--primario" data-agregar-modelo>${icono("mas")}Agregar modelo</button>` : "",
      })}`;
  }

  async function cargar() {
    try {
      [marcas, modelos] = await Promise.all([api(`${RECURSO}/marcas/`), api(`${RECURSO}/modelos/`)]);
    } catch (e) {
      cajaMarcas.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      cajaModelos.innerHTML = "";
      return;
    }
    if (!ctx.vigente()) return;
    olvidarMarcasYModelos();
    pintarMarcas();
  }

  async function formularioMarca(m) {
    const r = await abrirFormulario({
      titulo: m ? "Editar marca" : "Agregar marca",
      descripcion: m ? "El tipo solo se puede cambiar mientras la marca no tenga modelos ni dispositivos." : "",
      campos: [
        {
          nombre: "tipo_disp", etiqueta: "Tipo de equipo", tipo: "select", requerido: true, entero: true,
          opciones: opciones([...tipos].sort((a, b) => a.descripcion.localeCompare(b.descripcion, "es")), "tipo_disp"),
        },
        { nombre: "descripcion", etiqueta: "Marca", requerido: true, max: 100, placeholder: "CISCO" },
      ],
      valores: m || { tipo_disp: Number(selTipo.value) || "" },
      textoGuardar: m ? "Guardar cambios" : "Agregar",
      alGuardar: (datos) => api(m ? ruta(`${RECURSO}/marcas`, m.id_marca) : `${RECURSO}/marcas/`, { metodo: m ? "PUT" : "POST", datos }),
    });
    if (r) { elegida = r.id_marca; toast(m ? "Se guardaron los cambios." : `Se agregó la marca ${r.descripcion}.`); await cargar(); }
  }

  async function formularioModelo(marca, x) {
    const r = await abrirFormulario({
      titulo: x ? "Editar modelo" : `Agregar modelo de ${marca.descripcion}`,
      campos: [{ nombre: "descripcion", etiqueta: "Modelo", requerido: true, max: 150, placeholder: "CISCO 4321" }],
      valores: x || {},
      textoGuardar: x ? "Guardar cambios" : "Agregar",
      alGuardar: (datos) => (x
        ? api(ruta(`${RECURSO}/modelos`, x.id_marca, x.id_modelo), { metodo: "PUT", datos })
        : api(`${RECURSO}/modelos/`, { metodo: "POST", datos: { ...datos, id_marca: marca.id_marca } })),
    });
    if (r) { toast(x ? "Se guardaron los cambios." : `Se agregó el modelo ${r.descripcion}.`); await cargar(); }
  }

  cont.addEventListener("click", async (ev) => {
    if (ev.target.closest("[data-agregar-marca]")) return formularioMarca(null);
    const marcaElegida = marcas.find((x) => x.id_marca === elegida);
    if (ev.target.closest("[data-agregar-modelo]")) return formularioModelo(marcaElegida, null);

    if (cajaMarcas.contains(ev.target)) {
      const r = eventoFila(ev, visibles);
      if (!r) return;
      if (r.accion === "editar") return formularioMarca(r.fila);
      if (r.accion === "borrar") {
        const ok = await confirmar({
          titulo: "Eliminar marca",
          mensaje: `Se eliminará la marca ${r.fila.descripcion} (${r.fila.tipo_dispositivo.toLowerCase()}). Si tiene modelos o dispositivos, no se podrá eliminar.`,
          textoBoton: "Eliminar",
          accion: () => api(ruta(`${RECURSO}/marcas`, r.fila.id_marca), { metodo: "DELETE" }),
        });
        if (ok) { toast(`Se eliminó la marca ${r.fila.descripcion}.`); await cargar(); }
        return;
      }
      elegida = r.fila.id_marca;
      pintarMarcas();
      // En pantallas angostas los modelos quedan debajo: se lleva la vista hasta ellos
      if (window.matchMedia("(max-width: 1080px)").matches) cajaModelos.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }

    if (cajaModelos.contains(ev.target)) {
      const r = eventoFila(ev, modelosVisibles);
      if (!r?.accion) return;
      if (r.accion === "editar") return formularioModelo(marcaElegida, r.fila);
      const ok = await confirmar({
        titulo: "Eliminar modelo",
        mensaje: `Se eliminará el modelo ${r.fila.descripcion}. Si algún dispositivo lo usa, no se podrá eliminar.`,
        textoBoton: "Eliminar",
        accion: () => api(ruta(`${RECURSO}/modelos`, r.fila.id_marca, r.fila.id_modelo), { metodo: "DELETE" }),
      });
      if (ok) { toast(`Se eliminó el modelo ${r.fila.descripcion}.`); await cargar(); }
    }
  });
  selTipo.addEventListener("change", pintarMarcas);
  buscar.addEventListener("input", pintarMarcas);

  await cargar();
}

/* =====================================================================
   Edificios
   ===================================================================== */
export async function vistaEdificios(cont, _params, ctx) {
  ctx.migas([{ texto: "Edificios" }]);
  const admin = ctx.esAdmin;
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Edificios</h1><p>Edificios de la municipalidad donde se ubican los dispositivos de red. La ubicación GPS se pone aquí, en el edificio: cada dispositivo que está en él la toma para su mapa.</p></div>
      ${admin ? `<div class="encabezado__acciones"><button type="button" class="btn btn--primario" data-agregar>${icono("mas")}Agregar edificio</button></div>` : ""}
    </div>
    <section class="panel">
      <form class="filtros" role="search" onsubmit="return false">
        <div class="campo campo--buscar"><label for="e-buscar">Buscar</label><div class="buscador">${icono("buscar")}<input id="e-buscar" type="search" placeholder="Nombre u otras señas" autocomplete="off"></div></div>
        <span class="filtros__total" data-total aria-live="polite"></span>
      </form>
      <div data-lista>${cargandoHTML()}</div>
    </section>`;

  const lista = cont.querySelector("[data-lista]");
  const buscar = cont.querySelector("#e-buscar");
  const total = cont.querySelector("[data-total]");
  let filas = [];
  let visibles = [];

  function pintar() {
    const q = normalizar(buscar.value.trim());
    visibles = q ? filas.filter((f) => normalizar(`${f.descripcion} ${f.otras_senas || ""} ${f.nombre_distrito || ""} ${f.nombre_canton || ""}`).includes(q)) : filas;
    total.textContent = `${visibles.length} de ${filas.length}`;
    if (!visibles.length) {
      lista.innerHTML = vacioHTML({
        icono: "edificio", titulo: filas.length ? "Nada coincide con la búsqueda" : "Todavía no hay edificios",
        texto: filas.length ? "" : "Registre los edificios para indicar dónde está cada dispositivo.",
        boton: admin && !filas.length ? `<button type="button" class="btn btn--primario" data-agregar>${icono("mas")}Agregar edificio</button>` : "",
      });
      return;
    }
    const columnas = [
      {
        titulo: "Edificio",
        html: (f) => `<div class="persona"><span class="insignia-tipo" aria-hidden="true">${icono("edificio")}</span><div><strong>${esc(f.descripcion)}</strong>${f.otras_senas || f.nombre_distrito ? `<span class="secundario">${esc([f.nombre_distrito && `${nombreLugar(f.nombre_distrito)}, ${nombreLugar(f.nombre_canton)}, ${nombreLugar(f.nombre_provincia)}`, f.otras_senas].filter(Boolean).join(" · "))}</span>` : ""}</div></div>`,
      },
      {
        titulo: "Ubicación GPS", clase: "col-opcional",
        html: (f) => {
          const c = coordenadas(f.gps);
          return c
            ? `<a class="enlace-mapa" href="${esc(enlaceMaps(c))}" target="_blank" rel="noopener noreferrer">${icono("externo", "ic--sm")}<span class="dato-mono">${esc(c.texto)}</span></a>`
            : `<span class="secundario">Sin ubicación GPS</span>`;
        },
      },
      {
        titulo: "Dispositivos activos", clase: "col-numero",
        html: (f) => (f.cantidad_dispositivos
          ? `<a href="#/red/dispositivos?id_predio=${f.id_predio}">${f.cantidad_dispositivos}</a>`
          : `<span class="secundario">0</span>`),
      },
    ];
    if (admin) columnas.push({ titulo: "", clase: "col-acciones", html: (f) => botonesFila({ etiqueta: f.descripcion }) });
    lista.innerHTML = tablaHTML({ columnas, filas: visibles });
  }

  async function cargar() {
    try {
      filas = await api(`${RECURSO}/edificios/`);
    } catch (e) {
      lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    if (!ctx.vigente()) return;
    olvidarCatalogo("edificios");
    pintar();
  }

  async function formulario(fila) {
    const r = await formularioEdificio(fila);
    if (r) { toast(fila ? "Se guardaron los cambios." : `Se agregó ${r.descripcion}.`); await cargar(); }
  }

  cont.addEventListener("click", async (ev) => {
    if (ev.target.closest("[data-agregar]")) return formulario(null);
    const r = eventoFila(ev, visibles);
    if (!r?.accion) return;
    if (r.accion === "editar") return formulario(r.fila);
    const ok = await confirmar({
      titulo: "Eliminar edificio",
      mensaje: `Se eliminará ${r.fila.descripcion}. Si tiene dispositivos, no se podrá eliminar.`,
      textoBoton: "Eliminar",
      accion: () => api(ruta(`${RECURSO}/edificios`, r.fila.id_predio), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se eliminó ${r.fila.descripcion}.`); await cargar(); }
  });
  buscar.addEventListener("input", pintar);

  await cargar();
}

/* =====================================================================
   Equipos de una persona: pestaña de la ficha del funcionario (equipos
   asignados) y de la del proveedor (equipos a los que da soporte)
   ===================================================================== */
export async function pestanaEquiposPersona(panel, persona, ctx, { proveedor = false } = {}) {
  const campo = proveedor ? "id_proveedor" : "id_asignado";
  const filas = await api(`${RECURSO}/`, { query: { [campo]: persona.id, activo: "" } });
  const nombre = nombreCompleto(persona);
  const enLista = `#/red/dispositivos?${campo}=${persona.id}&activo=`;
  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza">
        <div><h2>${proveedor ? "Equipos a los que da soporte" : "Equipos asignados"}</h2>
          <p>${proveedor ? `Equipos municipales que tienen a ${esc(nombre)} como proveedor de soporte.` : `Equipos municipales que tiene a cargo ${esc(nombre)}.`}</p></div>
        <div class="panel__acciones">
          ${filas.length ? `<a class="btn btn--fantasma btn--sm" href="${enLista}">${icono("red")}Ver en la lista de equipos</a>` : ""}
          ${ctx.esAdmin && !proveedor ? `<a class="btn btn--secundario btn--sm" href="#/red/dispositivos/nuevo?asignado=${persona.id}">${icono("mas")}Registrar un equipo a su nombre</a>` : ""}
        </div>
      </div>
      <div data-lista></div>
    </section>`;
  const caja = panel.querySelector("[data-lista]");
  if (!filas.length) {
    caja.innerHTML = vacioHTML({
      icono: "red", titulo: proveedor ? "No da soporte a ningún equipo" : "No tiene equipos asignados",
      texto: proveedor ? "Se elige el proveedor en los datos de cada equipo." : "Se asignan en los datos de cada equipo (sección Asignación).",
    });
    return;
  }
  caja.innerHTML = tablaHTML({
    clicable: true,
    filas,
    columnas: [
      { titulo: "Equipo", html: celdaDispositivo },
      { titulo: "Tipo", html: (d) => `${esc(d.tipo_dispositivo)}<span class="secundario">${esc(nombreCategoria(d.categoria))}</span>` },
      {
        titulo: "Ubicación", clase: "col-opcional",
        html: (d) => (d.edificio || d.ubicacion
          ? `${esc(d.edificio || "Sin edificio")}<span class="secundario">${esc(d.ubicacion || "")}</span>`
          : `<span class="secundario">Sin ubicación</span>`),
      },
      { titulo: "Estado", html: (d) => pastillaEstado(d.activo) },
    ],
  });
  caja.addEventListener("click", (ev) => {
    const r = eventoFila(ev, filas);
    if (r && !ev.target.closest("a")) location.hash = `#/red/dispositivos/${r.fila.id_disp}`;
  });
}
