/* ============================================================
   COFONDE — Interactions
   ============================================================ */
(function () {
  "use strict";

  /* --- Header : fond au scroll --- */
  var header = document.querySelector(".site-header");
  if (header) {
    var onScroll = function () {
      header.classList.toggle("scrolled", window.scrollY > 24);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* --- Mockup Quieto : inclinaison 3D qui suit la souris --- */
  var shot = document.querySelector(".quieto-shot");
  if (shot && window.matchMedia("(hover: hover) and (pointer: fine)").matches) {
    shot.addEventListener("mousemove", function (e) {
      var r = shot.getBoundingClientRect();
      var ry = ((e.clientX - r.left) / r.width - 0.5) * 32;
      var rx = (0.5 - (e.clientY - r.top) / r.height) * 22;
      shot.style.transform =
        "rotateY(" + ry.toFixed(1) + "deg) rotateX(" + rx.toFixed(1) +
        "deg) scale(1.08)";
    });
    shot.addEventListener("mouseleave", function () {
      shot.style.transform = "";
    });
  }

  /* --- Icônes « copier le lien de partage » à côté des boutons de store --- */
  var copieSecours = function (texte) {
    var zone = document.createElement("textarea");
    zone.value = texte;
    zone.setAttribute("readonly", "");
    zone.style.position = "fixed";
    zone.style.opacity = "0";
    document.body.appendChild(zone);
    zone.select();
    document.execCommand("copy");
    document.body.removeChild(zone);
  };

  document.querySelectorAll("[data-copier]").forEach(function (bouton) {
    var bulle = bouton.getAttribute("data-bulle");
    var minuteur;
    var confirmer = function () {
      bouton.classList.add("copie");
      bouton.setAttribute("data-bulle", "Lien copié !");
      clearTimeout(minuteur);
      minuteur = setTimeout(function () {
        bouton.classList.remove("copie");
        bouton.setAttribute("data-bulle", bulle);
      }, 2000);
    };
    bouton.addEventListener("click", function () {
      var lien = bouton.getAttribute("data-copier");
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(lien).then(confirmer, function () {
          copieSecours(lien);
          confirmer();
        });
      } else {
        copieSecours(lien);
        confirmer();
      }
    });
  });

  /* --- Apparition des éléments au scroll --- */
  var reveals = document.querySelectorAll(".reveal");

  if (!("IntersectionObserver" in window)) {
    reveals.forEach(function (el) {
      el.classList.add("is-visible");
    });
    return;
  }

  var observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.14, rootMargin: "0px 0px -8% 0px" }
  );

  reveals.forEach(function (el) {
    observer.observe(el);
  });

  /* --- Année courante dans le footer --- */
  var year = document.querySelectorAll("[data-year]");
  year.forEach(function (el) {
    el.textContent = new Date().getFullYear();
  });
})();
