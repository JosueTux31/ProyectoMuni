// Usuarios: lista, creación (con contactos), ficha con pestañas y Mi perfil.
import { CONFIG } from "./config.js";
import { api, ErrorApi, ruta } from "./api.js";
import {
  abrirFormulario, botonCargando, botonesFila, camposHTML, cargandoHTML, confirmar, debounce,
  errorHTML, esc, eventoFila, fecha, icono, iniciales, leerCampos, limpiarErrores, mostrarErrores,
  nombreCompleto, tablaHTML, toast, vacioHTML,
} from "./ui.js";
import { cascadaGeo, NIVELES_GEO, opcionesCatalogo } from "./datos.js";

/* =====================================================================
   Lista
   ===================================================================== */
export async function vistaUsuarios(cont, _params, ctx) {
  ctx.migas([{ texto: "Usuarios" }]);
  cont.innerHTML = `
    <div class="encabezado">
      <div>
        <h1>Usuarios</h1>
        <p>Personas con acceso al sistema: su rol, departamento y estado.</p>
      </div>
      ${ctx.esAdmin ? `<div class="encabezado__acciones"><a class="btn btn--primario" href="#/usuarios/nuevo">${icono("usuario-mas")}Nuevo usuario</a></div>` : ""}
    </div>
    <section class="panel">
      <form class="filtros" role="search" id="filtros-usuarios">
        <div class="campo campo--buscar">
          <label for="f-buscar">Buscar</label>
          <div class="buscador">${icono("buscar")}<input id="f-buscar" name="buscar" type="search" placeholder="Nombre, identificación o usuario de red" autocomplete="off"></div>
        </div>
        <div class="campo">
          <label for="f-activo">Estado</label>
          <select id="f-activo" name="activo">
            <option value="true">Activos</option><option value="false">Inactivos</option><option value="">Todos</option>
          </select>
        </div>
        <div class="campo"><label for="f-rol">Rol</label><select id="f-rol" name="cod_rol"><option value="">Todos</option></select></div>
        <div class="campo"><label for="f-depto">Departamento</label><select id="f-depto" name="cod_departamento"><option value="">Todos</option></select></div>
        <span class="filtros__total" id="total-usuarios" aria-live="polite"></span>
      </form>
      <div id="lista-usuarios">${cargandoHTML()}</div>
    </section>`;

  const form = cont.querySelector("#filtros-usuarios");
  const lista = cont.querySelector("#lista-usuarios");
  const total = cont.querySelector("#total-usuarios");
  let filas = [];

  const [roles, deptos] = await Promise.all([opcionesCatalogo("roles"), opcionesCatalogo("departamentos")]);
  if (!ctx.vigente()) return;
  const opciones = (ops) => ops.map((o) => `<option value="${esc(o.valor)}">${esc(o.texto)}</option>`).join("");
  form.cod_rol.insertAdjacentHTML("beforeend", opciones(roles));
  form.cod_departamento.insertAdjacentHTML("beforeend", opciones(deptos));

  let consulta = 0;
  async function cargar() {
    const esta = ++consulta;
    lista.innerHTML = cargandoHTML();
    try {
      filas = await api("usuarios/", {
        query: {
          buscar: form.buscar.value.trim(),
          activo: form.activo.value,
          cod_rol: form.cod_rol.value,
          cod_departamento: form.cod_departamento.value,
        },
      });
    } catch (e) {
      if (esta === consulta) lista.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    if (esta !== consulta || !ctx.vigente()) return;
    total.textContent = `${filas.length} ${filas.length === 1 ? "usuario" : "usuarios"}`;

    if (!filas.length) {
      const hayFiltros = form.buscar.value || form.cod_rol.value || form.cod_departamento.value;
      lista.innerHTML = vacioHTML({
        icono: "usuarios",
        titulo: hayFiltros ? "Ningún usuario coincide con la búsqueda" : "No hay usuarios en este estado",
        texto: hayFiltros ? "Pruebe con otro nombre o quite los filtros." : "",
        boton: ctx.esAdmin && !hayFiltros ? `<a class="btn btn--primario" href="#/usuarios/nuevo">${icono("usuario-mas")}Crear el primero</a>` : "",
      });
      return;
    }

    lista.innerHTML = tablaHTML({
      clicable: true,
      filas,
      columnas: [
        {
          titulo: "Usuario",
          html: (u) => `<div class="persona"><span class="avatar">${esc(iniciales(u.nombre, u.apellido1))}</span><div>
            <a href="#/usuarios/${u.id}"><strong>${esc(nombreCompleto(u))}</strong></a>
            <span class="secundario">${u.usuario_red ? esc(u.usuario_red) : "Sin usuario de red"}</span></div></div>`,
        },
        { titulo: "Identificación", clase: "col-opcional", html: (u) => `${esc(u.dni)}<span class="secundario">${esc(u.tipo_identificacion)}</span>` },
        { titulo: "Rol", html: (u) => esc(u.rol) },
        { titulo: "Departamento", clase: "col-opcional", html: (u) => esc(u.departamento || "—") },
        { titulo: "Estado", html: (u) => pastillaEstado(u.activo) },
      ],
    });
  }

  lista.addEventListener("click", (ev) => {
    const r = eventoFila(ev, filas);
    if (r && !ev.target.closest("a")) location.hash = `#/usuarios/${r.fila.id}`;
  });
  form.addEventListener("submit", (ev) => { ev.preventDefault(); cargar(); });
  form.buscar.addEventListener("input", debounce(cargar, 300));
  ["activo", "cod_rol", "cod_departamento"].forEach((n) => form[n].addEventListener("change", cargar));

  await cargar();
}

const pastillaEstado = (activo) =>
  activo ? `<span class="pastilla pastilla--activo">Activo</span>` : `<span class="pastilla pastilla--inactivo">Inactivo</span>`;

/* =====================================================================
   Formulario de datos del usuario (crear y editar)
   ===================================================================== */
async function definicionCampos({ nuevo }) {
  const [tiposId, roles, auths, deptos] = await Promise.all([
    opcionesCatalogo("tipos-identificaciones"),
    opcionesCatalogo("roles"),
    opcionesCatalogo("tipos-autenticaciones"),
    opcionesCatalogo("departamentos"),
  ]);

  return [
    {
      clave: "identificacion", titulo: "Identificación", icono: "cedula",
      texto: "Documento de identidad y nombre completo.",
      campos: [
        { nombre: "cod_tipo_identificacion", etiqueta: "Tipo de identificación", tipo: "select", opciones: tiposId, requerido: true, entero: true },
        { nombre: "dni", etiqueta: "Número de identificación", requerido: true, max: 30, placeholder: "205550123" },
        { nombre: "nombre", etiqueta: "Nombre", requerido: true, max: 150, completo: true },
        { nombre: "apellido1", etiqueta: "Primer apellido", max: 100 },
        { nombre: "apellido2", etiqueta: "Segundo apellido", max: 100 },
      ],
    },
    {
      clave: "acceso", titulo: "Puesto y acceso", icono: "llave",
      texto: "Departamento, permisos y forma de entrar al sistema.",
      campos: [
        { nombre: "cod_departamento", etiqueta: "Departamento", tipo: "select", opciones: deptos, entero: true, vacioTexto: "Sin departamento" },
        { nombre: "cod_rol", etiqueta: "Rol", tipo: "select", opciones: roles, requerido: true, entero: true, ayuda: "Administrador puede modificar todo; los demás roles solo consultan." },
        { nombre: "cod_tipo_auth", etiqueta: "Forma de inicio de sesión", tipo: "select", opciones: auths, requerido: true, entero: true },
        { nombre: "usuario_red", etiqueta: "Usuario de red", max: 50, autocompletar: "off", placeholder: "jperez", ayuda: "Con este nombre inicia sesión." },
        ...(nuevo ? [{
          nombre: "password", etiqueta: "Clave inicial", tipo: "password", min: 8, max: 128,
          ayuda: "Mínimo 8 caracteres. Déjela vacía si el usuario entra con Active Directory.",
        }] : []),
        { nombre: "imagen_path", etiqueta: "Ruta de la fotografía", max: 255, placeholder: "fotos/jperez.jpg", completo: !nuevo },
      ],
    },
    {
      clave: "ubicacion", titulo: "Ubicación", icono: "punto",
      texto: "Dirección de residencia.",
      campos: [
        ...NIVELES_GEO.map((n) => ({ nombre: n.campo, etiqueta: n.titulo, tipo: "select", requerido: true })),
        { nombre: "otras_senas", etiqueta: "Otras señas", tipo: "textarea", completo: true, placeholder: "200 m norte de la iglesia, casa esquinera" },
      ],
    },
  ];
}

function seccionesHTML(secciones, valores, soloLectura) {
  return secciones.map((s) => `
    <section class="seccion-form">
      <h3>${icono(s.icono)}${esc(s.titulo)}</h3>
      <p>${esc(s.texto)}</p>
      <div class="rejilla">${camposHTML(s.campos, valores, { soloLectura })}</div>
    </section>`).join("");
}

const todosLosCampos = (secciones) => secciones.flatMap((s) => s.campos);

/** Traduce los choques de llaves únicas (409) a errores en el campo correcto. */
function precisarDuplicado(e) {
  if (e.estado !== 409) return e;
  if (e.db.includes("uk_usr_login")) e.campos = { usuario_red: "Ese usuario de red ya lo tiene otra persona." };
  else if (e.db.includes("uk_usr_documento")) e.campos = { dni: "Ya existe un usuario con este tipo y número de identificación." };
  return e;
}

/* ------------------------------------------------- Contactos repetibles */
const CONTACTOS = [
  {
    clave: "telefonos", titulo: "Teléfonos", singular: "teléfono", icono: "telefono", catalogo: "tipos-telefonos",
    fila: (tipos) => `
      <div class="campo"><label>Tipo</label><select data-k="cod_telefono" required><option value="">Seleccione…</option>${tipos}</select></div>
      <div class="campo"><label>Número</label><input data-k="telefono" type="tel" maxlength="25" required placeholder="8888-8888"></div>
      <label class="interruptor"><input type="checkbox" data-k="es_whatsapp"><span>WhatsApp</span></label>`,
  },
  {
    clave: "correos", titulo: "Correos", singular: "correo", icono: "correo", catalogo: "tipos-correos", columnas: 2,
    fila: (tipos) => `
      <div class="campo"><label>Tipo</label><select data-k="cod_correo" required><option value="">Seleccione…</option>${tipos}</select></div>
      <div class="campo"><label>Correo</label><input data-k="correo" type="email" maxlength="150" required placeholder="nombre@dominio.go.cr"></div>`,
  },
  {
    clave: "paginas-webs", titulo: "Páginas web", singular: "página web", icono: "web", columnas: 1,
    fila: () => `<div class="campo"><label>Dirección</label><input data-k="url_web" type="url" maxlength="255" required placeholder="https://"></div>`,
  },
];

async function contactosHTML() {
  const tipos = {};
  for (const c of CONTACTOS) {
    if (!c.catalogo) continue;
    tipos[c.clave] = (await opcionesCatalogo(c.catalogo))
      .map((o) => `<option value="${esc(o.valor)}">${esc(o.texto)}</option>`).join("");
  }
  const html = `
    <section class="seccion-form">
      <h3>${icono("telefono")}Contacto</h3>
      <p>Opcional. También se puede agregar después desde la ficha del usuario.</p>
      ${CONTACTOS.map((c) => `
        <div class="repetible" data-repetible="${c.clave}">
          <p class="repetible__titulo">${icono(c.icono, "ic--sm")}${esc(c.titulo)}</p>
          <div class="repetible__filas"></div>
          <div><button type="button" class="btn btn--fantasma btn--sm" data-agregar-contacto="${c.clave}">${icono("mas")}Agregar ${c.singular}</button></div>
        </div>`).join("")}
    </section>`;
  return { html, tipos };
}

function enlazarContactos(form, tipos) {
  form.addEventListener("click", (ev) => {
    const agregar = ev.target.closest("[data-agregar-contacto]");
    if (agregar) {
      const def = CONTACTOS.find((c) => c.clave === agregar.dataset.agregarContacto);
      const filas = form.querySelector(`[data-repetible="${def.clave}"] .repetible__filas`);
      const fila = document.createElement("div");
      fila.className = `repetible__fila${def.columnas ? ` repetible__fila--${def.columnas}` : ""}`;
      fila.innerHTML = `${def.fila(tipos[def.clave] || "")}
        <button type="button" class="btn-icono btn-icono--peligro" data-quitar aria-label="Quitar ${def.singular}">${icono("cerrar")}</button>`;
      // Asocia cada etiqueta con su control
      fila.querySelectorAll(".campo").forEach((campo, i) => {
        const control = campo.querySelector("input, select");
        control.id = `${def.clave}-${Date.now()}-${i}`;
        campo.querySelector("label").htmlFor = control.id;
      });
      filas.appendChild(fila);
      fila.querySelector("select, input")?.focus();
    }
    const quitar = ev.target.closest("[data-quitar]");
    if (quitar) quitar.closest(".repetible__fila").remove();
  });
}

function leerContactos(form) {
  const salida = {};
  for (const def of CONTACTOS) {
    salida[def.clave] = [...form.querySelectorAll(`[data-repetible="${def.clave}"] .repetible__fila`)].map((fila) => {
      const datos = {};
      fila.querySelectorAll("[data-k]").forEach((el) => {
        const k = el.dataset.k;
        if (el.type === "checkbox") datos[k] = el.checked;
        else if (k.startsWith("cod_")) datos[k] = Number.parseInt(el.value, 10);
        else datos[k] = el.value.trim();
      });
      return datos;
    });
  }
  return salida;
}

/* =====================================================================
   Nuevo usuario
   ===================================================================== */
export async function vistaUsuarioNuevo(cont, _params, ctx) {
  ctx.migas([{ texto: "Usuarios", href: "#/usuarios" }, { texto: "Nuevo usuario" }]);
  cont.innerHTML = cargandoHTML();

  const secciones = await definicionCampos({ nuevo: true });
  const contactos = await contactosHTML();
  if (!ctx.vigente()) return;

  cont.innerHTML = `
    <a class="volver" href="#/usuarios">${icono("atras")}Volver a usuarios</a>
    <div class="encabezado"><div><h1>Nuevo usuario</h1><p>Los campos con * son obligatorios.</p></div></div>
    <form class="panel" id="form-usuario" novalidate>
      <div class="panel__cuerpo">
        <div data-error hidden style="margin-bottom:18px"></div>
        ${seccionesHTML(secciones, {}, false)}
        ${contactos.html}
      </div>
      <div class="panel__pie">
        <a class="btn btn--secundario" href="#/usuarios">Cancelar</a>
        <button class="btn btn--primario" type="submit">${icono("check")}Crear usuario</button>
      </div>
    </form>`;

  const form = cont.querySelector("#form-usuario");
  const caja = form.querySelector("[data-error]");
  const campos = todosLosCampos(secciones);
  enlazarContactos(form, contactos.tipos);
  cascadaGeo(NIVELES_GEO.map((n) => form.elements.namedItem(n.campo)));

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity()) return;

    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    const datos = leerCampos(form, campos);
    const extra = leerContactos(form);

    let creado;
    try {
      creado = await api("usuarios/", { metodo: "POST", datos });
    } catch (e) {
      botonCargando(boton, false);
      if (e instanceof ErrorApi) mostrarErrores(form, precisarDuplicado(e), caja);
      else throw e;
      caja.scrollIntoView({ behavior: "smooth", block: "center" });
      return;
    }

    const fallos = [];
    for (const def of CONTACTOS) {
      for (const item of extra[def.clave]) {
        try {
          await api(ruta("usuarios", creado.id, def.clave), { metodo: "POST", datos: item });
        } catch (e) {
          fallos.push(`${def.singular} ${Object.values(item).find((v) => typeof v === "string") || ""}: ${e.message}`);
        }
      }
    }

    toast(`Se creó el usuario ${nombreCompleto(creado)}.`);
    if (fallos.length) toast(`No se guardaron algunos contactos. ${fallos.join(" ")}`, "error");
    location.hash = `#/usuarios/${creado.id}`;
  });
}

/* =====================================================================
   Ficha del usuario (y Mi perfil)
   ===================================================================== */
export function vistaUsuario(cont, [id, pestana], ctx) {
  const numero = Number(id);
  if (numero === ctx.usuario.id) {
    history.replaceState(null, "", `#/perfil${pestana ? `/${pestana}` : ""}`);
    return ficha(cont, numero, pestana, ctx, true);
  }
  return ficha(cont, numero, pestana, ctx, false);
}

export function vistaPerfil(cont, [pestana], ctx) {
  return ficha(cont, ctx.usuario.id, pestana, ctx, true);
}

const PESTANAS = [
  { clave: "datos", titulo: "Datos generales", icono: "usuario" },
  { clave: "telefonos", titulo: "Teléfonos", icono: "telefono" },
  { clave: "correos", titulo: "Correos", icono: "correo" },
  { clave: "paginas-webs", titulo: "Páginas web", icono: "web" },
  { clave: "seguridad", titulo: "Seguridad", icono: "candado" },
];

async function ficha(cont, id, pestanaInicial, ctx, perfil) {
  const migaBase = perfil ? [{ texto: "Mi perfil" }] : [{ texto: "Usuarios", href: "#/usuarios" }];
  ctx.migas(migaBase);
  cont.innerHTML = cargandoHTML();

  const u = await api(ruta("usuarios", id));
  if (!ctx.vigente()) return;
  if (!perfil) ctx.migas([...migaBase, { texto: nombreCompleto(u) }]);

  const propio = id === ctx.usuario.id;
  const base = perfil ? "#/perfil" : `#/usuarios/${id}`;
  const pestanas = PESTANAS.filter((p) => p.clave !== "seguridad" || ctx.esAdmin || propio);
  let actual = pestanas.find((p) => p.clave === pestanaInicial)?.clave || "datos";

  cont.innerHTML = `
    ${perfil ? "" : `<a class="volver" href="#/usuarios">${icono("atras")}Volver a usuarios</a>`}
    <div class="ficha">
      <span class="avatar avatar--grande">${esc(iniciales(u.nombre, u.apellido1))}</span>
      <div class="ficha__texto">
        <h1>${esc(nombreCompleto(u))}</h1>
        <div class="ficha__datos">
          ${pastillaEstado(u.activo)}
          <span>${esc(u.rol)}</span>
          <span>${esc(u.departamento || "Sin departamento")}</span>
          <span>${u.usuario_red ? `Usuario: <strong>${esc(u.usuario_red)}</strong>` : "Sin usuario de red"}</span>
        </div>
      </div>
      <div class="ficha__acciones">
        ${ctx.esAdmin && !propio ? (u.activo
          ? `<button type="button" class="btn btn--secundario" data-estado>${icono("encender")}Desactivar</button>`
          : `<button type="button" class="btn btn--primario" data-estado>${icono("encender")}Activar</button>`) : ""}
      </div>
    </div>
    <div class="pestanas" role="tablist" aria-label="Información del usuario">
      ${pestanas.map((p) => `<button type="button" role="tab" id="tab-${p.clave}" aria-controls="panel-pestana" data-pestana="${p.clave}" aria-selected="${p.clave === actual}">${icono(p.icono)}${esc(p.titulo)}</button>`).join("")}
    </div>
    <div id="panel-pestana" role="tabpanel"></div>`;

  const panel = cont.querySelector("#panel-pestana");
  const recargar = (pestana = actual) => ficha(cont, id, pestana, ctx, perfil);

  cont.querySelector("[data-estado]")?.addEventListener("click", () => cambiarEstado(u, () => recargar()));

  async function mostrar(clave) {
    actual = clave;
    cont.querySelectorAll("[data-pestana]").forEach((b) => b.setAttribute("aria-selected", String(b.dataset.pestana === clave)));
    panel.setAttribute("aria-labelledby", `tab-${clave}`);
    history.replaceState(null, "", clave === "datos" ? base : `${base}/${clave}`);
    // Cada pestaña se dibuja en un contenedor nuevo: si el usuario cambia
    // de pestaña antes de que termine de cargar, la anterior escribe en un
    // elemento que ya no está en pantalla.
    const caja = document.createElement("div");
    caja.innerHTML = cargandoHTML();
    panel.replaceChildren(caja);
    try {
      if (clave === "datos") await pestanaDatos(caja, u, ctx, propio, recargar);
      else if (clave === "seguridad") await pestanaSeguridad(caja, u, ctx, propio, recargar);
      else await pestanaContactos(caja, u, clave, ctx);
    } catch (e) {
      if (!ctx.vigente()) return;
      caja.innerHTML = errorHTML(e instanceof ErrorApi ? e.message : "No se pudo mostrar esta sección.");
      if (!(e instanceof ErrorApi)) console.error(e);
    }
  }

  const lista = cont.querySelector("[role=tablist]");
  lista.addEventListener("click", (ev) => {
    const b = ev.target.closest("[data-pestana]");
    if (b && b.dataset.pestana !== actual) mostrar(b.dataset.pestana);
  });
  lista.addEventListener("keydown", (ev) => {
    if (!["ArrowLeft", "ArrowRight"].includes(ev.key)) return;
    const botones = [...lista.querySelectorAll("[data-pestana]")];
    const i = botones.findIndex((b) => b.dataset.pestana === actual);
    const sig = botones[(i + (ev.key === "ArrowRight" ? 1 : -1) + botones.length) % botones.length];
    sig.focus();
    mostrar(sig.dataset.pestana);
  });

  await mostrar(actual);
}

async function cambiarEstado(u, alTerminar) {
  const nombre = nombreCompleto(u);
  if (u.activo) {
    const ok = await confirmar({
      titulo: "Desactivar usuario",
      mensaje: `${nombre} no podrá iniciar sesión hasta que lo active de nuevo. Sus datos se conservan.`,
      textoBoton: "Desactivar",
      accion: () => api(ruta("usuarios", u.id), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se desactivó a ${nombre}.`); alTerminar(); }
    return;
  }
  try {
    await api(ruta("usuarios", u.id, "activar"), { metodo: "POST" });
    toast(`Se activó a ${nombre}.`);
    alTerminar();
  } catch (e) {
    toast(e.message, "error");
  }
}

/* --------------------------------------------------------- Datos generales */
async function pestanaDatos(panel, u, ctx, propio, recargar) {
  const secciones = await definicionCampos({ nuevo: false });
  const soloLectura = !ctx.esAdmin;
  const campos = todosLosCampos(secciones);

  panel.innerHTML = `
    <form class="panel" novalidate>
      <div class="panel__cuerpo">
        ${soloLectura ? `<div class="aviso aviso--ocre" style="margin-bottom:18px">${icono("candado")}<span>Solo un administrador puede modificar estos datos.</span></div>` : ""}
        <div data-error hidden style="margin-bottom:18px"></div>
        ${seccionesHTML(secciones, u, soloLectura)}
        <section class="seccion-form">
          <h3>${icono("etiqueta")}Registro</h3>
          <dl class="lista-datos">
            <div><dt>Creado</dt><dd>${esc(fecha(u.creado_en))}</dd></div>
            <div><dt>Última modificación</dt><dd>${esc(fecha(u.actualizado_en))}</dd></div>
          </dl>
        </section>
      </div>
      ${soloLectura ? "" : `<div class="panel__pie"><button type="submit" class="btn btn--primario">${icono("check")}Guardar cambios</button></div>`}
    </form>`;

  const form = panel.querySelector("form");
  const caja = form.querySelector("[data-error]");
  cascadaGeo(NIVELES_GEO.map((n) => form.elements.namedItem(n.campo)), { valores: u, bloqueado: soloLectura });
  if (soloLectura) return;

  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity()) return;
    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    try {
      await api(ruta("usuarios", u.id), { metodo: "PUT", datos: { ...leerCampos(form, campos), activo: u.activo } });
      toast("Se guardaron los cambios.");
      if (propio) await ctx.refrescarSesion();
      recargar("datos");
    } catch (e) {
      botonCargando(boton, false);
      if (e instanceof ErrorApi) mostrarErrores(form, precisarDuplicado(e), caja);
      else throw e;
    }
  });
}

/* -------------------------------------------- Teléfonos, correos y páginas */
const SUBRECURSOS = {
  telefonos: {
    titulo: "Teléfonos", singular: "teléfono", icono: "telefono",
    campos: async () => [
      { nombre: "cod_telefono", etiqueta: "Tipo", tipo: "select", requerido: true, entero: true, opciones: await opcionesCatalogo("tipos-telefonos") },
      { nombre: "telefono", etiqueta: "Número", tipo: "tel", requerido: true, max: 25, placeholder: "8888-8888" },
      { nombre: "es_whatsapp", etiqueta: "Este número tiene WhatsApp", tipo: "checkbox" },
    ],
    columnas: [
      { titulo: "Número", html: (f) => `<strong>${esc(f.telefono)}</strong>` },
      { titulo: "Tipo", html: (f) => esc(f.tipo_telefono) },
      { titulo: "WhatsApp", html: (f) => (f.es_whatsapp ? `<span class="pastilla pastilla--activo pastilla--sin-punto">${icono("chat", "ic--sm")}Sí</span>` : `<span class="secundario">No</span>`) },
    ],
    etiqueta: (f) => f.telefono,
  },
  correos: {
    titulo: "Correos", singular: "correo", icono: "correo",
    campos: async () => [
      { nombre: "cod_correo", etiqueta: "Tipo", tipo: "select", requerido: true, entero: true, opciones: await opcionesCatalogo("tipos-correos") },
      { nombre: "correo", etiqueta: "Correo electrónico", tipo: "email", requerido: true, max: 150, placeholder: "nombre@dominio.go.cr" },
    ],
    columnas: [
      { titulo: "Correo", html: (f) => `<a href="mailto:${esc(f.correo)}"><strong>${esc(f.correo)}</strong></a>` },
      { titulo: "Tipo", html: (f) => esc(f.tipo_correo) },
    ],
    etiqueta: (f) => f.correo,
  },
  "paginas-webs": {
    titulo: "Páginas web", singular: "página web", icono: "web",
    campos: async () => [
      { nombre: "url_web", etiqueta: "Dirección", tipo: "url", requerido: true, max: 255, placeholder: "https://" },
    ],
    columnas: [
      {
        titulo: "Dirección",
        html: (f) => (/^https?:\/\//i.test(f.url_web)
          ? `<a href="${esc(f.url_web)}" target="_blank" rel="noopener noreferrer">${esc(f.url_web)}</a>`
          : esc(f.url_web)),
      },
    ],
    etiqueta: (f) => f.url_web,
  },
};

async function pestanaContactos(panel, u, clave, ctx) {
  const def = SUBRECURSOS[clave];
  const base = ruta("usuarios", u.id, clave);
  const admin = ctx.esAdmin;

  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza">
        <div><h2>${esc(def.titulo)}</h2><p>${admin ? "" : "Solo un administrador puede agregar o cambiar contactos."}</p></div>
        ${admin ? `<button type="button" class="btn btn--primario btn--sm" data-agregar>${icono("mas")}Agregar ${esc(def.singular)}</button>` : ""}
      </div>
      <div data-lista>${cargandoHTML()}</div>
    </section>`;

  const lista = panel.querySelector("[data-lista]");
  let filas = [];

  async function cargar() {
    filas = await api(base);
    if (!filas.length) {
      lista.innerHTML = vacioHTML({
        icono: def.icono,
        titulo: `Sin ${def.titulo.toLowerCase()} registrados`,
        boton: admin ? `<button type="button" class="btn btn--secundario" data-agregar>${icono("mas")}Agregar ${esc(def.singular)}</button>` : "",
      });
      return;
    }
    const columnas = [...def.columnas];
    if (admin) columnas.push({ titulo: "", clase: "col-acciones", html: (f) => botonesFila({ etiqueta: def.etiqueta(f) }) });
    lista.innerHTML = tablaHTML({ columnas, filas });
  }

  async function formulario(fila) {
    const r = await abrirFormulario({
      titulo: fila ? `Editar ${def.singular}` : `Agregar ${def.singular}`,
      campos: await def.campos(),
      valores: fila || {},
      textoGuardar: fila ? "Guardar cambios" : "Agregar",
      alGuardar: (datos) => api(fila ? ruta("usuarios", u.id, clave, fila.num_linea) : base, {
        metodo: fila ? "PUT" : "POST", datos,
      }),
    });
    if (r) { toast(fila ? "Se guardaron los cambios." : `Se agregó el ${def.singular}.`); await cargar(); }
  }

  panel.addEventListener("click", async (ev) => {
    if (ev.target.closest("[data-agregar]")) return formulario(null);
    const r = eventoFila(ev, filas);
    if (!r?.accion) return;
    if (r.accion === "editar") return formulario(r.fila);
    if (r.accion === "borrar") {
      const ok = await confirmar({
        titulo: `Eliminar ${def.singular}`,
        mensaje: `Se eliminará ${def.etiqueta(r.fila)} de ${nombreCompleto(u)}.`,
        textoBoton: "Eliminar",
        accion: () => api(ruta("usuarios", u.id, clave, r.fila.num_linea), { metodo: "DELETE" }),
      });
      if (ok) { toast(`Se eliminó ${def.etiqueta(r.fila)}.`); await cargar(); }
    }
  });

  await cargar();
}

/* --------------------------------------------------------------- Seguridad */
async function pestanaSeguridad(panel, u, ctx, propio, recargar) {
  const esAD = /directory|\bad\b/i.test(u.tipo_autenticacion || "");
  const campos = [
    ...(propio ? [{ nombre: "password_actual", etiqueta: "Clave actual", tipo: "password", requerido: true, autocompletar: "current-password" }] : []),
    { nombre: "password", etiqueta: "Clave nueva", tipo: "password", requerido: true, min: 8, max: 128, ayuda: "Mínimo 8 caracteres. No puede repetir sus últimas claves." },
    { nombre: "confirmacion", etiqueta: "Repita la clave nueva", tipo: "password", requerido: true, min: 8, max: 128 },
  ];

  panel.innerHTML = `
    <section class="panel">
      <div class="panel__cabeza"><div><h2>${propio ? "Cambiar mi clave" : "Asignar una clave nueva"}</h2>
        <p>${propio ? "Necesita su clave actual para confirmar el cambio." : "El usuario usará esta clave en su próximo inicio de sesión."}</p></div></div>
      <form novalidate>
        <div class="panel__cuerpo">
          ${esAD ? `<div class="aviso aviso--info" style="margin-bottom:16px">${icono("alerta")}<span>Este usuario inicia sesión con Active Directory, así que la clave del sistema no se usa para entrar.</span></div>` : ""}
          <div data-error hidden style="margin-bottom:16px"></div>
          <div class="rejilla">${camposHTML(campos, {})}</div>
        </div>
        <div class="panel__pie"><button type="submit" class="btn btn--primario">${icono("llave")}Cambiar clave</button></div>
      </form>
    </section>
    ${ctx.esAdmin ? `
    <section class="panel">
      <div class="panel__cabeza"><div><h2>Historial de claves</h2><p>Fechas en que se asignó cada clave. Las claves no se muestran.</p></div></div>
      <div data-historial>${cargandoHTML()}</div>
    </section>` : ""}
    ${ctx.esAdmin && !propio ? `
    <section class="panel zona-riesgo">
      <div class="panel__cabeza"><h2>Acciones sobre la cuenta</h2></div>
      <div class="fila-riesgo">
        <div><strong>${u.activo ? "Desactivar usuario" : "Activar usuario"}</strong>
          <p>${u.activo ? "Impide que inicie sesión. Sus datos se conservan y se puede activar de nuevo." : "Permite que vuelva a iniciar sesión."}</p></div>
        <button type="button" class="btn ${u.activo ? "btn--secundario" : "btn--primario"}" data-estado>${icono("encender")}${u.activo ? "Desactivar" : "Activar"}</button>
      </div>
      <div class="fila-riesgo">
        <div><strong>Eliminar definitivamente</strong>
          <p>Borra el usuario con sus teléfonos, correos, páginas web e historial de claves. No se puede deshacer.</p></div>
        <button type="button" class="btn btn--peligro-suave" data-eliminar>${icono("borrar")}Eliminar usuario</button>
      </div>
    </section>` : ""}`;

  // Cambio de clave
  const form = panel.querySelector("form");
  const caja = form.querySelector("[data-error]");
  form.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    limpiarErrores(form);
    caja.hidden = true;
    if (!form.reportValidity()) return;
    const datos = leerCampos(form, campos);
    if (datos.password !== datos.confirmacion) {
      mostrarErrores(form, new ErrorApi("", 400, { confirmacion: "Las dos claves no coinciden." }), caja);
      return;
    }
    const boton = form.querySelector("[type=submit]");
    botonCargando(boton, true);
    try {
      await api(ruta("usuarios", u.id, "cambiar-clave"), {
        metodo: "POST",
        datos: {
          password_actual: datos.password_actual ?? null,
          password: datos.password,
          historial_bloqueo: CONFIG.HISTORIAL_CLAVES_BLOQUEADAS,
        },
      });
      toast("Se cambió la clave.");
      form.reset();
      if (ctx.esAdmin) cargarHistorial();
    } catch (e) {
      if (e instanceof ErrorApi) mostrarErrores(form, e, caja);
      else throw e;
    } finally {
      botonCargando(boton, false);
    }
  });

  // Historial (solo administradores)
  const cajaHistorial = panel.querySelector("[data-historial]");
  let historial = [];
  async function cargarHistorial() {
    if (!cajaHistorial) return;
    try {
      historial = await api(ruta("usuarios", u.id, "historial-claves"));
    } catch (e) {
      cajaHistorial.innerHTML = `<div class="panel__cuerpo">${errorHTML(e.message)}</div>`;
      return;
    }
    cajaHistorial.innerHTML = historial.length
      ? tablaHTML({
        filas: historial,
        columnas: [
          { titulo: "Cambio", clase: "col-codigo", html: (f) => `N.º ${esc(f.num_linea)}` },
          { titulo: "Fecha", html: (f) => esc(fecha(f.fecha_registro)) },
          { titulo: "", clase: "col-acciones", html: (f) => botonesFila({ editar: false, etiqueta: `registro ${f.num_linea}` }) },
        ],
      })
      : vacioHTML({ icono: "llave", titulo: "Sin cambios de clave registrados" });
  }
  cajaHistorial?.addEventListener("click", async (ev) => {
    const r = eventoFila(ev, historial);
    if (r?.accion !== "borrar") return;
    const ok = await confirmar({
      titulo: "Eliminar registro del historial",
      mensaje: `Se eliminará el registro N.º ${r.fila.num_linea}. Esa clave podrá volver a usarse.`,
      textoBoton: "Eliminar",
      accion: () => api(ruta("usuarios", u.id, "historial-claves", r.fila.num_linea), { metodo: "DELETE" }),
    });
    if (ok) { toast("Se eliminó el registro."); cargarHistorial(); }
  });

  panel.querySelector("[data-estado]")?.addEventListener("click", () => cambiarEstado(u, () => recargar("seguridad")));
  panel.querySelector("[data-eliminar]")?.addEventListener("click", async () => {
    const nombre = nombreCompleto(u);
    const ok = await confirmar({
      titulo: "Eliminar usuario definitivamente",
      mensaje: `Se borrarán ${nombre} y todos sus datos relacionados. Si solo quiere impedir que entre, use Desactivar.`,
      textoBoton: "Eliminar definitivamente",
      accion: () => api(ruta("usuarios", u.id, "eliminar-fisico"), { metodo: "DELETE" }),
    });
    if (ok) { toast(`Se eliminó a ${nombre}.`); location.hash = "#/usuarios"; }
  });

  await cargarHistorial();
}
