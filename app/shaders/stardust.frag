#version 460 core

// Voile laiteux de la traînée d'étoiles — le pendant calme de l'aurore.
// Une lueur blanche en arc qui ondule à peine, dont le haut se teinte de
// turquoise pour fondre dans le bas du ruban vert. Même famille de bruit
// que aurora.frag : rien de périodique, aucun banding.

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;  // taille logique du canvas
uniform float uTime; // secondes écoulées + graine de lancement
uniform float uArc;  // position verticale de l'arc (fraction de la hauteur)

out vec4 fragColor;

const vec3 kMilk = vec3(0.930, 0.950, 0.900); // blanc chaud, cœur du voile
const vec3 kTint = vec3(0.420, 0.860, 0.800); // turquoise vers l'aurore

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 4; i++) {
    v += amp * vnoise(p);
    p = p * 2.03 + vec2(17.0, 9.2);
    amp *= 0.5;
  }
  return v;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  float h = uSize.y;
  float u = p.x / uSize.x;
  float t = uTime;

  // Arc légèrement bombé au centre, soulevé par une houle très lente.
  float lift = fbm(vec2(u * 1.9 + t * 0.014, t * 0.016 + 4.2)) - 0.5;
  float yc = h * uArc - h * 0.10 * sin(3.14159265 * u) + lift * h * 0.10;

  // Nappes de brillance qui dérivent le long de l'arc — avec de vrais
  // creux entre elles : la lueur est faite de taches douces, jamais une
  // barre continue d'un bord à l'autre.
  float bright = fbm(vec2(u * 2.3 - t * 0.019, t * 0.012 + 9.3));
  bright = 0.15 + 1.15 * smoothstep(0.40, 0.78, bright);

  // Profil vertical asymétrique : longue traîne vers le haut (elle va à la
  // rencontre de l'aurore), bord bas court et doux. Les sigmas sont bornés
  // par la place disponible : la gaussienne meurt AVANT les bords du
  // canvas, même sur une petite bande (sinon → rectangle coupé net).
  float dy = p.y - yc;
  float sUp = min(h * 0.42, yc / 2.2);
  float sDown = min(h * 0.10, (h - yc) / 2.2);
  float s = dy < 0.0 ? sUp : sDown;
  float fall = exp(-dy * dy / (2.0 * s * s));

  // Blanc chaud au cœur ; plus on monte, plus le voile prend la teinte de
  // l'aurore — c'est là que les deux lueurs se mélangent.
  float rise = clamp(-dy / (h * 0.55), 0.0, 1.0);
  vec3 col = mix(kMilk, kTint, smoothstep(0.15, 0.90, rise));

  float a = fall * bright * 0.115;
  // Extinction douce aux quatre bords du canvas (filet de sécurité —
  // le profil ci-dessus s'éteint normalement avant).
  a *= smoothstep(h, h * 0.84, p.y);
  a *= smoothstep(0.0, h * 0.10, p.y);
  a *= smoothstep(0.0, 0.06, u) * smoothstep(1.0, 0.94, u);
  a += (hash(p + vec2(t, -t)) - 0.5) * (1.5 / 255.0);
  a = clamp(a, 0.0, 1.0);

  fragColor = vec4(col * a, a);
}
