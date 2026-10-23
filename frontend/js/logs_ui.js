// Piezas compartidas del módulo de análisis de logs: catálogo de campos,
// formatos, barra de filtro estilo Wireshark, gráficos, globos de ayuda
// y el detalle de un evento (cajón lateral).
import { api } from "./api.js";
import { debounce, esc, icono, toast } from "./ui.js";

/* =====================================================================
   Catálogo de campos (GET logs/campos/): etiquetas, grupos, tipos,
   alias de cada programa y nombres del filtro. Se pide una vez.
   ===================================================================== */
let catalogo = null;

export function catalogoCampos() {
  if (!catalogo) catalogo = api("logs/campos/").then(prepararCatalogo).catch((e) => { catalogo = null; throw e; });
  return catalogo;
}

/** Después de cambiar un alias, para que se vuelva a pedir. */
export function olvidarCatalogo() { catalogo = null; }

function prepararCatalogo(r) {
  const porCampo = {};
  const deOrigen = {};      // fuente -> { nombre en el log: campo común }
  for (const c of r.campos) {
    porCampo[c.campo] = c;
    for (const a of c.alias) (deOrigen[a.fuente] ||= {})[a.nombre] ??= c.campo;
  }
  const etiqueta = (c) => porCampo[c]?.etiqueta || c;
  const sugerencias = [];
  const visto = new Set();
  const agregar = (nombre, texto, grupo = "") => {
    if (visto.has(nombre)) return;
    visto.add(nombre);
    sugerencias.push({ nombre, texto, grupo });
  };
  for (const c of r.campos) agregar(c.campo, c.etiqueta, c.grupo);
  for (const [k, t] of Object.entries(r.virtuales)) agregar(k, t, "Inventario");
  for (const [k, lista] of Object.entries(r.ambos)) agregar(k, `Origen o destino (${lista.map(etiqueta).join(", ")})`, "Origen");
  for (const c of r.campos) for (const f of c.filtro) agregar(f, `${c.etiqueta} · estilo Wireshark`, c.grupo);
  agregar("importacion", "Número de importación", "General");
  agregar("datos.", "Cualquier campo original del log: datos.hb_status", "General");
  for (const c of r.campos) for (const a of c.alias) agregar(a.nombre, `${c.etiqueta} · nombre en ${r.fuentes[a.fuente] || a.fuente}`, c.grupo);
  return { ...r, porCampo, deOrigen, etiqueta, sugerencias };
}

/** Clase CSS del grupo de un campo (colores de identidad). */
const CLASE_GRUPO = {
  General: "general", "Regla y política": "regla", Usuario: "usuario", Origen: "origen",
  Destino: "destino", Web: "web", "Aplicación": "app", "Tráfico": "trafico", Inventario: "inventario",
};
export const claseGrupo = (g) => CLASE_GRUPO[g] || "general";

/* =====================================================================
   Formatos
   ===================================================================== */
const NUM = new Intl.NumberFormat("es-CR");
const COMPACTO = new Intl.NumberFormat("es-CR", { notation: "compact", maximumFractionDigits: 1 });
const F_DIA = new Intl.DateTimeFormat("es-CR", { day: "numeric", month: "short", year: "numeric" });
const F_DIA_CORTO = new Intl.DateTimeFormat("es-CR", { day: "numeric", month: "short" });
const F_HORA = new Intl.DateTimeFormat("es-CR", { hour: "2-digit", minute: "2-digit", second: "2-digit", hourCycle: "h23" });
const F_HORA_MIN = new Intl.DateTimeFormat("es-CR", { hour: "2-digit", minute: "2-digit", hourCycle: "h23" });

export const num = (v) => (v === null || v === undefined || v === "" || Number.isNaN(Number(v)) ? "—" : NUM.format(Number(v)));
export const compacto = (v) => (Math.abs(Number(v)) >= 10000 ? COMPACTO.format(Number(v)) : num(v));
/** "1 evento", "3 eventos" */
export const eventos = (n) => `${num(n)} ${Number(n) === 1 ? "evento" : "eventos"}`;
export const pct = (parte, total) => (total ? `${(100 * parte / total).toLocaleString("es-CR", { maximumFractionDigits: parte && 100 * parte / total < 1 ? 1 : 0 })} %` : "—");

export function bytes(v) {
  if (v === null || v === undefined || v === "") return "—";
  let n = Number(v);
  const u = ["B", "KB", "MB", "GB", "TB"];
  let i = 0;
  while (n >= 1024 && i < u.length - 1) { n /= 1024; i += 1; }
  return `${n.toLocaleString("es-CR", { maximumFractionDigits: i ? 1 : 0 })} ${u[i]}`;
}

/** "2026-10-22T15:58:10" (hora del firewall, sin zona) -> Date local */
export function aFecha(v) {
  if (!v) return null;
  if (v instanceof Date) return v;
  const d = new Date(typeof v === "number" ? v : String(v).replace(" ", "T"));
  return Number.isNaN(d.getTime()) ? null : d;
}
export const fechaLog = (v) => { const d = aFecha(v); return d ? `${F_DIA.format(d)} ${F_HORA.format(d)}` : "—"; };
export const diaLog = (v) => { const d = aFecha(v); return d ? F_DIA.format(d) : "—"; };
export const horaLog = (v) => { const d = aFecha(v); return d ? F_HORA.format(d) : ""; };

/** Rango legible: "22 oct 2026, 08:13 a 15:58" o "30 sept 2026 a 22 oct 2026" */
export function rangoFechas(desde, hasta) {
  const a = aFecha(desde), b = aFecha(hasta);
  if (!a) return "—";
  if (!b || a.getTime() === b.getTime()) return fechaLog(a);
  if (a.toDateString() === b.toDateString()) {
    // Mismo minuto: con segundos (15:58:09 a 15:58:10)
    const hora = F_HORA_MIN.format(a) === F_HORA_MIN.format(b) ? F_HORA : F_HORA_MIN;
    return `${F_DIA.format(a)}, ${hora.format(a)} a ${hora.format(b)}`;
  }
  return `${F_DIA.format(a)} a ${F_DIA.format(b)}`;
}

/** Date -> "2026-10-22 15:58:10" para escribir en el filtro */
export function fechaFiltro(d) {
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}

export const macGuiones = (m) => (m && /^[0-9A-F]{12}$/i.test(m) ? m.toUpperCase().match(/../g).join("-") : (m || ""));

const ACCIONES = {
  PERMITIDO: { clase: "permitido", icono: "check", texto: "Permitido" },
  DENEGADO: { clase: "denegado", icono: "cerrar", texto: "Denegado" },
  OTRO: { clase: "otro", icono: "punto-lleno", texto: "Otro" },
};
export function pastillaAccion(a, { corta = false } = {}) {
  const d = ACCIONES[String(a || "OTRO").toUpperCase()] || ACCIONES.OTRO;
  return `<span class="accion accion--${d.clase}"${corta ? ` title="${d.texto}"` : ""}>${icono(d.icono)}${corta ? "" : d.texto}</span>`;
}

/** Valor de un campo común con el formato de su tipo (HTML). */
export function valorHTML(campo, v, cat) {
  if (v === null || v === undefined || v === "") return `<span class="sin-dato">—</span>`;
  const tipo = cat?.porCampo[campo]?.tipo;
  if (tipo === "accion") return pastillaAccion(v);
  if (tipo === "fecha") return esc(fechaLog(v));
  if (tipo === "mac") return `<span class="dato-mono">${esc(macGuiones(v))}</span>`;
  if (tipo === "ip" || tipo === "puerto") return `<span class="dato-mono">${esc(v)}</span>`;
  if (campo === "bytes_enviados" || campo === "bytes_recibidos") return `${esc(bytes(v))} <span class="sin-dato">(${esc(num(v))})</span>`;
  if (tipo === "numero") return esc(num(v));
  if (campo === "url") return `<span class="dato-url">${esc(v)}</span>`;
  return esc(v);
}

/** Valor corto en una línea (listas y tops). */
export function valorCorto(campo, v, cat) {
  if (v === null || v === undefined || v === "") return "(vacío)";
  const tipo = cat?.porCampo[campo]?.tipo;
  if (tipo === "mac") return macGuiones(v);
  if (tipo === "accion") return (ACCIONES[String(v).toUpperCase()] || ACCIONES.OTRO).texto;
  return String(v);
}
export const esMono = (campo, cat) => ["ip", "mac", "puerto"].includes(cat?.porCampo[campo]?.tipo) || campo === "id_conexion";

/* =====================================================================
   Expresiones del filtro
   ===================================================================== */
const PALABRAS = new Set(["and", "or", "not", "in", "contains", "matches", "eq", "ne", "gt", "lt", "ge", "le"]);

/** Valor escrito en el filtro: sin comillas si se puede (IP, dominio, número). */
export function literal(v) {
  const s = String(v);
  if (/^[^\s(){},!=<>~"']+$/.test(s) && !PALABRAS.has(s.toLowerCase())) return s;
  return `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

/** campo == valor (o !=). Sin valor: "no tiene" / "tiene". */
export function condicion(campo, valor, excluir = false) {
  if (valor === null || valor === undefined || valor === "") return excluir ? campo : `not ${campo}`;
  if (campo === "accion") return `accion ${excluir ? "!=" : "=="} ${String(valor).toLowerCase()}`;
  if (campo === "fecha") { const d = aFecha(valor); if (d) valor = fechaFiltro(d); }
  return `${campo} ${excluir ? "!=" : "=="} ${literal(valor)}`;
}

/** Agrega una condición con "and" al filtro que ya hay. */
export function agregarCondicion(q, cond) {
  const t = String(q || "").trim();
  if (!t) return cond;
  if (t.includes(cond)) return t;
  return `${/\bor\b|\|\|/i.test(t) ? `(${t})` : t} and ${cond}`;
}

export const listaIds = (v) => [...new Set((Array.isArray(v) ? v : String(v || "").split(/[^\d]+/))
  .map(Number).filter((n) => Number.isInteger(n) && n > 0))];

/** #/logs/<ruta>?q=...&importaciones=1,2 */
export function rutaLogs(ruta, { q, importaciones, ...otros } = {}) {
  const p = new URLSearchParams();
  if (q && String(q).trim()) p.set("q", String(q).trim());
  const ids = listaIds(importaciones);
  if (ids.length) p.set("importaciones", ids.join(","));
  for (const [k, v] of Object.entries(otros)) if (v !== undefined && v !== null && v !== "") p.set(k, v);
  const qs = p.toString();
  return `#/logs/${ruta}${qs ? `?${qs}` : ""}`;
}

/** Cambia la dirección sin volver a dibujar la pantalla (para Atrás/Adelante y enlaces). */
export function reemplazarRuta(href) {
  if (location.hash !== href) history.replaceState(null, "", href);
}

/**
 * Escucha un evento en document solo mientras se ve la pantalla actual:
 * al cambiar de pantalla (hashchange) se quita solo.
 */
export function escucharDocumento(tipo, fn) {
  const control = new AbortController();
  document.addEventListener(tipo, fn, { signal: control.signal });
  window.addEventListener("hashchange", () => control.abort(), { once: true });
}

/* =====================================================================
   Descargas (exportar)
   ===================================================================== */
export async function descargar(ruta, query, nombre) {
  const blob = await api(ruta, { query, comoArchivo: true });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nombre;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export function descargarTexto(texto, nombre, tipo = "text/csv;charset=utf-8") {
  const url = URL.createObjectURL(new Blob([texto], { type: tipo }));
  const a = document.createElement("a");
  a.href = url;
  a.download = nombre;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export const marcaArchivo = () => new Date().toISOString().slice(0, 19).replace(/[-:]/g, "").replace("T", "_");

/* =====================================================================
   Globos de ayuda de los gráficos (hover y foco con teclado)
   data-globo lleva el HTML ya escapado con globoHTML().
   ===================================================================== */
let globo = null;

export function globoHTML(titulo, filas = []) {
  const html = `<strong>${esc(titulo)}</strong>${filas.map(([etq, val, clase]) =>
    `<span class="globo-dato__fila">${clase ? `<i class="muestra muestra--${clase}"></i>` : ""}<span>${esc(etq)}</span><b>${esc(val)}</b></span>`).join("")}`;
  return esc(html);
}

export function activarGlobos(raiz) {
  if (!globo) {
    globo = document.createElement("div");
    globo.className = "globo-dato";
    globo.setAttribute("role", "tooltip");
    globo.hidden = true;
    document.body.appendChild(globo);
    window.addEventListener("hashchange", () => { globo.hidden = true; });
    window.addEventListener("scroll", () => { globo.hidden = true; }, { passive: true });
  }
  const mostrar = (el, x, y) => {
    globo.innerHTML = el.dataset.globo;
    globo.hidden = false;
    const r = globo.getBoundingClientRect();
    let izq = x + 14;
    let arr = y + 16;
    if (izq + r.width > innerWidth - 8) izq = x - r.width - 14;
    if (arr + r.height > innerHeight - 8) arr = y - r.height - 12;
    globo.style.left = `${Math.max(8, izq)}px`;
    globo.style.top = `${Math.max(8, arr)}px`;
  };
  raiz.addEventListener("pointermove", (ev) => {
    const el = ev.target.closest?.("[data-globo]");
    if (!el || !raiz.contains(el)) { globo.hidden = true; return; }
    mostrar(el, ev.clientX, ev.clientY);
  });
  raiz.addEventListener("pointerleave", () => { globo.hidden = true; });
  raiz.addEventListener("focusin", (ev) => {
    const el = ev.target.closest?.("[data-globo]");
    if (!el) return;
    const r = el.getBoundingClientRect();
    mostrar(el, r.left + Math.min(r.width / 2, 40), r.bottom);
  });
  raiz.addEventListener("focusout", () => { globo.hidden = true; });
  raiz.addEventListener("click", () => { globo.hidden = true; });
}

/* =====================================================================
   Gráficos
   Colores por estado: permitido (verde), denegado (rojo), otro (gris),
   siempre con leyenda y número; nunca solo el color.
   ===================================================================== */
const PARTES = [["permitidos", "permitido", "Permitidos"], ["denegados", "denegado", "Denegados"], ["otros", "otro", "Otros"]];

function partesDe(f) {
  const p = Number(f.permitidos) || 0;
  const d = Number(f.denegados) || 0;
  const o = f.otros !== undefined ? Number(f.otros) || 0 : Math.max((Number(f.cantidad ?? f.total) || 0) - p - d, 0);
  return { permitidos: p, denegados: d, otros: o };
}

export const leyendaAccionesHTML = (extra = "") => `
  <ul class="leyenda">
    <li><i class="muestra muestra--permitido"></i>Permitidos</li>
    <li><i class="muestra muestra--denegado"></i>Denegados</li>
    <li><i class="muestra muestra--otro"></i>Otros</li>${extra}
  </ul>`;

/** Medidor 100 %: permitidos | denegados | otros, con leyenda y porcentajes. */
export function medidorAcciones(r) {
  const total = Number(r.total) || 0;
  if (!total) return "";
  const v = partesDe(r);
  const partes = PARTES.filter(([k]) => v[k] > 0);
  return `
    <div class="medidor" role="img" aria-label="${esc(PARTES.map(([k, , t]) => `${t}: ${num(v[k])}`).join(", "))}">
      ${partes.map(([k, clase, t]) => `<span class="medidor__parte medidor__parte--${clase}" style="flex-grow:${v[k]}" tabindex="0"
        data-globo="${globoHTML(t, [["Eventos", num(v[k])], ["Del total", pct(v[k], total)]])}"></span>`).join("")}
    </div>
    <ul class="leyenda leyenda--medidor">
      ${PARTES.filter(([k]) => k !== "otros" || v[k]).map(([k, clase, t]) => `<li><i class="muestra muestra--${clase}"></i>${t}<b>${num(v[k])}</b><span>${pct(v[k], total)}</span></li>`).join("")}
    </ul>`;
}

/** Barras horizontales de lo más frecuente de un campo. Cada fila es un botón. */
export function listaTopHTML(campo, filas, cat, { limite = 8 } = {}) {
  if (!filas?.length) return `<p class="top-vacio">Sin datos en este campo.</p>`;
  const lista = filas.slice(0, limite);
  const max = Math.max(...lista.map((f) => Number(f.cantidad) || 0), 1);
  const mono = esMono(campo, cat);
  return `<ol class="top">${lista.map((f) => {
    const n = Number(f.cantidad) || 0;
    const v = partesDe(f);
    const texto = valorCorto(campo, f.valor, cat);
    const globoTxt = globoHTML(texto, [
      ["Eventos", num(n)], ["Permitidos", num(v.permitidos), "permitido"], ["Denegados", num(v.denegados), "denegado"],
      ...(v.otros ? [["Otros", num(v.otros), "otro"]] : []),
      ...(f.primera ? [["Primera vez", fechaLog(f.primera)], ["Última vez", fechaLog(f.ultima)]] : []),
    ]);
    return `<li><button type="button" class="top__fila" data-top-campo="${esc(campo)}" data-top-valor="${esc(f.valor ?? "")}" data-globo="${globoTxt}"
        aria-label="${esc(`${texto}: ${eventos(n)}. Ver estos eventos`)}">
      <span class="top__valor${mono ? " dato-mono" : ""}">${esc(texto)}</span>
      <span class="top__pista"><span class="top__barra" style="width:${Math.max(n / max * 100, 1.5).toFixed(1)}%">
        ${PARTES.filter(([k]) => v[k] > 0).map(([k, clase]) => `<i class="top__seg top__seg--${clase}" style="flex-grow:${v[k]}"></i>`).join("")}
      </span></span>
      <span class="top__n">${esc(num(n))}</span>
    </button></li>`;
  }).join("")}</ol>`;
}

/** Marcas redondas del eje: 0, paso, 2 pasos... con paso 1, 2 o 5 x 10^k */
function marcasEje(max, cuantas = 3) {
  const crudo = Math.max(max, 1) / cuantas;
  const pot = 10 ** Math.floor(Math.log10(crudo));
  const paso = [1, 2, 5, 10].map((m) => m * pot).find((p) => p >= crudo) || pot * 10;
  const pasoEntero = Math.max(1, Math.round(paso));
  const marcas = [];
  for (let v = 0; v <= max + pasoEntero * 0.001 || marcas.length < 2; v += pasoEntero) marcas.push(v);
  if (marcas[marcas.length - 1] < max) marcas.push(marcas[marcas.length - 1] + pasoEntero);
  return marcas;
}

function etiquetaTiempo(d, segundos) {
  if (segundos >= 86400) return F_DIA_CORTO.format(d);
  if (segundos < 60) return `${F_DIA_CORTO.format(d)} ${F_HORA.format(d)}`;
  return `${F_DIA_CORTO.format(d)} ${F_HORA_MIN.format(d)}`;
}

function rutaColumna(x, y, w, h, r) {
  r = Math.min(r, w / 2, h);
  if (r <= 0) return `M${x},${y}h${w}v${h}h${-w}Z`;
  return `M${x},${y + h}V${y + r}Q${x},${y} ${x + r},${y}H${x + w - r}Q${x + w},${y} ${x + w},${y + r}V${y + h}Z`;
}

/**
 * Línea de tiempo: columnas apiladas (permitidos, denegados, otros) por
 * intervalo. Clic en una columna -> alElegir(desde, hasta).
 */
export function lineaTiempo(caja, { segundos, puntos }, alElegir) {
  if (!puntos?.length) { caja.innerHTML = `<p class="top-vacio">Sin eventos con fecha.</p>`; return; }
  // Intervalos vacíos entre medio (el servidor solo manda los que tienen eventos)
  const paso = segundos * 1000;
  const barras = [];
  puntos.forEach((p, i) => {
    const t = aFecha(p.inicio).getTime();
    barras.push({ ...p, t });
    const sig = puntos[i + 1] ? aFecha(puntos[i + 1].inicio).getTime() : null;
    for (let x = t + paso; sig && x < sig - paso / 2 && barras.length < 500; x += paso) {
      barras.push({ t: x, total: 0, permitidos: 0, denegados: 0, otros: 0 });
    }
  });

  const dibujar = () => {
    const ancho = Math.max(caja.clientWidth, 300);
    const alto = 210;
    const m = { izq: 46, der: 10, arriba: 12, abajo: 28 };
    const w = ancho - m.izq - m.der;
    const h = alto - m.arriba - m.abajo;
    const max = Math.max(...barras.map((b) => Number(b.total) || 0), 1);
    const marcas = marcasEje(max);
    const tope = marcas[marcas.length - 1];
    const y = (v) => m.arriba + h - (v / tope) * h;
    const ranura = w / barras.length;
    const bw = Math.max(2, Math.min(24, ranura * 0.72));

    let svg = "";
    for (const v of marcas) {
      svg += `<line class="eje__guia${v === 0 ? " eje__base" : ""}" x1="${m.izq}" x2="${ancho - m.der}" y1="${y(v)}" y2="${y(v)}"/>`;
      svg += `<text class="eje__texto" x="${m.izq - 8}" y="${y(v) + 4}" text-anchor="end">${esc(compacto(v))}</text>`;
    }
    barras.forEach((b, i) => {
      const x = m.izq + i * ranura + (ranura - bw) / 2;
      const v = partesDe(b);
      const total = Number(b.total) || 0;
      // de abajo hacia arriba, con 2 px de separación entre partes
      const presentes = PARTES.filter(([k]) => v[k] > 0);
      let base = y(0);
      presentes.forEach(([k, clase], j) => {
        let alt = (v[k] / tope) * h;
        const ultima = j === presentes.length - 1;
        const hueco = j > 0 ? 2 : 0;
        alt = Math.max(alt - hueco, 1);
        base -= hueco;
        svg += `<path class="col col--${clase}" d="${rutaColumna(x, base - alt, bw, alt, ultima ? 4 : 0)}"/>`;
        base -= alt;
      });
      const desde = new Date(b.t);
      const hasta = new Date(b.t + paso);
      const titulo = segundos >= 86400 ? F_DIA.format(desde)
        : segundos < 60 ? `${F_DIA.format(desde)}, ${F_HORA.format(desde)}${segundos > 1 ? ` a ${F_HORA.format(hasta)}` : ""}`
          : `${F_DIA.format(desde)}, ${F_HORA_MIN.format(desde)} a ${F_HORA_MIN.format(hasta)}`;
      svg += `<rect class="col__zona" x="${m.izq + i * ranura}" y="${m.arriba}" width="${ranura}" height="${h}" tabindex="${total ? 0 : -1}"
        data-desde="${b.t}" data-hasta="${b.t + paso}" role="button" aria-label="${esc(`${titulo}: ${eventos(total)}`)}"
        data-globo="${globoHTML(titulo, [["Eventos", num(total)], ["Permitidos", num(v.permitidos), "permitido"], ["Denegados", num(v.denegados), "denegado"], ...(v.otros ? [["Otros", num(v.otros), "otro"]] : [])])}"/>`;
    });
    // Fechas del eje: primera, del medio y última
    const indices = barras.length > 2 ? [0, Math.floor((barras.length - 1) / 2), barras.length - 1] : barras.map((_, i) => i);
    // Si dos fechas se tocan (gráfico angosto), se omite la que va después
    const anchoTexto = (t) => t.length * 6.4;
    let finAnterior = -Infinity;
    indices.forEach((i, k) => {
      const x = m.izq + i * ranura + ranura / 2;
      const ancla = k === 0 && indices.length > 1 ? "start" : k === indices.length - 1 && indices.length > 1 ? "end" : "middle";
      const xa = ancla === "start" ? Math.max(x - bw / 2, m.izq) : ancla === "end" ? Math.min(x + bw / 2, ancho - m.der) : x;
      const texto = etiquetaTiempo(new Date(barras[i].t), segundos);
      const izq = ancla === "start" ? xa : ancla === "end" ? xa - anchoTexto(texto) : xa - anchoTexto(texto) / 2;
      if (izq < finAnterior + 12) return;
      finAnterior = izq + anchoTexto(texto);
      svg += `<text class="eje__texto" x="${xa}" y="${alto - 8}" text-anchor="${ancla}">${esc(texto)}</text>`;
    });
    caja.innerHTML = `<svg class="grafico-tiempo" width="${ancho}" height="${alto}" viewBox="0 0 ${ancho} ${alto}" role="group" aria-label="Eventos por intervalo de tiempo">${svg}</svg>`;
  };
  dibujar();
  const redibujar = debounce(dibujar, 150);
  if ("ResizeObserver" in window) {
    let ultimo = caja.clientWidth;
    new ResizeObserver(() => { if (Math.abs(caja.clientWidth - ultimo) > 4) { ultimo = caja.clientWidth; redibujar(); } }).observe(caja);
  }
  const elegir = (el) => alElegir?.(new Date(Number(el.dataset.desde)), new Date(Number(el.dataset.hasta)));
  caja.addEventListener("click", (ev) => { const el = ev.target.closest(".col__zona"); if (el) elegir(el); });
  caja.addEventListener("keydown", (ev) => {
    const el = ev.target.closest?.(".col__zona");
    if (el && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); elegir(el); }
  });
}

/** Tabla equivalente de la línea de tiempo (accesibilidad). */
export function tablaTiempoHTML({ segundos, puntos }) {
  return `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
    <thead><tr><th>Desde</th><th class="col-numero">Eventos</th><th class="col-numero">Permitidos</th><th class="col-numero">Denegados</th><th class="col-numero">Otros</th></tr></thead>
    <tbody>${puntos.map((p) => `<tr><td>${esc(segundos >= 86400 ? diaLog(p.inicio) : fechaLog(p.inicio))}</td><td class="col-numero">${num(p.total)}</td>
      <td class="col-numero">${num(p.permitidos)}</td><td class="col-numero">${num(p.denegados)}</td><td class="col-numero">${num(p.otros)}</td></tr>`).join("")}</tbody>
  </table></div>`;
}

/* =====================================================================
   Barra de filtro estilo Wireshark
   - Verde: filtro válido. Rojo: error, con el lugar exacto.
   - Sugiere nombres de campos mientras se escribe (Tab o Enter).
   - Selector de importaciones y atajos de un clic.
   ===================================================================== */
export const ATAJOS_FILTRO = [
  { texto: "Denegados", q: "accion == denegado", clase: "denegado" },
  { texto: "Permitidos", q: "accion == permitido", clase: "permitido" },
  { texto: "Firewall", q: 'tipo == "Firewall"' },
  { texto: "Web filter", q: 'tipo == "Web filter"' },
  { texto: "Equipos del inventario", q: "equipo", clase: "inventario" },
  { texto: "IP internas sin registrar", q: "(ip.src == 10.0.0.0/8 or ip.src == 172.16.0.0/12 or ip.src == 192.168.0.0/16) and not equipo_origen" },
  { texto: "Con usuario", q: "usuario" },
  { texto: "Con conexión", q: "id_conexion" },
];

export function barraFiltroHTML({ q = "", atajos = true, textoAplicar = "Aplicar" } = {}) {
  return `
    <form class="filtro-ws" data-filtro-ws novalidate role="search">
      <div class="filtro-ws__fila">
        <div class="selector-imp" data-selector-imp>
          <button type="button" class="btn btn--secundario selector-imp__boton" aria-expanded="false" aria-haspopup="true">
            ${icono("capas")}<span data-imp-texto>Todas las importaciones</span>${icono("abajo", "ic--sm")}
          </button>
          <div class="selector-imp__menu" hidden>
            <div class="selector-imp__cabeza"><strong>Importaciones</strong><button type="button" class="enlace-boton" data-imp-todas>Usar todas</button></div>
            <div class="selector-imp__lista" data-imp-lista><p class="top-vacio">Cargando…</p></div>
          </div>
        </div>
        <div class="filtro-ws__entrada" data-estado="${q ? "revisando" : "vacio"}">
          ${icono("filtro")}
          <input name="q" class="dato-mono" value="${esc(q)}" spellcheck="false" autocomplete="off" autocapitalize="off"
            placeholder="p. ej. ip.src == 10.1.10.0/24 and accion == denegado" aria-label="Filtro de eventos"
            role="combobox" aria-autocomplete="list" aria-expanded="false">
          <ul class="sugerencias" role="listbox" hidden></ul>
        </div>
        <button type="submit" class="btn btn--primario">${esc(textoAplicar)}</button>
        <button type="button" class="btn btn--fantasma" data-limpiar>Limpiar</button>
        <button type="button" class="btn-icono" data-guia title="Guía del filtro" aria-label="Guía del filtro">${icono("ayuda")}</button>
      </div>
      <div class="filtro-ws__estado" data-estado-texto aria-live="polite"></div>
      ${atajos ? `<div class="atajos-filtro" aria-label="Filtros rápidos">${ATAJOS_FILTRO.map((a, i) =>
        `<button type="button" class="atajo-filtro${a.clase ? ` atajo-filtro--${a.clase}` : ""}" data-atajo="${i}" title="${esc(a.q)}">${esc(a.texto)}</button>`).join("")}</div>` : ""}
    </form>`;
}

/**
 * Activa la barra. alAplicar({ q, importaciones }) se llama al aplicar.
 * Devuelve { q(), importaciones(), fijar(q) }.
 */
export function activarBarraFiltro(raiz, { q = "", importaciones = [], cat, alAplicar }) {
  const form = raiz.querySelector("[data-filtro-ws]");
  const entrada = form.q;
  const caja = form.querySelector(".filtro-ws__entrada");
  const estado = form.querySelector("[data-estado-texto]");
  const lista = form.querySelector(".sugerencias");
  let elegidas = listaIds(importaciones);
  let todas = [];
  let revision = 0;

  // ---------- revisión del filtro mientras se escribe
  const pintarEstado = (tipo, html) => {
    caja.dataset.estado = tipo;
    estado.innerHTML = html;
  };
  const revisar = async () => {
    const texto = entrada.value;
    const n = ++revision;
    if (!texto.trim()) { pintarEstado("vacio", ""); return true; }
    pintarEstado("revisando", "");
    try {
      const r = await api("logs/filtro/", { query: { q: texto } });
      if (n !== revision) return true;
      const usados = r.campos_usados.map((c) => cat.etiqueta(c));
      pintarEstado("ok", `${icono("check", "ic--sm")}<span>Filtro válido${usados.length ? `: ${esc(usados.join(", "))}` : ""}</span>`);
      return true;
    } catch (e) {
      if (n !== revision) return false;
      mostrarError(e);
      return false;
    }
  };
  const mostrarError = (e) => {
    const pos = Number(e.cuerpo?.posicion);
    const texto = entrada.value;
    let detalle = "";
    if (Number.isInteger(pos) && pos >= 0 && e.estado === 400) {
      const antes = texto.slice(Math.max(0, pos - 40), pos);
      const resto = texto.slice(pos, pos + 30);
      detalle = ` <code class="filtro-ws__lugar">${pos > 40 ? "…" : ""}${esc(antes)}<mark>${esc(resto || " ")}</mark></code>`;
    }
    pintarEstado("error", `${icono("alerta", "ic--sm")}<span>${esc(e.message)}${detalle}</span>`);
  };
  const revisarLuego = debounce(revisar, 320);

  // ---------- sugerencias de campos
  let opciones = [];
  let marcada = -1;
  const tokenActual = () => {
    const hasta = entrada.selectionStart ?? entrada.value.length;
    const antes = entrada.value.slice(0, hasta);
    const m = antes.match(/([A-Za-z_][\w.-]*)$/);
    if (!m) return null;
    const previo = antes.slice(0, m.index).trimEnd();
    const enPosicionDeCampo = !previo || /(\(|\band|\bor|\bnot|!|&&|\|\|)$/i.test(previo);
    return enPosicionDeCampo ? { texto: m[1], inicio: m.index, fin: hasta } : null;
  };
  const cerrarSugerencias = () => {
    lista.hidden = true;
    entrada.setAttribute("aria-expanded", "false");
    opciones = [];
    marcada = -1;
  };
  const pintarSugerencias = () => {
    const t = tokenActual();
    if (!t) { cerrarSugerencias(); return; }
    const buscado = t.texto.toLowerCase();
    opciones = cat.sugerencias
      .filter((s) => s.nombre.toLowerCase().startsWith(buscado) && s.nombre.toLowerCase() !== buscado)
      .slice(0, 8);
    if (!opciones.length) { cerrarSugerencias(); return; }
    marcada = 0;
    lista.innerHTML = opciones.map((s, i) => `<li role="option" id="sug-${i}" data-i="${i}" aria-selected="${i === 0}">
      <i class="punto-grupo punto-grupo--${claseGrupo(s.grupo)}"></i><span class="dato-mono">${esc(s.nombre)}</span><small>${esc(s.texto)}</small></li>`).join("");
    lista.hidden = false;
    entrada.setAttribute("aria-expanded", "true");
  };
  const marcar = (i) => {
    marcada = (i + opciones.length) % opciones.length;
    lista.querySelectorAll("li").forEach((li, k) => li.setAttribute("aria-selected", String(k === marcada)));
    entrada.setAttribute("aria-activedescendant", `sug-${marcada}`);
  };
  const aceptar = (i) => {
    const t = tokenActual();
    const s = opciones[i];
    if (!t || !s) return;
    const sufijo = s.nombre.endsWith(".") ? "" : " ";
    entrada.value = entrada.value.slice(0, t.inicio) + s.nombre + sufijo + entrada.value.slice(t.fin);
    const pos = t.inicio + s.nombre.length + sufijo.length;
    entrada.setSelectionRange(pos, pos);
    cerrarSugerencias();
    revisarLuego();
  };

  entrada.addEventListener("input", () => { pintarSugerencias(); revisarLuego(); });
  entrada.addEventListener("keydown", (ev) => {
    if (lista.hidden) return;
    if (ev.key === "ArrowDown") { ev.preventDefault(); marcar(marcada + 1); }
    else if (ev.key === "ArrowUp") { ev.preventDefault(); marcar(marcada - 1); }
    else if (ev.key === "Tab" || (ev.key === "Enter" && marcada >= 0)) { ev.preventDefault(); aceptar(marcada); }
    else if (ev.key === "Escape") { ev.preventDefault(); ev.stopPropagation(); cerrarSugerencias(); }
  });
  entrada.addEventListener("blur", () => setTimeout(cerrarSugerencias, 150));
  lista.addEventListener("mousedown", (ev) => {
    const li = ev.target.closest("li[data-i]");
    if (li) { ev.preventDefault(); aceptar(Number(li.dataset.i)); }
  });

  // ---------- importaciones
  const selector = form.querySelector("[data-selector-imp]");
  const botonImp = selector.querySelector(".selector-imp__boton");
  const menu = selector.querySelector(".selector-imp__menu");
  const pintarTextoImp = () => {
    const t = selector.querySelector("[data-imp-texto]");
    if (!elegidas.length) t.textContent = "Todas las importaciones";
    else if (elegidas.length === 1) {
      const imp = todas.find((x) => x.id_importacion === elegidas[0]);
      t.textContent = imp ? `N.º ${imp.id_importacion} · ${imp.nombre_archivo}` : `Importación N.º ${elegidas[0]}`;
    } else t.textContent = `${elegidas.length} importaciones`;
    botonImp.classList.toggle("selector-imp__boton--activo", elegidas.length > 0);
  };
  const pintarListaImp = () => {
    const cont = selector.querySelector("[data-imp-lista]");
    if (!todas.length) { cont.innerHTML = `<p class="top-vacio">Todavía no hay importaciones.</p>`; return; }
    cont.innerHTML = todas.map((x) => `
      <label class="selector-imp__item">
        <input type="checkbox" value="${x.id_importacion}"${elegidas.includes(x.id_importacion) ? " checked" : ""}>
        <span><strong>N.º ${x.id_importacion} · ${esc(x.nombre_archivo)}</strong>
        <small>${esc(eventos(x.total_eventos))} · ${esc(rangoFechas(x.fecha_desde, x.fecha_hasta))}${x.descripcion ? ` · ${esc(x.descripcion)}` : ""}</small></span>
      </label>`).join("");
  };
  const abrirMenu = (abrir) => {
    menu.hidden = !abrir;
    botonImp.setAttribute("aria-expanded", String(abrir));
    if (abrir) pintarListaImp();
  };
  botonImp.addEventListener("click", () => abrirMenu(menu.hidden));
  menu.addEventListener("change", (ev) => {
    if (ev.target.type !== "checkbox") return;
    const id = Number(ev.target.value);
    elegidas = ev.target.checked ? [...elegidas, id] : elegidas.filter((x) => x !== id);
    pintarTextoImp();
    aplicar();
  });
  selector.querySelector("[data-imp-todas]").addEventListener("click", () => {
    elegidas = [];
    pintarTextoImp();
    pintarListaImp();
    aplicar();
  });
  escucharDocumento("click", (ev) => { if (!selector.contains(ev.target)) abrirMenu(false); });
  form.addEventListener("keydown", (ev) => { if (ev.key === "Escape" && !menu.hidden) { abrirMenu(false); botonImp.focus(); } });
  api("logs/importaciones/").then((filas) => { todas = filas || []; pintarTextoImp(); if (!menu.hidden) pintarListaImp(); }).catch(() => {});
  pintarTextoImp();

  // ---------- aplicar
  async function aplicar() {
    cerrarSugerencias();
    alAplicar({ q: entrada.value.trim(), importaciones: [...elegidas] });
  }
  form.addEventListener("submit", (ev) => { ev.preventDefault(); aplicar(); });
  form.querySelector("[data-limpiar]").addEventListener("click", () => {
    entrada.value = "";
    pintarEstado("vacio", "");
    aplicar();
    entrada.focus();
  });
  form.querySelector("[data-guia]").addEventListener("click", () => abrirGuiaFiltro(cat, (nombre) => {
    entrada.value = agregarCondicion(entrada.value, nombre);
    revisar();
    entrada.focus();
  }));
  form.querySelectorAll("[data-atajo]").forEach((b) => b.addEventListener("click", () => {
    entrada.value = agregarCondicion(entrada.value, ATAJOS_FILTRO[Number(b.dataset.atajo)].q);
    revisar();
    aplicar();
  }));

  if (q) revisar();

  return {
    q: () => entrada.value.trim(),
    importaciones: () => [...elegidas],
    fijar(nuevo) { entrada.value = nuevo; revisar(); },
    error: mostrarError,
  };
}

/* =====================================================================
   Guía del filtro (ventana)
   ===================================================================== */
const EJEMPLOS_FILTRO = [
  ["ip.src == 10.1.10.172", "IP de origen exacta"],
  ["ip == 10.1.12.0/24", "Origen o destino dentro de una red"],
  ["accion == denegado", "Solo lo bloqueado (permitido, denegado, otro)"],
  ["dominio contains google", "Dominio que contiene un texto"],
  ["url matches \"^https://www\\.\"", "Expresión regular"],
  ["puerto_destino in {80 443 3389}", "Uno de varios valores"],
  ["tcp.dstport >= 1024", "Comparar números"],
  ["fecha >= \"2026-10-22 08:00\" and fecha < 2026-10-23", "Rango de fechas y horas"],
  ["src_ip == 10.1.10.172 && log_subtype == Denied", "Con los nombres propios de Sophos"],
  ["datos.hb_status == \"No Heartbeat\"", "Cualquier campo original del log"],
  ["equipo_origen", "El origen es un equipo del inventario"],
  ["not equipo_origen and ip.src == 10.0.0.0/8", "IP internas que no están en el inventario"],
  ["usuario and not persona", "Usuarios del log que no están en el sistema"],
  ["!(regla_id == 53) || dominio", "not / !, and / &&, or / ||, paréntesis"],
  ["google", "Texto suelto: lo busca en los campos principales"],
];

export function guiaFiltroHTML(cat) {
  const grupos = {};
  for (const c of cat.campos) (grupos[c.grupo] ||= []).push(c);
  return `
    <div class="guia-filtro">
      <p>Escriba condiciones como en Wireshark y únalas con <code>and</code>, <code>or</code> y <code>not</code>. Los nombres de campo se pueden escribir
      de tres formas: el campo común (<code>ip_origen</code>), el estilo Wireshark (<code>ip.src</code>) o el nombre que trae Sophos (<code>src_ip</code>).
      Haga clic en un ejemplo o en un campo para agregarlo al filtro.</p>
      <h3>Ejemplos</h3>
      <ul class="guia-filtro__ejemplos">${EJEMPLOS_FILTRO.map(([q, t]) =>
        `<li><button type="button" class="guia-filtro__ejemplo" data-insertar="${esc(q)}"><code>${esc(q)}</code><span>${esc(t)}</span></button></li>`).join("")}</ul>
      <h3>Operadores</h3>
      <p class="guia-filtro__ops"><code>==</code> <code>!=</code> <code>&gt;</code> <code>&lt;</code> <code>&gt;=</code> <code>&lt;=</code>
        (o <code>eq ne gt lt ge le</code>) · <code>contains</code> · <code>matches</code> o <code>~</code> · <code>in {…}</code> ·
        un campo solo significa «tiene valor». Las IP aceptan redes (<code>10.1.0.0/16</code>) y las MAC se escriben con o sin separadores.</p>
      <h3>Campos</h3>
      <div class="guia-filtro__grupos">${Object.entries(grupos).map(([g, lista]) => `
        <section class="guia-filtro__grupo guia-filtro__grupo--${claseGrupo(g)}"><h4><i class="punto-grupo punto-grupo--${claseGrupo(g)}"></i>${esc(g)}</h4>
          <ul>${lista.map((c) => `<li><button type="button" data-insertar="${esc(c.campo)}" title="${esc([c.campo, ...c.filtro, ...c.alias.map((a) => a.nombre)].join(" · "))}">
            <span>${esc(c.etiqueta)}</span><code>${esc(c.filtro[0] || c.campo)}</code></button></li>`).join("")}</ul>
        </section>`).join("")}
        <section class="guia-filtro__grupo guia-filtro__grupo--inventario"><h4><i class="punto-grupo punto-grupo--inventario"></i>Inventario y personas</h4>
          <ul>${Object.entries(cat.virtuales).map(([k, t]) => `<li><button type="button" data-insertar="${esc(k)}" title="${esc(t)}"><span>${esc(t)}</span><code>${esc(k)}</code></button></li>`).join("")}</ul>
        </section>
      </div>
    </div>`;
}

export function abrirGuiaFiltro(cat, alInsertar) {
  const d = document.createElement("dialog");
  d.className = "modal modal--guia";
  d.setAttribute("aria-labelledby", "guia-filtro-titulo");
  d.innerHTML = `
    <div class="modal__cabeza"><h2 id="guia-filtro-titulo">Guía del filtro</h2>
      <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono("cerrar")}</button></div>
    <div class="modal__cuerpo">${guiaFiltroHTML(cat)}</div>`;
  document.body.appendChild(d);
  d.addEventListener("close", () => d.remove());
  d.querySelector("[data-cerrar]").addEventListener("click", () => d.close());
  d.addEventListener("click", (ev) => {
    if (ev.target === d) { d.close(); return; }
    const b = ev.target.closest("[data-insertar]");
    if (b && alInsertar) { alInsertar(b.dataset.insertar); d.close(); }
  });
  d.showModal();
}

/* =====================================================================
   Detalle de un evento: cajón lateral
   opciones.alFiltrar(condicion): agrega la condición al filtro actual.
   Sin alFiltrar, abre el explorador con esa condición.
   ===================================================================== */
export async function abrirEvento(idEvento, opciones = {}) {
  const cat = await catalogoCampos();
  const d = document.createElement("dialog");
  d.className = "cajon";
  d.setAttribute("aria-label", "Detalle del evento");
  d.innerHTML = `<div class="cajon__contenido"><div class="cargando-bloque">Cargando el evento…</div></div>`;
  document.body.appendChild(d);
  d.addEventListener("close", () => d.remove());
  d.addEventListener("click", (ev) => { if (ev.target === d) d.close(); });
  d.showModal();
  activarGlobos(d);

  const filtrar = (cond) => {
    d.close();
    if (opciones.alFiltrar) opciones.alFiltrar(cond);
    else location.hash = rutaLogs("eventos", { q: agregarCondicion(opciones.q, cond), importaciones: opciones.importaciones });
  };

  let pestana = "comunes";
  const cargar = async (id) => {
    const caja = d.querySelector(".cajon__contenido");
    try {
      const ev = await api(`logs/eventos/${id}/`);
      if (!d.open) return;
      caja.innerHTML = eventoHTML(ev, cat, pestana);
      caja.scrollTop = 0;
      caja.querySelector("[data-cerrar]").focus();
      enlazar(caja, ev);
    } catch (e) {
      caja.innerHTML = `<div class="cajon__cabeza"><h2>Evento</h2><button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono("cerrar")}</button></div>
        <div class="cajon__cuerpo"><div class="aviso aviso--error">${icono("alerta")}<span>${esc(e.message)}</span></div></div>`;
      caja.querySelector("[data-cerrar]").addEventListener("click", () => d.close());
    }
  };

  const enlazar = (caja, ev) => {
    caja.querySelector("[data-cerrar]").addEventListener("click", () => d.close());
    caja.addEventListener("click", async (e) => {
      const f = e.target.closest("[data-filtrar]");
      if (f) { filtrar(condicion(f.dataset.filtrar, f.dataset.valor, f.dataset.excluir === "1")); return; }
      const otro = e.target.closest("[data-evento]");
      if (otro && Number(otro.dataset.evento) !== ev.id_evento) { cargar(otro.dataset.evento); return; }
      const p = e.target.closest("[data-pestana]");
      if (p) {
        pestana = p.dataset.pestana;
        caja.querySelectorAll("[data-pestana]").forEach((b) => b.setAttribute("aria-selected", String(b === p)));
        caja.querySelectorAll("[data-panel]").forEach((x) => { x.hidden = x.dataset.panel !== pestana; });
        return;
      }
      if (e.target.closest("[data-copiar-original]")) {
        const texto = Object.entries(ev.datos || {}).map(([k, v]) => `${k}="${v}"`).join("\n");
        try { await navigator.clipboard.writeText(texto); toast("Se copió el evento original."); } catch { toast("No se pudo copiar.", "error"); }
      }
      if (e.target.closest("[data-ver-conexion]")) filtrar(condicion("id_conexion", ev.id_conexion));
    });
  };

  await cargar(idEvento);
}

/** Nombre en el log del que salió cada campo común (el de mayor prioridad que traía valor). */
function origenDeCampos(ev, cat) {
  const datos = ev.datos || {};
  const salida = {};
  for (const c of cat.campos) {
    const usados = c.alias.filter((a) => a.fuente === ev.fuente && datos[a.nombre] !== undefined && datos[a.nombre] !== "")
      .sort((a, b) => a.prioridad - b.prioridad);
    if (usados.length) salida[c.campo] = usados[0].nombre;
  }
  return salida;
}

function botonesFiltro(campo, valor) {
  const v = esc(valor ?? "");
  return `<span class="acciones-dato">
    <button type="button" class="btn-dato" data-filtrar="${esc(campo)}" data-valor="${v}" title="Filtrar: solo eventos con este valor">${icono("filtro", "ic--sm")}<span>Filtrar</span></button>
    <button type="button" class="btn-dato" data-filtrar="${esc(campo)}" data-valor="${v}" data-excluir="1" title="Excluir este valor">${icono("cerrar", "ic--sm")}<span>Excluir</span></button>
  </span>`;
}

function extremoHTML(ev, lado, cat) {
  const sufijo = lado === "origen" ? "origen" : "destino";
  const ip = ev[`ip_${sufijo}`];
  const puerto = ev[`puerto_${sufijo}`];
  const mac = ev[`mac_${sufijo}`];
  const nat = ev[`ip_${sufijo}_nat`];
  const equipo = ev[`equipo_${sufijo}`];
  const idDisp = ev[`id_disp_${sufijo}`];
  const extras = [
    mac && `MAC <span class="dato-mono">${esc(macGuiones(mac))}</span>`,
    nat && `NAT <span class="dato-mono">${esc(nat)}</span>`,
    ev[`pais_${sufijo}`] && `País ${esc(ev[`pais_${sufijo}`])}`,
    ev[`zona_${sufijo}`] && `Zona ${esc(ev[`zona_${sufijo}`])}`,
    ev[lado === "origen" ? "interfaz_entrada" : "interfaz_salida"] && `Interfaz ${esc(ev[lado === "origen" ? "interfaz_entrada" : "interfaz_salida"])}`,
  ].filter(Boolean);
  const quien = lado === "origen" && ev.usuario
    ? `<span class="flujo__usuario">${icono("usuario", "ic--sm")}${ev.id_persona ? `<a href="#/usuarios/${esc(ev.id_persona)}">${esc(ev.persona || ev.usuario)}</a>` : esc(ev.usuario)}
       ${ev.id_persona ? "" : `<em>no registrado</em>`}</span>` : "";
  const sitio = lado === "destino" && (ev.dominio || ev.aplicacion)
    ? `<span class="flujo__sitio">${icono("web", "ic--sm")}<span>${esc(ev.dominio || ev.aplicacion)}</span></span>` : "";
  return `
    <div class="flujo__extremo flujo__extremo--${lado}">
      <small>${lado === "origen" ? "Origen" : "Destino"}</small>
      <strong class="dato-mono flujo__ip">${ip ? esc(ip) : "—"}${puerto ? `<span class="flujo__puerto">:${esc(puerto)}</span>` : ""}</strong>
      ${sitio}${quien}
      ${extras.length ? `<span class="flujo__extras">${extras.join(" · ")}</span>` : ""}
      ${idDisp ? `<a class="insignia-inventario" href="#/red/dispositivos/${esc(idDisp)}" title="Equipo del inventario">${icono("red", "ic--sm")}<span>${esc(equipo || `Dispositivo N.º ${idDisp}`)}</span></a>`
        : ip ? `<span class="insignia-inventario insignia-inventario--no">${icono("alerta", "ic--sm")}<span>No está en el inventario</span></span>` : ""}
    </div>`;
}

function eventoHTML(ev, cat, pestana) {
  const accion = String(ev.accion || "OTRO").toLowerCase();
  const origenes = origenDeCampos(ev, cat);
  const datos = ev.datos || {};
  const conexion = ev.conexion || [];

  // Campos comunes por grupo (solo los que tienen valor)
  const grupos = {};
  for (const c of cat.campos) {
    const v = ev[c.campo];
    if (v === null || v === undefined || v === "") continue;
    (grupos[c.grupo] ||= []).push(c);
  }
  const comunes = Object.entries(grupos).map(([g, lista]) => `
    <section class="grupo-campos grupo-campos--${claseGrupo(g)}">
      <h3><i class="punto-grupo punto-grupo--${claseGrupo(g)}"></i>${esc(g)}</h3>
      <dl>${lista.map((c) => `
        <div class="dato-log">
          <dt>${esc(c.etiqueta)}${origenes[c.campo] ? `<small class="dato-mono" title="Nombre en el log">${esc(origenes[c.campo])}</small>` : ""}</dt>
          <dd>${valorHTML(c.campo, ev[c.campo], cat)}</dd>
          ${c.campo === "fecha" ? "" : botonesFiltro(c.campo, ev[c.campo])}
        </div>`).join("")}</dl>
    </section>`).join("");

  // Campos originales con el campo común al que se asignaron
  const mapa = cat.deOrigen[ev.fuente] || {};
  const originales = Object.entries(datos);
  const asignados = originales.filter(([k]) => mapa[k]).length;
  const originalesHTML = `
    <p class="cajon__nota">${icono("enlace", "ic--sm")}<span>${asignados} de ${originales.length} campos del log se asignaron automáticamente a un campo común.
      Los demás se guardan igual y se pueden filtrar con <code>datos.nombre</code>.</span></p>
    <ul class="originales">${originales.map(([k, v]) => {
      const campo = mapa[k];
      const def = campo && cat.porCampo[campo];
      return `<li class="original${campo ? "" : " original--libre"}">
        <span class="original__clave dato-mono">${esc(k)}</span>
        <span class="original__valor dato-mono">${v === "" ? `<span class="sin-dato">(vacío)</span>` : esc(v)}</span>
        <span class="original__destino">${def ? `<span class="chip-campo chip-campo--${claseGrupo(def.grupo)}" title="Se guarda en el campo común ${esc(def.campo)}">${icono("derecha", "ic--sm")}${esc(def.etiqueta)}</span>`
          : `<span class="sin-dato">sin campo común</span>`}</span>
        ${botonesFiltro(def ? def.campo : `datos.${k}`, def ? ev[def.campo] ?? v : v)}
      </li>`;
    }).join("")}</ul>
    <div class="cajon__pie-seccion"><button type="button" class="btn btn--secundario btn--sm" data-copiar-original>${icono("documento")}Copiar el evento original</button></div>`;

  const conexionHTML = conexion.length ? `
    <p class="cajon__nota">${icono("enlace", "ic--sm")}<span>Eventos con el mismo identificador de conexión <code>${esc(ev.id_conexion)}</code>, en orden.
      Así se ve el recorrido completo: el firewall, el filtro web, la inspección SSL…</span></p>
    <ol class="recorrido">${conexion.map((x) => `
      <li class="recorrido__paso recorrido__paso--${String(x.accion || "otro").toLowerCase()}${x.id_evento === ev.id_evento ? " recorrido__paso--actual" : ""}">
        <button type="button" data-evento="${x.id_evento}">
          <span class="recorrido__hora dato-mono">${esc(horaLog(x.fecha))}</span>
          <span class="recorrido__texto"><strong>${esc(x.tipo || "Evento")}</strong>${pastillaAccion(x.accion)}
            <small>${esc([x.subtipo, x.regla_nombre && `Regla ${x.regla_id ? `${x.regla_id} · ` : ""}${x.regla_nombre}`, `Importación N.º ${x.id_importacion}`].filter(Boolean).join(" · "))}</small></span>
        </button>
      </li>`).join("")}</ol>
    <div class="cajon__pie-seccion"><button type="button" class="btn btn--secundario btn--sm" data-ver-conexion>${icono("filtro")}Ver esta conexión en el explorador</button></div>`
    : `<p class="top-vacio">${ev.id_conexion ? "No hay otros eventos de esta conexión." : "Este evento no trae identificador de conexión."}</p>`;

  const otras = Number(ev.en_otras_importaciones) || 0;
  const pest = (k, texto, n) => `<button type="button" role="tab" data-pestana="${k}" aria-selected="${pestana === k}">${texto}${n !== undefined ? `<span class="contador">${n}</span>` : ""}</button>`;
  return `
    <div class="cajon__cabeza cajon__cabeza--${accion}">
      <div class="cajon__titulo">
        ${pastillaAccion(ev.accion)}
        <h2>${esc(ev.tipo || "Evento")}${ev.subtipo ? ` <span>· ${esc(ev.subtipo)}</span>` : ""}</h2>
        <p><span class="dato-mono">${esc(fechaLog(ev.fecha))}</span> · Evento N.º ${esc(ev.id_evento)} ·
          <a href="#/logs/importaciones/${esc(ev.id_importacion)}">Importación N.º ${esc(ev.id_importacion)}</a>
          ${otras ? ` · <strong>también en ${otras} ${otras === 1 ? "importación más" : "importaciones más"}</strong>` : ""}</p>
      </div>
      <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono("cerrar")}</button>
    </div>
    <div class="cajon__cuerpo">
      <div class="flujo flujo--${accion}">
        ${extremoHTML(ev, "origen", cat)}
        <div class="flujo__medio">
          <span class="flujo__flecha">${icono("derecha")}</span>
          <span class="flujo__proto">${esc([ev.protocolo, ev.puerto_destino && `puerto ${ev.puerto_destino}`].filter(Boolean).join(" · ") || "—")}</span>
          ${ev.regla_nombre || ev.regla_id ? `<span class="flujo__regla">Regla ${esc(ev.regla_id || "")}${ev.regla_nombre ? ` · ${esc(ev.regla_nombre)}` : ""}</span>` : ""}
        </div>
        ${extremoHTML(ev, "destino", cat)}
      </div>
      ${ev.url ? `<p class="cajon__url">${icono("web", "ic--sm")}<span class="dato-url">${esc(ev.url)}</span></p>` : ""}
      <div class="pestanas pestanas--cajon" role="tablist">
        ${pest("comunes", "Campos comunes")}${pest("originales", "Log original", originales.length)}${pest("conexion", "Misma conexión", conexion.length)}
      </div>
      <div data-panel="comunes"${pestana === "comunes" ? "" : " hidden"}>${comunes}</div>
      <div data-panel="originales"${pestana === "originales" ? "" : " hidden"}>${originalesHTML}</div>
      <div data-panel="conexion"${pestana === "conexion" ? "" : " hidden"}>${conexionHTML}</div>
    </div>`;
}
