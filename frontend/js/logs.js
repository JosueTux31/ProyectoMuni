// Módulo de análisis de logs (tipo SIEM). Pantallas:
//   #/logs                       inicio del módulo
//   #/logs/importar/sophos       importar archivos de Sophos Firewall
//   #/logs/importar/microclaudia importar el listado de equipos con el agente de Microclaudia
//   #/logs/importar/dhcp         importar las concesiones del servidor DHCP
//   #/logs/importaciones         archivos importados
//   #/logs/importaciones/<id>    tablero visual de una importación
//   #/logs/tablero?q=&importaciones=     tablero de cualquier filtro
//   #/logs/eventos?q=&importaciones=     explorador con filtro estilo Wireshark
//   #/logs/comparar?importaciones=1,2    comparación de 2 a 4 conjuntos
//   #/logs/inventario?q=&importaciones=  cruce con equipos y personas
//   #/logs/cobertura?agentes=    equipos registrados sin el agente de Microclaudia
//   #/logs/intrusos?dhcp=&agentes=  concesiones del DHCP comparadas por MAC con el inventario
//   #/logs/campos                campos comunes y alias de cada programa
import { api, apiSubir } from "./api.js";
import { abrirFormulario, cargandoHTML, confirmar, debounce, errorHTML, esc, fecha, icono, toast, vacioHTML } from "./ui.js";
import {
  abrirEvento, activarBarraFiltro, activarGlobos, agregarCondicion, barraFiltroHTML, bytes, catalogoCampos, celdaCsv, claseGrupo,
  compacto, condicion, descargar, escucharDocumento, eventos, descargarTexto, diaLog, esMono, fechaFiltro, fechaLog, globoHTML, horaLog, leyendaAccionesHTML,
  lineaTiempo, listaIds, listaTopHTML, macGuiones, marcaArchivo, medidorAcciones, num, olvidarCatalogo, pastillaAccion, pct,
  rangoFechas, reemplazarRuta, rutaLogs, tablaTiempoHTML, valorCorto,
} from "./logs_ui.js";

const FUENTES = { SOPHOS: "Sophos Firewall", MICROCLAUDIA: "Microclaudia", DHCP: "Servidor DHCP" };
// logs: eventos de tráfico; agentes: listado de equipos con un agente (cada
// fila es un equipo); dhcp: concesiones del DHCP (cada fila es una IP entregada)
const CLASES = { SOPHOS: "logs", MICROCLAUDIA: "agentes", DHCP: "dhcp" };
const claseFuente = (fuente) => CLASES[fuente] || "logs";
const esListado = (fuente) => claseFuente(fuente) !== "logs";
const esDhcp = (fuente) => claseFuente(fuente) === "dhcp";
const UNIDADES = { logs: ["evento", "eventos"], agentes: ["equipo", "equipos"], dhcp: ["concesión", "concesiones"] };
const unidad = (fuente, n) => UNIDADES[claseFuente(fuente)][Number(n) === 1 ? 0 : 1];
const unidades = (fuente, n) => `${num(n)} ${unidad(fuente, n)}`;
const iconoFuente = (fuente) => ({ agentes: "agente", dhcp: "dhcp" }[claseFuente(fuente)] || "logs");
/** Sufijo de las clases CSS de cada tipo de fuente (tarjeta-imp--agente, alias--dhcp…) */
const estiloFuente = (fuente) => ({ agentes: "agente", dhcp: "dhcp" }[claseFuente(fuente)] || "");
/** Lo que se muestra como período de una importación */
const periodoImp = (x) => ({
  agentes: `Listado del ${fechaLog(x.fecha_hasta)}`,
  dhcp: `Concesiones importadas el ${fecha(x.creado_en)}`,
}[claseFuente(x.fuente)] || rangoFechas(x.fecha_desde, x.fecha_hasta));
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
        <p>Importe los registros del firewall, el listado de equipos con el agente de Microclaudia y las concesiones del DHCP, y véalos de
          inmediato en gráficos. Fíltrelos como en Wireshark, compárelos entre sí y crúcelos con el inventario de equipos y con el personal.</p>
      </div>
      <div class="encabezado__acciones">
        <a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Logs de Sophos</a>
        <a class="btn btn--secundario" href="#/logs/importar/microclaudia">${icono("agente")}Equipos de Microclaudia</a>
        <a class="btn btn--secundario" href="#/logs/importar/dhcp">${icono("dhcp")}Concesiones del DHCP</a>
      </div>
    </div>
    <div data-resumen>${cargandoHTML()}</div>

    <h2 class="titulo-seccion">Importar desde</h2>
    <div class="fuentes fuentes--cuatro">
      <a class="fuente" href="#/logs/importar/sophos">
        <span class="fuente__icono">${icono("firewall")}</span>
        <span class="fuente__texto"><strong>Sophos Firewall</strong>
          <span>Log viewer: Firewall, Web filter, SSL/TLS, IPS, ATP… El archivo .txt o .log que se copia o descarga.</span></span>
        <span class="fuente__ir">Importar${icono("derecha")}</span>
      </a>
      <a class="fuente fuente--agente" href="#/logs/importar/microclaudia">
        <span class="fuente__icono">${icono("agente")}</span>
        <span class="fuente__texto"><strong>Microclaudia</strong>
          <span>El listado de equipos con el agente (.csv o .txt). Muestra el estado del agente y qué equipos no lo tienen.</span></span>
        <span class="fuente__ir">Importar${icono("derecha")}</span>
      </a>
      <a class="fuente fuente--dhcp" href="#/logs/importar/dhcp">
        <span class="fuente__icono">${icono("dhcp")}</span>
        <span class="fuente__texto"><strong>Servidor DHCP</strong>
          <span>Las concesiones y reservas (.txt o .csv). Compara cada MAC con los equipos registrados para encontrar intrusos en la red.</span></span>
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
          ${atajo("#/logs/intrusos", "intruso", "Intrusos en la red", "Concesiones del DHCP cuya MAC no está registrada")}
          ${atajo("#/logs/cobertura", "agente", "Equipos sin agente", "Equipos registrados sin el agente de Microclaudia")}
          ${atajo("#/logs/comparar", "comparar", "Comparar logs", "Qué tienen en común y qué solo aparece en uno")}
          ${atajo("#/logs/inventario", "red", "Cruce con el inventario", "Equipos, IP sin registrar y personas")}
          ${atajo("#/logs/campos", "campos", "Campos y alias", "Cómo se llama cada dato en cada programa")}
        </ul>
      </section>
    </div>`;

  const imps = await api("logs/importaciones/");
  if (!ctx.vigente()) return;
  const logs = imps.filter((x) => !esListado(x.fuente));
  const ultimoListado = imps.find((x) => claseFuente(x.fuente) === "agentes");
  const ultimoDhcp = imps.find((x) => esDhcp(x.fuente));
  const suma = (k) => logs.reduce((s, x) => s + (Number(x[k]) || 0), 0);
  cont.querySelector("[data-resumen]").outerHTML = `
    <nav class="resumen resumen--cinco" aria-label="Resumen">
      <a href="#/logs/importaciones"><b>${num(imps.length)}</b><span>Importaciones</span></a>
      <a href="${rutaLogs("eventos", { q: "fuente == sophos" })}"><b>${compacto(suma("total_eventos"))}</b><span>Eventos de los logs</span></a>
      <a href="${rutaLogs("eventos", { q: "accion == denegado" })}"><b>${compacto(suma("denegados"))}</b><span>Eventos denegados</span></a>
      <a href="${ultimoListado ? `#/logs/importaciones/${ultimoListado.id_importacion}` : "#/logs/importar/microclaudia"}">
        <b>${ultimoListado ? num(ultimoListado.total_eventos) : "—"}</b><span>Equipos con el agente${ultimoListado ? " (último listado)" : ""}</span></a>
      <a href="${ultimoDhcp ? rutaLogs("intrusos", { dhcp: ultimoDhcp.id_importacion }) : "#/logs/importar/dhcp"}">
        <b>${ultimoDhcp ? num(ultimoDhcp.total_eventos) : "—"}</b><span>Concesiones del DHCP${ultimoDhcp ? " (última lista)" : ""}</span></a>
    </nav>`;

  const caja = cont.querySelector("[data-recientes]");
  if (!imps.length) {
    caja.innerHTML = vacioHTML({
      icono: "logs", titulo: "Todavía no hay nada importado", texto: "Importe el primer archivo de Sophos, de Microclaudia o del DHCP para ver su tablero.",
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
  const listado = esListado(x.fuente);
  return `<li><a class="tarjeta-imp${listado ? ` tarjeta-imp--${estiloFuente(x.fuente)}` : ""}" href="#/logs/importaciones/${x.id_importacion}">
    <span class="tarjeta-imp__icono">${icono(iconoFuente(x.fuente))}</span>
    <span class="tarjeta-imp__texto">
      <strong>${esc(x.nombre_archivo)}</strong>
      <small>N.º ${x.id_importacion} · ${esc(FUENTES[x.fuente] || x.fuente)} · ${esc(periodoImp(x).replace(/^\S+/, (p) => p.toLowerCase()))}${x.descripcion ? ` · ${esc(x.descripcion)}` : ""}</small>
      ${listado ? "" : miniMedidor(x)}
    </span>
    <span class="tarjeta-imp__n"><b>${num(x.total_eventos)}</b><small>${unidad(x.fuente, x.total_eventos)}</small></span>
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
   Importar: una pantalla por programa, con el mismo funcionamiento
   ===================================================================== */
const IMPORTADORES = {
  sophos: {
    clave: "SOPHOS", titulo: "Importar logs de Sophos Firewall", miga: "Importar logs de Sophos",
    ruta: "logs/importaciones/sophos/", icono: "firewall",
    texto: "Suelte uno o varios archivos. Cada uno queda como una importación con su propio tablero; después se pueden explorar juntos o comparar.",
    zona: "Arrastre aquí los archivos de Sophos", formatos: ".txt o .log", accept: ".txt,.log,.csv,.text,text/plain",
    extension: /\.(txt|log|csv|text)$/i, procesando: "Leyendo y guardando los eventos…",
    ejemplo: "Ej.: Revisión del acceso a www.grecia.go.cr",
    ayuda: `
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
        <a href="#/logs/campos">Campos y alias</a>.</span></p>`,
  },
  microclaudia: {
    clave: "MICROCLAUDIA", titulo: "Importar equipos de Microclaudia", miga: "Importar equipos de Microclaudia",
    ruta: "logs/importaciones/microclaudia/", icono: "agente",
    texto: "El listado de los equipos que tienen el agente de Microclaudia. Al importarlo se ve el estado del agente y qué equipos de la red municipal no lo tienen.",
    zona: "Arrastre aquí el listado de equipos de Microclaudia", formatos: ".csv o .txt", accept: ".csv,.txt,.text,text/csv,text/plain",
    extension: /\.(csv|txt|text)$/i, procesando: "Leyendo y guardando los equipos…",
    ejemplo: "Ej.: Listado del 23 de octubre",
    ayuda: `
      <ol class="pasos-ayuda">
        <li><strong>En el portal de Microclaudia</strong>, abra el listado de equipos y expórtelo. Sirven los dos formatos:
          <code>.csv</code> (separado por punto y coma) y <code>.txt</code> (separado por tabulaciones).</li>
        <li><strong>Columnas:</strong> NOMBRE, SIST_OPERATIVO, VERSION, ULTIMA_CONEXION, las vacunas, IPADDRESS y MACADDRESS.
          Un equipo puede traer varias IP y MAC: se guardan todas.</li>
        <li><strong>Para cruzar</strong> se usan las IPv4 y MAC de cada equipo; se dejan fuera las 169.254.x (sin DHCP) y la MAC que
          comparte VirtualBox en muchos equipos.</li>
        <li><strong>Equipos sin agente:</strong> los equipos registrados en el sistema (Equipos municipales) se comparan por su MAC,
          su IP y su nombre en la red con el último listado importado.</li>
      </ol>
      <p class="ayuda-importar__nota">${icono("enlace", "ic--sm")}<span>Importe un listado nuevo cada cierto tiempo y compárelos en
        <a href="#/logs/comparar">Comparar logs</a> por nombre del equipo: verá qué equipos entraron y cuáles salieron.</span></p>`,
  },
  dhcp: {
    clave: "DHCP", titulo: "Importar concesiones del DHCP", miga: "Importar concesiones del DHCP",
    ruta: "logs/importaciones/dhcp/", icono: "dhcp",
    texto: "La lista de direcciones que entregó el servidor DHCP. Cada MAC se compara con los equipos registrados en el sistema para encontrar intrusos en la red.",
    zona: "Arrastre aquí la lista de concesiones del DHCP", formatos: ".txt o .csv", accept: ".txt,.csv,.text,text/plain,text/csv",
    extension: /\.(txt|csv|text)$/i, procesando: "Leyendo y guardando las concesiones…",
    ejemplo: "Ej.: Ámbito 10.1.10.0, 27 de octubre",
    ayuda: `
      <ol class="pasos-ayuda">
        <li><strong>En el Administrador de DHCP</strong>, abra el servidor, <em>IPv4</em>, el ámbito y <em>Concesiones de direcciones</em>.
          Clic derecho, <em>Exportar lista…</em> y guárdela como texto delimitado por tabulaciones (<code>.txt</code>) o por comas (<code>.csv</code>).</li>
        <li><strong>También sirve</strong> copiar las filas de la consola y pegarlas en un <code>.txt</code>: aunque las columnas queden corridas,
          cada fila se lee por su contenido.</li>
        <li><strong>Con PowerShell:</strong> <code>Get-DhcpServerv4Lease -ScopeId 10.1.10.0 | Export-Csv dhcp.csv -NoTypeInformation</code>.</li>
        <li><strong>La MAC</strong> sale del <em>Id. exclusivo</em> de cada concesión, también en los equipos que envían un identificador largo
          (DUID). Las reservas se importan junto con las concesiones.</li>
      </ol>
      <p class="ayuda-importar__nota">${icono("enlace", "ic--sm")}<span>Al importar se abre <a href="#/logs/intrusos">Intrusos en la red</a>:
        cada MAC se busca en los equipos registrados y en el último listado de Microclaudia.</span></p>`,
  },
};

export const vistaImportarSophos = (cont, _params, ctx) => vistaImportar(cont, ctx, IMPORTADORES.sophos);
export const vistaImportarMicroclaudia = (cont, _params, ctx) => vistaImportar(cont, ctx, IMPORTADORES.microclaudia);
export const vistaImportarDhcp = (cont, _params, ctx) => vistaImportar(cont, ctx, IMPORTADORES.dhcp);

async function vistaImportar(cont, ctx, def) {
  ctx.migas([{ texto: def.miga }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div class="encabezado-imp">
        <span class="insignia-log${esListado(def.clave) ? ` insignia-log--${estiloFuente(def.clave)}` : ""}">${icono(def.icono)}</span>
        <div><h1>${esc(def.titulo)}</h1><p>${esc(def.texto)}</p></div>
      </div>
      <div class="encabezado__acciones"><a class="btn btn--secundario" href="#/logs/importaciones">${icono("capas")}Importaciones</a></div>
    </div>
    <div class="importar">
      <section class="panel soltar" data-zona>
        <input type="file" id="archivos-log" multiple accept="${esc(def.accept)}" class="visualmente-oculto">
        <label for="archivos-log" class="soltar__zona">
          <span class="soltar__icono">${icono("subir")}</span>
          <strong>${esc(def.zona)}</strong>
          <span>o haga clic para elegirlos · ${esc(def.formatos)} · hasta ${MAX_MB} MB cada uno</span>
        </label>
        <ul class="soltar__archivos" data-lista hidden></ul>
        <div class="soltar__pie">
          <div class="campo">
            <label for="desc-log">Descripción <span class="etiqueta-nota">(opcional, para todos los archivos)</span></label>
            <input id="desc-log" maxlength="255" placeholder="${esc(def.ejemplo)}">
          </div>
          <button type="button" class="btn btn--primario" data-importar disabled>${icono("subir")}Importar</button>
        </div>
      </section>
      <aside class="panel ayuda-importar">
        <div class="panel__cabeza"><h2>Qué archivos sirven</h2></div>
        <div class="panel__cuerpo">${def.ayuda}</div>
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

  const extOk = (n) => def.extension.test(n) || !/\.[^./\\]+$/.test(n);
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
    procesando: def.procesando,
    listo: `${unidades(def.clave, a.resultado?.total_eventos)} guardados${a.resultado?.repetidos ? ` · ${num(a.resultado.repetidos)} repetidos` : ""}${a.resultado?.avisos ? ` · ${num(a.resultado.avisos)} avisos` : ""}`,
    error: a.error || "No se pudo importar",
  }[a.estado]);

  const agregar = (lista2) => {
    for (const f of lista2) {
      if (archivos.some((a) => a.file.name === f.name && a.file.size === f.size && a.estado !== "error")) continue;
      const a = { file: f, estado: "pendiente" };
      if (!extOk(f.name)) { a.estado = "error"; a.error = `Use el archivo que exporta ${FUENTES[def.clave]} (${def.formatos}).`; }
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
        a.resultado = await apiSubir(def.ruta, datos, {
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
      toast(`Se importaron ${unidades(def.clave, listas[0].resultado.total_eventos)}.`);
      location.hash = `#/logs/importaciones/${listas[0].resultado.id_importacion}`;
      return;
    }
    if (listas.length) {
      const ids = listas.map((a) => a.resultado.id_importacion);
      const total = listas.reduce((s, a) => s + (Number(a.resultado.total_eventos) || 0), 0);
      resultados.innerHTML = `
        <section class="panel resultado-importacion">
          <div class="panel__cuerpo">
            <div class="resultado-importacion__texto">${icono("check")}<div><strong>Se importaron ${listas.length} archivos con ${unidades(def.clave, total)}.</strong>
              <p>${errores.length ? `${errores.length} no se pudieron importar (vea el motivo en la lista). ` : ""}Véalos juntos o compárelos.</p></div></div>
            <div class="encabezado__acciones">
              ${esDhcp(def.clave)
                ? `<a class="btn btn--primario" href="${rutaLogs("intrusos", { dhcp: ids[ids.length - 1] })}">${icono("intruso")}Intrusos en la red</a>`
                : esListado(def.clave)
                ? `<a class="btn btn--primario" href="${rutaLogs("cobertura", { agentes: ids[ids.length - 1] })}">${icono("agente")}Equipos sin agente</a>`
                : `<a class="btn btn--primario" href="${rutaLogs("tablero", { importaciones: ids })}">${icono("grafico")}Tablero de todos</a>`}
              <a class="btn btn--secundario" href="${rutaLogs("eventos", { importaciones: ids })}">${icono("filtro")}Explorar ${UNIDADES[claseFuente(def.clave)][1]}</a>
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
      <div><h1>Importaciones</h1><p>Cada archivo importado: logs de Sophos, listados de equipos de Microclaudia y concesiones del DHCP. Marque varias para explorarlas juntas o compararlas.</p></div>
      <div class="encabezado__acciones"><a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Logs de Sophos</a>
        <a class="btn btn--secundario" href="#/logs/importar/microclaudia">${icono("agente")}Equipos de Microclaudia</a>
        <a class="btn btn--secundario" href="#/logs/importar/dhcp">${icono("dhcp")}Concesiones del DHCP</a></div>
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
        icono: "logs", titulo: "Todavía no hay nada importado", texto: "Importe logs de Sophos, el listado de equipos de Microclaudia o las concesiones del DHCP.",
        boton: `<span class="botones-vacio"><a class="btn btn--primario" href="#/logs/importar/sophos">${icono("subir")}Logs de Sophos</a>
          <a class="btn btn--secundario" href="#/logs/importar/microclaudia">${icono("agente")}Equipos de Microclaudia</a>
          <a class="btn btn--secundario" href="#/logs/importar/dhcp">${icono("dhcp")}Concesiones del DHCP</a></span>`,
      });
      return;
    }
    caja.innerHTML = `<div class="tabla-envoltura"><table class="tabla">
      <thead><tr><th class="col-check"><span class="visualmente-oculto">Elegir</span></th><th>Archivo</th><th class="col-numero">Registros</th>
        <th>Permitidos / denegados</th><th class="col-opcional">Período</th><th class="col-opcional">Importado</th><th class="col-acciones"><span class="visualmente-oculto">Acciones</span></th></tr></thead>
      <tbody>${filas.map((x) => `
        <tr data-id="${x.id_importacion}">
          <td class="col-check"><input type="checkbox" data-elegir="${x.id_importacion}"${elegidas.has(x.id_importacion) ? " checked" : ""} aria-label="Elegir ${esc(x.nombre_archivo)}"></td>
          <td><a href="#/logs/importaciones/${x.id_importacion}" class="enlace-imp">${icono(iconoFuente(x.fuente), "ic--sm")}<strong>${esc(x.nombre_archivo)}</strong></a>
            <span class="secundario">N.º ${x.id_importacion} · ${esc(FUENTES[x.fuente] || x.fuente)}${x.descripcion ? ` · ${esc(x.descripcion)}` : ""}</span></td>
          <td class="col-numero"><strong>${num(x.total_eventos)}</strong><span class="secundario">${unidad(x.fuente, x.total_eventos)}${x.repetidos ? ` · ${num(x.repetidos)} repetidos` : ""}</span></td>
          <td class="col-medidor">${esDhcp(x.fuente) ? `<span class="pastilla pastilla--dhcp pastilla--sin-punto">${icono("dhcp", "ic--sm")}Concesiones del DHCP</span>`
            : esListado(x.fuente) ? `<span class="pastilla pastilla--agente pastilla--sin-punto">${icono("agente", "ic--sm")}Listado de agentes</span>`
            : `${miniMedidor(x)}<span class="secundario">${num(x.permitidos)} · ${num(x.denegados)}</span>`}</td>
          <td class="col-opcional">${esc(periodoImp(x))}</td>
          <td class="col-opcional"><span>${esc(fecha(x.creado_en))}</span><span class="secundario">${esc(x.importado_por || "")}</span></td>
          <td class="col-acciones"><span class="acciones-fila">
            ${esDhcp(x.fuente) ? `<a class="btn-icono" href="${rutaLogs("intrusos", { dhcp: x.id_importacion })}" title="Intrusos en la red" aria-label="Intrusos en la red según ${esc(x.nombre_archivo)}">${icono("intruso")}</a>`
              : esListado(x.fuente) ? `<a class="btn-icono" href="${rutaLogs("cobertura", { agentes: x.id_importacion })}" title="Equipos sin agente" aria-label="Equipos sin agente según ${esc(x.nombre_archivo)}">${icono("agente")}</a>` : ""}
            <a class="btn-icono" href="${rutaLogs("eventos", { importaciones: [x.id_importacion] })}" title="Explorar ${UNIDADES[claseFuente(x.fuente)][1]}" aria-label="Explorar ${esc(x.nombre_archivo)}">${icono("filtro")}</a>
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
    mensaje: `Se eliminarán «${imp.nombre_archivo}» y ${Number(imp.total_eventos) === 1 ? `su ${unidad(imp.fuente, 1)}` : `sus ${unidades(imp.fuente, imp.total_eventos)}`}. El archivo original no se toca; se puede volver a importar.`,
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
    const top = ev.target.closest("[data-top-campo], [data-top-q]");
    if (top) { ir(top.dataset.topQ !== undefined ? top.dataset.topQ : condicion(top.dataset.topCampo, top.dataset.topValor)); return; }
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
  if (esDhcp(imp.fuente)) return vistaIntrusos(cont, [], ctx, imp);
  if (esListado(imp.fuente)) return vistaListadoAgentes(cont, imp, ctx, cat);
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

/** Fila de un equipo del listado de Microclaudia dentro del explorador */
function filaAgenteHTML(e) {
  const pendientes = Number(e.vacunas_pendientes) || 0;
  return `<tr class="fila-log fila-log--agente" data-evento="${e.id_evento}" tabindex="0" aria-label="${esc(`Equipo con agente ${e.nombre_equipo || ""}`)}">
    <td class="col-hora"><span class="dato-mono">${esc(horaLog(e.fecha))}</span><small>${esc(diaLog(e.fecha))}</small></td>
    <td><span class="pastilla pastilla--agente">${icono("agente", "ic--sm")}Agente</span></td>
    <td class="col-tipo"><strong>${esc(e.nombre_equipo || "—")}</strong><small>${esc(e.sistema_operativo || "Equipo con agente")}</small></td>
    <td class="col-ip">${ipPuerto(e.ip_origen)}${e.mac_origen ? `<small class="dato-mono">${esc(macGuiones(e.mac_origen))}</small>` : ""}</td>
    <td class="col-flecha"></td>
    <td class="col-ip"><span class="sin-dato">—</span></td>
    <td class="col-sitio"><strong>Microclaudia</strong><small>Versión ${esc(e.version_agente || "—")}${pendientes ? ` · ${num(pendientes)} ${pendientes === 1 ? "vacuna pendiente" : "vacunas pendientes"}` : ""}</small></td>
  </tr>`;
}

/** Fila de una concesión o reserva del DHCP dentro del explorador */
function filaDhcpHTML(e) {
  const reserva = /^Reserva/.test(e.tipo || "");
  return `<tr class="fila-log fila-log--dhcp" data-evento="${e.id_evento}" tabindex="0" aria-label="${esc(`${e.tipo || "Concesión"} ${e.ip_origen || ""}`)}">
    <td class="col-hora">${e.fecha ? `<span class="dato-mono">${esc(horaLog(e.fecha))}</span><small>${esc(diaLog(e.fecha))}</small>` : `<span class="sin-dato">${reserva ? "Reserva" : "—"}</span>`}</td>
    <td><span class="pastilla pastilla--dhcp">${icono("dhcp", "ic--sm")}DHCP</span></td>
    <td class="col-tipo"><strong>${esc(e.nombre_equipo || "Sin nombre")}</strong><small>${esc(e.tipo || "Concesión DHCP")}</small></td>
    <td class="col-ip">${ipPuerto(e.ip_origen)}${e.mac_origen ? `<small class="dato-mono">${esc(macGuiones(e.mac_origen))}</small>` : ""}</td>
    <td class="col-flecha"></td>
    <td class="col-ip">${e.equipo_origen ? `<small class="en-inventario" title="Equipo del inventario">${icono("red", "ic--sm")}${esc(e.equipo_origen)}</small>` : `<span class="sin-dato">—</span>`}</td>
    <td class="col-sitio"><strong>Servidor DHCP</strong>${e.descripcion ? `<small>${esc(e.descripcion)}</small>` : ""}</td>
  </tr>`;
}

function tablaEventosHTML(filas, cat) {
  return `<div class="tabla-envoltura"><table class="tabla tabla--eventos">
    <thead><tr><th>Hora</th><th>Acción</th><th>Tipo</th><th>Origen</th><th class="col-flecha"><span class="visualmente-oculto">hacia</span></th>
      <th>Destino</th><th>Sitio o aplicación</th></tr></thead>
    <tbody>${filas.map((e) => {
      if (esDhcp(e.fuente)) return filaDhcpHTML(e);
      if (esListado(e.fuente)) return filaAgenteHTML(e);
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
        <p>Arme de 2 a 4 conjuntos (una o varias importaciones, con o sin filtro) y vea qué IP, dominios, reglas, usuarios o equipos tienen en común y cuáles aparecen solo en uno.
          Por ejemplo: un log de Sophos contra el listado de Microclaudia, por «IP de origen» o «MAC de origen».</p></div>
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
              <span><strong>N.º ${x.id_importacion} · ${esc(x.nombre_archivo)}</strong><small>${esListado(x.fuente) ? `<span class="pastilla pastilla--${claseFuente(x.fuente) === "dhcp" ? "dhcp" : "agente"} pastilla--mini">${icono(iconoFuente(x.fuente), "ic--sm")}${esc(FUENTES[x.fuente] || x.fuente)}</span> ` : ""}${esc(unidades(x.fuente, x.total_eventos))} · ${esc(esDhcp(x.fuente) ? `importada el ${diaLog(x.creado_en)}` : esListado(x.fuente) ? `listado del ${diaLog(x.fecha_hasta)}` : rangoFechas(x.fecha_desde, x.fecha_hasta))}</small></span></label>`).join("")
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
      // Clase de cada conjunto si todas sus importaciones son listados de la misma clase (agentes o dhcp)
      const listado = (ids) => {
        const clases = new Set(ids.map((id) => claseFuente(imps.find((x) => x.id_importacion === id)?.fuente)));
        const [clase] = clases;
        return ids.length && clases.size === 1 && clase !== "logs" ? clase : false;
      };
      pintarComparacion(salida, r, envio, cat, envio.map((c) => listado(c.importaciones)));
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

function pintarComparacion(salida, r, envio, cat, listados = []) {
  const k = r.conjuntos.length;
  const nombres = r.conjuntos.map((c) => c.nombre);
  const letra = (i) => `<span class="letra-conjunto letra-conjunto--${i + 1}" title="${esc(nombres[i])}">${LETRAS[i]}</span>`;
  // Solo los campos con algún valor (un listado de equipos no trae dominios ni reglas)
  const conValores = Object.keys(r.campos).filter((c) => r.campos[c].total);
  const campos = conValores.length ? conValores : Object.keys(r.campos);
  const cuantos = (i, n) => (listados[i] ? `${num(n)} ${UNIDADES[listados[i]][Number(n) === 1 ? 0 : 1]}` : eventos(n));
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
            ${letra(i)}<div><strong>${esc(nombres[i])}</strong><small>${listados[i] ? `${icono(listados[i] === "dhcp" ? "dhcp" : "agente", "ic--sm")} ` : ""}${esc(cuantos(i, s.total))} · ${esc(rangoFechas(s.desde, s.hasta))}</small>
            ${miniMedidor({ total: s.total, permitidos: s.permitidos, denegados: s.denegados })}</div>
          </div>`).join("")}</div>

        <div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--comparar">
          <thead><tr><th>Dato</th>${nombres.map((_, i) => `<th class="col-numero">${letra(i)}</th>`).join("")}</tr></thead>
          <tbody>${METRICAS.map(([clave, texto, f]) => `<tr><td>${esc(clave === "total" && listados.some(Boolean) ? "Registros" : texto)}</td>${r.resumenes.map((s) =>
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
  const celda = celdaCsv;   // con protección contra fórmulas de Excel
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
      <div class="encabezado__acciones"><a class="btn btn--secundario" href="#/logs/cobertura">${icono("agente")}Equipos sin el agente de Microclaudia</a></div>
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
        <p>Cada programa llama distinto a lo mismo: Sophos dice <code>src_ip</code>, Microclaudia <code>ipaddress</code> y el DHCP <code>ip_cliente</code>. Al importar, cada nombre se asigna
          solo a un campo común, así todos los archivos se pueden filtrar y comparar entre sí.</p></div>
      <div class="encabezado__acciones"><button type="button" class="btn btn--primario" data-nuevo-alias>${icono("mas")}Agregar alias</button></div>
    </div>
    <ul class="leyenda leyenda--alias"><li><span class="alias__fuente">SF</span>Sophos Firewall</li><li><span class="alias__fuente alias__fuente--agente">MC</span>Microclaudia</li>
      <li><span class="alias__fuente alias__fuente--dhcp">DH</span>Servidor DHCP</li></ul>
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
              <span class="alias${esListado(a.fuente) ? ` alias--${estiloFuente(a.fuente)}` : ""}">
                <span class="alias__fuente" title="${esc(FUENTES[a.fuente] || a.fuente)}">${esc({ MICROCLAUDIA: "MC", SOPHOS: "SF", DHCP: "DH" }[a.fuente] || a.fuente.slice(0, 2))}</span>
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


/* =====================================================================
   Tablero de un listado de Microclaudia (equipos con el agente)
   ===================================================================== */
const TRAMO_CLASE = { "24h": "t24h", "7d": "t7d", "30d": "t30d", mas: "tmas", sin: "otro" };
const ALERTA_ICONO = {
  sin_conexion: "historial", version: "agente", pendientes: "alerta", error: "alerta", soporte: "sistema", ip_compartida: "red",
};

/** "hace 3 h" / "hace 12 días", contado desde el momento del listado */
function haceTexto(horas) {
  if (horas === null || horas === undefined) return "sin fecha";
  if (horas < 1) return "menos de 1 h antes";
  if (horas < 48) return `${Math.round(horas)} h antes`;
  return `${Math.round(horas / 24)} días antes`;
}

function medidorPartes(partes, unidad) {
  const total = partes.reduce((s, x) => s + (Number(x.cantidad) || 0), 0);
  if (!total) return "";
  return `
    <div class="medidor" role="img" aria-label="${esc(partes.map((x) => `${x.texto}: ${num(x.cantidad)}`).join(", "))}">
      ${partes.filter((x) => x.cantidad).map((x) => `<span class="medidor__parte medidor__parte--${x.clase}" style="flex-grow:${x.cantidad}" tabindex="0"
        data-globo="${globoHTML(x.texto, [[unidad, num(x.cantidad)], ["Del total", pct(x.cantidad, total)]])}"></span>`).join("")}
    </div>
    <ul class="leyenda leyenda--medidor">
      ${partes.map((x) => `<li><i class="muestra muestra--${x.clase}"></i>${esc(x.texto)}<b>${num(x.cantidad)}</b><span>${pct(x.cantidad, total)}</span></li>`).join("")}
    </ul>`;
}

const medidorTramos = (tramos) => medidorPartes(tramos.map((t) => ({ texto: t.valor, cantidad: t.cantidad, clase: TRAMO_CLASE[t.clave] })), "Equipos");

/* ---------------------------------------------------------------------
   Equipos registrados en el sistema contra el listado de Microclaudia.
   El servidor devuelve cada dispositivo activo con su estado; aquí se
   filtran los tipos de equipo que se comparan (se recuerda en el navegador).
   --------------------------------------------------------------------- */
const CLAVE_TIPOS = "muni.logs.cobertura.excluir";

/** Tipos de equipo que no se comparan con el listado. Los que la persona no
 *  ha elegido todavía: se comparan solo los que llevan el agente por su
 *  categoría (computadoras y servidores); una impresora o un switch no. */
function tiposExcluidos(tipos = []) {
  let guardado = {};
  try {
    const v = JSON.parse(localStorage.getItem(CLAVE_TIPOS) || "null");
    // Versión anterior: solo la lista de excluidos
    guardado = Array.isArray(v) ? { excluidos: v, vistos: v } : v && typeof v === "object" ? v : {};
  } catch {
    guardado = {};
  }
  const excluidos = new Set(Array.isArray(guardado.excluidos) ? guardado.excluidos : []);
  const vistos = new Set(Array.isArray(guardado.vistos) ? guardado.vistos : []);
  for (const t of tipos) if (!vistos.has(t.tipo) && t.lleva_agente === false) excluidos.add(t.tipo);
  return excluidos;
}

function guardarExcluidos(excluidos, tipos = []) {
  try {
    localStorage.setItem(CLAVE_TIPOS, JSON.stringify({ excluidos: [...excluidos], vistos: tipos.map((t) => t.tipo) }));
  } catch {
    /* sin almacenamiento del navegador: vale solo mientras la pantalla esté abierta */
  }
}

const ESTADOS_COBERTURA = {
  con: { texto: "Con el agente", clase: "permitido" },
  sin: { texto: "Sin el agente", clase: "denegado" },
  revisar: { texto: "Por revisar", clase: "revisar" },
  sin_direcciones: { texto: "Sin IP, MAC ni nombre en la red", clase: "otro" },
};

function resumirCobertura(cb, excluidos) {
  const lista = cb.dispositivos.filter((d) => !excluidos.has(d.tipo));
  const n = { con: 0, sin: 0, revisar: 0, sin_direcciones: 0 };
  for (const d of lista) n[d.estado] += 1;
  const comparables = n.con + n.sin + n.revisar;
  return { lista, ...n, total: lista.length, comparables, cobertura: comparables ? (100 * n.con) / comparables : null };
}

const porcentaje = (v) => (v === null || v === undefined ? "—" : `${v.toLocaleString("es-CR", { maximumFractionDigits: 1 })} %`);

const medidorCobertura = (r) => medidorPartes(Object.entries(ESTADOS_COBERTURA)
  .filter(([k]) => k === "con" || k === "sin" || r[k])
  .map(([k, e]) => ({ texto: e.texto, cantidad: r[k], clase: e.clase })), "Equipos");

/** Barra fina con agente / sin agente / por revisar, con globo. */
function miniCobertura(n) {
  const partes = ["con", "sin", "revisar"].filter((k) => n[k]);
  const total = partes.reduce((s, k) => s + n[k], 0);
  if (!total) return "";
  return `<span class="mini-medidor" tabindex="0" data-globo="${globoHTML(`${num(total)} ${total === 1 ? "equipo" : "equipos"} que se comparan`,
    partes.map((k) => [ESTADOS_COBERTURA[k].texto, num(n[k]), ESTADOS_COBERTURA[k].clase]))}">
    ${partes.map((k) => `<i class="medidor__parte--${ESTADOS_COBERTURA[k].clase}" style="flex-grow:${n[k]}"></i>`).join("")}</span>`;
}

const nombreDispositivo = (d) => d.equipo || `Dispositivo N.º ${d.id_disp}`;
/** «SERIE CN-123» del texto «COMPUTADORA · DELL · SERIE CN-123» (para listas cortas) */
const serieDispositivo = (d) => (d.equipo ? d.equipo.split(" · ").pop() : `N.º ${d.id_disp}`);
const direccionesHTML = (ips, macs) => [...ips, ...macs.map(macGuiones)].map(esc).join("<br>") || `<span class="sin-dato">—</span>`;
// Los equipos del listado de Microclaudia son computadoras (el agente es para ellas)
const rutaRegistrar = (f) => `#/red/dispositivos/nuevo?${new URLSearchParams(
  Object.entries({ ip: f.ip, mac: f.mac, equipo: f.nombre, tipo: "COMPUTADORA" }).filter(([, v]) => v))}`;

function coberturaResumenHTML(cb, idAgentes) {
  if (!cb?.totales) return "";
  const enlace = rutaLogs("cobertura", { agentes: idAgentes });
  const noRegistrados = cb.totales.no_registrados;
  if (!cb.totales.dispositivos) {
    return `<section class="panel cobertura-resumen"><div class="panel__cuerpo"><div class="aviso aviso--info">${icono("red")}
      <span>Todavía no hay equipos registrados en el sistema. Registre cada equipo en <a href="#/red/dispositivos/nuevo">Equipos municipales</a>
      con su IP, su MAC o su nombre en la red y aquí verá cuáles no tienen el agente.</span></div></div></section>`;
  }
  const excluidos = tiposExcluidos(cb.tipos);
  const r = resumirCobertura(cb, excluidos);
  const sin = r.lista.filter((d) => d.estado === "sin");
  return `
    <section class="panel cobertura-resumen">
      <div class="panel__cabeza"><div><h2>Equipos registrados sin el agente</h2>
        <p>Los equipos registrados en el sistema${excluidos.size ? ` (sin ${esc([...excluidos].join(", ").toLowerCase())})` : ""}, comparados por su IP, su MAC y su nombre en la red con este listado.</p></div>
        <a class="btn btn--primario btn--sm" href="${enlace}">${icono("agente")}Ver el detalle</a></div>
      <div class="panel__cuerpo cobertura-resumen__cuerpo">
        <a class="cobertura-resumen__dato${r.sin ? " cobertura-resumen__dato--sin" : ""}" href="${enlace}">
          <b>${num(r.sin)}</b><span>${r.sin === 1 ? "equipo registrado sin el agente" : "equipos registrados sin el agente"}</span>
          <small>Cobertura: ${porcentaje(r.cobertura)} de ${num(r.comparables)}</small></a>
        <div class="cobertura-resumen__medidor">${r.total ? medidorCobertura(r) : ""}
          ${noRegistrados ? `<p class="cobertura-resumen__nota">${icono("agente", "ic--sm")}<span>${num(noRegistrados)} ${noRegistrados === 1
            ? "equipo de este listado no está registrado" : "equipos de este listado no están registrados"} en el sistema.
            <a href="${rutaLogs("cobertura", { agentes: idAgentes, ver: "no-registrados" })}">Verlos</a></span></p>` : ""}</div>
        ${sin.length ? `<ul class="ips-sin-agente">${sin.slice(0, 8).map((d) => `<li>
          <a href="#/red/dispositivos/${d.id_disp}" title="${esc(nombreDispositivo(d))}">${esc(serieDispositivo(d))}</a>
          <small>${esc(d.tipo)} · <span class="dato-mono">${esc(d.ips[0] || macGuiones(d.macs[0] || ""))}</span></small></li>`).join("")}
          ${sin.length > 8 ? `<li><a href="${enlace}">y ${num(sin.length - 8)} más</a></li>` : ""}</ul>`
          : `<p class="cobertura-resumen__ok">${icono("check")}<span>${r.comparables ? "Todos los equipos registrados que se pueden comparar tienen el agente." : "Ningún equipo registrado tiene IP, MAC ni nombre en la red para comparar."}</span></p>`}
      </div>
    </section>`;
}

async function vistaListadoAgentes(cont, imp, ctx, cat) {
  const id = imp.id_importacion;
  const base = { q: "", importaciones: [id] };
  const [a, cb] = await Promise.all([
    api("logs/agentes/", { query: { importacion: id } }),
    api("logs/cobertura/", { query: { agentes: id } }).catch(() => null),
  ]);
  if (!ctx.vigente()) return;
  ctx.migas([{ texto: "Importaciones", href: "#/logs/importaciones" }, { texto: imp.nombre_archivo }]);
  const nueva = recienImportadas.get(id);
  recienImportadas.delete(id);
  const avisos = nueva?.avisos_detalle || [];
  const r = a.resumen;
  const cifra = (valor, texto, extra = "", clase = "") => `<div class="cifra${clase ? ` ${clase}` : ""}"><b>${valor}</b><span>${esc(texto)}</span>${extra}</div>`;
  const panelTop = (titulo, grupo, filas, opciones = {}) => `
    <section class="panel panel--top">
      <div class="panel__cabeza"><h2><i class="punto-grupo punto-grupo--${grupo}"></i>${esc(titulo)}</h2></div>
      <div class="panel__cuerpo">${listaTopHTML(opciones.campo || "nombre_equipo", filas, cat, { unidad: "Equipos", limite: opciones.limite || 8 })}</div>
    </section>`;

  cont.innerHTML = `
    <div class="encabezado encabezado--imp">
      <div class="encabezado-imp">
        <span class="insignia-log insignia-log--agente">${icono("agente")}</span>
        <div>
          <h1>${esc(imp.nombre_archivo)}</h1>
          <p>${imp.descripcion ? `${esc(imp.descripcion)} · ` : ""}Listado de equipos de Microclaudia · Importación N.º ${id} ·
            ${esc(fecha(imp.creado_en))}${imp.importado_por ? ` por ${esc(imp.importado_por)}` : ""}</p>
        </div>
      </div>
      <div class="encabezado__acciones">
        <a class="btn btn--primario" href="${rutaLogs("cobertura", { agentes: id })}">${icono("agente")}Equipos sin agente</a>
        <a class="btn btn--secundario" href="${rutaLogs("eventos", base)}">${icono("filtro")}Explorar equipos</a>
        <a class="btn btn--secundario" href="${rutaLogs("comparar", base)}">${icono("comparar")}Comparar</a>
        ${menuExportarHTML()}
        <button type="button" class="btn-icono" data-editar title="Editar descripción" aria-label="Editar descripción">${icono("editar")}</button>
        <button type="button" class="btn-icono btn-icono--peligro" data-eliminar title="Eliminar importación" aria-label="Eliminar importación">${icono("borrar")}</button>
      </div>
    </div>
    ${nueva ? `
      <div class="aviso aviso--exito">${icono("check")}<div><strong>Importación lista: ${unidades(imp.fuente, nueva.total_eventos)} con el agente.</strong>
        ${nueva.repetidos ? ` ${num(nueva.repetidos)} filas estaban repetidas y se guardaron una sola vez.` : ""}
        ${avisos.length ? `<details class="avisos-imp"><summary>${num(nueva.avisos)} filas tuvieron avisos</summary><ul>${avisos.map((x) => `<li>${esc(x)}</li>`).join("")}</ul></details>` : ""}
      </div></div>` : ""}
    <div class="tablero" data-tablero>
      <div class="cifras">
        <div class="cifra cifra--principal cifra--agente"><span>Equipos con el agente</span><b>${num(a.total)}</b>
          <small>Listado del ${esc(fechaLog(a.referencia))} (hora del listado)</small></div>
        <div class="cifra cifra--medidor"><span>Última conexión de cada equipo</span>${medidorTramos(a.tramos)}</div>
      </div>
      <div class="cifras cifras--chicas">
        ${cifra(num(r.conectados_24h), "Conectados en las últimas 24 h", "", "cifra--ok")}
        ${cifra(num(r.sin_conexion_7d), "Más de 7 días sin conectarse", "", r.sin_conexion_7d ? "cifra--aviso" : "")}
        ${cifra(num(r.desactualizados), "Con otra versión del agente", `<small>La más nueva: ${esc(a.version_actual || "—")}</small>`, r.desactualizados ? "cifra--aviso" : "")}
        ${cifra(num(r.con_pendientes), "Con vacunas pendientes", `<small>${num(r.vacunas_pendientes)} vacunas en total</small>`, r.con_pendientes ? "cifra--aviso" : "")}
        ${cifra(num(r.sin_soporte), "Sistema sin soporte", "<small>Windows 10 o anterior; Server 2012 o anterior</small>", r.sin_soporte ? "cifra--aviso" : "")}
        ${cifra(num(r.servidores), "Servidores")}
      </div>
      ${coberturaResumenHTML(cb, id)}
      <div class="rejilla-tablero">
        ${panelTop("Última conexión", "general", a.tramos.map((t) => ({ valor: t.valor, cantidad: t.cantidad, q: t.q, clase: TRAMO_CLASE[t.clave] })), { limite: 6 })}
        ${panelTop("Sistema operativo", "origen", a.sistemas)}
        ${panelTop("Versión del agente", "app", a.versiones)}
        ${panelTop("Nombre del equipo (prefijo)", "origen", a.prefijos, { limite: 10 })}
        ${panelTop("Red de la IP principal", "origen", a.redes)}
        <section class="panel panel--top">
          <div class="panel__cabeza"><h2><i class="punto-grupo punto-grupo--general"></i>IP repetidas en varios equipos</h2></div>
          <div class="panel__cuerpo">${a.compartidas.length ? `<ul class="lista-compartidas">${a.compartidas.slice(0, 8).map((x) => `
            <li><span class="dato-mono">${esc(x.ip)}</span><small>${esc(x.equipos.join(", "))}</small></li>`).join("")}</ul>
            <p class="nota-panel">Suele ser una IP vieja que el agente aún reporta y que el DHCP ya le dio a otro equipo. No se cuenta la red 192.168.56.x de VirtualBox.</p>`
            : `<p class="top-vacio">Ninguna IP se repite.</p>`}</div>
        </section>
      </div>

      <section class="panel" data-atencion>
        <div class="panel__cabeza"><div><h2>Requieren atención</h2><p>Equipos con el agente que tienen algo por revisar. Elija qué ver.</p></div></div>
        <div class="chips-alerta" role="group" aria-label="Qué revisar">
          <button type="button" class="chip-alerta" data-alerta="todas" aria-pressed="true">Todo<b>${num(a.equipos.filter((e) => e.alertas.length).length)}</b></button>
          ${a.alertas.map((x) => `<button type="button" class="chip-alerta" data-alerta="${x.clave}" aria-pressed="false"${x.cantidad ? "" : " disabled"}>
            ${icono(ALERTA_ICONO[x.clave], "ic--sm")}${esc(x.texto)}<b>${num(x.cantidad)}</b></button>`).join("")}
        </div>
        <div data-atencion-tabla></div>
      </section>

      <section class="panel" data-equipos>
        <div class="panel__cabeza"><div><h2>Todos los equipos</h2><p>Haga clic en un equipo para ver todas sus IP, MAC y vacunas.</p></div>
          <div class="buscador buscador--equipos">${icono("buscar")}<input type="search" class="control" data-buscar-equipo placeholder="Nombre, IP, MAC o sistema" aria-label="Buscar equipo"></div></div>
        <div data-equipos-tabla></div>
      </section>
    </div>`;

  const POR_PAGINA = 25;
  const masBoton = (lista, todos, clave) => (lista.length > POR_PAGINA && !todos
    ? `<div class="mas-filas"><button type="button" class="btn btn--secundario btn--sm" data-mas="${clave}">Mostrar los ${num(lista.length)} equipos</button>
        <span>Se ven ${num(POR_PAGINA)} de ${num(lista.length)}.</span></div>` : "");
  const tabla = (lista, conAlertas, todos) => (lista.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--equipos">
    <thead><tr><th>Equipo</th>${conAlertas ? "<th>Qué revisar</th>" : ""}<th>Última conexión</th><th class="col-opcional">Sistema</th><th>Versión</th>
      <th>IP principal</th>${conAlertas ? "" : `<th class="col-opcional">MAC</th>`}<th class="col-numero col-opcional">Vacunas</th></tr></thead>
    <tbody>${(todos ? lista : lista.slice(0, POR_PAGINA)).map((e) => `
      <tr class="clicable" data-evento="${e.id_evento}" tabindex="0">
        <td><strong>${esc(e.nombre)}</strong></td>
        ${conAlertas ? `<td><span class="alertas-equipo">${e.alertas.map((k) => `<span class="alerta-equipo alerta-equipo--${k}">${esc((a.alertas.find((x) => x.clave === k) || {}).texto || k)}</span>`).join("")}</span></td>` : ""}
        <td><span class="tramo tramo--${TRAMO_CLASE[e.tramo]}"><i class="muestra muestra--${TRAMO_CLASE[e.tramo]}"></i>${esc(haceTexto(e.horas))}</span>
          <span class="secundario">${esc(fechaLog(e.ultima_conexion))}</span></td>
        <td class="col-opcional">${esc(e.sistema || "—")}</td>
        <td>${e.version === a.version_actual ? esc(e.version || "—") : `<strong class="texto-denegado">${esc(e.version || "—")}</strong>`}</td>
        <td class="dato-mono">${esc(e.ip || "—")}${e.ips.length > 1 ? `<span class="mas-direcciones" title="${esc(e.ips.join(", "))}">+${e.ips.length - 1}</span>` : ""}</td>
        ${conAlertas ? "" : `<td class="dato-mono col-opcional">${esc(macGuiones(e.macs[0] || ""))}${e.macs.length > 1 ? `<span class="mas-direcciones" title="${esc(e.macs.map(macGuiones).join(", "))}">+${e.macs.length - 1}</span>` : ""}</td>`}
        <td class="col-numero col-opcional">${num(e.aplicadas)}${e.pendientes ? ` <span class="texto-denegado">· ${num(e.pendientes)} pend.</span>` : ""}</td>
      </tr>`).join("")}</tbody></table></div>${masBoton(lista, todos, conAlertas ? "atencion" : "equipos")}` : `<p class="top-vacio">Ningún equipo.</p>`);

  const cajaAtencion = cont.querySelector("[data-atencion-tabla]");
  let alertaActual = "todas";
  const pintarAtencion = (clave, todos = false) => {
    alertaActual = clave;
    const lista = a.equipos.filter((e) => (clave === "todas" ? e.alertas.length : e.alertas.includes(clave)))
      .sort((x, y) => y.alertas.length - x.alertas.length || String(x.nombre).localeCompare(String(y.nombre)));
    cajaAtencion.innerHTML = tabla(lista, true, todos);
  };
  const cajaEquipos = cont.querySelector("[data-equipos-tabla]");
  let textoActual = "";
  const pintarEquipos = (texto, todos = false) => {
    textoActual = texto;
    const t = texto.trim().toLowerCase().replace(/[:-]/g, "");
    const lista = !t ? a.equipos : a.equipos.filter((e) => [e.nombre, e.sistema, e.version, ...e.ips, ...e.macs]
      .some((v) => String(v || "").toLowerCase().replace(/[:-]/g, "").includes(t)));
    cajaEquipos.innerHTML = tabla(lista, false, todos);
  };
  pintarAtencion("todas");
  pintarEquipos("");

  const tablero = cont.querySelector("[data-tablero]");
  enlazarTablero(tablero, { linea_tiempo: null }, base);
  enlazarExportar(cont, () => base);
  cont.querySelector("[data-buscar-equipo]").addEventListener("input", debounce((ev) => pintarEquipos(ev.target.value), 200));
  cont.querySelector(".chips-alerta").addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-alerta]");
    if (!b || b.disabled) return;
    cont.querySelectorAll("[data-alerta]").forEach((x) => x.setAttribute("aria-pressed", String(x === b)));
    pintarAtencion(b.dataset.alerta);
  });
  const abrir = (tr) => abrirEvento(Number(tr.dataset.evento), { importaciones: [id] });
  tablero.addEventListener("click", (ev) => {
    const mas = ev.target.closest("[data-mas]");
    if (mas) {
      if (mas.dataset.mas === "atencion") pintarAtencion(alertaActual, true); else pintarEquipos(textoActual, true);
      return;
    }
    const tr = ev.target.closest("tr[data-evento]");
    if (tr) abrir(tr);
  });
  tablero.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest?.("tr[data-evento]");
    if (tr && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); abrir(tr); }
  });
  cont.querySelector("[data-editar]").addEventListener("click", async () => {
    if (await editarDescripcion(imp)) vistaImportacion(cont, [id], ctx);
  });
  cont.querySelector("[data-eliminar]").addEventListener("click", async () => {
    if (await eliminarImportacion(imp)) location.hash = "#/logs/importaciones";
  });
}

/* =====================================================================
   Equipos sin el agente: los equipos registrados en el sistema
   (Equipos municipales) comparados con el listado de Microclaudia
   ===================================================================== */
export async function vistaCobertura(cont, _params, ctx) {
  ctx.migas([{ texto: "Equipos sin agente" }]);
  const listados = await api("logs/importaciones/", { query: { fuente: "MICROCLAUDIA" } });
  if (!ctx.vigente()) return;
  const encabezado = `
    <div class="encabezado">
      <div class="encabezado-imp">
        <span class="insignia-log insignia-log--agente">${icono("agente")}</span>
        <div><h1>Equipos sin el agente de Microclaudia</h1>
          <p>Los equipos registrados en el sistema (Equipos municipales), comparados por su IP, su MAC y su nombre en la red con
            el listado de equipos que tienen el agente.</p></div>
      </div>
      <div class="encabezado__acciones">
        <a class="btn btn--secundario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar equipo</a>
        <button type="button" class="btn btn--secundario" data-exportar-cobertura hidden>${icono("descargar")}Exportar (CSV)</button>
      </div>
    </div>`;
  if (!listados.length) {
    cont.innerHTML = `${encabezado}<section class="panel">${vacioHTML({
      icono: "agente", titulo: "Todavía no hay un listado de Microclaudia",
      texto: "Importe el listado de equipos con el agente para compararlo con los equipos registrados en el sistema.",
      boton: `<a class="btn btn--primario" href="#/logs/importar/microclaudia">${icono("subir")}Importar equipos de Microclaudia</a>`,
    })}</section>`;
    return;
  }
  const pedido = Number(ctx.query.get("agentes"));
  let agentes = listados.some((x) => x.id_importacion === pedido) ? pedido : listados[0].id_importacion;
  let irA = ctx.query.get("ver");
  let excluidos = null;      // se calcula con los tipos de la primera respuesta
  cont.innerHTML = `${encabezado}
    <section class="panel panel--filtro">
      <div class="cobertura-controles">
        <div class="campo"><label for="cb-listado">Listado de Microclaudia</label>
          <select id="cb-listado" class="control">${listados.map((x) => `<option value="${x.id_importacion}"${x.id_importacion === agentes ? " selected" : ""}>
            N.º ${x.id_importacion} · ${esc(x.nombre_archivo)} · ${esc(unidades(x.fuente, x.total_eventos))}</option>`).join("")}</select></div>
        <div class="campo cobertura-controles__tipos"><span class="etiqueta-campo">Tipos de equipo que se comparan</span>
          <div class="chips-tipos" data-tipos role="group" aria-label="Tipos de equipo que se comparan"></div></div>
      </div>
    </section>
    <div data-cobertura>${cargandoHTML()}</div>`;

  const caja = cont.querySelector("[data-cobertura]");
  const cajaTipos = cont.querySelector("[data-tipos]");
  const botonExportar = cont.querySelector("[data-exportar-cobertura]");
  let datos = null;
  let consulta = 0;
  let buscado = "";
  let todosNoRegistrados = false;

  const conexion = (f) => (f ? `<span class="tramo tramo--${TRAMO_CLASE[f.tramo]}"><i class="muestra muestra--${TRAMO_CLASE[f.tramo]}"></i>${esc(haceTexto(f.horas))}</span>
    <span class="secundario">${esc(fechaLog(f.ultima_conexion))}</span>` : `<span class="sin-dato">—</span>`);
  const celdaDispositivo = (d) => `<a href="#/red/dispositivos/${d.id_disp}"><strong>${esc(nombreDispositivo(d))}</strong></a>
    ${d.edificio || d.asignado ? `<span class="secundario">${esc([d.edificio, d.asignado].filter(Boolean).join(" · "))}</span>` : ""}`;
  const POR = { IP: "por la IP", MAC: "por la MAC", "IP y MAC": "por la IP y la MAC", "IP y nombre": "por la IP y el nombre", nombre: "por el nombre en la red" };
  const celdaAgente = (d) => `<button type="button" class="enlace-boton" data-evento-agente="${d.agente.id_evento}"><strong>${esc(d.agente.nombre)}</strong></button>
    <span class="secundario">${POR[d.por] || ""}${d.otros.length ? ` · también ${esc(d.otros.join(", "))}` : ""}</span>`;

  const tablaNoRegistrados = (lista) => {
    const t = buscado.trim().toLowerCase().replace(/[:-]/g, "");
    const filtrada = !t ? lista : lista.filter((f) => [f.nombre, f.sistema, f.version, ...f.ips, ...f.macs]
      .some((v) => String(v || "").toLowerCase().replace(/[:-]/g, "").includes(t)));
    const vista = todosNoRegistrados ? filtrada : filtrada.slice(0, 25);
    if (!filtrada.length) return `<p class="top-vacio">${lista.length ? "Ningún equipo coincide con la búsqueda." : "Todos los equipos del listado están registrados en el sistema."}</p>`;
    return `<div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--equipos">
      <thead><tr><th>Equipo en Microclaudia</th><th>IP principal</th><th class="col-opcional">MAC</th><th class="col-opcional">Sistema</th>
        <th>Última conexión</th><th class="col-acciones"></th></tr></thead>
      <tbody>${vista.map((f) => `<tr class="clicable" data-evento="${f.id_evento}" tabindex="0">
        <td><strong>${esc(f.nombre)}</strong></td>
        <td class="dato-mono">${esc(f.ip || "—")}${f.ips.length > 1 ? `<span class="mas-direcciones" title="${esc(f.ips.join(", "))}">+${f.ips.length - 1}</span>` : ""}</td>
        <td class="dato-mono col-opcional">${esc(macGuiones(f.mac || f.macs[0] || "")) || "—"}${f.macs.length > 1 ? `<span class="mas-direcciones" title="${esc(f.macs.map(macGuiones).join(", "))}">+${f.macs.length - 1}</span>` : ""}</td>
        <td class="col-opcional">${esc(f.sistema || "—")}</td>
        <td>${conexion(f)}</td>
        <td class="col-acciones"><a class="btn btn--secundario btn--sm" href="${rutaRegistrar(f)}">${icono("mas")}Registrar</a></td>
      </tr>`).join("")}</tbody></table></div>
      ${filtrada.length > vista.length ? `<div class="mas-filas"><button type="button" class="btn btn--secundario btn--sm" data-mas-no-registrados>Mostrar los ${num(filtrada.length)} equipos</button>
        <span>Se ven ${num(vista.length)} de ${num(filtrada.length)}.</span></div>` : ""}`;
  };

  const pintar = () => {
    const d = datos;
    excluidos ??= tiposExcluidos(d.tipos);
    const r = resumirCobertura(d, excluidos);
    const listado = d.importacion;
    const grupo = (estado) => r.lista.filter((x) => x.estado === estado);
    const porMac = r.lista.filter((x) => x.estado === "con" && x.por !== "IP").length;
    cajaTipos.innerHTML = d.tipos.length ? d.tipos.map((t) => {
      const dentro = !excluidos.has(t.tipo);
      return `<button type="button" class="chip-alerta" data-tipo="${esc(t.tipo)}" aria-pressed="${dentro}">
        ${icono(dentro ? "check" : "cerrar", "ic--sm")}${esc(t.tipo)}<b>${num(t.total)}</b></button>`;
    }).join("") : `<span class="sin-dato">Todavía no hay equipos registrados.</span>`;

    const porTipo = d.tipos.map((t) => {
      const n = { con: 0, sin: 0, revisar: 0, sin_direcciones: 0 };
      for (const x of d.dispositivos) if (x.tipo === t.tipo) n[x.estado] += 1;
      const comparables = n.con + n.sin + n.revisar;
      return { ...t, ...n, cobertura: comparables ? (100 * n.con) / comparables : null, fuera: excluidos.has(t.tipo) };
    });
    const sinAgente = grupo("sin");
    const revisar = grupo("revisar");
    const sinDirecciones = grupo("sin_direcciones");
    const conAgente = grupo("con");
    const cifra = (valor, texto, extra = "", clase = "") => `<div class="cifra${clase ? ` ${clase}` : ""}"><b>${valor}</b><span>${esc(texto)}</span>${extra}</div>`;

    caja.innerHTML = `
      ${d.totales.dispositivos ? `
      <div class="cifras">
        <div class="cifra cifra--principal cifra--cobertura"><span>Cobertura del agente</span><b>${porcentaje(r.cobertura)}</b>
          <small>de los ${num(r.comparables)} equipos registrados que se pueden comparar${excluidos.size ? " (tipos elegidos)" : ""}</small></div>
        <div class="cifra cifra--medidor"><span>Equipos registrados en el sistema</span>${r.total ? medidorCobertura(r) : `<p class="top-vacio">Elija al menos un tipo de equipo.</p>`}</div>
      </div>
      <div class="cifras cifras--chicas">
        ${cifra(num(r.total), "Equipos registrados")}
        ${cifra(num(r.sin), "Sin el agente", "", r.sin ? "cifra--sin" : "")}
        ${cifra(num(r.con), "Con el agente", porMac ? `<small>${num(porMac)} confirmados por la MAC</small>` : "", "cifra--ok")}
        ${cifra(num(r.revisar), "Por revisar", "<small>La IP coincide, la MAC no</small>", r.revisar ? "cifra--aviso" : "")}
        ${cifra(num(r.sin_direcciones), "Sin IP, MAC ni nombre en la red", "<small>No se pueden comparar</small>")}
        ${cifra(num(d.totales.no_registrados), "En el listado, sin registrar", `<small>de ${num(d.totales.agentes)} con el agente</small>`)}
      </div>` : `<section class="panel">${vacioHTML({
        icono: "red", titulo: "Todavía no hay equipos registrados en el sistema",
        texto: "Registre cada equipo en Equipos municipales con su nombre en la red, su IP o su MAC; aquí se compara con el listado de Microclaudia. Puede empezar por los de la lista de abajo.",
        boton: `<a class="btn btn--primario" href="#/red/dispositivos/nuevo">${icono("mas")}Registrar equipo</a>`,
      })}</section>`}
      <p class="nota-cobertura">${icono("enlace", "ic--sm")}<span>Listado: <a href="#/logs/importaciones/${listado.id_importacion}">${esc(listado.nombre_archivo)}</a>
        (${esc(unidades(listado.fuente, listado.total_eventos))}, del ${esc(fechaLog(d.referencia || listado.fecha_hasta))}).
        Un equipo tiene el agente si una de sus MAC está en el listado, o su IP cuando no tiene MAC registrada, o su nombre en la red.
        De entrada solo se comparan las computadoras y los servidores: los demás tipos se agregan arriba.</span></p>

      ${porTipo.length > 1 ? `
      <section class="panel">
        <div class="panel__cabeza"><div><h2>${icono("red")} Por tipo de equipo</h2><p>Los tipos que no se comparan quedan fuera de las cifras de arriba.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--tipos">
          <thead><tr><th>Tipo</th><th class="col-numero">Registrados</th><th class="col-numero">Con el agente</th><th class="col-numero">Sin el agente</th>
            <th class="col-numero col-opcional">Por revisar</th><th class="col-numero col-opcional">Sin datos para comparar</th><th>Cobertura</th></tr></thead>
          <tbody>${porTipo.map((t) => `<tr${t.fuera ? ' class="fila-fuera"' : ""}>
            <td><strong>${esc(t.tipo)}</strong>${t.fuera ? `<span class="secundario">No se compara</span>` : ""}</td>
            <td class="col-numero">${num(t.total)}</td><td class="col-numero">${num(t.con)}</td>
            <td class="col-numero">${t.sin ? `<strong class="texto-denegado">${num(t.sin)}</strong>` : "0"}</td>
            <td class="col-numero col-opcional">${num(t.revisar)}</td><td class="col-numero col-opcional">${num(t.sin_direcciones)}</td>
            <td class="col-medidor">${miniCobertura(t)}<span class="secundario">${porcentaje(t.cobertura)}</span></td>
          </tr>`).join("")}</tbody>
        </table></div>
      </section>` : ""}

      ${d.totales.dispositivos ? `
      <section class="panel panel--sin-agente">
        <div class="panel__cabeza"><div><h2>${icono("alerta")} Registrados sin el agente (${num(sinAgente.length)})</h2>
          <p>Ni sus IP, ni sus MAC, ni su nombre en la red están en el listado de Microclaudia.</p></div></div>
        ${sinAgente.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Equipo registrado</th><th>IP y MAC registradas</th><th class="col-acciones"></th></tr></thead>
          <tbody>${sinAgente.map((x) => `<tr>
            <td>${celdaDispositivo(x)}</td>
            <td class="dato-mono col-mac">${direccionesHTML(x.ips, x.macs)}</td>
            <td class="col-acciones"><a class="btn btn--secundario btn--sm" href="#/red/dispositivos/${x.id_disp}">${icono("red")}Ficha</a></td>
          </tr>`).join("")}</tbody></table></div>`
          : `<div class="panel__cuerpo"><p class="top-vacio">${r.comparables ? "Todos los equipos registrados que se pueden comparar tienen el agente." : "No hay equipos con IP, MAC o nombre en la red para comparar."}</p></div>`}
      </section>` : ""}

      ${revisar.length ? `
      <section class="panel panel--revisar">
        <div class="panel__cabeza"><div><h2>${icono("alerta")} Por revisar (${num(revisar.length)})</h2>
          <p>Su IP está en el listado, pero con otras MAC: puede ser otro equipo que recibió esa IP, o a este equipo le falta registrar una MAC.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Equipo registrado</th><th>IP y MAC registradas</th><th>Tiene esa IP en Microclaudia</th><th class="col-opcional">MAC en Microclaudia</th><th>Última conexión</th></tr></thead>
          <tbody>${revisar.map((x) => `<tr>
            <td>${celdaDispositivo(x)}</td>
            <td class="dato-mono col-mac">${direccionesHTML(x.ips, x.macs)}</td>
            <td>${celdaAgente(x)}</td>
            <td class="dato-mono col-mac col-opcional">${x.agente.macs.map((m) => esc(macGuiones(m))).join("<br>") || "—"}</td>
            <td>${conexion(x.agente)}</td>
          </tr>`).join("")}</tbody></table></div>
      </section>` : ""}

      ${sinDirecciones.length ? `
      <section class="panel">
        <div class="panel__cabeza"><div><h2>${icono("red")} Sin IP, MAC ni nombre en la red (${num(sinDirecciones.length)})</h2>
          <p>No se pueden comparar con el listado. Agregue su nombre en la red, su IP o su MAC en la ficha del equipo.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Equipo registrado</th><th class="col-acciones"></th></tr></thead>
          <tbody>${sinDirecciones.map((x) => `<tr><td>${celdaDispositivo(x)}</td>
            <td class="col-acciones"><a class="btn btn--secundario btn--sm" href="#/red/dispositivos/${x.id_disp}">${icono("editar")}Completar datos</a></td></tr>`).join("")}</tbody>
        </table></div>
      </section>` : ""}

      ${conAgente.length ? `
      <details class="panel panel--plegable">
        <summary class="panel__cabeza"><div><h2>${icono("check")} Con el agente (${num(conAgente.length)})</h2>
          <p>Una de sus MAC, o su IP cuando no tiene MAC registrada, o su nombre en la red está en el listado de Microclaudia.</p></div></summary>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Equipo registrado</th><th>IP y MAC registradas</th><th>Equipo en Microclaudia</th><th>Última conexión</th><th class="col-opcional">Versión</th></tr></thead>
          <tbody>${conAgente.map((x) => `<tr>
            <td>${celdaDispositivo(x)}</td>
            <td class="dato-mono col-mac">${direccionesHTML(x.ips, x.macs)}</td>
            <td>${celdaAgente(x)}</td>
            <td>${conexion(x.agente)}</td>
            <td class="col-opcional">${esc(x.agente.version || "—")}</td>
          </tr>`).join("")}</tbody></table></div>
      </details>` : ""}

      <section class="panel" data-no-registrados>
        <div class="panel__cabeza"><div><h2>${icono("agente")} En el listado de Microclaudia, pero no registrados en el sistema (${num(d.no_registrados.length)})</h2>
          <p>Tienen el agente, pero ningún equipo registrado tiene su MAC (ni su IP). <strong>Registrar</strong> abre el formulario con su IP y su MAC.</p></div>
          ${d.no_registrados.length ? `<div class="buscador buscador--equipos">${icono("buscar")}<input type="search" class="control" data-buscar-no-registrado value="${esc(buscado)}" placeholder="Nombre, IP, MAC o sistema" aria-label="Buscar en los equipos sin registrar"></div>` : ""}</div>
        <div data-tabla-no-registrados>${tablaNoRegistrados(d.no_registrados)}</div>
      </section>`;
    activarGlobos(caja);
    botonExportar.hidden = false;
    if (irA === "no-registrados") {
      irA = null;
      caja.querySelector("[data-no-registrados]")?.scrollIntoView({ block: "start" });
    }
  };

  const cargar = async () => {
    const yo = ++consulta;
    caja.classList.add("cargando-suave");
    try {
      const d = await api("logs/cobertura/", { query: { agentes } });
      if (!ctx.vigente() || yo !== consulta) return;
      datos = d;
      todosNoRegistrados = false;
      pintar();
    } catch (e) {
      if (!ctx.vigente() || yo !== consulta) return;
      caja.innerHTML = errorHTML(e.message);
    } finally {
      caja.classList.remove("cargando-suave");
    }
  };

  cont.querySelector("#cb-listado").addEventListener("change", (ev) => {
    agentes = Number(ev.target.value);
    reemplazarRuta(rutaLogs("cobertura", { agentes }));
    cargar();
  });
  cajaTipos.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-tipo]");
    if (!b || !datos) return;
    const tipo = b.dataset.tipo;
    if (excluidos.has(tipo)) excluidos.delete(tipo); else excluidos.add(tipo);
    guardarExcluidos(excluidos, datos.tipos);
    pintar();
    cajaTipos.querySelector(`[data-tipo="${CSS.escape(tipo)}"]`)?.focus();
  });
  caja.addEventListener("input", debounce((ev) => {
    if (!ev.target.matches("[data-buscar-no-registrado]")) return;
    buscado = ev.target.value;
    caja.querySelector("[data-tabla-no-registrados]").innerHTML = tablaNoRegistrados(datos.no_registrados);
  }, 200));
  caja.addEventListener("click", (ev) => {
    if (ev.target.closest("[data-mas-no-registrados]")) {
      todosNoRegistrados = true;
      caja.querySelector("[data-tabla-no-registrados]").innerHTML = tablaNoRegistrados(datos.no_registrados);
      return;
    }
    const agente = ev.target.closest("[data-evento-agente]");
    if (agente) { abrirEvento(Number(agente.dataset.eventoAgente), { importaciones: [agentes] }); return; }
    const tr = ev.target.closest("tr[data-evento]");
    if (tr && !ev.target.closest("a")) abrirEvento(Number(tr.dataset.evento), { importaciones: [agentes] });
  });
  caja.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest?.("tr[data-evento]");
    if (tr && ev.target === tr && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); abrirEvento(Number(tr.dataset.evento), { importaciones: [agentes] }); }
  });
  botonExportar.addEventListener("click", () => {
    if (!datos) return;
    const celda = celdaCsv;   // con protección contra fórmulas de Excel
    const filas = [["Estado", "Equipo registrado", "Tipo", "Edificio", "IP registradas", "MAC registradas", "Equipo en Microclaudia",
      "Coincide por", "IP en Microclaudia", "MAC en Microclaudia", "Última conexión del agente", "Versión del agente"]];
    for (const x of resumirCobertura(datos, excluidos).lista) {
      const a = x.agente;
      filas.push([ESTADOS_COBERTURA[x.estado].texto, nombreDispositivo(x), x.tipo, x.edificio || "", x.ips.join(" "), x.macs.map(macGuiones).join(" "),
        a ? a.nombre : "", x.por || "", a ? a.ips.join(" ") : "", a ? a.macs.map(macGuiones).join(" ") : "", a ? fechaLog(a.ultima_conexion) : "", a ? a.version || "" : ""]);
    }
    for (const f of datos.no_registrados) {
      filas.push(["En el listado, sin registrar", "", "", "", "", "", f.nombre, "", f.ips.join(" "), f.macs.map(macGuiones).join(" "),
        fechaLog(f.ultima_conexion), f.version || ""]);
    }
    descargarTexto(`﻿${filas.map((f) => f.map(celda).join(";")).join("\r\n")}\r\n`, `equipos_sin_agente_${marcaArchivo()}.csv`);
    toast("Se descargó el archivo.");
  });
  await cargar();
}

/* =====================================================================
   Intrusos en la red: las concesiones del DHCP comparadas por MAC con
   los equipos registrados en el sistema (Equipos municipales)
   ===================================================================== */
const ESTADOS_INTRUSOS = {
  intruso: { texto: "Posibles intrusos", clase: "denegado" },
  inactivo: { texto: "Registrados como inactivos", clase: "t30d" },
  municipal: { texto: "Municipales sin registrar", clase: "revisar" },
  registrado: { texto: "Registrados en el inventario", clase: "permitido" },
  sin_mac: { texto: "Sin MAC", clase: "otro" },
};
// Señales de cada concesión: buena = indica que es un equipo de la municipalidad
const PISTAS = {
  agente: { texto: "Tiene el agente", clase: "buena", ayuda: "Su MAC o su nombre está en el listado de Microclaudia" },
  dominio: { texto: "En el dominio", clase: "buena", ayuda: "Su nombre termina con el dominio de la red" },
  reserva: { texto: "Reserva del DHCP", clase: "buena", ayuda: "Alguien de TI le reservó esta IP en el DHCP" },
  aleatoria: { texto: "MAC aleatoria", clase: "mala", ayuda: "Dirección privada: la usan los celulares y portátiles personales en el Wi-Fi" },
  sin_nombre: { texto: "Sin nombre", clase: "mala", ayuda: "El equipo no le dijo su nombre al DHCP" },
  nueva: { texto: "MAC nueva", clase: "mala", ayuda: "No estaba en la lista anterior del DHCP" },
  ip_de_otro: { texto: "IP de otro equipo", clase: "mala", ayuda: "Esa IP está registrada a otro dispositivo" },
  inventario: { texto: "Nombre del inventario", clase: "buena", ayuda: "Su nombre es el de un equipo registrado: puede ser otra tarjeta de red (Wi-Fi o cable) de ese equipo" },
  nombre_distinto: { texto: "Otro nombre", clase: "neutra", ayuda: "Su MAC está registrada a un equipo con otro nombre en la red" },
  virtual: { texto: "Máquina virtual", clase: "neutra", ayuda: "La MAC es de un adaptador virtual" },
};
// Texto de más en el globo de cada pista: qué equipo es
const EXTRA_PISTA = {
  ip_de_otro: (c) => (c.ip_de ? `: ${c.ip_de.equipo || `N.º ${c.ip_de.id_disp}`}` : ""),
  inventario: (c) => (c.mismo_nombre ? ` (${c.mismo_nombre.equipo || `N.º ${c.mismo_nombre.id_disp}`})` : ""),
  nombre_distinto: (c) => (c.dispositivo?.nombre_equipo ? `: ${c.dispositivo.nombre_equipo}` : ""),
};

const pistaHTML = (k, extra = "") => {
  const p = PISTAS[k];
  return p ? `<span class="pista pista--${p.clase}" title="${esc(p.ayuda + extra)}">${esc(p.texto)}</span>` : "";
};
function pistasHTML(c, { solo } = {}) {
  const lista = c.pistas.filter((k) => k !== "virtual" || !c.parece).filter((k) => !solo || PISTAS[k]?.clase === solo);
  const parece = c.parece && !solo ? `<span class="pista pista--neutra" title="Por el nombre del equipo">Parece ${esc(c.parece)}</span>` : "";
  return `<span class="pistas">${lista.map((k) => pistaHTML(k, EXTRA_PISTA[k]?.(c) || "")).join("")}${parece}</span>`;
}
const malas = (c) => c.pistas.filter((k) => PISTAS[k]?.clase === "mala").length;
const expiraTexto = (c) => (c.tipo === "Reserva DHCP activa" ? "Reserva activa" : c.tipo === "Reserva DHCP inactiva" ? "Reserva inactiva"
  : c.expira ? fechaLog(c.expira) : c.tipo || "—");
// tipo: el que parece por su nombre (IMPRESORA, CELULAR…) para elegirlo de una vez
const rutaRegistrarDhcp = (c) => `#/red/dispositivos/nuevo?${new URLSearchParams(
  Object.entries({ ip: c.ip, mac: c.mac, equipo: c.nombre_corto, tipo: c.tipo_sugerido }).filter(([, v]) => v))}`;

export async function vistaIntrusos(cont, _params, ctx, impDirecta = null) {
  ctx.migas(impDirecta ? [{ texto: "Importaciones", href: "#/logs/importaciones" }, { texto: impDirecta.nombre_archivo }] : [{ texto: "Intrusos en la red" }]);
  const [listas, listados] = await Promise.all([
    api("logs/importaciones/", { query: { fuente: "DHCP" } }),
    api("logs/importaciones/", { query: { fuente: "MICROCLAUDIA" } }),
  ]);
  if (!ctx.vigente()) return;
  const encabezado = `
    <div class="encabezado">
      <div class="encabezado-imp">
        <span class="insignia-log insignia-log--dhcp">${icono("intruso")}</span>
        <div><h1>Intrusos en la red</h1>
          <p>Las direcciones que entregó el servidor DHCP, comparadas por su MAC y su nombre con los equipos registrados en el sistema
            (Equipos municipales). Lo que no está registrado y no tiene ninguna señal de ser de la municipalidad es un posible intruso.</p></div>
      </div>
      <div class="encabezado__acciones">
        <a class="btn btn--secundario" href="#/logs/importar/dhcp">${icono("subir")}Importar DHCP</a>
        <a class="btn btn--secundario" data-explorar hidden>${icono("filtro")}Explorar concesiones</a>
        <button type="button" class="btn btn--secundario" data-exportar-intrusos hidden>${icono("descargar")}Exportar (CSV)</button>
        ${impDirecta ? `<button type="button" class="btn-icono" data-editar title="Editar descripción" aria-label="Editar descripción">${icono("editar")}</button>
        <button type="button" class="btn-icono btn-icono--peligro" data-eliminar title="Eliminar importación" aria-label="Eliminar importación">${icono("borrar")}</button>` : ""}
      </div>
    </div>`;
  if (!listas.length) {
    cont.innerHTML = `${encabezado}<section class="panel">${vacioHTML({
      icono: "dhcp", titulo: "Todavía no hay una lista del DHCP",
      texto: "Importe las concesiones del servidor DHCP para comparar cada MAC con los equipos registrados en el sistema.",
      boton: `<a class="btn btn--primario" href="#/logs/importar/dhcp">${icono("subir")}Importar concesiones del DHCP</a>`,
    })}</section>`;
    return;
  }
  const pedido = impDirecta ? impDirecta.id_importacion : Number(ctx.query.get("dhcp"));
  let dhcp = listas.some((x) => x.id_importacion === pedido) ? pedido : listas[0].id_importacion;
  const pedidoAg = ctx.query.get("agentes");
  let agentes = pedidoAg === "0" ? 0 : listados.some((x) => x.id_importacion === Number(pedidoAg)) ? Number(pedidoAg) : listados[0]?.id_importacion || 0;
  const nueva = impDirecta ? recienImportadas.get(dhcp) : null;
  if (nueva) recienImportadas.delete(dhcp);
  const avisos = nueva?.avisos_detalle || [];

  cont.innerHTML = `${encabezado}
    ${nueva ? `
      <div class="aviso aviso--exito">${icono("check")}<div><strong>Importación lista: ${unidades("DHCP", nueva.total_eventos)} guardadas.</strong>
        ${nueva.repetidos ? ` ${num(nueva.repetidos)} filas estaban repetidas y se guardaron una sola vez.` : ""}
        ${avisos.length ? `<details class="avisos-imp"><summary>${num(nueva.avisos)} filas tuvieron avisos</summary><ul>${avisos.map((a) => `<li>${esc(a)}</li>`).join("")}</ul></details>` : ""}
      </div></div>` : ""}
    <section class="panel panel--filtro">
      <div class="cobertura-controles">
        <div class="campo"><label for="in-dhcp">Lista del DHCP</label>
          <select id="in-dhcp" class="control">${listas.map((x) => `<option value="${x.id_importacion}"${x.id_importacion === dhcp ? " selected" : ""}>
            N.º ${x.id_importacion} · ${esc(x.nombre_archivo)} · ${esc(unidades(x.fuente, x.total_eventos))} · ${esc(fecha(x.creado_en))}</option>`).join("")}</select></div>
        <div class="campo"><label for="in-agentes">Listado de Microclaudia <span class="etiqueta-nota">(señal de equipo municipal)</span></label>
          <select id="in-agentes" class="control"><option value="0"${agentes ? "" : " selected"}>Sin listado</option>${listados.map((x) => `<option value="${x.id_importacion}"${x.id_importacion === agentes ? " selected" : ""}>
            N.º ${x.id_importacion} · ${esc(x.nombre_archivo)} · ${esc(unidades(x.fuente, x.total_eventos))}</option>`).join("")}</select></div>
      </div>
    </section>
    <div data-intrusos>${cargandoHTML("Comparando con el inventario…")}</div>`;

  const caja = cont.querySelector("[data-intrusos]");
  const botonExportar = cont.querySelector("[data-exportar-intrusos]");
  const explorar = cont.querySelector("[data-explorar]");
  let datos = null;
  let consulta = 0;
  let buscado = "";
  let todos = false;

  const celdaMac = (c) => (c.mac ? `<span class="dato-mono">${esc(macGuiones(c.mac))}</span>` : `<span class="sin-dato">—</span>`);
  const celdaNombre = (c) => `<strong>${esc(c.nombre || "Sin nombre")}</strong>${c.descripcion ? `<span class="secundario">${esc(c.descripcion)}</span>` : ""}`;
  const celdaDispositivo = (d) => `<a href="#/red/dispositivos/${d.id_disp}"><strong>${esc(d.equipo || `Dispositivo N.º ${d.id_disp}`)}</strong></a>
    <span class="secundario">${esc([d.tipo, d.edificio].filter(Boolean).join(" · "))}</span>`;
  const fila = (c, columnas) => `<tr class="clicable${c.presente ? "" : " fila-ausente"}" data-evento="${c.id_evento}" tabindex="0">${columnas.map((f) => f(c)).join("")}</tr>`;
  const colIp = (c) => `<td class="dato-mono">${esc(c.ip || "—")}</td>`;
  const colMac = (c) => `<td class="col-mac">${celdaMac(c)}</td>`;
  const colNombre = (c) => `<td>${celdaNombre(c)}</td>`;
  const colExpira = (c) => `<td class="col-opcional col-fecha"><span class="${c.presente ? "" : "sin-dato"}">${esc(expiraTexto(c))}</span></td>`;
  // Si se llama como un equipo registrado, lo más probable es que sea otra tarjeta de red de ese equipo:
  // «Agregar MAC» la suma a ese equipo (con confirmación) y el ícono abre su ficha
  const colRegistrar = (c) => `<td class="col-acciones">${!c.mac ? ""
    : c.mismo_nombre ? `<span class="acciones-concesion"><button type="button" class="btn btn--secundario btn--sm" data-agregar-mac="${c.id_evento}"
        title="Agregar esta MAC a ${esc(c.mismo_nombre.equipo || "ese equipo")}">${icono("mas")}Agregar MAC</button><a class="btn-icono" href="#/red/dispositivos/${c.mismo_nombre.id_disp}"
        title="Ver la ficha de ${esc(c.mismo_nombre.equipo || "ese equipo")}" aria-label="Ver la ficha de ${esc(c.mismo_nombre.equipo || "ese equipo")}">${icono("red")}</a></span>`
      : `<a class="btn btn--secundario btn--sm" href="${rutaRegistrarDhcp(c)}">${icono("mas")}Registrar</a>`}</td>`;

  const tablaMunicipales = (lista) => {
    const t = buscado.trim().toLowerCase().replace(/[:-]/g, "");
    const filtrada = !t ? lista : lista.filter((c) => [c.ip, c.mac, c.nombre, c.descripcion, c.agente?.nombre]
      .some((v) => String(v || "").toLowerCase().replace(/[:-]/g, "").includes(t)));
    const vista = todos ? filtrada : filtrada.slice(0, 25);
    if (!filtrada.length) return `<p class="top-vacio">${lista.length ? "Ninguna concesión coincide con la búsqueda." : "Todos los equipos municipales que aparecen en el DHCP están registrados."}</p>`;
    return `<div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--equipos">
      <thead><tr><th>IP</th><th>MAC</th><th>Nombre en el DHCP</th><th>Por qué parece municipal</th><th class="col-opcional">Expira</th><th class="col-acciones"></th></tr></thead>
      <tbody>${vista.map((c) => fila(c, [colIp, colMac, colNombre, (x) => `<td>${pistasHTML(x)}</td>`, colExpira, colRegistrar])).join("")}</tbody></table></div>
      ${filtrada.length > vista.length ? `<div class="mas-filas"><button type="button" class="btn btn--secundario btn--sm" data-mas-municipales>Mostrar las ${num(filtrada.length)} concesiones</button>
        <span>Se ven ${num(vista.length)} de ${num(filtrada.length)}.</span></div>` : ""}`;
  };

  const pintar = () => {
    const d = datos;
    const tt = d.totales;
    const grupo = (estado) => d.concesiones.filter((c) => c.estado === estado);
    const intrusos = grupo("intruso").sort((a, b) => malas(b) - malas(a) || Number(b.presente) - Number(a.presente));
    const inactivos = grupo("inactivo");
    const municipales = grupo("municipal");
    const registrados = grupo("registrado");
    const sinMac = grupo("sin_mac");
    const imp = d.importacion;
    const cifra = (valor, texto, extra = "", clase = "") => `<div class="cifra${clase ? ` ${clase}` : ""}"><b>${valor}</b><span>${esc(texto)}</span>${extra}</div>`;
    const medidor = medidorPartes(Object.entries(ESTADOS_INTRUSOS).filter(([k]) => tt[k] || ["intruso", "municipal", "registrado"].includes(k))
      .map(([k, e]) => ({ texto: e.texto, cantidad: tt[k], clase: e.clase })), "Concesiones");
    const p = tt.pistas || {};
    explorar.hidden = false;
    explorar.href = rutaLogs("eventos", { importaciones: [imp.id_importacion] });

    caja.innerHTML = `
      <div class="cifras">
        <div class="cifra cifra--principal cifra--intruso${tt.intruso ? "" : " cifra--intruso-cero"}"><span>Posibles intrusos</span><b>${num(tt.intruso)}</b>
          <small>${tt.intruso ? "MAC sin registrar y sin ninguna señal de ser de la municipalidad" : "Toda MAC del DHCP está registrada o tiene una señal de ser municipal"}</small></div>
        <div class="cifra cifra--medidor"><span>Concesiones y reservas del DHCP</span>${medidor}</div>
      </div>
      <div class="cifras cifras--chicas">
        ${cifra(num(tt.presentes), "Conectadas", `<small>${num(tt.reservas_activas)} reservas activas · ${num(tt.reservas_inactivas)} inactivas</small>`)}
        ${cifra(num(tt.registrado), "Registradas en el inventario", tt.ip_distinta ? `<small>${num(tt.ip_distinta)} con otra IP que la registrada</small>` : "", "cifra--ok")}
        ${cifra(num(tt.municipal), "Municipales sin registrar", "<small>Agente, dominio, reserva o nombre del inventario</small>", tt.municipal ? "cifra--aviso" : "")}
        ${cifra(num(p.aleatoria || 0), "Con MAC aleatoria", "<small>Celulares y portátiles personales</small>", p.aleatoria ? "cifra--sin" : "")}
        ${cifra(num(p.ip_de_otro || 0), "Con la IP de otro equipo", "<small>Registrada a otro dispositivo</small>", p.ip_de_otro ? "cifra--aviso" : "")}
        ${cifra(num(tt.no_vistos), "Registrados que no aparecen", `<small>de ${num(tt.inventario_con_mac)} activos con MAC</small>`)}
      </div>
      <p class="nota-cobertura">${icono("enlace", "ic--sm")}<span>Lista: <a href="${rutaLogs("eventos", { importaciones: [imp.id_importacion] })}">${esc(imp.nombre_archivo)}</a>
        (${esc(unidades(imp.fuente, imp.total_eventos))}, importada el ${esc(fecha(imp.creado_en))}).
        ${d.dominio ? `Dominio de la red: <strong>${esc(d.dominio)}</strong>.` : "Ningún nombre trae el dominio de la red."}
        ${d.agentes ? `Microclaudia: <a href="#/logs/importaciones/${d.agentes.id_importacion}">${esc(d.agentes.nombre_archivo)}</a>.` : "Sin listado de Microclaudia."}
        ${d.anterior ? `Las MAC que no estaban en la lista anterior (N.º ${d.anterior.id_importacion}) se marcan como nuevas.` : ""}</span></p>

      <section class="panel panel--intrusos">
        <div class="panel__cabeza"><div><h2>${icono("intruso")} Posibles intrusos (${num(intrusos.length)})</h2>
          <p>${esc(["Su MAC no está registrada en el sistema", d.dominio && `su nombre no es del dominio ${d.dominio}`, "no es una reserva del DHCP",
            d.agentes && "no tiene el agente de Microclaudia"].filter(Boolean).join(", ").replace(/, ([^,]+)$/, " y $1"))}.
            Revise primero los que tienen más señales en rojo.</p></div></div>
        ${intrusos.length ? `<div class="tabla-envoltura"><table class="tabla tabla--compacta tabla--equipos">
          <thead><tr><th>IP</th><th>MAC</th><th>Nombre en el DHCP</th><th>Señales</th><th class="col-opcional">Expira</th><th class="col-acciones"></th></tr></thead>
          <tbody>${intrusos.map((c) => fila(c, [colIp, colMac, colNombre, (x) => `<td>${pistasHTML(x)}</td>`, colExpira, colRegistrar])).join("")}</tbody></table></div>`
          : `<div class="panel__cuerpo"><p class="cobertura-resumen__ok">${icono("check")}<span>Ninguna concesión es un posible intruso.</span></p></div>`}
      </section>

      ${inactivos.length ? `
      <section class="panel panel--sin-agente">
        <div class="panel__cabeza"><div><h2>${icono("alerta")} Registrados como inactivos que están en la red (${num(inactivos.length)})</h2>
          <p>Su MAC es de un dispositivo marcado como inactivo (dado de baja), pero recibió una IP del DHCP.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Dispositivo registrado</th><th>IP entregada</th><th>MAC</th><th>Nombre en el DHCP</th><th class="col-opcional">Expira</th></tr></thead>
          <tbody>${inactivos.map((c) => fila(c, [(x) => `<td>${celdaDispositivo(x.dispositivo)}</td>`, colIp, colMac, colNombre, colExpira])).join("")}</tbody></table></div>
      </section>` : ""}

      <section class="panel panel--revisar" data-municipales>
        <div class="panel__cabeza"><div><h2>${icono("red")} Municipales sin registrar (${num(municipales.length)})</h2>
          <p>No están en el inventario, pero tienen el agente, son del dominio, tienen una reserva o se llaman como un equipo registrado.
            <strong>Registrar</strong> abre el formulario con su IP y su MAC; <strong>Agregar MAC</strong> suma la MAC al equipo registrado que se llama igual.</p></div>
          ${municipales.length ? `<div class="buscador buscador--equipos">${icono("buscar")}<input type="search" class="control" data-buscar-municipal value="${esc(buscado)}" placeholder="Nombre, IP o MAC" aria-label="Buscar en los municipales sin registrar"></div>` : ""}</div>
        <div data-tabla-municipales>${tablaMunicipales(municipales)}</div>
      </section>

      ${sinMac.length ? `
      <section class="panel">
        <div class="panel__cabeza"><div><h2>${icono("alerta")} Sin MAC (${num(sinMac.length)})</h2>
          <p>Del Id. exclusivo no se pudo sacar una MAC, así que no se pueden comparar con el inventario.</p></div></div>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>IP</th><th>Nombre en el DHCP</th><th>Id. exclusivo</th><th class="col-opcional">Expira</th></tr></thead>
          <tbody>${sinMac.map((c) => fila(c, [colIp, colNombre, (x) => `<td class="dato-mono">${esc(x.id_exclusivo || "—")}</td>`, colExpira])).join("")}</tbody></table></div>
      </section>` : ""}

      ${registrados.length ? `
      <details class="panel panel--plegable">
        <summary class="panel__cabeza"><div><h2>${icono("check")} Registrados en el inventario (${num(registrados.length)})</h2>
          <p>Su MAC es de un dispositivo activo registrado en el sistema.</p></div></summary>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Dispositivo registrado</th><th>IP entregada</th><th>MAC</th><th class="col-opcional">Nombre en el DHCP</th></tr></thead>
          <tbody>${registrados.map((c) => fila(c, [(x) => `<td>${celdaDispositivo(x.dispositivo)}</td>`,
            (x) => `<td><span class="dato-mono">${esc(x.ip)}</span>${x.ip_distinta ? `<span class="secundario" title="IP registradas: ${esc(x.dispositivo.ips.join(", "))}">Registrada: ${esc(x.dispositivo.ips.join(", "))}</span>` : ""}</td>`,
            colMac, (x) => `<td class="col-opcional">${celdaNombre(x)}</td>`])).join("")}</tbody></table></div>
      </details>` : ""}

      ${d.no_vistos.length ? `
      <details class="panel panel--plegable">
        <summary class="panel__cabeza"><div><h2>${icono("red")} Registrados que no aparecen en el DHCP (${num(d.no_vistos.length)})</h2>
          <p>Dispositivos activos con MAC registrada que no recibieron IP de este DHCP: tienen IP fija, estaban apagados, están en otra red
            o su MAC registrada no es la de la tarjeta que usan.</p></div></summary>
        <div class="tabla-envoltura"><table class="tabla tabla--compacta">
          <thead><tr><th>Dispositivo registrado</th><th>IP y MAC registradas</th><th class="col-acciones"></th></tr></thead>
          <tbody>${d.no_vistos.map((x) => `<tr><td>${celdaDispositivo(x)}</td><td class="dato-mono col-mac">${direccionesHTML(x.ips, x.macs)}</td>
            <td class="col-acciones"><a class="btn btn--secundario btn--sm" href="#/red/dispositivos/${x.id_disp}">${icono("red")}Ficha</a></td></tr>`).join("")}</tbody></table></div>
      </details>` : ""}`;
    activarGlobos(caja);
    botonExportar.hidden = false;
  };

  const cargar = async () => {
    const yo = ++consulta;
    caja.classList.add("cargando-suave");
    try {
      const d = await api("logs/intrusos/", { query: { dhcp, agentes } });
      if (!ctx.vigente() || yo !== consulta) return;
      datos = d;
      todos = false;
      pintar();
    } catch (e) {
      if (!ctx.vigente() || yo !== consulta) return;
      caja.innerHTML = errorHTML(e.message);
    } finally {
      caja.classList.remove("cargando-suave");
    }
  };
  const actualizarRuta = () => reemplazarRuta(rutaLogs("intrusos", { dhcp, agentes: agentes || "0" }));

  cont.querySelector("#in-dhcp").addEventListener("change", (ev) => { dhcp = Number(ev.target.value); actualizarRuta(); cargar(); });
  cont.querySelector("#in-agentes").addEventListener("change", (ev) => { agentes = Number(ev.target.value); actualizarRuta(); cargar(); });
  caja.addEventListener("input", debounce((ev) => {
    if (!ev.target.matches("[data-buscar-municipal]") || !datos) return;
    buscado = ev.target.value;
    caja.querySelector("[data-tabla-municipales]").innerHTML = tablaMunicipales(datos.concesiones.filter((c) => c.estado === "municipal"));
  }, 200));
  const abrir = (tr) => abrirEvento(Number(tr.dataset.evento), { importaciones: [dhcp] });
  const agregarMac = async (c) => {
    const eq = c.mismo_nombre;
    const nombre = eq.equipo || `Dispositivo N.º ${eq.id_disp}`;
    const ok = await confirmar({
      titulo: "Agregar la MAC al equipo registrado",
      mensaje: `La concesión «${c.nombre || c.ip}» se llama como ${nombre}${eq.nombre_equipo ? ` (${eq.nombre_equipo})` : ""}: lo más probable es que sea `
        + `otra tarjeta de red de ese equipo, por ejemplo la Wi-Fi. Se agregará la MAC ${macGuiones(c.mac)} a sus direcciones.`,
      textoBoton: "Agregar MAC", peligro: false,
      accion: () => api(`dispositivos/${eq.id_disp}/macs/`, { metodo: "POST", datos: { direccion_mac: c.mac } }),
    });
    if (ok) { toast(`Se agregó la MAC ${macGuiones(c.mac)} a ${nombre}.`); cargar(); }
  };
  caja.addEventListener("click", (ev) => {
    const agregar = ev.target.closest("[data-agregar-mac]");
    if (agregar) {
      const c = datos?.concesiones.find((x) => x.id_evento === Number(agregar.dataset.agregarMac));
      if (c?.mismo_nombre) agregarMac(c);
      return;
    }
    if (ev.target.closest("[data-mas-municipales]")) {
      todos = true;
      caja.querySelector("[data-tabla-municipales]").innerHTML = tablaMunicipales(datos.concesiones.filter((c) => c.estado === "municipal"));
      return;
    }
    const tr = ev.target.closest("tr[data-evento]");
    if (tr && !ev.target.closest("a")) abrir(tr);
  });
  caja.addEventListener("keydown", (ev) => {
    const tr = ev.target.closest?.("tr[data-evento]");
    if (tr && ev.target === tr && (ev.key === "Enter" || ev.key === " ")) { ev.preventDefault(); abrir(tr); }
  });
  botonExportar.addEventListener("click", () => {
    if (!datos) return;
    const celda = celdaCsv;   // con protección contra fórmulas de Excel
    const filas = [["Estado", "IP", "MAC", "Nombre en el DHCP", "Descripción", "Tipo", "Expira", "Señales", "Parece",
      "Dispositivo registrado", "IP registradas", "Equipo en Microclaudia", "Equipo registrado con el mismo nombre"]];
    for (const c of datos.concesiones) {
      filas.push([datos.estados?.[c.estado] || c.estado, c.ip, macGuiones(c.mac || ""), c.nombre || "", c.descripcion || "",
        c.tipo, c.expira ? fechaLog(c.expira) : "", c.pistas.map((k) => PISTAS[k]?.texto || k).join(", "), c.parece || "",
        c.dispositivo?.equipo || "", c.dispositivo?.ips.join(" ") || "", c.agente?.nombre || "", c.mismo_nombre?.equipo || ""]);
    }
    for (const x of datos.no_vistos) {
      filas.push(["Registrado que no aparece en el DHCP", x.ips.join(" "), x.macs.map(macGuiones).join(" "), "", "", "", "", "", "", x.equipo || "", x.ips.join(" "), "", ""]);
    }
    descargarTexto(`﻿${filas.map((f) => f.map(celda).join(";")).join("\r\n")}\r\n`, `intrusos_dhcp_${marcaArchivo()}.csv`);
    toast("Se descargó el archivo.");
  });
  if (impDirecta) {
    cont.querySelector("[data-editar]").addEventListener("click", async () => {
      if (await editarDescripcion(impDirecta)) vistaImportacion(cont, [impDirecta.id_importacion], ctx);
    });
    cont.querySelector("[data-eliminar]").addEventListener("click", async () => {
      if (await eliminarImportacion(impDirecta)) location.hash = "#/logs/importaciones";
    });
  }
  await cargar();
}
