// Zoom de imágenes al estilo de las tiendas en línea, visor a pantalla
// completa y ventana de vista previa de documentos.
import { esc, icono } from "./ui.js";

const conMouse = () => window.matchMedia("(hover: hover) and (pointer: fine)").matches;

/** Rectángulo donde realmente se dibuja la imagen (object-fit: contain/cover). */
function areaDibujada(img) {
  const caja = img.getBoundingClientRect();
  const nw = img.naturalWidth || caja.width;
  const nh = img.naturalHeight || caja.height;
  const ajuste = getComputedStyle(img).objectFit;
  const escala = ajuste === "cover" ? Math.max(caja.width / nw, caja.height / nh)
    : ajuste === "contain" ? Math.min(caja.width / nw, caja.height / nh)
      : caja.width / nw;
  const w = ajuste === "fill" || !ajuste ? caja.width : nw * escala;
  const h = ajuste === "fill" || !ajuste ? caja.height : nh * escala;
  return { x: caja.left + (caja.width - w) / 2, y: caja.top + (caja.height - h) / 2, w, h };
}

/**
 * Zoom al pasar el mouse: aparece una lupa sobre la imagen y, al lado,
 * un panel con esa zona ampliada. Si no hay espacio al lado (pantallas
 * angostas), la ampliación se muestra encima de la misma imagen.
 * Con dedo (sin mouse) no hace nada: use abrirVisor() al tocar.
 */
export function zoomAlPasar(img, { tamPanel = 420 } = {}) {
  if (!img) return;
  let lupa = null;
  let panel = null;

  function quitar() {
    lupa?.remove();
    panel?.remove();
    lupa = null;
    panel = null;
  }

  function mover(ev) {
    if (!conMouse() || !img.complete || !img.naturalWidth) return;
    const a = areaDibujada(img);
    if (ev.clientX < a.x || ev.clientX > a.x + a.w || ev.clientY < a.y || ev.clientY > a.y + a.h) {
      quitar();
      return;
    }
    const espacioDerecha = window.innerWidth - (a.x + a.w) - 24;
    const alLado = espacioDerecha >= Math.min(tamPanel, 260);
    const panelLado = alLado ? Math.min(tamPanel, espacioDerecha) : Math.min(a.w, a.h);
    // Aumento: la resolución real de la foto (como Amazon), mínimo 2x y máximo 4x
    const aumento = Math.min(4, Math.max(2, img.naturalWidth / a.w));
    const lado = Math.max(30, Math.min(a.w, a.h, panelLado / aumento));    // lupa cuadrada
    const factor = panelLado / lado;

    if (!lupa) {
      lupa = document.createElement("div");
      lupa.className = "zoom-lupa";
      panel = document.createElement("div");
      panel.className = "zoom-panel";
      panel.setAttribute("aria-hidden", "true");
      document.body.append(lupa, panel);
    }

    // Lupa centrada en el cursor, sin salirse de la imagen
    const lx = Math.min(Math.max(ev.clientX - lado / 2, a.x), a.x + a.w - lado);
    const ly = Math.min(Math.max(ev.clientY - lado / 2, a.y), a.y + a.h - lado);
    Object.assign(lupa.style, { left: `${lx}px`, top: `${ly}px`, width: `${lado}px`, height: `${lado}px` });

    Object.assign(panel.style, {
      width: `${panelLado}px`,
      height: `${panelLado}px`,
      left: `${alLado ? a.x + a.w + 16 : a.x + (a.w - panelLado) / 2}px`,
      top: `${alLado ? Math.max(8, Math.min(a.y, window.innerHeight - panelLado - 8)) : a.y + (a.h - panelLado) / 2}px`,
      backgroundImage: `url("${img.currentSrc || img.src}")`,
      backgroundSize: `${a.w * factor}px ${a.h * factor}px`,
      backgroundPosition: `${-(lx - a.x) * factor}px ${-(ly - a.y) * factor}px`,
    });
    panel.classList.toggle("zoom-panel--encima", !alLado);
  }

  img.addEventListener("mousemove", mover);
  img.addEventListener("mouseleave", quitar);
  window.addEventListener("scroll", quitar, { passive: true });
  window.addEventListener("hashchange", quitar);
  img.classList.add("con-zoom");
}

/** Abre la imagen grande en una ventana; al mover el mouse (o tocar) se acerca. */
export function abrirVisor(src, { titulo = "Imagen", alt = "" } = {}) {
  const dialogo = document.createElement("dialog");
  dialogo.className = "modal visor";
  dialogo.setAttribute("aria-label", titulo);
  dialogo.innerHTML = `
    <div class="modal__cabeza">
      <h2>${esc(titulo)}</h2>
      <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono("cerrar")}</button>
    </div>
    <div class="visor__marco" data-marco>
      <img src="${esc(src)}" alt="${esc(alt)}" draggable="false">
    </div>
    <p class="visor__ayuda">${conMouse() ? "Pase el mouse sobre la imagen para acercarla." : "Toque la imagen para acercarla."}</p>`;
  document.body.appendChild(dialogo);

  const marco = dialogo.querySelector("[data-marco]");
  const img = marco.querySelector("img");
  const enfocar = (ev) => {
    const r = marco.getBoundingClientRect();
    img.style.transformOrigin = `${((ev.clientX - r.left) / r.width) * 100}% ${((ev.clientY - r.top) / r.height) * 100}%`;
  };
  if (conMouse()) {
    marco.addEventListener("mouseenter", () => marco.classList.add("acercado"));
    marco.addEventListener("mouseleave", () => marco.classList.remove("acercado"));
    marco.addEventListener("mousemove", enfocar);
  } else {
    marco.addEventListener("click", (ev) => { enfocar(ev); marco.classList.toggle("acercado"); });
  }

  dialogo.querySelector("[data-cerrar]").addEventListener("click", () => dialogo.close());
  dialogo.addEventListener("click", (ev) => { if (ev.target === dialogo) dialogo.close(); });
  dialogo.addEventListener("close", () => dialogo.remove());
  dialogo.showModal();
}

/**
 * Ventana de vista previa de un documento.
 *   obtener: async () => Blob (PDF o imagen)
 *   alDescargar: async () => void (botón Descargar)
 */
export function abrirVistaPrevia({ titulo, nombre = "", obtener, alDescargar }) {
  const dialogo = document.createElement("dialog");
  dialogo.className = "modal vista-previa";
  dialogo.setAttribute("aria-label", titulo);
  dialogo.innerHTML = `
    <div class="modal__cabeza">
      <div><h2>${esc(titulo)}</h2>${nombre ? `<p class="vista-previa__nombre">${esc(nombre)}</p>` : ""}</div>
      <div class="vista-previa__acciones">
        ${alDescargar ? `<button type="button" class="btn btn--secundario btn--sm" data-descargar>${icono("descargar")}Descargar</button>` : ""}
        <button type="button" class="btn-icono" data-cerrar aria-label="Cerrar">${icono("cerrar")}</button>
      </div>
    </div>
    <div class="vista-previa__cuerpo" data-cuerpo><div class="cargando-bloque">Preparando la vista previa…</div></div>`;
  document.body.appendChild(dialogo);

  let url = null;
  const cuerpo = dialogo.querySelector("[data-cuerpo]");
  dialogo.querySelector("[data-cerrar]").addEventListener("click", () => dialogo.close());
  dialogo.querySelector("[data-descargar]")?.addEventListener("click", (ev) => {
    const b = ev.currentTarget;
    b.classList.add("cargando");
    Promise.resolve(alDescargar()).finally(() => b.classList.remove("cargando"));
  });
  dialogo.addEventListener("close", () => { if (url) URL.revokeObjectURL(url); dialogo.remove(); });
  dialogo.showModal();

  (async () => {
    try {
      const blob = await obtener();
      url = URL.createObjectURL(blob);
      if (blob.type.startsWith("image/")) {
        cuerpo.innerHTML = `<div class="vista-previa__imagen"><img src="${url}" alt="${esc(nombre)}"></div>`;
        zoomAlPasar(cuerpo.querySelector("img"), { tamPanel: 360 });
      } else {
        cuerpo.innerHTML = `<iframe class="vista-previa__pdf" src="${url}#view=FitH" title="${esc(titulo)}"></iframe>`;
      }
    } catch (e) {
      cuerpo.innerHTML = `<div class="vacio">${icono("documento")}<strong>No hay vista previa disponible</strong>
        <p>${esc(e.message || "No se pudo abrir el documento.")}</p></div>`;
    }
  })();
}

/**
 * Al pasar el mouse sobre un avatar con foto (listas, auditoría…) muestra
 * la foto más grande junto al cursor. Se activa una vez para toda la página.
 */
export function activarVistaAvatares() {
  if (!conMouse()) return;
  let globo = null;
  let actual = null;

  const ocultar = () => { globo?.remove(); globo = null; actual = null; };

  document.addEventListener("mouseover", (ev) => {
    const avatar = ev.target.closest?.(".avatar.con-imagen:not(.avatar--grande)");
    if (!avatar || avatar === actual || avatar.closest(".lateral, dialog")) return;
    const img = avatar.querySelector("img");
    if (!img) return;
    ocultar();
    actual = avatar;
    globo = document.createElement("div");
    globo.className = `globo-foto${avatar.classList.contains("avatar--logo") ? " globo-foto--logo" : ""}`;
    globo.setAttribute("aria-hidden", "true");
    globo.innerHTML = `<img src="${esc(img.currentSrc || img.src)}" alt="">`;
    document.body.appendChild(globo);
    const r = avatar.getBoundingClientRect();
    const lado = 200;
    const izquierda = r.right + 12 + lado < window.innerWidth ? r.right + 12 : r.left - lado - 12;
    globo.style.left = `${Math.max(8, izquierda)}px`;
    globo.style.top = `${Math.max(8, Math.min(r.top + r.height / 2 - lado / 2, window.innerHeight - lado - 8))}px`;
  });
  document.addEventListener("mouseout", (ev) => {
    if (actual && !actual.contains(ev.relatedTarget)) ocultar();
  });
  window.addEventListener("scroll", ocultar, { passive: true });
  window.addEventListener("hashchange", ocultar);
}
