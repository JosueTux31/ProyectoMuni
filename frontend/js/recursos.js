// Pantallas de catálogos (cat_*) y de división territorial (geo_*).
import { api, ruta } from "./api.js";
import {
  abrirFormulario, botonesFila, cargandoHTML, confirmar, errorHTML, esc, eventoFila, icono,
  tablaHTML, toast, vacioHTML,
} from "./ui.js";
import { CATALOGOS, cascadaGeo, NIVELES_GEO, olvidarCatalogo, rutaGeo } from "./datos.js";

const normalizar = (s) => String(s ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

function encabezado({ titulo, descripcion, boton, admin }) {
  return `
    <div class="encabezado">
      <div><h1>${esc(titulo)}</h1><p>${esc(descripcion)}</p></div>
      ${admin ? `<div class="encabezado__acciones"><button type="button" class="btn btn--primario" data-agregar>${icono("mas")}${esc(boton)}</button></div>` : ""}
    </div>`;
}

const buscadorHTML = (placeholder) => `
  <div class="campo campo--buscar">
    <label for="f-buscar">Buscar</label>
    <div class="buscador">${icono("buscar")}<input id="f-buscar" type="search" placeholder="${esc(placeholder)}" autocomplete="off"></div>
  </div>`;

function noExiste(cont, ctx) {
  ctx.migas([{ texto: "No encontrado" }]);
  cont.innerHTML = `<section class="panel">${vacioHTML({ icono: "mapa", titulo: "Esta sección no existe", boton: `<a class="btn btn--secundario" href="#/inicio">Ir al inicio</a>` })}</section>`;
}

/* =====================================================================
   Catálogos
   ===================================================================== */
export async function vistaCatalogo(cont, [slug], ctx) {
  const def = CATALOGOS[slug];
  if (!def) return noExiste(cont, ctx);
  const admin = ctx.esAdmin;
  ctx.migas([{ texto: "Catálogos" }, { texto: def.titulo }]);

  cont.innerHTML = `
    ${encabezado({ titulo: def.titulo, descripcion: def.descripcion, boton: `Agregar ${def.singular}`, admin })}
    <section class="panel">
      <form class="filtros" role="search" onsubmit="return false">
        ${buscadorHTML("Buscar por descripción o código")}
        <span class="filtros__total" data-total aria-live="polite"></span>
      </form>
      <div data-lista>${cargandoHTML()}</div>
    </section>`;

  const lista = cont.querySelector("[data-lista]");
  const buscar = cont.querySelector("#f-buscar");
  const total = cont.querySelector("[data-total]");
  let filas = [];
  let visibles = [];

  function pintar() {
    const q = normalizar(buscar.value.trim());
    visibles = q ? filas.filter((f) => normalizar(`${f[def.llave]} ${f.descripcion}`).includes(q)) : filas;
    total.textContent = `${visibles.length} de ${filas.length}`;
    if (!visibles.length) {
      lista.innerHTML = vacioHTML({
        icono: def.icono,
        titulo: filas.length ? "Nada coincide con la búsqueda" : `Todavía no hay ${def.titulo.toLowerCase()}`,
        boton: admin && !filas.length ? `<button type="button" class="btn btn--primario" data-agregar>${icono("mas")}Agregar ${esc(def.singular)}</button>` : "",
      });
      return;
    }
    const columnas = [
      { titulo: "Código", clase: "col-codigo", html: (f) => esc(f[def.llave]) },
      { titulo: "Descripción", html: (f) => `<strong>${esc(f.descripcion)}</strong>` },
    ];
    if (admin) columnas.push({ titulo: "", clase: "col-acciones", html: (f) => botonesFila({ etiqueta: f.descripcion }) });
    lista.innerHTML = tablaHTML({ columnas, filas: visibles });
  }

  async function cargar() {
    try {
      filas = await api(`catalogos/${slug}/`);
    } catch (e) {
      lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    if (!ctx.vigente()) return;
    olvidarCatalogo(slug); // las demás pantallas tomarán la versión nueva
    pintar();
  }

  const campos = [{ nombre: "descripcion", etiqueta: "Descripción", requerido: true, max: def.max }];

  async function formulario(fila) {
    const r = await abrirFormulario({
      titulo: fila ? `Editar ${def.singular}` : `Agregar ${def.singular}`,
      campos,
      valores: fila || {},
      textoGuardar: fila ? "Guardar cambios" : "Agregar",
      alGuardar: (datos) => api(fila ? ruta(`catalogos/${slug}`, fila[def.llave]) : `catalogos/${slug}/`, {
        metodo: fila ? "PUT" : "POST", datos,
      }),
    });
    if (r) { toast(fila ? "Se guardaron los cambios." : `Se agregó «${r.descripcion}».`); await cargar(); }
  }

  cont.addEventListener("click", async (ev) => {
    if (ev.target.closest("[data-agregar]")) return formulario(null);
    const r = eventoFila(ev, visibles);
    if (!r?.accion) return;
    if (r.accion === "editar") return formulario(r.fila);
    const ok = await confirmar({
      titulo: `Eliminar ${def.singular}`,
      mensaje: `Se eliminará «${r.fila.descripcion}». Si algún usuario lo está usando, no se podrá eliminar.`,
      textoBoton: "Eliminar",
      accion: () => api(ruta(`catalogos/${slug}`, r.fila[def.llave]), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se eliminó «${r.fila.descripcion}».`); await cargar(); }
  });
  buscar.addEventListener("input", pintar);

  await cargar();
}

/* =====================================================================
   División territorial
   ===================================================================== */
const GEO = {
  paises: { titulo: "Países", singular: "país", descripcion: "Países disponibles para la dirección de los usuarios." },
  provincias: { titulo: "Provincias", singular: "provincia", descripcion: "Provincias de cada país." },
  cantones: { titulo: "Cantones", singular: "cantón", descripcion: "Cantones de cada provincia." },
  distritos: { titulo: "Distritos", singular: "distrito", descripcion: "Distritos de cada cantón con su código postal. Es el nivel que se asigna a cada usuario y proveedor." },
};

export async function vistaGeografia(cont, [slug], ctx) {
  const i = NIVELES_GEO.findIndex((n) => n.slug === slug);
  if (i < 0) return noExiste(cont, ctx);
  const nivel = NIVELES_GEO[i];
  const padres = NIVELES_GEO.slice(0, i);
  const padre = padres[padres.length - 1];
  const def = GEO[slug];
  const esDistrito = slug === "distritos";
  const admin = ctx.esAdmin;
  ctx.migas([{ texto: "Territorio" }, { texto: def.titulo }]);

  cont.innerHTML = `
    ${encabezado({ titulo: def.titulo, descripcion: def.descripcion, boton: `Agregar ${def.singular}`, admin })}
    <section class="panel">
      <form class="filtros" role="search" onsubmit="return false">
        ${padres.map((p) => `<div class="campo"><label for="filtro-${p.campo}">${esc(p.titulo)}</label><select id="filtro-${p.campo}" data-filtro="${p.campo}"></select></div>`).join("")}
        ${buscadorHTML("Buscar por nombre o código")}
        <span class="filtros__total" data-total aria-live="polite"></span>
      </form>
      <div data-lista>${cargandoHTML()}</div>
    </section>`;

  const lista = cont.querySelector("[data-lista]");
  const buscar = cont.querySelector("#f-buscar");
  const total = cont.querySelector("[data-total]");
  const filtros = [...cont.querySelectorAll("[data-filtro]")];
  const codigosDe = (f) => [...padres.map((p) => f[p.campo]), f[nivel.campo]];
  let filas = [];
  let visibles = [];
  let consulta = 0;

  function pintar() {
    const q = normalizar(buscar.value.trim());
    visibles = q ? filas.filter((f) => normalizar(`${f[nivel.campo]} ${f[nivel.nombre]}`).includes(q)) : filas;
    total.textContent = `${visibles.length} de ${filas.length}`;
    if (!visibles.length) {
      lista.innerHTML = vacioHTML({
        icono: "mapa",
        titulo: filas.length ? "Nada coincide con la búsqueda" : `No hay ${def.titulo.toLowerCase()} con estos filtros`,
        boton: admin && !filas.length ? `<button type="button" class="btn btn--primario" data-agregar>${icono("mas")}Agregar ${esc(def.singular)}</button>` : "",
      });
      return;
    }
    const columnas = [
      { titulo: "Código", clase: "col-codigo", html: (f) => esc(codigosDe(f).slice(1).join("-") || f[nivel.campo]) },
      { titulo: "Nombre", html: (f) => `<strong>${esc(f[nivel.nombre])}</strong>` },
    ];
    if (padre) columnas.push({ titulo: padre.titulo, html: (f) => esc(f[padre.nombre]) });
    if (esDistrito) columnas.push({ titulo: "Código postal", clase: "col-codigo", html: (f) => (f.codigo_postal ? esc(f.codigo_postal) : `<span class="secundario">—</span>`) });
    if (admin) columnas.push({ titulo: "", clase: "col-acciones", html: (f) => botonesFila({ etiqueta: f[nivel.nombre] }) });
    lista.innerHTML = tablaHTML({ columnas, filas: visibles });
  }

  async function cargar() {
    const esta = ++consulta;
    lista.innerHTML = cargandoHTML();
    const query = {};
    filtros.forEach((s) => { if (s.value) query[s.dataset.filtro] = s.value; });
    try {
      filas = await api(`geografia/${slug}/`, { query });
    } catch (e) {
      if (esta === consulta) lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    if (esta !== consulta || !ctx.vigente()) return;
    pintar();
  }

  async function formulario(fila) {
    const valoresFiltro = Object.fromEntries(filtros.map((s) => [s.dataset.filtro, s.value]));
    const campoPostal = esDistrito ? [{
      nombre: "codigo_postal", etiqueta: "Código postal", max: 10, placeholder: "20301",
      ayuda: fila ? "Si lo cambia, se actualiza en todos los usuarios y proveedores de este distrito."
        : "Si lo deja vacío se arma con provincia + cantón + distrito.",
    }] : [];
    const campos = fila
      ? [
        ...padres.map((p) => ({ nombre: p.campo, etiqueta: p.titulo, deshabilitado: true })),
        { nombre: nivel.campo, etiqueta: "Código", deshabilitado: true },
        { nombre: nivel.nombre, etiqueta: "Nombre", requerido: true, max: 100 },
        ...campoPostal,
      ]
      : [
        ...padres.map((p) => ({ nombre: p.campo, etiqueta: p.titulo, tipo: "select", requerido: true })),
        { nombre: nivel.campo, etiqueta: "Código", requerido: true, max: 10, ayuda: i === 0 ? "Por ejemplo CR." : "Código oficial, por ejemplo 01." },
        { nombre: nivel.nombre, etiqueta: "Nombre", requerido: true, max: 100 },
        ...campoPostal,
      ];

    const r = await abrirFormulario({
      titulo: fila ? `Editar ${def.singular}` : `Agregar ${def.singular}`,
      descripcion: fila ? "El código no se puede cambiar; si está mal, elimine el registro y créelo de nuevo." : "",
      campos,
      valores: fila ? { ...fila, ...Object.fromEntries(padres.map((p) => [p.campo, fila[p.campo]])) } : {},
      textoGuardar: fila ? "Guardar cambios" : "Agregar",
      alAbrir: fila || !padres.length ? null : (form) => cascadaGeo(padres.map((p) => form.elements.namedItem(p.campo)), { valores: valoresFiltro }),
      alGuardar: (datos) => (fila
        ? api(rutaGeo(slug, ...codigosDe(fila)), {
          metodo: "PUT",
          datos: { [nivel.nombre]: datos[nivel.nombre], ...(esDistrito ? { codigo_postal: datos.codigo_postal } : {}) },
        })
        : api(`geografia/${slug}/`, { metodo: "POST", datos })),
    });
    if (r) { toast(fila ? "Se guardaron los cambios." : `Se agregó ${r[nivel.nombre]}.`); await cargar(); }
  }

  cont.addEventListener("click", async (ev) => {
    if (ev.target.closest("[data-agregar]")) return formulario(null);
    const r = eventoFila(ev, visibles);
    if (!r?.accion) return;
    if (r.accion === "editar") return formulario(r.fila);
    const ok = await confirmar({
      titulo: `Eliminar ${def.singular}`,
      mensaje: `Se eliminará ${r.fila[nivel.nombre]}. Si tiene divisiones o usuarios asociados, no se podrá eliminar.`,
      textoBoton: "Eliminar",
      accion: () => api(rutaGeo(slug, ...codigosDe(r.fila)), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se eliminó ${r.fila[nivel.nombre]}.`); await cargar(); }
  });
  buscar.addEventListener("input", pintar);

  if (filtros.length) await cascadaGeo(filtros, { todos: true, alCambiar: cargar });
  await cargar();
}
