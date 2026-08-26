#version 460 core

// Aurore boréale de la Home — nappe de lumière calculée pixel par pixel.
// Remplace l'ancien collage de halos radiaux (banding visible) par un
// ruban continu déformé par du bruit fractal : jamais deux fois la même
// forme, aucun motif périodique. Palette inchangée : vert (oxygène) à la
// base, turquoise Quieto au corps, violet dissous au sommet.

precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;  // taille logique du canvas (largeur écran × 260)
uniform float uTime; // secondes écoulées + graine aléatoire de lancement

out vec4 fragColor;

const vec3 kGreen  = vec3(0.310, 0.910, 0.659); // 0xFF4FE8A8
const vec3 kTeal   = vec3(0.361, 0.878, 0.847); // 0xFF5CE0D8 (accent)
const vec3 kViolet = vec3(0.561, 0.482, 0.910); // 0xFF8F7BE8

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

// Bruit de valeur, interpolation quintique (dérivée continue → pas de
// cassure visible dans les dégradés).
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
  float u = p.x / uSize.x;
  float t = uTime;

  // Étirement horizontal irrégulier : casse la régularité gauche-droite
  // (une vraie aurore se tasse et s'étire par endroits).
  float warp = fbm(vec2(u * 2.2 + t * 0.013, t * 0.021)) - 0.5;
  float uu = u + warp * 0.35;

  // Ligne médiane du ruban : grande houle + détail, pilotées par le
  // bruit — amples, jamais périodiques. Le canvas part du haut de
  // l'écran, l'altitude intègre ~50 px de barre d'état.
  float big = fbm(vec2(uu * 1.5 + t * 0.017, t * 0.011 + 3.7)) - 0.5;
  float detail = fbm(vec2(uu * 4.0 - t * 0.023, t * 0.017 + 8.1)) - 0.5;
  float center = 165.0 + big * 70.0 + detail * 22.0;

  // Hauteur locale du ruban (respiration lente, indépendante de la houle).
  float breath = 0.75 + 0.5 * fbm(vec2(uu * 1.8 + t * 0.019, t * 0.013 + 5.5));
  float H = 135.0 * breath;

  // Nappes brillantes qui dérivent le long du ruban.
  float bright = fbm(vec2(uu * 2.8 - t * 0.021, t * 0.015 + 11.0));
  bright = 0.35 + 0.9 * smoothstep(0.35, 0.75, bright);

  // Profil vertical : bord bas doux (gaussienne), sommet qui s'évapore
  // lentement vers le violet.
  float dy = p.y - center; // > 0 sous la ligne médiane
  float h = max(-dy, 0.0) / H;
  float fall = dy >= 0.0
      ? exp(-dy * dy / (2.0 * 30.0 * 30.0))
      : exp(-pow(h, 1.7) * 2.6);

  vec3 col = mix(kGreen, kTeal, smoothstep(0.05, 0.45, h));
  col = mix(col, kViolet, smoothstep(0.40, 0.95, h));

  float a = fall * bright * 0.34;
  // Extinction garantie avant le bord bas du canvas (aucune coupure nette).
  a *= smoothstep(uSize.y, uSize.y - 60.0, p.y);
  // Micro-bruit temporel ±0,5/255 : dissout le banding des dégradés
  // sombres, invisible à l'œil.
  a += (hash(p + vec2(t, -t)) - 0.5) * (1.5 / 255.0);
  a = clamp(a, 0.0, 1.0);

  // Flutter attend une couleur en alpha prémultiplié.
  fragColor = vec4(col * a, a);
}
