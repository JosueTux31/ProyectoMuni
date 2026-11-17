// Exportar a CSV (Excel): la lista de equipos y los puertos de los switches.
// Son las mismas funciones que usa el módulo de análisis de logs; cuando ese
// módulo se una a este sistema, dispositivos.js y switch.js las toman de
// logs_ui.js y este archivo se quita.

export function descargarTexto(texto, nombre, tipo = "text/csv;charset=utf-8") {
  const url = URL.createObjectURL(new Blob([texto], { type: tipo }));
  const a = document.createElement("a");
  a.href = url;
  a.download = nombre;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export const marcaArchivo = () => new Date().toISOString().slice(0, 19).replace(/[-:]/g, "").replace("T", "_");

/**
 * Una celda de un CSV para Excel (separado por punto y coma). Un texto que
 * empieza con = + - @ se escribe con un apóstrofo delante para que Excel no
 * lo ejecute como fórmula: los nombres y las notas los escribe el personal.
 * Los números (-5, -3,5) y las rayas solas (-) quedan como están.
 */
export function celdaCsv(v) {
  let t = String(v ?? "");
  if (/^[=+\-@\t\r]/.test(t) && !/^(-?\d+([.,]\d+)?|-+)$/.test(t)) t = `'${t}`;
  return /[";\r\n]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t;
}

/** Filas (listas de valores) -> texto CSV con BOM para que Excel abra bien las tildes. */
export const textoCsv = (filas) => `﻿${filas.map((f) => f.map(celdaCsv).join(";")).join("\r\n")}\r\n`;
