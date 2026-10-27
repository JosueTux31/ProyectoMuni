// Módulo de dispositivos de red: inicio del módulo, lista, registro, ficha
// (datos, documentos e historial), marcas y modelos, y edificios.
// Todo pasa por las APIs de /api/dispositivos/ (procedimientos almacenados).
import { api, apiSubir, ErrorApi, ruta } from "./api.js";
import {
  abrirFormulario, botonCargando, botonesFila, cargandoHTML, confirmar, debounce, errorHTML, esc, eventoFila,
  fecha, icono, leerCampos, limpiarErrores, mostrarErrores, nombreCompleto, tablaHTML, toast, urlApi, vacioHTML,
} from "./ui.js";
import { filasCatalogo, olvidarCatalogo } from "./datos.js";
import { pastillaEstado, seccionesHTML, todosLosCampos } from "./usuarios.js";
import { coordenadas, embebidoMaps, enlaceMaps, enlazarCampoMapa, validarMapaLocal } from "./proveedores.js";
import { feedAuditoria } from "./auditoria.js";
import { abrirVisor, abrirVistaPrevia } from "./zoom.js";

const RECURSO = "dispositivos";
const MAX_MB_DOCUMENTO = 1024;   // igual que MUNI_MAX_MB_DOCUMENTO_RED en settings.py
const EXT_BLOQUEADAS = [".html", ".htm", ".xhtml", ".svg", ".js", ".mjs", ".php", ".phtml", ".asp", ".aspx", ".jsp", ".hta"];

/* =====================================================================
   Utilidades
   ===================================================================== */
const ICONO_TIPO = { MODEM: "modem", FIREWALL: "firewall", ROUTER: "router", SWITCH: "switch" };
const normalizar = (s) => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

/** Ícono según el tipo de dispositivo (red si es un tipo nuevo). */
export const iconoTipo = (descripcion) => ICONO_TIPO[String(descripcion || "").toUpperCase()] || "red";

const insigniaTipo = (d, tam = "") =>
  `<span class="insignia-tipo${tam ? ` insignia-tipo--${tam}` : ""}" aria-hidden="true">${icono(iconoTipo(d.tipo_dispositivo))}</span>`;

/** Nombre del equipo: el modelo (ya incluye la marca) o la marca si no tiene modelo. */
export const tituloDispositivo = (d) => d.modelo || d.marca || `Dispositivo ${d.id_disp}`;

/** La marca solo se agrega si el modelo no la trae ya (CISCO ASA ya dice CISCO). */
const marcaAparte = (d) => (d.modelo && !normalizar(d.modelo).startsWith(normalizar(d.marca)) ? d.marca : "");

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

const MAX_DIRECCIONES = 50;   // IP o MAC por dispositivo (igual que el servidor)

const DIRECCIONES = {
  ips: {
    titulo: "Direcciones IP", etiqueta: "Dirección IP", singular: "dirección IP", plural: "direcciones IP", corto: "IP",
    campo: "direccion_ip", icono: "web", placeholder: "192.168.1.1", max: 45, valida: ipValida, mensaje: MENSAJE_IP,
    mostrar: (x) => x, normalizar: (x) => String(x || "").trim().toLowerCase(),
  },
  macs: {
    titulo: "Direcciones MAC", etiqueta: "Dirección MAC", singular: "dirección MAC", plural: "direcciones MAC", corto: "MAC",
    campo: "direccion_mac", icono: "puertos", placeholder: "AA-BB-CC-DD-EE-FF", max: 30, valida: macValida, mensaje: MENSAJE_MAC,
    mostrar: formatearMac, normalizar: (x) => String(x || "").replace(/[^0-9a-f]/gi, "").toUpperCase(),
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
  if (e.estado === 409 && /uk_disp_serie/.test(e.db)) e.campos = { serie: "Ya hay otro dispositivo de esa marca con la misma serie." };
  else if (e.estado === 409 && /uk_macs_mac/.test(e.db)) e.campos = { direccion_mac: "Esa dirección MAC ya está registrada en un dispositivo." };
  else if (e.estado === 409 && /uk_ips_dispositivo/.test(e.db)) e.campos = { direccion_ip: "El dispositivo ya tiene esa dirección IP." };
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
  const [tipos, marcas, sistemas, edificios] = await Promise.all([
    filasCatalogo("tipos-dispositivos"), filasCatalogo("marcas"),
    filasCatalogo("sistemas-operativos"), filasCatalogo("edificios"),
  ]);
  return { tipos, marcas, sistemas, edificios };
}

/* =====================================================================
   Inicio del módulo
   ===================================================================== */
export async function vistaInicioRed(cont, _params, ctx) {
  ctx.migas([{ texto: "Inicio" }]);
  cont.innerHTML = `
    <div class="saludo">
      <h1>Dispositivos de red</h1>
      <p>Modems, firewalls, routers y switches de la municipalidad: dónde están, quién les da soporte y sus archivos.</p>
    </div>
    ${ctx.esAdmin ? "" : `<div class="aviso aviso--ocre" style="margin-top:18px">${icono("candado")}<span>Su rol permite consultar los dispositivos y descargar sus documentos. Los cambios los hace un administrador.</span></div>`}
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
    ${ctx.esAdmin ? `
    <section class="panel" style="margin-top:20px">
      <div class="panel__cabeza"><div><h2>Actividad reciente</h2><p>Últimos cambios a los dispositivos.</p></div><a class="btn btn--fantasma btn--sm" href="#/red/auditoria">Ver toda la auditoría</a></div>
      <div class="panel__cuerpo" id="actividad-red"></div>
    </section>` : ""}`;

  if (ctx.esAdmin) {
    feedAuditoria(cont.querySelector("#actividad-red"), { tabla: "red_dispositivos" }, {
      limite: 8, paginar: false, vacio: "Todavía no hay cambios en los dispositivos.",
    }).catch((e) => { cont.querySelector("#actividad-red").innerHTML = errorHTML(e.message); });
  }

  const [dispositivos, tipos] = await Promise.all([
    api(`${RECURSO}/`, { query: { activo: true } }),
    filasCatalogo("tipos-dispositivos"),
  ]);
  if (!ctx.vigente()) return;

  const ordenados = [...tipos].sort((a, b) => a.tipo_disp - b.tipo_disp);
  const cuantos = (t) => dispositivos.filter((d) => d.tipo_disp === t.tipo_disp).length;
  const nombreTipo = (t) => t.descripcion.charAt(0) + t.descripcion.slice(1).toLowerCase();
  cont.querySelector("#resumen-red").outerHTML = `
    <h2 class="resumen__titulo" id="titulo-resumen-red">Dispositivos activos por tipo</h2>
    <nav class="resumen resumen--iconos" aria-labelledby="titulo-resumen-red" style="--columnas:${Math.min(Math.max(ordenados.length, 1), 6)}">
      ${ordenados.map((t) => `<a href="#/red/dispositivos?tipo_disp=${t.tipo_disp}">${icono(iconoTipo(t.descripcion))}<b>${cuantos(t)}</b><span>${esc(nombreTipo(t))}</span></a>`).join("")}
    </nav>`;

  const recientes = [...dispositivos].sort((a, b) => String(b.creado_en).localeCompare(String(a.creado_en))).slice(0, 6);
  const caja = cont.querySelector("#recientes-red");
  if (!recientes.length) {
    caja.innerHTML = vacioHTML({
      icono: "red", titulo: "Todavía no hay dispositivos",
      boton: ctx.esAdmin ? `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar el primero</a>` : "",
    });
    return;
  }
  caja.innerHTML = tablaHTML({
    clicable: true,
    filas: recientes,
    columnas: [
      { titulo: "Dispositivo", html: (d) => celdaDispositivo(d) },
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
      ? item("#/red/dispositivos/nuevo", "mas", "Registrar un dispositivo", "Equipo, ubicación, red, soporte y documentos")
      : item("#/red/dispositivos", "red", "Buscar un dispositivo", "Por serie, modelo, ubicación, IP o MAC"),
    item("#/red/edificios", "edificio", "Edificios", "Dónde están los equipos"),
    item("#/red/marcas", "etiqueta", "Marcas y modelos", "Por tipo de dispositivo"),
    item("#/red/catalogos/tipos-documentos", "documento", "Tipos de documento", "Manuales, firmware, respaldos…"),
  ];
}

const celdaDispositivo = (d) => `
  <div class="persona">${insigniaTipo(d)}<div>
    <a href="#/red/dispositivos/${d.id_disp}"><strong>${esc(tituloDispositivo(d))}</strong></a>
    <span class="secundario">${esc([marcaAparte(d), `Serie ${d.serie}`].filter(Boolean).join(" · "))}</span>
  </div></div>`;

/* =====================================================================
   Lista de dispositivos
   ===================================================================== */
export async function vistaDispositivos(cont, _params, ctx) {
  ctx.migas([{ texto: "Dispositivos" }]);
  const q = ctx.query || new URLSearchParams();
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Dispositivos</h1>
        <p>Inventario de equipos de red con su ubicación, proveedor de soporte y documentos.</p>
      </div>
      ${ctx.esAdmin ? `<div class="encabezado__acciones"><a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Nuevo dispositivo</a></div>` : ""}
    </div>
    <section class="panel">
      <form class="filtros" role="search" id="filtros-dispositivos">
        <div class="campo campo--buscar">
          <label for="d-buscar">Buscar</label>
          <div class="buscador">${icono("buscar")}<input id="d-buscar" name="buscar" type="search" placeholder="Serie, modelo, ubicación, IP o MAC" autocomplete="off"></div>
        </div>
        <div class="campo"><label for="d-tipo">Tipo</label><select id="d-tipo" name="tipo_disp"><option value="">Todos</option></select></div>
        <div class="campo"><label for="d-marca">Marca</label><select id="d-marca" name="id_marca"><option value="">Todas</option></select></div>
        <div class="campo"><label for="d-edificio">Edificio</label><select id="d-edificio" name="id_predio"><option value="">Todos</option></select></div>
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
  let filas = [];

  const [base, proveedores] = await Promise.all([datosBase(), api("proveedores/", { query: { activo: "" } })]);
  if (!ctx.vigente()) return;
  const opcionesHTML = (lista2) => lista2.map((o) => `<option value="${esc(o.valor)}">${esc(o.texto)}</option>`).join("");
  form.tipo_disp.insertAdjacentHTML("beforeend", opcionesHTML(opciones(base.tipos, "tipo_disp")));
  form.id_predio.insertAdjacentHTML("beforeend", opcionesHTML(opciones(base.edificios, "id_predio")));
  form.id_proveedor.insertAdjacentHTML("beforeend", opcionesHTML(opciones(proveedores, "id", nombreCompleto)));

  function llenarMarcas() {
    const tipo = Number(form.tipo_disp.value);
    const anterior = form.id_marca.value;
    const marcas = base.marcas.filter((m) => !tipo || m.tipo_disp === tipo);
    form.id_marca.innerHTML = `<option value="">Todas</option>${opcionesHTML(opciones(marcas, "id_marca", (m) => (tipo ? m.descripcion : `${m.descripcion} (${m.tipo_dispositivo.toLowerCase()})`)))}`;
    if (marcas.some((m) => String(m.id_marca) === anterior)) form.id_marca.value = anterior;
  }

  // Filtros que vienen en la dirección (#/red/dispositivos?tipo_disp=2)
  for (const nombre of ["buscar", "tipo_disp", "id_predio", "id_proveedor", "activo"]) {
    if (q.has(nombre)) form[nombre].value = q.get(nombre);
  }
  llenarMarcas();
  if (q.has("id_marca")) form.id_marca.value = q.get("id_marca");

  const NOMBRES = ["buscar", "tipo_disp", "id_marca", "id_predio", "id_proveedor", "activo"];
  let consulta = 0;
  async function cargar() {
    const esta = ++consulta;
    const query = Object.fromEntries(NOMBRES.map((n) => [n, form[n].value.trim()]));
    // La dirección guarda los filtros para volver a la misma lista
    const qs = new URLSearchParams(Object.entries(query).filter(([n, v]) => v !== "" && !(n === "activo" && v === "true"))).toString();
    history.replaceState(null, "", `#/red/dispositivos${qs ? `?${qs}` : ""}`);
    lista.innerHTML = cargandoHTML();
    try {
      filas = await api(`${RECURSO}/`, { query });
    } catch (e) {
      if (esta === consulta) lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    if (esta !== consulta || !ctx.vigente()) return;
    total.textContent = `${filas.length} ${filas.length === 1 ? "dispositivo" : "dispositivos"}`;

    if (!filas.length) {
      const hayFiltros = NOMBRES.some((n) => n !== "activo" && form[n].value);
      lista.innerHTML = vacioHTML({
        icono: "red",
        titulo: hayFiltros ? "Ningún dispositivo coincide con la búsqueda" : "No hay dispositivos en este estado",
        texto: hayFiltros ? "Pruebe con otro texto o quite los filtros." : "",
        boton: ctx.esAdmin && !hayFiltros ? `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar el primero</a>` : "",
      });
      return;
    }

    lista.innerHTML = tablaHTML({
      clicable: true,
      filas,
      columnas: [
        { titulo: "Dispositivo", html: celdaDispositivo },
        { titulo: "Tipo", html: (d) => esc(d.tipo_dispositivo) },
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
  form.addEventListener("submit", (ev) => { ev.preventDefault(); cargar(); });
  form.buscar.addEventListener("input", debounce(cargar, 300));
  form.tipo_disp.addEventListener("change", () => { llenarMarcas(); cargar(); });
  ["id_marca", "id_predio", "id_proveedor", "activo"].forEach((n) => form[n].addEventListener("change", cargar));

  await cargar();
}

/* =====================================================================
   Formulario del dispositivo (crear y editar)
   ===================================================================== */
function seccionesDispositivo(base, proveedores, valores = {}) {
  const provOpciones = opciones(proveedores, "id", nombreCompleto);
  if (valores.id_proveedor && !provOpciones.some((o) => o.valor === valores.id_proveedor)) {
    provOpciones.push({ valor: valores.id_proveedor, texto: `${valores.proveedor || `Proveedor ${valores.id_proveedor}`} (inactivo)` });
  }
  return [
    {
      titulo: "Equipo", icono: "red",
      texto: "La marca depende del tipo y el modelo depende de la marca.",
      campos: [
        { nombre: "tipo_disp", etiqueta: "Tipo de dispositivo", tipo: "select", opciones: opciones(base.tipos, "tipo_disp"), requerido: true, entero: true },
        { nombre: "id_marca", etiqueta: "Marca", tipo: "select", opciones: [], requerido: true, entero: true },
        { nombre: "id_modelo", etiqueta: "Modelo", tipo: "select", opciones: [], entero: true, vacioTexto: "Sin modelo" },
        { nombre: "serie", etiqueta: "Número de serie", requerido: true, max: 100, placeholder: "658429" },
        { nombre: "id_os", etiqueta: "Sistema operativo", tipo: "select", opciones: opciones(base.sistemas, "id_os"), entero: true, sinVacio: true },
      ],
    },
    {
      titulo: "Puertos", icono: "puertos",
      texto: "Cantidad de puertos de red del equipo.",
      campos: [
        { nombre: "cant_ptos_ethernet", etiqueta: "Puertos Ethernet", tipo: "number", entero: true, placeholder: "0" },
        { nombre: "cant_ptos_sfp", etiqueta: "Puertos SFP", tipo: "number", entero: true, placeholder: "0" },
      ],
    },
    {
      titulo: "Ubicación", icono: "punto",
      texto: "Edificio donde está el equipo y el lugar exacto dentro de él. La ubicación GPS se toma del edificio.",
      campos: [
        { nombre: "id_predio", etiqueta: "Edificio", tipo: "select", opciones: opciones(base.edificios, "id_predio"), entero: true, vacioTexto: "Sin edificio" },
        { nombre: "ubicacion", etiqueta: "Ubicación en el edificio", max: 255, placeholder: "Piso 2, cuarto de comunicaciones, rack 1" },
      ],
    },
    {
      titulo: "Soporte", icono: "proveedor",
      texto: "Proveedor que le da soporte al equipo.",
      campos: [
        { nombre: "id_proveedor", etiqueta: "Proveedor de soporte", tipo: "select", opciones: provOpciones, entero: true, vacioTexto: "Sin proveedor", completo: true },
      ],
    },
  ];
}

/** Tipo → marca → modelo en cascada. Termina cuando los modelos quedaron cargados. */
async function enlazarEquipo(form, base, valores = {}, bloqueado = false) {
  const selTipo = form.elements.namedItem("tipo_disp");
  const selMarca = form.elements.namedItem("id_marca");
  const selModelo = form.elements.namedItem("id_modelo");
  const opcion = (v, t, elegida) => `<option value="${esc(v)}"${elegida ? " selected" : ""}>${esc(t)}</option>`;

  function llenarMarcas(preseleccion) {
    const tipo = Number(selTipo.value);
    const marcas = base.marcas.filter((m) => m.tipo_disp === tipo);
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

  selTipo.addEventListener("change", () => { llenarMarcas(null); llenarModelos(null); });
  selMarca.addEventListener("change", () => llenarModelos(null));
  llenarMarcas(valores.id_marca ?? null);
  await llenarModelos(valores.id_modelo ?? null);
}

/** Formulario de un edificio: nombre, otras señas y ubicación GPS. Lo usan la
 *  lista de edificios y el formulario del dispositivo. Devuelve el edificio
 *  guardado (o null si se cancela). */
export async function formularioEdificio(fila) {
  const r = await abrirFormulario({
    titulo: fila ? "Editar edificio" : "Agregar edificio",
    campos: [
      { nombre: "descripcion", etiqueta: "Nombre del edificio", requerido: true, max: 150, placeholder: "PALACIO MUNICIPAL" },
      { nombre: "otras_senas", etiqueta: "Otras señas", tipo: "textarea", placeholder: "Opcional: dirección o referencias" },
      {
        nombre: "gps", etiqueta: "Ubicación GPS", max: 2000, mayus: false, placeholder: "10.0732, -84.3116",
        ayuda: "En Google Maps, haga clic derecho sobre el edificio y copie las coordenadas, o pegue el enlace del lugar. Todos los dispositivos del edificio toman esta ubicación.",
      },
    ],
    valores: fila || {},
    textoGuardar: fila ? "Guardar cambios" : "Agregar",
    alAbrir: (form) => enlazarCampoMapa(form, "gps"),
    alGuardar: (datos, form) => {
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
const seccionDireccionesHTML = (soloLectura) => `
  <section class="seccion-form" data-seccion-direcciones>
    <h3>${icono("web")}Direcciones de red</h3>
    <p>${soloLectura ? "Direcciones IP y MAC del equipo."
    : "Puede agregar varias IP y varias MAC; las filas vacías no se guardan. La MAC se escribe con o sin separadores, se guarda entera y se muestra como AA-BB-CC-DD-EE-FF."}</p>
    ${Object.entries(DIRECCIONES).map(([clave, def]) => `
    <div class="repetible" data-repetible="${clave}">
      <p class="repetible__titulo">${icono(def.icono, "ic--sm")}${esc(def.titulo)}</p>
      <div class="repetible__filas"></div>
      <p class="repetible__vacio" data-vacio hidden>Sin ${esc(def.plural)}.</p>
      ${soloLectura ? "" : `<div><button type="button" class="btn btn--fantasma btn--sm" data-agregar-dir="${clave}">${icono("mas")}Agregar otra ${def.corto}</button></div>`}
    </div>`).join("")}
  </section>`;

function filaDireccion(clave, valores = {}, soloLectura = false) {
  const def = DIRECCIONES[clave];
  const n = ++contadorFilas;
  const fila = document.createElement("div");
  fila.className = "repetible__fila repetible__fila--direccion";
  if (valores.num_linea) fila.dataset.numLinea = valores.num_linea;
  const valor = valores[def.campo] ? def.mostrar(valores[def.campo]) : "";
  const bloqueo = soloLectura ? " disabled" : "";
  fila.innerHTML = `
    <div class="campo" data-campo="${clave}-${n}"><label for="${clave}-dir-${n}">${esc(def.etiqueta)}</label>
      <input id="${clave}-dir-${n}" data-k="${def.campo}" value="${esc(valor)}" maxlength="${def.max}" placeholder="${soloLectura ? "" : esc(def.placeholder)}" class="dato-mono${clave === "macs" ? " mayus" : ""}" autocomplete="off" spellcheck="false"${bloqueo}><p class="error-campo" hidden></p></div>
    <div class="campo"><label for="${clave}-int-${n}">Interfaz</label>
      <input id="${clave}-int-${n}" data-k="interfaz" value="${esc(valores.interfaz || "")}" maxlength="50" placeholder="${soloLectura ? "" : "WAN, LAN, GESTIÓN…"}" class="mayus" autocomplete="off"${bloqueo}></div>
    ${soloLectura ? "" : `<button type="button" class="btn-icono btn-icono--peligro" data-quitar-dir aria-label="Quitar esta ${esc(def.singular)}">${icono("cerrar")}</button>`}`;
  return fila;
}

/** Pone las IP y MAC en el formulario. Sin direcciones: una fila vacía para escribir. */
function pintarDirecciones(form, valores, soloLectura) {
  for (const clave of Object.keys(DIRECCIONES)) {
    const caja = form.querySelector(`[data-repetible="${clave}"]`);
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
        toast(`Un dispositivo puede tener hasta ${MAX_DIRECCIONES} ${DIRECCIONES[clave].plural}.`, "error");
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

/** Lee y revisa las filas de IP y MAC (las vacías se ignoran).
 *  Devuelve { datos: {ips, macs}, filas: {ips, macs}, errores } donde filas
 *  son los elementos en el mismo orden que datos, para ubicar los errores. */
function leerDirecciones(form) {
  const datos = { ips: [], macs: [] };
  const filas = { ips: [], macs: [] };
  const errores = {};
  for (const [clave, def] of Object.entries(DIRECCIONES)) {
    const vistas = new Set();
    form.querySelectorAll(`[data-repetible="${clave}"] .repetible__fila`).forEach((fila) => {
      const input = fila.querySelector(`[data-k="${def.campo}"]`);
      const campo = input.closest(".campo").dataset.campo;
      const valor = input.value.trim();
      const interfaz = fila.querySelector('[data-k="interfaz"]').value.trim().toUpperCase();
      if (!valor && !interfaz) return;
      if (!valor) { errores[campo] = `Escriba la ${def.singular} o quite la fila.`; return; }
      if (!def.valida(valor)) { errores[campo] = def.mensaje; return; }
      const llave = def.normalizar(valor);
      if (vistas.has(llave)) { errores[campo] = `Esta ${def.singular} ya está en la lista.`; return; }
      vistas.add(llave);
      const item = { [def.campo]: valor, interfaz: interfaz || null };
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
        campos[campoDe(fila)] = e.estado === 409
          ? (clave === "macs" ? "Esa dirección MAC ya está registrada en otro dispositivo." : "Esa dirección IP está repetida.")
          : e.message;
      }
    }
  }
  return campos;
}

/** El servidor devuelve las IP y MAC que quedaron guardadas. Si no coinciden
 *  con las que se mandaron, el backend o la base no son de esta versión. */
function direccionesNoGuardadas(respuesta, datos) {
  const faltan = Object.entries(DIRECCIONES)
    .filter(([clave]) => String(respuesta?.[clave] || "").length < 1000
      && lista(respuesta?.[clave]).length !== datos[clave].length)
    .map(([, def]) => def.corto);
  return faltan.length
    ? `El servidor no guardó las direcciones ${faltan.join(" ni las ")}. Copie de nuevo apps/dispositivos (serializers.py y views.py), ejecute procedimientosDispositivos.sql y reinicie Django.`
    : "";
}

/** Muestra un error del servidor al guardar el dispositivo. */
function mostrarErrorDispositivo(form, e, caja, filas) {
  const enDirecciones = erroresDirecciones(e, filas);
  if (Object.keys(enDirecciones).length) mostrarErrores(form, new ErrorApi(e.message, e.estado, enDirecciones), caja);
  else mostrarErrores(form, precisarError(e), caja);
  caja.scrollIntoView({ behavior: "smooth", block: "center" });
}

function prepararNumeros(form) {
  form.querySelectorAll('input[type="number"]').forEach((input) => {
    input.min = "0";
    input.max = "9999";
    input.step = "1";
    input.inputMode = "numeric";
  });
}

/* =====================================================================
   Nuevo dispositivo
   ===================================================================== */
export async function vistaDispositivoNuevo(cont, _params, ctx) {
  ctx.migas([{ texto: "Dispositivos", href: "#/red/dispositivos" }, { texto: "Nuevo dispositivo" }]);
  cont.innerHTML = cargandoHTML();

  const [base, proveedores, tiposDoc] = await Promise.all([
    datosBase(), api("proveedores/", { query: { activo: true } }), filasCatalogo("tipos-documentos"),
  ]);
  if (!ctx.vigente()) return;
  const secciones = seccionesDispositivo(base, proveedores);
  const valores = { id_os: base.sistemas.some((s) => s.id_os === 1) ? 1 : undefined };
  const opcionesDoc = [...tiposDoc].sort((a, b) => a.id_doc - b.id_doc)
    .map((t) => `<option value="${t.id_doc}">${esc(t.descripcion)}</option>`).join("");

  // Desde «Equipos sin agente»: #/red/dispositivos/nuevo?ip=&mac=&equipo= trae la IP y la MAC del listado de Microclaudia
  const q = ctx.query || new URLSearchParams();
  const previas = {
    ips: q.get("ip") ? [{ direccion_ip: q.get("ip") }] : [],
    macs: q.get("mac") ? [{ direccion_mac: q.get("mac") }] : [],
  };
  const deListado = q.get("equipo");

  cont.innerHTML = `
    <a class="volver" href="#/red/dispositivos">${icono("atras")}Volver a dispositivos</a>
    <div class="encabezado"><div><h1>Nuevo dispositivo</h1><p>Los campos con * son obligatorios.</p></div></div>
    ${deListado ? `<div class="aviso aviso--info">${icono("enlace")}<span>La IP y la MAC vienen del equipo <strong>${esc(deListado)}</strong> del listado de
      Microclaudia. Complete el tipo, la marca y la serie.</span></div>` : ""}
    <form class="panel" id="form-dispositivo" novalidate>
      <div class="panel__cuerpo">
        <div data-error hidden style="margin-bottom:18px"></div>
        ${seccionesHTML(secciones.slice(0, 2), valores, false)}
        ${seccionDireccionesHTML(false)}
        ${seccionesHTML(secciones.slice(2), valores, false)}
        <section class="seccion-form">
          <h3>${icono("documento")}Documentos</h3>
          <p>Opcional. Manuales, imagen, firmware, respaldos o configuración, hasta ${MAX_MB_DOCUMENTO / 1024} GB cada uno. También se pueden subir después desde la ficha.</p>
          <div class="repetible" data-repetible="documentos">
            <div class="repetible__filas"></div>
            <div><button type="button" class="btn btn--fantasma btn--sm" data-agregar-doc>${icono("mas")}Agregar documento</button></div>
          </div>
        </section>
      </div>
      <div class="panel__pie">
        <span class="progreso-texto" data-progreso aria-live="polite"></span>
        <a class="btn btn--secundario" href="#/red/dispositivos">Cancelar</a>
        <button class="btn btn--primario" type="submit">${icono("check")}Registrar dispositivo</button>
      </div>
    </form>`;

  const form = cont.querySelector("#form-dispositivo");
  const caja = form.querySelector("[data-error]");
  const campos = todosLosCampos(secciones);
  const filasDoc = form.querySelector('[data-repetible="documentos"] .repetible__filas');
  prepararNumeros(form);
  enlazarEdificio(form, base.edificios, ctx.esAdmin);
  pintarDirecciones(form, previas, false);
  enlazarDirecciones(form);
  await enlazarEquipo(form, base);

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
      creado = await api(`${RECURSO}/`, { metodo: "POST", datos: { ...leerCampos(form, campos), ...direcciones.datos } });
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

    toast(`Se registró el dispositivo ${tituloDispositivo(creado)} (serie ${creado.serie}).`);
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
  { clave: "historial", titulo: "Historial", icono: "historial", soloAdmin: true },
];

export async function vistaDispositivo(cont, [id, pestanaInicial], ctx) {
  ctx.migas([{ texto: "Dispositivos", href: "#/red/dispositivos" }]);
  cont.innerHTML = cargandoHTML();

  const d = await api(ruta(RECURSO, id));
  if (!ctx.vigente()) return;
  const titulo = tituloDispositivo(d);
  ctx.migas([{ texto: "Dispositivos", href: "#/red/dispositivos" }, { texto: `${titulo} · ${d.serie}` }]);

  const base = `#/red/dispositivos/${d.id_disp}`;
  const pestanas = PESTANAS.filter((t) => !t.soloAdmin || ctx.esAdmin);
  let actual = pestanas.find((t) => t.clave === pestanaInicial)?.clave || "datos";
  const recargar = (pestana = actual) => vistaDispositivo(cont, [String(d.id_disp), pestana], ctx);
  const marca = marcaAparte(d);

  cont.innerHTML = `
    <a class="volver" href="#/red/dispositivos">${icono("atras")}Volver a dispositivos</a>
    <div class="ficha">
      ${insigniaTipo(d, "grande")}
      <div class="ficha__texto">
        <h1>${esc(titulo)}</h1>
        <div class="ficha__datos">
          ${pastillaEstado(d.activo)}
          <span>${esc(d.tipo_dispositivo)}${marca ? ` · ${esc(marca)}` : ""}</span>
          <span class="dato-mono">Serie ${esc(d.serie)}</span>
          ${d.edificio ? `<span class="ficha__dato-icono">${icono("edificio", "ic--sm")}${esc(d.edificio)}</span>` : ""}
          ${d.ips ? `<span class="ficha__dato-icono dato-mono" title="Direcciones IP">${icono("web", "ic--sm")}${resumenDirecciones(d.ips)}</span>` : ""}
          ${d.macs ? `<span class="ficha__dato-icono dato-mono" title="Direcciones MAC">${icono("puertos", "ic--sm")}${resumenDirecciones(d.macs, formatearMac)}</span>` : ""}
        </div>
      </div>
      <div class="ficha__acciones">
        ${ctx.esAdmin ? (d.activo
          ? `<button type="button" class="btn btn--secundario" data-estado>${icono("encender")}Desactivar</button>`
          : `<button type="button" class="btn btn--primario" data-estado>${icono("encender")}Activar</button>`) : ""}
      </div>
    </div>
    <div class="pestanas" role="tablist" aria-label="Información del dispositivo">
      ${pestanas.map((t) => `<button type="button" role="tab" id="tab-${t.clave}" aria-controls="panel-pestana" data-pestana="${t.clave}" aria-selected="${t.clave === actual}">${icono(t.icono)}${esc(t.titulo)}${t.clave === "documentos" ? `<span class="contador">${d.cantidad_documentos || 0}</span>` : ""}</button>`).join("")}
    </div>
    <div id="panel-pestana" role="tabpanel"></div>`;

  cont.querySelector("[data-estado]")?.addEventListener("click", () => cambiarEstado(d, () => recargar()));

  const panel = cont.querySelector("#panel-pestana");
  async function mostrar(clave) {
    actual = clave;
    cont.querySelectorAll("[data-pestana]").forEach((b) => b.setAttribute("aria-selected", String(b.dataset.pestana === clave)));
    panel.setAttribute("aria-labelledby", `tab-${clave}`);
    history.replaceState(null, "", clave === "datos" ? base : `${base}/${clave}`);
    const caja = document.createElement("div");
    caja.innerHTML = cargandoHTML();
    panel.replaceChildren(caja);
    try {
      if (clave === "datos") await pestanaDatos(caja, d, ctx, recargar);
      else if (clave === "documentos") await pestanaDocumentos(caja, d, ctx, recargar);
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
  const [base, proveedores, ips, macs] = await Promise.all([
    datosBase(), api("proveedores/", { query: { activo: true } }),
    api(ruta(RECURSO, d.id_disp, "ips")), api(ruta(RECURSO, d.id_disp, "macs")),
  ]);
  const secciones = seccionesDispositivo(base, proveedores, d);
  const soloLectura = !ctx.esAdmin;
  const campos = todosLosCampos(secciones);

  panel.innerHTML = `
    <form class="panel" novalidate>
      <div class="panel__cuerpo">
        ${soloLectura ? `<div class="aviso aviso--ocre" style="margin-bottom:18px">${icono("candado")}<span>Solo un administrador puede modificar estos datos.</span></div>` : ""}
        <div data-error hidden style="margin-bottom:18px"></div>
        ${seccionesHTML(secciones.slice(0, 2), d, soloLectura)}
        ${seccionDireccionesHTML(soloLectura)}
        ${seccionesHTML(secciones.slice(2), d, soloLectura)}
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
      <div class="panel__cabeza"><h2>Acciones sobre el dispositivo</h2></div>
      <div class="fila-riesgo">
        <div><strong>Eliminar definitivamente</strong>
          <p>Borra el dispositivo con sus direcciones IP y MAC, sus documentos y archivos. No se puede deshacer. Si solo se retiró de servicio, use Desactivar.</p></div>
        <button type="button" class="btn btn--peligro-suave" data-eliminar>${icono("borrar")}Eliminar dispositivo</button>
      </div>
    </section>` : ""}`;

  const form = panel.querySelector("form");
  const caja = form.querySelector("[data-error]");
  prepararNumeros(form);
  enlazarEdificio(form, base.edificios, ctx.esAdmin);
  pintarDirecciones(form, { ips, macs }, soloLectura);
  if (!soloLectura) enlazarDirecciones(form);
  await enlazarEquipo(form, base, d, soloLectura);

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
      r = await api(ruta(RECURSO, d.id_disp), { metodo: "PUT", datos: { ...leerCampos(form, campos), ...direcciones.datos } });
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
        <p>Cada marca pertenece a un tipo de dispositivo y tiene sus propios modelos. Una marca que fabrica varios tipos (por ejemplo CISCO) se registra una vez por cada tipo.</p></div>
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

  const tipos = await filasCatalogo("tipos-dispositivos");
  if (!ctx.vigente()) return;
  selTipo.insertAdjacentHTML("beforeend", [...tipos].sort((a, b) => a.tipo_disp - b.tipo_disp)
    .map((t) => `<option value="${t.tipo_disp}">${esc(t.descripcion)}</option>`).join(""));
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
          { titulo: "", clase: "col-acciones", html: (x) => `<a class="btn btn--fantasma btn--sm" href="#/red/dispositivos?id_marca=${x.id_marca}&tipo_disp=${x.tipo_disp}" title="Ver dispositivos de esta marca">${icono("red")}<span class="visualmente-oculto">Dispositivos</span></a>${admin ? botonesFila({ etiqueta: x.descripcion }) : ""}` },
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
        { nombre: "tipo_disp", etiqueta: "Tipo de dispositivo", tipo: "select", requerido: true, entero: true, opciones: opciones(tipos, "tipo_disp") },
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
    visibles = q ? filas.filter((f) => normalizar(`${f.descripcion} ${f.otras_senas || ""}`).includes(q)) : filas;
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
        html: (f) => `<div class="persona"><span class="insignia-tipo" aria-hidden="true">${icono("edificio")}</span><div><strong>${esc(f.descripcion)}</strong>${f.otras_senas ? `<span class="secundario">${esc(f.otras_senas)}</span>` : ""}</div></div>`,
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
