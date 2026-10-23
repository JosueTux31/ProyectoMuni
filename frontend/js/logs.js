// Módulo de análisis de logs (tipo SIEM). Pantallas:
//   #/logs                       inicio del módulo
//   #/logs/importar/sophos       importar archivos de Sophos Firewall
//   #/logs/importaciones         archivos importados
//   #/logs/importaciones/<id>    tablero visual de una importación
//   #/logs/tablero?q=&importaciones=     tablero de cualquier filtro
//   #/logs/eventos?q=&importaciones=     explorador con filtro estilo Wireshark
//   #/logs/comparar?importaciones=1,2    comparación de 2 a 4 conjuntos
//   #/logs/inventario?q=&importaciones=  cruce con equipos y personas
//   #/logs/campos                campos comunes y alias de cada programa
import { api, apiSubir } from "./api.js";
import { abrirFormulario, cargandoHTML, confirmar, errorHTML, esc, fecha, icono, toast, vacioHTML } from "./ui.js";
import {
  abrirEvento, activarBarraFiltro, activarGlobos, agregarCondicion, barraFiltroHTML, bytes, catalogoCampos, claseGrupo,
  compacto, condicion, descargar, escucharDocumento, eventos, descargarTexto, diaLog, esMono, fechaFiltro, fechaLog, horaLog, leyendaAccionesHTML,
  lineaTiempo, listaIds, listaTopHTML, macGuiones, marcaArchivo, medidorAcciones, num, olvidarCatalogo, pastillaAccion, pct,
  rangoFechas, reemplazarRuta, rutaLogs, tablaTiempoHTML, valorCorto,
} from "./logs_ui.js";

const FUENTES = { SOPHOS: "Sophos Firewall" };
const MAX_MB = 100;

// Resultado de la última importación (para mostrar los avisos en su tablero)
const recienImportadas = new Map();

/* =====================================================================
   Inicio del módulo
   ===================================================================== */
export async function vistaInicioLogs(cont, _params, ctx) {
  ctx.migas([{ texto: "Inicio" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Análisis de logs</h1>
        <p>Importe los registros del firewall y véalos de inmediato en gráficos. Fíltrelos como en Wireshark, compare varios logs
          entre sí y crúcelos con el inventario de equipos y con el personal.</p>
      </div>
      <div class="encabezado__acciones"><a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Importar logs de Sophos</a></div>
    </div>
    <div data-resumen>${cargandoHTML()}</div>

    <h2 class="titulo-seccion">Importar desde</h2>
    <div class="fuentes">
      <a class="fuente" href="#/logs/importar/sophos">
        <span class="fuente__icono">${icono("firewall")}</span>
        <span class="fuente__texto"><strong>Sophos Firewall</strong>
          <span>Log viewer: Firewall, Web filter, SSL/TLS, IPS, ATP… El archivo .txt o .log que se copia o descarga.</span></span>
        <span class="fuente__ir">Importar${icono("derecha")}</span>
      </a>
      <div class="fuente fuente--pronto">
        <span class="fuente__icono">${icono("mas")}</span>
        <span class="fuente__texto"><strong>Otros programas</strong>
          <span>Cada programa tendrá su propia pantalla de importación. Todos llegan a los mismos campos comunes, así se pueden comparar entre sí.</span></span>
      </div>
    </div>

    <div class="dos-columnas">
      <section class="panel">
        <div class="panel__cabeza"><div><h2>Importaciones recientes</h2><p>Abra una para ver su tablero.</p></div>
          <a class="btn btn--fantasma btn--sm" href="#/logs/importaciones">Ver todas</a></div>
        <div data-recientes>${cargandoHTML()}</div>
      </section>
      <section class="panel">
        <div class="panel__cabeza"><h2>Análisis</h2></div>
        <ul class="atajos">
          ${atajo("#/logs/eventos", "filtro", "Explorar eventos", "Filtro estilo Wireshark, detalle y exportación")}
          ${atajo("#/logs/tablero", "grafico", "Tablero general", "Gráficos de todos los logs o de un filtro")}
          ${atajo("#/logs/comparar", "comparar", "Comparar logs", "Qué tienen en común y qué solo aparece en uno")}
          ${atajo("#/logs/inventario", "red", "Cruce con el inventario", "Equipos, IP sin registrar y personas")}
          ${atajo("#/logs/campos", "campos", "Campos y alias", "Cómo se llama cada dato en cada programa")}
        </ul>
      </section>
    </div>`;

  const imps = await api("logs/importaciones/");
  if (!ctx.vigente()) return;
  const suma = (k) => imps.reduce((s, x) => s + (Number(x[k]) || 0), 0);
  const desde = imps.map((x) => x.fecha_desde).filter(Boolean).sort()[0];
  const hasta = imps.map((x) => x.fecha_hasta).filter(Boolean).sort().pop();
  cont.querySelector("[data-resumen]").outerHTML = `
    <nav class="resumen" aria-label="Resumen">
      <a href="#/logs/importaciones"><b>${num(imps.length)}</b><span>Importaciones</span></a>
      <a href="#/logs/eventos"><b>${compacto(suma("total_eventos"))}</b><span>Eventos guardados</span></a>
      <a href="${rutaLogs("eventos", { q: "accion == denegado" })}"><b>${compacto(suma("denegados"))}</b><span>Eventos denegados</span></a>
      <a href="#/logs/tablero"><b class="resumen__texto">${esc(desde ? rangoFechas(desde, hasta) : "—")}</b><span>Período de los logs</span></a>
    </nav>`;

  const caja = cont.querySelector("[data-recientes]");
  if (!imps.length) {
    caja.innerHTML = vacioHTML({
      icono: "logs", titulo: "Todavía no hay logs importados", texto: "Importe el primer archivo de Sophos para ver su tablero.",
      boton: `<a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Importar logs de Sophos</a>`,
    });
    return;
  }
  caja.innerHTML = `<ul class="lista-importaciones">${[...imps].sort((a, b) => b.id_importacion - a.id_importacion).slice(0, 6)
    .map(tarjetaImportacion).join("")}</ul>`;
  activarGlobos(caja);
}

const atajo = (href, ic, titulo, texto) =>
  `<li><a href="${href}">${icono(ic)}<span><strong>${esc(titulo)}</strong><small>${esc(texto)}</small></span>${icono("derecha")}</a></li>`;

function tarjetaImportacion(x) {
  return `<li><a class="tarjeta-imp" href="#/logs/importaciones/${x.id_importacion}">
    <span class="tarjeta-imp__icono">${icono("logs")}</span>
    <span class="tarjeta-imp__texto">
      <strong>${esc(x.nombre_archivo)}</strong>
      <small>N.º ${x.id_importacion} · ${esc(FUENTES[x.fuente] || x.fuente)} · ${esc(rangoFechas(x.fecha_desde, x.fecha_hasta))}${x.descripcion ? ` · ${esc(x.descripcion)}` : ""}</small>
      ${miniMedidor(x)}
    </span>
    <span class="tarjeta-imp__n"><b>${num(x.total_eventos)}</b><small>${Number(x.total_eventos) === 1 ? "evento" : "eventos"}</small></span>
  </a></li>`;
}

/** Barra fina permitidos/denegados con globo. */
function miniMedidor(x) {
  const total = Number(x.total_eventos ?? x.total ?? x.veces) || 0;
  const p = Number(x.permitidos) || 0;
  const d = Number(x.denegados) || 0;
  const o = Math.max(total - p - d, 0);
  if (!total) return "";
  return `<span class="mini-medidor" data-globo="${esc(`<strong>${eventos(total)}</strong><span class="globo-dato__fila"><i class="muestra muestra--permitido"></i><span>Permitidos</span><b>${num(p)}</b></span><span class="globo-dato__fila"><i class="muestra muestra--denegado"></i><span>Denegados</span><b>${num(d)}</b></span>${o ? `<span class="globo-dato__fila"><i class="muestra muestra--otro"></i><span>Otros</span><b>${num(o)}</b></span>` : ""}`)}">
    ${p ? `<i class="medidor__parte--permitido" style="flex-grow:${p}"></i>` : ""}${d ? `<i class="medidor__parte--denegado" style="flex-grow:${d}"></i>` : ""}${o ? `<i class="medidor__parte--otro" style="flex-grow:${o}"></i>` : ""}
  </span>`;
}

/* =====================================================================
   Importar logs de Sophos
   ===================================================================== */
export async function vistaImportarSophos(cont, _params, ctx) {
  ctx.migas([{ texto: "Importar logs de Sophos" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Importar logs de Sophos Firewall</h1>
        <p>Suelte uno o varios archivos. Cada uno queda como una importación con su propio tablero; después se pueden explorar juntos o comparar.</p>
      </div>
      <div class="encabezado__acciones"><a class="btn btn--secundario" href="#/logs/importaciones">${icono("capas")}Importaciones</a></div>
    </div>
    <div class="importar">
      <section class="panel soltar" data-zona>
        <input type="file" id="archivos-log" multiple accept=".txt,.log,.csv,.text,text/plain" class="visualmente-oculto">
        <label for="archivos-log" class="soltar__zona">
          <span class="soltar__icono">${icono("subir")}</span>
          <strong>Arrastre aquí los archivos de Sophos</strong>
          <span>o haga clic para elegirlos · .txt o .log · hasta ${MAX_MB} MB cada uno</span>
        </label>
        <ul class="soltar__archivos" data-lista hidden></ul>
        <div class="soltar__pie">
          <div class="campo">
            <label for="desc-log">Descripción <span class="etiqueta-nota">(opcional, para todos los archivos)</span></label>
            <input id="desc-log" maxlength="255" placeholder="Ej.: Revisión del acceso a www.grecia.go.cr">
          </div>
          <button type="button" class="btn btn--primario" data-importar disabled>${icono("subir")}Importar</button>
        </div>
      </section>
      <aside class="panel ayuda-importar">
        <div class="panel__cabeza"><h2>Qué archivos sirven</h2></div>
        <div class="panel__cuerpo">
          <ol class="pasos-ayuda">
            <li><strong>En Sophos</strong>, abra <em>Log viewer</em>, filtre lo que necesita y copie o descargue los registros como texto.</li>
            <li><strong>Formato del visor:</strong> el tipo (<em>Firewall</em>, <em>Web filter</em>…), la fecha y los campos <code>clave="valor"</code>.
              No importa si hay espacios, tabulaciones o líneas de más, ni si un valor quedó partido en dos líneas.</li>
            <li><strong>Formato syslog:</strong> un evento por línea con <code>date=</code> y <code>time=</code> también sirve.</li>
            <li><strong>Repetidos:</strong> un evento idéntico dentro del mismo archivo se guarda una sola vez. Si importa el mismo archivo otra vez,
              queda como otra importación y la comparación lo marca como idéntico.</li>
          </ol>
          <p class="ayuda-importar__nota">${icono("enlace", "ic--sm")}<span>Cada campo de Sophos se asigna solo a un campo común
            (<code>src_ip</code> → IP de origen, <code>fw_rule_id</code> → N.º de regla…). Los nombres se pueden ajustar en
            <a href="#/logs/campos">Campos y alias</a>.</span></p>
        </div>
      </aside>
    </div>
    <div data-resultados></div>`;

  const zona = cont.querySelector("[data-zona]");
  const entrada = cont.querySelector("#archivos-log");
  const lista = cont.querySelector("[data-lista]");
  const boton = cont.querySelector("[data-importar]");
  const resultados = cont.querySelector("[data-resultados]");
  let archivos = [];
  let trabajando = false;

  const extOk = (n) => /\.(txt|log|csv|text)$/i.test(n) || !/\.[^./\\]+$/.test(n);
  const pintar = () => {
    lista.hidden = !archivos.length;
    lista.innerHTML = archivos.map((a, i) => `
      <li class="archivo-log archivo-log--${a.estado}">
        <span class="archivo-log__icono">${icono(a.estado === "listo" ? "check" : a.estado === "error" ? "alerta" : "documento")}</span>
        <span class="archivo-log__texto">
          <strong>${esc(a.file.name)}</strong>
          <small>${esc(bytes(a.file.size))} · ${esc(textoEstado(a))}</small>
          ${a.estado === "subiendo" || a.estado === "procesando" ? `<span class="progreso__barra${a.estado === "procesando" ? " progreso__barra--indefinida" : ""}"><span style="width:${Math.round((a.progreso || 0) * 100)}%"></span></span>` : ""}
        </span>
        ${a.estado === "listo" ? `<a class="btn btn--secundario btn--sm" href="#/logs/importaciones/${a.resultado.id_importacion}">${icono("grafico")}Ver tablero</a>`
          : !trabajando && a.estado !== "procesando" ? `<button type="button" class="btn-icono" data-quitar="${i}" aria-label="Quitar ${esc(a.file.name)}">${icono("cerrar")}</button>` : ""}
      </li>`).join("");
    boton.disabled = trabajando || !archivos.some((a) => a.estado === "pendiente");
  };
  const textoEstado = (a) => ({
    pendiente: "Listo para importar",
    subiendo: `Subiendo ${Math.round((a.progreso || 0) * 100)} %`,
    procesando: "Leyendo y guardando los eventos…",
    listo: `${eventos(a.resultado?.total_eventos)} guardados${a.resultado?.repetidos ? ` · ${num(a.resultado.repetidos)} repetidos` : ""}${a.resultado?.avisos ? ` · ${num(a.resultado.avisos)} avisos` : ""}`,
    error: a.error || "No se pudo importar",
  }[a.estado]);

  const agregar = (lista2) => {
    for (const f of lista2) {
      if (archivos.some((a) => a.file.name === f.name && a.file.size === f.size && a.estado !== "error")) continue;
      const a = { file: f, estado: "pendiente" };
      if (!extOk(f.name)) { a.estado = "error"; a.error = "Use el archivo de texto que exporta Sophos (.txt o .log)."; }
      else if (f.size > MAX_MB * 1024 * 1024) { a.estado = "error"; a.error = `Pesa más de ${MAX_MB} MB. Divídalo en partes.`; }
      else if (!f.size) { a.estado = "error"; a.error = "El archivo está vacío."; }
      archivos.push(a);
    }
    pintar();
  };

  entrada.addEventListener("change", () => { agregar([...entrada.files]); entrada.value = ""; });
  ["dragenter", "dragover"].forEach((t) => zona.addEventListener(t, (ev) => { ev.preventDefault(); zona.classList.add("soltar--encima"); }));
  ["dragleave", "drop"].forEach((t) => zona.addEventListener(t, (ev) => { ev.preventDefault(); if (t === "drop" || !zona.contains(ev.relatedTarget)) zona.classList.remove("soltar--encima"); }));
  zona.addEventListener("drop", (ev) => { if (!trabajando) agregar([...ev.dataTransfer.files]); });
  lista.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-quitar]");
    if (b) { archivos.splice(Number(b.dataset.quitar), 1); pintar(); }
  });

  boton.addEventListener("click", async () => {
    trabajando = true;
    resultados.innerHTML = "";
    const descripcion = cont.querySelector("#desc-log").value.trim();
    for (const a of archivos.filter((x) => x.estado === "pendiente")) {
      a.estado = "subiendo";
      a.progreso = 0;
      pintar();
      const datos = new FormData();
      datos.append("archivo", a.file);
      if (descripcion) datos.append("descripcion", descripcion);
      try {
        a.resultado = await apiSubir("logs/importaciones/sophos/", datos, {
          alProgreso: (p) => {
            a.progreso = p;
            if (p >= 1) a.estado = "procesando";
            if (ctx.vigente()) pintar();
          },
        });
        a.estado = "listo";
        recienImportadas.set(a.resultado.id_importacion, a.resultado);
      } catch (e) {
        a.estado = "error";
        a.error = e.message;
        const avisos = e.cuerpo?.avisos;
        if (Array.isArray(avisos) && avisos.length) a.error += ` (${avisos[0]})`;
      }
      if (!ctx.vigente()) return;
      pintar();
    }
    trabajando = false;
    pintar();
    const listas = archivos.filter((a) => a.estado === "listo");
    const errores = archivos.filter((a) => a.estado === "error");
    if (listas.length === 1 && !errores.length) {
      toast(`Se importaron ${eventos(listas[0].resultado.total_eventos)}.`);
      location.hash = `#/logs/importaciones/${listas[0].resultado.id_importacion}`;
      return;
    }
    if (listas.length) {
      const ids = listas.map((a) => a.resultado.id_importacion);
      const total = listas.reduce((s, a) => s + (Number(a.resultado.total_eventos) || 0), 0);
      resultados.innerHTML = `
        <section class="panel resultado-importacion">
          <div class="panel__cuerpo">
            <div class="resultado-importacion__texto">${icono("check")}<div><strong>Se importaron ${listas.length} archivos con ${eventos(total)}.</strong>
              <p>${errores.length ? `${errores.length} no se pudieron importar (vea el motivo en la lista). ` : ""}Véalos juntos o compárelos.</p></div></div>
            <div class="encabezado__acciones">
              <a class="btn btn--primario" href="${rutaLogs("tablero", { importaciones: ids })}">${icono("grafico")}Tablero de todos</a>
              <a class="btn btn--secundario" href="${rutaLogs("eventos", { importaciones: ids })}">${icono("filtro")}Explorar eventos</a>
              ${ids.length >= 2 && ids.length <= 4 ? `<a class="btn btn--secundario" href="${rutaLogs("comparar", { importaciones: ids })}">${icono("comparar")}Comparar</a>` : ""}
            </div>
          </div>
        </section>`;
    }
  });
  pintar();
}

/* =====================================================================
   Lista de importaciones
   ===================================================================== */
export async function vistaImportaciones(cont, _params, ctx) {
  ctx.migas([{ texto: "Importaciones" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Importaciones</h1><p>Cada archivo de logs importado. Marque varias para explorarlas juntas o compararlas.</p></div>
      <div class="encabezado__acciones"><a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Importar logs de Sophos</a></div>
    </div>
    <section class="panel">
      <div class="barra-seleccion" data-barra-seleccion hidden>
        <span data-seleccion-texto></span>
        <a class="btn btn--secundario btn--sm" data-sel-ir="tablero">${icono("grafico")}Tablero</a>
        <a class="btn btn--secundario btn--sm" data-sel-ir="eventos">${icono("filtro")}Explorar</a>
        <a class="btn btn--secundario btn--sm" data-sel-ir="comparar">${icono("comparar")}Comparar</a>
        <a class="btn btn--secundario btn--sm" data-sel-ir="inventario">${icono("red")}Inventario</a>
      </div>
      <div data-tabla>${cargandoHTML()}</div>
    </section>`;

  let filas = [];
  const elegidas = new Set();
  const caja = cont.querySelector("[data-tabla]");
  const barra = cont.querySelector("[data-barra-seleccion]");

  const pintarSeleccion = () => {
    barra.hidden = !elegidas.size;
    barra.querySelector("[data-seleccion-texto]").textContent = `${elegidas.size} ${elegidas.size === 1 ? "importación elegida" : "importaciones elegidas"}`;
    const ids = [...elegidas];
    barra.querySelectorAll("[data-sel-ir]").forEach((a) => {
      const destino = a.dataset.selIr;
      const permitido = destino !== "comparar" || (ids.length >= 2 && ids.length <= 4);
      a.classList.toggle("deshabilitado", !permitido);
      a.setAttribute("aria-disabled", String(!permitido));
      a.title = permitido ? "" : "Elija de 2 a 4 importaciones para comparar";
      a.href = permitido ? rutaLogs(destino, { importaciones: ids }) : "javascript:void(0)";
    });
  };

  const cargar = async () => {
    filas = await api("logs/importaciones/");
    if (!ctx.vigente()) return;
    for (const id of [...elegidas]) if (!filas.some((f) => f.id_importacion === id)) elegidas.delete(id);
    pintarSeleccion();
    if (!filas.length) {
      caja.innerHTML = vacioHTML({
        icono: "logs", titulo: "Todavía no hay logs importados",
        boton: `<a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Importar logs de Sophos</a>`,
      });
      return;
    }
    caja.innerHTML = `<div class="tabla-envoltura"><table class="tabla">
      <thead><tr><th class="col-check"><span class="visualmente-oculto">Elegir</span></th><th>Archivo</th><th class="col-numero">Eventos</th>
        <th>Permitidos / denegados</th><th class="col-opcional">Período de los eventos</th><th class="col-opcional">Importado</th><th class="col-acciones"><span class="visualmente-oculto">Acciones</span></th></tr></thead>
      <tbody>${filas.map((x) => `
        <tr data-id="${x.id_importacion}">
          <td class="col-check"><input type="checkbox" data-elegir="${x.id_importacion}"${elegidas.has(x.id_importacion) ? " checked" : ""} aria-label="Elegir ${esc(x.nombre_archivo)}"></td>
          <td><a href="#/logs/importaciones/${x.id_importacion}"><strong>${esc(x.nombre_archivo)}</strong></a>
            <span class="secundario">N.º ${x.id_importacion} · ${esc(FUENTES[x.fuente] || x.fuente)}${x.descripcion ? ` · ${esc(x.descripcion)}` : ""}</span></td>
          <td class="col-numero"><strong>${num(x.total_eventos)}</strong>${x.repetidos ? `<span class="secundario">${num(x.repetidos)} repetidos</span>` : ""}</td>
          <td class="col-medidor">${miniMedidor(x)}<span class="secundario">${num(x.permitidos)} · ${num(x.denegados)}</span></td>
          <td class="col-opcional">${esc(rangoFechas(x.fecha_desde, x.fecha_hasta))}</td>
          <td class="col-opcional"><span>${esc(fecha(x.creado_en))}</span><span class="secundario">${esc(x.importado_por || "")}</span></td>
          <td class="col-acciones"><span class="acciones-fila">
            <a class="btn-icono" href="${rutaLogs("eventos", { importaciones: [x.id_importacion] })}" title="Explorar eventos" aria-label="Explorar eventos de ${esc(x.nombre_archivo)}">${icono("filtro")}</a>
            <button type="button" class="btn-icono" data-accion="editar" title="Editar descripción" aria-label="Editar descripción">${icono("editar")}</button>
            <button type="button" class="btn-icono btn-icono--peligro" data-accion="borrar" title="Eliminar" aria-label="Eliminar ${esc(x.nombre_archivo)}">${icono("borrar")}</button>
          </span></td>
        </tr>`).join("")}</tbody></table></div>`;
    activarGlobos(caja);
  };

  caja.addEventListener("change", (ev) => {
    const c = ev.target.closest("[data-elegir]");
    if (!c) return;
    const id = Number(c.dataset.elegir);
    if (c.checked) elegidas.add(id); else elegidas.delete(id);
    pintarSeleccion();
  });
  caja.addEventListener("click", async (ev) => {
    const b = ev.target.closest("[data-accion]");
    if (!b) return;
    const fila = filas.find((f) => f.id_importacion === Number(b.closest("tr").dataset.id));
    if (b.dataset.accion === "editar" && await editarDescripcion(fila)) await cargar();
    if (b.dataset.accion === "borrar" && await eliminarImportacion(fila)) await cargar();
  });
  barra.addEventListener("click", (ev) => {
    const a = ev.target.closest("[data-sel-ir]");
    if (a?.getAttribute("aria-disabled") === "true") { ev.preventDefault(); toast("Elija de 2 a 4 importaciones para comparar.", "error"); }
  });
  await cargar();
}

async function editarDescripcion(imp) {
  const r = await abrirFormulario({
    titulo: "Descripción de la importación",
    descripcion: imp.nombre_archivo,
    campos: [{ nombre: "descripcion", etiqueta: "Descripción", max: 255, mayus: false, placeholder: "Para qué se importó este log" }],
    valores: imp,
    textoGuardar: "Guardar",
    alGuardar: (datos) => api(`logs/importaciones/${imp.id_importacion}/`, { metodo: "PUT", datos }),
  });
  if (r) toast("Se guardó la descripción.");
  return !!r;
}

function eliminarImportacion(imp) {
  return confirmar({
    titulo: "Eliminar la importación",
    mensaje: `Se eliminarán «${imp.nombre_archivo}» y ${Number(imp.total_eventos) === 1 ? "su evento" : `sus ${num(imp.total_eventos)} eventos`}. El archivo original no se toca; se puede volver a importar.`,
    textoBoton: "Eliminar",
    accion: async () => {
      await api(`logs/importaciones/${imp.id_importacion}/`, { metodo: "DELETE" });
      toast("Se eliminó la importación.");
    },
  });
}

/* =====================================================================
   Tablero: cifras, línea de tiempo, lo más frecuente, conexiones y
   cruce con el inventario. Lo usan la importación y el tablero general.
   ===================================================================== */
const TOPS = [
  ["ip_origen", "IP de origen"], ["ip_destino", "IP de destino"], ["dominio", "Dominios"],
  ["regla_nombre", "Reglas"], ["categoria", "Categorías web"], ["aplicacion", "Aplicaciones"],
  ["puerto_destino", "Puertos de destino"], ["pais_destino", "Países de destino"], ["usuario", "Usuarios"],
];

function tableroHTML(t, inv, cat) {
  const r = t.resumen;
  if (!Number(r.total)) {
    return `<section class="panel">${vacioHTML({ icono: "filtro", titulo: "No hay eventos con este filtro", texto: "Cambie el filtro o elija otras importaciones." })}</section>`;
  }
  const cifra = (valor, texto, extra = "", href = "") => {
    const cuerpo = `<b>${valor}</b><span>${esc(texto)}</span>${extra}`;
    return href ? `<a class="cifra" href="${href}">${cuerpo}</a>` : `<div class="cifra">${cuerpo}</div>`;
  };
  const tops = TOPS.filter(([c]) => t.tops[c]?.length);
  return `
    <div class="cifras">
      <div class="cifra cifra--principal"><span>Eventos</span><b>${num(r.total)}</b><small>${esc(rangoFechas(r.desde, r.hasta))}</small></div>
      <div class="cifra cifra--medidor"><span>Permitidos y denegados</span>${medidorAcciones(r)}</div>
    </div>
    <div class="cifras cifras--chicas">
      ${cifra(num(r.ips_origen), "IP de origen distintas")}
      ${cifra(num(r.ips_destino), "IP de destino distintas")}
      ${cifra(num(r.dominios), "Dominios")}
      ${cifra(num(r.conexiones), "Conexiones")}
      ${cifra(num(r.usuarios), "Usuarios")}
      ${cifra(esc(bytes(r.bytes_enviados)), "Enviados", `<small>${esc(bytes(r.bytes_recibidos))} recibidos</small>`)}
    </div>

    <section class="panel panel--grafico">
      <div class="panel__cabeza"><div><h2>Eventos en el tiempo</h2><p>Haga clic en una columna para ver esos eventos.</p></div>${leyendaAccionesHTML()}</div>
      <div class="panel__cuerpo"><div class="grafico" data-tiempo></div>
        <details class="como-tabla"><summary>Ver como tabla</summary>${tablaTiempoHTML(t.linea_tiempo)}</details></div>
    </section>

    <div class="rejilla-tablero">
      <section class="panel panel--top">
        <div class="panel__cabeza"><h2>Tipos de log</h2></div>
        <div class="panel__cuerpo">${listaTopHTML("tipo", t.tipos, cat, { limite: 12 })}</div>
      </section>
      ${tops.map(([c, titulo]) => `
        <section class="panel panel--top">
          <div class="panel__cabeza"><h2><i class="punto-grupo punto-grupo--${claseGrupo(cat.porCampo[c]?.grupo)}"></i>${esc(titulo)}</h2></div>
          <div class="panel__cuerpo">${listaTopHTML(c, t.tops[c], cat)}</div>
        </section>`).join("")}
    </div>

    ${conexionesHTML(t.correlacionados)}
    ${inv ? inventarioResumenHTML(inv) : ""}`;
}

function conexionesHTML(lista) {
  if (!lista?.length) return "";
  return `
    <section class="panel">
      <div class="panel__cabeza"><div><h2>Conexiones con varios eventos</h2>
        <p>La misma conexión (<code>con_id</code>) pasó por varios controles: firewall, filtro web, SSL… Haga clic para ver el recorrido.</p></div></div>
      <ul class="conexiones">${lista.map((c) => `
        <li><button type="button" class="conexion conexion--${String(c.acciones || "").includes("DENEGADO") ? "denegado" : "permitido"}" data-conexion="${esc(c.id_conexion)}">
          <span class="conexion__ruta dato-mono">${esc(c.ip_origen || "—")} ${icono("derecha", "ic--sm")} ${esc(c.ip_destino || "—")}${c.puerto_destino ? `<span class="flujo__puerto">:${esc(c.puerto_destino)}</span>` : ""}</span>
          <span class="conexion__sitio">${esc(c.dominio || c.regla_nombre || "")}</span>
          <span class="conexion__pasos">${String(c.tipos || "").split("|").filter(Boolean).map((t) => `<span class="paso-tipo">${esc(t)}</span>`).join(icono("derecha", "ic--sm"))}</span>
          <span class="conexion__meta">${String(c.acciones || "").split("|").map((a) => pastillaAccion(a)).join("")}
            <small>${eventos(c.eventos)}${Number(c.importaciones_distintas) > 1 ? ` · en ${c.importaciones_distintas} importaciones` : ""} · ${esc(horaLog(c.desde))}</small></span>
        </button></li>`).join("")}</ul>
    </section>`;
}

function inventarioResumenHTML(inv) {
  const t = inv.totales;
  return `
    <section class="panel">
      <div class="panel__cabeza"><div><h2>Cruce con el inventario</h2><p>Las IP y MAC del log comparadas con los dispositivos registrados, y los usuarios con el personal.</p></div>
        <a class="btn btn--fantasma btn--sm" data-ir-inventario href="#/logs/inventario">Ver el cruce completo</a></div>
      <div class="panel__cuerpo">
        <div class="cruce">
          <div class="cruce__dato cruce__dato--ok"><b>${num(inv.equipos.length)}</b><span>equipos del inventario aparecen</span></div>
          <div class="cruce__dato${t.internas_desconocidas ? " cruce__dato--aviso" : ""}"><b>${num(t.internas_desconocidas)}</b><span>IP internas que no están en el inventario</span></div>
          <div class="cruce__dato"><b>${num(t.externas)}</b><span>IP externas</span></div>
          <div class="cruce__dato"><b>${num(t.macs_inventariadas)} <small>de ${num(t.macs)}</small></b><span>MAC conocidas</span></div>
          <div class="cruce__dato"><b>${num(t.usuarios_conocidos)} <small>de ${num(t.usuarios)}</small></b><span>usuarios son personal registrado</span></div>
        </div>
        ${inv.equipos.length ? `<ul class="equipos-vistos">${inv.equipos.slice(0, 6).map((e) => `
          <li><a href="#/red/dispositivos/${e.id_disp}" class="insignia-inventario">${icono("red", "ic--sm")}<span>${esc(e.equipo)}</span></a>
            <span class="dato-mono">${esc([...(e.ips || []), ...(e.macs || []).map(macGuiones)].join(" · "))}</span>
            <small>${eventos(e.veces)}</small></li>`).join("")}</ul>` : ""}
      </div>
    </section>`;
}

/** Enlaza los clics del tablero: tops, línea de tiempo y conexiones. */
function enlazarTablero(caja, t, base) {
  activarGlobos(caja);
  const ir = (cond) => { location.hash = rutaLogs("eventos", { q: agregarCondicion(base.q, cond), importaciones: base.importaciones }); };
  const tiempo = caja.querySelector("[data-tiempo]");
  if (tiempo) {
    lineaTiempo(tiempo, t.linea_tiempo, (desde, hasta) =>
      ir(`fecha >= "${fechaFiltro(desde)}" and fecha < "${fechaFiltro(hasta)}"`));
  }
  caja.addEventListener("click", (ev) => {
    const top = ev.target.closest("[data-top-campo]");
    if (top) { ir(condicion(top.dataset.topCampo, top.dataset.topValor)); return; }
    const con = ev.target.closest("[data-conexion]");
    if (con) { ir(condicion("id_conexion", con.dataset.conexion)); return; }
    const inv = ev.target.closest("[data-ir-inventario]");
    if (inv) { ev.preventDefault(); location.hash = rutaLogs("inventario", base); }
  });
}

/* =====================================================================
   Tablero de una importación (pantalla que se abre al importar)
   ===================================================================== */
export async function vistaImportacion(cont, [id], ctx) {
  id = Number(id);
  ctx.migas([{ texto: "Importaciones", href: "#/logs/importaciones" }, { texto: `N.º ${id}` }]);
  cont.innerHTML = cargandoHTML("Preparando el tablero…");
  const base = { q: "", importaciones: [id] };
  const [imp, cat] = await Promise.all([api(`logs/importaciones/${id}/`), catalogoCampos()]);
  const [t, inv] = await Promise.all([
    api("logs/eventos/tablero/", { query: { importaciones: id } }),
    api("logs/inventario/", { query: { importaciones: id } }).catch(() => null),
  ]);
  if (!ctx.vigente()) return;
  ctx.migas([{ texto: "Importaciones", href: "#/logs/importaciones" }, { texto: imp.nombre_archivo }]);

  const nueva = recienImportadas.get(id);
  recienImportadas.delete(id);
  const avisos = nueva?.avisos_detalle || [];
  cont.innerHTML = `
    <div class="encabezado encabezado--imp">
      <div class="encabezado-imp">
        <span class="insignia-log">${icono("logs")}</span>
        <div>
          <h1>${esc(imp.nombre_archivo)}</h1>
          <p>${imp.descripcion ? `${esc(imp.descripcion)} · ` : ""}${esc(FUENTES[imp.fuente] || imp.fuente)} · Importación N.º ${id} ·
            ${esc(fecha(imp.creado_en))}${imp.importado_por ? ` por ${esc(imp.importado_por)}` : ""}</p>
        </div>
      </div>
      <div class="encabezado__acciones">
        <a class="btn btn--primario" href="${rutaLogs("eventos", base)}">${icono("filtro")}Explorar eventos</a>
        <a class="btn btn--secundario" href="${rutaLogs("comparar", base)}">${icono("comparar")}Comparar</a>
        ${menuExportarHTML()}
        <button type="button" class="btn-icono" data-editar title="Editar descripción" aria-label="Editar descripción">${icono("editar")}</button>
        <button type="button" class="btn-icono btn-icono--peligro" data-eliminar title="Eliminar importación" aria-label="Eliminar importación">${icono("borrar")}</button>
      </div>
    </div>
    ${nueva ? `
      <div class="aviso aviso--exito">${icono("check")}<div><strong>Importación lista: ${eventos(nueva.total_eventos)} guardados.</strong>
        ${nueva.repetidos ? ` ${num(nueva.repetidos)} estaban repetidos dentro del archivo y se guardaron una sola vez.` : ""}
        ${avisos.length ? `<details class="avisos-imp"><summary>${num(nueva.avisos)} partes del archivo no se pudieron leer</summary><ul>${avisos.map((a) => `<li>${esc(a)}</li>`).join("")}</ul></details>` : ""}
      </div></div>` : imp.avisos ? `<div class="aviso aviso--ocre">${icono("alerta")}<span>Al importar, ${num(imp.avisos)} partes del archivo no se pudieron leer (no traían campos clave="valor").</span></div>` : ""}
    <div class="tablero" data-tablero>${tableroHTML(t, inv, cat)}</div>`;

  enlazarTablero(cont.querySelector("[data-tablero]"), t, base);
  enlazarExportar(cont, () => base);
  cont.querySelector("[data-editar]").addEventListener("click", async () => {
    if (await editarDescripcion(imp)) vistaImportacion(cont, [id], ctx);
  });
  cont.querySelector("[data-eliminar]").addEventListener("click", async () => {
    if (await eliminarImportacion(imp)) location.hash = "#/logs/importaciones";
  });
}

/* =====================================================================
   Tablero general (de cualquier filtro e importaciones)
   ===================================================================== */
export async function vistaTablero(cont, _params, ctx) {
  ctx.migas([{ texto: "Tablero" }]);
  const cat = await catalogoCampos();
  let base = { q: ctx.query.get("q") || "", importaciones: listaIds(ctx.query.get("importaciones")) };
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Tablero</h1><p>Los gráficos de todos los logs o solo de lo que deja pasar el filtro. Haga clic en cualquier barra para ver esos eventos.</p></div>
      <div class="encabezado__acciones">
        <a class="btn btn--secundario" data-ir-eventos href="${rutaLogs("eventos", base)}">${icono("filtro")}Explorar estos eventos</a>
        ${menuExportarHTML()}
      </div>
    </div>
    <section class="panel panel--filtro">${barraFiltroHTML({ q: base.q })}</section>
    <div class="tablero" data-tablero>${cargandoHTML()}</div>`;

  let consulta = 0;
  const cargar = async () => {
    const yo = ++consulta;
    cont.querySelector("[data-tablero]").innerHTML = cargandoHTML("Calculando…");
    try {
      const query = { q: base.q, importaciones: base.importaciones.join(",") };
      const [t, inv] = await Promise.all([api("logs/eventos/tablero/", { query }), api("logs/inventario/", { query }).catch(() => null)]);
      if (!ctx.vigente() || yo !== consulta) return;
      // Contenedor nuevo: así no se acumulan los eventos del tablero anterior
      const nueva = document.createElement("div");
      nueva.className = "tablero";
      nueva.dataset.tablero = "";
      cont.querySelector("[data-tablero]").replaceWith(nueva);
      nueva.innerHTML = tableroHTML(t, inv, cat);
      enlazarTablero(nueva, t, base);
    } catch (e) {
      if (yo !== consulta) return;
      if (!ctx.vigente()) return;
      cont.querySelector("[data-tablero]").innerHTML = errorHTML(e.message);
      if (e.cuerpo?.posicion !== undefined) barra.error(e);
    }
  };
  const barra = activarBarraFiltro(cont, {
    q: base.q, importaciones: base.importaciones, cat,
    alAplicar: (nuevo) => {
      base = nuevo;
      reemplazarRuta(rutaLogs("tablero", base));
      cont.querySelector("[data-ir-eventos]").href = rutaLogs("eventos", base);
      ctx.migas([{ texto: "Tablero" }]);
      cargar();
    },
  });
  enlazarExportar(cont, () => base);
  await cargar();
}

/* =====================================================================
   Exportar (menú)
   ===================================================================== */
function menuExportarHTML() {
  return `
    <details class="menu-exportar">
      <summary class="btn btn--secundario">${icono("descargar")}Exportar</summary>
      <div class="menu-exportar__lista" role="menu">
        <button type="button" role="menuitem" data-exportar="csv" data-campos="comunes"><strong>Excel (CSV) · campos comunes</strong>
          <small>Una columna por campo común, con el equipo y la persona del inventario</small></button>
        <button type="button" role="menuitem" data-exportar="csv" data-campos="todos"><strong>Excel (CSV) · con el log original</strong>
          <small>Además, todos los campos originales de Sophos</small></button>
        <button type="button" role="menuitem" data-exportar="json" data-campos="todos"><strong>JSON</strong>
          <small>Para otros programas: campos comunes y originales</small></button>
      </div>
    </details>`;
}

function enlazarExportar(cont, obtenerBase) {
  const menu = cont.querySelector(".menu-exportar");
  if (!menu) return;
  escucharDocumento("click", (ev) => { if (!menu.contains(ev.target)) menu.open = false; });
  menu.addEventListener("click", async (ev) => {
    const b = ev.target.closest("[data-exportar]");
    if (!b) return;
    menu.open = false;
    const base = obtenerBase();
    const formato = b.dataset.exportar;
    const resumen = menu.querySelector("summary");
    resumen.classList.add("cargando");
    try {
      await descargar("logs/eventos/exportar/", {
        q: base.q, importaciones: listaIds(base.importaciones).join(","), formato, campos: b.dataset.campos,
      }, `logs_${marcaArchivo()}.${formato}`);
      toast("Se descargó el archivo.");
    } catch (e) {
      toast(e.message, "error");
    } finally {
      resumen.classList.remove("cargando");
    }
  });
}

/* =====================================================================
   Explorador de eventos
   ===================================================================== */
const POR_PAGINA = 100;

export async function vistaEventos(cont, _params, ctx) {
  ctx.migas([{ texto: "Eventos" }]);
  const cat = await catalogoCampos();
  const estado = {
    q: ctx.query.get("q") || "",
    importaciones: listaIds(ctx.query.get("importaciones")),
    orden: ctx.query.get("orden") === "asc" ? "asc" : "desc",
    pagina: Math.max(0, (Number(ctx.query.get("pag")) || 1) - 1),
  };
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Eventos</h1><p>Filtre como en Wireshark; haga clic en un evento para ver todo su detalle, su conexión y el log original.</p></div>
      <div class="encabezado__acciones">
        <a class="btn btn--secundario" data-ir-tablero href="${rutaLogs("tablero", estado)}">${icono("grafico")}Ver en gráficos</a>
        ${menuExportarHTML()}
      </div>
    </div>
    <section class="panel panel--filtro">${barraFiltroHTML({ q: estado.q })}</section>
    <section class="panel">
      <div class="resultados-cabeza">
        <span class="resultados-cabeza__total" data-total aria-live="polite"></span>
        <div class="segmentado" role="radiogroup" aria-label="Orden">
          <button type="button" role="radio" data-orden="desc" aria-checked="${estado.orden === "desc"}">Más recientes</button>
          <button type="button" role="radio" data-orden="asc" aria-checked="${estado.orden === "asc"}">Más antiguos</button>
        </div>
        <div class="paginador" data-paginador></div>
      </div>
      <div data-resultados>${cargandoHTML()}</div>
      <div class="panel__pie panel__pie--paginas" data-paginador-pie hidden></div>
    </section>`;

  const resultados = cont.querySelector("[data-resultados]");
  const total = cont.querySelector("[data-total]");
  let filas = [];
  let n = 0;
  let consulta = 0;

  const actualizarRuta = () => {
    reemplazarRuta(rutaLogs("eventos", {
      ...estado, orden: estado.orden === "asc" ? "asc" : "", pag: estado.pagina ? estado.pagina + 1 : "",
    }));
    cont.querySelector("[data-ir-tablero]").href = rutaLogs("tablero", estado);
  };

  const paginadorHTML = () => {
    const paginas = Math.max(1, Math.ceil(n / POR_PAGINA));
    return `
      <button type="button" class="btn btn--secundario btn--sm" data-pagina="${estado.pagina - 1}"${estado.pagina ? "" : " disabled"} aria-label="Página anterior">${icono("atras")}</button>
      <span>Página ${num(estado.pagina + 1)} de ${num(paginas)}</span>
      <button type="button" class="btn btn--secundario btn--sm" data-pagina="${estado.pagina + 1}"${estado.pagina + 1 < paginas ? "" : " disabled"} aria-label="Página siguiente">${icono("derecha")}</button>`;
  };

  const cargar = async () => {
    const yo = ++consulta;
    resultados.classList.add("cargando-suave");
    try {
      const r = await api("logs/eventos/", {
        query: {
          q: estado.q, importaciones: estado.importaciones.join(","), orden: estado.orden,
          limite: POR_PAGINA, desplazamiento: estado.pagina * POR_PAGINA,
        },
      });
      if (!ctx.vigente() || yo !== consulta) return;
      filas = r.resultados;
      n = r.total;
      if (estado.pagina && !filas.length && n) { estado.pagina = Math.floor((n - 1) / POR_PAGINA); actualizarRuta(); cargar(); return; }
      const desde = n ? estado.pagina * POR_PAGINA + 1 : 0;
      total.innerHTML = n ? `<b>${num(n)}</b> ${n === 1 ? "evento" : "eventos"}${n > POR_PAGINA ? ` · ${num(desde)} a ${num(desde + filas.length - 1)}` : ""}` : "Ningún evento";
      cont.querySelector("[data-paginador]").innerHTML = n > POR_PAGINA ? paginadorHTML() : "";
      const pie = cont.querySelector("[data-paginador-pie]");
      pie.hidden = n <= POR_PAGINA;
      pie.innerHTML = n > POR_PAGINA ? paginadorHTML() : "";
      resultados.innerHTML = filas.length ? tablaEventosHTML(filas, cat) : vacioHTML({
        icono: "filtro", titulo: estado.q || estado.importaciones.length ? "Ningún evento cumple el filtro" : "Todavía no hay eventos",
        texto: estado.q ? "Revise el filtro o quite alguna condición." : "",
        boton: estado.q || estado.importaciones.length ? "" : `<a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Importar logs de Sophos</a>`,
      });
    } catch (e) {
      if (!ctx.vigente() || yo !== consulta) return;
      total.textContent = "";
      resultados.innerHTML = errorHTML(e.message);
      if (e.cuerpo?.posicion !== undefined) barra.error(e);
    } finally {
      resultados.classList.remove("cargando-suave");
    }
  };

  const barra = activarBarraFiltro(cont, {
    q: estado.q, importaciones: estado.importaciones, cat,
    alAplicar: ({ q, importaciones }) => {
      estado.q = q;
      estado.importaciones = importaciones;
      estado.pagina = 0;
      actualizarRuta();
      cargar();
    },
  });
  enlazarExportar(cont, () => estado);

  const abrir = (id) => abrirEvento(id, {
    alFiltrar: (cond) => {
      barra.fijar(agregarCondicion(estado.q, cond));
      estado.q = barra.q();
      estado.pagina = 0;
      actualizarRuta();
      cargar();
    },
  });

  cont.addEventListener("click", (ev) => {
    const p = ev.target.closest("[data-pagina]");
    if (p && !p.disabled) {
      estado.pagina = Number(p.dataset.pagina);
      actualizarRuta();
      cargar();
      cont.querySelector(".resultados-cabeza").scrollIntoView({ block: "nearest" });
      return;
    }
    const o = ev.target.closest("[data-orden]");
    if (o) {
      estado.orden = o.dataset.orden;
      estado.pagina = 0;
      cont.querySelectorAll("[data-orden]").forEach((b) => b.setAttribute("aria-checked", String(b === o)));
      actualizarRuta();
      cargar();
      return;
    }
    const tr = ev.target.closest("tr[data-evento]");
    if (tr && !ev.target.closest("a")) abrir(Number(tr.dataset.evento));
  });
  resultados.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest("tr[data-evento]");
    if (tr && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); abrir(Number(tr.dataset.evento)); }
  });

  await cargar();
}

function ipPuerto(ip, puerto) {
  if (!ip) return `<span class="sin-dato">—</span>`;
  return `<span class="dato-mono ip-puerto">${esc(ip)}${puerto ? `<span class="flujo__puerto">:${esc(puerto)}</span>` : ""}</span>`;
}

function tablaEventosHTML(filas, cat) {
  return `<div class="tabla-envoltura"><table class="tabla tabla--eventos">
    <thead><tr><th>Hora</th><th>Acción</th><th>Tipo</th><th>Origen</th><th class="col-flecha"><span class="visualmente-oculto">hacia</span></th>
      <th>Destino</th><th>Sitio o aplicación</th></tr></thead>
    <tbody>${filas.map((e) => {
      const accion = String(e.accion || "otro").toLowerCase();
      const sitio = e.dominio || e.aplicacion || "";
      const detalle = e.url && e.url !== `https://${e.dominio}` && e.url !== `http://${e.dominio}` ? e.url : e.categoria || "";
      return `<tr class="fila-log fila-log--${accion}" data-evento="${e.id_evento}" tabindex="0" aria-label="${esc(`Evento ${e.id_evento}: ${e.tipo || ""} ${valorCorto("accion", e.accion, cat)}`)}">
        <td class="col-hora"><span class="dato-mono">${esc(horaLog(e.fecha))}</span><small>${esc(diaLog(e.fecha))}</small></td>
        <td>${pastillaAccion(e.accion)}</td>
        <td class="col-tipo"><strong>${esc(e.tipo || "—")}</strong>${e.subtipo || e.regla_nombre ? `<small title="${esc([e.subtipo, e.regla_nombre && `Regla ${e.regla_id ? `${e.regla_id} · ` : ""}${e.regla_nombre}`].filter(Boolean).join(" · "))}">${esc([e.subtipo, e.regla_nombre].filter(Boolean).join(" · "))}</small>` : ""}</td>
        <td class="col-ip">${ipPuerto(e.ip_origen, e.puerto_origen)}
          ${e.equipo_origen ? `<small class="en-inventario" title="Equipo del inventario">${icono("red", "ic--sm")}${esc(e.equipo_origen)}</small>`
            : e.usuario ? `<small>${icono("usuario", "ic--sm")}${esc(e.persona || e.usuario)}</small>` : e.mac_origen ? `<small class="dato-mono">${esc(macGuiones(e.mac_origen))}</small>` : ""}</td>
        <td class="col-flecha">${icono("derecha", "ic--sm")}</td>
        <td class="col-ip">${ipPuerto(e.ip_destino, e.puerto_destino)}
          ${e.equipo_destino ? `<small class="en-inventario" title="Equipo del inventario">${icono("red", "ic--sm")}${esc(e.equipo_destino)}</small>` : e.pais_destino ? `<small>${esc(e.pais_destino)}</small>` : ""}</td>
        <td class="col-sitio">${sitio ? `<strong>${esc(sitio)}</strong>` : `<span class="sin-dato">—</span>`}${detalle ? `<small title="${esc(detalle)}">${esc(detalle)}</small>` : ""}</td>
      </tr>`;
    }).join("")}</tbody></table></div>`;
}

/* =====================================================================
   Comparar logs (2 a 4 conjuntos)
   ===================================================================== */
const LETRAS = ["A", "B", "C", "D"];

export async function vistaComparar(cont, _params, ctx) {
  ctx.migas([{ texto: "Comparar logs" }]);
  const [cat, imps] = await Promise.all([catalogoCampos(), api("logs/importaciones/")]);
  if (!ctx.vigente()) return;
  const deRuta = listaIds(ctx.query.get("importaciones"));
  let conjuntos = deRuta.length >= 2
    ? deRuta.slice(0, 4).map((id) => ({ nombre: imps.find((x) => x.id_importacion === id)?.nombre_archivo || `Importación ${id}`, importaciones: [id], filtro: "" }))
    : deRuta.length === 1
      ? [{ nombre: imps.find((x) => x.id_importacion === deRuta[0])?.nombre_archivo || "", importaciones: deRuta, filtro: "" }, { nombre: "", importaciones: [], filtro: "" }]
      : [{ nombre: "", importaciones: [], filtro: "" }, { nombre: "", importaciones: [], filtro: "" }];

  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Comparar logs</h1>
        <p>Arme de 2 a 4 conjuntos (una o varias importaciones, con o sin filtro) y vea qué IP, dominios, reglas o usuarios tienen en común y cuáles aparecen solo en uno.</p></div>
    </div>
    ${imps.length ? "" : `<div class="aviso aviso--ocre">${icono("alerta")}<span>Primero importe al menos un archivo de logs.</span></div>`}
    <form class="panel comparar-form" novalidate>
      <div class="conjuntos" data-conjuntos></div>
      <div class="panel__pie">
        <button type="button" class="btn btn--fantasma" data-agregar>${icono("mas")}Agregar conjunto</button>
        <span class="progreso-texto" data-error-comparar></span>
        <button type="submit" class="btn btn--primario">${icono("comparar")}Comparar</button>
      </div>
    </form>
    <div data-resultado-comparar></div>`;

  const form = cont.querySelector(".comparar-form");
  const caja = cont.querySelector("[data-conjuntos]");
  const leer = () => {
    caja.querySelectorAll("[data-conjunto]").forEach((el, i) => {
      conjuntos[i].nombre = el.querySelector("[name=nombre]").value.trim();
      conjuntos[i].filtro = el.querySelector("[name=filtro]").value.trim();
      conjuntos[i].importaciones = [...el.querySelectorAll("[data-imp]:checked")].map((c) => Number(c.value));
    });
  };
  const pintar = () => {
    caja.innerHTML = conjuntos.map((c, i) => `
      <fieldset class="conjunto conjunto--${i + 1}" data-conjunto="${i}">
        <legend><span class="letra-conjunto letra-conjunto--${i + 1}">${LETRAS[i]}</span>Conjunto ${LETRAS[i]}</legend>
        ${conjuntos.length > 2 ? `<button type="button" class="btn-icono conjunto__quitar" data-quitar="${i}" aria-label="Quitar el conjunto ${LETRAS[i]}">${icono("cerrar")}</button>` : ""}
        <div class="campo"><label for="cj-nombre-${i}">Nombre</label><input id="cj-nombre-${i}" name="nombre" maxlength="40" value="${esc(c.nombre)}" placeholder="${LETRAS[i]}"></div>
        <div class="campo"><span class="etiqueta-campo">Importaciones</span>
          <div class="conjunto__imps">${imps.length ? imps.map((x) => `
            <label class="conjunto__imp"><input type="checkbox" data-imp value="${x.id_importacion}"${c.importaciones.includes(x.id_importacion) ? " checked" : ""}>
              <span><strong>N.º ${x.id_importacion} · ${esc(x.nombre_archivo)}</strong><small>${eventos(x.total_eventos)} · ${esc(rangoFechas(x.fecha_desde, x.fecha_hasta))}</small></span></label>`).join("")
            : `<p class="top-vacio">No hay importaciones.</p>`}</div></div>
        <div class="campo"><label for="cj-filtro-${i}">Filtro <span class="etiqueta-nota">(opcional)</span></label>
          <input id="cj-filtro-${i}" name="filtro" class="dato-mono" spellcheck="false" autocomplete="off" value="${esc(c.filtro)}" placeholder="p. ej.: accion == denegado"></div>
      </fieldset>`).join("");
    cont.querySelector("[data-agregar]").hidden = conjuntos.length >= 4;
  };
  pintar();

  cont.querySelector("[data-agregar]").addEventListener("click", () => {
    leer();
    if (conjuntos.length < 4) conjuntos.push({ nombre: "", importaciones: [], filtro: "" });
    pintar();
  });
  caja.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-quitar]");
    if (!b) return;
    leer();
    conjuntos.splice(Number(b.dataset.quitar), 1);
    pintar();
  });

  const salida = cont.querySelector("[data-resultado-comparar]");
  const error = cont.querySelector("[data-error-comparar]");
  let bajar = true;
  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    leer();
    error.textContent = "";
    caja.querySelectorAll(".conjunto--error").forEach((el) => el.classList.remove("conjunto--error"));
    const boton = form.querySelector("[type=submit]");
    boton.classList.add("cargando");
    boton.disabled = true;
    salida.innerHTML = cargandoHTML("Comparando…");
    const envio = conjuntos.map((c, i) => ({ nombre: c.nombre || LETRAS[i], importaciones: c.importaciones, filtro: c.filtro }));
    try {
      const r = await api("logs/comparar/", { metodo: "POST", datos: { conjuntos: envio } });
      if (!ctx.vigente()) return;
      reemplazarRuta(rutaLogs("comparar", { importaciones: conjuntos.every((c) => c.importaciones.length === 1 && !c.filtro) ? conjuntos.map((c) => c.importaciones[0]) : [] }));
      pintarComparacion(salida, r, envio, cat);
      if (bajar) salida.scrollIntoView({ behavior: "smooth", block: "start" });
      bajar = true;
    } catch (e) {
      salida.innerHTML = "";
      error.innerHTML = `<span class="texto-error">${esc(e.message)}</span>`;
      const i = Number(e.cuerpo?.conjunto);
      if (Number.isInteger(i)) caja.querySelectorAll("[data-conjunto]")[i]?.classList.add("conjunto--error");
    } finally {
      boton.classList.remove("cargando");
      boton.disabled = false;
    }
  });

  if (deRuta.length >= 2) { bajar = false; form.requestSubmit(); }
}

const METRICAS = [
  ["total", "Eventos", num], ["permitidos", "Permitidos", num], ["denegados", "Denegados", num],
  ["ips_origen", "IP de origen distintas", num], ["ips_destino", "IP de destino distintas", num],
  ["dominios", "Dominios", num], ["conexiones", "Conexiones", num], ["usuarios", "Usuarios", num],
  ["bytes_enviados", "Datos enviados", bytes], ["bytes_recibidos", "Datos recibidos", bytes],
  ["desde", "Primer evento", fechaLog], ["hasta", "Último evento", fechaLog],
];

function pintarComparacion(salida, r, envio, cat) {
  const k = r.conjuntos.length;
  const nombres = r.conjuntos.map((c) => c.nombre);
  const letra = (i) => `<span class="letra-conjunto letra-conjunto--${i + 1}" title="${esc(nombres[i])}">${LETRAS[i]}</span>`;
  const campos = Object.keys(r.campos);
  let campoActual = campos.find((c) => r.campos[c].total) || campos[0];
  let vista = "todos";
  const todasImps = [...new Set(envio.flatMap((c) => c.importaciones))];

  salida.innerHTML = `
    <section class="panel comparacion">
      <div class="panel__cabeza"><div><h2>Resultado</h2><p>${k} conjuntos comparados.</p></div>
        <button type="button" class="btn btn--secundario btn--sm" data-exportar-comparacion>${icono("descargar")}Exportar comparación (CSV)</button></div>
      <div class="panel__cuerpo">
        <div class="conjuntos-resumen">${r.resumenes.map((s, i) => `
          <div class="conjunto-resumen conjunto-resumen--${i + 1}">
            ${letra(i)}<div><strong>${esc(nombres[i])}</strong><small>${eventos(s.total)} · ${esc(rangoFechas(s.desde, s.hasta))}</small>
            ${miniMedidor({ total: s.total, permitidos: s.permitidos, denegados: s.denegados })}</div>
          </div>`).join("")}</div>

        <div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--comparar">
          <thead><tr><th>Dato</th>${nombres.map((_, i) => `<th class="col-numero">${letra(i)}</th>`).join("")}</tr></thead>
          <tbody>${METRICAS.map(([clave, texto, f]) => `<tr><td>${esc(texto)}</td>${r.resumenes.map((s) =>
            `<td class="col-numero">${esc(f(s[clave]))}${clave === "denegados" && Number(s.total) ? ` <small>(${pct(Number(s.denegados), Number(s.total))})</small>` : ""}</td>`).join("")}</tr>`).join("")}</tbody>
        </table></div>

        <div class="identicos">
          <div class="identicos__dato"><b>${num(r.identicos)}</b><span>eventos idénticos están en todos los conjuntos</span></div>
          <p>${r.identicos ? "El mismo evento (mismo tipo, fecha y campos) aparece en cada conjunto: por ejemplo, el mismo archivo importado dos veces o dos exportaciones que se traslapan."
            : "Ningún evento está repetido en todos los conjuntos."}</p>
        </div>

        <h3 class="titulo-seccion">Valores por campo</h3>
        <div class="pestanas pestanas--campos" role="tablist">${campos.map((c) => `
          <button type="button" role="tab" data-campo-comp="${c}" aria-selected="${c === campoActual}">
            <i class="punto-grupo punto-grupo--${claseGrupo(cat.porCampo[c]?.grupo)}"></i>${esc(cat.etiqueta(c))}<span class="contador" title="En todos los conjuntos">${num(r.campos[c].en_todos)}</span></button>`).join("")}
        </div>
        <div data-campo-detalle></div>
      </div>
    </section>
    ${conexionesHTML(r.correlacionados)}`;

  const detalle = salida.querySelector("[data-campo-detalle]");
  const pintarCampo = () => {
    const d = r.campos[campoActual];
    const maximo = Math.max(1, ...d.valores.flatMap((v) => v.conteos));
    const filtrados = d.valores.filter((v) => vista === "todos" || (vista === "comunes" ? v.en_todos : v.en.length === 1 && v.en[0] === Number(vista)));
    const mono = esMono(campoActual, cat);
    detalle.innerHTML = `
      <div class="venn" role="group" aria-label="Filtrar valores">
        <button type="button" class="venn__parte${vista === "todos" ? " venn__parte--activa" : ""}" data-vista="todos"><b>${num(d.total)}</b><span>valores distintos</span></button>
        <button type="button" class="venn__parte venn__parte--comun${vista === "comunes" ? " venn__parte--activa" : ""}" data-vista="comunes"><b>${num(d.en_todos)}</b><span>en todos</span></button>
        ${d.solo.map((s, i) => `<button type="button" class="venn__parte${vista === String(i) ? " venn__parte--activa" : ""}" data-vista="${i}">${letra(i)}<b>${num(s)}</b><span>solo en ${esc(LETRAS[i])}</span></button>`).join("")}
      </div>
      ${filtrados.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--valores">
        <thead><tr><th>${esc(cat.etiqueta(campoActual))}</th>${nombres.map((_, i) => `<th>${letra(i)} <span class="visualmente-oculto">${esc(nombres[i])}</span></th>`).join("")}<th>Dónde aparece</th></tr></thead>
        <tbody>${filtrados.slice(0, 300).map((v) => `
          <tr class="clicable" data-valor-comp="${esc(v.valor ?? "")}" tabindex="0">
            <td class="${mono ? "dato-mono" : ""}">${esc(valorCorto(campoActual, v.valor, cat))}</td>
            ${v.conteos.map((n, i) => `<td class="celda-conteo">${n ? `<span class="barra-conteo barra-conteo--${i + 1}" style="width:${Math.max(n / maximo * 100, 3).toFixed(1)}%"></span>
              <span>${num(n)}${v.denegados[i] ? ` <small class="texto-denegado">${num(v.denegados[i])} den.</small>` : ""}</span>` : `<span class="sin-dato">—</span>`}</td>`).join("")}
            <td>${v.en_todos ? `<span class="pastilla pastilla--activo pastilla--sin-punto">En todos</span>` : v.en.map(letra).join("")}</td>
          </tr>`).join("")}</tbody></table></div>
        ${filtrados.length > 300 ? `<p class="nota-tabla">Se muestran 300 de ${num(filtrados.length)} valores. Exporte la comparación para verlos todos.</p>` : ""}`
        : `<p class="top-vacio">No hay valores en esta parte.</p>`}`;
  };
  pintarCampo();
  activarGlobos(salida);

  salida.addEventListener("click", (ev) => {
    const p = ev.target.closest("[data-campo-comp]");
    if (p) {
      campoActual = p.dataset.campoComp;
      vista = "todos";
      salida.querySelectorAll("[data-campo-comp]").forEach((b) => b.setAttribute("aria-selected", String(b === p)));
      pintarCampo();
      return;
    }
    const v = ev.target.closest("[data-vista]");
    if (v) { vista = v.dataset.vista; pintarCampo(); return; }
    const fila = ev.target.closest("[data-valor-comp]");
    if (fila) { location.hash = rutaLogs("eventos", { q: condicion(campoActual, fila.dataset.valorComp), importaciones: todasImps }); return; }
    const con = ev.target.closest("[data-conexion]");
    if (con) { location.hash = rutaLogs("eventos", { q: condicion("id_conexion", con.dataset.conexion), importaciones: todasImps }); return; }
    if (ev.target.closest("[data-exportar-comparacion]")) exportarComparacion(r, nombres, cat);
  });
  salida.addEventListener("keydown", (ev) => {
    const fila = ev.target.closest("[data-valor-comp]");
    if (fila && ev.key === "Enter") fila.click();
  });
}

function exportarComparacion(r, nombres, cat) {
  const celda = (v) => {
    const s = String(v ?? "");
    return /[";\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const lineas = [["Campo", "Valor", ...nombres.map((n, i) => `${LETRAS[i]} ${n}`), ...nombres.map((_, i) => `Denegados ${LETRAS[i]}`), "En todos", "Aparece en"].map(celda).join(";")];
  for (const [campo, d] of Object.entries(r.campos)) {
    for (const v of d.valores) {
      lineas.push([cat.etiqueta(campo), valorCorto(campo, v.valor, cat), ...v.conteos, ...v.denegados, v.en_todos ? "Sí" : "No",
        v.en.map((i) => LETRAS[i]).join(" ")].map(celda).join(";"));
    }
  }
  lineas.push("");
  lineas.push(["Resumen", "", ...nombres].map(celda).join(";"));
  for (const [clave, texto] of METRICAS) lineas.push([texto, "", ...r.resumenes.map((s) => s[clave] ?? "")].map(celda).join(";"));
  lineas.push(["Eventos idénticos en todos", "", r.identicos].map(celda).join(";"));
  descargarTexto(`﻿${lineas.join("\r\n")}\r\n`, `comparacion_logs_${marcaArchivo()}.csv`);
  toast("Se descargó la comparación.");
}

/* =====================================================================
   Cruce con el inventario y el personal
   ===================================================================== */
export async function vistaInventarioLogs(cont, _params, ctx) {
  ctx.migas([{ texto: "Cruce con el inventario" }]);
  const cat = await catalogoCampos();
  let base = { q: ctx.query.get("q") || "", importaciones: listaIds(ctx.query.get("importaciones")) };
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Cruce con el inventario</h1>
        <p>Qué equipos registrados aparecen en los logs (por IP o MAC), qué IP internas no están en el inventario y qué usuarios del log son personal del sistema.</p></div>
    </div>
    <section class="panel panel--filtro">${barraFiltroHTML({ q: base.q, atajos: false })}</section>
    <div data-cruce>${cargandoHTML()}</div>`;

  const caja = cont.querySelector("[data-cruce]");
  const verEventos = (cond) => rutaLogs("eventos", { q: agregarCondicion(base.q, cond), importaciones: base.importaciones });
  const condEquipo = (e) => {
    const partes = [...(e.ips || []).map((ip) => `ip == ${ip}`), ...(e.macs || []).map((m) => `mac == ${m}`)];
    return partes.length > 1 ? `(${partes.join(" or ")})` : partes[0] || "equipo";
  };
  const fechas = (x) => `<span>${esc(fechaLog(x.primera))}</span>${x.ultima && x.ultima !== x.primera ? `<span class="secundario">a ${esc(fechaLog(x.ultima))}</span>` : ""}`;

  const cargar = async () => {
    caja.innerHTML = cargandoHTML("Cruzando con el inventario…");
    try {
      const inv = await api("logs/inventario/", { query: { q: base.q, importaciones: base.importaciones.join(",") } });
      if (!ctx.vigente()) return;
      const t = inv.totales;
      caja.innerHTML = `
        <div class="cifras cifras--chicas cifras--cinco">
          <div class="cifra cifra--ok"><b>${num(inv.equipos.length)}</b><span>Equipos del inventario en los logs</span></div>
          <div class="cifra${t.internas_desconocidas ? " cifra--aviso" : ""}"><b>${num(t.internas_desconocidas)}</b><span>IP internas sin registrar</span></div>
          <div class="cifra"><b>${num(t.externas)}</b><span>IP externas</span></div>
          <div class="cifra"><b>${num(t.macs_inventariadas)}<small> de ${num(t.macs)}</small></b><span>MAC del inventario</span></div>
          <div class="cifra"><b>${num(t.usuarios_conocidos)}<small> de ${num(t.usuarios)}</small></b><span>Usuarios que son personal</span></div>
        </div>

        <section class="panel">
          <div class="panel__cabeza"><div><h2>${icono("red")} Equipos del inventario que aparecen</h2><p>Por cualquiera de sus IP o MAC registradas, también como IP traducida por NAT.</p></div></div>
          ${inv.equipos.length ? `<div class="tabla-envoltura"><table class="tabla">
            <thead><tr><th>Equipo</th><th>IP y MAC en el log</th><th class="col-numero">Eventos</th><th>Permitidos / denegados</th><th class="col-opcional">Visto</th><th class="col-acciones"></th></tr></thead>
            <tbody>${inv.equipos.map((e) => `<tr>
              <td><a href="#/red/dispositivos/${e.id_disp}"><strong>${esc(e.equipo)}</strong></a>${e.edificio ? `<span class="secundario">${esc(e.edificio)}</span>` : ""}</td>
              <td class="dato-mono col-mac">${[...(e.ips || []), ...(e.macs || []).map(macGuiones)].map(esc).join("<br>")}</td>
              <td class="col-numero"><strong>${num(e.veces)}</strong></td>
              <td class="col-medidor">${e.permitidos === null ? `<span class="sin-dato">solo por MAC</span>` : `${miniMedidor({ total: e.veces, permitidos: e.permitidos, denegados: e.denegados })}<span class="secundario">${num(e.permitidos)} · ${num(e.denegados)}</span>`}</td>
              <td class="col-opcional">${fechas(e)}</td>
              <td class="col-acciones"><a class="btn btn--secundario btn--sm" href="${verEventos(condEquipo(e))}">${icono("filtro")}Eventos</a></td>
            </tr>`).join("")}</tbody></table></div>`
            : vacioHTML({ icono: "red", titulo: "Ningún equipo del inventario aparece en estos logs", texto: "Revise que los dispositivos tengan sus IP y MAC registradas." })}
        </section>

        <section class="panel">
          <div class="panel__cabeza"><div><h2>${icono("alerta")} IP internas que no están en el inventario</h2>
            <p>Direcciones privadas (10.x, 172.16–31.x, 192.168.x) sin dispositivo registrado: equipos de usuarios o algo que falta registrar.</p></div>
            <a class="btn btn--fantasma btn--sm" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar dispositivo</a></div>
          ${tablaIps(inv.ips_internas_desconocidas, verEventos, fechas, "No hay IP internas sin registrar.")}
        </section>

        <div class="dos-columnas dos-columnas--iguales">
          <section class="panel">
            <div class="panel__cabeza"><div><h2>${icono("usuario")} Usuarios del log</h2><p>Comparados con el usuario de red del personal.</p></div></div>
            ${inv.usuarios.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
              <thead><tr><th>Usuario</th><th>Persona</th><th class="col-numero">Eventos</th><th class="col-numero">Denegados</th><th class="col-acciones"></th></tr></thead>
              <tbody>${inv.usuarios.map((u) => `<tr>
                <td class="dato-mono">${esc(u.usuario)}</td>
                <td>${u.id_persona ? `<a href="#/usuarios/${u.id_persona}">${esc(u.persona)}</a>` : `<span class="pastilla pastilla--inactivo">No registrado</span>`}</td>
                <td class="col-numero">${num(u.veces)}</td><td class="col-numero">${num(u.denegados)}</td>
                <td class="col-acciones"><a class="btn-icono" href="${verEventos(condicion("usuario", u.usuario))}" title="Ver eventos" aria-label="Ver eventos de ${esc(u.usuario)}">${icono("filtro")}</a></td>
              </tr>`).join("")}</tbody></table></div>`
              : `<div class="panel__cuerpo"><p class="top-vacio">Estos logs no traen usuarios (en Sophos, el campo <code>user</code> viene vacío si no hay autenticación).</p></div>`}
          </section>
          <section class="panel">
            <div class="panel__cabeza"><div><h2>${icono("red")} Direcciones MAC</h2><p>Las MAC que trae el log y si son de un equipo registrado.</p></div></div>
            ${inv.macs.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
              <thead><tr><th>MAC</th><th>Equipo</th><th class="col-numero">Eventos</th><th class="col-acciones"></th></tr></thead>
              <tbody>${inv.macs.map((m) => `<tr>
                <td class="dato-mono col-mac">${esc(macGuiones(m.mac))}${m.ips ? `<span class="secundario">${esc(String(m.ips).split(",").slice(0, 3).join(", "))}</span>` : ""}</td>
                <td>${m.id_disp ? `<a href="#/red/dispositivos/${m.id_disp}">${esc(m.equipo)}</a>` : `<span class="pastilla pastilla--inactivo">No registrada</span>`}</td>
                <td class="col-numero">${num(m.veces)}</td>
                <td class="col-acciones"><a class="btn-icono" href="${verEventos(condicion("mac", m.mac))}" title="Ver eventos" aria-label="Ver eventos de ${esc(macGuiones(m.mac))}">${icono("filtro")}</a></td>
              </tr>`).join("")}</tbody></table></div>`
              : `<div class="panel__cuerpo"><p class="top-vacio">Estos logs no traen direcciones MAC.</p></div>`}
          </section>
        </div>

        <section class="panel">
          <div class="panel__cabeza"><div><h2>${icono("web")} IP externas</h2><p>Las 200 con más eventos.</p></div></div>
          ${tablaIps(inv.ips_externas, verEventos, fechas, "No hay IP externas.")}
        </section>`;
      activarGlobos(caja);
    } catch (e) {
      if (!ctx.vigente()) return;
      caja.innerHTML = errorHTML(e.message);
      if (e.cuerpo?.posicion !== undefined) barra.error(e);
    }
  };
  const barra = activarBarraFiltro(cont, {
    q: base.q, importaciones: base.importaciones, cat,
    alAplicar: (nuevo) => { base = nuevo; reemplazarRuta(rutaLogs("inventario", base)); cargar(); },
  });
  await cargar();
}

function tablaIps(lista, verEventos, fechas, vacio) {
  if (!lista.length) return `<div class="panel__cuerpo"><p class="top-vacio">${esc(vacio)}</p></div>`;
  const conNat = lista.some((x) => Number(x.por_nat));
  return `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
    <thead><tr><th>IP</th><th class="col-numero">Eventos</th><th class="col-numero col-opcional">Como origen</th><th class="col-numero col-opcional">Como destino</th>
      ${conNat ? `<th class="col-numero col-opcional" title="Veces que aparece como IP traducida por NAT">Por NAT</th>` : ""}
      <th>Permitidos / denegados</th><th class="col-opcional">Visto</th><th class="col-acciones"></th></tr></thead>
    <tbody>${lista.map((x) => `<tr>
      <td class="dato-mono">${esc(x.ip)}</td><td class="col-numero"><strong>${num(x.veces)}</strong></td>
      <td class="col-numero col-opcional">${num(x.como_origen)}</td><td class="col-numero col-opcional">${num(x.como_destino)}</td>
      ${conNat ? `<td class="col-numero col-opcional">${num(x.por_nat)}</td>` : ""}
      <td class="col-medidor">${miniMedidor({ total: x.veces, permitidos: x.permitidos, denegados: x.denegados })}<span class="secundario">${num(x.permitidos)} · ${num(x.denegados)}</span></td>
      <td class="col-opcional">${fechas(x)}</td>
      <td class="col-acciones"><a class="btn-icono" href="${verEventos(`ip == ${x.ip}`)}" title="Ver eventos" aria-label="Ver eventos de ${esc(x.ip)}">${icono("filtro")}</a></td>
    </tr>`).join("")}</tbody></table></div>`;
}

/* =====================================================================
   Campos comunes y alias
   ===================================================================== */
export async function vistaCamposLogs(cont, _params, ctx) {
  ctx.migas([{ texto: "Campos y alias" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div><h1>Campos y alias</h1>
        <p>Cada programa llama distinto a lo mismo: Sophos dice <code>src_ip</code>, otro dirá <code>source</code>. Al importar, cada nombre se asigna
          solo a un campo común, así todos los logs se pueden filtrar y comparar entre sí.</p></div>
      <div class="encabezado__acciones"><button type="button" class="btn btn--primario" data-nuevo-alias>${icono("mas")}Agregar alias</button></div>
    </div>
    <div class="aviso aviso--info">${icono("enlace")}<span>Un alias nuevo o cambiado se usa en las próximas importaciones. Lo ya importado conserva cómo se leyó,
      pero todos sus campos originales siguen guardados y se pueden filtrar con <code>datos.nombre</code>.</span></div>
    <div data-campos>${cargandoHTML()}</div>`;

  const caja = cont.querySelector("[data-campos]");
  let cat;
  let alias = [];

  const cargar = async () => {
    olvidarCatalogo();
    [cat, alias] = await Promise.all([catalogoCampos(), api("logs/mapeo/")]);
    if (!ctx.vigente()) return;
    const porCampo = {};
    for (const a of alias) (porCampo[a.campo] ||= []).push(a);
    const grupos = {};
    for (const c of cat.campos) (grupos[c.grupo] ||= []).push(c);
    caja.innerHTML = Object.entries(grupos).map(([g, lista]) => `
      <section class="panel grupo-panel grupo-panel--${claseGrupo(g)}">
        <div class="panel__cabeza"><h2><i class="punto-grupo punto-grupo--${claseGrupo(g)}"></i>${esc(g)}</h2></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--campos">
          <thead><tr><th>Campo común</th><th class="col-opcional">Tipo</th><th>Nombres en los logs (prioridad)</th><th class="col-opcional">Filtro estilo Wireshark</th></tr></thead>
          <tbody>${lista.map((c) => `<tr>
            <td><strong>${esc(c.etiqueta)}</strong><span class="secundario dato-mono">${esc(c.campo)}</span></td>
            <td class="col-opcional">${esc(TIPOS[c.tipo] || c.tipo)}</td>
            <td><div class="alias-lista">${(porCampo[c.campo] || []).sort((a, b) => a.prioridad - b.prioridad).map((a) => `
              <span class="alias">
                <span class="dato-mono">${esc(a.campo_origen)}</span><small title="Prioridad: si el log trae varios, se usa el de número menor">${a.prioridad}</small>
                <button type="button" class="alias__boton" data-editar-alias="${esc(a.fuente)}|${esc(a.campo_origen)}" aria-label="Editar alias ${esc(a.campo_origen)}" title="Editar">${icono("editar", "ic--sm")}</button>
                <button type="button" class="alias__boton alias__boton--peligro" data-borrar-alias="${esc(a.fuente)}|${esc(a.campo_origen)}" aria-label="Quitar alias ${esc(a.campo_origen)}" title="Quitar">${icono("cerrar", "ic--sm")}</button>
              </span>`).join("") || `<span class="sin-dato">${["fecha", "tipo", "accion"].includes(c.campo) ? "Lo calcula el lector" : "Sin alias"}</span>`}</div></td>
            <td class="col-opcional dato-mono">${c.filtro.map(esc).join(", ") || `<span class="sin-dato">—</span>`}</td>
          </tr>`).join("")}</tbody>
        </table></div>
      </section>`).join("");
  };

  const camposEditables = () => cat.campos.filter((c) => !["fecha", "tipo", "accion"].includes(c.campo))
    .map((c) => ({ valor: c.campo, texto: `${c.etiqueta} (${c.grupo})` }));

  const editar = async (fila) => {
    const r = await abrirFormulario({
      titulo: fila ? `Alias ${fila.campo_origen}` : "Agregar alias",
      descripcion: fila ? "El nombre en el log no se cambia; si está mal, quite el alias y agréguelo de nuevo."
        : "Escriba el nombre del campo tal como viene en el log y el campo común donde se debe guardar.",
      campos: [
        ...(fila ? [] : [
          { nombre: "fuente", etiqueta: "Programa", tipo: "select", requerido: true, sinVacio: true, opciones: Object.entries(cat.fuentes).map(([v, t]) => ({ valor: v, texto: t })) },
          { nombre: "campo_origen", etiqueta: "Nombre en el log", requerido: true, max: 64, mayus: false, placeholder: "p. ej.: src_ip", ayuda: "Letras, números, punto, guion o guion bajo." },
        ]),
        { nombre: "campo", etiqueta: "Campo común", tipo: "select", requerido: true, opciones: camposEditables() },
        { nombre: "prioridad", etiqueta: "Prioridad", tipo: "number", entero: true, requerido: true, ayuda: "1 es la más alta. Si un evento trae dos nombres para el mismo campo, gana el de número menor." },
      ],
      valores: fila || { fuente: "SOPHOS", prioridad: 1 },
      textoGuardar: fila ? "Guardar" : "Agregar",
      alGuardar: (datos) => (fila
        ? api(`logs/mapeo/${encodeURIComponent(fila.fuente)}/${encodeURIComponent(fila.campo_origen)}/`, { metodo: "PUT", datos: { campo: datos.campo, prioridad: datos.prioridad } })
        : api("logs/mapeo/", { metodo: "POST", datos })),
    });
    if (r) { toast(fila ? "Se guardó el alias." : `Se agregó el alias «${r.campo_origen}».`); await cargar(); }
  };

  cont.querySelector("[data-nuevo-alias]").addEventListener("click", () => editar(null));
  caja.addEventListener("click", async (ev) => {
    const e = ev.target.closest("[data-editar-alias]");
    const b = ev.target.closest("[data-borrar-alias]");
    const clave = (e || b)?.dataset[e ? "editarAlias" : "borrarAlias"];
    if (!clave) return;
    const [fuente, origen] = clave.split("|");
    const fila = alias.find((a) => a.fuente === fuente && a.campo_origen === origen);
    if (!fila) return;
    if (e) { editar(fila); return; }
    const ok = await confirmar({
      titulo: "Quitar el alias",
      mensaje: `Desde la próxima importación, «${fila.campo_origen}» ya no se guardará en «${cat.etiqueta(fila.campo)}» (seguirá en los campos originales).`,
      textoBoton: "Quitar",
      accion: () => api(`logs/mapeo/${encodeURIComponent(fila.fuente)}/${encodeURIComponent(fila.campo_origen)}/`, { metodo: "DELETE" }),
    });
    if (ok) { toast("Se quitó el alias."); await cargar(); }
  });

  await cargar();
}

const TIPOS = { fecha: "Fecha y hora", texto: "Texto", ip: "Dirección IP", mac: "Dirección MAC", puerto: "Puerto", numero: "Número", accion: "Permitido / denegado" };
