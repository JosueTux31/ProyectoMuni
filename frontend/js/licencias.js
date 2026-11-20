// Módulo «Licencias y reportes» (solo administradores): control de las
// licencias de Microclaudia en los equipos del inventario, y de las cuentas
// de Google Workspace y de Sophos Email contra el personal registrado.
//   #/licencias                     resumen con lo que hay que hacer
//   #/licencias/microclaudia        equipos sin licencia, inactivos con licencia, check...
//   #/licencias/google              cuentas de Google: personal sin correo, retirados, sin uso
//   #/licencias/sophos              lo mismo con Sophos Email, y correos de Google sin licencia
import { api, apiSubir, ErrorApi } from "./api.js";
import { cargandoHTML, confirmar, debounce, errorHTML, esc, fecha, icono, toast } from "./ui.js";
import { filasCatalogo } from "./datos.js";
import { abrirEvento, descargarTexto, fechaLog, marcaArchivo, num, textoCsv } from "./logs_ui.js";

/* =====================================================================
   Piezas comunes
   ===================================================================== */
const DIA = new Intl.DateTimeFormat("es-CR", { day: "numeric", month: "short", year: "numeric" });
const dia = (v) => { const d = v ? new Date(String(v).replace(" ", "T")) : null; return d && !Number.isNaN(d.getTime()) ? DIA.format(d) : "—"; };
const titulo = (n) => String(n || "").toLowerCase().replace(/(^|\s)(\p{L})/gu, (_, a, b) => a + b.toUpperCase());
const primerNombre = (n) => titulo(String(n || "").trim().split(/\s+/)[0] || "");
const plural = (n, uno, varios) => `${num(n)} ${Number(n) === 1 ? uno : varios}`;
/** «hoy», «hace 1 día», «hace 12 días» */
const hace = (dias) => (dias === null || dias === undefined ? "" : Number(dias) <= 0 ? "hoy" : `hace ${plural(dias, "día", "días")}`);
const macGuiones = (m) => (/^[0-9A-F]{12}$/i.test(m || "") ? m.toUpperCase().match(/../g).join("-") : (m || ""));
const reemplazar = (href) => { if (location.hash !== href) history.replaceState(null, "", href); };
const ruta = (base, params) => {
  const q = new URLSearchParams(Object.entries(params).filter(([, v]) => v !== null && v !== undefined && v !== ""));
  return `${base}${q.toString() ? `?${q}` : ""}`;
};

/** Una cifra; con «ir» es un botón que baja a esa sección de la página. */
const cifra = (valor, texto, extra = "", clase = "", ir = "") => {
  const cuerpo = `<b>${valor}</b><span>${esc(texto)}</span>${extra ? `<small>${extra}</small>` : ""}`;
  return ir ? `<button type="button" class="cifra cifra--enlace${clase ? ` ${clase}` : ""}" data-ir="${ir}" title="Ver la lista">${cuerpo}</button>`
    : `<div class="cifra${clase ? ` ${clase}` : ""}">${cuerpo}</div>`;
};

/** Baja a una sección (los botones de las cifras y ?ver= en la dirección). */
function irA(cont, id) {
  const el = id && cont.querySelector(`#${CSS.escape(id)}`);
  if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
}

/** Encabezado de cada página con sus botones (importar, exportar, imprimir). */
const encabezado = (ic, clase, h1, texto, acciones = "") => `
  <div class="encabezado encabezado--imp">
    <div class="encabezado-imp"><span class="insignia-log insignia-log--${clase}">${icono(ic)}</span>
      <div><h1>${esc(h1)}</h1><p>${texto}</p></div></div>
    <div class="encabezado__acciones no-imprimir">${acciones}
      <button type="button" class="btn btn--secundario" data-exportar disabled>${icono("descargar")}Exportar (CSV)</button>
      <button type="button" class="btn btn--secundario" data-imprimir>${icono("documento")}Imprimir</button>
    </div>
  </div>`;

/**
 * Una sección con su tabla. Muestra 25 filas y un botón para ver todas.
 * columnas: [{ titulo, html(fila), clase }]
 */
function seccion({ clave, titulo: t, ic = "alerta", texto = "", filas, columnas, clase = "", vacio = "", todas = false, extraCabeza = "", pie = "" }) {
  const vista = todas ? filas : filas.slice(0, 25);
  const tabla = filas.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
      <thead><tr>${columnas.map((c) => `<th class="${(c.clase || "").replace("dato-mono", "").trim()}">${c.titulo ? esc(c.titulo) : `<span class="visualmente-oculto">Acciones</span>`}</th>`).join("")}</tr></thead>
      <tbody>${vista.map((f, i) => `<tr data-fila="${clave}:${i}"${f.id_evento && !f.id_disp ? ` class="clicable" data-evento="${f.id_evento}" tabindex="0"` : ""}>${columnas.map((c) => `<td class="${c.clase || ""}">${c.html(f)}</td>`).join("")}</tr>`).join("")}</tbody>
    </table></div>
    ${filas.length > vista.length ? `<div class="mas-filas no-imprimir"><button type="button" class="btn btn--secundario btn--sm" data-mas="${clave}">Mostrar las ${num(filas.length)}</button>
      <span>Se ven ${num(vista.length)} de ${num(filas.length)}.</span></div>` : ""}`
    : `<div class="panel__cuerpo"><p class="cobertura-resumen__ok">${icono("check")}<span>${esc(vacio || "Nada que revisar.")}</span></p></div>`;
  return `<section class="panel panel--licencia${clase ? ` ${clase}` : ""}" data-seccion="${clave}">
    <div class="panel__cabeza"><div><h2>${icono(ic)} ${esc(t)} (${num(filas.length)})</h2>${texto ? `<p>${texto}</p>` : ""}</div>${extraCabeza}</div>
    ${tabla}${pie}
  </section>`;
}

/** Imprimir: el navegador imprime solo el contenido (sin el menú ni los botones). */
function enlazarImprimir(cont) {
  cont.querySelector("[data-imprimir]")?.addEventListener("click", () => window.print());
}

/** Un botón que abre el selector de archivo y lo sube; alTerminar(respuesta). */
function botonImportar(cont, { selector, rutaApi, campos = {}, aceptar, alTerminar }) {
  const boton = cont.querySelector(selector);
  if (!boton) return;
  const input = document.createElement("input");
  input.type = "file";
  input.accept = aceptar;
  input.hidden = true;
  boton.after(input);
  boton.addEventListener("click", () => input.click());
  input.addEventListener("change", async () => {
    const archivo = input.files[0];
    input.value = "";
    if (!archivo) return;
    const datos = new FormData();
    datos.append("archivo", archivo);
    for (const [k, v] of Object.entries(campos)) datos.append(k, v);
    const texto = boton.innerHTML;
    boton.disabled = true;
    boton.innerHTML = `${icono("subir")}Importando…`;
    try {
      const r = await apiSubir(rutaApi, datos);
      toast(`Se importó ${archivo.name}.`);
      alTerminar(r);
    } catch (e) {
      toast(e instanceof ErrorApi ? e.message : "No se pudo importar el archivo.", "error");
    } finally {
      boton.disabled = false;
      boton.innerHTML = texto;
    }
  });
}

/** Cambia el check «Tiene Microclaudia» de un equipo (a mano, con confirmación). */
async function cambiarCheck(f, valor) {
  const ok = await confirmar({
    titulo: valor ? "Marcar «Tiene Microclaudia»" : "Quitar «Tiene Microclaudia»",
    mensaje: valor ? `Se marcará que ${f.equipo} tiene la licencia de Microclaudia.`
      : `Se quitará el check de Microclaudia de ${f.equipo}. Recuerde desinstalar el agente en la consola de Microclaudia si el equipo ya no se usa.`,
    textoBoton: valor ? "Marcar" : "Quitar", peligro: false,
    accion: () => api(`dispositivos/${f.id_disp}/`, { metodo: "PATCH", datos: { tiene_microclaudia: valor } }),
  });
  if (ok) toast(valor ? "Se marcó el check." : "Se quitó el check.");
  return ok;
}

/* =====================================================================
   Resumen
   ===================================================================== */
export async function vistaInicioLicencias(cont, _params, ctx) {
  ctx.migas([{ texto: "Resumen" }]);
  cont.innerHTML = `
    ${encabezado("licencia", "licencia", "Licencias y reportes",
      "Las licencias de Microclaudia en los equipos y las cuentas de correo de Google Workspace y de Sophos Email, comparadas con el inventario y con el personal registrado.")}
    <div data-resumen>${cargandoHTML("Comparando…")}</div>`;
  enlazarImprimir(cont);
  const [mc, google, sophos] = await Promise.allSettled([
    api("logs/licencias/"), api("correo/licencias/", { query: { origen: "GOOGLE" } }), api("correo/licencias/", { query: { origen: "SOPHOS" } }),
  ]);
  if (!ctx.vigente()) return;
  const caja = cont.querySelector("[data-resumen]");
  const valor = (r) => (r.status === "fulfilled" ? r.value : null);
  const m = valor(mc);
  const g = valor(google)?.resultado;
  const s = valor(sophos)?.resultado;

  // Qué hacer, en orden de importancia: cada tarea con su cantidad aparte (n) y el texto según sea una o varias
  const tareas = [];
  const tarea = (n, uno, varios, href, clase = "aviso") => { if (n > 0) tareas.push({ n, texto: n === 1 ? uno : varios, href, clase }); };
  if (m) {
    const t = m.totales;
    tarea(t.nuevos_sin_licencia, "equipo nuevo sin Microclaudia: instálele el agente.", "equipos nuevos sin Microclaudia: instáleles el agente.",
      "#/licencias/microclaudia?solo=nuevos", "sin");
    tarea(t.sin_licencia - t.nuevos_sin_licencia, "equipo activo más sin Microclaudia.", "equipos activos más sin Microclaudia.", "#/licencias/microclaudia?ver=sin-licencia");
    tarea(t.inactivos_con_licencia, "equipo dado de baja con licencia de Microclaudia: libérela desinstalando el agente.",
      "equipos dados de baja con licencia de Microclaudia: libérelas desinstalando el agente.", "#/licencias/microclaudia?ver=inactivos", "sin");
    tarea(t.no_registrados, "licencia de Microclaudia en un equipo que no está en el inventario: regístrelo.",
      "licencias de Microclaudia en equipos que no están en el inventario: regístrelos.", "#/licencias/microclaudia?ver=no-registrados");
    tarea(t.listado_sin_check + t.check_sin_listado, "equipo con el check de Microclaudia distinto al listado.",
      "equipos con el check de Microclaudia distinto al listado.", "#/licencias/microclaudia?ver=check");
  }
  if (g) {
    const t = g.totales;
    tarea(t.faltan, "persona activa sin correo de Google: créele la cuenta o registre la que tiene.",
      "personas activas sin correo de Google: créeles la cuenta o registre la que tienen.", "#/licencias/google?ver=faltan", "sin");
    tarea(t.retirados, "cuenta de Google de personal retirado sigue activa: suspéndala o elimínela.",
      "cuentas de Google de personal retirado siguen activas: suspéndalas o elimínelas.", "#/licencias/google?ver=retirados", "sin");
    tarea(t.sin_uso, `cuenta de Google sin uso en ${g.dias} días o que nunca entró.`, `cuentas de Google sin uso en ${g.dias} días o que nunca entraron.`,
      "#/licencias/google?ver=sin-uso");
    tarea(t.suspendidas, "cuenta suspendida en Google: sigue ocupando licencia.", "cuentas suspendidas en Google: siguen ocupando licencia.",
      "#/licencias/google?ver=suspendidas");
  }
  if (s) {
    const t = s.totales;
    if (s.google) {
      tarea(s.google.totales.sin_licencia, "correo de Google sin licencia de Sophos Email.", "correos de Google sin licencia de Sophos Email.",
        "#/licencias/sophos?ver=sin-licencia", "sin");
      tarea(s.google.totales.sobran, "licencia de Sophos Email en una cuenta suspendida, borrada o de personal retirado.",
        "licencias de Sophos Email en cuentas suspendidas, borradas o de personal retirado.", "#/licencias/sophos?ver=sobran");
    }
    tarea(t.retirados, "cuenta protegida por Sophos es de personal retirado.", "cuentas protegidas por Sophos son de personal retirado.",
      "#/licencias/sophos?ver=retirados");
  }

  const fuente = (r, nombre) => (r.status === "rejected" ? `<p class="top-vacio">${esc(r.reason?.message || `No se pudo leer ${nombre}.`)}</p>` : "");
  const tarjeta = (href, ic, clase, h2, sub, contenido) => `
    <section class="panel tarjeta-licencia">
      <div class="panel__cabeza"><div class="en-red__titulo"><span class="insignia-log insignia-log--sm insignia-log--${clase}">${icono(ic)}</span>
        <div><h2>${esc(h2)}</h2><p>${sub}</p></div></div>
        <a class="btn btn--secundario btn--sm no-imprimir" href="${href}">Ver detalle${icono("derecha")}</a></div>
      <div class="panel__cuerpo">${contenido}</div>
    </section>`;
  const filaDato = (n, texto, clase = "", href = "") => `<li class="dato-licencia${clase ? ` dato-licencia--${clase}` : ""}">
    ${href ? `<a href="${href}">` : ""}<b>${esc(num(n))}</b><span>${esc(texto)}</span>${href ? "</a>" : ""}</li>`;

  caja.innerHTML = `
    <section class="panel panel--tareas">
      <div class="panel__cabeza"><div><h2>${icono("check")} Qué hacer</h2><p>Lo que sale de comparar los últimos listados importados con el inventario y el personal.</p></div></div>
      <div class="panel__cuerpo">${tareas.length ? `<ol class="tareas-licencia">${tareas.map((x) => `<li class="tarea-licencia tarea-licencia--${x.clase}">
        <a href="${x.href}"><b>${esc(num(x.n))}</b><span>${esc(x.texto)}</span>${icono("derecha")}</a></li>`).join("")}</ol>`
        : `<p class="cobertura-resumen__ok">${icono("check")}<span>No hay nada pendiente con los datos importados.</span></p>`}</div>
    </section>
    <div class="licencias-tarjetas">
      ${tarjeta("#/licencias/microclaudia", "agente", "agente", "Microclaudia",
        m?.importacion ? `Listado ${esc(m.importacion.nombre_archivo)} (${esc(dia(m.importacion.creado_en))})` : "Sin listado importado: se usa el check de cada equipo",
        m ? `<ul class="datos-licencia">
            ${filaDato(m.totales.licencias_en_uso, "licencias en uso (equipos en el listado)")}
            ${filaDato(m.totales.deben_tenerla, "computadoras y servidores activos")}
            ${filaDato(m.totales.sin_licencia, `activos sin licencia (${num(m.totales.nuevos_sin_licencia)} nuevos)`, m.totales.sin_licencia ? "sin" : "ok", "#/licencias/microclaudia")}
            ${filaDato(m.totales.inactivos_con_licencia, "dados de baja con licencia", m.totales.inactivos_con_licencia ? "sin" : "ok", "#/licencias/microclaudia?ver=inactivos")}
            ${filaDato(m.totales.no_registrados, "licencias en equipos no registrados", m.totales.no_registrados ? "aviso" : "ok", "#/licencias/microclaudia?ver=no-registrados")}
          </ul>` : fuente(mc, "Microclaudia"))}
      ${tarjeta("#/licencias/google", "correo", "correo", "Google Workspace",
        g ? `Lista ${esc(g.lista.nombre_archivo)} (${esc(dia(g.lista.creado_en))})` : "Sin lista importada",
        g ? `<ul class="datos-licencia">
            ${filaDato(g.totales.cuentas, `cuentas (${num(g.totales.suspendidas)} suspendidas)`)}
            ${filaDato(g.totales.faltan, `personas activas sin correo (de ${num(g.totales.personal_activo)})`, g.totales.faltan ? "sin" : "ok", "#/licencias/google?ver=faltan")}
            ${filaDato(g.totales.retirados, "cuentas activas de personal retirado", g.totales.retirados ? "sin" : "ok", "#/licencias/google?ver=retirados")}
            ${g.trae_uso ? filaDato(g.totales.sin_uso, `sin uso en ${num(g.dias)} días o que nunca entraron`, g.totales.sin_uso ? "aviso" : "ok", "#/licencias/google?ver=sin-uso") : ""}
            ${filaDato(g.totales.sin_persona, "cuentas que no son de nadie registrado", "", "#/licencias/google?ver=sin-persona")}
          </ul>` : fuente(google, "Google") || `<p class="top-vacio">Importe la descarga de usuarios de Google en la página de Google Workspace.</p>`)}
      ${tarjeta("#/licencias/sophos", "escudo", "sophos", "Sophos Email",
        s ? `Lista ${esc(s.lista.nombre_archivo)} (${esc(dia(s.lista.creado_en))})` : "Sin lista importada",
        s ? `<ul class="datos-licencia">
            ${filaDato(s.totales.cuentas, "cuentas protegidas (licencias en uso)")}
            ${s.google ? filaDato(s.google.totales.sin_licencia, "correos de Google sin licencia de Sophos", s.google.totales.sin_licencia ? "sin" : "ok", "#/licencias/sophos?ver=sin-licencia") : ""}
            ${s.google ? filaDato(s.google.totales.sobran, "licencias que se pueden liberar", s.google.totales.sobran ? "aviso" : "ok", "#/licencias/sophos?ver=sobran") : ""}
            ${filaDato(s.totales.faltan, "personas activas sin cuenta protegida", s.totales.faltan ? "aviso" : "ok", "#/licencias/sophos?ver=faltan")}
            ${filaDato(s.totales.retirados, "cuentas de personal retirado", s.totales.retirados ? "sin" : "ok", "#/licencias/sophos?ver=retirados")}
          </ul>` : fuente(sophos, "Sophos") || `<p class="top-vacio">Importe la lista de cuentas de Sophos Email en la página de Sophos Email.</p>`)}
    </div>`;

  const exportar = cont.querySelector("[data-exportar]");
  exportar.disabled = false;
  exportar.addEventListener("click", () => {
    const filas = [["Qué hacer", "Cantidad"], ...tareas.map((x) => [`${x.n} ${x.texto}`, x.n])];
    if (m) Object.entries(m.totales).forEach(([k, v]) => filas.push([`Microclaudia: ${k.replaceAll("_", " ")}`, v]));
    if (g) Object.entries(g.totales).forEach(([k, v]) => filas.push([`Google: ${k.replaceAll("_", " ")}`, v ?? ""]));
    if (s) Object.entries(s.totales).forEach(([k, v]) => filas.push([`Sophos: ${k.replaceAll("_", " ")}`, v ?? ""]));
    if (s?.google) Object.entries(s.google.totales).forEach(([k, v]) => filas.push([`Sophos contra Google: ${k.replaceAll("_", " ")}`, v]));
    descargarTexto(textoCsv(filas), `resumen_licencias_${marcaArchivo()}.csv`);
    toast("Se descargó el resumen.");
  });
}

/* =====================================================================
   Microclaudia
   ===================================================================== */
const DIAS_NUEVO = [7, 15, 30, 60, 90];
const DIAS_CONEXION = [7, 15, 30, 60, 90];

const celdaEquipo = (f) => `<a href="#/red/dispositivos/${f.id_disp}"><strong>${esc(f.equipo || `Equipo N.º ${f.id_disp}`)}</strong></a>
  <span class="secundario">${esc([f.nombre_equipo && `En la red: ${f.nombre_equipo}`, f.asignado && titulo(f.asignado), f.edificio].filter(Boolean).join(" · ") || f.tipo)}</span>`;
const celdaDirecciones = (f) => (f.ips.length || f.macs.length
  ? `<span class="dato-mono sin-corte">${esc(f.ips.join(", ") || "Sin IP")}</span><span class="secundario dato-mono">${esc(f.macs.map(macGuiones).join(", "))}</span>`
  : `<span class="sin-dato">Sin IP ni MAC</span>`);
const celdaAgente = (a) => (a ? `<strong>${esc(a.nombre || "Sin nombre")}</strong><span class="secundario">${esc([a.version && `Agente ${a.version}`,
  a.ultima_conexion && `conectado ${fechaLog(a.ultima_conexion)}`].filter(Boolean).join(" · "))}</span>` : `<span class="sin-dato">—</span>`);
const pastillaCheck = (f) => (f.tiene_microclaudia ? `<span class="pista pista--buena">Marcado</span>` : `<span class="pista pista--neutra">Sin marcar</span>`);
const POR = { MAC: "Por su MAC", nombre: "Por el nombre", IP: "Solo por la IP" };

export async function vistaLicMicroclaudia(cont, _params, ctx) {
  ctx.migas([{ texto: "Resumen", href: "#/licencias" }, { texto: "Microclaudia" }]);
  const q = ctx.query;
  let agentes = q.get("agentes") || "";
  let nuevos = Number(q.get("nuevos")) || 30;
  let sinConexion = Number(q.get("sin_conexion")) || 30;
  let soloNuevos = q.get("solo") === "nuevos";
  const todas = new Set();
  cont.innerHTML = cargandoHTML("Comparando el inventario con Microclaudia…");
  const listados = await api("logs/importaciones/", { query: { fuente: "MICROCLAUDIA" } });
  if (!ctx.vigente()) return;

  cont.innerHTML = `
    ${encabezado("agente", "agente", "Licencias de Microclaudia",
      "Cada equipo del listado de Microclaudia ocupa una licencia. Aquí se compara con el inventario (activos e inactivos) y con el check «Tiene Microclaudia» que se marca en cada equipo.",
      `<button type="button" class="btn btn--primario" data-importar>${icono("subir")}Importar listado</button>`)}
    <section class="panel panel--filtro no-imprimir">
      <div class="cobertura-controles cobertura-controles--tres">
        <div class="campo"><label for="li-agentes">Listado de Microclaudia</label>
          <select id="li-agentes" class="control">${listados.length ? listados.map((x) => `<option value="${x.id_importacion}">
            N.º ${x.id_importacion} · ${esc(x.nombre_archivo)} · ${num(x.total_eventos)} equipos · ${esc(dia(x.creado_en))}</option>`).join("")
            : `<option value="">Todavía no hay listados</option>`}</select></div>
        <div class="campo"><label for="li-nuevos">Equipos nuevos: registrados en los últimos</label>
          <select id="li-nuevos" class="control">${DIAS_NUEVO.map((d) => `<option value="${d}"${d === nuevos ? " selected" : ""}>${d} días</option>`).join("")}</select></div>
        <div class="campo"><label for="li-conexion">Sin conexión hace más de</label>
          <select id="li-conexion" class="control">${DIAS_CONEXION.map((d) => `<option value="${d}"${d === sinConexion ? " selected" : ""}>${d} días</option>`).join("")}</select></div>
      </div>
    </section>
    <div data-resultado>${cargandoHTML("Comparando…")}</div>`;
  enlazarImprimir(cont);
  const caja = cont.querySelector("[data-resultado]");
  const exportar = cont.querySelector("[data-exportar]");
  const selAgentes = cont.querySelector("#li-agentes");
  if (agentes && listados.some((x) => String(x.id_importacion) === agentes)) selAgentes.value = agentes;
  let r = null;
  let consulta = 0;

  const pintar = () => {
    const t = r.totales;
    const imp = r.importacion;
    const sinLic = soloNuevos ? r.sin_licencia.filter((f) => f.nuevo) : r.sin_licencia;
    caja.innerHTML = `
      ${r.hay_listado ? `<p class="nota-cobertura">${icono("enlace", "ic--sm")}<span>Listado <strong>${esc(imp.nombre_archivo)}</strong>
        (${plural(imp.total_eventos, "equipo", "equipos")}, importado el ${esc(fecha(imp.creado_en))}); la conexión más reciente es del ${esc(fechaLog(r.referencia))}.</span></p>`
        : `<div class="aviso aviso--ocre">${icono("alerta")}<span>Todavía no se ha importado un listado de Microclaudia: por ahora se usa solo el check «Tiene Microclaudia» de cada equipo.
          Importe el listado (consola de Microclaudia, listado de equipos en .csv o .txt) para saber qué equipos tienen de verdad la licencia.</span></div>`}
      <div class="cifras cifras--chicas">
        ${cifra(num(t.licencias_en_uso), "Licencias en uso", "Equipos en el listado")}
        ${cifra(num(t.con_licencia), "Con licencia", `de ${num(t.deben_tenerla)} computadoras y servidores activos`, "cifra--ok")}
        ${cifra(num(t.sin_licencia), "Activos sin licencia", `${num(t.nuevos_sin_licencia)} registrados en ${nuevos} días`, t.sin_licencia ? "cifra--sin" : "", "sin-licencia")}
        ${cifra(num(t.inactivos_con_licencia), "Dados de baja con licencia", "Licencias para liberar", t.inactivos_con_licencia ? "cifra--sin" : "", "inactivos")}
        ${cifra(num(t.no_registrados), "En equipos no registrados", "Están en Microclaudia, no en el inventario", t.no_registrados ? "cifra--aviso" : "", "no-registrados")}
        ${cifra(num(t.listado_sin_check + t.check_sin_listado), "Check distinto al listado", `${num(t.con_check)} equipos con el check`, t.listado_sin_check + t.check_sin_listado ? "cifra--aviso" : "", "check")}
      </div>

      <div id="sin-licencia">${seccion({
        clave: "sin", titulo: "Equipos activos sin licencia", ic: "alerta", clase: "panel--sin-agente", todas: todas.has("sin"),
        texto: `Computadoras y servidores activos que ${r.hay_listado ? "no aparecen en el listado de Microclaudia" : "no tienen el check «Tiene Microclaudia»"}.
          Primero los nuevos: los registrados en los últimos ${nuevos} días.`,
        extraCabeza: `<div class="chips-alerta no-imprimir" role="group" aria-label="Qué equipos ver">
          <button type="button" class="chip-alerta" data-solo="todos" aria-pressed="${!soloNuevos}">Todos<b>${num(t.sin_licencia)}</b></button>
          <button type="button" class="chip-alerta" data-solo="nuevos" aria-pressed="${soloNuevos}"${t.nuevos_sin_licencia ? "" : " disabled"}>Solo nuevos<b>${num(t.nuevos_sin_licencia)}</b></button></div>`,
        filas: sinLic, vacio: soloNuevos ? "Todos los equipos nuevos tienen la licencia." : "Todas las computadoras y servidores activos tienen la licencia.",
        columnas: [
          { titulo: "Equipo", html: celdaEquipo },
          { titulo: "Registrado", html: (f) => `${esc(dia(f.creado_en))}${f.nuevo ? ` <span class="pastilla pastilla--aviso pastilla--mini">Nuevo</span>` : ""}<span class="secundario">${hace(f.dias_registrado)}</span>` },
          { titulo: "Check", html: pastillaCheck },
          { titulo: "IP y MAC", clase: "col-opcional", html: celdaDirecciones },
          { titulo: "", clase: "col-acciones no-imprimir", html: (f) => `<a class="btn btn--secundario btn--sm" href="#/red/dispositivos/${f.id_disp}">${icono("red")}Ficha</a>` },
        ],
      })}</div>

      <div id="inactivos">${seccion({
        clave: "inactivos", titulo: "Equipos dados de baja con licencia", ic: "alerta", clase: "panel--sin-agente", todas: todas.has("inactivos"),
        texto: "Están inactivos en el inventario, pero siguen en el listado de Microclaudia o con el check marcado. Desinstale el agente desde la consola de Microclaudia para liberar la licencia y quite el check.",
        filas: r.inactivos_con_licencia, vacio: "Ningún equipo dado de baja tiene la licencia.",
        columnas: [
          { titulo: "Equipo", html: celdaEquipo },
          { titulo: "Por qué", html: (f) => `${f.agente ? `En Microclaudia como <strong>${esc(f.agente.nombre)}</strong> (${esc(POR[f.por] || "")})` : ""}${f.agente && f.tiene_microclaudia ? "<br>" : ""}${f.tiene_microclaudia ? "Tiene el check marcado" : ""}` },
          { titulo: "Última conexión", html: (f) => (f.agente ? esc(fechaLog(f.agente.ultima_conexion)) : `<span class="sin-dato">—</span>`) },
          { titulo: "", clase: "col-acciones no-imprimir", html: (f) => (f.tiene_microclaudia ? `<button type="button" class="btn btn--secundario btn--sm" data-check="0" data-fila-id="${f.id_disp}">${icono("cerrar")}Quitar check</button>` : "") },
        ],
      })}</div>

      <div id="check">${r.hay_listado ? seccion({
        clave: "listado_sin_check", titulo: "En Microclaudia, pero sin el check", ic: "agente", todas: todas.has("listado_sin_check"),
        texto: "El equipo aparece en el listado de Microclaudia (tiene la licencia) pero en el inventario no está marcado «Tiene Microclaudia».",
        filas: r.listado_sin_check, vacio: "Todos los equipos del listado tienen el check.",
        columnas: [
          { titulo: "Equipo", html: celdaEquipo },
          { titulo: "En Microclaudia", html: (f) => celdaAgente(f.agente) },
          { titulo: "Coincide", html: (f) => esc(POR[f.por] || "") },
          { titulo: "", clase: "col-acciones no-imprimir", html: (f) => `<button type="button" class="btn btn--secundario btn--sm" data-check="1" data-fila-id="${f.id_disp}">${icono("check")}Marcar check</button>` },
        ],
      }) + seccion({
        clave: "check_sin_listado", titulo: "Con el check, pero no están en Microclaudia", ic: "alerta", todas: todas.has("check_sin_listado"),
        texto: "Tienen marcado «Tiene Microclaudia» pero no aparecen en el listado: el agente no está instalado, no se ha conectado o el equipo está registrado con otra MAC o nombre.",
        filas: r.check_sin_listado, vacio: "Todos los equipos con el check aparecen en el listado.",
        columnas: [
          { titulo: "Equipo", html: celdaEquipo },
          { titulo: "IP y MAC", html: celdaDirecciones },
          { titulo: "", clase: "col-acciones no-imprimir", html: (f) => `<button type="button" class="btn btn--secundario btn--sm" data-check="0" data-fila-id="${f.id_disp}">${icono("cerrar")}Quitar check</button>` },
        ],
      }) : ""}</div>

      <div id="no-registrados">${r.hay_listado ? seccion({
        clave: "no_registrados", titulo: "Licencias en equipos que no están en el inventario", ic: "red", clase: "panel--revisar", todas: todas.has("no_registrados"),
        texto: "Están en el listado de Microclaudia pero no coinciden con ningún equipo registrado (ni por MAC ni por nombre). Regístrelos o, si ya no existen, libere la licencia. Clic en la fila para ver el detalle.",
        filas: r.no_registrados, vacio: "Todos los equipos del listado están en el inventario.",
        columnas: [
          { titulo: "Equipo en Microclaudia", html: (a) => `<strong>${esc(a.nombre || "Sin nombre")}</strong><span class="secundario">${esc(a.sistema || "")}</span>` },
          { titulo: "Última conexión", html: (a) => `${esc(fechaLog(a.ultima_conexion))}${a.dias_sin_conexion ? `<span class="secundario">${hace(a.dias_sin_conexion)}</span>` : ""}` },
          { titulo: "IP y MAC", clase: "col-opcional", html: (a) => `<span class="dato-mono">${esc(a.ip || "—")}</span><span class="secundario dato-mono">${esc(macGuiones(a.mac))}</span>` },
          { titulo: "Ojo", clase: "col-opcional", html: (a) => (a.ip_de ? `Su IP es la de <a href="#/red/dispositivos/${a.ip_de.id_disp}">${esc(a.ip_de.equipo)}</a>` : "") },
          {
            titulo: "", clase: "col-acciones no-imprimir",
            html: (a) => `<a class="btn btn--secundario btn--sm" href="#/red/dispositivos/nuevo?${new URLSearchParams(Object.entries({
              ip: a.ip, mac: a.mac, equipo: a.nombre, tipo: "COMPUTADORA" }).filter(([, v]) => v))}">${icono("mas")}Registrar</a>`,
          },
        ],
      }) : ""}</div>

      ${r.revisar.length ? seccion({
        clave: "revisar", titulo: "Por revisar: solo coincide la IP", ic: "alerta", todas: todas.has("revisar"),
        texto: "La IP registrada del equipo la tiene un equipo del listado con otra MAC y otro nombre: puede ser otro equipo que recibió esa IP del DHCP.",
        filas: r.revisar,
        columnas: [
          { titulo: "Equipo registrado", html: celdaEquipo },
          { titulo: "En Microclaudia", html: (f) => celdaAgente(f.agente) },
          { titulo: "IP y MAC registradas", clase: "col-opcional", html: celdaDirecciones },
        ],
      }) : ""}

      ${r.hay_listado ? seccion({
        clave: "sin_conexion", titulo: `Sin conexión hace más de ${sinConexion} días`, ic: "historial", todas: todas.has("sin_conexion"),
        texto: "Ocupan licencia pero no se conectan a Microclaudia hace tiempo (contado desde la conexión más reciente del listado): equipos apagados, dañados o retirados.",
        filas: r.sin_conexion, vacio: "Todos los equipos del listado se conectaron hace poco.",
        columnas: [
          { titulo: "Equipo en Microclaudia", html: (a) => `<strong>${esc(a.nombre || "Sin nombre")}</strong><span class="secundario">${esc(a.sistema || "")}</span>` },
          { titulo: "Última conexión", html: (a) => `${esc(fechaLog(a.ultima_conexion))}<span class="secundario">${hace(a.dias_sin_conexion)}</span>` },
          { titulo: "En el inventario", html: (a) => (a.equipo ? `<a href="#/red/dispositivos/${a.equipo.id_disp}">${esc(a.equipo.equipo)}</a>${a.equipo.activo ? "" : `<span class="secundario">Dado de baja</span>`}` : `<span class="sin-dato">No registrado</span>`) },
        ],
      }) : ""}`;
    exportar.disabled = false;
  };

  const cargar = async () => {
    const yo = ++consulta;
    caja.classList.add("cargando-suave");
    reemplazar(ruta("#/licencias/microclaudia", { agentes, nuevos: nuevos === 30 ? "" : nuevos, sin_conexion: sinConexion === 30 ? "" : sinConexion, solo: soloNuevos ? "nuevos" : "" }));
    try {
      const d = await api("logs/licencias/", { query: { agentes, nuevos, sin_conexion: sinConexion } });
      if (!ctx.vigente() || yo !== consulta) return;
      r = d;
      pintar();
    } catch (e) {
      if (!ctx.vigente() || yo !== consulta) return;
      caja.innerHTML = errorHTML(e.message);
    } finally {
      caja.classList.remove("cargando-suave");
    }
  };

  selAgentes.addEventListener("change", () => { agentes = selAgentes.value; cargar(); });
  cont.querySelector("#li-nuevos").addEventListener("change", (ev) => { nuevos = Number(ev.target.value); cargar(); });
  cont.querySelector("#li-conexion").addEventListener("change", (ev) => { sinConexion = Number(ev.target.value); cargar(); });
  caja.addEventListener("click", async (ev) => {
    const ir = ev.target.closest("[data-ir]");
    if (ir) { irA(cont, ir.dataset.ir); return; }
    const solo = ev.target.closest("[data-solo]");
    if (solo && !solo.disabled) { soloNuevos = solo.dataset.solo === "nuevos"; pintar(); return; }
    const mas = ev.target.closest("[data-mas]");
    if (mas) { todas.add(mas.dataset.mas); pintar(); return; }
    const b = ev.target.closest("[data-check]");
    if (b) {
      const f = r.equipos.find((x) => String(x.id_disp) === b.dataset.filaId);
      if (f && await cambiarCheck(f, b.dataset.check === "1")) cargar();
      return;
    }
    const tr = ev.target.closest("tr[data-evento]");
    if (tr && !ev.target.closest("a, button")) abrirEvento(Number(tr.dataset.evento));
  });
  caja.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest?.("tr[data-evento]");
    if (tr && ev.target === tr && ev.key === "Enter") abrirEvento(Number(tr.dataset.evento));
  });
  botonImportar(cont, {
    selector: "[data-importar]", rutaApi: "logs/importaciones/microclaudia/", aceptar: ".csv,.txt,.text,text/csv,text/plain",
    alTerminar: (imp) => { agentes = String(imp?.id_importacion || ""); vistaLicMicroclaudia(cont, [], { ...ctx, query: new URLSearchParams(agentes ? { agentes } : {}) }); },
  });
  exportar.addEventListener("click", () => {
    if (!r) return;
    const filas = [["Situación", "Equipo", "Serie", "Tipo", "Activo", "Nombre en la red", "Responsable", "Edificio", "Registrado",
      "Check «Tiene Microclaudia»", "En Microclaudia como", "Coincide por", "Última conexión", "Versión del agente", "IP", "MAC"]];
    for (const f of r.equipos) {
      filas.push([r.situaciones[f.situacion] || f.situacion, f.equipo, f.serie, f.tipo, f.activo ? "Sí" : "No", f.nombre_equipo || "", f.asignado || "",
        f.edificio || "", dia(f.creado_en), f.tiene_microclaudia ? "Sí" : "No", f.agente?.nombre || "", POR[f.por] || "",
        f.agente ? fechaLog(f.agente.ultima_conexion) : "", f.agente?.version || "", f.ips.join(" "), f.macs.map(macGuiones).join(" ")]);
    }
    for (const a of r.no_registrados) {
      filas.push(["Licencia en equipo no registrado", "", "", "", "", "", "", "", "", "", a.nombre || "", "", fechaLog(a.ultima_conexion),
        a.version || "", a.ips.join(" "), a.macs.map(macGuiones).join(" ")]);
    }
    descargarTexto(textoCsv(filas), `licencias_microclaudia_${marcaArchivo()}.csv`);
    toast("Se descargó el reporte.");
  });
  const ver = q.get("ver");
  await cargar();
  if (ver && ctx.vigente()) irA(cont, ver);
}



/* =====================================================================
   Correos: Google Workspace y Sophos Email (misma página, otra lista)
   ===================================================================== */
const DEF_CORREO = {
  GOOGLE: {
    ruta: "#/licencias/google", nombre: "Google Workspace", h1: "Cuentas de Google Workspace", ic: "correo", clase: "correo",
    texto: "Las cuentas de correo de Google comparadas con el personal: a quién le falta el correo, qué cuentas siguen activas de personal retirado y cuáles no se usan.",
    ayuda: "La descarga de usuarios de la consola de Google (Directorio › Usuarios › Descargar usuarios, con todas las columnas): así trae también el último acceso (Last Sign In) y el uso (Email Usage).",
  },
  SOPHOS: {
    ruta: "#/licencias/sophos", nombre: "Sophos Email", h1: "Cuentas protegidas por Sophos Email", ic: "escudo", clase: "sophos",
    texto: "Las cuentas protegidas por Sophos Email (cada una ocupa una licencia) comparadas con el personal y con las cuentas de Google: correos sin licencia y licencias que se pueden liberar.",
    ayuda: "La lista de cuentas protegidas por Sophos Email en .csv, .txt o .xlsx, con el correo (y si los trae, el estado, el último acceso y el uso).",
  },
};

const estadoCuenta = (c) => (c.suspendida ? `<span class="pista pista--mala">Suspendida</span>` : `<span class="pista pista--buena">Activa</span>`);
const celdaPersona = (p, sinTexto = "Nadie registrado") => (p ? `<a href="#/usuarios/${p.id}"><strong>${esc(titulo(p.nombre))}</strong></a>
  <span class="secundario">${esc(p.departamento || "Sin departamento")}${p.activo ? "" : " · retirada (inactiva)"}</span>` : `<span class="sin-dato">${esc(sinTexto)}</span>`);
const celdaCuenta = (c) => `<span class="dato-mono">${esc(c.correo)}</span>${c.nombre ? `<span class="secundario">${esc(c.nombre)}</span>` : ""}`;
const celdaAcceso = (c) => (c.nunca_entro ? `<span class="pista pista--mala">Nunca entró</span>`
  : c.ultimo_acceso ? `${esc(dia(c.ultimo_acceso))}${c.dias_sin_entrar !== null && c.dias_sin_entrar !== undefined ? `<span class="secundario">${hace(c.dias_sin_entrar)}</span>` : ""}`
    : `<span class="sin-dato">—</span>`);
const celdaUso = (c) => (c.uso_gb === null || c.uso_gb === undefined ? `<span class="sin-dato">—</span>` : `${esc(c.uso_gb.toLocaleString("es-CR", { maximumFractionDigits: 2 }))} GB`);

export async function vistaLicCorreo(cont, _params, ctx, origen) {
  const def = DEF_CORREO[origen];
  ctx.migas([{ texto: "Resumen", href: "#/licencias" }, { texto: def.nombre }]);
  const q = ctx.query;
  let lista = q.get("lista") || "";
  let dias = Number(q.get("dias")) || 90;
  let google = q.get("google") || "";
  const todas = new Set();
  let buscado = "";
  cont.innerHTML = cargandoHTML("Comparando con el personal…");
  const tipos = await filasCatalogo("tipos-correos").catch(() => []);
  const institucional = (tipos.find((t) => /INSTITUCIONAL/i.test(t.descripcion)) || tipos[0])?.cod_correo;
  if (!ctx.vigente()) return;

  cont.innerHTML = `
    ${encabezado(def.ic, def.clase, def.h1, def.texto, `<button type="button" class="btn btn--primario" data-importar>${icono("subir")}Importar lista</button>`)}
    <section class="panel panel--filtro no-imprimir" data-controles>${cargandoHTML()}</section>
    <div data-resultado>${cargandoHTML("Comparando…")}</div>`;
  enlazarImprimir(cont);
  const caja = cont.querySelector("[data-resultado]");
  const controles = cont.querySelector("[data-controles]");
  const exportar = cont.querySelector("[data-exportar]");
  let d = null;
  let consulta = 0;

  const pintarControles = () => {
    const opcion = (x) => `<option value="${x.id_lista}"${x.id_lista === d.resultado?.lista.id_lista ? " selected" : ""}>N.º ${x.id_lista} · ${esc(x.nombre_archivo)} · ${num(x.total)} cuentas · ${esc(dia(x.creado_en))}</option>`;
    controles.innerHTML = `<div class="cobertura-controles${origen === "SOPHOS" ? " cobertura-controles--tres" : ""}">
      <div class="campo"><label for="lc-lista">Lista de ${esc(def.nombre)}</label>
        <select id="lc-lista" class="control">${d.listas.length ? d.listas.map(opcion).join("") : `<option value="">Todavía no hay listas</option>`}</select></div>
      <div class="campo"><label for="lc-dias">Cuenta sin uso: sin entrar hace más de</label>
        <select id="lc-dias" class="control">${d.opciones_dias.map((x) => `<option value="${x}"${x === d.dias ? " selected" : ""}>${x} días</option>`).join("")}</select></div>
      ${origen === "SOPHOS" ? `<div class="campo"><label for="lc-google">Comparar con la lista de Google</label>
        <select id="lc-google" class="control"><option value="0"${d.resultado && !d.resultado.google ? " selected" : ""}>No comparar</option>${d.listas_google.map((x) =>
          `<option value="${x.id_lista}"${x.id_lista === d.resultado?.google?.lista.id_lista ? " selected" : ""}>N.º ${x.id_lista} · ${esc(x.nombre_archivo)} · ${num(x.total)} cuentas</option>`).join("")}</select></div>` : ""}
    </div>`;
  };

  const tablaTodas = (r) => {
    const t = buscado.trim().toLowerCase();
    const filas = t ? r.cuentas.filter((c) => [c.correo, c.nombre, c.persona?.nombre].some((v) => String(v || "").toLowerCase().includes(t))) : r.cuentas;
    return seccion({
      clave: "todas", titulo: "Todas las cuentas", ic: "correo", todas: todas.has("todas"), filas, vacio: "Ninguna cuenta coincide con la búsqueda.",
      columnas: [
        { titulo: "Cuenta", html: celdaCuenta }, { titulo: "Estado", html: estadoCuenta },
        { titulo: "Persona registrada", html: (c) => celdaPersona(c.persona, c.generica ? "Cuenta de uso común" : "Nadie registrado") },
        ...(r.trae_uso ? [{ titulo: "Último acceso", html: celdaAcceso }] : []),
        ...(r.trae_tamano ? [{ titulo: "Uso", clase: "col-numero", html: celdaUso }] : []),
      ],
    });
  };

  const pintar = () => {
    const r = d.resultado;
    if (!r) {
      caja.innerHTML = `<section class="panel"><div class="panel__cuerpo"><div class="vacio">${icono(def.ic)}<strong>Todavía no hay una lista de ${esc(def.nombre)}</strong>
        <p>${esc(def.ayuda)}</p><button type="button" class="btn btn--primario" data-importar-vacio>${icono("subir")}Importar lista</button></div></div></section>`;
      exportar.disabled = true;
      return;
    }
    const t = r.totales;
    const g = r.google;
    const dominio = r.dominios[0]?.dominio || "";
    const colUso = r.trae_uso ? [{ titulo: "Último acceso", html: celdaAcceso }] : [];
    const colTam = r.trae_tamano ? [{ titulo: "Uso", clase: "col-numero col-opcional", html: celdaUso }] : [];
    const botonAgregar = (persona, correo) => (persona && correo && institucional
      ? `<button type="button" class="btn btn--secundario btn--sm" data-agregar="${persona.id}" data-correo="${esc(correo)}" data-nombre="${esc(persona.nombre)}">${icono("mas")}Agregar a ${esc(primerNombre(persona.nombre))}</button>` : "");

    caja.innerHTML = `
      <p class="nota-cobertura">${icono("enlace", "ic--sm")}<span>Lista <strong>${esc(r.lista.nombre_archivo)}</strong>
        (${plural(t.cuentas, "cuenta", "cuentas")}${dominio ? ` de ${esc(r.dominios.map((x) => x.dominio).join(", "))}` : ""}, importada el ${esc(fecha(r.lista.creado_en))})${r.referencia
          ? `; el último acceso más reciente es del ${esc(fechaLog(r.referencia))}: los días sin entrar se cuentan desde ahí` : ""}.</span></p>
      ${r.trae_uso ? "" : `<div class="aviso aviso--ocre">${icono("alerta")}<span>Esta lista no trae el último acceso ni el uso de cada cuenta, así que no se puede saber cuáles no se usan.
        ${esc(def.ayuda)}</span></div>`}
      <div class="cifras cifras--chicas">
        ${cifra(num(t.cuentas), "Cuentas (licencias)", `${num(t.activas)} activas · ${num(t.suspendidas)} suspendidas`)}
        ${cifra(num(t.faltan), "Personal activo sin correo", `de ${num(t.personal_activo)} personas activas`, t.faltan ? "cifra--sin" : "cifra--ok", "faltan")}
        ${cifra(num(t.retirados), "Cuentas de personal retirado", "Activas, de personas inactivas", t.retirados ? "cifra--sin" : "cifra--ok", "retirados")}
        ${r.trae_uso ? cifra(num(t.sin_uso), "Cuentas sin uso", `${num(t.nunca_entraron)} nunca entraron · más de ${num(r.dias)} días`, t.sin_uso ? "cifra--aviso" : "cifra--ok", "sin-uso") : ""}
        ${cifra(num(t.suspendidas), "Suspendidas", "Siguen ocupando licencia", t.suspendidas ? "cifra--aviso" : "", "suspendidas")}
        ${t.uso_total_gb !== null ? cifra(`${num(Math.round(t.uso_total_gb))} <small>GB</small>`, "Espacio usado", `en ${plural(t.cuentas, "cuenta", "cuentas")}`) : cifra(num(t.sin_persona), "Sin persona registrada", `${num(t.genericas)} de uso común`, "", "sin-persona")}
      </div>
      ${g ? `
      <h2 class="titulo-cruce">Contra la lista de Google ${esc(g.lista.nombre_archivo)} (${plural(g.totales.google, "cuenta", "cuentas")})</h2>
      <div class="cifras cifras--chicas cifras--tres">
        ${cifra(num(g.totales.sin_licencia), "Correos de Google sin licencia de Sophos", `de ${num(g.totales.google_activas)} cuentas activas en Google`, g.totales.sin_licencia ? "cifra--sin" : "cifra--ok", "sin-licencia")}
        ${cifra(num(g.totales.sobran), "Licencias que se pueden liberar", "Suspendidas o borradas en Google, o de personal retirado", g.totales.sobran ? "cifra--aviso" : "cifra--ok", "sobran")}
        ${cifra(num(g.totales.no_en_google), "No están en Google", "La cuenta ya no existe en Google", g.totales.no_en_google ? "cifra--aviso" : "")}
      </div>` : origen === "SOPHOS" && d.listas_google.length === 0 ? `<div class="aviso aviso--info">${icono("enlace")}<span>Importe también la lista de Google en
        <a href="#/licencias/google">Google Workspace</a> para ver qué correos no tienen licencia de Sophos.</span></div>` : ""}

      <div id="faltan">${seccion({
        clave: "faltan", titulo: `Personal activo sin correo${dominio ? ` de ${dominio}` : ""}`, ic: "usuarios", clase: "panel--revisar", todas: todas.has("faltan"),
        texto: `Personas activas en el sistema sin ninguna cuenta de esta lista: son los correos que faltan${origen === "SOPHOS" ? " por proteger" : ""}. Si la lista tiene una cuenta que se le parece, agréguela con un clic.`,
        filas: r.faltan, vacio: "Todo el personal activo tiene una cuenta de la lista.",
        columnas: [
          { titulo: "Persona", html: (s) => celdaPersona(s.persona) },
          { titulo: "Cuenta de la lista que se le parece", html: (s) => (s.sugerencia ? `<span class="dato-mono">${esc(s.sugerencia)}</span>` : `<span class="sin-dato">Ninguna</span>`) },
          { titulo: "Otros correos registrados", clase: "col-opcional dato-mono", html: (s) => s.otros_correos.map(esc).join("<br>") || `<span class="sin-dato">—</span>` },
          { titulo: "", clase: "col-acciones no-imprimir", html: (s) => botonAgregar(s.persona, s.sugerencia) || `<a class="btn btn--secundario btn--sm" href="#/usuarios/${s.persona.id}">${icono("usuario")}Ficha</a>` },
        ],
      })}</div>

      <div id="retirados">${seccion({
        clave: "retirados", titulo: "Cuentas activas de personal retirado", ic: "alerta", clase: "panel--sin-agente", todas: todas.has("retirados"),
        texto: "La persona está inactiva en el sistema pero su cuenta sigue activa y ocupando una licencia: suspéndala, archívela o elimínela.",
        filas: r.retirados, vacio: "Ninguna cuenta activa es de personal retirado.",
        columnas: [{ titulo: "Cuenta", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona) }, ...colUso, ...colTam],
      })}</div>

      ${r.trae_uso ? `<div id="sin-uso">${seccion({
        clave: "sin_uso", titulo: "Cuentas sin uso", ic: "historial", clase: "panel--revisar", todas: todas.has("sin_uso"),
        texto: `Cuentas activas que nunca han iniciado sesión o que no entran hace más de ${num(r.dias)} días: revise si todavía se necesitan.`,
        filas: r.sin_uso, vacio: `Todas las cuentas activas entraron en los últimos ${num(r.dias)} días.`,
        columnas: [{ titulo: "Cuenta", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona, c.generica ? "Cuenta de uso común" : "Nadie registrado") },
          { titulo: "Último acceso", html: celdaAcceso }, ...colTam],
      })}</div>` : ""}

      <div id="suspendidas">${seccion({
        clave: "suspendidas", titulo: "Cuentas suspendidas", ic: "candado", todas: todas.has("suspendidas"),
        texto: "Una cuenta suspendida no envía ni recibe correo, pero sigue ocupando su licencia. Si la persona ya no está, elimínela o archívela; si está activa, no recibirá los avisos.",
        filas: r.suspendidas, vacio: "No hay cuentas suspendidas.",
        columnas: [{ titulo: "Cuenta", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona) }, ...colUso, ...colTam],
      })}</div>

      ${g ? `<div id="sin-licencia">${seccion({
        clave: "sin_licencia", titulo: "Correos de Google sin licencia de Sophos", ic: "escudo", clase: "panel--sin-agente", todas: todas.has("sin_licencia"),
        texto: "Cuentas activas en Google que no están protegidas por Sophos Email. Primero las de personal activo.",
        filas: g.sin_licencia, vacio: "Todas las cuentas activas de Google tienen licencia de Sophos.",
        columnas: [{ titulo: "Cuenta de Google", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona) }],
      })}</div>
      <div id="sobran">${seccion({
        clave: "no_en_google", titulo: "Licencias de Sophos de cuentas que no están en Google", ic: "alerta", todas: todas.has("no_en_google"),
        texto: "La cuenta está protegida por Sophos pero ya no existe en Google: libere la licencia.",
        filas: g.no_en_google, vacio: "Todas las cuentas de Sophos están en Google.",
        columnas: [{ titulo: "Cuenta", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona) }, ...colUso],
      })}${seccion({
        clave: "suspendida_en_google", titulo: "Licencias de Sophos de cuentas suspendidas en Google", ic: "candado", todas: todas.has("suspendida_en_google"),
        texto: "La cuenta está suspendida en Google pero sigue ocupando una licencia de Sophos.",
        filas: g.suspendida_en_google, vacio: "Ninguna cuenta de Sophos está suspendida en Google.",
        columnas: [{ titulo: "Cuenta", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona) }, ...colUso],
      })}</div>` : ""}

      <div id="sin-persona">${seccion({
        clave: "sin_persona", titulo: "Cuentas que no son de nadie registrado", ic: "correo", todas: todas.has("sin_persona"),
        texto: "Ninguna persona del sistema tiene registrado este correo. Las de uso común (sin punto en el nombre y sin parecido con nadie) suelen ser de una oficina.",
        filas: r.sin_persona, vacio: "Todas las cuentas son de alguien registrado.",
        columnas: [
          { titulo: "Cuenta", html: celdaCuenta }, { titulo: "Estado", html: estadoCuenta },
          { titulo: "Se parece a", html: (c) => (c.sugerencias[0] ? celdaPersona(c.sugerencias[0]) : `<span class="sin-dato">${c.generica ? "Cuenta de uso común" : "Nadie"}</span>`) },
          ...colUso,
          { titulo: "", clase: "col-acciones no-imprimir", html: (c) => botonAgregar(c.sugerencias[0], c.correo) },
        ],
      })}</div>

      ${r.solo_sistema.length ? seccion({
        clave: "solo_sistema", titulo: "Registrados que no están en la lista", ic: "alerta", todas: todas.has("solo_sistema"),
        texto: "El correo está registrado en el sistema con el dominio de la lista, pero la cuenta no aparece: puede estar mal escrito o ya no existe.",
        filas: r.solo_sistema,
        columnas: [{ titulo: "Correo registrado", clase: "dato-mono", html: (s) => esc(s.correo) }, { titulo: "Persona", html: (s) => celdaPersona(s.persona) },
          { titulo: "", clase: "col-acciones no-imprimir", html: (s) => `<a class="btn btn--secundario btn--sm" href="#/usuarios/${s.persona.id}">${icono("editar")}Corregir</a>` }],
      }) : ""}

      ${r.mayores.length ? seccion({
        clave: "mayores", titulo: "Los buzones más grandes", ic: "grafico", todas: true, filas: r.mayores,
        columnas: [{ titulo: "Cuenta", html: celdaCuenta }, { titulo: "Persona", html: (c) => celdaPersona(c.persona, c.generica ? "Cuenta de uso común" : "Nadie registrado") },
          { titulo: "Uso", clase: "col-numero", html: celdaUso }, ...colUso],
      }) : ""}

      <details class="panel panel--plegable" data-plegable-todas>
        <summary class="panel__cabeza"><div><h2>${icono("correo")} Todas las cuentas (${num(r.cuentas.length)})</h2><p>Con su estado, la persona registrada${r.trae_uso ? ", el último acceso" : ""}${r.trae_tamano ? " y el uso" : ""}.</p></div></summary>
        <div class="panel__cuerpo no-imprimir"><div class="buscador buscador--equipos">${icono("buscar")}<input type="search" class="control" data-buscar value="${esc(buscado)}" placeholder="Correo o nombre" aria-label="Buscar cuentas"></div></div>
        <div data-tabla-todas>${tablaTodas(r)}</div>
      </details>`;
    exportar.disabled = false;
  };

  const cargar = async () => {
    const yo = ++consulta;
    caja.classList.add("cargando-suave");
    reemplazar(ruta(def.ruta, { lista, dias: dias === 90 ? "" : dias, google }));
    try {
      const x = await api("correo/licencias/", { query: { origen, lista, dias, google } });
      if (!ctx.vigente() || yo !== consulta) return;
      d = x;
      pintarControles();
      pintar();
    } catch (e) {
      if (!ctx.vigente() || yo !== consulta) return;
      caja.innerHTML = errorHTML(e.message);
    } finally {
      caja.classList.remove("cargando-suave");
    }
  };

  controles.addEventListener("change", (ev) => {
    if (ev.target.id === "lc-lista") lista = ev.target.value;
    if (ev.target.id === "lc-dias") dias = Number(ev.target.value);
    if (ev.target.id === "lc-google") google = ev.target.value;
    cargar();
  });
  caja.addEventListener("input", debounce((ev) => {
    if (!ev.target.matches("[data-buscar]") || !d?.resultado) return;
    buscado = ev.target.value;
    caja.querySelector("[data-tabla-todas]").innerHTML = tablaTodas(d.resultado);
  }, 200));
  caja.addEventListener("click", async (ev) => {
    const ir = ev.target.closest("[data-ir]");
    if (ir) { irA(cont, ir.dataset.ir); return; }
    if (ev.target.closest("[data-importar-vacio]")) { cont.querySelector("[data-importar]").click(); return; }
    const mas = ev.target.closest("[data-mas]");
    if (mas) {
      todas.add(mas.dataset.mas);
      if (mas.dataset.mas === "todas") caja.querySelector("[data-tabla-todas]").innerHTML = tablaTodas(d.resultado);
      else pintar();
      return;
    }
    const a = ev.target.closest("[data-agregar]");
    if (a) {
      const ok = await confirmar({
        titulo: "Agregar el correo", peligro: false, textoBoton: "Agregar",
        mensaje: `Se registrará ${a.dataset.correo} como correo institucional de ${titulo(a.dataset.nombre)}.`,
        accion: () => api(`usuarios/${a.dataset.agregar}/correos/`, { metodo: "POST", datos: { cod_correo: institucional, correo: a.dataset.correo } }),
      });
      if (ok) { toast("Se agregó el correo."); cargar(); }
    }
  });
  botonImportar(cont, {
    selector: "[data-importar]", rutaApi: "correo/listas/", campos: { origen }, aceptar: ".csv,.txt,.xlsx,.text,text/csv,text/plain",
    alTerminar: (x) => { lista = String(x?.lista?.id_lista || ""); cargar(); },
  });
  exportar.addEventListener("click", () => {
    const r = d?.resultado;
    if (!r) return;
    const filas = [["Situación", "Correo", "Nombre en la lista", "Estado de la cuenta", "Persona registrada", "Departamento", "Persona activa",
      "Último acceso", "Nunca entró", "Días sin entrar", "Uso (GB)"]];
    const fila = (sit, c, p = c.persona) => filas.push([sit, c.correo, c.nombre || "", c.estado || "", p ? titulo(p.nombre) : "", p?.departamento || "",
      p ? (p.activo ? "Sí" : "No") : "", c.ultimo_acceso ? fechaLog(c.ultimo_acceso) : "", c.nunca_entro ? "Sí" : "", c.dias_sin_entrar ?? "",
      c.uso_gb ?? ""]);
    for (const s of r.faltan) {
      filas.push(["Persona activa sin correo", s.sugerencia || "", "", "", titulo(s.persona.nombre), s.persona.departamento || "", "Sí", "", "", "", ""]);
    }
    for (const c of r.cuentas) {
      const sit = c.persona && !c.persona.activo && !c.suspendida ? "Cuenta activa de personal retirado"
        : c.suspendida ? "Suspendida" : c.sin_uso ? (c.nunca_entro ? "Nunca entró" : `Sin uso en ${r.dias} días`)
          : !c.persona ? (c.generica ? "De uso común" : "Sin persona registrada") : "En uso";
      fila(sit, c);
    }
    if (r.google) {
      for (const c of r.google.sin_licencia) fila("Correo de Google sin licencia de Sophos", c);
      for (const c of r.google.no_en_google) fila("Licencia de Sophos de cuenta que no está en Google", c);
      for (const c of r.google.suspendida_en_google) fila("Licencia de Sophos de cuenta suspendida en Google", c);
    }
    descargarTexto(textoCsv(filas), `licencias_${origen.toLowerCase()}_${marcaArchivo()}.csv`);
    toast("Se descargó el reporte.");
  });
  const ver = q.get("ver");
  await cargar();
  if (ver && ctx.vigente()) irA(cont, ver);
}
