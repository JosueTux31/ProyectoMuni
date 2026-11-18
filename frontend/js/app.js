// Arranque: inicio de sesión, menú de módulos, estructura, menú lateral y rutas.
// Módulos de este sistema: usuarios y proveedores, equipos municipales y análisis de logs.
import { CONFIG } from "./config.js";
import { api, cuandoExpireSesion, ErrorApi, sesion } from "./api.js";
import {
  activarMascaraTelefono, avatarHTML, cargandoHTML, debounce, errorHTML, esc, fecha, icono, nombreCompleto,
  botonCargando, tablaHTML, eventoFila, vacioHTML,
} from "./ui.js";
import { activarVistaAvatares } from "./zoom.js";
import { filasCatalogo } from "./datos.js";
import { vistaPerfil, vistaUsuario, vistaUsuarioNuevo, vistaUsuarios } from "./usuarios.js";
import { vistaCatalogo, vistaGeografia } from "./recursos.js";
import { vistaProveedor, vistaProveedores, vistaProveedorNuevo } from "./proveedores.js";
import { feedAuditoria, vistaAuditoria } from "./auditoria.js";
import {
  vistaDispositivo, vistaDispositivoNuevo, vistaDispositivos, vistaEdificios, vistaInicioRed, vistaMarcas,
} from "./dispositivos.js";
import { vistaSwitches } from "./switch.js";
import {
  vistaCamposLogs, vistaCobertura, vistaComparar, vistaEventos, vistaImportacion, vistaImportaciones, vistaImportarDhcp,
  vistaImportarMicroclaudia, vistaImportarSophos, vistaInicioLogs, vistaIntrusos, vistaInventarioLogs, vistaTablero,
} from "./logs.js";

const $ = (sel) => document.querySelector(sel);

const pantallaLogin = $("#pantalla-login");
const pantallaApp = $("#pantalla-app");
const vista = $("#vista");

document.querySelectorAll("[data-institucion]").forEach((el) => { el.textContent = CONFIG.INSTITUCION; });
activarMascaraTelefono();   // 0000-0000 en todos los teléfonos
activarVistaAvatares();     // foto más grande al pasar el mouse por un avatar

/* =====================================================================
   Sesión
   ===================================================================== */
let usuarioActual = null;

function mostrarLogin(mensaje) {
  usuarioActual = null;
  pantallaApp.hidden = true;
  pantallaLogin.hidden = false;
  document.title = "Iniciar sesión | Gestión Municipal";
  const caja = $("#login-error");
  if (mensaje) { caja.innerHTML = `${icono("alerta")}<span>${esc(mensaje)}</span>`; caja.hidden = false; }
  else caja.hidden = true;
  dibujarRelieve();
  $("#login-usuario").focus();
}

function entrar(perfil) {
  usuarioActual = perfil;
  pantallaLogin.hidden = true;
  pantallaApp.hidden = false;
  pintarSesion();
  if (!location.hash || location.hash === "#" || location.hash === "#/") location.hash = "#/modulos";
  else navegar();
}

function pintarSesion() {
  const u = usuarioActual;
  $("#sesion-avatar").innerHTML = avatarHTML(u, { clase: "avatar--claro" });
  $("#sesion-nombre").textContent = nombreCompleto(u);
  $("#sesion-rol").textContent = u.rol || "";
  const indicador = $("#indicador-permiso");
  indicador.className = `permiso ${u.es_admin ? "permiso--admin" : "permiso--lectura"}`;
  indicador.innerHTML = u.es_admin
    ? `${icono("escudo")}<span>Administrador</span>`
    : `${icono("candado")}<span>Solo consulta</span>`;
  indicador.title = u.es_admin ? "Puede crear, modificar y eliminar" : "Puede consultar; los cambios los hace un administrador";
  document.querySelectorAll("[data-solo-admin]").forEach((el) => { el.hidden = !u.es_admin; });
}

function salir(mensaje) {
  // Registra el cierre de sesión en la auditoría (si falla, se sale igual)
  if (!mensaje && sesion.leer()?.token) api("usuarios/logout/", { metodo: "POST" }).catch(() => {});
  sesion.borrar();
  history.replaceState(null, "", location.pathname);
  mostrarLogin(mensaje);
}

cuandoExpireSesion((mensaje) => { if (usuarioActual) salir(mensaje); });

$("#form-login").addEventListener("submit", async (ev) => {
  ev.preventDefault();
  const form = ev.currentTarget;
  const caja = $("#login-error");
  const usuario = form.usuario_red.value.trim();
  const clave = form.password.value;
  if (!usuario || !clave) {
    caja.innerHTML = `${icono("alerta")}<span>Escriba su usuario de red y su clave.</span>`;
    caja.hidden = false;
    (usuario ? form.password : form.usuario_red).focus();
    return;
  }
  const boton = form.querySelector("[type=submit]");
  botonCargando(boton, true);
  caja.hidden = true;
  try {
    const r = await api("usuarios/login/", { metodo: "POST", datos: { usuario_red: usuario, password: clave } });
    sesion.guardar({ token: r.token, usuario: r.usuario });
    form.reset();
    entrar(r.usuario);
  } catch (e) {
    caja.innerHTML = `${icono("alerta")}<span>${esc(e.message)}</span>`;
    caja.hidden = false;
    form.password.select();
  } finally {
    botonCargando(boton, false);
  }
});

$("#btn-salir").addEventListener("click", () => salir());

/** Vuelve a leer los datos del usuario en sesión (después de editarlo). */
async function refrescarSesion() {
  try {
    const perfil = await api("usuarios/yo/");
    usuarioActual = perfil;
    const s = sesion.leer();
    if (s) sesion.guardar({ ...s, usuario: perfil });
    pintarSesion();
  } catch { /* si falla, la sesión expirada ya redirige al login */ }
}

/* =====================================================================
   Menú lateral (móvil)
   ===================================================================== */
const botonMenu = $("#btn-menu");
const velo = $("#velo");
function menuMovil(abrir) {
  pantallaApp.classList.toggle("menu-abierto", abrir);
  velo.hidden = !abrir;
  botonMenu.setAttribute("aria-expanded", String(abrir));
}
botonMenu.addEventListener("click", () => menuMovil(!pantallaApp.classList.contains("menu-abierto")));
velo.addEventListener("click", () => menuMovil(false));
document.addEventListener("keydown", (ev) => { if (ev.key === "Escape") menuMovil(false); });

/* =====================================================================
   Módulos: al entrar se elige con cuál trabajar. Cada uno tiene su menú.
   ===================================================================== */
const MODULOS = {
  usuarios: { nombre: "Usuarios y proveedores", inicio: "#/inicio", icono: "usuarios" },
  red: { nombre: "Equipos municipales", inicio: "#/red", icono: "red" },
  logs: { nombre: "Análisis de logs", inicio: "#/logs", icono: "logs", soloAdmin: true },
};
let moduloActual = null;

function moduloDeRuta(r) {
  if (r === "modulos") return null;
  if (r === "red" || r.startsWith("red/")) return "red";
  if (r === "logs" || r.startsWith("logs/")) return "logs";
  // Mi perfil se queda en el módulo donde estaba la persona
  if (r === "perfil" || r.startsWith("perfil/")) return moduloActual || "usuarios";
  return "usuarios";
}

function pintarModulo(modulo) {
  moduloActual = modulo;
  document.querySelectorAll("#nav [data-modulo]").forEach((g) => { g.hidden = g.dataset.modulo !== (modulo || "modulos"); });
  const def = MODULOS[modulo];
  $("#modulo-nombre").textContent = def ? def.nombre : "Elija un módulo";
  $("#modulo-icono").setAttribute("href", `#i-${def ? def.icono : "modulos"}`);
  $("#modulo-actual").classList.toggle("modulo-actual--ninguno", !def);
}

/* =====================================================================
   Rutas
   ===================================================================== */
const RUTAS = [
  { patron: /^modulos$/, vista: vistaModulos },
  { patron: /^inicio$/, vista: vistaInicio },
  { patron: /^usuarios$/, vista: vistaUsuarios },
  { patron: /^usuarios\/nuevo$/, vista: vistaUsuarioNuevo, soloAdmin: true },
  { patron: /^usuarios\/(\d+)(?:\/([\w-]+))?$/, vista: vistaUsuario },
  { patron: /^perfil(?:\/([\w-]+))?$/, vista: vistaPerfil },
  { patron: /^proveedores$/, vista: vistaProveedores },
  { patron: /^proveedores\/nuevo$/, vista: vistaProveedorNuevo, soloAdmin: true },
  { patron: /^proveedores\/(\d+)(?:\/([\w-]+))?$/, vista: vistaProveedor },
  { patron: /^auditoria$/, vista: vistaAuditoria, soloAdmin: true },
  { patron: /^catalogos\/([\w-]+)$/, vista: vistaCatalogo },
  { patron: /^geografia\/([\w-]+)$/, vista: vistaGeografia },
  // Módulo de equipos municipales (rutas #/red/...)
  { patron: /^red$/, vista: vistaInicioRed },
  { patron: /^red\/dispositivos$/, vista: vistaDispositivos },
  { patron: /^red\/dispositivos\/nuevo$/, vista: vistaDispositivoNuevo, soloAdmin: true },
  { patron: /^red\/dispositivos\/(\d+)(?:\/([\w-]+))?$/, vista: vistaDispositivo },
  { patron: /^red\/switches$/, vista: vistaSwitches },
  { patron: /^red\/marcas$/, vista: vistaMarcas },
  { patron: /^red\/edificios$/, vista: vistaEdificios },
  { patron: /^red\/catalogos\/([\w-]+)$/, vista: (cont, params, ctx) => vistaCatalogo(cont, params, ctx, "red") },
  { patron: /^red\/auditoria$/, vista: vistaAuditoria, soloAdmin: true },
  // Módulo de análisis de logs (solo administradores: muestra la navegación del personal)
  { patron: /^logs$/, vista: vistaInicioLogs, soloAdmin: true },
  { patron: /^logs\/importar\/sophos$/, vista: vistaImportarSophos, soloAdmin: true },
  { patron: /^logs\/importar\/microclaudia$/, vista: vistaImportarMicroclaudia, soloAdmin: true },
  { patron: /^logs\/importar\/dhcp$/, vista: vistaImportarDhcp, soloAdmin: true },
  { patron: /^logs\/cobertura$/, vista: vistaCobertura, soloAdmin: true },
  { patron: /^logs\/intrusos$/, vista: vistaIntrusos, soloAdmin: true },
  { patron: /^logs\/importaciones$/, vista: vistaImportaciones, soloAdmin: true },
  { patron: /^logs\/importaciones\/(\d+)$/, vista: vistaImportacion, soloAdmin: true },
  { patron: /^logs\/tablero$/, vista: vistaTablero, soloAdmin: true },
  { patron: /^logs\/eventos$/, vista: vistaEventos, soloAdmin: true },
  { patron: /^logs\/comparar$/, vista: vistaComparar, soloAdmin: true },
  { patron: /^logs\/inventario$/, vista: vistaInventarioLogs, soloAdmin: true },
  { patron: /^logs\/campos$/, vista: vistaCamposLogs, soloAdmin: true },
  { patron: /^logs\/auditoria$/, vista: vistaAuditoria, soloAdmin: true },
];

let navegacion = 0;

function marcarMenu(rutaActual) {
  let mejor = null;
  const visibles = `#nav [data-modulo="${moduloActual || "modulos"}"] [data-ruta]`;
  document.querySelectorAll(visibles).forEach((a) => {
    const r = a.dataset.ruta;
    if ((rutaActual === r || rutaActual.startsWith(`${r}/`)) && (!mejor || r.length > mejor.dataset.ruta.length)) mejor = a;
  });
  document.querySelectorAll("[data-ruta]").forEach((a) => {
    const activo = a === mejor;
    a.classList.toggle("activo", activo);
    if (activo) a.setAttribute("aria-current", "page"); else a.removeAttribute("aria-current");
  });
}

function migas(lista) {
  // La primera miga es el módulo (en su inicio, solo el nombre del módulo)
  const def = MODULOS[moduloActual];
  let partes = def ? [{ texto: def.nombre, href: def.inicio }, ...lista] : [...lista];
  if (def && lista.length === 1 && lista[0].texto === "Inicio") partes = [{ texto: def.nombre }];
  $("#migas").innerHTML = partes.map((m, i) => {
    const ultimo = i === partes.length - 1;
    const separador = i ? icono("derecha") : "";
    if (ultimo) return `${separador}<span aria-current="page">${esc(m.texto)}</span>`;
    return `${separador}${m.href ? `<a href="${m.href}">${esc(m.texto)}</a>` : `<span>${esc(m.texto)}</span>`}`;
  }).join("");
  document.title = `${partes[partes.length - 1].texto} | Gestión Municipal`;
}

async function navegar() {
  if (!usuarioActual) return;
  const actual = ++navegacion;
  menuMovil(false);

  // #/red/dispositivos?tipo_disp=2 -> ruta "red/dispositivos" y filtros en ctx.query
  const [rutaActual, consulta = ""] = (location.hash.replace(/^#\/?/, "") || "modulos").split("?");
  pintarModulo(moduloDeRuta(rutaActual));
  marcarMenu(rutaActual);

  const ctx = {
    usuario: usuarioActual,
    esAdmin: !!usuarioActual.es_admin,
    vigente: () => actual === navegacion,
    query: new URLSearchParams(consulta),
    modulo: moduloActual,
    migas,
    refrescarSesion,
  };

  let encontrada = null;
  let params = [];
  for (const r of RUTAS) {
    const m = rutaActual.match(r.patron);
    if (m) { encontrada = r; params = m.slice(1); break; }
  }

  // Cada pantalla recibe un contenedor nuevo, así los eventos de la
  // pantalla anterior se descartan junto con su contenido.
  const contenedor = document.createElement("div");
  vista.replaceChildren(contenedor);
  window.scrollTo(0, 0);

  if (!encontrada) return paginaMensaje(contenedor, ctx, "No encontramos esta página", "Revise la dirección o use el menú.", "mapa");
  if (encontrada.soloAdmin && !ctx.esAdmin) {
    return paginaMensaje(contenedor, ctx, "Solo un administrador puede usar esta opción",
      "Su rol permite consultar la información. Si necesita un cambio, pídalo a un administrador.", "candado");
  }

  try {
    await encontrada.vista(contenedor, params, ctx);
  } catch (e) {
    if (!ctx.vigente()) return;
    console.error(e);
    contenedor.innerHTML = errorHTML(e instanceof ErrorApi ? e.message : "Ocurrió un error inesperado al mostrar esta página.");
  }
  if (ctx.vigente()) vista.focus({ preventScroll: true });
}

function paginaMensaje(contenedor, ctx, titulo, texto, ic) {
  ctx.migas([{ texto: titulo }]);
  const inicio = MODULOS[moduloActual]?.inicio || "#/modulos";
  contenedor.innerHTML = `<section class="panel">${vacioHTML({
    icono: ic, titulo, texto, boton: `<a class="btn btn--secundario" href="${inicio}">Ir al inicio</a>`,
  })}</section>`;
}

window.addEventListener("hashchange", navegar);

/* =====================================================================
   Menú de módulos (primera pantalla después de iniciar sesión)
   ===================================================================== */
async function vistaModulos(cont, _params, ctx) {
  ctx.migas([{ texto: "Módulos" }]);
  const hora = new Date().getHours();
  const saludo = hora < 12 ? "Buenos días" : hora < 19 ? "Buenas tardes" : "Buenas noches";

  const tarjeta = (clave, texto, datos) => {
    const m = MODULOS[clave];
    return `
      <a class="modulo modulo--${clave}" href="${m.inicio}">
        <span class="modulo__icono">${icono(m.icono)}</span>
        <span class="modulo__cuerpo">
          <strong class="modulo__titulo">${esc(m.nombre)}</strong>
          <span class="modulo__texto">${esc(texto)}</span>
          <span class="modulo__datos" data-datos="${clave}">${datos.map((d) => `<span><b>…</b>${esc(d)}</span>`).join("")}</span>
        </span>
        <span class="modulo__entrar">Entrar${icono("derecha")}</span>
      </a>`;
  };

  cont.innerHTML = `
    <div class="saludo">
      <h1>${saludo}, ${esc(ctx.usuario.nombre)}</h1>
      <p>¿Con cuál módulo va a trabajar? Puede cambiar de módulo cuando quiera desde el menú.</p>
    </div>
    <div class="modulos">
      ${tarjeta("usuarios", "Personal municipal, proveedores con sus contactos y catálogos de servicios, catálogos del sistema y división territorial.",
        ["usuarios activos", "proveedores activos"])}
      ${tarjeta("red", "Equipos de red, computadoras, servidores, celulares, impresoras, UPS y más: a quién están asignados, dónde están, quién les da soporte y sus documentos.",
        ["equipos activos", "edificios"])}
      ${ctx.esAdmin ? tarjeta("logs", "Logs de Sophos Firewall, equipos con el agente de Microclaudia y concesiones del DHCP en gráficos: filtro estilo Wireshark, comparación, equipos sin agente, intrusos en la red y cruce con el inventario.",
        ["importaciones", "registros"]) : ""}
    </div>
    ${ctx.esAdmin ? "" : `<div class="aviso aviso--ocre" style="margin-top:20px">${icono("candado")}<span>Su rol permite consultar la información de estos módulos. Los cambios los hace un administrador.</span></div>`}`;

  // Cantidades de cada módulo (si una falla, se deja el guion)
  const pintar = (clave, valores) => {
    cont.querySelectorAll(`[data-datos="${clave}"] b`).forEach((b, i) => { b.textContent = valores[i] ?? "—"; });
  };
  const [usuarios, proveedores, dispositivos, edificios, importaciones] = await Promise.allSettled([
    api("usuarios/", { query: { activo: true } }),
    api("proveedores/", { query: { activo: true } }),
    api("dispositivos/", { query: { activo: true } }),
    api("dispositivos/edificios/"),
    ctx.esAdmin ? api("logs/importaciones/") : Promise.resolve([]),
  ]);
  if (!ctx.vigente()) return;
  const n = (r) => (r.status === "fulfilled" ? r.value.length : null);
  pintar("usuarios", [n(usuarios), n(proveedores)]);
  pintar("red", [n(dispositivos), n(edificios)]);
  if (ctx.esAdmin) {
    const eventos = importaciones.status === "fulfilled"
      ? importaciones.value.reduce((s, x) => s + (Number(x.total_eventos) || 0), 0).toLocaleString("es-CR") : null;
    pintar("logs", [n(importaciones), eventos]);
  }
}

/* =====================================================================
   Inicio del módulo de usuarios y proveedores
   ===================================================================== */
async function vistaInicio(cont, _params, ctx) {
  ctx.migas([{ texto: "Inicio" }]);
  const hora = new Date().getHours();
  const saludo = hora < 12 ? "Buenos días" : hora < 19 ? "Buenas tardes" : "Buenas noches";
  const hoy = new Intl.DateTimeFormat("es-CR", { dateStyle: "full" }).format(new Date());

  cont.innerHTML = `
    <div class="saludo">
      <h1>${saludo}, ${esc(ctx.usuario.nombre)}</h1>
      <p>Hoy es ${esc(hoy)}.</p>
    </div>
    ${ctx.esAdmin ? "" : `<div class="aviso aviso--ocre" style="margin-top:18px">${icono("candado")}<span>Su rol permite consultar la información. Los cambios los hace un administrador; usted sí puede cambiar su propia clave en Mi perfil.</span></div>`}
    <div id="resumen">${cargandoHTML()}</div>
    <div class="dos-columnas">
      <section class="panel">
        <div class="panel__cabeza"><div><h2>Usuarios registrados recientemente</h2></div><a class="btn btn--fantasma btn--sm" href="#/usuarios">Ver todos</a></div>
        <div id="recientes">${cargandoHTML()}</div>
      </section>
      <section class="panel">
        <div class="panel__cabeza"><h2>Accesos rápidos</h2></div>
        <ul class="atajos">${atajos(ctx).join("")}</ul>
      </section>
    </div>
    ${ctx.esAdmin ? `
    <section class="panel" style="margin-top:20px">
      <div class="panel__cabeza"><div><h2>Actividad reciente</h2><p>Últimos cambios en el sistema.</p></div><a class="btn btn--fantasma btn--sm" href="#/auditoria">Ver toda la auditoría</a></div>
      <div class="panel__cuerpo" id="actividad-reciente"></div>
    </section>` : ""}`;

  if (ctx.esAdmin) {
    feedAuditoria(cont.querySelector("#actividad-reciente"), {}, { limite: 8, paginar: false })
      .catch((e) => { cont.querySelector("#actividad-reciente").innerHTML = errorHTML(e.message); });
  }

  const [usuarios, proveedores, departamentos] = await Promise.all([
    api("usuarios/", { query: { activo: "" } }),
    api("proveedores/", { query: { activo: true } }),
    filasCatalogo("departamentos"),
  ]);
  if (!ctx.vigente()) return;

  const activos = usuarios.filter((u) => u.activo).length;
  cont.querySelector("#resumen").outerHTML = `
    <nav class="resumen" aria-label="Resumen">
      <a href="#/usuarios"><b>${activos}</b><span>Usuarios activos</span></a>
      <a href="#/usuarios"><b>${usuarios.length - activos}</b><span>Usuarios inactivos</span></a>
      <a href="#/proveedores"><b>${proveedores.length}</b><span>Proveedores activos</span></a>
      <a href="#/catalogos/departamentos"><b>${departamentos.length}</b><span>Departamentos</span></a>
    </nav>`;

  const recientes = [...usuarios]
    .sort((a, b) => String(b.creado_en).localeCompare(String(a.creado_en)))
    .slice(0, 6);
  const caja = cont.querySelector("#recientes");
  if (!recientes.length) {
    caja.innerHTML = vacioHTML({ icono: "usuarios", titulo: "Todavía no hay usuarios" });
    return;
  }
  caja.innerHTML = tablaHTML({
    clicable: true,
    filas: recientes,
    columnas: [
      { titulo: "Usuario", html: (u) => `<div class="persona">${avatarHTML(u)}<div><a href="#/usuarios/${u.id}"><strong>${esc(nombreCompleto(u))}</strong></a><span class="secundario">${esc(u.departamento || "Sin departamento")}</span></div></div>` },
      { titulo: "Registrado", html: (u) => `<span class="secundario">${esc(fecha(u.creado_en))}</span>` },
    ],
  });
  caja.addEventListener("click", (ev) => {
    const r = eventoFila(ev, recientes);
    if (r && !ev.target.closest("a")) location.hash = `#/usuarios/${r.fila.id}`;
  });
}

function atajos(ctx) {
  const item = (href, ic, titulo, texto) =>
    `<li><a href="${href}">${icono(ic)}<span><strong>${esc(titulo)}</strong><small>${esc(texto)}</small></span>${icono("derecha")}</a></li>`;
  if (ctx.esAdmin) {
    return [
      item("#/usuarios/nuevo", "usuario-mas", "Crear un usuario", "Datos, acceso, ubicación y contactos"),
      item("#/proveedores/nuevo", "proveedor", "Registrar un proveedor", "Datos, categoría, contactos y catálogo"),
      item("#/catalogos/categorias-proveedores", "etiqueta", "Categorías de proveedores", "Bienes y servicios"),
      item("#/perfil/seguridad", "llave", "Cambiar mi clave", "Desde Mi perfil"),
    ];
  }
  return [
    item("#/proveedores", "proveedor", "Directorio de proveedores", "Contactos y catálogos de servicios"),
    item("#/usuarios", "usuarios", "Directorio de usuarios", "Consulta de personal"),
    item("#/perfil/seguridad", "llave", "Cambiar mi clave", "Desde Mi perfil"),
    item("#/perfil", "usuario", "Mis datos", "Información de su cuenta"),
  ];
}

/* =====================================================================
   Relieve del inicio de sesión: curvas de nivel generadas
   ===================================================================== */
function curvaCerrada(puntos) {
  // Catmull-Rom cerrada convertida a curvas Bézier
  const n = puntos.length;
  let d = `M${puntos[0][0].toFixed(1)},${puntos[0][1].toFixed(1)}`;
  for (let i = 0; i < n; i++) {
    const p0 = puntos[(i - 1 + n) % n], p1 = puntos[i], p2 = puntos[(i + 1) % n], p3 = puntos[(i + 2) % n];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6];
    d += `C${c1[0].toFixed(1)},${c1[1].toFixed(1)} ${c2[0].toFixed(1)},${c2[1].toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`;
  }
  return `${d}Z`;
}

let relieveDibujado = false;
function dibujarRelieve() {
  const svg = $("#relieve");
  const { width: w, height: h } = svg.getBoundingClientRect();
  if (!w || !h) return;
  svg.setAttribute("viewBox", `0 0 ${w} ${h}`);

  const cimas = [
    { x: w * 0.8, y: h * 0.4, anillos: 15, paso: Math.max(w, h) * 0.05, fase: 0.4 },
    { x: w * 0.12, y: h * 1.02, anillos: 8, paso: Math.max(w, h) * 0.045, fase: 2.1 },
  ];
  let html = "";
  let orden = 0;
  for (const c of cimas) {
    for (let k = 1; k <= c.anillos; k++) {
      const r = k * c.paso;
      const puntos = [];
      for (let j = 0; j < 48; j++) {
        const t = (j / 48) * Math.PI * 2;
        const f = 1
          + 0.16 * Math.sin(3 * t + c.fase + k * 0.17)
          + 0.08 * Math.sin(5 * t - c.fase * 2 - k * 0.11)
          + 0.04 * Math.sin(9 * t + k * 0.3);
        puntos.push([c.x + Math.cos(t) * r * f * 1.25, c.y + Math.sin(t) * r * f]);
      }
      const cota = c === cimas[0] && k === 6 ? ' class="cota"' : "";
      html += `<path${cota} style="--retraso:${(orden++ * 70)}ms" d="${curvaCerrada(puntos)}"/>`;
    }
  }
  svg.innerHTML = html;

  if (!relieveDibujado) {
    svg.querySelectorAll("path").forEach((p) => p.style.setProperty("--largo", Math.ceil(p.getTotalLength())));
    svg.classList.add("dibujar");
    relieveDibujado = true;
  } else {
    svg.classList.remove("dibujar");
  }
}
window.addEventListener("resize", debounce(() => { if (!pantallaLogin.hidden) dibujarRelieve(); }, 200));

/* =====================================================================
   Inicio de la aplicación
   ===================================================================== */
(async function iniciar() {
  const guardada = sesion.leer();
  if (!guardada?.token) return mostrarLogin();
  try {
    const perfil = await api("usuarios/yo/");
    sesion.guardar({ ...guardada, usuario: perfil });
    entrar(perfil);
  } catch (e) {
    sesion.borrar();
    mostrarLogin(e.estado === 401 ? "Su sesión expiró. Inicie sesión de nuevo." : e.message);
  }
})();
