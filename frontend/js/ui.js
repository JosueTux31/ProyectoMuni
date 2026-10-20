// Componentes de interfaz: escape de HTML, íconos, avisos, modales,
// formularios generados a partir de una lista de campos y tablas.
import { ErrorApi } from "./api.js";
import { CONFIG } from "./config.js";

/* ----------------------------------------------------------- Utilidades */
const ENTIDADES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
export const esc = (v) => String(v ?? "").replace(/[&<>"']/g, (c) => ENTIDADES[c]);

export const icono = (nombre, clase = "") =>
  `<svg class="ic ${clase}" aria-hidden="true"><use href="#i-${nombre}"/></svg>`;

export function iniciales(nombre, apellido) {
  const a = (nombre || "").trim()[0] || "";
  const b = (apellido || "").trim()[0] || (nombre || "").trim().split(/\s+/)[1]?.[0] || "";
  return (a + b).toUpperCase() || "?";
}

export const nombreCompleto = (u) =>
  [u.nombre, u.apellido1, u.apellido2].filter(Boolean).join(" ");

/** Agrega la dirección del backend a las rutas /api/... que entrega el servidor. */
export const urlApi = (ruta) => (ruta ? `${CONFIG.API_BASE}${ruta}` : null);

/**
 * Avatar de una persona: su foto si tiene (foto_url o imagen_url), si no sus iniciales.
 *   avatarHTML(usuario)                        -> 36 px
 *   avatarHTML(usuario, { tam: "grande" })     -> 64 px
 *   avatarHTML(proveedor, { logo: true })      -> esquinas cuadradas, imagen completa
 */
export function avatarHTML(p, { tam = "", logo = false, clase = "" } = {}) {
  const url = urlApi(p?.foto_url || p?.imagen_url);
  const clases = ["avatar", tam && `avatar--${tam}`, logo && "avatar--logo", url && "con-imagen", clase].filter(Boolean).join(" ");
  const texto = esc(iniciales(p?.nombre, p?.apellido1));
  return `<span class="${clases}" aria-hidden="true"><span>${texto}</span>${url ? `<img src="${esc(url)}" alt="" loading="lazy" onerror="this.parentNode.classList.remove('con-imagen');this.remove()">` : ""}</span>`;
}

const relativo = new Intl.RelativeTimeFormat("es", { numeric: "auto" });
const soloHora = new Intl.DateTimeFormat("es-CR", { hour: "numeric", minute: "2-digit" });

/** "hace 5 minutos", "hace 3 horas"; después de un día, la hora. */
export function tiempoRelativo(valor) {
  const d = new Date(valor);
  if (Number.isNaN(d.getTime())) return "";
  const seg = Math.round((d.getTime() - Date.now()) / 1000);
  if (Math.abs(seg) < 45) return "hace un momento";
  if (Math.abs(seg) < 3600) return relativo.format(Math.round(seg / 60), "minute");
  if (Math.abs(seg) < 6 * 3600) return relativo.format(Math.round(seg / 3600), "hour");
  return soloHora.format(d);
}

const formatoFecha = new Intl.DateTimeFormat("es-CR", { dateStyle: "medium", timeStyle: "short" });
export function fecha(valor) {
  if (!valor) return "—";
  const d = new Date(valor);
  return Number.isNaN(d.getTime()) ? String(valor) : formatoFecha.format(d);
}

export function debounce(fn, ms = 300) {
  let t;
  return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}

export function botonCargando(boton, activo) {
  if (!boton) return;
  boton.classList.toggle("cargando", activo);
  boton.disabled = activo;
}

export const cargandoHTML = (texto = "Cargando…") => `<div class="cargando-bloque">${esc(texto)}</div>`;

export function vacioHTML({ icono: ic = "buscar", titulo, texto = "", boton = "" }) {
  return `<div class="vacio">${icono(ic)}<strong>${esc(titulo)}</strong>${texto ? `<p>${esc(texto)}</p>` : ""}${boton}</div>`;
}

export const errorHTML = (mensaje) =>
  `<div class="aviso aviso--error" role="alert">${icono("alerta")}<span>${esc(mensaje)}</span></div>`;

/* --------------------------------------------------------------- Toasts */
export function toast(mensaje, tipo = "ok") {
  const contenedor = document.getElementById("toasts");
  const el = document.createElement("div");
  el.className = `toast${tipo === "error" ? " toast--error" : ""}`;
  el.setAttribute("role", tipo === "error" ? "alert" : "status");
  el.innerHTML = `${icono(tipo === "error" ? "alerta" : "check")}<span>${esc(mensaje)}</span>`;
  contenedor.appendChild(el);
  setTimeout(() => {
    el.classList.add("saliendo");
    setTimeout(() => el.remove(), 300);
  }, tipo === "error" ? 6500 : 4000);
}

/* --------------------------------------------------------------- Modales */
let contadorModal = 0;

function crearModal({ titulo, peligro = false, ancho }) {
  const id = `modal-titulo-${++contadorModal}`;
  const dialogo = document.createElement("dialog");
  dialogo.className = `modal${peligro ? " modal--peligro" : ""}`;
  dialogo.setAttribute("aria-labelledby", id);
  if (ancho) dialogo.style.width = `min(${ancho}px, calc(100vw - 32px))`;
  dialogo.innerHTML = `
    <div class="modal__cabeza">
      <h2 id="${id}">${esc(titulo)}</h2>
      <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono("cerrar")}</button>
    </div>`;
  document.body.appendChild(dialogo);
  dialogo.addEventListener("close", () => dialogo.remove());
  dialogo.querySelector("[data-cerrar]").addEventListener("click", () => dialogo.close());
  return dialogo;
}

/**
 * Pide confirmación. Si se pasa `accion` (async), la ejecuta con el botón
 * en espera y muestra el error dentro del modal si falla.
 * Devuelve true si se confirmó (y la acción terminó bien).
 */
export function confirmar({ titulo, mensaje, textoBoton = "Confirmar", peligro = true, accion }) {
  return new Promise((resolve) => {
    const dialogo = crearModal({ titulo, peligro, ancho: 460 });
    let resultado = false;
    dialogo.insertAdjacentHTML("beforeend", `
      <div class="modal__cuerpo">
        <div data-error hidden></div>
        <p>${esc(mensaje)}</p>
      </div>
      <div class="modal__pie">
        <button type="button" class="btn btn--secundario" data-cancelar>Cancelar</button>
        <button type="button" class="btn ${peligro ? "btn--peligro" : "btn--primario"}" data-confirmar>${esc(textoBoton)}</button>
      </div>`);

    const boton = dialogo.querySelector("[data-confirmar]");
    dialogo.querySelector("[data-cancelar]").addEventListener("click", () => dialogo.close());
    dialogo.addEventListener("close", () => resolve(resultado));
    boton.addEventListener("click", async () => {
      if (!accion) { resultado = true; dialogo.close(); return; }
      botonCargando(boton, true);
      try {
        await accion();
        resultado = true;
        dialogo.close();
      } catch (e) {
        botonCargando(boton, false);
        const caja = dialogo.querySelector("[data-error]");
        caja.innerHTML = errorHTML(e instanceof ErrorApi ? e.message : "Ocurrió un error inesperado.");
        caja.hidden = false;
        if (!(e instanceof ErrorApi)) console.error(e);
      }
    });
    dialogo.showModal();
    dialogo.querySelector("[data-cancelar]").focus();
  });
}

/* ------------------------------------------------------------ Formularios
   Cada campo se describe con un objeto:
   { nombre, etiqueta, tipo: "text"|"email"|"url"|"tel"|"password"|"number"|
     "select"|"textarea"|"checkbox", requerido, max, min, entero, opciones:
     [{valor, texto}], vacioTexto, ayuda, completo, deshabilitado, autocompletar }
   --------------------------------------------------------------------- */
/* ------------------------------------------------- Mayúsculas y teléfonos
   La base de datos guarda los textos en MAYÚSCULA. Para que la persona lo
   vea desde que escribe, los campos de texto se muestran en mayúscula
   (clase .mayus) y se envían ya convertidos. No aplica a correos, páginas
   web, claves, teléfonos ni a los campos marcados con mayus: false.  */
const SIN_MAYUS = new Set(["email", "url", "password", "tel", "number", "date", "select", "checkbox"]);
export const usaMayus = (c) => c.mayus !== false && !SIN_MAYUS.has(c.tipo || "text");

/** 88881234 -> 8888-1234. Los números internacionales (con +) se dejan igual. */
export function formatearTelefono(valor) {
  const texto = String(valor ?? "").trim();
  if (texto.startsWith("+")) return texto;
  const digitos = texto.replace(/\D/g, "").slice(0, 8);
  return digitos.length > 4 ? `${digitos.slice(0, 4)}-${digitos.slice(4)}` : digitos;
}

/** Máscara 0000-0000 en todos los campos de teléfono de la página. */
export function activarMascaraTelefono(raiz = document) {
  raiz.addEventListener("input", (ev) => {
    const el = ev.target;
    if (!(el instanceof HTMLInputElement) || el.type !== "tel" || el.value.trim().startsWith("+")) return;
    const antes = el.value;
    const despues = formatearTelefono(antes);
    if (antes !== despues) {
      el.value = despues;
      el.setSelectionRange(despues.length, despues.length);
    }
  });
}

export function campoHTML(c, valor, { soloLectura = false } = {}) {
  const id = `c-${c.nombre}-${++contadorModal}`;
  const deshabilitado = soloLectura || c.deshabilitado ? "disabled" : "";
  const requerido = c.requerido && !soloLectura ? "required" : "";
  const ayuda = c.ayuda && !soloLectura ? `<p class="ayuda">${esc(c.ayuda)}</p>` : "";
  const clase = `campo${c.completo ? " campo--completo" : ""}`;
  const error = `<p class="error-campo" hidden></p>`;

  if (c.tipo === "checkbox") {
    return `<div class="${clase}" data-campo="${esc(c.nombre)}">
      <label class="interruptor"><input type="checkbox" id="${id}" name="${esc(c.nombre)}" ${valor ? "checked" : ""} ${deshabilitado}><span>${esc(c.etiqueta)}</span></label>
      ${ayuda}${error}</div>`;
  }

  let control;
  if (c.tipo === "select") {
    const actual = valor === null || valor === undefined ? "" : String(valor);
    const vacio = c.sinVacio ? "" : `<option value="">${esc(c.vacioTexto || "Seleccione…")}</option>`;
    const opciones = (c.opciones || [])
      .map((o) => `<option value="${esc(o.valor)}"${String(o.valor) === actual ? " selected" : ""}>${esc(o.texto)}</option>`)
      .join("");
    control = `<select id="${id}" name="${esc(c.nombre)}" ${requerido} ${deshabilitado}>${vacio}${opciones}</select>`;
  } else if (c.tipo === "textarea") {
    control = `<textarea id="${id}" name="${esc(c.nombre)}"${usaMayus(c) ? ' class="mayus"' : ""} ${c.max ? `maxlength="${c.max}"` : ""} ${requerido} ${deshabilitado}>${esc(valor)}</textarea>`;
  } else {
    const tipo = c.tipo || "text";
    const valorMostrado = tipo === "tel" ? formatearTelefono(valor) : valor;
    control = `<input id="${id}" name="${esc(c.nombre)}" type="${tipo}" value="${esc(valorMostrado)}"${usaMayus(c) ? ' class="mayus"' : ""}${tipo === "tel" ? ' inputmode="tel"' : ""}
      ${c.max ? `maxlength="${c.max}"` : ""} ${c.min ? `minlength="${c.min}"` : ""}
      ${c.autocompletar ? `autocomplete="${c.autocompletar}"` : tipo === "password" ? 'autocomplete="new-password"' : ""}
      ${c.placeholder && !soloLectura ? `placeholder="${esc(c.placeholder)}"` : ""}
      ${requerido} ${deshabilitado}>`;
  }

  const marca = c.requerido && !soloLectura ? ` <span class="req" aria-hidden="true">*</span>` : "";
  return `<div class="${clase}" data-campo="${esc(c.nombre)}">
    <label for="${id}">${esc(c.etiqueta)}${marca}</label>${control}${ayuda}${error}</div>`;
}

export const camposHTML = (campos, valores = {}, opciones = {}) =>
  campos.map((c) => campoHTML(c, valores[c.nombre], opciones)).join("");

export function leerCampos(form, campos) {
  const datos = {};
  for (const c of campos) {
    const el = form.elements.namedItem(c.nombre);
    if (!el) continue;
    if (c.tipo === "checkbox") { datos[c.nombre] = el.checked; continue; }
    let v = el.value;
    if (c.tipo !== "password") v = v.trim();
    if (v === "") { datos[c.nombre] = null; continue; }
    if (usaMayus(c)) v = v.toUpperCase();
    if (c.tipo === "tel") v = formatearTelefono(v);
    datos[c.nombre] = c.entero ? Number.parseInt(v, 10) : v;
  }
  return datos;
}

export function limpiarErrores(form) {
  form.querySelectorAll(".con-error").forEach((el) => el.classList.remove("con-error"));
  form.querySelectorAll(".error-campo").forEach((el) => { el.hidden = true; el.textContent = ""; });
}

/** Marca en el formulario los errores por campo que devolvió la API. */
export function mostrarErrores(form, error, cajaAviso) {
  limpiarErrores(form);
  let primero = null;
  for (const [campo, texto] of Object.entries(error.campos || {})) {
    const contenedor = form.querySelector(`[data-campo="${CSS.escape(campo)}"]`);
    if (!contenedor) continue;
    contenedor.classList.add("con-error");
    const p = contenedor.querySelector(".error-campo");
    p.textContent = texto;
    p.hidden = false;
    primero ??= contenedor.querySelector("input, select, textarea");
  }
  if (cajaAviso) {
    cajaAviso.innerHTML = errorHTML(primero ? "Revise los campos marcados." : error.message);
    cajaAviso.hidden = false;
  }
  if (primero) primero.focus();
}

/**
 * Abre un formulario en un modal. `alGuardar(datos)` hace la llamada a la
 * API; si lanza ErrorApi, el error se muestra en el mismo modal.
 * Devuelve lo que retorne alGuardar, o null si se cancela.
 */
export function abrirFormulario({
  titulo, descripcion, campos, valores = {}, textoGuardar = "Guardar",
  alGuardar, alAbrir, columnas = 1, ancho,
}) {
  return new Promise((resolve) => {
    const dialogo = crearModal({ titulo, ancho: ancho || (columnas > 1 ? 640 : 480) });
    let resultado = null;
    dialogo.insertAdjacentHTML("beforeend", `
      <form class="modal__form" novalidate>
        <div class="modal__cuerpo">
          ${descripcion ? `<p>${esc(descripcion)}</p>` : ""}
          <div data-error hidden></div>
          <div class="${columnas > 1 ? "rejilla" : "pila"}">${camposHTML(campos, valores)}</div>
        </div>
        <div class="modal__pie">
          <button type="button" class="btn btn--secundario" data-cancelar>Cancelar</button>
          <button type="submit" class="btn btn--primario">${esc(textoGuardar)}</button>
        </div>
      </form>`);

    const form = dialogo.querySelector("form");
    const caja = dialogo.querySelector("[data-error]");
    const boton = form.querySelector("[type=submit]");
    dialogo.querySelector("[data-cancelar]").addEventListener("click", () => dialogo.close());
    dialogo.addEventListener("close", () => resolve(resultado));

    form.addEventListener("submit", async (ev) => {
      ev.preventDefault();
      limpiarErrores(form);
      caja.hidden = true;
      if (!form.reportValidity()) return;
      botonCargando(boton, true);
      try {
        resultado = await alGuardar(leerCampos(form, campos), form);
        dialogo.close();
      } catch (e) {
        botonCargando(boton, false);
        if (e instanceof ErrorApi) mostrarErrores(form, e, caja);
        else { caja.innerHTML = errorHTML("Ocurrió un error inesperado."); caja.hidden = false; console.error(e); }
      }
    });

    dialogo.showModal();
    if (alAbrir) alAbrir(form);
    form.querySelector("input:not([disabled]), select:not([disabled]), textarea:not([disabled])")?.focus();
  });
}

/* --------------------------------------------------------------- Tablas
   columnas: [{ titulo, html: (fila) => "...", clase }]
   Las filas llevan data-i con su índice para manejar clics por delegación.
   --------------------------------------------------------------------- */
export function tablaHTML({ columnas, filas, clicable = false }) {
  const cabeza = columnas
    .map((c) => `<th class="${c.clase || ""}">${c.titulo ? esc(c.titulo) : `<span class="visualmente-oculto">Acciones</span>`}</th>`)
    .join("");
  const cuerpo = filas
    .map((f, i) => `<tr data-i="${i}"${clicable ? ' class="clicable"' : ""}>${columnas
      .map((c) => `<td class="${c.clase || ""}">${c.html(f)}</td>`).join("")}</tr>`)
    .join("");
  return `<div class="tabla-envoltura"><table class="tabla"><thead><tr>${cabeza}</tr></thead><tbody>${cuerpo}</tbody></table></div>`;
}

export function botonesFila({ editar = true, borrar = true, etiqueta = "" } = {}) {
  return `<span class="acciones-fila">
    ${editar ? `<button type="button" class="btn-icono" data-accion="editar" aria-label="Editar ${esc(etiqueta)}" title="Editar">${icono("editar")}</button>` : ""}
    ${borrar ? `<button type="button" class="btn-icono btn-icono--peligro" data-accion="borrar" aria-label="Eliminar ${esc(etiqueta)}" title="Eliminar">${icono("borrar")}</button>` : ""}
  </span>`;
}

/** Busca la fila (data-i) y la acción (data-accion) de un clic dentro de una tabla. */
export function eventoFila(ev, filas) {
  const tr = ev.target.closest("tr[data-i]");
  if (!tr) return null;
  const boton = ev.target.closest("[data-accion]");
  return { fila: filas[Number(tr.dataset.i)], accion: boton?.dataset.accion || null };
}
