#version 440
// Indicador circular de Vórtice, dibujado en una sola pasada en la GPU:
// pista, arco con degradado, halo, brillo especular, marcas de escala y punto final.
// Animar solo cambia el uniform `progress`: la CPU no regenera geometría.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;    // 0..1
    float thickness;   // grosor del arco (px)
    float inset;       // margen desde el borde hasta el centro del arco (px)
    float startAngle;  // radianes, 0 = derecha, sentido horario
    float sweep;       // radianes
    float ticks;       // nº de marcas (0 = sin marcas)
    float glow;        // intensidad del halo
    vec2 res;          // tamaño del item (px)
    vec4 colorA;
    vec4 colorB;
};

const float TAU = 6.28318530718;

// Composición "over" con alfa premultiplicado.
void over(inout vec4 acc, vec3 rgb, float a) {
    acc = vec4(rgb * a, a) + acc * (1.0 - a);
}

vec2 polar(vec2 c, float r, float a) { return c + r * vec2(cos(a), sin(a)); }

// Distancia a un arco [start, start + len·sweep] de radio r, con extremos redondeados.
float arcDist(vec2 p, vec2 c, float r, float t, float len) {
    if (t <= len) return abs(length(p - c) - r);
    vec2 e0 = polar(c, r, startAngle);
    vec2 e1 = polar(c, r, startAngle + len * sweep);
    return min(length(p - e0), length(p - e1));
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec2 c = res * 0.5;
    vec2 d = p - c;
    float dist = length(d);
    float R = min(res.x, res.y) * 0.5 - inset;
    float aa = max(fwidth(dist), 0.5);

    // Posición angular normalizada sobre la escala (0 = inicio, 1 = fin).
    float ang = atan(d.y, d.x);
    float t = mod(ang - startAngle + 2.0 * TAU, TAU) / sweep;
    float prog = clamp(progress, 0.0, 1.0);
    float hw = thickness * 0.5;

    vec4 acc = vec4(0.0);

    // Marcas de escala exteriores.
    if (ticks > 0.5 && t <= 1.0 + 0.5 / ticks) {
        float fi = t * ticks;
        float i = floor(fi + 0.5);
        if (i >= 0.0 && i <= ticks) {
            bool major = mod(i, 9.0) < 0.5;
            float r1 = R + hw + 7.0;
            float r2 = r1 + (major ? 7.0 : 4.0);
            float across = abs(fi - i) * (sweep / ticks) * dist;   // px a la marca
            float w = major ? 0.8 : 0.55;
            float m = (1.0 - smoothstep(w - aa * 0.5, w + aa, across))
                    * smoothstep(r1 - aa, r1, dist) * (1.0 - smoothstep(r2, r2 + aa, dist));
            bool lit = prog > 0.002 && i <= floor(prog * ticks + 0.0001);
            vec3 col = lit ? colorB.rgb : vec3(1.0);
            float a = lit ? (major ? 0.9 : 0.55) : (major ? 0.22 : 0.08);
            over(acc, col, m * a);
        }
        // Círculo interior fino.
        float rin = R - thickness - 6.0;
        over(acc, vec3(1.0), 0.05 * (1.0 - smoothstep(0.5, 0.5 + aa, abs(dist - rin))));
    }

    // Pista.
    float dTrack = arcDist(p, c, R, t, 1.0);
    over(acc, vec3(1.0), 0.055 * (1.0 - smoothstep(hw - aa, hw, dTrack)));

    if (prog > 0.002) {
        float dv = arcDist(p, c, R, t, prog);
        float g = clamp(t / prog, 0.0, 1.0);
        if (t > prog) g = (length(p - polar(c, R, startAngle)) < length(p - polar(c, R, startAngle + prog * sweep))) ? 0.0 : 1.0;
        vec3 col = mix(colorA.rgb, colorB.rgb, g);

        // Halo: caída exponencial fuera del arco.
        float out_ = max(dv - hw, 0.0);
        float h = exp(-out_ / (thickness * 0.9)) * glow
                * (1.0 - smoothstep(thickness * 2.0, thickness * 3.2, out_));   // alcance limitado
        over(acc, col, h * 0.55);

        // Arco nítido.
        float body = 1.0 - smoothstep(hw - aa, hw, dv);
        over(acc, col, body);

        // Brillo especular en la parte interior del arco.
        if (t <= prog) {
            float rs = R - thickness * 0.18;
            float sw = thickness * 0.13;
            over(acc, vec3(1.0), 0.26 * (1.0 - smoothstep(sw - aa, sw, abs(dist - rs))) * body);
        }

        // Punto final luminoso.
        vec2 e = polar(c, R, startAngle + prog * sweep);
        float de = length(p - e);
        float dotR = thickness * 0.36;
        float od = max(de - dotR, 0.0);
        over(acc, colorB.rgb, exp(-od / (thickness * 0.5)) * 0.6 * glow
                              * (1.0 - smoothstep(thickness * 1.5, thickness * 2.5, od)));
        over(acc, vec3(1.0), 1.0 - smoothstep(dotR - aa, dotR, de));
    }

    fragColor = acc * qt_Opacity;
}
