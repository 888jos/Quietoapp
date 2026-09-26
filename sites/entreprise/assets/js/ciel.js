// Quieto Entreprise — le ciel de l'accueil de l'app, recréé pour le web.
//
// Traduit fidèlement depuis l'app Flutter :
//   - étoiles qui scintillent et étoiles filantes → lib/core/ui/starry_background.dart
//   - aurore boréale                              → shaders/aurora.frag
//   - voile laiteux de la poussière d'étoiles    → shaders/stardust.frag
//   - micro-étoiles de la poussière              → night_sky_header.dart (_StardustPainter)
//   (la lune est en HTML/CSS dans la page : glowing_moon.dart)
//
// Même palette : vert #4FE8A8, turquoise #5CE0D8, violet #8F7BE8.
// Léger : l'aurore est calculée en demi-résolution (elle est toute en
// douceur, ça ne se voit pas) et à 30 images/s ; tout s'arrête quand
// l'onglet est caché ou le ciel hors de l'écran. « Réduire les
// animations » : une seule image fixe, ni scintillement ni étoile filante.
(function () {
  "use strict";

  var requeteReduit = window.matchMedia("(prefers-reduced-motion: reduce)");
  var reduit = requeteReduit.matches;
  var DPR = Math.min(window.devicePixelRatio || 1, 2);
  var DEUX_PI = Math.PI * 2;
  var debut = performance.now();
  // Graine tirée au chargement : l'aurore ne reprend jamais au même endroit.
  var graine = Math.random() * 100;

  // La souris (ordinateur seulement) : le ciel glisse doucement avec elle,
  // chaque plan à sa vitesse, et les étoiles proches se relient.
  // lx/ly suivent x/y avec du retard : le ciel a de l'inertie.
  var pointeurFin = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  var souris = { x: 0.5, y: 0.5, lx: 0.5, ly: 0.5, px: -1e4, py: -1e4, presence: 0, cible: 0, neuve: false };

  // Générateur pseudo-aléatoire à graine fixe : même ciel à chaque image.
  function hasard(g) {
    return function () {
      g = (g + 0x6d2b79f5) | 0;
      var t = Math.imul(g ^ (g >>> 15), 1 | g);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function largeurPage() { return document.documentElement.clientWidth; }

  // ════════════════════════════════════════════════════════════
  // 1. CIEL ÉTOILÉ FIXE, derrière toute la page (StarryBackground)
  // ════════════════════════════════════════════════════════════
  var fond = document.createElement("canvas");
  fond.className = "etoiles";
  fond.setAttribute("aria-hidden", "true");
  document.body.insertBefore(fond, document.body.firstChild);
  var cf = fond.getContext("2d");
  var fW = 0, fH = 0, etoiles = [], filantes = [], prochaineFilante = 2.2;

  function preparerEtoiles() {
    var r = fond.getBoundingClientRect();
    var w = Math.round(r.width), h = Math.round(r.height);
    if (w === fW && h === fH) return false;
    fW = w; fH = h;
    fond.width = Math.round(w * DPR);
    fond.height = Math.round(h * DPR);
    // Même densité que l'app (75 étoiles sur un écran de téléphone).
    var nombre = Math.max(60, Math.min(230, Math.round((w * h) / 4400)));
    var rnd = hasard(717);
    etoiles = [];
    for (var i = 0; i < nombre; i++) {
      var tirage = rnd();
      // Trois plans de profondeur : au défilement, les étoiles proches
      // glissent un peu plus vite que les lointaines.
      var profondeur = tirage < 0.6 ? 0.03 : tirage < 0.9 ? 0.08 : 0.16;
      etoiles.push({
        x: rnd(), y: rnd(),
        r: rnd() * 1.1 + 0.4 + (profondeur > 0.1 ? 0.3 : 0),
        phase: rnd() * DEUX_PI,
        vitesse: 1 + Math.floor(rnd() * 3), // 1, 2 ou 3 cycles par période de 10 s
        d: profondeur,
        // Amplitude du glissement quand la souris bouge (px) : même
        // logique de profondeur, les proches bougent davantage.
        m: profondeur < 0.05 ? 8 : profondeur < 0.1 ? 16 : 28,
      });
    }
    return true;
  }

  // Étoiles filantes : toujours vers le bas-droite (18° à 30°), lentes,
  // une sur trois turquoise. Dans l'app : 5 par période de 24 s ; ici, une
  // de temps en temps (toutes les 7 à 15 s).
  function lancerFilante(t) {
    var angle = 0.32 + Math.random() * 0.2;
    filantes.push({
      t0: t, duree: 3.1 + Math.random() * 0.6,
      x: Math.random() * 0.55, y: Math.random() * 0.5,
      dx: Math.cos(angle), dy: Math.sin(angle),
      couleur: Math.random() < 1 / 3 ? "92,224,216" : "255,255,255",
    });
    prochaineFilante = t + 7 + Math.random() * 8;
  }

  // Constellations : autour de la souris, les étoiles voisines se relient
  // par de fins traits qui s'effacent avec la distance (aucun saut : tout
  // varie en continu avec la position du curseur).
  var RAYON_CONSTELLATION = 170, LIEN_MAX = 95;
  var proches = [];

  function dessinerEtoiles(t, defilement) {
    cf.setTransform(DPR, 0, 0, DPR, 0, 0);
    cf.clearRect(0, 0, fW, fH);
    var cycle = (t / 10) * DEUX_PI;
    var ox = souris.lx - 0.5, oy = souris.ly - 0.5;
    var avecConstellation = souris.presence > 0.01;
    var R = RAYON_CONSTELLATION, zone = R + LIEN_MAX;
    proches.length = 0;

    cf.fillStyle = "#fff";
    for (var i = 0; i < etoiles.length; i++) {
      var s = etoiles[i];
      var y = (s.y * fH - defilement * s.d) % fH;
      if (y < 0) y += fH;
      var x = s.x * fW - ox * s.m;
      y -= oy * s.m;
      var alpha = 0.16 + 0.34 * (0.5 + 0.5 * Math.sin(s.phase + s.vitesse * cycle));
      var rayon = s.r;
      if (avecConstellation) {
        var ddx = x - souris.px, ddy = y - souris.py;
        if (ddx > -zone && ddx < zone && ddy > -zone && ddy < zone) {
          proches.push(x, y);
          var dd = Math.sqrt(ddx * ddx + ddy * ddy);
          if (dd < R) {
            // Les étoiles sous la souris s'éveillent un peu.
            var eveil = Math.pow(1 - (dd / R) * (dd / R), 2) * souris.presence;
            alpha += (0.85 - alpha) * eveil;
            rayon += 0.5 * eveil;
          }
        }
      }
      cf.globalAlpha = alpha;
      cf.beginPath();
      cf.arc(x, y, rayon, 0, DEUX_PI);
      cf.fill();
    }
    cf.globalAlpha = 1;

    if (avecConstellation && proches.length > 2) {
      cf.lineWidth = 0.8;
      for (var a = 0; a < proches.length; a += 2) {
        for (var b = a + 2; b < proches.length; b += 2) {
          var lx = proches[b] - proches[a], ly = proches[b + 1] - proches[a + 1];
          var d = Math.sqrt(lx * lx + ly * ly);
          if (d > LIEN_MAX || d < 4) continue;
          var mx = (proches[a] + proches[b]) / 2 - souris.px;
          var my = (proches[a + 1] + proches[b + 1]) / 2 - souris.py;
          var dm = Math.sqrt(mx * mx + my * my);
          if (dm > R) continue;
          var force = Math.pow(1 - (dm / R) * (dm / R), 2) * (1 - d / LIEN_MAX) * souris.presence;
          cf.strokeStyle = "rgba(190,238,232," + (0.5 * force).toFixed(3) + ")";
          cf.beginPath();
          cf.moveTo(proches[a], proches[a + 1]);
          cf.lineTo(proches[b], proches[b + 1]);
          cf.stroke();
        }
      }
    }

    // Filantes : traînée en fuseau, large et lumineuse à la tête, pointue
    // et transparente à la queue, comme dans l'app.
    var base = Math.min(fW, 1100);
    for (var j = filantes.length - 1; j >= 0; j--) {
      var f = filantes[j];
      var p = (t - f.t0) / f.duree;
      if (p > 1) { filantes.splice(j, 1); continue; }
      var env = Math.pow(Math.sin(p * Math.PI), 1.6);
      var parcours = base * 0.55, trainee = base * 0.24, demi = 2.6;
      var tx = f.x * fW + f.dx * parcours * p, ty = f.y * fH + f.dy * parcours * p;
      var qx = tx - f.dx * trainee, qy = ty - f.dy * trainee;
      var px = -f.dy, py = f.dx;
      var degrade = cf.createLinearGradient(tx, ty, qx, qy);
      degrade.addColorStop(0, "rgba(" + f.couleur + "," + (0.42 * env).toFixed(3) + ")");
      degrade.addColorStop(1, "rgba(" + f.couleur + ",0)");
      cf.fillStyle = degrade;
      cf.beginPath();
      cf.moveTo(tx + px * demi, ty + py * demi);
      cf.lineTo(tx - px * demi, ty - py * demi);
      cf.lineTo(qx, qy);
      cf.closePath();
      cf.fill();
      // Tête : halo doux + petit cœur brillant.
      var halo = cf.createRadialGradient(tx, ty, 0, tx, ty, 7);
      halo.addColorStop(0, "rgba(" + f.couleur + "," + (0.3 * env).toFixed(3) + ")");
      halo.addColorStop(1, "rgba(" + f.couleur + ",0)");
      cf.fillStyle = halo;
      cf.beginPath(); cf.arc(tx, ty, 7, 0, DEUX_PI); cf.fill();
      cf.fillStyle = "rgba(255,255,255," + (0.75 * env).toFixed(3) + ")";
      cf.beginPath(); cf.arc(tx, ty, 1.4, 0, DEUX_PI); cf.fill();
    }
  }

  // ════════════════════════════════════════════════════════════
  // 2. AURORE + POUSSIÈRE D'ÉTOILES en haut de page (.ciel)
  // ════════════════════════════════════════════════════════════
  // Les shaders de l'app, traduits en GLSL ES 1.0 (WebGL 1, partout).
  // La scène garde exactement les proportions de l'app (canvas de 330 px
  // de haut, ruban centré à 165 px, poussière à ~225 px) multipliées par
  // uK, pour tenir la hauteur d'un écran d'ordinateur.
  var FRAG = [
    "#ifdef GL_FRAGMENT_PRECISION_HIGH",
    "precision highp float;",
    "#else",
    "precision mediump float;",
    "#endif",
    "uniform vec2 uRes;",   // taille du canvas en pixels réels
    "uniform vec2 uSize;",  // taille CSS
    "uniform float uTime;", // secondes + graine
    "uniform float uK;",    // échelle verticale (hauteur / 330)
    "uniform float uUnit;", // px CSS par unité de bruit horizontale
    "const vec3 kGreen  = vec3(0.310, 0.910, 0.659);", // #4FE8A8
    "const vec3 kTeal   = vec3(0.361, 0.878, 0.847);", // #5CE0D8
    "const vec3 kViolet = vec3(0.561, 0.482, 0.910);", // #8F7BE8
    "const vec3 kMilk   = vec3(0.930, 0.950, 0.900);",
    "const vec3 kTint   = vec3(0.420, 0.860, 0.800);",
    "float hash(vec2 p) {",
    "  p = fract(p * vec2(123.34, 456.21));",
    "  p += dot(p, p + 45.32);",
    "  return fract(p.x * p.y);",
    "}",
    "float vnoise(vec2 p) {",
    "  vec2 i = floor(p); vec2 f = fract(p);",
    "  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);",
    "  float a = hash(i); float b = hash(i + vec2(1.0, 0.0));",
    "  float c = hash(i + vec2(0.0, 1.0)); float d = hash(i + vec2(1.0, 1.0));",
    "  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);",
    "}",
    "float fbm(vec2 p) {",
    "  float v = 0.0; float amp = 0.5;",
    "  for (int i = 0; i < 4; i++) { v += amp * vnoise(p); p = p * 2.03 + vec2(17.0, 9.2); amp *= 0.5; }",
    "  return v;",
    "}",
    "void main() {",
    "  vec2 p = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y) * (uSize / uRes);",
    "  float u = p.x / uUnit;",
    "  float uw = p.x / uSize.x;",
    "  float t = uTime;",
    // ── aurora.frag ──
    "  float warp = fbm(vec2(u * 2.2 + t * 0.013, t * 0.021)) - 0.5;",
    "  float uu = u + warp * 0.35;",
    "  float big = fbm(vec2(uu * 1.5 + t * 0.017, t * 0.011 + 3.7)) - 0.5;",
    "  float detail = fbm(vec2(uu * 4.0 - t * 0.023, t * 0.017 + 8.1)) - 0.5;",
    "  float center = (165.0 + big * 70.0 + detail * 22.0) * uK;",
    "  float breath = 0.75 + 0.5 * fbm(vec2(uu * 1.8 + t * 0.019, t * 0.013 + 5.5));",
    "  float H = 135.0 * breath * uK;",
    "  float bright = fbm(vec2(uu * 2.8 - t * 0.021, t * 0.015 + 11.0));",
    "  bright = 0.35 + 0.9 * smoothstep(0.35, 0.75, bright);",
    "  float dy = p.y - center;",
    "  float h = max(-dy, 0.0) / H;",
    "  float sb = 30.0 * uK;",
    "  float fall = dy >= 0.0 ? exp(-dy * dy / (2.0 * sb * sb)) : exp(-pow(h, 1.7) * 2.6);",
    "  vec3 col = mix(kGreen, kTeal, smoothstep(0.05, 0.45, h));",
    "  col = mix(col, kViolet, smoothstep(0.40, 0.95, h));",
    "  float a = fall * bright * 0.34;",
    "  a *= smoothstep(330.0 * uK, 330.0 * uK - 60.0 * uK, p.y);",
    // ── stardust.frag (canvas de 230 px posé 89 px sous le haut, arc à 0,59) ──
    "  float hh = 230.0 * uK;",
    "  float py = p.y - 89.0 * uK;",
    "  float lift = fbm(vec2(u * 1.9 + t * 0.014, t * 0.016 + 4.2)) - 0.5;",
    "  float yc = hh * 0.59 - hh * 0.10 * sin(3.14159265 * uw) + lift * hh * 0.10;",
    "  float vb = fbm(vec2(u * 2.3 - t * 0.019, t * 0.012 + 9.3));",
    "  vb = 0.15 + 1.15 * smoothstep(0.40, 0.78, vb);",
    "  float vdy = py - yc;",
    "  float sUp = min(hh * 0.42, yc / 2.2);",
    "  float sDown = min(hh * 0.10, (hh - yc) / 2.2);",
    "  float s = vdy < 0.0 ? sUp : sDown;",
    "  float vfall = exp(-vdy * vdy / (2.0 * s * s));",
    "  float rise = clamp(-vdy / (hh * 0.55), 0.0, 1.0);",
    "  vec3 vcol = mix(kMilk, kTint, smoothstep(0.15, 0.90, rise));",
    "  float va = vfall * vb * 0.115;",
    "  va *= smoothstep(hh, hh * 0.84, py) * smoothstep(0.0, hh * 0.10, py);",
    "  va *= smoothstep(0.0, 0.06, uw) * smoothstep(1.0, 0.94, uw);",
    // Voile par-dessus l'aurore (alpha prémultiplié), puis micro-bruit
    // ±0,5/255 contre le banding des dégradés sombres.
    "  float n = (hash(gl_FragCoord.xy + vec2(fract(t) * 91.0, 17.0)) - 0.5) * (1.5 / 255.0);",
    "  a = clamp(a, 0.0, 1.0); va = clamp(va, 0.0, 1.0);",
    "  vec3 rgb = vcol * va + col * a * (1.0 - va);",
    "  float alpha = va + a * (1.0 - va);",
    "  vec3 teinte = alpha > 0.0001 ? rgb / alpha : kTeal;",
    "  alpha = clamp(alpha + n, 0.0, 1.0);",
    "  gl_FragColor = vec4(teinte * alpha, alpha);",
    "}",
  ].join("\n");

  var ciel = document.querySelector(".ciel");
  var gl = null, programme = null, uni = {}, canvasAurore = null;
  var canvasPoussiere = null, cp = null, poussiere = [];
  var cW = 0, cH = 0, uK = 1, uUnit = 390;
  var echelleAurore = 0.5; // demi-résolution : l'aurore n'a aucun bord net

  function initAurore() {
    canvasAurore = document.createElement("canvas");
    canvasAurore.className = "ciel__aurore";
    ciel.appendChild(canvasAurore);
    canvasPoussiere = document.createElement("canvas");
    canvasPoussiere.className = "ciel__poussiere";
    ciel.appendChild(canvasPoussiere);
    cp = canvasPoussiere.getContext("2d");

    try {
      gl = canvasAurore.getContext("webgl", {
        alpha: true, premultipliedAlpha: true, antialias: false, depth: false,
        stencil: false, powerPreference: "low-power",
      });
    } catch (e) { gl = null; }
    if (!gl) { ciel.classList.add("ciel--statique"); return; }

    function compiler(type, source) {
      var s = gl.createShader(type);
      gl.shaderSource(s, source);
      gl.compileShader(s);
      if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) { throw new Error(gl.getShaderInfoLog(s)); }
      return s;
    }
    try {
      programme = gl.createProgram();
      gl.attachShader(programme, compiler(gl.VERTEX_SHADER,
        "attribute vec2 a; void main() { gl_Position = vec4(a, 0.0, 1.0); }"));
      gl.attachShader(programme, compiler(gl.FRAGMENT_SHADER, FRAG));
      gl.linkProgram(programme);
      if (!gl.getProgramParameter(programme, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(programme));
    } catch (e) {
      (window.__erreurs = window.__erreurs || []).push(String(e));
      gl = null; ciel.classList.add("ciel--statique"); return;
    }
    gl.useProgram(programme);
    var tampon = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, tampon);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
    var loc = gl.getAttribLocation(programme, "a");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    ["uRes", "uSize", "uTime", "uK", "uUnit"].forEach(function (n) { uni[n] = gl.getUniformLocation(programme, n); });
    gl.clearColor(0, 0, 0, 0);

    canvasAurore.addEventListener("webglcontextlost", function (e) {
      e.preventDefault(); gl = null; ciel.classList.add("ciel--statique");
    });
  }

  function preparerAurore() {
    // Le ciel déborde un peu à gauche et à droite (voir .ciel) : quand il
    // glisse avec la souris, aucun bord n'apparaît.
    var w = ciel.offsetWidth || largeurPage();
    // Hauteur de la scène : celle de l'app (330) agrandie pour l'écran.
    var h = w < 700 ? 470 : Math.round(Math.max(460, Math.min(640, w * 0.42)));
    if (w === cW && h === cH) return false;
    cW = w; cH = h;
    uK = h / 330;
    // Sur grand écran, le bruit est un peu resserré : sinon le ruban
    // s'étire et perd ses ondulations.
    uUnit = w <= 600 ? w : 600 + (w - 600) * 0.45;
    ciel.style.height = h + "px";
    if (gl) {
      canvasAurore.width = Math.max(1, Math.round(w * echelleAurore));
      canvasAurore.height = Math.max(1, Math.round(h * echelleAurore));
      gl.viewport(0, 0, canvasAurore.width, canvasAurore.height);
    }
    canvasPoussiere.width = Math.round(w * DPR);
    canvasPoussiere.height = Math.round(h * DPR);

    // Micro-étoiles de la poussière : denses près de l'arc, éparses au
    // bord, blanches avec quelques grains turquoise et ivoire (90 sur un
    // téléphone, davantage sur un grand écran).
    var rnd = hasard(1214);
    var nombre = Math.round(90 * Math.max(1, Math.min(2.6, w / 393)));
    var hh = 230 * uK, haut = 89 * uK;
    poussiere = [];
    for (var i = 0; i < nombre; i++) {
      var u = rnd();
      var ecart = (rnd() + rnd() - 1) * 24 * uK;
      var phase = rnd() * DEUX_PI;
      var vitesse = 0.25 + rnd() * 0.45;
      var y = haut + hh * 0.59 - hh * 0.10 * Math.sin(Math.PI * u) + ecart;
      var r = 0.4 + rnd() * 0.9;
      var teinte = Math.floor(rnd() * 6);
      var base = 0.10 + rnd() * 0.30;
      poussiere.push({
        x: u, y: y, r: r, phase: phase, vitesse: vitesse, base: base,
        couleur: teinte === 0 ? "92,224,216" : teinte === 1 ? "239,234,216" : "255,255,255",
      });
    }
    return true;
  }

  function dessinerAurore(t) {
    if (gl) {
      gl.uniform2f(uni.uRes, canvasAurore.width, canvasAurore.height);
      gl.uniform2f(uni.uSize, cW, cH);
      gl.uniform1f(uni.uTime, graine + t);
      gl.uniform1f(uni.uK, uK);
      gl.uniform1f(uni.uUnit, uUnit);
      gl.clear(gl.COLOR_BUFFER_BIT);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    cp.setTransform(DPR, 0, 0, DPR, 0, 0);
    cp.clearRect(0, 0, cW, cH);
    var tt = graine + t;
    for (var i = 0; i < poussiere.length; i++) {
      var s = poussiere[i];
      var scintille = 0.72 + 0.28 * Math.sin(tt * s.vitesse + s.phase);
      cp.fillStyle = "rgba(" + s.couleur + "," + (s.base * scintille).toFixed(3) + ")";
      cp.beginPath();
      cp.arc(s.x * cW, s.y, s.r, 0, DEUX_PI);
      cp.fill();
    }
  }

  // ════════════════════════════════════════════════════════════
  // 3. PROFONDEUR : l'aurore et la lune défilent moins vite que la page
  //    et glissent avec la souris.
  // ════════════════════════════════════════════════════════════
  function borne(v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
  function adoucir(v) { return v * v * (3 - 2 * v); }

  function placerCiel(defilement) {
    if (!ciel) return;
    if (reduit) { ciel.style.transform = ""; return; }
    var d = Math.min(defilement, 1400);
    var ox = souris.lx - 0.5, oy = souris.ly - 0.5;
    ciel.style.transform = "translate3d(" + (-ox * 16).toFixed(1) + "px," + (d * 0.42 - oy * 10).toFixed(1) + "px,0)";
  }

  // ── La lune ──
  // Sur grand écran, elle quitte le haut de page en glissant dans la marge
  // de droite, rapetisse, et veille sur toute la page. Au fil du
  // défilement, elle passe du croissant à la pleine lune, pleine en
  // arrivant au formulaire de démo : une nuit qui s'apaise.
  // Sur téléphone (pas de marge), elle reste en haut et s'arrondit un peu
  // quand on quitte le haut de page.
  var lune = document.querySelector(".lune");
  var morsure = lune && lune.querySelector(".lune__morsure");
  var requeteLarge = window.matchMedia("(min-width: 1300px)");
  var luneAmarree = false, luneBase = null, phaseLune = -1;
  var TAILLE_AMARREE = 64;

  function preparerLune() {
    if (!lune) return;
    lune.classList.remove("lune--amarree");
    lune.style.transform = ""; lune.style.top = ""; lune.style.left = "";
    luneAmarree = requeteLarge.matches && !reduit;
    if (!luneAmarree) return;
    var r = lune.getBoundingClientRect();
    var W = largeurPage();
    var marge = (W - (Math.min(W, 1180) - 80)) / 2;
    luneBase = {
      haut: r.top + window.scrollY, gauche: r.left, taille: r.width,
      xFin: W - marge / 2 - TAILLE_AMARREE / 2, yFin: 108,
    };
    lune.classList.add("lune--amarree");
    lune.style.top = luneBase.haut + "px";
    lune.style.left = luneBase.gauche + "px";
  }

  function mettrePhase(f) {
    if (!morsure || Math.abs(f - phaseLune) < 0.002) return;
    phaseLune = f;
    // L'ombre du croissant (cercle noir du masque) s'éloigne du disque
    // dans l'axe du croissant de l'app : croissant → gibbeuse → pleine.
    var dist = 16.64 + (62 - 16.64) * adoucir(f);
    morsure.setAttribute("cx", (47 + 0.8412 * dist).toFixed(2));
    morsure.setAttribute("cy", (50 - 0.5408 * dist).toFixed(2));
    lune.style.setProperty("--plein", f.toFixed(3));
  }

  function placerLune(defilement) {
    if (!lune) return;
    if (reduit) { lune.style.transform = ""; mettrePhase(0); return; }
    var mx = -(souris.lx - 0.5) * 22, my = -(souris.ly - 0.5) * 14;
    if (luneAmarree) {
      var p = adoucir(borne(defilement / 480));
      var s = 1 + (TAILLE_AMARREE / luneBase.taille - 1) * p;
      var dx = (luneBase.xFin - luneBase.gauche) * p + mx;
      var dy = (luneBase.yFin - luneBase.haut) * p + my;
      lune.style.transform = "translate3d(" + dx.toFixed(1) + "px," + dy.toFixed(1) + "px,0) scale(" + s.toFixed(4) + ")";
      var course = document.documentElement.scrollHeight - window.innerHeight;
      mettrePhase(course > 0 ? borne(defilement / course) : 0);
    } else {
      var d = Math.min(defilement, 1400);
      lune.style.transform = "translate3d(" + mx.toFixed(1) + "px," + (d * 0.3 + my).toFixed(1) + "px,0)";
      mettrePhase(borne(defilement / 900) * 0.5);
    }
  }

  function suivreSouris() {
    if (!pointeurFin) return;
    window.addEventListener("pointermove", function (e) {
      if (e.pointerType && e.pointerType !== "mouse") return;
      souris.x = e.clientX / Math.max(1, fW);
      souris.y = e.clientY / Math.max(1, fH);
      souris.px = e.clientX; souris.py = e.clientY;
      souris.cible = 1; souris.neuve = true;
    }, { passive: true });
    window.addEventListener("mouseout", function (e) { if (!e.relatedTarget) souris.cible = 0; });
    window.addEventListener("blur", function () { souris.cible = 0; });
  }

  // Avance l'inertie de la souris ; vrai tant que quelque chose bouge.
  function majSouris() {
    if (reduit || !pointeurFin) return false;
    var avant = souris.lx + souris.ly * 3 + souris.presence * 7;
    souris.lx += (souris.x - souris.lx) * 0.06;
    souris.ly += (souris.y - souris.ly) * 0.06;
    souris.presence += (souris.cible - souris.presence) * 0.08;
    var neuve = souris.neuve; souris.neuve = false;
    return neuve || Math.abs(souris.lx + souris.ly * 3 + souris.presence * 7 - avant) > 0.0003;
  }

  // ════════════════════════════════════════════════════════════
  // Boucle unique
  // ════════════════════════════════════════════════════════════
  if (ciel) initAurore();
  preparerEtoiles();
  if (ciel) preparerAurore();
  preparerLune();
  suivreSouris();

  var enCours = false, derniereEtoile = 0, derniereAurore = 0, dernierDefilement = -1;

  function image(ms) {
    if (!enCours) return;
    requestAnimationFrame(image);
    var t = (ms - debut) / 1000;
    var defilement = window.scrollY;
    var sourisBouge = majSouris();
    var bouge = defilement !== dernierDefilement || sourisBouge;

    if (t > prochaineFilante) lancerFilante(t);
    // Le scintillement est lent : 30 images/s suffisent, sauf pendant un
    // défilement, un mouvement de souris ou une étoile filante (là, on
    // suit l'écran).
    if (bouge || filantes.length || ms - derniereEtoile > 32) {
      derniereEtoile = ms;
      dessinerEtoiles(t, defilement);
    }
    if (bouge) placerLune(defilement);
    if (ciel) {
      if (bouge) placerCiel(defilement);
      var cielVisible = defilement < cH * 1.6;
      if (cielVisible && ms - derniereAurore > 32) {
        derniereAurore = ms;
        dessinerAurore(t);
      }
    }
    dernierDefilement = defilement;
  }

  function demarrer() {
    if (enCours || reduit || document.hidden) return;
    enCours = true;
    requestAnimationFrame(image);
  }
  function arreter() { enCours = false; }

  // Image fixe (réduire les animations, ou avant le premier tour de boucle).
  function imageFixe() {
    var t = 12; // un instant où l'aurore est bien formée
    dessinerEtoiles(t, reduit ? 0 : window.scrollY);
    if (ciel) { dessinerAurore(t); placerCiel(window.scrollY); }
    placerLune(window.scrollY);
  }

  imageFixe();
  demarrer();

  document.addEventListener("visibilitychange", function () {
    if (document.hidden) arreter(); else demarrer();
  });

  var attente = null;
  window.addEventListener("resize", function () {
    clearTimeout(attente);
    attente = setTimeout(function () {
      var a = preparerEtoiles();
      var b = ciel ? preparerAurore() : false;
      preparerLune();
      placerLune(window.scrollY);
      if ((a || b) && !enCours) imageFixe();
    }, 150);
  });

  // En mode réduit, les étoiles restent fixes : on ne redessine qu'au besoin.
  var suiviChangement = function () {
    reduit = requeteReduit.matches;
    preparerLune();
    if (reduit) { arreter(); filantes = []; imageFixe(); } else { demarrer(); }
  };
  if (requeteReduit.addEventListener) requeteReduit.addEventListener("change", suiviChangement);
  else if (requeteReduit.addListener) requeteReduit.addListener(suiviChangement);
})();
