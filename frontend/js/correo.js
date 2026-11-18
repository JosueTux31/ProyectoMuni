// Módulo de correo institucional (solo administradores). Pantallas:
//   #/correo                    inicio: la cuenta, los avisos recientes y el personal sin correo
//   #/correo/enviar?base=<id>   escribir un aviso al personal y enviarlo
//   #/correo/avisos             avisos enviados
//   #/correo/avisos/<id>        un aviso: a quién le llegó y a quién no
//   #/correo/comparar           importar una lista de correos y compararla con el personal
//   #/correo/comparar/<id>      resultado de la comparación de una lista
//   #/correo/configuracion      la cuenta institucional con que se envía
import { api, apiSubir } from "./api.js";
import { abrirFormulario, botonCargando, cargandoHTML, confirmar, debounce, errorHTML, esc, fecha, icono, toast, vacioHTML } from "./ui.js";
import { filasCatalogo } from "./datos.js";
import { celdaCsv, descargar, descargarTexto, marcaArchivo, num } from "./logs_ui.js";

const MAX_ADJUNTOS = 5;
const MAX_MB_ADJUNTOS = 15;
const ESTADOS_ENVIO = {
  PENDIENTE: { texto: "Por enviar", clase: "otro" },
  ENVIANDO: { texto: "Enviando", clase: "revisar" },
  ENVIADO: { texto: "Enviado", clase: "permitido" },
  CON_ERRORES: { texto: "Con errores", clase: "denegado" },
  CANCELADO: { texto: "Detenido", clase: "otro" },
};
const ESTADOS_DESTINATARIO = {
  ENVIADO: { texto: "Enviado", clase: "permitido" },
  ERROR: { texto: "No se envió", clase: "denegado" },
  PENDIENTE: { texto: "Por enviar", clase: "revisar" },
  CANCELADO: { texto: "Cancelado", clase: "otro" },
};
const plural = (n, uno, varios) => `${num(n)} ${Number(n) === 1 ? uno : varios}`;
const pastillaEstado = (estado, mapa = ESTADOS_ENVIO) => {
  const e = mapa[estado] || { texto: estado, clase: "otro" };
  return `<span class="estado-envio estado-envio--${e.clase}"><i class="muestra muestra--${e.clase}"></i>${esc(e.texto)}</span>`;
};
const tamano = (b) => (b >= 1048576 ? `${(b / 1048576).toLocaleString("es-CR", { maximumFractionDigits: 1 })} MB`
  : `${Math.max(1, Math.round(b / 1024))} KB`);
const primerNombre = (n) => { const p = String(n || "").trim().split(/\s+/)[0] || ""; return p ? p[0].toUpperCase() + p.slice(1).toLowerCase() : ""; };
const titulo = (n) => String(n || "").toLowerCase().replace(/(^|\s)(\p{L})/gu, (_, a, b) => a + b.toUpperCase());

/** Texto del aviso como se ve en el correo (párrafos, enlaces y {nombre}).
 *  Sin nombre (null), {nombre} queda marcado tal cual. */
function cuerpoHTML(texto, nombre = null) {
  let t = String(texto || "");
  if (nombre !== null) t = t.replace(/\{nombre_completo\}/g, titulo(nombre)).replace(/\{nombre\}/g, primerNombre(nombre));
  return t.replace(/\r\n/g, "\n").split(/\n\s*\n/).filter((b) => b.trim())
    .map((b) => `<p>${esc(b.replace(/^\n+|\n+$/g, "")).replace(/(https?:\/\/[^\s<]+[^\s<.,;:!?)\]])/g, '<a href="$1" target="_blank" rel="noopener">$1</a>')
      .replace(/\{(nombre|nombre_completo)\}/g, '<em class="marcador">{$1}</em>').replace(/\n/g, "<br>")}</p>`)
    .join("");
}

/** Envía de a lotes hasta terminar, avisando el avance. Se detiene si se sale de la pantalla. */
async function enviarHastaTerminar(id, { alAvance, vigente }) {
  let antes = null;
  for (;;) {
    const r = await api(`correo/envios/${id}/enviar/`, { metodo: "POST", datos: {} });
    alAvance(r.envio);
    const faltan = Number(r.envio.pendientes) || 0;
    if (r.error) return { envio: r.envio, error: r.error };
    if (!faltan || faltan === antes || !vigente()) return { envio: r.envio, error: null };
    antes = faltan;
  }
}

function avanceHTML(e) {
  const total = Number(e.total) || 0;
  const hechos = (Number(e.enviados) || 0) + (Number(e.errores) || 0);
  const pct = total ? Math.round((100 * hechos) / total) : 0;
  return `<div class="avance-envio">
    <div class="avance-envio__cifras"><b>${num(e.enviados)}</b> de ${num(total)} enviados${Number(e.errores) ? ` · <span class="texto-denegado">${plural(e.errores, "error", "errores")}</span>` : ""}
      ${Number(e.pendientes) ? ` · ${plural(e.pendientes, "falta", "faltan")}` : ""}</div>
    <span class="progreso__barra" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${pct}"><span style="width:${pct}%"></span></span>
  </div>`;
}

/* =====================================================================
   Inicio del módulo
   ===================================================================== */
export async function vistaInicioCorreo(cont, _params, ctx) {
  ctx.migas([{ texto: "Inicio" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Correo institucional</h1>
        <p>Avisos al personal enviados desde la cuenta de correo institucional, y la comparación de los correos registrados
          en el sistema con la lista de cuentas de la municipalidad.</p></div>
      <div class="encabezado__acciones">
        <a class="btn btn--primario" href="#/correo/enviar">${icono("enviar")}Escribir aviso</a>
        <a class="btn btn--secundario" href="#/correo/comparar">${icono("comparar")}Comparar correos</a>
      </div>
    </div>
    <div data-inicio>${cargandoHTML()}</div>`;
  const [cfg, gente, envios] = await Promise.all([api("correo/configuracion/"), api("correo/personal/"), api("correo/envios/")]);
  if (!ctx.vigente()) return;
  const sin = gente.filter((p) => !p.correo);
  const enviados = envios.reduce((s, e) => s + (Number(e.enviados) || 0), 0);
  cont.querySelector("[data-inicio]").innerHTML = `
    ${cuentaResumenHTML(cfg)}
    <nav class="resumen" aria-label="Resumen">
      <a href="#/correo/enviar"><b>${num(gente.length - sin.length)}</b><span>Personas activas con correo</span></a>
      <a href="#/correo/comparar"><b>${num(sin.length)}</b><span>Personas activas sin correo</span></a>
      <a href="#/correo/avisos"><b>${num(envios.length)}</b><span>Avisos</span></a>
      <a href="#/correo/avisos"><b>${num(enviados)}</b><span>Correos enviados</span></a>
    </nav>
    <div class="dos-columnas">
      <section class="panel">
        <div class="panel__cabeza"><div><h2>Avisos recientes</h2></div><a class="btn btn--fantasma btn--sm" href="#/correo/avisos">Ver todos</a></div>
        ${envios.length ? `<ul class="lista-avisos">${envios.slice(0, 6).map(itemAvisoHTML).join("")}</ul>`
          : `<div class="panel__cuerpo">${vacioHTML({ icono: "enviar", titulo: "Todavía no se ha enviado ningún aviso",
            boton: `<a class="btn btn--primario" href="#/correo/enviar">${icono("enviar")}Escribir el primero</a>` })}</div>`}
      </section>
      <section class="panel">
        <div class="panel__cabeza"><div><h2>Personal activo sin correo</h2><p>No recibirán los avisos hasta que se registre su correo.</p></div></div>
        ${sin.length ? `<ul class="lista-sin-correo">${sin.slice(0, 8).map((p) => `<li><a href="#/usuarios/${p.id}">${esc(titulo(p.nombre))}</a>
            <small>${esc(p.departamento || "Sin departamento")}</small></li>`).join("")}
            ${sin.length > 8 ? `<li><a href="#/correo/comparar">y ${num(sin.length - 8)} más</a></li>` : ""}</ul>`
          : `<div class="panel__cuerpo"><p class="cobertura-resumen__ok">${icono("check")}<span>Todo el personal activo tiene un correo registrado.</span></p></div>`}
      </section>
    </div>`;
}

function cuentaResumenHTML(cfg) {
  if (!cfg.configurada) {
    return `<div class="aviso aviso--ocre aviso--accion">${icono("alerta")}<span><strong>La cuenta de correo institucional todavía no está configurada.</strong>
      Sin ella no se pueden enviar avisos.</span><a class="btn btn--primario btn--sm" href="#/correo/configuracion">${icono("llave")}Configurar</a></div>`;
  }
  const prueba = cfg.prueba_ok === true ? `<span class="texto-ok">${icono("check", "ic--sm")}Probada con éxito el ${esc(fecha(cfg.ultima_prueba))}</span>`
    : cfg.prueba_ok === false ? `<span class="texto-denegado">${icono("alerta", "ic--sm")}La última prueba falló</span>`
    : `<span class="secundario">Sin probar desde el último cambio</span>`;
  return `<section class="panel cuenta-correo">
    <div class="cuenta-correo__cuerpo">
      <span class="cuenta-correo__icono">${icono("correo")}</span>
      <div class="cuenta-correo__texto"><small>Los avisos salen de</small><strong>${esc(cfg.remitente)}</strong>
        <span>${esc(cfg.servidor)}:${esc(cfg.puerto)} · ${esc(cfg.seguridad)} · ${prueba}</span></div>
      <div class="cuenta-correo__hoy"><b>${num(cfg.enviados_hoy)}</b><span>de ${num(cfg.limite_diario)} hoy</span></div>
      ${cfg.activo ? "" : `<span class="estado-envio estado-envio--denegado">${icono("candado", "ic--sm")}Envío pausado</span>`}
      <a class="btn btn--secundario btn--sm" href="#/correo/configuracion">${icono("editar")}Configuración</a>
    </div>
  </section>`;
}

const itemAvisoHTML = (e) => `<li><a class="item-aviso" href="#/correo/avisos/${e.id_envio}">
  <span class="item-aviso__texto"><strong>${esc(e.asunto)}</strong>
    <small>${esc(e.destinatarios || "")} · ${esc(fecha(e.creado_en))}${Number(e.adjuntos) ? ` · ${icono("documento", "ic--sm")}${num(e.adjuntos)}` : ""}</small></span>
  <span class="item-aviso__estado">${pastillaEstado(e.estado)}<small>${num(e.enviados)} de ${num(e.total)}</small></span>
</a></li>`;

/* =====================================================================
   Escribir y enviar un aviso
   ===================================================================== */
export async function vistaEnviarAviso(cont, _params, ctx) {
  ctx.migas([{ texto: "Escribir aviso" }]);
  cont.innerHTML = cargandoHTML();
  const base = Number(ctx.query.get("base")) || null;
  const [cfg, gente, previo] = await Promise.all([
    api("correo/configuracion/"), api("correo/personal/"), base ? api(`correo/envios/${base}/`).catch(() => null) : null,
  ]);
  if (!ctx.vigente()) return;

  const deps = new Map();
  for (const p of gente) {
    const k = p.cod_departamento ?? 0;
    const d = deps.get(k) || { cod: k, nombre: p.departamento || "Sin departamento", total: 0, conCorreo: 0 };
    d.total += 1;
    if (p.correo) d.conCorreo += 1;
    deps.set(k, d);
  }
  const listaDeps = [...deps.values()].sort((a, b) => a.nombre.localeCompare(b.nombre, "es"));
  const estado = { modo: "todos", departamentos: new Set(), personas: new Set() };
  let adjuntos = [];
  const sinCuenta = !cfg.configurada;

  cont.innerHTML = `
    <div class="encabezado">
      <div class="encabezado-imp"><span class="insignia-log insignia-log--correo">${icono("enviar")}</span>
        <div><h1>Escribir aviso</h1><p>Le llega a cada persona en un correo aparte, desde la cuenta institucional.</p></div></div>
      <div class="encabezado__acciones"><a class="btn btn--secundario" href="#/correo/avisos">${icono("historial")}Avisos enviados</a></div>
    </div>
    ${sinCuenta ? `<div class="aviso aviso--ocre aviso--accion">${icono("alerta")}<span><strong>Configure primero la cuenta de correo institucional.</strong>
      Puede escribir el aviso, pero no enviarlo.</span><a class="btn btn--primario btn--sm" href="#/correo/configuracion">${icono("llave")}Configurar</a></div>`
      : cfg.activo ? "" : `<div class="aviso aviso--ocre">${icono("candado")}<span>El envío está pausado en la <a href="#/correo/configuracion">configuración</a>.</span></div>`}
    ${previo ? `<div class="aviso aviso--info">${icono("enlace")}<span>Se copió el asunto, el mensaje y los destinatarios del aviso
      <a href="#/correo/avisos/${previo.id_envio}">«${esc(previo.asunto)}»</a>. Los adjuntos no se copian.</span></div>` : ""}
    <div class="redactar" data-redactar>
      <form class="panel redactar__form" novalidate>
        <div class="panel__cuerpo pila">
          <div class="campo"><span class="etiqueta-campo">Para</span>
            <div class="segmentado" role="radiogroup" aria-label="A quién">
              <button type="button" role="radio" data-modo="todos" aria-checked="true">Todo el personal</button>
              <button type="button" role="radio" data-modo="elegir" aria-checked="false">Elegir departamentos o personas</button>
            </div>
            <div class="para-elegir" data-elegir hidden>
              <div class="chips-tipos" role="group" aria-label="Departamentos">${listaDeps.map((d) => `
                <button type="button" class="chip-alerta" data-dep="${d.cod}" aria-pressed="false">${icono("edificio", "ic--sm")}${esc(d.nombre)}<b>${num(d.conCorreo)}</b></button>`).join("")}</div>
              <div class="buscador-personas">
                <div class="buscador">${icono("buscar")}<input type="search" class="control" data-buscar-persona placeholder="Agregar una persona: nombre, correo o departamento" aria-label="Buscar persona" autocomplete="off"></div>
                <ul class="resultados-personas" data-resultados hidden></ul>
              </div>
              <div class="personas-elegidas" data-elegidas></div>
            </div>
            <p class="resumen-para" data-resumen-para aria-live="polite"></p>
          </div>
          <div class="campo" data-campo="asunto"><label for="av-asunto">Asunto <span class="req" aria-hidden="true">*</span></label>
            <input id="av-asunto" name="asunto" maxlength="200" required placeholder="Ej.: Mantenimiento de la red el sábado" value="${esc(previo?.asunto || "")}">
            <p class="error-campo" hidden></p></div>
          <div class="campo" data-campo="mensaje"><label for="av-mensaje">Mensaje <span class="req" aria-hidden="true">*</span></label>
            <textarea id="av-mensaje" name="mensaje" rows="10" maxlength="20000" required placeholder="Hola {nombre}:&#10;&#10;Les informamos que…">${esc(previo?.mensaje || "")}</textarea>
            <p class="ayuda">Escriba <code>{nombre}</code> para saludar a cada persona por su nombre. Deje una línea en blanco entre párrafos; los enlaces quedan activos.</p>
            <p class="error-campo" hidden></p></div>
          <div class="campo"><span class="etiqueta-campo">Adjuntos <span class="etiqueta-nota">(opcional: hasta ${MAX_ADJUNTOS} archivos y ${MAX_MB_ADJUNTOS} MB en total)</span></span>
            <input type="file" id="av-adjuntos" multiple class="visualmente-oculto">
            <label for="av-adjuntos" class="btn btn--secundario btn--sm adjuntar">${icono("documento")}Adjuntar archivos</label>
            <ul class="adjuntos-lista" data-adjuntos></ul></div>
          <div data-error-envio hidden></div>
        </div>
        <div class="panel__pie redactar__pie">
          <button type="button" class="btn btn--secundario" data-prueba${sinCuenta ? " disabled" : ""}>${icono("correo")}Enviarme una prueba</button>
          <button type="submit" class="btn btn--primario" data-enviar${sinCuenta ? " disabled" : ""}>${icono("enviar")}Enviar aviso</button>
        </div>
      </form>
      <aside class="panel vista-correo" aria-label="Así se verá">
        <div class="panel__cabeza"><h2>Así se verá</h2></div>
        <div class="vista-correo__cuerpo" data-vista></div>
      </aside>
    </div>`;

  const form = cont.querySelector(".redactar__form");
  const cajaElegir = cont.querySelector("[data-elegir]");
  const resumenPara = cont.querySelector("[data-resumen-para]");
  const vista = cont.querySelector("[data-vista]");
  const buscar = cont.querySelector("[data-buscar-persona]");
  const resultados = cont.querySelector("[data-resultados]");
  const cajaAdjuntos = cont.querySelector("[data-adjuntos]");
  const errorEnvio = cont.querySelector("[data-error-envio]");

  const elegidos = () => (estado.modo === "todos" ? gente
    : gente.filter((p) => estado.departamentos.has(p.cod_departamento ?? 0) || estado.personas.has(p.id)));

  const pintarVista = () => {
    const con = elegidos().filter((p) => p.correo);
    const primero = con[0];
    const asunto = form.asunto.value.trim();
    vista.innerHTML = `
      <dl class="vista-correo__cabeza">
        <div><dt>De</dt><dd>${esc(cfg.configurada ? cfg.remitente : "Cuenta institucional sin configurar")}</dd></div>
        <div><dt>Para</dt><dd>${primero ? `${esc(titulo(primero.nombre))} &lt;${esc(primero.correo)}&gt;${con.length > 1 ? ` <span class="secundario">y ${plural(con.length - 1, "persona más", "personas más")}, cada una en su correo</span>` : ""}` : `<span class="sin-dato">Nadie</span>`}</dd></div>
        <div><dt>Asunto</dt><dd><strong>${asunto ? esc(asunto) : `<span class="sin-dato">Sin asunto</span>`}</strong></dd></div>
      </dl>
      <div class="vista-correo__mensaje">
        <div class="vista-correo__banda">${esc(cfg.nombre_remitente || cfg.correo_remitente || "Municipalidad")}</div>
        ${cuerpoHTML(form.mensaje.value, primero ? primero.nombre : null) || `<p class="sin-dato">El mensaje aparece aquí.</p>`}
        ${cfg.firma ? `<div class="vista-correo__firma">${cuerpoHTML(cfg.firma)}</div>` : ""}
        ${adjuntos.length ? `<div class="vista-correo__adjuntos">${adjuntos.map((a) => `<span class="chip-dir">${icono("documento", "ic--sm")}${esc(a.name)}</span>`).join("")}</div>` : ""}
      </div>`;
  };

  const pintarPara = () => {
    cajaElegir.hidden = estado.modo === "todos";
    cont.querySelectorAll("[data-modo]").forEach((b) => b.setAttribute("aria-checked", String(b.dataset.modo === estado.modo)));
    cont.querySelectorAll("[data-dep]").forEach((b) => b.setAttribute("aria-pressed", String(estado.departamentos.has(Number(b.dataset.dep)))));
    const sueltos = gente.filter((p) => estado.personas.has(p.id));
    cont.querySelector("[data-elegidas]").innerHTML = sueltos.map((p) => `<span class="persona-chip${p.correo ? "" : " persona-chip--sin"}" title="${esc(p.correo || "Sin correo registrado")}">
      ${esc(titulo(p.nombre))}${p.correo ? "" : " · sin correo"}<button type="button" data-quitar-persona="${p.id}" aria-label="Quitar a ${esc(p.nombre)}">${icono("cerrar", "ic--sm")}</button></span>`).join("");
    const lista = elegidos();
    const con = lista.filter((p) => p.correo);
    const sin = lista.filter((p) => !p.correo);
    resumenPara.innerHTML = lista.length
      ? `${icono("usuarios", "ic--sm")}<span>Le llegará a <strong>${plural(con.length, "persona", "personas")}</strong>.
        ${sin.length ? `<span class="texto-denegado">${plural(sin.length, "persona no tiene", "personas no tienen")} correo registrado y no ${sin.length === 1 ? "lo recibirá" : "lo recibirán"}:</span>
        ${sin.slice(0, 6).map((p) => `<a href="#/usuarios/${p.id}">${esc(titulo(p.nombre))}</a>`).join(", ")}${sin.length > 6 ? ` y ${num(sin.length - 6)} más` : ""}.` : ""}</span>`
      : `${icono("alerta", "ic--sm")}<span>Elija al menos un departamento o una persona.</span>`;
    pintarVista();
  };

  const pintarAdjuntos = () => {
    const total = adjuntos.reduce((s, a) => s + a.size, 0);
    cajaAdjuntos.innerHTML = adjuntos.map((a, i) => `<li>${icono("documento", "ic--sm")}<span>${esc(a.name)}</span><small>${esc(tamano(a.size))}</small>
      <button type="button" class="btn-icono" data-quitar-adjunto="${i}" aria-label="Quitar ${esc(a.name)}">${icono("cerrar")}</button></li>`).join("")
      + (total > MAX_MB_ADJUNTOS * 1048576 ? `<li class="texto-denegado">${icono("alerta", "ic--sm")}Los adjuntos pesan ${esc(tamano(total))}: el máximo es ${MAX_MB_ADJUNTOS} MB.</li>` : "");
    pintarVista();
  };

  const buscarPersonas = () => {
    const t = buscar.value.trim().toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
    if (!t) { resultados.hidden = true; return; }
    const norm = (v) => String(v || "").toLowerCase().normalize("NFD").replace(/\p{M}/gu, "");
    const lista = gente.filter((p) => !estado.personas.has(p.id) && [p.nombre, p.correo, p.departamento].some((v) => norm(v).includes(t))).slice(0, 8);
    resultados.hidden = false;
    resultados.innerHTML = lista.length ? lista.map((p) => `<li><button type="button" data-agregar-persona="${p.id}">
      <strong>${esc(titulo(p.nombre))}</strong><small>${esc(p.correo || "Sin correo registrado")} · ${esc(p.departamento || "Sin departamento")}</small></button></li>`).join("")
      : `<li class="sin-dato">Nadie coincide.</li>`;
  };

  // Copiar los destinatarios de un aviso anterior
  if (previo) {
    if (previo.destinatarios === "Todo el personal") estado.modo = "todos";
    else {
      estado.modo = "elegir";
      for (const d of previo.destinatarios_lista || []) if (d.id_persona && gente.some((p) => p.id === d.id_persona)) estado.personas.add(d.id_persona);
    }
  }

  cont.addEventListener("click", (ev) => {
    const m = ev.target.closest("[data-modo]");
    if (m) { estado.modo = m.dataset.modo; pintarPara(); return; }
    const d = ev.target.closest("[data-dep]");
    if (d) {
      const k = Number(d.dataset.dep);
      if (estado.departamentos.has(k)) estado.departamentos.delete(k); else estado.departamentos.add(k);
      pintarPara();
      return;
    }
    const a = ev.target.closest("[data-agregar-persona]");
    if (a) { estado.personas.add(Number(a.dataset.agregarPersona)); buscar.value = ""; resultados.hidden = true; pintarPara(); buscar.focus(); return; }
    const q = ev.target.closest("[data-quitar-persona]");
    if (q) { estado.personas.delete(Number(q.dataset.quitarPersona)); pintarPara(); return; }
    const qa = ev.target.closest("[data-quitar-adjunto]");
    if (qa) { adjuntos.splice(Number(qa.dataset.quitarAdjunto), 1); pintarAdjuntos(); }
  });
  buscar.addEventListener("input", debounce(buscarPersonas, 150));
  buscar.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter") { ev.preventDefault(); resultados.querySelector("[data-agregar-persona]")?.click(); }
    if (ev.key === "Escape") { resultados.hidden = true; }
  });
  form.asunto.addEventListener("input", debounce(pintarVista, 150));
  form.mensaje.addEventListener("input", debounce(pintarVista, 200));
  const entradaAdjuntos = cont.querySelector("#av-adjuntos");
  entradaAdjuntos.addEventListener("change", () => {
    for (const f of entradaAdjuntos.files) {
      if (adjuntos.length >= MAX_ADJUNTOS) { toast(`Adjunte ${MAX_ADJUNTOS} archivos como máximo.`, "error"); break; }
      if (!adjuntos.some((x) => x.name === f.name && x.size === f.size)) adjuntos.push(f);
    }
    entradaAdjuntos.value = "";
    pintarAdjuntos();
  });

  const datosForm = (extra = {}) => {
    const datos = new FormData();
    datos.append("asunto", form.asunto.value.trim());
    datos.append("mensaje", form.mensaje.value);
    for (const [k, v] of Object.entries(extra)) datos.append(k, v);
    for (const a of adjuntos) datos.append("adjuntos", a);
    return datos;
  };
  const validar = () => {
    errorEnvio.hidden = true;
    form.querySelectorAll(".con-error").forEach((x) => x.classList.remove("con-error"));
    form.querySelectorAll(".error-campo").forEach((x) => { x.hidden = true; });
    for (const nombre of ["asunto", "mensaje"]) {
      if (!form[nombre].value.trim()) {
        const c = form.querySelector(`[data-campo="${nombre}"]`);
        c.classList.add("con-error");
        c.querySelector(".error-campo").textContent = nombre === "asunto" ? "Escriba el asunto." : "Escriba el mensaje.";
        c.querySelector(".error-campo").hidden = false;
        form[nombre].focus();
        return false;
      }
    }
    if (adjuntos.reduce((s, a) => s + a.size, 0) > MAX_MB_ADJUNTOS * 1048576) { toast(`Los adjuntos pasan de ${MAX_MB_ADJUNTOS} MB.`, "error"); return false; }
    return true;
  };
  const mostrarError = (e) => { errorEnvio.innerHTML = errorHTML(e.message); errorEnvio.hidden = false; errorEnvio.scrollIntoView({ block: "nearest" }); };

  cont.querySelector("[data-prueba]").addEventListener("click", async (ev) => {
    if (!validar()) return;
    const boton = ev.currentTarget;
    botonCargando(boton, true);
    try {
      const r = await apiSubir("correo/envios/prueba/", datosForm());
      toast(r.detail);
    } catch (e) {
      mostrarError(e);
    } finally {
      botonCargando(boton, false);
    }
  });

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    if (!validar()) return;
    const con = elegidos().filter((p) => p.correo);
    if (!con.length) { mostrarError(new Error("Ninguna de las personas elegidas tiene un correo registrado.")); return; }
    const ok = await confirmar({
      titulo: "Enviar el aviso", peligro: false, textoBoton: `Enviar a ${plural(con.length, "persona", "personas")}`,
      mensaje: `«${form.asunto.value.trim()}» le llegará a ${plural(con.length, "persona", "personas")}, cada una en su propio correo, desde ${cfg.remitente}.`,
    });
    if (!ok) return;
    const boton = form.querySelector("[data-enviar]");
    botonCargando(boton, true);
    let envio;
    try {
      envio = await apiSubir("correo/envios/", datosForm({
        todos: estado.modo === "todos" ? "true" : "false",
        departamentos: JSON.stringify([...estado.departamentos]),
        personas: JSON.stringify([...estado.personas]),
      }));
    } catch (e) {
      botonCargando(boton, false);
      mostrarError(e);
      return;
    }
    if (!ctx.vigente()) return;
    const caja = cont.querySelector("[data-redactar]");
    caja.outerHTML = `<section class="panel envio-en-curso" data-en-curso>
      <div class="panel__cabeza"><div><h2>${icono("enviar")} Enviando «${esc(envio.asunto)}»</h2>
        <p>No cierre esta pantalla hasta que termine. Si la cierra, lo que falte queda pendiente y lo puede continuar desde el aviso.</p></div></div>
      <div class="panel__cuerpo" data-avance>${avanceHTML({ ...envio, pendientes: envio.total })}</div>
    </section>`;
    const avance = cont.querySelector("[data-avance]");
    let r;
    try {
      r = await enviarHastaTerminar(envio.id_envio, { alAvance: (e) => { if (ctx.vigente()) avance.innerHTML = avanceHTML(e); }, vigente: ctx.vigente });
    } catch (e) {
      r = { envio, error: e.message };
    }
    if (!ctx.vigente()) return;
    const e = r.envio;
    const final = r.error ? "error" : Number(e.errores) ? "errores" : "ok";
    cont.querySelector("[data-en-curso]").outerHTML = `<section class="panel envio-terminado envio-terminado--${final}">
      <div class="panel__cuerpo">
        <div class="resultado-importacion__texto">${icono(final === "ok" ? "check" : "alerta")}<div>
          <strong>${final === "ok" ? `El aviso se envió a ${plural(e.enviados, "persona", "personas")}.`
            : final === "errores" ? `Se envió a ${plural(e.enviados, "persona", "personas")}; a ${num(e.errores)} no se le pudo enviar.`
            : `El envío se detuvo: ${esc(r.error)}`}</strong>
          ${final === "error" ? `<p>Los que faltan quedaron pendientes. Corrija la causa y continúe el envío desde el aviso.</p>` : ""}
          ${envio.sin_correo?.length ? `<p>${plural(envio.sin_correo.length, "persona no lo recibió", "personas no lo recibieron")} por no tener correo registrado.</p>` : ""}</div></div>
        ${avanceHTML(e)}
        <div class="encabezado__acciones">
          <a class="btn btn--primario" href="#/correo/avisos/${e.id_envio}">${icono("documento")}Ver el aviso</a>
          <a class="btn btn--secundario" href="#/correo/enviar">${icono("enviar")}Escribir otro</a>
          ${final === "error" ? `<a class="btn btn--secundario" href="#/correo/configuracion">${icono("llave")}Revisar la cuenta</a>` : ""}
        </div>
      </div></section>`;
    toast(final === "ok" ? "Se envió el aviso." : "El envío terminó con avisos.", final === "ok" ? "ok" : "error");
  });

  pintarPara();
  pintarAdjuntos();
}

/* =====================================================================
   Avisos enviados
   ===================================================================== */
export async function vistaAvisos(cont, _params, ctx) {
  ctx.migas([{ texto: "Avisos enviados" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Avisos enviados</h1><p>Cada aviso con a cuántas personas les llegó. Ábralo para ver a quién no se le pudo enviar.</p></div>
      <div class="encabezado__acciones"><a class="btn btn--primario" href="#/correo/enviar">${icono("enviar")}Escribir aviso</a></div>
    </div>
    <section class="panel">
      <div class="panel__cabeza"><div class="buscador">${icono("buscar")}<input type="search" class="control" data-buscar placeholder="Buscar en el asunto o el mensaje" aria-label="Buscar avisos"></div></div>
      <div data-tabla>${cargandoHTML()}</div>
    </section>`;
  const caja = cont.querySelector("[data-tabla]");
  const cargar = async (buscar = "") => {
    const filas = await api("correo/envios/", { query: { buscar } });
    if (!ctx.vigente()) return;
    caja.innerHTML = filas.length ? `<div class="tabla-envoltura"><table class="tabla">
      <thead><tr><th>Aviso</th><th>Para</th><th>Estado</th><th class="col-opcional">Enviado por</th><th class="col-opcional">Fecha</th></tr></thead>
      <tbody>${filas.map((e) => `<tr class="clicable" data-id="${e.id_envio}" tabindex="0">
        <td><a href="#/correo/avisos/${e.id_envio}"><strong>${esc(e.asunto)}</strong></a><span class="secundario recorte">${esc(e.extracto || "")}</span></td>
        <td>${esc(e.destinatarios || "—")}<span class="secundario">${plural(e.total, "persona", "personas")}${Number(e.adjuntos) ? ` · ${plural(e.adjuntos, "adjunto", "adjuntos")}` : ""}</span></td>
        <td>${pastillaEstado(e.estado)}<span class="secundario">${num(e.enviados)} de ${num(e.total)}${Number(e.errores) ? ` · ${plural(e.errores, "error", "errores")}` : ""}</span></td>
        <td class="col-opcional">${esc(e.enviado_por || "—")}</td>
        <td class="col-opcional">${esc(fecha(e.creado_en))}</td>
      </tr>`).join("")}</tbody></table></div>`
      : vacioHTML({ icono: "enviar", titulo: buscar ? "Ningún aviso coincide" : "Todavía no se ha enviado ningún aviso",
        boton: buscar ? "" : `<a class="btn btn--primario" href="#/correo/enviar">${icono("enviar")}Escribir aviso</a>` });
  };
  cont.querySelector("[data-buscar]").addEventListener("input", debounce((ev) => cargar(ev.target.value.trim()), 300));
  caja.addEventListener("click", (ev) => {
    const tr = ev.target.closest("tr[data-id]");
    if (tr && !ev.target.closest("a")) location.hash = `#/correo/avisos/${tr.dataset.id}`;
  });
  caja.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest("tr[data-id]");
    if (tr && ev.key === "Enter") location.hash = `#/correo/avisos/${tr.dataset.id}`;
  });
  await cargar();
}

/* =====================================================================
   Un aviso: mensaje, adjuntos y resultado de cada destinatario
   ===================================================================== */
export async function vistaAviso(cont, [id], ctx) {
  id = Number(id);
  ctx.migas([{ texto: "Avisos enviados", href: "#/correo/avisos" }, { texto: `N.º ${id}` }]);
  cont.innerHTML = cargandoHTML();
  let e = await api(`correo/envios/${id}/`);
  if (!ctx.vigente()) return;
  ctx.migas([{ texto: "Avisos enviados", href: "#/correo/avisos" }, { texto: e.asunto }]);
  let filtro = "todos";
  let errorEnvio = null;
  let enviando = false;

  const pintar = () => {
    const d = e.destinatarios_lista || [];
    const cuenta = (k) => d.filter((x) => x.estado === k).length;
    const lista = filtro === "todos" ? d : d.filter((x) => x.estado === filtro);
    const faltan = Number(e.pendientes) || 0;
    const reintentables = (Number(e.errores) || 0) + (Number(e.cancelados) || 0);
    cont.innerHTML = `
      <div class="encabezado encabezado--imp">
        <div class="encabezado-imp"><span class="insignia-log insignia-log--correo">${icono("enviar")}</span>
          <div><h1>${esc(e.asunto)}</h1>
            <p>Aviso N.º ${e.id_envio} · ${esc(fecha(e.creado_en))}${e.enviado_por ? ` por ${esc(e.enviado_por)}` : ""} · De ${esc(e.remitente || "—")}</p></div></div>
        <div class="encabezado__acciones">
          ${faltan && !enviando ? `<button type="button" class="btn btn--primario" data-continuar>${icono("enviar")}Continuar el envío (${num(faltan)})</button>` : ""}
          ${reintentables && !faltan && !enviando ? `<button type="button" class="btn btn--primario" data-reintentar>${icono("cambiar")}${reintentables === 1 ? "Reintentar el que falta" : `Reintentar los ${num(reintentables)} que faltan`}</button>` : ""}
          ${faltan && !enviando ? `<button type="button" class="btn btn--secundario" data-cancelar>${icono("cerrar")}Detener</button>` : ""}
          <a class="btn btn--secundario" href="#/correo/enviar?base=${e.id_envio}">${icono("documento")}Usar como base</a>
          ${Number(e.enviados) ? "" : `<button type="button" class="btn-icono btn-icono--peligro" data-eliminar title="Eliminar aviso" aria-label="Eliminar aviso">${icono("borrar")}</button>`}
        </div>
      </div>
      ${errorEnvio ? `<div class="aviso aviso--error aviso--accion" role="alert">${icono("alerta")}<span><strong>El envío se detuvo.</strong> ${esc(errorEnvio)}</span>
        <a class="btn btn--secundario btn--sm" href="#/correo/configuracion">${icono("llave")}Revisar la cuenta</a></div>` : ""}
      <div class="cifras cifras--chicas cifras--aviso">
        <div class="cifra"><b>${num(e.total)}</b><span>Destinatarios</span><small>${esc(e.destinatarios || "")}</small></div>
        <div class="cifra cifra--ok"><b>${num(e.enviados)}</b><span>Enviados</span></div>
        <div class="cifra${Number(e.errores) ? " cifra--sin" : ""}"><b>${num(e.errores)}</b><span>No se pudieron enviar</span></div>
        <div class="cifra${faltan ? " cifra--aviso" : ""}"><b>${num(faltan)}</b><span>Por enviar</span>${Number(e.cancelados) ? `<small>${plural(e.cancelados, "cancelado", "cancelados")}</small>` : ""}</div>
        <div class="cifra"><span>Estado</span>${pastillaEstado(e.estado)}${e.terminado_en ? `<small>Terminó el ${esc(fecha(e.terminado_en))}</small>` : ""}</div>
      </div>
      <div data-avance>${enviando ? avanceHTML(e) : ""}</div>
      <div class="aviso-detalle">
        <section class="panel">
          <div class="panel__cabeza"><h2>${icono("correo")} Mensaje</h2></div>
          <div class="panel__cuerpo vista-correo__mensaje vista-correo__mensaje--plano">${cuerpoHTML(e.mensaje)}
            ${(e.adjuntos_lista || []).length ? `<div class="vista-correo__adjuntos">${e.adjuntos_lista.map((a) => `<button type="button" class="chip-dir chip-dir--boton" data-adjunto="${a.num_linea}" data-nombre="${esc(a.nombre_archivo)}" title="Descargar">
              ${icono("descargar", "ic--sm")}${esc(a.nombre_archivo)} <small>${esc(tamano(Number(a.tamano)))}</small></button>`).join("")}</div>` : ""}
          </div>
        </section>
        <section class="panel">
          <div class="panel__cabeza"><div><h2>${icono("usuarios")} Destinatarios</h2><p>Cada persona recibió su propio correo.</p></div></div>
          <div class="chips-alerta" role="group" aria-label="Qué destinatarios ver">
            <button type="button" class="chip-alerta" data-filtro="todos" aria-pressed="${filtro === "todos"}">Todos<b>${num(d.length)}</b></button>
            ${Object.entries(ESTADOS_DESTINATARIO).map(([k, x]) => (cuenta(k) ? `<button type="button" class="chip-alerta" data-filtro="${k}" aria-pressed="${filtro === k}">${esc(x.texto)}<b>${num(cuenta(k))}</b></button>` : "")).join("")}
          </div>
          <div class="tabla-envoltura"><table class="tabla tabla--compacta">
            <thead><tr><th>Persona</th><th>Correo</th><th>Resultado</th></tr></thead>
            <tbody>${lista.map((x) => `<tr>
              <td>${x.id_persona ? `<a href="#/usuarios/${x.id_persona}"><strong>${esc(titulo(x.nombre))}</strong></a>` : `<strong>${esc(titulo(x.nombre) || "—")}</strong>`}
                <span class="secundario">${esc(x.departamento || "")}</span></td>
              <td class="dato-mono">${esc(x.correo)}</td>
              <td class="col-resultado">${pastillaEstado(x.estado, ESTADOS_DESTINATARIO)}${x.error ? `<span class="secundario error-envio">${esc(x.error)}</span>` : x.enviado_en ? `<span class="secundario">${esc(fecha(x.enviado_en))}</span>` : ""}</td>
            </tr>`).join("") || `<tr><td colspan="3" class="sin-dato">Ninguno.</td></tr>`}</tbody></table></div>
        </section>
      </div>`;
  };

  const recargar = async () => { e = await api(`correo/envios/${id}/`); if (ctx.vigente()) pintar(); };
  const continuar = async () => {
    enviando = true;
    errorEnvio = null;
    pintar();
    try {
      const r = await enviarHastaTerminar(id, {
        alAvance: (x) => { if (!ctx.vigente()) return; e = { ...e, ...x }; cont.querySelector("[data-avance]").innerHTML = avanceHTML(e); },
        vigente: ctx.vigente,
      });
      errorEnvio = r.error;
    } catch (x) {
      errorEnvio = x.message;
    }
    enviando = false;
    if (!ctx.vigente()) return;
    await recargar();
    toast(errorEnvio ? "El envío se detuvo." : "Se terminó de enviar el aviso.", errorEnvio ? "error" : "ok");
  };

  cont.addEventListener("click", async (ev) => {
    const f = ev.target.closest("[data-filtro]");
    if (f) { filtro = f.dataset.filtro; pintar(); return; }
    if (ev.target.closest("[data-continuar]")) { continuar(); return; }
    if (ev.target.closest("[data-reintentar]")) {
      e = await api(`correo/envios/${id}/reintentar/`, { metodo: "POST", datos: {} });
      continuar();
      return;
    }
    if (ev.target.closest("[data-cancelar]")) {
      const ok = await confirmar({ titulo: "Detener el envío", mensaje: `Los ${num(e.pendientes)} que faltan no se enviarán. Después puede reintentarlos.`, textoBoton: "Detener",
        accion: async () => { e = await api(`correo/envios/${id}/cancelar/`, { metodo: "POST", datos: {} }); } });
      if (ok) { pintar(); toast("Se detuvo el envío."); }
      return;
    }
    if (ev.target.closest("[data-eliminar]")) {
      const ok = await confirmar({ titulo: "Eliminar el aviso", mensaje: `Se eliminará «${e.asunto}» con sus adjuntos. No se le envió a nadie.`, textoBoton: "Eliminar",
        accion: () => api(`correo/envios/${id}/`, { metodo: "DELETE" }) });
      if (ok) { toast("Se eliminó el aviso."); location.hash = "#/correo/avisos"; }
      return;
    }
    const a = ev.target.closest("[data-adjunto]");
    if (a) {
      try { await descargar(`correo/envios/${id}/adjuntos/${a.dataset.adjunto}/`, {}, a.dataset.nombre); } catch (x) { toast(x.message, "error"); }
    }
  });
  pintar();
}

/* =====================================================================
   Comparar correos: listas importadas
   ===================================================================== */
const recienListas = new Map();

export async function vistaCompararCorreos(cont, _params, ctx) {
  ctx.migas([{ texto: "Comparar correos" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div class="encabezado-imp"><span class="insignia-log insignia-log--correo">${icono("comparar")}</span>
        <div><h1>Comparar correos</h1><p>Importe la lista de cuentas de correo de la municipalidad y compárela con los correos del personal
          registrado en el sistema: qué cuentas no tienen a nadie registrado, quién no tiene cuenta y qué cuentas suspendidas son de personal activo.</p></div></div>
    </div>
    <div class="importar">
      <section class="panel soltar" data-zona>
        <input type="file" id="archivo-lista" accept=".txt,.csv,.xlsx,text/plain,text/csv" class="visualmente-oculto">
        <label for="archivo-lista" class="soltar__zona">
          <span class="soltar__icono">${icono("subir")}</span>
          <strong>Arrastre aquí la lista de correos</strong>
          <span>o haga clic para elegirla · .txt separado por comas, .csv o .xlsx · hasta 10 MB</span>
        </label>
        <ul class="soltar__archivos" data-archivo hidden></ul>
        <div class="soltar__pie">
          <div class="campo"><label for="desc-lista">Descripción <span class="etiqueta-nota">(opcional)</span></label>
            <input id="desc-lista" maxlength="255" placeholder="Ej.: Cuentas de Google Workspace, octubre"></div>
          <button type="button" class="btn btn--primario" data-importar disabled>${icono("subir")}Importar y comparar</button>
        </div>
      </section>
      <aside class="panel ayuda-importar">
        <div class="panel__cabeza"><h2>Qué archivos sirven</h2></div>
        <div class="panel__cuerpo">
          <ol class="pasos-ayuda">
            <li><strong>Un .txt con los correos separados por comas</strong> (también sirven punto y coma, espacios o un correo por línea).
              Si vienen como <code>Nombre &lt;correo&gt;</code>, se toma el nombre.</li>
            <li><strong>La descarga de usuarios de Google Workspace</strong> (.csv o .xlsx) con las columnas Nombre, Apellidos,
              Correo electrónico y Estado; también en inglés (First Name, Last Name, Email Address, Status).</li>
            <li><strong>Se compara por el correo</strong> con los correos registrados de cada persona del personal. Cuando una cuenta no tiene
              a nadie registrado, se sugiere la persona que más se le parece por el nombre.</li>
          </ol>
        </div>
      </aside>
    </div>
    <section class="panel">
      <div class="panel__cabeza"><div><h2>Listas importadas</h2><p>Ábrala para ver la comparación con los correos registrados hoy.</p></div></div>
      <div data-listas>${cargandoHTML()}</div>
    </section>`;

  const zona = cont.querySelector("[data-zona]");
  const entrada = cont.querySelector("#archivo-lista");
  const cajaArchivo = cont.querySelector("[data-archivo]");
  const boton = cont.querySelector("[data-importar]");
  let archivo = null;
  const pintarArchivo = (error = "") => {
    cajaArchivo.hidden = !archivo;
    cajaArchivo.innerHTML = archivo ? `<li class="archivo-log archivo-log--${error ? "error" : "pendiente"}"><span class="archivo-log__icono">${icono(error ? "alerta" : "documento")}</span>
      <span class="archivo-log__texto"><strong>${esc(archivo.name)}</strong><small>${esc(tamano(archivo.size))} · ${esc(error || "Lista para importar")}</small></span></li>` : "";
    boton.disabled = !archivo || !!error;
  };
  const elegir = (f) => {
    if (!f) return;
    archivo = f;
    pintarArchivo(!/\.(txt|csv|xlsx|text)$/i.test(f.name) ? "Use un archivo .txt, .csv o .xlsx." : f.size > 10 * 1048576 ? "Pesa más de 10 MB." : "");
  };
  entrada.addEventListener("change", () => { elegir(entrada.files[0]); entrada.value = ""; });
  ["dragenter", "dragover"].forEach((t) => zona.addEventListener(t, (ev) => { ev.preventDefault(); zona.classList.add("soltar--encima"); }));
  ["dragleave", "drop"].forEach((t) => zona.addEventListener(t, (ev) => { ev.preventDefault(); if (t === "drop" || !zona.contains(ev.relatedTarget)) zona.classList.remove("soltar--encima"); }));
  zona.addEventListener("drop", (ev) => elegir(ev.dataTransfer.files[0]));
  boton.addEventListener("click", async () => {
    const datos = new FormData();
    datos.append("archivo", archivo);
    const d = cont.querySelector("#desc-lista").value.trim();
    if (d) datos.append("descripcion", d);
    botonCargando(boton, true);
    try {
      const r = await apiSubir("correo/listas/", datos);
      recienListas.set(r.lista.id_lista, r);
      toast(`Se importaron ${plural(r.lista.total, "correo", "correos")}.`);
      location.hash = `#/correo/comparar/${r.lista.id_lista}`;
    } catch (e) {
      botonCargando(boton, false);
      pintarArchivo(e.message);
    }
  });

  const listas = await api("correo/listas/");
  if (!ctx.vigente()) return;
  const caja = cont.querySelector("[data-listas]");
  caja.innerHTML = listas.length ? `<div class="tabla-envoltura"><table class="tabla">
    <thead><tr><th>Archivo</th><th class="col-numero">Correos</th><th class="col-opcional">Dominio</th><th class="col-opcional">Importada</th></tr></thead>
    <tbody>${listas.map((l) => `<tr class="clicable" data-id="${l.id_lista}" tabindex="0">
      <td><a href="#/correo/comparar/${l.id_lista}"><strong>${esc(l.nombre_archivo)}</strong></a><span class="secundario">N.º ${l.id_lista}${l.descripcion ? ` · ${esc(l.descripcion)}` : ""}</span></td>
      <td class="col-numero">${num(l.total)}</td><td class="col-opcional">${esc(l.dominio || "—")}</td>
      <td class="col-opcional">${esc(fecha(l.creado_en))}<span class="secundario">${esc(l.importado_por || "")}</span></td></tr>`).join("")}</tbody></table></div>`
    : `<div class="panel__cuerpo"><p class="top-vacio">Todavía no se ha importado ninguna lista.</p></div>`;
  caja.addEventListener("click", (ev) => {
    const tr = ev.target.closest("tr[data-id]");
    if (tr && !ev.target.closest("a")) location.hash = `#/correo/comparar/${tr.dataset.id}`;
  });
  caja.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest("tr[data-id]");
    if (tr && ev.key === "Enter") location.hash = `#/correo/comparar/${tr.dataset.id}`;
  });
}

/* =====================================================================
   Resultado de la comparación de una lista
   ===================================================================== */
const ESTADO_CUENTA = { activa: "Activa", suspendida: "Suspendida" };
const estadoCuentaHTML = (c) => (c.estado_cuenta === "suspendida" ? `<span class="pista pista--mala">Suspendida</span>`
  : c.estado_cuenta === "activa" ? `<span class="pista pista--buena">Activa</span>` : c.estado ? `<span class="pista pista--neutra">${esc(c.estado)}</span>` : "");

export async function vistaListaCorreos(cont, [id], ctx) {
  id = Number(id);
  ctx.migas([{ texto: "Comparar correos", href: "#/correo/comparar" }, { texto: `Lista N.º ${id}` }]);
  cont.innerHTML = cargandoHTML("Comparando con el personal…");
  let r = recienListas.get(id);
  recienListas.delete(id);
  const avisos = r?.avisos || [];
  if (!r) r = await api(`correo/listas/${id}/`);
  const tipos = await filasCatalogo("tipos-correos").catch(() => []);
  if (!ctx.vigente()) return;
  const institucional = (tipos.find((t) => /INSTITUCIONAL/i.test(t.descripcion)) || tipos[0])?.cod_correo;
  ctx.migas([{ texto: "Comparar correos", href: "#/correo/comparar" }, { texto: r.lista.nombre_archivo }]);
  let filtro = "todas";
  let buscado = "";
  let todas = false;

  const tablaSoloLista = () => {
    const t = buscado.trim().toLowerCase();
    let lista = r.solo_lista;
    if (filtro === "sugerencia") lista = lista.filter((x) => x.sugerencias.length);
    if (filtro === "generica") lista = lista.filter((x) => x.generica);
    if (filtro === "suspendida") lista = lista.filter((x) => x.estado_cuenta === "suspendida");
    if (t) lista = lista.filter((x) => [x.correo, x.nombre].some((v) => String(v || "").toLowerCase().includes(t)));
    const vista = todas ? lista : lista.slice(0, 25);
    if (!lista.length) return `<p class="top-vacio">${r.solo_lista.length ? "Ninguna cuenta coincide." : "Todas las cuentas de la lista son de alguien registrado."}</p>`;
    return `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
      <thead><tr><th>Cuenta</th><th>Estado</th><th>Persona registrada que se le parece</th><th class="col-acciones"></th></tr></thead>
      <tbody>${vista.map((x) => {
        const p = x.sugerencias[0];
        return `<tr>
          <td><span class="dato-mono">${esc(x.correo)}</span><span class="secundario">${esc(x.nombre || "")}${x.generica ? `${x.nombre ? " · " : ""}Cuenta de uso común` : ""}</span></td>
          <td>${estadoCuentaHTML(x)}</td>
          <td>${p ? `<a href="#/usuarios/${p.id}"><strong>${esc(titulo(p.nombre))}</strong></a><span class="secundario">${esc(p.departamento || "Sin departamento")}${p.activo ? "" : " · inactivo"}${x.sugerencias[1] ? ` · también ${esc(titulo(x.sugerencias[1].nombre))}` : ""}</span>`
            : `<span class="sin-dato">${x.generica ? "No es de una persona" : "Ninguna"}</span>`}</td>
          <td class="col-acciones">${p && institucional ? `<button type="button" class="btn btn--secundario btn--sm" data-agregar="${p.id}" data-correo="${esc(x.correo)}" data-nombre="${esc(p.nombre)}">${icono("mas")}Agregar a ${esc(primerNombre(p.nombre))}</button>` : ""}</td>
        </tr>`;
      }).join("")}</tbody></table></div>
      ${lista.length > vista.length ? `<div class="mas-filas"><button type="button" class="btn btn--secundario btn--sm" data-mas>Mostrar las ${num(lista.length)} cuentas</button>
        <span>Se ven ${num(vista.length)} de ${num(lista.length)}.</span></div>` : ""}`;
  };

  const pintar = () => {
    const t = r.totales;
    const dominio = r.dominios[0]?.dominio || "";
    const alertas = r.coinciden.filter((c) => c.alerta);
    const cifra = (valor, texto, extra = "", clase = "") => `<div class="cifra${clase ? ` ${clase}` : ""}"><b>${valor}</b><span>${esc(texto)}</span>${extra}</div>`;
    cont.innerHTML = `
      <div class="encabezado encabezado--imp">
        <div class="encabezado-imp"><span class="insignia-log insignia-log--correo">${icono("comparar")}</span>
          <div><h1>${esc(r.lista.nombre_archivo)}</h1>
            <p>${r.lista.descripcion ? `${esc(r.lista.descripcion)} · ` : ""}Lista N.º ${r.lista.id_lista} · ${plural(t.lista, "correo", "correos")}
              ${dominio ? `de ${esc(r.dominios.map((d) => d.dominio).join(", "))}` : ""} · importada el ${esc(fecha(r.lista.creado_en))}${r.lista.importado_por ? ` por ${esc(r.lista.importado_por)}` : ""}</p></div></div>
        <div class="encabezado__acciones">
          <button type="button" class="btn btn--secundario" data-exportar>${icono("descargar")}Exportar (CSV)</button>
          <button type="button" class="btn-icono" data-editar title="Editar descripción" aria-label="Editar descripción">${icono("editar")}</button>
          <button type="button" class="btn-icono btn-icono--peligro" data-eliminar title="Eliminar lista" aria-label="Eliminar lista">${icono("borrar")}</button>
        </div>
      </div>
      ${avisos.length ? `<div class="aviso aviso--info">${icono("enlace")}<span>${avisos.map(esc).join(" ")}</span></div>` : ""}
      <div class="cifras cifras--chicas cifras--seis">
        ${cifra(num(t.coinciden), "Coinciden", `<small>de ${num(t.lista)} cuentas de la lista</small>`, "cifra--ok")}
        ${cifra(num(t.solo_lista), "En la lista, sin registrar", `<small>${num(t.con_sugerencia)} con una persona sugerida</small>`, t.solo_lista ? "cifra--aviso" : "")}
        ${cifra(num(t.sin_correo), `Personal activo sin correo${dominio ? ` de ${dominio}` : ""}`, `<small>de ${num(t.personal_activo)} activos</small>`, t.sin_correo ? "cifra--aviso" : "")}
        ${cifra(num(t.solo_sistema), "Registrados que no están en la lista", "<small>Correo mal escrito o cuenta eliminada</small>", t.solo_sistema ? "cifra--sin" : "")}
        ${cifra(num(t.alerta_suspendida), "Cuenta suspendida, persona activa", "", t.alerta_suspendida ? "cifra--sin" : "")}
        ${cifra(num(t.alerta_inactivo), "Persona inactiva, cuenta activa", "", t.alerta_inactivo ? "cifra--sin" : "")}
      </div>

      ${alertas.length ? `
      <section class="panel panel--sin-agente">
        <div class="panel__cabeza"><div><h2>${icono("alerta")} Para revisar (${num(alertas.length)})</h2>
          <p>La cuenta y la persona no están en el mismo estado: una cuenta activa de alguien que ya no trabaja, o una cuenta suspendida de alguien activo.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Cuenta</th><th>Estado de la cuenta</th><th>Persona registrada</th><th>Qué pasa</th></tr></thead>
          <tbody>${alertas.map((c) => `<tr>
            <td class="dato-mono">${esc(c.correo)}</td><td>${estadoCuentaHTML(c)}</td>
            <td><a href="#/usuarios/${c.persona.id}"><strong>${esc(titulo(c.persona.nombre))}</strong></a><span class="secundario">${esc(c.persona.departamento || "")} · ${c.persona.activo ? "activa" : "inactiva"}</span></td>
            <td>${c.alerta === "inactivo" ? "La persona está inactiva en el sistema, pero su cuenta sigue activa: valore suspenderla."
              : "La cuenta está suspendida, pero la persona está activa: no recibirá los avisos."}</td></tr>`).join("")}</tbody></table></div>
      </section>` : ""}

      <section class="panel panel--revisar">
        <div class="panel__cabeza"><div><h2>${icono("usuarios")} Personal activo sin correo${dominio ? ` de ${esc(dominio)}` : ""} (${num(r.sin_correo.length)})</h2>
          <p>No recibirán los avisos por el correo institucional. Si la lista tiene una cuenta que se le parece, agréguela con un clic.</p></div></div>
        ${r.sin_correo.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Persona</th><th>Cuenta sugerida de la lista</th><th class="col-opcional">Otros correos registrados</th><th class="col-acciones"></th></tr></thead>
          <tbody>${r.sin_correo.map((s) => `<tr>
            <td><a href="#/usuarios/${s.persona.id}"><strong>${esc(titulo(s.persona.nombre))}</strong></a><span class="secundario">${esc(s.persona.departamento || "Sin departamento")}</span></td>
            <td>${s.sugerencia ? `<span class="dato-mono">${esc(s.sugerencia)}</span>` : `<span class="sin-dato">Ninguna se le parece</span>`}</td>
            <td class="col-opcional dato-mono">${s.otros_correos.map(esc).join("<br>") || `<span class="sin-dato">—</span>`}</td>
            <td class="col-acciones">${s.sugerencia && institucional ? `<button type="button" class="btn btn--secundario btn--sm" data-agregar="${s.persona.id}" data-correo="${esc(s.sugerencia)}" data-nombre="${esc(s.persona.nombre)}">${icono("mas")}Agregar</button>`
              : `<a class="btn btn--secundario btn--sm" href="#/usuarios/${s.persona.id}">${icono("usuario")}Ficha</a>`}</td>
          </tr>`).join("")}</tbody></table></div>`
          : `<div class="panel__cuerpo"><p class="cobertura-resumen__ok">${icono("check")}<span>Todo el personal activo tiene un correo de la lista.</span></p></div>`}
      </section>

      <section class="panel" data-solo-lista>
        <div class="panel__cabeza"><div><h2>${icono("correo")} En la lista, sin registrar en el sistema (${num(r.solo_lista.length)})</h2>
          <p>Ninguna persona del sistema tiene registrado este correo. Las cuentas de uso común (sin punto en el nombre y sin parecido con nadie) suelen ser de una oficina.</p></div>
          ${r.solo_lista.length ? `<div class="buscador buscador--equipos">${icono("buscar")}<input type="search" class="control" data-buscar value="${esc(buscado)}" placeholder="Correo o nombre" aria-label="Buscar en las cuentas sin registrar"></div>` : ""}</div>
        ${r.solo_lista.length ? `<div class="chips-alerta" role="group" aria-label="Qué cuentas ver">
          <button type="button" class="chip-alerta" data-filtro="todas" aria-pressed="${filtro === "todas"}">Todas<b>${num(r.solo_lista.length)}</b></button>
          <button type="button" class="chip-alerta" data-filtro="sugerencia" aria-pressed="${filtro === "sugerencia"}"${t.con_sugerencia ? "" : " disabled"}>Con persona sugerida<b>${num(t.con_sugerencia)}</b></button>
          <button type="button" class="chip-alerta" data-filtro="generica" aria-pressed="${filtro === "generica"}"${t.genericas ? "" : " disabled"}>De uso común<b>${num(t.genericas)}</b></button>
          <button type="button" class="chip-alerta" data-filtro="suspendida" aria-pressed="${filtro === "suspendida"}"${r.solo_lista.some((x) => x.estado_cuenta === "suspendida") ? "" : " disabled"}>Suspendidas<b>${num(r.solo_lista.filter((x) => x.estado_cuenta === "suspendida").length)}</b></button>
        </div>` : ""}
        <div data-tabla-solo>${tablaSoloLista()}</div>
      </section>

      ${r.solo_sistema.length ? `
      <section class="panel panel--sin-agente">
        <div class="panel__cabeza"><div><h2>${icono("alerta")} Registrados que no están en la lista (${num(r.solo_sistema.length)})</h2>
          <p>El correo está registrado en el sistema con el dominio de la lista, pero la cuenta no aparece: puede estar mal escrito o la cuenta ya no existe.
            Los avisos a estos correos no llegarán.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Correo registrado</th><th>Persona</th><th class="col-acciones"></th></tr></thead>
          <tbody>${r.solo_sistema.map((s) => `<tr><td class="dato-mono">${esc(s.correo)}</td>
            <td><a href="#/usuarios/${s.persona.id}"><strong>${esc(titulo(s.persona.nombre))}</strong></a><span class="secundario">${esc(s.persona.departamento || "")}${s.persona.activo ? "" : " · inactiva"}</span></td>
            <td class="col-acciones"><a class="btn btn--secundario btn--sm" href="#/usuarios/${s.persona.id}">${icono("editar")}Corregir</a></td></tr>`).join("")}</tbody></table></div>
      </section>` : ""}

      ${r.coinciden.length ? `
      <details class="panel panel--plegable">
        <summary class="panel__cabeza"><div><h2>${icono("check")} Coinciden (${num(r.coinciden.length)})</h2><p>La cuenta de la lista es el correo registrado de una persona.</p></div></summary>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Correo</th><th>Estado de la cuenta</th><th>Persona registrada</th></tr></thead>
          <tbody>${r.coinciden.map((c) => `<tr><td class="dato-mono">${esc(c.correo)}</td><td>${estadoCuentaHTML(c)}</td>
            <td><a href="#/usuarios/${c.persona.id}"><strong>${esc(titulo(c.persona.nombre))}</strong></a><span class="secundario">${esc(c.persona.departamento || "")}${c.persona.activo ? "" : " · inactiva"}</span></td></tr>`).join("")}</tbody></table></div>
      </details>` : ""}`;
  };

  const recargar = async () => { r = await api(`correo/listas/${id}/`); if (ctx.vigente()) pintar(); };

  cont.addEventListener("click", async (ev) => {
    const f = ev.target.closest("[data-filtro]");
    if (f && !f.disabled) {
      filtro = f.dataset.filtro;
      todas = false;
      cont.querySelectorAll("[data-solo-lista] [data-filtro]").forEach((b) => b.setAttribute("aria-pressed", String(b === f)));
      cont.querySelector("[data-tabla-solo]").innerHTML = tablaSoloLista();
      return;
    }
    if (ev.target.closest("[data-mas]")) { todas = true; cont.querySelector("[data-tabla-solo]").innerHTML = tablaSoloLista(); return; }
    const a = ev.target.closest("[data-agregar]");
    if (a) {
      const ok = await confirmar({
        titulo: "Agregar el correo", peligro: false, textoBoton: "Agregar",
        mensaje: `Se registrará ${a.dataset.correo} como correo institucional de ${titulo(a.dataset.nombre)}.`,
        accion: () => api(`usuarios/${a.dataset.agregar}/correos/`, { metodo: "POST", datos: { cod_correo: institucional, correo: a.dataset.correo } }),
      });
      if (ok) { toast("Se agregó el correo."); await recargar(); }
      return;
    }
    if (ev.target.closest("[data-editar]")) {
      const g = await abrirFormulario({
        titulo: "Descripción de la lista", descripcion: r.lista.nombre_archivo, textoGuardar: "Guardar",
        campos: [{ nombre: "descripcion", etiqueta: "Descripción", max: 255, mayus: false }], valores: r.lista,
        alGuardar: (datos) => api(`correo/listas/${id}/`, { metodo: "PUT", datos }),
      });
      if (g) { r.lista = { ...r.lista, ...g }; pintar(); toast("Se guardó la descripción."); }
      return;
    }
    if (ev.target.closest("[data-eliminar]")) {
      const ok = await confirmar({ titulo: "Eliminar la lista", mensaje: `Se eliminará «${r.lista.nombre_archivo}» con sus ${num(r.lista.total)} correos. No cambia nada del personal.`,
        textoBoton: "Eliminar", accion: () => api(`correo/listas/${id}/`, { metodo: "DELETE" }) });
      if (ok) { toast("Se eliminó la lista."); location.hash = "#/correo/comparar"; }
      return;
    }
    if (ev.target.closest("[data-exportar]")) {
      const celda = celdaCsv;   // con protección contra fórmulas de Excel
      const filas = [["Resultado", "Correo", "Nombre en la lista", "Estado de la cuenta", "Persona registrada", "Departamento", "Persona activa", "Sugerencia"]];
      for (const c of r.coinciden) filas.push([c.alerta === "inactivo" ? "Persona inactiva con cuenta activa" : c.alerta === "suspendida" ? "Cuenta suspendida de persona activa" : "Coincide",
        c.correo, c.nombre, c.estado, c.persona.nombre, c.persona.departamento, c.persona.activo ? "Sí" : "No", ""]);
      for (const x of r.solo_lista) filas.push([x.generica ? "En la lista (uso común)" : "En la lista, sin registrar", x.correo, x.nombre, x.estado, "", "", "", x.sugerencias.map((p) => p.nombre).join(" / ")]);
      for (const s of r.solo_sistema) filas.push(["Registrado, no está en la lista", s.correo, "", "", s.persona.nombre, s.persona.departamento, s.persona.activo ? "Sí" : "No", ""]);
      for (const s of r.sin_correo) filas.push(["Personal activo sin correo del dominio", s.otros_correos.join(" "), "", "", s.persona.nombre, s.persona.departamento, "Sí", s.sugerencia || ""]);
      descargarTexto(`﻿${filas.map((f) => f.map(celda).join(";")).join("\r\n")}\r\n`, `comparacion_correos_${marcaArchivo()}.csv`);
      toast("Se descargó el archivo.");
    }
  });
  cont.addEventListener("input", debounce((ev) => {
    if (!ev.target.matches("[data-buscar]")) return;
    buscado = ev.target.value;
    cont.querySelector("[data-tabla-solo]").innerHTML = tablaSoloLista();
  }, 200));
  pintar();
}

/* =====================================================================
   Configuración de la cuenta institucional
   ===================================================================== */
export async function vistaConfigCorreo(cont, _params, ctx) {
  ctx.migas([{ texto: "Configuración" }]);
  cont.innerHTML = cargandoHTML();
  let [cfg, gente] = await Promise.all([api("correo/configuracion/"), api("correo/personal/")]);
  if (!ctx.vigente()) return;
  const yo = gente.find((p) => p.id === ctx.usuario.id);
  const proveedores = cfg.proveedores || {};
  const proveedorDe = (c) => Object.entries(proveedores).find(([, p]) => p.servidor === c.servidor)?.[0] || (c.configurada ? "otro" : "google");
  let proveedor = proveedorDe(cfg);
  const v = cfg.configurada ? cfg : { ...proveedores.google, limite_diario: 1500, activo: true, correo_remitente: "", usuario: "" };

  const resultadoPrueba = (c) => (c.ultima_prueba ? `<div class="aviso ${c.prueba_ok ? "aviso--exito" : c.prueba_ok === false ? "aviso--error" : "aviso--ocre"}">
      ${icono(c.prueba_ok ? "check" : "alerta")}<span><strong>${c.prueba_ok ? "Funciona." : c.prueba_ok === false ? "La prueba falló." : "Pruebe de nuevo."}</strong>
      ${esc(c.resultado_prueba || "")} <small>(${esc(fecha(c.ultima_prueba))})</small></span></div>`
    : `<p class="secundario">Todavía no se ha enviado un correo de prueba.</p>`);

  cont.innerHTML = `
    <div class="encabezado">
      <div class="encabezado-imp"><span class="insignia-log insignia-log--correo">${icono("llave")}</span>
        <div><h1>Cuenta de correo institucional</h1><p>La cuenta con que el sistema envía los avisos al personal. La clave se guarda cifrada y nunca se muestra.</p></div></div>
    </div>
    <div class="config-correo">
      <form class="panel" novalidate data-form>
        <div class="panel__cuerpo pila">
          <div class="campo"><span class="etiqueta-campo">Servicio de correo</span>
            <div class="segmentado" role="radiogroup" aria-label="Servicio de correo">
              ${Object.entries(proveedores).map(([k, p]) => `<button type="button" role="radio" data-proveedor="${k}" aria-checked="${proveedor === k}">${esc(p.nombre)}</button>`).join("")}
              <button type="button" role="radio" data-proveedor="otro" aria-checked="${proveedor === "otro"}">Otro servidor</button>
            </div></div>
          <div class="rejilla rejilla--tres">
            <div class="campo" data-campo="servidor"><label for="cf-servidor">Servidor SMTP <span class="req">*</span></label>
              <input id="cf-servidor" name="servidor" maxlength="150" required value="${esc(v.servidor || "")}" placeholder="smtp.gmail.com" autocomplete="off"><p class="error-campo" hidden></p></div>
            <div class="campo" data-campo="puerto"><label for="cf-puerto">Puerto <span class="req">*</span></label>
              <input id="cf-puerto" name="puerto" type="number" min="1" max="65535" required value="${esc(v.puerto || 587)}"><p class="error-campo" hidden></p></div>
            <div class="campo" data-campo="seguridad"><label for="cf-seguridad">Seguridad</label>
              <select id="cf-seguridad" name="seguridad">
                ${[["STARTTLS", "STARTTLS (puerto 587)"], ["SSL", "SSL/TLS (puerto 465)"], ["NINGUNA", "Ninguna (red interna)"]]
                  .map(([k, t]) => `<option value="${k}"${(v.seguridad || "STARTTLS") === k ? " selected" : ""}>${t}</option>`).join("")}</select><p class="error-campo" hidden></p></div>
          </div>
          <div class="rejilla">
            <div class="campo" data-campo="usuario"><label for="cf-usuario">Usuario de la cuenta</label>
              <input id="cf-usuario" name="usuario" type="email" maxlength="150" value="${esc(v.usuario || "")}" placeholder="avisos@grecia.go.cr" autocomplete="off">
              <p class="ayuda">Normalmente, el correo completo. Vacío si el servidor no pide iniciar sesión.</p><p class="error-campo" hidden></p></div>
            <div class="campo" data-campo="clave"><label for="cf-clave">Clave ${cfg.tiene_clave ? `<span class="etiqueta-nota">(guardada)</span>` : ""}</label>
              <input id="cf-clave" name="clave" type="password" maxlength="200" autocomplete="new-password" placeholder="${cfg.tiene_clave ? "Déjela en blanco para conservarla" : "Contraseña de aplicación"}">
              ${cfg.tiene_clave ? `<label class="interruptor interruptor--chico"><input type="checkbox" name="quitar_clave"><span>Quitar la clave guardada</span></label>` : ""}
              <p class="error-campo" hidden></p></div>
          </div>
          <div class="rejilla">
            <div class="campo" data-campo="correo_remitente"><label for="cf-remitente">Correo del remitente <span class="req">*</span></label>
              <input id="cf-remitente" name="correo_remitente" type="email" maxlength="150" required value="${esc(v.correo_remitente || "")}" placeholder="avisos@grecia.go.cr">
              <p class="ayuda">El «De:» de los avisos. Con Google, debe ser la misma cuenta o un alias de ella.</p><p class="error-campo" hidden></p></div>
            <div class="campo" data-campo="nombre_remitente"><label for="cf-nombre">Nombre del remitente</label>
              <input id="cf-nombre" name="nombre_remitente" maxlength="150" value="${esc(v.nombre_remitente || "")}" placeholder="Municipalidad de Grecia"><p class="error-campo" hidden></p></div>
          </div>
          <div class="rejilla">
            <div class="campo" data-campo="responder_a"><label for="cf-responder">Las respuestas llegan a <span class="etiqueta-nota">(opcional)</span></label>
              <input id="cf-responder" name="responder_a" type="email" maxlength="150" value="${esc(v.responder_a || "")}" placeholder="soporte@grecia.go.cr"><p class="error-campo" hidden></p></div>
            <div class="campo" data-campo="limite_diario"><label for="cf-limite">Límite de correos por día</label>
              <input id="cf-limite" name="limite_diario" type="number" min="1" max="100000" value="${esc(v.limite_diario || 1500)}">
              <p class="ayuda">Google Workspace permite 2000 por día y por cuenta.</p><p class="error-campo" hidden></p></div>
          </div>
          <div class="campo" data-campo="firma"><label for="cf-firma">Firma <span class="etiqueta-nota">(va al final de cada aviso)</span></label>
            <textarea id="cf-firma" name="firma" rows="3" maxlength="2000" placeholder="Departamento de Tecnologías de Información&#10;Municipalidad de Grecia">${esc(v.firma || "")}</textarea><p class="error-campo" hidden></p></div>
          <label class="interruptor"><input type="checkbox" name="activo"${v.activo !== false ? " checked" : ""}><span>Permitir el envío de avisos</span></label>
          <div data-error hidden></div>
        </div>
        <div class="panel__pie"><button type="submit" class="btn btn--primario">${icono("check")}Guardar</button></div>
      </form>
      <div class="pila">
        <section class="panel">
          <div class="panel__cabeza"><div><h2>${icono("correo")} Correo de prueba</h2><p>Guarde y envíe una prueba para confirmar que la cuenta funciona.</p></div></div>
          <div class="panel__cuerpo pila">
            <div data-resultado-prueba>${resultadoPrueba(cfg)}</div>
            <div class="campo"><label for="cf-para">Enviarlo a</label>
              <input id="cf-para" type="email" value="${esc(yo?.correo || cfg.correo_remitente || "")}" placeholder="su.correo@grecia.go.cr"></div>
            <button type="button" class="btn btn--secundario" data-probar${cfg.configurada ? "" : " disabled"}>${icono("enviar")}Enviar correo de prueba</button>
          </div>
        </section>
        <aside class="panel ayuda-importar">
          <div class="panel__cabeza"><h2>Con Google Workspace</h2></div>
          <div class="panel__cuerpo">
            <ol class="pasos-ayuda">
              <li><strong>Servidor</strong> <code>smtp.gmail.com</code>, puerto <code>587</code> con STARTTLS.</li>
              <li><strong>Usuario:</strong> la cuenta completa (por ejemplo, avisos@grecia.go.cr).</li>
              <li><strong>Clave:</strong> una contraseña de aplicación de esa cuenta: Cuenta de Google, Seguridad, Verificación en dos pasos,
                Contraseñas de aplicaciones. La clave normal no sirve.</li>
              <li><strong>Firewall:</strong> el servidor del sistema debe poder salir al puerto 587.</li>
            </ol>
            <p class="ayuda-importar__nota">${icono("candado", "ic--sm")}<span>La clave se cifra con la llave secreta de Django antes de guardarla.
              Si se cambia SECRET_KEY, hay que volver a escribirla aquí.</span></p>
          </div>
        </aside>
      </div>
    </div>`;

  const form = cont.querySelector("[data-form]");
  const caja = form.querySelector("[data-error]");
  cont.querySelectorAll("[data-proveedor]").forEach((b) => b.addEventListener("click", () => {
    proveedor = b.dataset.proveedor;
    cont.querySelectorAll("[data-proveedor]").forEach((x) => x.setAttribute("aria-checked", String(x === b)));
    const p = proveedores[proveedor];
    if (p) {
      form.servidor.value = p.servidor;
      form.puerto.value = p.puerto;
      form.seguridad.value = p.seguridad;
    } else {
      form.servidor.focus();
    }
  }));
  form.seguridad.addEventListener("change", () => {
    const puerto = { STARTTLS: 587, SSL: 465 }[form.seguridad.value];
    if (puerto && ["587", "465", "25", ""].includes(form.puerto.value)) form.puerto.value = puerto;
  });
  form.usuario.addEventListener("change", () => { if (!form.correo_remitente.value.trim()) form.correo_remitente.value = form.usuario.value.trim(); });

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    caja.hidden = true;
    form.querySelectorAll(".con-error").forEach((x) => x.classList.remove("con-error"));
    form.querySelectorAll(".error-campo").forEach((x) => { x.hidden = true; });
    if (!form.reportValidity()) return;
    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    const datos = {
      servidor: form.servidor.value.trim(), puerto: Number(form.puerto.value), seguridad: form.seguridad.value,
      usuario: form.usuario.value.trim() || null, clave: form.clave.value || null, quitar_clave: !!form.quitar_clave?.checked,
      correo_remitente: form.correo_remitente.value.trim(), nombre_remitente: form.nombre_remitente.value.trim() || null,
      responder_a: form.responder_a.value.trim() || null, firma: form.firma.value.trim() || null,
      limite_diario: Number(form.limite_diario.value) || 1500, activo: form.activo.checked,
    };
    try {
      cfg = await api("correo/configuracion/", { metodo: "PUT", datos });
      toast("Se guardó la cuenta.");
      if (ctx.vigente()) vistaConfigCorreo(cont, [], ctx);
    } catch (e) {
      botonCargando(boton, false);
      let marcado = false;
      for (const [campo, texto] of Object.entries(e.campos || {})) {
        const c = form.querySelector(`[data-campo="${CSS.escape(campo)}"]`);
        if (!c) continue;
        c.classList.add("con-error");
        c.querySelector(".error-campo").textContent = texto;
        c.querySelector(".error-campo").hidden = false;
        marcado = true;
      }
      if (!marcado) { caja.innerHTML = errorHTML(e.message); caja.hidden = false; }
    }
  });

  cont.querySelector("[data-probar]").addEventListener("click", async (ev) => {
    const boton = ev.currentTarget;
    const para = cont.querySelector("#cf-para").value.trim();
    if (!para) { cont.querySelector("#cf-para").focus(); return; }
    botonCargando(boton, true);
    try {
      const r = await api("correo/configuracion/prueba/", { metodo: "POST", datos: { para } });
      cfg = r.configuracion;
      toast(r.detail);
    } catch (e) {
      if (e.cuerpo?.configuracion) cfg = e.cuerpo.configuracion;
      else toast(e.message, "error");
    } finally {
      botonCargando(boton, false);
    }
    if (ctx.vigente()) cont.querySelector("[data-resultado-prueba]").innerHTML = resultadoPrueba(cfg);
  });
}
