// Quieto Entreprise — les mouvements doux de la page :
//   - apparitions au défilement ([data-apparition], ou les enfants d'un
//     [data-apparition-groupe], qui arrivent l'un après l'autre) ;
//   - profondeur des peintures ([data-profondeur] : la gouache glisse
//     moins vite que son cadre) ;
//   - en-tête qui se pose sur un voile de nuit dès qu'on défile.
// Tout passe par transform/opacity (le compositeur s'en charge, fluide sur
// téléphone). « Réduire les animations » : tout est affiché d'emblée,
// rien ne bouge.
(function () {
  "use strict";
  window.__mouvement = true;

  var reduit = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var racine = document.documentElement;

  // ── Apparitions ──
  Array.prototype.forEach.call(document.querySelectorAll("[data-apparition-groupe]"), function (groupe) {
    var pas = parseFloat(groupe.getAttribute("data-apparition-groupe")) || 0.09;
    Array.prototype.forEach.call(groupe.children, function (enfant, i) {
      enfant.setAttribute("data-apparition", "");
      enfant.style.setProperty("--delai", (i * pas).toFixed(2) + "s");
    });
  });
  var aApparaitre = document.querySelectorAll("[data-apparition]");
  if (reduit || !("IntersectionObserver" in window)) {
    Array.prototype.forEach.call(aApparaitre, function (el) { el.classList.add("visible"); });
  } else {
    var observateur = new IntersectionObserver(function (entrees) {
      entrees.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("visible"); observateur.unobserve(e.target); }
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0 });
    Array.prototype.forEach.call(aApparaitre, function (el) { observateur.observe(el); });
  }

  // ── Profondeur des peintures + en-tête ──
  var entete = document.querySelector(".entete");
  var profondeurs = reduit ? [] : Array.prototype.map.call(document.querySelectorAll("[data-profondeur]"), function (el) {
    return { el: el, cadre: el.parentElement, f: parseFloat(el.getAttribute("data-profondeur")) || 0.08 };
  });
  // Marge de sécurité : l'image est agrandie de 16 % (voir style.css),
  // elle ne doit jamais découvrir le bord de son cadre.
  var AGRANDI = 1.16;

  var prevu = false;
  function maj() {
    prevu = false;
    var hVue = window.innerHeight;
    if (entete) entete.classList.toggle("entete--pleine", window.scrollY > 8);
    var mesures = profondeurs.map(function (p) { return p.cadre.getBoundingClientRect(); });
    profondeurs.forEach(function (p, i) {
      var r = mesures[i];
      if (r.bottom < -80 || r.top > hVue + 80) return;
      var marge = ((AGRANDI - 1) / 2) * r.height * 0.92;
      var decalage = -(r.top + r.height / 2 - hVue / 2) * p.f;
      decalage = Math.max(-marge, Math.min(marge, decalage));
      p.el.style.transform = "translate3d(0," + decalage.toFixed(1) + "px,0) scale(" + AGRANDI + ")";
    });
  }
  function demander() { if (!prevu) { prevu = true; requestAnimationFrame(maj); } }
  window.addEventListener("scroll", demander, { passive: true });
  window.addEventListener("resize", demander);
  maj();

  racine.classList.add("mouvement-pret");
})();
