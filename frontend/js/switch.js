// Frente de los switches con sus puertos: al pasar el mouse por un puerto,
// un resumen del equipo conectado; al hacer clic, debajo del switch, la
// información completa del equipo y (administradores) el formulario para
// asignar el equipo del inventario, el estado, la VLAN y la nota del puerto.
// Se usa en la pestaña «Puertos» de la ficha de un switch, en la página
// «Switches» del módulo y en la ficha del equipo conectado («Conectado a…»).
// APIs: /api/dispositivos/<id>/puertos/, /switches/ y /<id>/conexiones/.
import { api, ErrorApi, ruta } from "./api.js";
import { botonCargando, cargandoHTML, confirmar, debounce, errorHTML, esc, fecha, icono, toast, vacioHTML } from "./ui.js";
import { CAT, datosCompletos, formatearMac, iconoTipo, insigniaTipo, marcaAparte, tituloDispositivo } from "./dispositivos.js";
import { descargarTexto, marcaArchivo, textoCsv } from "./logs_ui.js";

const ESTADOS = {
  EN_USO: { texto: "En uso", clase: "en-uso" },
  LIBRE: { texto: "Libre", clase: "libre" },
  DESHABILITADO: { texto: "Deshabilitado", clase: "deshabilitado" },
  DANADO: { texto: "Dañado", clase: "danado" },
};
// Colores del frente (y de la leyenda): el ámbar es para revisar
const LEYENDA = [
  ["en-uso", "Equipo del inventario conectado"],
  ["revisar", "En uso sin equipo registrado, o equipo dado de baja"],
  ["danado", "Dañado"],
  ["deshabilitado", "Deshabilitado"],
  ["libre", "Libre"],
];

const lista = (texto) => String(texto || "").split(",").map((x) => x.trim()).filter(Boolean);
const titulo = (t) => String(t || "").toLowerCase().replace(/(^|[\s(-])(\p{L})/gu, (m, a, b) => a + b.toUpperCase());
const clave = (tipo, num) => `${tipo}${num}`;

/** ¿El equipo muestra el frente con puertos? (equipos de red con puertos) */
export const tienePuertos = (d) => d.id_categoria === CAT.RED && (Number(d.cant_ptos_ethernet) || 0) + (Number(d.cant_ptos_sfp) || 0) > 0;

/** Nombre corto del switch: su nombre en la red o la serie. */
export const nombreSwitch = (sw) => sw.nombre_equipo || sw.switch_nombre || `Serie ${sw.serie || sw.switch_serie}`;

/* =====================================================================
   Puertos del switch: rótulos y distribución
   ===================================================================== */
/** Rótulo impreso: 12; combo 45T y 45F; si no, los SFP siguen (49, 50…). */
export function rotuloPuerto(sw, tipo, num) {
  const eth = Number(sw.cant_ptos_ethernet) || 0;
  const sfp = Number(sw.cant_ptos_sfp) || 0;
  const combo = Boolean(sw.sfp_combo) && sfp > 0;
  const base = Math.max(eth - sfp, 0);
  if (tipo === "F") return combo ? `${base + num}F` : String(eth + num);
  return combo && num > base ? `${num}T` : String(num);
}

/** Columnas de un grupo de puertos: impares arriba y pares abajo (una fila si son pocos). */
function columnas(cantidad, dosFilas) {
  const cols = [];
  if (!dosFilas) {
    for (let n = 1; n <= cantidad; n++) cols.push([n]);
    return cols;
  }
  for (let n = 1; n <= cantidad; n += 2) cols.push(n + 1 <= cantidad ? [n, n + 1] : [n]);
  return cols;
}

/** Bloques de columnas como en el equipo: de 8 columnas (16 puertos) o de 6 (12). */
function bloques(cols) {
  if (cols.length <= 8) return [cols];
  const ancho = cols.length % 8 === 0 ? 8 : cols.length % 6 === 0 ? 6 : 8;
  const salida = [];
  for (let i = 0; i < cols.length; i += ancho) salida.push(cols.slice(i, i + ancho));
  return salida;
}

/** Situación de un puerto para el color: en-uso, revisar, danado, deshabilitado o libre. */
function situacion(p) {
  if (!p) return "libre";
  if (p.estado === "DANADO") return "danado";
  if (p.estado === "DESHABILITADO") return "deshabilitado";
  if (p.estado === "EN_USO") return p.id_disp && p.activo !== false ? "en-uso" : "revisar";
  return "libre";
}

function cuentas(sw, puertos) {
  const c = { "en-uso": 0, revisar: 0, danado: 0, deshabilitado: 0, libre: 0 };
  const eth = Number(sw.cant_ptos_ethernet) || 0;
  const sfp = Number(sw.cant_ptos_sfp) || 0;
  const mapa = porClave(puertos);
  for (let n = 1; n <= eth; n++) c[situacion(mapa.get(clave("T", n)))]++;
  for (let n = 1; n <= sfp; n++) c[situacion(mapa.get(clave("F", n)))]++;
  return { ...c, total: eth + sfp };
}

const porClave = (puertos) => new Map(puertos.filter((p) => !p.fuera_de_rango).map((p) => [clave(p.tipo_puerto, p.num_puerto), p]));

/* =====================================================================
   Dibujo del frente
   ===================================================================== */
function puertoHTML(sw, mapa, tipo, num, arriba) {
  const p = mapa.get(clave(tipo, num));
  const sit = situacion(p);
  const rot = rotuloPuerto(sw, tipo, num);
  const ic = p?.id_disp ? icono(iconoTipo(p.tipo_dispositivo, p.id_categoria), "puerto__ic") : sit === "danado" ? icono("cerrar", "puerto__ic") : "";
  const que = p?.id_disp ? `${p.tipo_dispositivo || "Equipo"} ${p.nombre_equipo || p.serie || ""}`.trim() : ESTADOS[p?.estado || "LIBRE"].texto;
  return `<button type="button" class="puerto puerto--${tipo === "F" ? "sfp" : "rj45"} puerto--${sit} ${arriba ? "puerto--arriba" : "puerto--abajo"}"
    data-puerto="${tipo}:${num}" tabindex="-1" aria-label="Puerto ${esc(rot)}: ${esc(que)}">${ic}</button>`;
}

function grupoHTML(sw, mapa, tipo, cantidad, combo) {
  const dosFilas = cantidad > (tipo === "F" ? 1 : 8);
  const base = Math.max((Number(sw.cant_ptos_ethernet) || 0) - (Number(sw.cant_ptos_sfp) || 0), 0);
  const esCombo = (n) => combo && (tipo === "F" || n > base);
  return bloques(columnas(cantidad, dosFilas)).map((cols) => `
    <div class="frente__bloque${tipo === "F" ? " frente__bloque--sfp" : ""}">
      ${cols.map(([a, b]) => `
        <div class="frente__col">
          <span class="frente__num${esCombo(a) ? " frente__num--combo" : ""}">${esc(rotuloPuerto(sw, tipo, a))}</span>
          ${puertoHTML(sw, mapa, tipo, a, true)}
          ${b ? `${puertoHTML(sw, mapa, tipo, b, false)}<span class="frente__num${esCombo(b) ? " frente__num--combo" : ""}">${esc(rotuloPuerto(sw, tipo, b))}</span>`
            : dosFilas ? `<span class="puerto puerto--vacio" aria-hidden="true"></span><span class="frente__num"></span>` : ""}
        </div>`).join("")}
    </div>`).join("");
}

/** El frente del switch (HTML). */
function frenteHTML(sw, puertos) {
  const eth = Number(sw.cant_ptos_ethernet) || 0;
  const sfp = Number(sw.cant_ptos_sfp) || 0;
  const combo = Boolean(sw.sfp_combo) && sfp > 0;
  const mapa = porClave(puertos);
  const marca = String(sw.marca || "").replace(/^D-?LINK$/i, "D-Link");
  const modelo = String(sw.modelo || "").replace(new RegExp(`^${String(sw.marca || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*`, "i"), "");
  return `
    <div class="frente" role="group" aria-label="Frente de ${esc(nombreSwitch(sw))}: ${eth} puertos de cobre${sfp ? ` y ${sfp} SFP` : ""}">
      <span class="frente__oreja" aria-hidden="true"></span>
      <div class="frente__marca" aria-hidden="true">
        <strong>${esc(marca || sw.tipo_dispositivo || "Switch")}</strong>
        <span>${esc(modelo || sw.tipo_dispositivo || "")}</span>
        <small>${esc(nombreSwitch(sw))}</small>
        <span class="frente__leds"><i class="frente__led frente__led--on"></i>Power</span>
      </div>
      <div class="frente__puertos">
        ${eth ? `<div class="frente__grupo">${grupoHTML(sw, mapa, "T", eth, combo)}</div>` : ""}
        ${sfp ? `<div class="frente__grupo frente__grupo--sfp">${grupoHTML(sw, mapa, "F", sfp, combo)}</div>` : ""}
      </div>
      <span class="frente__oreja" aria-hidden="true"></span>
    </div>`;
}

function leyendaHTML(c) {
  return `<ul class="leyenda-puertos">${LEYENDA.map(([k, t]) => `
    <li${c[k] ? "" : ' class="leyenda-puertos--cero"'}><span class="leyenda-puertos__color puerto--${k}"></span><span>${esc(t)} <b>${c[k]}</b></span></li>`).join("")}</ul>`;
}

/** Si el frente se pasa un poco del ancho, se achica (hasta `minimo`); si
 *  aun así no cabe (celular), se desliza de lado dentro de su envoltura.
 *  `achicarSiempre`: en la vista previa se achica hasta `minimo` aunque no quepa. */
export function ajustarFrente(env, minimo = 0.8, achicarSiempre = false) {
  const frente = env?.querySelector(".frente");
  if (!frente) return;
  frente.style.zoom = "";
  const disponible = env.clientWidth - 4;
  const natural = frente.offsetWidth;
  if (!(natural > disponible && disponible > 0)) return;
  const escala = disponible / natural;
  if (escala >= minimo) frente.style.zoom = escala.toFixed(3);
  else if (achicarSiempre) frente.style.zoom = String(minimo);
}

/* =====================================================================
   Tamaño del switch en el formulario del equipo: botones rápidos y vista
   previa del frente mientras se elige (solo equipos de red)
   ===================================================================== */
const TAMANOS_COBRE = [8, 12, 16, 24, 48];
const TAMANOS_SFP = [0, 2, 4];
const MAX_VISTA = 96;   // la vista previa se dibuja hasta esta cantidad de puertos

/** Descripción del frente en palabras: cuántos puertos y cómo se numeran. */
export function resumenFrente(sw) {
  const eth = Number(sw.cant_ptos_ethernet) || 0;
  const sfp = Number(sw.cant_ptos_sfp) || 0;
  const combo = Boolean(sw.sfp_combo) && sfp > 0;
  const partes = [`${eth} ${eth === 1 ? "puerto" : "puertos"} de cobre`];
  if (sfp) {
    partes.push(combo
      ? `y ${sfp} SFP combinados con los últimos de cobre: del ${rotuloPuerto(sw, "F", 1)} al ${rotuloPuerto(sw, "F", sfp)}`
      : `y ${sfp} SFP numerados ${sfp === 1 ? `como ${eth + 1}` : `del ${eth + 1} al ${eth + sfp}`}`);
  }
  return `${partes.join(" ")}. ${eth > 8 ? "Impares arriba y pares abajo." : "En una fila."}`;
}

/**
 * Agrega a la sección «Puertos» del formulario los botones de tamaño (8, 12,
 * 16, 24, 48 de cobre; sin SFP, 2 o 4 SFP) y la vista previa del frente, que
 * se redibuja al cambiar la cantidad, el check «SFP combinados», la marca, el
 * modelo o el nombre. Devuelve { categoria(idCategoria) }: solo se muestra
 * para los equipos de red. Sin permiso de edición solo se ve la vista previa.
 */
export function enlazarDisenoSwitch(form, { soloLectura = false } = {}) {
  const seccion = form.querySelector('[data-seccion="puertos"]');
  const eth = form.elements.namedItem("cant_ptos_ethernet");
  const sfp = form.elements.namedItem("cant_ptos_sfp");
  const combo = form.elements.namedItem("sfp_combo");
  const rejilla = seccion?.querySelector(".rejilla");
  if (!rejilla || !eth || !sfp) return { categoria() {} };

  const fila = (nombre, valores, etiqueta, ayuda) => `
    <div class="diseno-switch__fila" role="group" aria-label="${esc(etiqueta)}">
      <span class="diseno-switch__etiqueta">${esc(etiqueta)}</span>
      ${valores.map((v) => `<button type="button" class="chip-alerta" data-tamano="${nombre}" data-valor="${v}" aria-pressed="false">${v === 0 ? "Sin SFP" : v}</button>`).join("")}
      <button type="button" class="chip-alerta" data-tamano="${nombre}" data-valor="otro" aria-pressed="false" title="${esc(ayuda)}">Otro</button>
    </div>`;
  const arriba = document.createElement("div");
  arriba.className = "diseno-switch";
  arriba.hidden = true;
  arriba.innerHTML = `
    <p class="diseno-switch__titulo">Tamaño del switch: elija uno de los comunes o escriba la cantidad abajo.</p>
    ${fila("cant_ptos_ethernet", TAMANOS_COBRE, "Puertos de cobre", "Escriba la cantidad en «Puertos Ethernet»")}
    ${fila("cant_ptos_sfp", TAMANOS_SFP, "Puertos SFP", "Escriba la cantidad en «Puertos SFP»")}`;
  if (!soloLectura) rejilla.before(arriba);

  const abajo = document.createElement("div");
  abajo.className = "diseno-switch__vista";
  abajo.hidden = true;
  abajo.innerHTML = `
    <p class="diseno-switch__titulo">Vista previa del frente</p>
    <div class="switch-envoltura switch-envoltura--vista" inert></div>
    <p class="diseno-switch__resumen" aria-live="polite"></p>`;
  rejilla.after(abajo);
  const env = abajo.querySelector(".switch-envoltura");
  const resumen = abajo.querySelector(".diseno-switch__resumen");

  let esRed = false;
  const cantidad = (control) => Math.max(0, Math.trunc(Number(control.value) || 0));
  const texto = (nombre) => {
    const o = form.elements.namedItem(nombre)?.selectedOptions?.[0];
    return o && o.value ? o.textContent.trim() : "";
  };

  function pintar() {
    const nEth = cantidad(eth);
    const nSfp = cantidad(sfp);
    for (const b of arriba.querySelectorAll("[data-tamano]")) {
      const cobre = b.dataset.tamano === "cant_ptos_ethernet";
      const v = cobre ? nEth : nSfp;
      const comunes = cobre ? TAMANOS_COBRE : TAMANOS_SFP;
      const lleno = (cobre ? eth : sfp).value.trim() !== "";
      b.setAttribute("aria-pressed", String(b.dataset.valor === "otro" ? lleno && !comunes.includes(v) : lleno && Number(b.dataset.valor) === v));
    }
    if (!esRed) return;
    const total = nEth + nSfp;
    if (!total) {
      env.innerHTML = "";
      resumen.textContent = soloLectura ? "Este equipo no tiene puertos registrados." : "Elija el tamaño para ver cómo queda el frente del switch.";
      return;
    }
    const sw = {
      cant_ptos_ethernet: nEth, cant_ptos_sfp: nSfp, sfp_combo: Boolean(combo?.checked) && nSfp > 0,
      marca: texto("id_marca"), modelo: texto("id_modelo"), tipo_dispositivo: texto("tipo_disp"),
      nombre_equipo: (form.elements.namedItem("nombre_equipo")?.value || "").trim().toUpperCase(),
      serie: (form.elements.namedItem("serie")?.value || "").trim().toUpperCase() || "NUEVO",
    };
    if (total > MAX_VISTA) {
      env.innerHTML = "";
      resumen.textContent = `${resumenFrente(sw)} La vista previa se dibuja hasta ${MAX_VISTA} puertos.`;
      return;
    }
    env.innerHTML = frenteHTML(sw, []);
    ajustarFrente(env, 0.5, true);
    resumen.textContent = resumenFrente(sw);
  }

  let pendiente = 0;
  const repintar = () => { cancelAnimationFrame(pendiente); pendiente = requestAnimationFrame(pintar); };
  const DE_LA_VISTA = new Set(["cant_ptos_ethernet", "cant_ptos_sfp", "sfp_combo", "id_marca", "id_modelo", "tipo_disp", "nombre_equipo", "serie"]);
  form.addEventListener("input", (ev) => { if (DE_LA_VISTA.has(ev.target.name)) repintar(); });
  form.addEventListener("change", (ev) => { if (DE_LA_VISTA.has(ev.target.name)) repintar(); });
  arriba.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-tamano]");
    if (!b) return;
    const control = form.elements.namedItem(b.dataset.tamano);
    if (b.dataset.valor === "otro") {
      control.focus();
      control.select?.();
    } else {
      control.value = b.dataset.valor;
      control.dispatchEvent(new Event("input", { bubbles: true }));
      control.dispatchEvent(new Event("change", { bubbles: true }));
    }
    pintar();
  });
  if ("ResizeObserver" in window) {
    let ancho = 0;
    new ResizeObserver(() => { if (abajo.clientWidth && abajo.clientWidth !== ancho) { ancho = abajo.clientWidth; ajustarFrente(env, 0.5, true); } }).observe(abajo);
  }

  return {
    categoria(idCategoria) {
      esRed = idCategoria === CAT.RED;
      arriba.hidden = !esRed;
      abajo.hidden = !esRed;
      pintar();
    },
  };
}

/* =====================================================================
   Tooltip (uno para toda la página, fuera del contenedor que se desliza)
   ===================================================================== */
let tooltip = null;
function cajaTooltip() {
  if (!tooltip || !document.body.contains(tooltip)) {
    tooltip = document.createElement("div");
    tooltip.className = "tooltip-puerto";
    tooltip.id = "tooltip-puerto";
    tooltip.setAttribute("role", "tooltip");
    tooltip.hidden = true;
    document.body.append(tooltip);
  }
  return tooltip;
}

function pastillaEstado(p) {
  const sit = situacion(p);
  const e = ESTADOS[p?.estado || "LIBRE"];
  return `<span class="estado-puerto estado-puerto--${sit}">${esc(e.texto)}</span>`;
}

function resumenHTML(sw, tipo, num, p) {
  const rot = rotuloPuerto(sw, tipo, num);
  const cab = `<div class="tooltip-puerto__cab"><strong>Puerto ${esc(rot)}${tipo === "F" ? " · SFP" : ""}</strong>${pastillaEstado(p)}${p?.vlan ? `<span class="tooltip-puerto__vlan">VLAN ${esc(p.vlan)}</span>` : ""}</div>`;
  if (!p) return `${cab}<p class="tooltip-puerto__vacio">Sin equipo conectado.</p>`;
  const filas = [];
  if (p.id_disp) {
    const marca = marcaAparte(p);
    filas.push(`<p class="tooltip-puerto__equipo">${icono(iconoTipo(p.tipo_dispositivo, p.id_categoria), "ic--sm")}<span><b>${esc(titulo(p.tipo_dispositivo))}</b> · ${esc(tituloDispositivo(p))}${marca ? ` (${esc(marca)})` : ""}</span></p>`);
    filas.push(`<p class="dato-mono">Serie ${esc(p.serie)}${p.nombre_equipo ? ` · ${esc(p.nombre_equipo)}` : ""}</p>`);
    const ips = lista(p.ips);
    if (ips.length) filas.push(`<p class="dato-mono">${icono("web", "ic--sm")}${esc(ips.join(", "))}</p>`);
    if (p.asignado) filas.push(`<p>${icono("usuario", "ic--sm")}${esc(titulo(p.asignado))}${p.departamento ? ` · ${esc(titulo(p.departamento))}` : ""}</p>`);
    else if (p.departamento) filas.push(`<p>${icono("usuarios", "ic--sm")}${esc(titulo(p.departamento))}</p>`);
    if (p.edificio || p.ubicacion) filas.push(`<p>${icono("edificio", "ic--sm")}${esc([p.edificio, p.ubicacion].filter(Boolean).map(titulo).join(" · "))}</p>`);
    if (p.activo === false) filas.push(`<p class="tooltip-puerto__aviso">${icono("alerta", "ic--sm")}El equipo está dado de baja</p>`);
    if (p.puertos_del_equipo > 1) filas.push(`<p class="tooltip-puerto__aviso">${icono("enlace", "ic--sm")}Conectado en ${p.puertos_del_equipo} puertos</p>`);
  } else if (p.estado === "EN_USO") {
    filas.push(`<p class="tooltip-puerto__aviso">${icono("alerta", "ic--sm")}En uso, sin equipo del inventario</p>`);
  }
  if (p.nota) filas.push(`<p>${icono("etiqueta", "ic--sm")}${esc(p.nota)}</p>`);
  return `${cab}${filas.join("")}<p class="tooltip-puerto__pie">Clic para ver todo</p>`;
}

function mostrarTooltip(boton, html) {
  const t = cajaTooltip();
  t.innerHTML = html;
  t.hidden = false;
  boton.setAttribute("aria-describedby", t.id);
  const r = boton.getBoundingClientRect();
  const tr = t.getBoundingClientRect();
  const margen = 8;
  let x = r.left + r.width / 2 - tr.width / 2;
  x = Math.max(margen, Math.min(x, window.innerWidth - tr.width - margen));
  let y = r.top - tr.height - 10;
  t.classList.toggle("tooltip-puerto--abajo", y < margen);
  if (y < margen) y = r.bottom + 10;
  t.style.left = `${Math.round(x)}px`;
  t.style.top = `${Math.round(y)}px`;
}

function ocultarTooltip() {
  if (!tooltip) return;
  tooltip.hidden = true;
  document.querySelectorAll("[aria-describedby='tooltip-puerto']").forEach((b) => b.removeAttribute("aria-describedby"));
}

/* =====================================================================
   Un switch: frente + leyenda + detalle del puerto elegido
   ===================================================================== */
/**
 * Pinta el frente de un switch en `caja` y maneja tooltip, clic y teclado.
 * opciones: { esAdmin, puerto: "T12" para abrirlo, compacto, alCambiar(puertos) }
 */
export function montarSwitch(caja, sw, puertosIniciales, opciones = {}) {
  let puertos = puertosIniciales;
  let elegido = opciones.puerto || null;  // "T12"
  const esAdmin = Boolean(opciones.esAdmin);

  function pintar() {
    const c = cuentas(sw, puertos);
    const fuera = puertos.filter((p) => p.fuera_de_rango);
    caja.innerHTML = `
      <div class="switch-envoltura" tabindex="-1">${frenteHTML(sw, puertos)}</div>
      <p class="switch-desliza" hidden>${icono("derecha", "ic--sm")}Deslice el switch para ver todos los puertos</p>
      ${leyendaHTML(c)}
      ${fuera.length ? `<div class="aviso aviso--ocre">${icono("alerta")}<span>${fuera.length === 1 ? "Un puerto registrado ya no existe" : `${fuera.length} puertos registrados ya no existen`}
        en el switch (se le bajó la cantidad de puertos): ${fuera.map((p) => `<strong>${esc(p.rotulo)}</strong>${p.serie ? ` (${esc(p.serie)})` : ""}`).join(", ")}.
        ${esAdmin ? `<button type="button" class="btn btn--secundario btn--sm" data-liberar-fuera>Liberarlos</button>` : ""}</span></div>` : ""}
      <div class="detalle-puerto" data-detalle aria-live="polite"></div>`;
    ajustar();
    const botones = [...caja.querySelectorAll(".puerto[data-puerto]")];
    const primero = (elegido && caja.querySelector(`[data-puerto="${elegido[0]}:${elegido.slice(1)}"]`)) || botones[0];
    if (primero) primero.tabIndex = 0;
    if (elegido) {
      caja.querySelector(`[data-puerto="${elegido[0]}:${elegido.slice(1)}"]`)?.classList.add("puerto--elegido");
      detalle(elegido[0], Number(elegido.slice(1)));
    }
  }

  function ajustar() {
    const env = caja.querySelector(".switch-envoltura");
    if (!env) return;
    ajustarFrente(env);
    caja.querySelector(".switch-desliza").hidden = env.scrollWidth <= env.clientWidth + 1;
  }
  if ("ResizeObserver" in window) {
    let ancho = 0;
    new ResizeObserver(() => { if (caja.clientWidth !== ancho) { ancho = caja.clientWidth; ajustar(); } }).observe(caja);
  }

  const buscar = (tipo, num) => puertos.find((p) => p.tipo_puerto === tipo && p.num_puerto === num && !p.fuera_de_rango);
  const datosDe = (b) => { const [t, n] = b.dataset.puerto.split(":"); return [t, Number(n)]; };

  function elegir(tipo, num, enfocar = false) {
    elegido = clave(tipo, num);
    caja.querySelectorAll(".puerto--elegido").forEach((x) => x.classList.remove("puerto--elegido"));
    const b = caja.querySelector(`[data-puerto="${tipo}:${num}"]`);
    if (b) {
      b.classList.add("puerto--elegido");
      caja.querySelectorAll(".puerto[tabindex='0']").forEach((x) => { x.tabIndex = -1; });
      b.tabIndex = 0;
      if (enfocar) b.focus();
    }
    detalle(tipo, num);
    opciones.alElegir?.(elegido);
  }

  /* ---------------- Detalle del puerto elegido */
  async function detalle(tipo, num, editar = false) {
    const zona = caja.querySelector("[data-detalle]");
    const p = buscar(tipo, num);
    const rot = rotuloPuerto(sw, tipo, num);
    const cabeza = (extra = "") => `
      <div class="panel__cabeza">
        <div class="detalle-puerto__titulo">
          <span class="detalle-puerto__puerto puerto--${situacion(p)}" aria-hidden="true">${esc(rot)}</span>
          <div><h3>Puerto ${esc(rot)}${tipo === "F" ? " (SFP)" : ""} de ${esc(nombreSwitch(sw))}</h3>
            <p>${pastillaEstado(p)}${p?.vlan ? ` · VLAN <strong>${esc(p.vlan)}</strong>` : ""}${p?.nota ? ` · ${esc(p.nota)}` : ""}${p?.actualizado_en ? ` · actualizado el ${esc(fecha(p.actualizado_en))}` : ""}</p></div>
        </div>
        ${extra ? `<div class="detalle-puerto__acciones">${extra}</div>` : ""}
        <button type="button" class="btn-icono detalle-puerto__cerrar" data-cerrar-detalle aria-label="Cerrar el detalle">${icono("cerrar")}</button>
      </div>`;
    const accionesAdmin = esAdmin && !editar
      ? `<button type="button" class="btn btn--secundario btn--sm" data-editar>${icono("editar")}${p ? "Editar puerto" : "Asignar equipo"}</button>
         ${p ? `<button type="button" class="btn btn--secundario btn--sm" data-liberar>${icono("encender")}Liberar</button>` : ""}` : "";

    if (editar) {
      zona.innerHTML = `<section class="panel panel--puerto">${cabeza()}<div class="panel__cuerpo">${formularioHTML(p)}</div></section>`;
      enlazarFormulario(zona, tipo, num, p);
      return;
    }
    if (!p?.id_disp) {
      zona.innerHTML = `<section class="panel panel--puerto">${cabeza(accionesAdmin)}<div class="panel__cuerpo">
        ${p?.estado === "EN_USO" ? `<div class="aviso aviso--ocre">${icono("alerta")}<span>El puerto está en uso, pero no tiene asignado un equipo del inventario.${esAdmin ? " Asígnelo con «Editar puerto»." : ""}</span></div>`
          : `<p class="sin-dato">${p ? "No tiene un equipo conectado." : "Puerto libre: no tiene un equipo conectado."}${esAdmin && !p ? " Use «Asignar equipo» para registrar cuál está conectado." : ""}</p>`}
      </div></section>`;
      return;
    }
    zona.innerHTML = `<section class="panel panel--puerto">${cabeza(accionesAdmin)}<div class="panel__cuerpo">${cargandoHTML("Cargando el equipo…")}</div></section>`;
    try {
      const [d, conex] = await Promise.all([api(ruta("dispositivos", p.id_disp)), api(ruta("dispositivos", p.id_disp, "conexiones"))]);
      if (elegido !== clave(tipo, num) || !caja.isConnected) return;
      const otros = conex.filter((x) => !(x.id_switch === sw.id_disp && x.tipo_puerto === tipo && x.num_puerto === num));
      const marca = marcaAparte(d);
      zona.querySelector(".panel__cuerpo").innerHTML = `
        <div class="equipo-puerto">
          <div class="persona">${insigniaTipo(d)}<div>
            <a href="#/red/dispositivos/${d.id_disp}"><strong>${esc(tituloDispositivo(d))}</strong></a>
            <span class="secundario">${esc(d.tipo_dispositivo)}${marca ? ` · ${esc(marca)}` : ""} · Serie ${esc(d.serie)}</span></div></div>
          <a class="btn btn--secundario btn--sm" href="#/red/dispositivos/${d.id_disp}">${icono("derecha")}Abrir la ficha</a>
        </div>
        ${d.activo ? "" : `<div class="aviso aviso--ocre">${icono("alerta")}<span>El equipo está dado de baja: libere el puerto si ya no está conectado.</span></div>`}
        ${otros.length ? `<div class="aviso aviso--info">${icono("enlace")}<span>También está conectado en: ${otros.map((x) =>
          `<a href="#/red/dispositivos/${x.id_switch}/puertos?puerto=${x.tipo_puerto}${x.num_puerto}">puerto ${esc(x.rotulo)} de ${esc(nombreSwitch(x))}</a>`).join(", ")}.</span></div>` : ""}
        <dl class="lista-datos lista-datos--puerto">${datosCompletos(d).map(([t, v]) => `<div><dt>${esc(t)}</dt><dd${/IP|MAC|Serie|Placa|Nombre en la red/.test(t) ? ' class="dato-mono"' : ""}>${esc(v)}</dd></div>`).join("")}</dl>`;
    } catch (e) {
      if (!caja.isConnected) return;
      zona.querySelector(".panel__cuerpo").innerHTML = errorHTML(e instanceof ErrorApi ? e.message : "No se pudo cargar el equipo.");
    }
  }

  /* ---------------- Formulario del puerto (administradores) */
  function formularioHTML(p) {
    const estado = p?.estado || "LIBRE";
    return `
      <form class="form-puerto" novalidate>
        <div class="campo campo--completo" data-campo="id_disp">
          <label for="fp-buscar">Equipo conectado</label>
          <div class="elegir-equipo" data-elegido>${p?.id_disp ? elegidoHTML(p) : ""}</div>
          <div class="elegir-equipo__buscar"${p?.id_disp ? " hidden" : ""} data-buscador>
            <div class="elegir-equipo__filtros">
              <div class="buscador">${icono("buscar")}<input id="fp-buscar" type="search" autocomplete="off"
                placeholder="Filtrar por serie, placa, nombre en la red, IP, MAC o responsable" aria-describedby="fp-ayuda fp-total" aria-controls="fp-resultados"></div>
              <select id="fp-categoria" aria-label="Categoría de equipo"><option value="">Todas las categorías</option></select>
            </div>
            <div class="elegir-equipo__vista" role="group" aria-label="Qué equipos mostrar">
              <button type="button" class="chip-alerta" data-vista="libres" aria-pressed="true"
                title="Equipos activos que no están conectados a ningún puerto">Disponibles<b data-n="libres">…</b></button>
              <button type="button" class="chip-alerta" data-vista="todos" aria-pressed="false"
                title="También los que ya están en otro puerto (un servidor con dos tarjetas, un enlace entre switches)">Todos los activos<b data-n="todos">…</b></button>
            </div>
            <p class="elegir-equipo__total" id="fp-total" aria-live="polite">Cargando los equipos…</p>
            <ul class="elegir-equipo__resultados elegir-equipo__resultados--todos" id="fp-resultados" data-resultados aria-label="Equipos del inventario"></ul>
          </div>
          <p class="ayuda" id="fp-ayuda">Elija el equipo de la lista (escriba para filtrarla). «Disponibles» son los equipos activos que no están conectados a ningún puerto; en «Todos los activos» salen también los que ya están en otro puerto. Si el equipo no está en el inventario, deje el puerto «En uso» y descríbalo en la nota.</p>
          <p class="error-campo" hidden></p>
        </div>
        <div class="campo" data-campo="estado">
          <label for="fp-estado">Estado del puerto</label>
          <select id="fp-estado" name="estado"${p?.id_disp ? " disabled" : ""}>
            ${Object.entries(ESTADOS).map(([k, e]) => `<option value="${k}"${k === estado ? " selected" : ""}>${esc(e.texto)}</option>`).join("")}
          </select>
          <p class="ayuda" data-ayuda-estado>${p?.id_disp ? "Con un equipo conectado queda «En uso»." : "Dañado o deshabilitado: no se le puede conectar un equipo."}</p>
          <p class="error-campo" hidden></p>
        </div>
        <div class="campo" data-campo="vlan">
          <label for="fp-vlan">VLAN</label>
          <input id="fp-vlan" name="vlan" maxlength="30" value="${esc(p?.vlan || "")}" placeholder="10, 10,20 o 1-100" inputmode="numeric">
          <p class="error-campo" hidden></p>
        </div>
        <div class="campo campo--completo" data-campo="nota">
          <label for="fp-nota">Nota</label>
          <input id="fp-nota" name="nota" class="mayus" maxlength="255" value="${esc(p?.nota || "")}" placeholder="PATCH PANEL A-12, OFICINA DE CATASTRO…">
          <p class="error-campo" hidden></p>
        </div>
        <div class="form-puerto__aviso" data-aviso hidden></div>
        <div class="form-puerto__botones">
          <button type="submit" class="btn btn--primario">${icono("check")}Guardar</button>
          <button type="button" class="btn btn--secundario" data-cancelar>Cancelar</button>
        </div>
      </form>`;
  }

  function elegidoHTML(e, otros = []) {
    const ips = lista(e.ips);
    return `<div class="elegir-equipo__elegido" data-id="${e.id_disp}">
      ${insigniaTipo(e)}<span><strong>${esc(tituloDispositivo(e))}</strong>
      <small>${esc(e.tipo_dispositivo || "")} · Serie ${esc(e.serie)}${e.nombre_equipo ? ` · ${esc(e.nombre_equipo)}` : ""}${ips.length ? ` · ${esc(ips[0])}` : ""}</small>
      ${otros.length ? `<small class="elegir-equipo__otro">${icono("enlace", "ic--sm")}También está conectado en ${esc(otros.join(", "))}</small>` : ""}</span>
      <button type="button" class="btn btn--secundario btn--sm" data-cambiar-equipo>${icono("editar")}Cambiar</button>
      <button type="button" class="btn btn--secundario btn--sm" data-quitar-equipo>${icono("cerrar")}Quitar</button></div>`;
  }

  function enlazarFormulario(zona, tipo, num, p) {
    const form = zona.querySelector("form");
    const elegidoCaja = form.querySelector("[data-elegido]");
    const buscador = form.querySelector("[data-buscador]");
    const entrada = form.querySelector("#fp-buscar");
    const categoria = form.querySelector("#fp-categoria");
    let soloLibres = true;   // «Disponibles»: los que no están conectados a ningún puerto
    const total = form.querySelector("#fp-total");
    const resultados = form.querySelector("[data-resultados]");
    const estado = form.querySelector("#fp-estado");
    const ayudaEstado = form.querySelector("[data-ayuda-estado]");
    const aviso = form.querySelector("[data-aviso]");
    let idDisp = p?.id_disp || null;
    let todos = null;        // los equipos activos del inventario (menos este switch)
    let visibles = [];
    const conexiones = new Map();   // id_disp -> ["SW-PALACIO-01 · 7", ...] (sin este puerto)

    const plano = (x) => String(x ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
    const textoDe = (x) => plano([x.serie, x.placa, x.nombre_equipo, x.ips, x.macs, lista(x.macs).map(formatearMac).join(" "), x.asignado,
      x.departamento, x.marca, x.modelo, x.tipo_dispositivo, x.categoria, x.edificio, x.ubicacion].filter(Boolean).join(" "));
    const otrosDe = (id) => conexiones.get(id) || [];

    function pintarLista() {
      if (!todos) return;
      const q = plano(entrada.value.trim()).split(/\s+/).filter(Boolean);
      const enCategoria = todos.filter((x) => (!categoria.value || x.categoria === categoria.value) && q.every((t) => x._texto.includes(t)));
      const libres = enCategoria.filter((x) => !otrosDe(x.id_disp).length);
      visibles = soloLibres ? libres : enCategoria;
      form.querySelector('[data-n="libres"]').textContent = libres.length;
      form.querySelector('[data-n="todos"]').textContent = enCategoria.length;
      form.querySelectorAll("[data-vista]").forEach((b) => b.setAttribute("aria-pressed", String((b.dataset.vista === "libres") === soloLibres)));
      const filtrado = q.length || categoria.value;
      total.textContent = soloLibres
        ? `${visibles.length} ${visibles.length === 1 ? "equipo disponible" : "equipos disponibles"}${filtrado ? " con el filtro" : ""}`
          + (enCategoria.length > libres.length ? ` · ${enCategoria.length - libres.length} ya conectados a otro puerto` : "")
        : `${visibles.length} ${visibles.length === 1 ? "equipo activo" : "equipos activos"}${filtrado ? " con el filtro" : ""} · ${libres.length} disponibles`;
      // Agrupados por categoría (con su encabezado), en el orden de la lista
      let grupo = null;
      const filas = [];
      visibles.forEach((x, i) => {
        if (x.categoria !== grupo) {
          grupo = x.categoria;
          const n = visibles.filter((y) => y.categoria === grupo).length;
          filas.push(`<li class="elegir-equipo__grupo" aria-hidden="true">${esc(titulo(grupo))} <span>${n}</span></li>`);
        }
        const ips = lista(x.ips);
        const otros = otrosDe(x.id_disp);
        filas.push(`<li><button type="button" data-resultado="${i}"${x.id_disp === idDisp ? ' aria-current="true"' : ""}>${insigniaTipo(x)}<span><strong>${esc(tituloDispositivo(x))}</strong>
          <small>${esc(x.tipo_dispositivo)} · Serie ${esc(x.serie)}${x.nombre_equipo ? ` · ${esc(x.nombre_equipo)}` : ""}${ips.length ? ` · ${esc(ips[0])}` : ""}${x.asignado ? ` · ${esc(titulo(x.asignado))}` : ""}${x.edificio ? ` · ${esc(titulo(x.edificio))}` : ""}</small></span>
          ${otros.length ? `<span class="elegir-equipo__conectado" title="Ya está conectado en ${esc(otros.join(", "))}">${icono("switch", "ic--sm")}${esc(otros[0])}${otros.length > 1 ? ` +${otros.length - 1}` : ""}</span>`
            : `<span class="elegir-equipo__libre">Disponible</span>`}</button></li>`);
      });
      resultados.innerHTML = filas.length ? filas.join("")
        : `<li class="elegir-equipo__nada">${soloLibres && enCategoria.length
          ? `Los ${enCategoria.length} equipos que coinciden ya están conectados a otro puerto: véalos en «Todos los activos».`
          : todos.length ? "Ningún equipo activo coincide con el filtro." : "No hay equipos activos en el inventario."}</li>`;
    }

    async function cargarEquipos() {
      try {
        const [equipos, switches] = await Promise.all([
          api("dispositivos/", { query: { activo: true } }),
          api("dispositivos/switches/", { query: { activo: "" } }),
        ]);
        for (const s_ of switches) {
          for (const x of s_.puertos) {
            if (!x.id_disp || (s_.id_disp === sw.id_disp && x.tipo_puerto === tipo && x.num_puerto === num)) continue;
            if (!conexiones.has(x.id_disp)) conexiones.set(x.id_disp, []);
            conexiones.get(x.id_disp).push(`${nombreSwitch(s_)} · ${x.rotulo}`);
          }
        }
        todos = equipos.filter((x) => x.id_disp !== sw.id_disp)
          .map((x) => ({ ...x, _texto: textoDe(x) }))
          .sort((a, b) => String(a.categoria).localeCompare(String(b.categoria), "es")
            || (otrosDe(a.id_disp).length > 0) - (otrosDe(b.id_disp).length > 0)
            || String(a.tipo_dispositivo).localeCompare(String(b.tipo_dispositivo), "es")
            || String(a.nombre_equipo || a.serie).localeCompare(String(b.nombre_equipo || b.serie), "es"));
        const cats = new Map();
        todos.forEach((x) => cats.set(x.categoria, (cats.get(x.categoria) || 0) + 1));
        categoria.innerHTML = `<option value="">Todas las categorías (${todos.length})</option>${[...cats].sort((a, b) => String(a[0]).localeCompare(String(b[0]), "es"))
          .map(([c, n]) => `<option value="${esc(c)}">${esc(titulo(c))} (${n})</option>`).join("")}`;
        pintarLista();
        if (idDisp) {
          const actual = todos.find((x) => x.id_disp === idDisp);
          if (actual) elegidoCaja.innerHTML = elegidoHTML(actual, otrosDe(idDisp));
        }
      } catch (e) {
        total.textContent = "";
        resultados.innerHTML = `<li class="elegir-equipo__nada">${esc(e instanceof ErrorApi ? e.message : "No se pudieron cargar los equipos.")}</li>`;
      }
    }

    const ponerEquipo = (e) => {
      idDisp = e ? e.id_disp : null;
      elegidoCaja.innerHTML = e ? elegidoHTML(e, otrosDe(e.id_disp)) : "";
      buscador.hidden = Boolean(e);
      estado.disabled = Boolean(e);
      if (e) estado.value = "EN_USO";
      else if (estado.value === "EN_USO" && !p?.nota) estado.value = "LIBRE";
      ayudaEstado.textContent = e ? "Con un equipo conectado queda «En uso»." : "Dañado o deshabilitado: no se le puede conectar un equipo.";
      if (!e) { pintarLista(); entrada.focus(); }
      else form.querySelector("[data-cambiar-equipo]")?.focus();
    };

    entrada.addEventListener("input", debounce(pintarLista, 120));
    categoria.addEventListener("change", pintarLista);
    entrada.addEventListener("keydown", (ev) => {
      if (ev.key === "ArrowDown") { ev.preventDefault(); resultados.querySelector("button")?.focus(); }
      if (ev.key === "Enter") { ev.preventDefault(); if (visibles.length === 1) ponerEquipo(visibles[0]); }
    });
    resultados.addEventListener("keydown", (ev) => {
      const bs = [...resultados.querySelectorAll("button")];
      const i = bs.indexOf(document.activeElement);
      if (ev.key === "ArrowDown" && i < bs.length - 1) { ev.preventDefault(); bs[i + 1].focus(); }
      if (ev.key === "ArrowUp") { ev.preventDefault(); (i > 0 ? bs[i - 1] : entrada).focus(); }
    });
    form.addEventListener("click", (ev) => {
      const r = ev.target.closest("[data-resultado]");
      if (r) ponerEquipo(visibles[Number(r.dataset.resultado)]);
      if (ev.target.closest("[data-quitar-equipo]")) ponerEquipo(null);
      const vista = ev.target.closest("[data-vista]");
      if (vista) { soloLibres = vista.dataset.vista === "libres"; pintarLista(); }
      if (ev.target.closest("[data-cambiar-equipo]")) {
        buscador.hidden = false;
        pintarLista();
        entrada.focus();
      }
      if (ev.target.closest("[data-cancelar]")) detalle(tipo, num);
    });
    form.addEventListener("submit", async (ev) => {
      ev.preventDefault();
      const boton = form.querySelector("[type=submit]");
      aviso.hidden = true;
      form.querySelectorAll(".con-error").forEach((x) => x.classList.remove("con-error"));
      form.querySelectorAll(".error-campo").forEach((x) => { x.hidden = true; });
      const datos = {
        id_disp: idDisp, estado: idDisp ? "EN_USO" : estado.value,
        vlan: form.vlan.value.trim() || null, nota: form.nota.value.trim().toUpperCase() || null,
      };
      botonCargando(boton, true);
      try {
        const r = await api(ruta("dispositivos", sw.id_disp, "puertos", tipo, num), { metodo: "PUT", datos });
        actualizar(r.puertos);
        toast(datos.id_disp || datos.estado !== "LIBRE" || datos.vlan || datos.nota
          ? `Se guardó el puerto ${rotuloPuerto(sw, tipo, num)}.` : `El puerto ${rotuloPuerto(sw, tipo, num)} quedó libre.`);
      } catch (e) {
        botonCargando(boton, false);
        if (!(e instanceof ErrorApi)) throw e;
        let marcado = false;
        for (const [campo, texto] of Object.entries(e.campos || {})) {
          const c = form.querySelector(`[data-campo="${CSS.escape(campo)}"]`);
          if (!c) continue;
          c.classList.add("con-error");
          const pe = c.querySelector(".error-campo");
          pe.textContent = texto;
          pe.hidden = false;
          marcado = true;
        }
        aviso.innerHTML = errorHTML(marcado ? "Revise los campos marcados." : e.message);
        aviso.hidden = false;
      }
    });
    (idDisp ? form.querySelector("[data-cambiar-equipo]") : entrada)?.focus();
    cargarEquipos();
  }

  function actualizar(nuevos) {
    puertos = nuevos;
    pintar();
    opciones.alCambiar?.(puertos);
  }

  async function liberar(tipo, num) {
    const rot = rotuloPuerto(sw, tipo, num);
    const p = buscar(tipo, num);
    let r = null;
    const ok = await confirmar({
      titulo: `Liberar el puerto ${rot}`,
      mensaje: `Se quitará ${p?.id_disp ? `el equipo conectado (serie ${p.serie}), ` : ""}el estado, la VLAN y la nota del puerto ${rot}. Queda en el historial.`,
      textoBoton: "Liberar", peligro: true,
      accion: async () => { r = await api(ruta("dispositivos", sw.id_disp, "puertos", tipo, num), { metodo: "DELETE" }); },
    });
    if (ok && r) { toast(`El puerto ${rot} quedó libre.`); actualizar(r.puertos); }
  }

  /* ---------------- Eventos */
  caja.addEventListener("mouseover", (ev) => {
    const b = ev.target.closest(".puerto[data-puerto]");
    if (!b) return;
    const [t, n] = datosDe(b);
    mostrarTooltip(b, resumenHTML(sw, t, n, buscar(t, n)));
  });
  caja.addEventListener("mouseout", (ev) => {
    if (ev.target.closest(".puerto[data-puerto]") && !ev.relatedTarget?.closest?.(".puerto[data-puerto]")) ocultarTooltip();
  });
  caja.addEventListener("focusin", (ev) => {
    const b = ev.target.closest(".puerto[data-puerto]");
    if (!b) return;
    const [t, n] = datosDe(b);
    mostrarTooltip(b, resumenHTML(sw, t, n, buscar(t, n)));
  });
  caja.addEventListener("focusout", (ev) => { if (ev.target.closest(".puerto[data-puerto]")) ocultarTooltip(); });
  caja.addEventListener("scroll", ocultarTooltip, true);

  caja.addEventListener("click", async (ev) => {
    const b = ev.target.closest(".puerto[data-puerto]");
    if (b) {
      ocultarTooltip();
      const [t, n] = datosDe(b);
      elegir(t, n);
      if (window.matchMedia("(max-width: 640px)").matches) caja.querySelector("[data-detalle]")?.scrollIntoView({ behavior: "smooth", block: "start" });
      return;
    }
    if (ev.target.closest("[data-cerrar-detalle]")) {
      const anterior = elegido;
      elegido = null;
      caja.querySelectorAll(".puerto--elegido").forEach((x) => x.classList.remove("puerto--elegido"));
      caja.querySelector("[data-detalle]").innerHTML = "";
      opciones.alElegir?.(null);
      if (anterior) caja.querySelector(`[data-puerto="${anterior[0]}:${anterior.slice(1)}"]`)?.focus();
      return;
    }
    if (ev.target.closest("[data-editar]") && elegido) { detalle(elegido[0], Number(elegido.slice(1)), true); return; }
    if (ev.target.closest("[data-liberar]") && elegido) { liberar(elegido[0], Number(elegido.slice(1))); return; }
    if (ev.target.closest("[data-liberar-fuera]")) {
      const fuera = puertos.filter((p) => p.fuera_de_rango);
      const ok = await confirmar({
        titulo: "Liberar los puertos que ya no existen",
        mensaje: `Se borrarán los datos de ${fuera.map((p) => p.rotulo).join(", ")}: el switch ya no tiene esos puertos.`,
        textoBoton: "Liberar", peligro: true,
        accion: async () => {
          let r = null;
          for (const p of fuera) r = await api(ruta("dispositivos", sw.id_disp, "puertos", p.tipo_puerto, p.num_puerto), { metodo: "DELETE" });
          if (r) actualizar(r.puertos);
        },
      });
      if (ok) toast("Se liberaron los puertos.");
    }
  });

  // Teclado: flechas entre puertos (izquierda/derecha en orden, arriba/abajo
  // entre el impar y el par de la misma columna); Inicio y Fin
  caja.addEventListener("keydown", (ev) => {
    const b = ev.target.closest?.(".puerto[data-puerto]");
    if (!b) return;
    if (ev.key === "Escape") { ocultarTooltip(); return; }
    const todos = [...caja.querySelectorAll(".puerto[data-puerto]")].sort((x, y) => {
      const [tx, nx] = datosDe(x); const [ty, ny] = datosDe(y);
      return tx === ty ? nx - ny : tx === "T" ? -1 : 1;
    });
    const i = todos.indexOf(b);
    const [t, n] = datosDe(b);
    let sig = null;
    if (ev.key === "ArrowRight") sig = todos[i + 2] || todos[i + 1];
    else if (ev.key === "ArrowLeft") sig = todos[i - 2] || todos[i - 1];
    else if (ev.key === "ArrowDown" && n % 2 === 1) sig = caja.querySelector(`[data-puerto="${t}:${n + 1}"]`);
    else if (ev.key === "ArrowUp" && n % 2 === 0) sig = caja.querySelector(`[data-puerto="${t}:${n - 1}"]`);
    else if (ev.key === "Home") sig = todos[0];
    else if (ev.key === "End") sig = todos[todos.length - 1];
    if (!sig) return;
    ev.preventDefault();
    b.tabIndex = -1;
    sig.tabIndex = 0;
    sig.focus();
  });

  pintar();
  return {
    get puertos() { return puertos; },
    elegir,
  };
}

/* =====================================================================
   CSV de los puertos de uno o varios switches
   ===================================================================== */
function filasCsv(sw, puertos) {
  const mapa = porClave(puertos);
  const salida = [];
  const fila = (tipo, num, p) => salida.push([
    nombreSwitch(sw), sw.serie, rotuloPuerto(sw, tipo, num), tipo === "F" ? "SFP" : "Cobre", ESTADOS[p?.estado || "LIBRE"].texto, p?.vlan || "",
    p?.serie || "", p?.tipo_dispositivo || "", p ? [p.marca, p.modelo].filter(Boolean).join(" ") : "", p?.nombre_equipo || "",
    lista(p?.ips).join(" "), lista(p?.macs).map(formatearMac).join(" "), p?.asignado || "", p?.departamento || "",
    [p?.edificio, p?.ubicacion].filter(Boolean).join(" · "), p?.id_disp && p.activo === false ? "Dado de baja" : "", p?.nota || "",
  ]);
  for (let n = 1; n <= (Number(sw.cant_ptos_ethernet) || 0); n++) fila("T", n, mapa.get(clave("T", n)));
  for (let n = 1; n <= (Number(sw.cant_ptos_sfp) || 0); n++) fila("F", n, mapa.get(clave("F", n)));
  return salida;
}
const ENCABEZADO_CSV = ["Switch", "Serie del switch", "Puerto", "Tipo de puerto", "Estado", "VLAN", "Serie del equipo", "Tipo de equipo",
  "Marca y modelo", "Nombre en la red", "Direcciones IP", "Direcciones MAC", "Funcionario responsable", "Departamento", "Ubicación", "Aviso", "Nota"];

/* =====================================================================
   Pestaña «Puertos» de la ficha de un switch
   ===================================================================== */
export async function pestanaPuertos(panel, d, ctx) {
  const r = await api(ruta("dispositivos", d.id_disp, "puertos"));
  if (!ctx.vigente()) return;
  const sw = r.switch;
  const inicial = /^[TF]\d+$/.test(ctx.query?.get?.("puerto") || "") ? ctx.query.get("puerto") : null;
  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza">
        <div><h2>Puertos</h2><p>Pase el mouse por un puerto para ver qué tiene conectado; haga clic para ver el equipo completo${ctx.esAdmin ? " y asignarlo" : ""}.</p></div>
        <div class="panel__acciones">
          <button type="button" class="btn btn--secundario btn--sm" data-exportar>${icono("descargar")}Exportar (CSV)</button>
          <button type="button" class="btn btn--secundario btn--sm" data-imprimir>${icono("documento")}Imprimir</button>
        </div>
      </div>
      <div class="panel__cuerpo" data-switch></div>
    </section>`;
  const m = montarSwitch(panel.querySelector("[data-switch]"), sw, r.puertos, { esAdmin: ctx.esAdmin, puerto: inicial });
  panel.querySelector("[data-exportar]").addEventListener("click", () =>
    descargarTexto(textoCsv([ENCABEZADO_CSV, ...filasCsv(sw, m.puertos)]), `puertos_${(sw.nombre_equipo || sw.serie).replace(/[^\w-]+/g, "_")}_${marcaArchivo()}.csv`));
  panel.querySelector("[data-imprimir]").addEventListener("click", () => window.print());
}

/* =====================================================================
   Ficha del equipo conectado: «Conectado a: switch, puerto»
   ===================================================================== */
export async function conexionesHTML(idDisp) {
  const filas = await api(ruta("dispositivos", idDisp, "conexiones"));
  return filas.map((x) => `<a class="ficha__dato-icono" href="#/red/dispositivos/${x.id_switch}/puertos?puerto=${x.tipo_puerto}${x.num_puerto}"
    title="Conectado al puerto ${esc(x.rotulo)} de ${esc(nombreSwitch(x))}${x.vlan ? ` (VLAN ${esc(x.vlan)})` : ""}">${icono("switch", "ic--sm")}${esc(nombreSwitch(x))} · puerto ${esc(x.rotulo)}</a>`).join("");
}

/* =====================================================================
   Página «Switches»: todos los equipos de red con puertos
   ===================================================================== */
export async function vistaSwitches(cont, _params, ctx) {
  ctx.migas([{ texto: "Switches" }]);
  const q = ctx.query || new URLSearchParams();
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Switches y puertos</h1>
        <p>El frente de cada switch con lo que tiene conectado. Pase el mouse por un puerto para ver el resumen y haga clic para ver el equipo completo${ctx.esAdmin ? " o asignarlo" : ""}.</p>
      </div>
      <div class="encabezado__acciones no-imprimir">
        <button type="button" class="btn btn--secundario" data-exportar>${icono("descargar")}Exportar (CSV)</button>
        <button type="button" class="btn btn--secundario" data-imprimir>${icono("documento")}Imprimir</button>
      </div>
    </div>
    <section class="panel filtros-switches no-imprimir">
      <form class="filtros" role="search" onsubmit="return false">
        <div class="campo campo--buscar"><label for="sw-buscar">Buscar</label>
          <div class="buscador">${icono("buscar")}<input id="sw-buscar" type="search" autocomplete="off" placeholder="Switch, edificio o equipo conectado (serie, nombre, IP, VLAN)" value="${esc(q.get("q") || "")}"></div></div>
        <div class="campo"><label for="sw-edificio">Edificio</label><select id="sw-edificio"><option value="">Todos</option></select></div>
        <div class="campo campo--interruptor"><label class="interruptor"><input type="checkbox" id="sw-inactivos"${q.get("inactivos") === "1" ? " checked" : ""}><span>Incluir los dados de baja</span></label></div>
      </form>
    </section>
    <div data-totales></div>
    <div data-lista>${cargandoHTML()}</div>`;

  const buscar = cont.querySelector("#sw-buscar");
  const selEdificio = cont.querySelector("#sw-edificio");
  const inactivos = cont.querySelector("#sw-inactivos");
  const caja = cont.querySelector("[data-lista]");
  const totales = cont.querySelector("[data-totales]");
  let equipos = [];

  const texto = (x) => String(x ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
  const coincide = (sw, t) => !t || [sw.serie, sw.nombre_equipo, sw.placa, sw.marca, sw.modelo, sw.edificio, sw.ubicacion, sw.ips,
    ...sw.puertos.flatMap((p) => [p.serie, p.nombre_equipo, p.ips, p.macs, p.asignado, p.nota, p.vlan && `vlan ${p.vlan}`])].some((v) => texto(v).includes(t));

  function guardarFiltros() {
    const ps = new URLSearchParams();
    if (buscar.value.trim()) ps.set("q", buscar.value.trim());
    if (selEdificio.value) ps.set("edificio", selEdificio.value);
    if (inactivos.checked) ps.set("inactivos", "1");
    history.replaceState(null, "", `#/red/switches${ps.toString() ? `?${ps}` : ""}`);
  }

  function pintar() {
    const t = texto(buscar.value.trim());
    const visibles = equipos.filter((sw) => (!selEdificio.value || String(sw.id_predio ?? "") === selEdificio.value) && coincide(sw, t));
    const suma = { total: 0, "en-uso": 0, revisar: 0, danado: 0, deshabilitado: 0, libre: 0 };
    visibles.forEach((sw) => Object.entries(cuentas(sw, sw.puertos)).forEach(([k, v]) => { suma[k] += v; }));
    totales.innerHTML = visibles.length ? `
      <div class="cifras cifras--chicas cifras--cinco">
        <div class="cifra"><b>${visibles.length}</b><span>${visibles.length === 1 ? "Equipo de red" : "Equipos de red"}</span><small>${suma.total} puertos</small></div>
        <div class="cifra cifra--ok"><b>${suma["en-uso"]}</b><span>Con equipo del inventario</span><small>${suma.total ? Math.round((suma["en-uso"] / suma.total) * 100) : 0} % de los puertos</small></div>
        <div class="cifra${suma.revisar ? " cifra--aviso" : ""}"><b>${suma.revisar}</b><span>Por revisar</span><small>En uso sin equipo, o equipo dado de baja</small></div>
        <div class="cifra${suma.danado ? " cifra--sin" : ""}"><b>${suma.danado}</b><span>Dañados</span><small>${suma.deshabilitado} ${suma.deshabilitado === 1 ? "deshabilitado" : "deshabilitados"}</small></div>
        <div class="cifra"><b>${suma.libre}</b><span>Libres</span><small>${suma.total ? Math.round((suma.libre / suma.total) * 100) : 0} % de los puertos</small></div>
      </div>` : "";
    if (!equipos.length) {
      caja.innerHTML = vacioHTML({
        icono: "switch", titulo: "No hay switches con puertos",
        texto: "Registre el switch como equipo de red (tipo SWITCH) con la cantidad de puertos Ethernet y SFP: aquí aparecerá su frente.",
        boton: ctx.esAdmin ? `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar un switch</a>` : "",
      });
      return;
    }
    if (!visibles.length) {
      caja.innerHTML = vacioHTML({ titulo: "Ningún switch coincide", texto: "Cambie la búsqueda o el edificio." });
      return;
    }
    caja.innerHTML = visibles.map((sw) => {
      const marca = marcaAparte(sw);
      return `
      <section class="panel tarjeta-switch${sw.activo ? "" : " tarjeta-switch--baja"}" data-id="${sw.id_disp}">
        <div class="panel__cabeza">
          <div class="persona">${insigniaTipo({ ...sw, id_categoria: CAT.RED })}<div>
            <h2><a href="#/red/dispositivos/${sw.id_disp}/puertos">${esc(nombreSwitch(sw))}</a>${sw.activo ? "" : ' <span class="pastilla pastilla--inactivo">Dado de baja</span>'}</h2>
            <p>${esc([sw.tipo_dispositivo, [tituloDispositivo(sw), marca && `(${marca})`].filter(Boolean).join(" "), `Serie ${sw.serie}`].join(" · "))}
              ${sw.ips ? ` · <span class="dato-mono">${esc(lista(sw.ips).join(", "))}</span>` : ""}
              ${sw.edificio || sw.ubicacion ? ` · ${icono("edificio", "ic--sm")}${esc([sw.edificio, sw.ubicacion].filter(Boolean).map(titulo).join(" · "))}` : ""}</p>
          </div></div>
          <a class="btn btn--secundario btn--sm no-imprimir" href="#/red/dispositivos/${sw.id_disp}/puertos">${icono("derecha")}Abrir la ficha</a>
        </div>
        <div class="panel__cuerpo" data-switch></div>
      </section>`;
    }).join("");
    for (const sw of visibles) {
      const zona = caja.querySelector(`[data-id="${sw.id_disp}"] [data-switch]`);
      montarSwitch(zona, sw, sw.puertos, {
        esAdmin: ctx.esAdmin,
        alCambiar: (nuevos) => { sw.puertos = nuevos; },
      });
    }
  }

  async function cargar() {
    caja.innerHTML = cargandoHTML();
    try {
      const [lista_, edificios] = await Promise.all([
        api("dispositivos/switches/", { query: { activo: inactivos.checked ? "" : "true" } }),
        api("dispositivos/edificios/").catch(() => []),
      ]);
      if (!ctx.vigente()) return;
      equipos = lista_;
      const elegido = selEdificio.value || q.get("edificio") || "";
      const conSwitch = new Set(equipos.map((s) => String(s.id_predio ?? "")));
      selEdificio.innerHTML = `<option value="">Todos</option>${edificios.filter((e) => conSwitch.has(String(e.id_predio)))
        .map((e) => `<option value="${e.id_predio}"${String(e.id_predio) === elegido ? " selected" : ""}>${esc(titulo(e.descripcion))}</option>`).join("")}`;
      pintar();
    } catch (e) {
      if (!ctx.vigente()) return;
      caja.innerHTML = errorHTML(e instanceof ErrorApi ? e.message : "No se pudieron cargar los switches.");
    }
  }

  buscar.addEventListener("input", debounce(() => { guardarFiltros(); pintar(); }, 200));
  selEdificio.addEventListener("change", () => { guardarFiltros(); pintar(); });
  inactivos.addEventListener("change", () => { guardarFiltros(); cargar(); });
  cont.querySelector("[data-imprimir]").addEventListener("click", () => window.print());
  cont.querySelector("[data-exportar]").addEventListener("click", () => {
    if (!equipos.length) { toast("No hay switches para exportar.", "error"); return; }
    const t = texto(buscar.value.trim());
    const visibles = equipos.filter((sw) => (!selEdificio.value || String(sw.id_predio ?? "") === selEdificio.value) && coincide(sw, t));
    descargarTexto(textoCsv([ENCABEZADO_CSV, ...visibles.flatMap((sw) => filasCsv(sw, sw.puertos))]), `switches_puertos_${marcaArchivo()}.csv`);
  });
  await cargar();
}
