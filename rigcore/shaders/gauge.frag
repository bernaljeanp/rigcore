#version 440
// Indicador circular de Rigcore (estilo instrumento), en una sola pasada de GPU:
// pista, arco de valor, marcas de escala menores/mayores y aguja.
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
    float ticks;       // nº de divisiones (0 = sin marcas)
    float majorEvery;  // cada cuántas divisiones va una marca mayor
    float glow;        // halo suave (0 = ninguno)
    float needle;      // 1 = aguja radial al final del arco
    vec2 res;          // tamaño del item (px)
    vec4 valueColor;
    vec4 trackColor;
    vec4 tickColor;
};

const float TAU = 6.28318530718;

void over(inout vec4 acc, vec3 rgb, float a) {
    acc = vec4(rgb * a, a) + acc * (1.0 - a);
}

vec2 polar(vec2 c, float r, float a) { return c + r * vec2(cos(a), sin(a)); }

// Distancia a un arco de radio r entre startAngle y startAngle + len·sweep (extremos rectos).
float arcDist(vec2 p, vec2 c, float r, float t, float len, float hw) {
    float radial = abs(length(p - c) - r);
    if (t <= len) return radial;
    // Fuera del tramo: distancia a los extremos (corte recto, como una barra de medición).
    vec2 e0 = polar(c, r, startAngle);
    vec2 e1 = polar(c, r, startAngle + len * sweep);
    return min(length(p - e0), length(p - e1)) + hw;
}

void main() {
    vec2 p = qt_TexCoord0 * res;
    vec2 c = res * 0.5;
    vec2 d = p - c;
    float dist = length(d);
    float R = min(res.x, res.y) * 0.5 - inset;
    float aa = max(fwidth(dist), 0.6);

    float ang = atan(d.y, d.x);
    float t = mod(ang - startAngle + 2.0 * TAU, TAU) / sweep;
    float prog = clamp(progress, 0.0, 1.0);
    float hw = thickness * 0.5;

    vec4 acc = vec4(0.0);

    // Marcas de escala, por fuera del arco.
    if (ticks > 0.5 && t <= 1.0 + 0.5 / ticks) {
        float fi = t * ticks;
        float i = floor(fi + 0.5);
        if (i >= 0.0 && i <= ticks) {
            bool major = mod(i, majorEvery) < 0.5;
            float r1 = R + hw + 6.0;
            float r2 = r1 + (major ? 10.0 : 5.0);
            float across = abs(fi - i) * (sweep / ticks) * dist;
            float w = major ? 0.75 : 0.5;
            float m = (1.0 - smoothstep(w - aa * 0.5, w + aa * 0.5, across))
                    * smoothstep(r1 - aa, r1, dist) * (1.0 - smoothstep(r2, r2 + aa, dist));
            bool passed = prog > 0.002 && i / ticks <= prog + 0.0001;
            vec3 col = passed ? valueColor.rgb : tickColor.rgb;
            float a = passed ? (major ? 1.0 : 0.75) : (major ? tickColor.a : tickColor.a * 0.55);
            over(acc, col, m * a);
        }
    }

    // Pista.
    float dTrack = arcDist(p, c, R, t, 1.0, hw);
    over(acc, trackColor.rgb, trackColor.a * (1.0 - smoothstep(hw - aa, hw, dTrack)));

    if (prog > 0.002) {
        float dv = arcDist(p, c, R, t, prog, hw);
        if (glow > 0.0) {
            float o = max(dv - hw, 0.0);
            over(acc, valueColor.rgb, glow * 0.35 * exp(-o / (thickness * 1.2))
                                       * (1.0 - smoothstep(thickness * 2.0, thickness * 3.0, o)));
        }
        over(acc, valueColor.rgb, 1.0 - smoothstep(hw - aa, hw, dv));

        // Aguja: segmento radial que cruza el arco en el valor actual.
        if (needle > 0.5) {
            float a = startAngle + prog * sweep;
            vec2 dir = vec2(cos(a), sin(a));
            float along = dot(d, dir);
            float perp = abs(d.x * dir.y - d.y * dir.x);
            float inner = R - hw - 10.0, outer = R + hw + 18.0;
            float n = (1.0 - smoothstep(0.9, 0.9 + aa, perp))
                    * smoothstep(inner - aa, inner, along) * (1.0 - smoothstep(outer, outer + aa, along));
            over(acc, valueColor.rgb, n);
        }
    }

    fragColor = acc * qt_Opacity;
}
