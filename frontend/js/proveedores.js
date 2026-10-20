// Proveedores: lista, registro (con contactos y documentos) y ficha con pestañas.
// Se guardan en la misma tabla que los usuarios, pero no inician sesión.
import { api, ErrorApi, ruta } from "./api.js";
import {
  avatarHTML, botonCargando, cargandoHTML, confirmar, debounce, errorHTML, esc, eventoFila, fecha,
  formatearTelefono, icono, leerCampos, limpiarErrores, mostrarErrores, nombreCompleto, tablaHTML, toast,
  urlApi, vacioHTML,
} from "./ui.js";
import { opcionesCatalogo } from "./datos.js";
import {
  camposUbicacion, contactosHTML, enlazarConsultaCedula, enlazarContactos, enlazarUbicacion, guardarContactos, leerContactos,
  pastillaEstado, pestanaContactos, precisarDuplicado, seccionesHTML, todosLosCampos,
} from "./usuarios.js";
import { pestanaHistorialProveedor } from "./auditoria.js";
import { abrirVisor, abrirVistaPrevia, zoomAlPasar } from "./zoom.js";

const RECURSO = "proveedores";

/* ------------------------------------------------------- Documentos */
const DOCUMENTOS = {
  imagen: {
    titulo: "Imagen", campo: "imagen_path", icono: "imagen",
    extensiones: [".jpg", ".jpeg", ".png", ".webp"], maxMb: 5,
    ayuda: "Logo o fotografía. JPG, PNG o WEBP, hasta 5 MB.",
    vacio: "Sin imagen",
  },
  catalogo: {
    titulo: "Catálogo de servicios", campo: "archivo_path", icono: "documento",
    extensiones: [".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx"], maxMb: 20,
    ayuda: "PDF, Word, Excel o PowerPoint, hasta 20 MB.",
    vacio: "Sin catálogo",
  },
};

const nombreArchivo = (rutaGuardada) => (rutaGuardada || "").split("/").pop();
const extension = (nombre) => (nombre.match(/\.[^.]+$/)?.[0] || "").toLowerCase();

function validarArchivo(tipo, archivo) {
  const def = DOCUMENTOS[tipo];
  if (!def.extensiones.includes(extension(archivo.name))) {
    return `Formato no permitido. Use: ${def.extensiones.map((e) => e.slice(1)).join(", ")}.`;
  }
  if (archivo.size > def.maxMb * 1024 * 1024) return `El archivo pesa más de ${def.maxMb} MB.`;
  return null;
}

function subirArchivo(id, tipo, archivo) {
  const datos = new FormData();
  datos.append("archivo", archivo);
  return api(ruta(RECURSO, id, tipo), { metodo: "POST", formulario: datos });
}

async function descargarCatalogo(p) {
  const blob = await api(ruta(RECURSO, p.id, "catalogo"), { comoArchivo: true });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nombreArchivo(p.archivo_path);
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}


/* --------------------------------------------------------- Mapa */
const PAR = /(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)/;

/** Mismas reglas que el servidor: "lat, lng" o un enlace de Google Maps que las incluya. */
function coordenadas(texto) {
  const t = (texto || "").trim();
  if (!t) return null;
  let m;
  if (/^https?:\/\//i.test(t)) {
    let decodificado = t;
    try { decodificado = decodeURIComponent(t); } catch { /* se usa tal cual */ }
    m = decodificado.match(new RegExp(`(?:@|[?&](?:q|query|ll|center|destination)=)${PAR.source}`));
  } else {
    m = t.match(new RegExp(`^${PAR.source}$`));
  }
  if (!m) return null;
  const lat = Number(m[1]);
  const lng = Number(m[2]);
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  return { lat, lng, texto: `${lat},${lng}` };
}

const enlaceMaps = (c) => `https://www.google.com/maps?q=${encodeURIComponent(c.texto)}`;
const embebidoMaps = (c) => `https://maps.google.com/maps?q=${encodeURIComponent(c.texto)}&z=16&output=embed`;

/** Muestra debajo del campo "mapa" un enlace para comprobar la ubicación. */
function enlazarCampoMapa(form) {
  const input = form.elements.namedItem("mapa");
  if (!input) return;
  const contenedor = input.closest(".campo");
  const enlace = document.createElement("a");
  enlace.className = "enlace-mapa";
  enlace.target = "_blank";
  enlace.rel = "noopener noreferrer";
  enlace.innerHTML = `${icono("externo", "ic--sm")}<span>Comprobar en Google Maps</span>`;
  contenedor.querySelector(".ayuda")?.after(enlace);
  const actualizar = () => {
    const c = coordenadas(input.value);
    enlace.hidden = !c;
    if (c) enlace.href = enlaceMaps(c);
  };
  input.addEventListener("input", actualizar);
  actualizar();
}

/* =====================================================================
   Lista
   ===================================================================== */
export async function vistaProveedores(cont, _params, ctx) {
  ctx.migas([{ texto: "Proveedores" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Proveedores</h1>
        <p>Empresas y personas que ofrecen bienes o servicios a la municipalidad. No tienen acceso al sistema.</p>
      </div>
      ${ctx.esAdmin ? `<div class="encabezado__acciones"><a class="btn btn--primario" href="#/proveedores/nuevo">${icono("mas")}Nuevo proveedor</a></div>` : ""}
    </div>
    <section class="panel">
      <form class="filtros" role="search" id="filtros-proveedores">
        <div class="campo campo--buscar">
          <label for="p-buscar">Buscar</label>
          <div class="buscador">${icono("buscar")}<input id="p-buscar" name="buscar" type="search" placeholder="Nombre, razón social o identificación" autocomplete="off"></div>
        </div>
        <div class="campo campo--ancho"><label for="p-categoria">Categoría</label><select id="p-categoria" name="cod_categoria"><option value="">Todas</option></select></div>
        <div class="campo">
          <label for="p-activo">Estado</label>
          <select id="p-activo" name="activo">
            <option value="true">Activos</option><option value="false">Inactivos</option><option value="">Todos</option>
          </select>
        </div>
        <span class="filtros__total" id="total-proveedores" aria-live="polite"></span>
      </form>
      <div id="lista-proveedores">${cargandoHTML()}</div>
    </section>`;

  const form = cont.querySelector("#filtros-proveedores");
  const lista = cont.querySelector("#lista-proveedores");
  const total = cont.querySelector("#total-proveedores");
  let filas = [];

  const categorias = await opcionesCatalogo("categorias-proveedores");
  if (!ctx.vigente()) return;
  form.cod_categoria.insertAdjacentHTML("beforeend",
    categorias.map((o) => `<option value="${esc(o.valor)}">${esc(o.texto)}</option>`).join(""));

  let consulta = 0;
  async function cargar() {
    const esta = ++consulta;
    lista.innerHTML = cargandoHTML();
    try {
      filas = await api("proveedores/", {
        query: { buscar: form.buscar.value.trim(), activo: form.activo.value, cod_categoria: form.cod_categoria.value },
      });
    } catch (e) {
      if (esta === consulta) lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    if (esta !== consulta || !ctx.vigente()) return;
    total.textContent = `${filas.length} ${filas.length === 1 ? "proveedor" : "proveedores"}`;

    if (!filas.length) {
      const hayFiltros = form.buscar.value || form.cod_categoria.value;
      lista.innerHTML = vacioHTML({
        icono: "proveedor",
        titulo: hayFiltros ? "Ningún proveedor coincide con la búsqueda" : "No hay proveedores en este estado",
        texto: hayFiltros ? "Pruebe con otro nombre o quite los filtros." : "",
        boton: ctx.esAdmin && !hayFiltros ? `<a class="btn btn--primario" href="#/proveedores/nuevo">${icono("mas")}Registrar el primero</a>` : "",
      });
      return;
    }

    lista.innerHTML = tablaHTML({
      clicable: true,
      filas,
      columnas: [
        {
          titulo: "Proveedor",
          html: (p) => `<div class="persona">${avatarHTML(p, { logo: true })}<div>
            <a href="#/proveedores/${p.id}"><strong>${esc(nombreCompleto(p))}</strong></a>
            <span class="secundario">${esc(p.tipo_identificacion)} ${esc(p.dni)}</span></div></div>`,
        },
        { titulo: "Categoría", html: (p) => `<span class="texto-categoria">${esc(p.categoria)}</span>` },
        {
          titulo: "Contacto", clase: "col-opcional",
          html: (p) => (p.telefono_principal || p.correo_principal
            ? `${esc(formatearTelefono(p.telefono_principal))}<span class="secundario">${esc(p.correo_principal || "")}</span>`
            : `<span class="secundario">Sin contacto</span>`),
        },
        { titulo: "Estado", html: (p) => pastillaEstado(p.activo) },
      ],
    });
  }

  lista.addEventListener("click", (ev) => {
    const r = eventoFila(ev, filas);
    if (r && !ev.target.closest("a")) location.hash = `#/proveedores/${r.fila.id}`;
  });
  form.addEventListener("submit", (ev) => { ev.preventDefault(); cargar(); });
  form.buscar.addEventListener("input", debounce(cargar, 300));
  ["activo", "cod_categoria"].forEach((n) => form[n].addEventListener("change", cargar));

  await cargar();
}

/* =====================================================================
   Formulario (crear y editar)
   ===================================================================== */
async function definicionCampos() {
  const [tiposId, categorias] = await Promise.all([
    opcionesCatalogo("tipos-identificaciones"),
    opcionesCatalogo("categorias-proveedores"),
  ]);
  return [
    {
      titulo: "Identificación", icono: "cedula",
      texto: "Si es una empresa, escriba la razón social en Nombre y deje los apellidos vacíos.",
      campos: [
        { nombre: "cod_tipo_identificacion", etiqueta: "Tipo de identificación", tipo: "select", opciones: tiposId, requerido: true, entero: true },
        { nombre: "dni", etiqueta: "Número de identificación", requerido: true, max: 30, placeholder: "3101123456" },
        { nombre: "nombre", etiqueta: "Nombre o razón social", requerido: true, max: 150, completo: true },
        { nombre: "apellido1", etiqueta: "Primer apellido", max: 100 },
        { nombre: "apellido2", etiqueta: "Segundo apellido", max: 100 },
        { nombre: "cod_categoria", etiqueta: "Categoría", tipo: "select", opciones: categorias, requerido: true, entero: true, completo: true },
      ],
    },
    {
      titulo: "Ubicación", icono: "punto",
      texto: "Dirección del proveedor y su punto en el mapa.",
      campos: [
        ...camposUbicacion("Edificio, local, referencias"),
        {
          nombre: "mapa", etiqueta: "Ubicación en Google Maps", max: 2000, completo: true, placeholder: "10.0732, -84.3116", mayus: false,
          ayuda: "En Google Maps, haga clic derecho sobre el lugar y elija las coordenadas para copiarlas. También puede pegar el enlace del lugar.",
        },
      ],
    },
  ];
}

function validarMapaLocal(form) {
  const input = form.elements.namedItem("mapa");
  if (!input || !input.value.trim() || coordenadas(input.value)) return true;
  mostrarErrores(form, new ErrorApi("", 400, {
    mapa: "Escriba latitud y longitud separadas por coma (por ejemplo 10.0732, -84.3116) o pegue un enlace de Google Maps que las incluya.",
  }), form.querySelector("[data-error]"));
  return false;
}

/* =====================================================================
   Nuevo proveedor
   ===================================================================== */
const campoArchivoHTML = (tipo) => {
  const d = DOCUMENTOS[tipo];
  return `<div class="campo" data-campo="doc-${tipo}">
    <label for="doc-${tipo}">${esc(d.titulo)}</label>
    <input id="doc-${tipo}" type="file" class="control-archivo" accept="${d.extensiones.join(",")}">
    <p class="ayuda">${esc(d.ayuda)}</p>
    <button type="button" class="enlace-mapa" data-ver-local="${tipo}" hidden>${icono("buscar", "ic--sm")}<span>Vista previa</span></button>
    <p class="error-campo" hidden></p>
  </div>`;
};

export async function vistaProveedorNuevo(cont, _params, ctx) {
  ctx.migas([{ texto: "Proveedores", href: "#/proveedores" }, { texto: "Nuevo proveedor" }]);
  cont.innerHTML = cargandoHTML();

  const secciones = await definicionCampos();
  const contactos = await contactosHTML("proveedor");
  if (!ctx.vigente()) return;

  cont.innerHTML = `
    <a class="volver" href="#/proveedores">${icono("atras")}Volver a proveedores</a>
    <div class="encabezado"><div><h1>Nuevo proveedor</h1><p>Los campos con * son obligatorios. El proveedor no tendrá acceso al sistema.</p></div></div>
    <form class="panel" id="form-proveedor" novalidate>
      <div class="panel__cuerpo">
        <div data-error hidden style="margin-bottom:18px"></div>
        ${seccionesHTML(secciones, {}, false)}
        ${contactos.html}
        <section class="seccion-form">
          <h3>${icono("documento")}Documentos</h3>
          <p>Opcional. También se pueden subir después desde la ficha del proveedor.</p>
          <div class="rejilla">${campoArchivoHTML("imagen")}${campoArchivoHTML("catalogo")}</div>
        </section>
      </div>
      <div class="panel__pie">
        <a class="btn btn--secundario" href="#/proveedores">Cancelar</a>
        <button class="btn btn--primario" type="submit">${icono("check")}Registrar proveedor</button>
      </div>
    </form>`;

  const form = cont.querySelector("#form-proveedor");
  const caja = form.querySelector("[data-error]");
  const campos = todosLosCampos(secciones);
  enlazarContactos(form, contactos.tipos);
  enlazarCampoMapa(form);
  enlazarUbicacion(form);
  enlazarConsultaCedula(form);

  // Vista previa de los archivos elegidos, antes de guardarlos
  for (const tipo of Object.keys(DOCUMENTOS)) {
    const input = form.querySelector(`#doc-${tipo}`);
    const ver = form.querySelector(`[data-ver-local="${tipo}"]`);
    input.addEventListener("change", () => {
      const archivo = input.files[0];
      const ext = archivo ? extension(archivo.name) : "";
      ver.hidden = !archivo;
      ver.dataset.office = String(![".pdf", ".jpg", ".jpeg", ".png", ".webp"].includes(ext));
    });
    ver.addEventListener("click", () => {
      const archivo = input.files[0];
      if (!archivo) return;
      abrirVistaPrevia({
        titulo: DOCUMENTOS[tipo].titulo,
        nombre: archivo.name,
        obtener: async () => {
          if (ver.dataset.office === "true") {
            throw new Error("Word, Excel y PowerPoint se pueden ver después de registrar el proveedor, desde su pestaña Documentos.");
          }
          return archivo;
        },
      });
    });
  }

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity() || !validarMapaLocal(form)) return;

    // Revisa los archivos antes de crear nada
    const archivos = {};
    const erroresArchivo = {};
    for (const tipo of Object.keys(DOCUMENTOS)) {
      const archivo = form.querySelector(`#doc-${tipo}`).files[0];
      if (!archivo) continue;
      const problema = validarArchivo(tipo, archivo);
      if (problema) erroresArchivo[`doc-${tipo}`] = problema;
      else archivos[tipo] = archivo;
    }
    if (Object.keys(erroresArchivo).length) {
      mostrarErrores(form, new ErrorApi("", 400, erroresArchivo), caja);
      return;
    }

    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);

    let creado;
    try {
      creado = await api("proveedores/", { metodo: "POST", datos: leerCampos(form, campos) });
    } catch (e) {
      botonCargando(boton, false);
      if (e instanceof ErrorApi) mostrarErrores(form, precisarDuplicado(e, "proveedor"), caja);
      else throw e;
      caja.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }

    const fallos = await guardarContactos(RECURSO, creado.id, leerContactos(form));
    for (const [tipo, archivo] of Object.entries(archivos)) {
      try {
        await subirArchivo(creado.id, tipo, archivo);
      } catch (e) {
        fallos.push(`${DOCUMENTOS[tipo].titulo}: ${e.message}`);
      }
    }

    toast(`Se registró el proveedor ${nombreCompleto(creado)}.`);
    if (fallos.length) toast(`Algunos datos no se guardaron. ${fallos.join(" ")}`, "error");
    location.hash = `#/proveedores/${creado.id}`;
  });
}

/* =====================================================================
   Ficha del proveedor
   ===================================================================== */
const PESTANAS = [
  { clave: "datos", titulo: "Datos generales", icono: "proveedor" },
  { clave: "telefonos", titulo: "Teléfonos", icono: "telefono" },
  { clave: "correos", titulo: "Correos", icono: "correo" },
  { clave: "paginas-webs", titulo: "Páginas web", icono: "web" },
  { clave: "documentos", titulo: "Documentos", icono: "documento" },
  { clave: "historial", titulo: "Historial", icono: "historial", soloAdmin: true },
];

export async function vistaProveedor(cont, [id, pestanaInicial], ctx) {
  ctx.migas([{ texto: "Proveedores", href: "#/proveedores" }]);
  cont.innerHTML = cargandoHTML();

  const p = await api(ruta(RECURSO, id));
  if (!ctx.vigente()) return;
  ctx.migas([{ texto: "Proveedores", href: "#/proveedores" }, { texto: nombreCompleto(p) }]);

  const base = `#/proveedores/${p.id}`;
  const pestanas = PESTANAS.filter((t) => !t.soloAdmin || ctx.esAdmin);
  let actual = pestanas.find((t) => t.clave === pestanaInicial)?.clave || "datos";
  const recargar = (pestana = actual) => vistaProveedor(cont, [String(p.id), pestana], ctx);

  cont.innerHTML = `
    <a class="volver" href="#/proveedores">${icono("atras")}Volver a proveedores</a>
    <div class="ficha">
      ${p.imagen_url ? `<button type="button" class="ficha__ver-foto" data-ver-imagen aria-label="Ver imagen de ${esc(nombreCompleto(p))}">${avatarHTML(p, { tam: "grande", logo: true })}</button>` : avatarHTML(p, { tam: "grande", logo: true })}
      <div class="ficha__texto">
        <h1>${esc(nombreCompleto(p))}</h1>
        <div class="ficha__datos">
          ${pastillaEstado(p.activo)}
          <span>${esc(p.tipo_identificacion)} ${esc(p.dni)}</span>
          <span class="texto-categoria">${esc(p.categoria)}</span>
        </div>
      </div>
      <div class="ficha__acciones">
        ${ctx.esAdmin ? (p.activo
          ? `<button type="button" class="btn btn--secundario" data-estado>${icono("encender")}Desactivar</button>`
          : `<button type="button" class="btn btn--primario" data-estado>${icono("encender")}Activar</button>`) : ""}
      </div>
    </div>
    <div class="pestanas" role="tablist" aria-label="Información del proveedor">
      ${pestanas.map((t) => `<button type="button" role="tab" id="tab-${t.clave}" aria-controls="panel-pestana" data-pestana="${t.clave}" aria-selected="${t.clave === actual}">${icono(t.icono)}${esc(t.titulo)}</button>`).join("")}
    </div>
    <div id="panel-pestana" role="tabpanel"></div>`;

  cont.querySelector("[data-estado]")?.addEventListener("click", () => cambiarEstado(p, () => recargar()));
  cont.querySelector("[data-ver-imagen]")?.addEventListener("click", () => {
    abrirVisor(urlApi(p.imagen_url), { titulo: nombreCompleto(p), alt: `Imagen de ${nombreCompleto(p)}` });
  });

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
      if (clave === "datos") await pestanaDatos(caja, p, ctx, recargar);
      else if (clave === "documentos") await pestanaDocumentos(caja, p, ctx, recargar);
      else if (clave === "historial") await pestanaHistorialProveedor(caja, p);
      else await pestanaContactos(caja, p, clave, ctx, RECURSO);
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

async function cambiarEstado(p, alTerminar) {
  const nombre = nombreCompleto(p);
  if (p.activo) {
    const ok = await confirmar({
      titulo: "Desactivar proveedor",
      mensaje: `${nombre} dejará de aparecer entre los proveedores activos. Sus datos se conservan y se puede activar de nuevo.`,
      textoBoton: "Desactivar",
      accion: () => api(ruta(RECURSO, p.id), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se desactivó a ${nombre}.`); alTerminar(); }
    return;
  }
  try {
    await api(ruta(RECURSO, p.id, "activar"), { metodo: "POST" });
    toast(`Se activó a ${nombre}.`);
    alTerminar();
  } catch (e) {
    toast(e.message, "error");
  }
}

/* --------------------------------------------------------- Datos generales */
async function pestanaDatos(panel, p, ctx, recargar) {
  const secciones = await definicionCampos();
  const soloLectura = !ctx.esAdmin;
  const campos = todosLosCampos(secciones);
  const c = coordenadas(p.mapa);

  panel.innerHTML = `
    <form class="panel" novalidate>
      <div class="panel__cuerpo">
        ${soloLectura ? `<div class="aviso aviso--ocre" style="margin-bottom:18px">${icono("candado")}<span>Solo un administrador puede modificar estos datos.</span></div>` : ""}
        <div data-error hidden style="margin-bottom:18px"></div>
        ${seccionesHTML(secciones, p, soloLectura)}
        <section class="seccion-form">
          <h3>${icono("etiqueta")}Registro</h3>
          <dl class="lista-datos">
            <div><dt>Registrado</dt><dd>${esc(fecha(p.creado_en))}</dd></div>
            <div><dt>Última modificación</dt><dd>${esc(fecha(p.actualizado_en))}</dd></div>
          </dl>
        </section>
      </div>
      ${soloLectura ? "" : `<div class="panel__pie"><button type="submit" class="btn btn--primario">${icono("check")}Guardar cambios</button></div>`}
    </form>
    ${c ? `
    <section class="panel">
      <div class="panel__cabeza">
        <div><h2>Ubicación en el mapa</h2><p>${esc(c.texto)}</p></div>
        <a class="btn btn--secundario btn--sm" href="${esc(enlaceMaps(c))}" target="_blank" rel="noopener noreferrer">${icono("externo")}Abrir en Google Maps</a>
      </div>
      <iframe class="mapa" title="Ubicación de ${esc(nombreCompleto(p))}" src="${esc(embebidoMaps(c))}" loading="lazy" referrerpolicy="no-referrer-when-downgrade"></iframe>
    </section>` : ""}
    ${ctx.esAdmin ? `
    <section class="panel zona-riesgo">
      <div class="panel__cabeza"><h2>Acciones sobre el proveedor</h2></div>
      <div class="fila-riesgo">
        <div><strong>Eliminar definitivamente</strong>
          <p>Borra el proveedor con sus teléfonos, correos, páginas web, imagen y catálogo. No se puede deshacer. Si solo dejó de trabajar con la municipalidad, use Desactivar.</p></div>
        <button type="button" class="btn btn--peligro-suave" data-eliminar>${icono("borrar")}Eliminar proveedor</button>
      </div>
    </section>` : ""}`;

  const form = panel.querySelector("form");
  const caja = form.querySelector("[data-error]");
  enlazarUbicacion(form, { valores: p, bloqueado: soloLectura });

  panel.querySelector("[data-eliminar]")?.addEventListener("click", async () => {
    const nombre = nombreCompleto(p);
    const ok = await confirmar({
      titulo: "Eliminar proveedor definitivamente",
      mensaje: `Se borrarán ${nombre} y todos sus datos y documentos. Si solo quiere ocultarlo, use Desactivar.`,
      textoBoton: "Eliminar definitivamente",
      accion: () => api(ruta(RECURSO, p.id, "eliminar-fisico"), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se eliminó a ${nombre}.`); location.hash = "#/proveedores"; }
  });

  if (soloLectura) return;
  enlazarCampoMapa(form);

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity() || !validarMapaLocal(form)) return;
    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    try {
      await api(ruta(RECURSO, p.id), { metodo: "PUT", datos: { ...leerCampos(form, campos), activo: p.activo } });
      toast("Se guardaron los cambios.");
      recargar("datos");
    } catch (e) {
      botonCargando(boton, false);
      if (e instanceof ErrorApi) mostrarErrores(form, precisarDuplicado(e, "proveedor"), caja);
      else throw e;
    }
  });
}

/* --------------------------------------------------------------- Documentos */
async function pestanaDocumentos(panel, p, ctx, recargar) {
  const admin = ctx.esAdmin;

  const tarjeta = (tipo) => {
    const d = DOCUMENTOS[tipo];
    const rutaGuardada = p[d.campo];
    const nombre = nombreArchivo(rutaGuardada);
    const vista = tipo === "imagen"
      ? `<div class="documento__vista documento__vista--imagen">${p.imagen_url
        ? `<img alt="Imagen de ${esc(nombreCompleto(p))}" src="${esc(urlApi(p.imagen_url))}">`
        : `${icono("imagen")}<span>${esc(d.vacio)}</span>`}</div>`
      : `<div class="documento__vista">${icono("documento")}${rutaGuardada
        ? `<span class="documento__nombre">${esc(nombre)}</span><span class="documento__ext">${esc(extension(nombre).slice(1).toUpperCase())}</span>`
        : `<span>${esc(d.vacio)}</span>`}</div>`;

    const acciones = [];
    if (tipo === "catalogo" && rutaGuardada) {
      acciones.push(`<button type="button" class="btn btn--primario btn--sm" data-vista-previa>${icono("buscar")}Vista previa</button>`);
      acciones.push(`<button type="button" class="btn btn--secundario btn--sm" data-descargar>${icono("descargar")}Descargar</button>`);
    }
    if (admin) {
      acciones.push(`<label class="btn btn--secundario btn--sm boton-archivo">${icono("subir")}${rutaGuardada ? "Reemplazar" : "Subir"}
        <input type="file" accept="${d.extensiones.join(",")}" data-subir="${tipo}" class="visualmente-oculto"></label>`);
      if (rutaGuardada) acciones.push(`<button type="button" class="btn btn--fantasma btn--sm" data-quitar-doc="${tipo}">${icono("borrar")}Quitar</button>`);
    }

    return `
      <section class="panel documento" data-tipo="${tipo}">
        <div class="panel__cabeza"><div><h2>${esc(d.titulo)}</h2><p>${esc(d.ayuda)}</p></div></div>
        <div class="panel__cuerpo">
          ${vista}
          <div data-error-doc hidden style="margin-top:12px"></div>
          ${acciones.length ? `<div class="documento__acciones">${acciones.join("")}</div>` : ""}
        </div>
      </section>`;
  };

  panel.innerHTML = `<div class="documentos">${tarjeta("imagen")}${tarjeta("catalogo")}</div>`;

  const imagen = panel.querySelector(".documento__vista--imagen img");
  if (imagen) {
    zoomAlPasar(imagen);
    imagen.addEventListener("click", () => abrirVisor(imagen.src, { titulo: nombreCompleto(p), alt: imagen.alt }));
  }
  panel.querySelector(".documento__vista--imagen img")?.addEventListener("error", (ev) => {
    ev.target.closest(".documento__vista").innerHTML = `${icono("alerta")}<span>No se pudo cargar la imagen.</span>`;
  });

  panel.addEventListener("click", async (ev) => {
    if (ev.target.closest("[data-vista-previa]")) {
      abrirVistaPrevia({
        titulo: "Catálogo de servicios",
        nombre: nombreArchivo(p.archivo_path),
        obtener: () => api(ruta(RECURSO, p.id, "catalogo", "vista-previa"), { comoArchivo: true }),
        alDescargar: () => descargarCatalogo(p).catch((e) => toast(e.message, "error")),
      });
      return;
    }
    if (ev.target.closest("[data-descargar]")) {
      const boton = ev.target.closest("[data-descargar]");
      botonCargando(boton, true);
      try { await descargarCatalogo(p); } catch (e) { toast(e.message, "error"); }
      botonCargando(boton, false);
      return;
    }
    const quitar = ev.target.closest("[data-quitar-doc]");
    if (quitar) {
      const tipo = quitar.dataset.quitarDoc;
      const cual = tipo === "imagen" ? "la imagen" : "el catálogo de servicios";
      const ok = await confirmar({
        titulo: `Quitar ${DOCUMENTOS[tipo].titulo.toLowerCase()}`,
        mensaje: `Se borrará ${cual} de ${nombreCompleto(p)}.`,
        textoBoton: "Quitar",
        accion: () => api(ruta(RECURSO, p.id, tipo), { metodo: "DELETE" }),
      });
      if (ok) { toast(`Se quitó ${cual}.`); recargar("documentos"); }
    }
  });

  panel.addEventListener("change", async (ev) => {
    const input = ev.target.closest("[data-subir]");
    if (!input?.files[0]) return;
    const tipo = input.dataset.subir;
    const tarjetaEl = input.closest(".documento");
    const cajaError = tarjetaEl.querySelector("[data-error-doc]");
    const etiqueta = input.closest(".boton-archivo");
    cajaError.hidden = true;

    const problema = validarArchivo(tipo, input.files[0]);
    if (problema) {
      cajaError.innerHTML = errorHTML(problema);
      cajaError.hidden = false;
      input.value = "";
      return;
    }
    etiqueta.classList.add("cargando");
    try {
      await subirArchivo(p.id, tipo, input.files[0]);
      toast(tipo === "imagen" ? "Se guardó la imagen." : "Se guardó el catálogo de servicios.");
      recargar("documentos");
    } catch (e) {
      etiqueta.classList.remove("cargando");
      cajaError.innerHTML = errorHTML(e.message);
      cajaError.hidden = false;
      input.value = "";
    }
  });
}
