// Sistema de diseño "Instrumento".
// Principios: grafito plano, separación con líneas de 1 px, cifras tabulares,
// y UN color de señal (ámbar) reservado a lo que exige atención.
.pragma library

// Superficies
var bg       = "#121315"   // grafito base
var bgRaised = "#17181B"   // zonas interactivas en hover
var rule     = "#26282C"   // líneas divisorias de 1 px
var ruleHi   = "#34373C"   // pistas y marcas inactivas

// Texto (blanco y grises cálidos, nunca blanco puro)
var ink      = "#E8E4DC"
var ink2     = "#9A968E"
var ink3     = "#5E5B56"

// Señal
var amber    = "#FFB020"   // activo, boost, temperatura alta
var red      = "#FF5A45"   // crítico
var steel    = "#7FA6BC"   // segunda serie de datos (GPU)
var ok       = "#8FCB8F"   // estado correcto (muy contenido)

// Tipografía
var sans     = "IBM Plex Sans Condensed"
var mono     = "IBM Plex Mono"

// Medidas
var pad      = 22
var labelSize = 12

// Color de temperatura: neutro hasta que importa.
function tempColor(t) {
    if (t >= 92) return red
    if (t >= 82) return amber
    return ink
}
