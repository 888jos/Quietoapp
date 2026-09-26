// Quieto Entreprise — « Trente secondes pour souffler » (index.html).
//
// Une respiration guidée qu'on essaie sur place : trois cycles de 10 s,
// on inspire 4 s (tout s'ouvre), on expire 6 s (tout se referme).
// Le visuel reprend la gouache « respiration » de l'app : de larges bandes
// bleues et violettes autour d'une petite lune, au bord un peu irrégulier
// comme un coup de pinceau. Derrière, un halo d'aurore sur toute la largeur ;
// devant, des étoiles qui s'écartent à l'inspiration et reviennent à
// l'expiration. Canvas 2D, dessiné seulement quand la section est à l'écran.
// « Réduire les animations » : rien ne grandit, la lumière monte et descend.
(function () {
  "use strict";

  var souffle = document.querySelector(".souffle");
  if (!souffle) return;
  var toile = souffle.querySelector(".souffle__toile");
  var ctx = toile.getContext("2d");
  var bouton = souffle.querySelector(".souffle__bouton");
  var consigne = souffle.querySelector(".souffle__consigne");
  var fin = souffle.querySelector(".souffle__fin");
  var pastilles = souffle.querySelectorAll(".souffle__cycles i");

  var reduit = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var DPR = Math.min(window.devicePixelRatio || 1, 2);
  var DEUX_PI = Math.PI * 2;
  var INSPIRE = 4, EXPIRE = 6, CYCLE = INSPIRE + EXPIRE, CYCLES = 3;

  var W = 0, H = 0, etoiles = [];
  var etat = "repos", debutSeance = 0, depart = 0.3, phase = "";
  // Souffle courant par bande : les bandes extérieures suivent avec un
  // léger retard, comme une onde qui se propage.
  var BANDES = [
    { f: 1.00, couleur: "#7B2FD1", vitesse: 2.4 },
    { f: 0.86, couleur: "#101B4A", vitesse: 2.8 },
    { f: 0.76, couleur: "#1C4FD8", vitesse: 3.2 },
    { f: 0.62, couleur: "#101B4A", vitesse: 3.8 },
    { f: 0.53, couleur: "#6A3BD6", vitesse: 4.4 },
    { f: 0.41, couleur: "#101B4A", vitesse: 5.0 },
    { f: 0.32, couleur: "#1C4FD8", vitesse: 5.6 },
  ];
  BANDES.forEach(function (b, i) { b.b = 0.3; b.phi = i * 1.7; });

  function adoucir(x) { return 0.5 - 0.5 * Math.cos(Math.PI * Math.max(0, Math.min(1, x))); }

  function preparer() {
    var r = toile.getBoundingClientRect();
    var w = Math.round(r.width), h = Math.round(r.height);
    if (w === W && h === H) return;
    W = w; H = h;
    toile.width = Math.round(W * DPR);
    toile.height = Math.round(H * DPR);
    // Les étoiles, réparties dans une large ellipse qui couvre la largeur.
    var n = W < 700 ? 90 : 170;
    etoiles = [];
    for (var i = 0; i < n; i++) {
      var tirage = Math.random();
      etoiles.push({
        a: Math.random() * DEUX_PI,
        d: 0.18 + Math.sqrt(Math.random()) * 0.82,
        r: 0.5 + Math.random() * 1.2,
        base: 0.25 + Math.random() * 0.45,
        phase: Math.random() * DEUX_PI,
        vitesse: 0.4 + Math.random() * 0.9,
        sens: Math.random() < 0.5 ? -1 : 1,
        couleur: tirage < 0.2 ? "92,224,216" : tirage < 0.3 ? "245,227,200" : "255,255,255",
      });
    }
  }

  // Le souffle voulu (0 = poumons vides, 1 = pleins) et la consigne.
  function cible(t) {
    if (etat !== "seance") return 0.3 + 0.12 * Math.sin((t / 8) * DEUX_PI); // au repos, il respire tout seul
    var e = (t - debutSeance);
    if (e >= CYCLE * CYCLES) { terminer(); return 0.3; }
    var c = Math.floor(e / CYCLE), dans = e - c * CYCLE;
    for (var k = 0; k < pastilles.length; k++) {
      pastilles[k].style.setProperty("--p", Math.max(0, Math.min(1, (e - k * CYCLE) / CYCLE)).toFixed(3));
    }
    if (dans < INSPIRE) {
      direConsigne("inspire", "Inspirez");
      var de = c === 0 ? depart : 0;
      return de + (1 - de) * adoucir(dans / INSPIRE);
    }
    direConsigne("expire", "Expirez");
    return 1 - adoucir((dans - INSPIRE) / EXPIRE);
  }

  function direConsigne(p, texte) {
    if (p === phase) return;
    phase = p;
    consigne.textContent = texte;
  }

  function dessiner(t, dt) {
    var b = cible(t);
    var geo = reduit ? 0.6 : null; // en mode réduit, la géométrie ne bouge pas
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, W, H);
    var cx = W / 2, cy = H / 2;

    // 1. Halo d'aurore, large comme l'écran, qui s'ouvre avec le souffle.
    var ouv = geo !== null ? geo : b;
    var rx = W * 0.46 * (0.78 + 0.22 * ouv), ry = H * 0.44 * (0.82 + 0.18 * ouv);
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(rx / ry, 1);
    var g = ctx.createRadialGradient(0, 0, 0, 0, 0, ry);
    var lum = 0.55 + 0.45 * b;
    g.addColorStop(0, "rgba(92,224,216," + (0.26 * lum).toFixed(3) + ")");
    g.addColorStop(0.35, "rgba(79,232,168," + (0.15 * lum).toFixed(3) + ")");
    g.addColorStop(0.7, "rgba(143,123,232," + (0.1 * lum).toFixed(3) + ")");
    g.addColorStop(1, "rgba(143,123,232,0)");
    ctx.fillStyle = g;
    ctx.fillRect(-ry * 1.1, -ry * 1.1, ry * 2.2, ry * 2.2);
    ctx.restore();

    // 2. Les bandes peintes, de l'extérieur vers la lune.
    var Rmax = Math.min(H * 0.38, W * (W < 700 ? 0.42 : 0.3));
    // Halo violet autour de l'orbe.
    var R0 = Rmax * (0.5 + 0.5 * (geo !== null ? geo : BANDES[0].b));
    // (borné à la hauteur du canvas : le halo s'éteint avant le bord)
    var rh = Math.min(R0 * 1.3, H * 0.5);
    var h = ctx.createRadialGradient(cx, cy, R0 * 0.8, cx, cy, rh);
    h.addColorStop(0, "rgba(123,47,209," + (0.3 * lum).toFixed(3) + ")");
    h.addColorStop(1, "rgba(123,47,209,0)");
    ctx.fillStyle = h;
    ctx.beginPath(); ctx.arc(cx, cy, rh, 0, DEUX_PI); ctx.fill();

    for (var i = 0; i < BANDES.length; i++) {
      var bd = BANDES[i];
      bd.b += (b - bd.b) * (1 - Math.exp(-dt * bd.vitesse));
      var R = Rmax * (0.5 + 0.5 * (geo !== null ? geo : bd.b)) * bd.f;
      ctx.fillStyle = bd.couleur;
      ctx.beginPath();
      // Bord légèrement irrégulier, comme un coup de pinceau qui bouge à peine.
      for (var k = 0; k <= 72; k++) {
        var a = (k / 72) * DEUX_PI;
        var tt = reduit ? 0 : t;
        var ondule = 1 + 0.013 * Math.sin(3 * a + bd.phi + tt * 0.25) + 0.008 * Math.sin(5 * a - bd.phi - tt * 0.18);
        var x = cx + Math.cos(a) * R * ondule, y = cy + Math.sin(a) * R * ondule;
        if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.fill();
    }

    // 3. La lune au centre, qui s'éclaire à l'inspiration.
    var rl = Rmax * 0.14 * (1 + 0.12 * ouv);
    var l = ctx.createRadialGradient(cx, cy, rl, cx, cy, rl * 1.9);
    l.addColorStop(0, "rgba(255,236,205," + (0.28 + 0.22 * b).toFixed(3) + ")");
    l.addColorStop(1, "rgba(255,236,205,0)");
    ctx.fillStyle = l;
    ctx.beginPath(); ctx.arc(cx, cy, rl * 1.9, 0, DEUX_PI); ctx.fill();
    ctx.fillStyle = "#F5E3C8";
    ctx.beginPath(); ctx.arc(cx, cy, rl, 0, DEUX_PI); ctx.fill();

    // 4. Les étoiles, par-dessus, comme sur la gouache : elles s'écartent
    //    quand on inspire, reviennent quand on expire.
    var ex = W * 0.49, ey = H * 0.47;
    var ecart = geo !== null ? 1 : 0.82 + 0.3 * b;
    for (var j = 0; j < etoiles.length; j++) {
      var s = etoiles[j];
      var ang = s.a + (reduit ? 0 : t * 0.012 * s.sens);
      var sx = cx + Math.cos(ang) * s.d * ex * ecart;
      var sy = cy + Math.sin(ang) * s.d * ey * ecart;
      if (sx < -4 || sx > W + 4 || sy < -4 || sy > H + 4) continue;
      var bord = Math.min(1, Math.min(sx, W - sx, sy, H - sy) / 40);
      var alpha = s.base * (0.7 + 0.3 * Math.sin((reduit ? 0 : t) * s.vitesse + s.phase)) * bord;
      ctx.fillStyle = "rgba(" + s.couleur + "," + alpha.toFixed(3) + ")";
      ctx.beginPath(); ctx.arc(sx, sy, s.r, 0, DEUX_PI); ctx.fill();
    }
  }

  // ── Boucle : seulement quand la section est à l'écran (ou pendant la séance) ──
  var visible = false, enCours = false, dernier = 0;
  function image(ms) {
    if (!(visible || etat === "seance")) { enCours = false; return; }
    requestAnimationFrame(image);
    var t = ms / 1000;
    var dt = dernier ? Math.min(0.1, t - dernier) : 0.016;
    dernier = t;
    dessiner(t, dt);
  }
  function relancer() {
    if (enCours) return;
    enCours = true; dernier = 0;
    requestAnimationFrame(image);
  }

  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (entrees) {
      visible = entrees[0].isIntersecting;
      if (visible) relancer();
    }, { rootMargin: "100px 0px" }).observe(toile);
  } else { visible = true; }

  // ── Séance ──
  function demarrer() {
    etat = "seance";
    depart = BANDES[BANDES.length - 1].b;
    debutSeance = performance.now() / 1000;
    phase = "";
    fin.hidden = true;
    souffle.classList.add("souffle--actif");
    bouton.textContent = "Arrêter";
    relancer();
  }
  function arreter() {
    etat = "repos";
    phase = "";
    souffle.classList.remove("souffle--actif");
    Array.prototype.forEach.call(pastilles, function (p) { p.style.setProperty("--p", "0"); });
    consigne.textContent = "Prêt ?";
    bouton.textContent = "Commencer · 30 s";
  }
  function terminer() {
    etat = "fini";
    phase = "";
    souffle.classList.remove("souffle--actif");
    Array.prototype.forEach.call(pastilles, function (p) { p.style.setProperty("--p", "1"); });
    consigne.textContent = "Voilà.";
    bouton.textContent = "Recommencer";
    fin.hidden = false;
  }
  bouton.addEventListener("click", function () {
    if (etat === "seance") arreter(); else demarrer();
  });

  var attente = null;
  window.addEventListener("resize", function () {
    clearTimeout(attente);
    attente = setTimeout(function () { preparer(); if (!enCours) dessiner(performance.now() / 1000, 0.016); }, 150);
  });

  preparer();
  dessiner(performance.now() / 1000, 0.016);
})();
