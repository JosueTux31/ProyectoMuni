// Elegir una foto, encuadrarla en un círculo (zoom y arrastre) y devolverla
// como un JPG cuadrado de 512 px listo para subir.
import { esc, icono } from "./ui.js";

const LADO_SALIDA = 512;
const MAX_MB_ORIGINAL = 25;

function abrirSelector() {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = "image/jpeg,image/png,image/webp,image/*";
    input.hidden = true;
    document.body.appendChild(input);
    const terminar = (archivo) => { input.remove(); resolve(archivo); };
    input.addEventListener("change", () => terminar(input.files[0] || null), { once: true });
    input.addEventListener("cancel", () => terminar(null), { once: true });
    input.click();
  });
}

function cargarImagen(archivo) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(archivo);
    const img = new Image();
    img.onload = () => resolve({ img, url });
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error("formato")); };
    img.src = url;
  });
}

/**
 * Abre el selector de archivos y luego el encuadre.
 * Devuelve un File JPG (512×512) o null si la persona cancela.
 * `alError(mensaje)` recibe los problemas (archivo inválido o muy grande).
 */
export async function elegirFoto({ titulo = "Foto de perfil", alError } = {}) {
  const archivo = await abrirSelector();
  if (!archivo) return null;
  if (archivo.size > MAX_MB_ORIGINAL * 1024 * 1024) {
    alError?.(`La imagen pesa más de ${MAX_MB_ORIGINAL} MB.`);
    return null;
  }
  let cargada;
  try {
    cargada = await cargarImagen(archivo);
  } catch {
    alError?.("No se pudo leer la imagen. Use una foto JPG, PNG o WEBP.");
    return null;
  }
  try {
    return await encuadrar(cargada.img, titulo);
  } finally {
    URL.revokeObjectURL(cargada.url);
  }
}

function encuadrar(img, titulo) {
  return new Promise((resolve) => {
    const dialogo = document.createElement("dialog");
    dialogo.className = "modal modal--foto";
    dialogo.setAttribute("aria-labelledby", "foto-titulo");
    dialogo.innerHTML = `
      <div class="modal__cabeza">
        <h2 id="foto-titulo">${esc(titulo)}</h2>
        <button type="button" class="btn-icono" data-cancelar aria-label="Cerrar">${icono("cerrar")}</button>
      </div>
      <div class="modal__cuerpo">
        <p>Arrastre la imagen para encuadrarla y use el control para acercarla.</p>
        <div class="encuadre" data-encuadre>
          <canvas width="560" height="560" aria-label="Vista previa de la foto"></canvas>
          <span class="encuadre__mascara" aria-hidden="true"></span>
        </div>
        <label class="encuadre__zoom">
          ${icono("imagen", "ic--sm")}
          <span class="visualmente-oculto">Acercar</span>
          <input type="range" min="1" max="3" step="0.01" value="1" data-zoom>
          ${icono("imagen")}
        </label>
      </div>
      <div class="modal__pie">
        <button type="button" class="btn btn--secundario" data-cancelar>Cancelar</button>
        <button type="button" class="btn btn--primario" data-usar>${icono("check")}Usar esta foto</button>
      </div>`;
    document.body.appendChild(dialogo);

    const canvas = dialogo.querySelector("canvas");
    const ctx2d = canvas.getContext("2d");
    const zoom = dialogo.querySelector("[data-zoom]");
    const L = canvas.width;
    const base = Math.max(L / img.naturalWidth, L / img.naturalHeight);
    let z = 1;
    let dx = 0;
    let dy = 0;
    let resultado = null;

    const medidas = (lado) => {
      const f = lado / L;
      const s = base * z * f;
      const w = img.naturalWidth * s;
      const h = img.naturalHeight * s;
      return { w, h, x: lado / 2 - w / 2 + dx * f, y: lado / 2 - h / 2 + dy * f };
    };

    function limitar() {
      const s = base * z;
      const maxX = Math.max(0, (img.naturalWidth * s - L) / 2);
      const maxY = Math.max(0, (img.naturalHeight * s - L) / 2);
      dx = Math.min(maxX, Math.max(-maxX, dx));
      dy = Math.min(maxY, Math.max(-maxY, dy));
    }

    function dibujar() {
      limitar();
      const m = medidas(L);
      ctx2d.fillStyle = "#fff";
      ctx2d.fillRect(0, 0, L, L);
      ctx2d.drawImage(img, m.x, m.y, m.w, m.h);
    }

    zoom.addEventListener("input", () => { z = Number(zoom.value); dibujar(); });

    // Arrastrar con mouse, dedo o lápiz
    let arrastre = null;
    canvas.addEventListener("pointerdown", (ev) => {
      canvas.setPointerCapture(ev.pointerId);
      const escala = L / canvas.getBoundingClientRect().width;
      arrastre = { x: ev.clientX, y: ev.clientY, dx, dy, escala };
    });
    canvas.addEventListener("pointermove", (ev) => {
      if (!arrastre) return;
      dx = arrastre.dx + (ev.clientX - arrastre.x) * arrastre.escala;
      dy = arrastre.dy + (ev.clientY - arrastre.y) * arrastre.escala;
      dibujar();
    });
    const soltar = () => { arrastre = null; };
    canvas.addEventListener("pointerup", soltar);
    canvas.addEventListener("pointercancel", soltar);
    canvas.addEventListener("wheel", (ev) => {
      ev.preventDefault();
      z = Math.min(3, Math.max(1, z - ev.deltaY * 0.0015));
      zoom.value = String(z);
      dibujar();
    }, { passive: false });

    dialogo.querySelectorAll("[data-cancelar]").forEach((b) => b.addEventListener("click", () => dialogo.close()));
    dialogo.querySelector("[data-usar]").addEventListener("click", () => {
      const salida = document.createElement("canvas");
      salida.width = LADO_SALIDA;
      salida.height = LADO_SALIDA;
      const c = salida.getContext("2d");
      c.fillStyle = "#fff";
      c.fillRect(0, 0, LADO_SALIDA, LADO_SALIDA);
      const m = medidas(LADO_SALIDA);
      c.imageSmoothingQuality = "high";
      c.drawImage(img, m.x, m.y, m.w, m.h);
      salida.toBlob((blob) => {
        resultado = blob ? new File([blob], "foto.jpg", { type: "image/jpeg" }) : null;
        dialogo.close();
      }, "image/jpeg", 0.9);
    });
    dialogo.addEventListener("close", () => { dialogo.remove(); resolve(resultado); });

    dibujar();
    dialogo.showModal();
    dialogo.querySelector("[data-usar]").focus();
  });
}
