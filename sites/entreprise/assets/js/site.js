// Quieto Entreprise — interactions communes aux pages :
// calculateur de tarif (tarifs.html), onglets « une journée avec Quieto »
// et formulaire de démo (index.html).
(function () {
  "use strict";

  // Fonctions du backend (quieto-backend/functions/index.js).
  var API = "https://us-central1-quieto-06.cloudfunctions.net/";
  var EMAIL = "quieto@cofonde.com";

  // ── Grille de prix : même grille que Headspace (« small business »), en € HT
  //    par salarié et par an. ⚠️ Copie d'affichage : c'est GRILLE_ENTREPRISE
  //    côté serveur qui fait foi pour le paiement. Mensuel = annuel ÷ 10.
  var GRILLE = [[800, 44.88], [600, 45.96], [450, 47.16], [350, 48.36],
    [250, 49.56], [150, 52.56], [50, 54.30], [10, 56.04]];
  var REFERENCE_ANNUELLE = 69.99;
  var MIN = 10;
  var MAX = 999;

  function tarif(places, rythme) {
    var annuel = GRILLE.filter(function (p) { return places >= p[0]; })[0][1];
    var diviseur = rythme === "mensuel" ? 10 : 1;
    var unitaire = Math.round((annuel / diviseur) * 100) / 100;
    var reference = Math.round((REFERENCE_ANNUELLE / diviseur) * 100) / 100;
    var total = Math.round(unitaire * places * 100) / 100; // comme le serveur
    return { unitaire: unitaire, reference: reference, total: total, economie: Math.round((reference - unitaire) * places * 100) / 100 };
  }

  var euros = function (n) {
    return n.toLocaleString("fr-FR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + " €";
  };

  // ── Calculateur (tarifs.html) ──
  var calc = document.getElementById("calculateur");
  if (calc) {
    var champ = document.getElementById("places");
    var curseur = document.getElementById("places-curseur");
    var boutonsRythme = calc.querySelectorAll(".bascule button");
    var commencer = document.getElementById("commencer");
    var etat = calc.querySelector(".calculateur__etat");
    var rythme = "annuel";

    var params = new URLSearchParams(location.search);
    if (params.get("places")) champ.value = params.get("places");
    if (params.get("rythme") === "mensuel") rythme = "mensuel";

    var borner = function (v) {
      var n = parseInt(v, 10);
      if (isNaN(n)) return MIN;
      return Math.min(MAX, Math.max(MIN, n));
    };

    var afficher = function () {
      var n = borner(champ.value);
      var t = tarif(n, rythme);
      var mensuel = rythme === "mensuel";
      curseur.value = n;
      // Remplissage du curseur jusqu'au pouce (repère visuel comme chez Headspace).
      curseur.style.background = "linear-gradient(to right, #0E1733 " + ((n - MIN) / (MAX - MIN) * 100) +
        "%, rgba(14,23,51,0.18) 0)";
      calc.querySelector("[data-libelle-unitaire]").textContent = mensuel ? "Prix mensuel par salarié" : "Prix annuel par salarié";
      calc.querySelector("[data-libelle-total]").textContent = mensuel ? "Total par mois" : "Total pour un an";
      calc.querySelector("[data-reference]").textContent = euros(t.reference);
      calc.querySelector("[data-unitaire]").textContent = euros(t.unitaire);
      calc.querySelector("[data-total]").textContent = euros(t.total) + " HT";
      calc.querySelector("[data-economie]").textContent = "Vous économisez " + euros(t.economie) + (mensuel ? " par mois" : " par an");
      calc.querySelector("[data-lien-demo]").href = "index.html?places=" + n + "&rythme=" + rythme + "#demo";
      boutonsRythme.forEach(function (b) {
        b.setAttribute("aria-pressed", b.dataset.rythme === rythme ? "true" : "false");
      });
      etat.textContent = "";
    };

    champ.addEventListener("input", function () {
      var n = parseInt(champ.value, 10);
      if (!isNaN(n) && n >= MIN && n <= MAX) afficher();
    });
    champ.addEventListener("blur", function () { champ.value = borner(champ.value); afficher(); });
    curseur.addEventListener("input", function () { champ.value = curseur.value; afficher(); });
    boutonsRythme.forEach(function (b) {
      b.addEventListener("click", function () { rythme = b.dataset.rythme; afficher(); });
    });

    commencer.addEventListener("click", function () {
      var n = borner(champ.value);
      champ.value = n;
      afficher();
      commencer.disabled = true;
      etat.textContent = "Préparation du paiement…";
      var repli = "index.html?places=" + n + "&rythme=" + rythme + "#demo";
      fetch(API + "paiementEntreprise", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ places: n, rythme: rythme }),
      }).then(function (r) {
        return r.json().catch(function () { return {}; }).then(function (j) { return { statut: r.status, j: j }; });
      }).then(function (rep) {
        if (rep.statut === 200 && rep.j.url) {
          location.href = rep.j.url; // page de paiement Stripe, montant exact
          return;
        }
        etat.innerHTML = rep.statut === 503 ?
          "Le paiement en ligne ouvre très bientôt. <a href=\"" + repli + "\">Laissez-nous vos coordonnées</a>, on vous envoie votre lien de paiement." :
          "Le paiement n'a pas pu démarrer. <a href=\"" + repli + "\">Écrivez-nous</a> ou réessayez dans un instant.";
        commencer.disabled = false;
      }).catch(function () {
        etat.innerHTML = "Le paiement n'a pas pu démarrer. <a href=\"" + repli + "\">Écrivez-nous</a> ou réessayez dans un instant.";
        commencer.disabled = false;
      });
    });

    afficher();
  }

  // ── Onglets « une journée avec Quieto » (index.html) ──
  // Transition douce : l'ancien panneau s'efface pendant que le nouveau
  // arrive (image qui se pose, texte qui monte), et la pastille crème
  // glisse d'un onglet à l'autre. Les panneaux sont empilés dans la même
  // case de grille : la hauteur ne saute pas d'un onglet à l'autre.
  var onglets = Array.prototype.slice.call(document.querySelectorAll(".journee__onglets [role=tab]"));
  var barreOnglets = document.querySelector(".journee__onglets");
  var pastille = document.querySelector(".journee__pastille");
  var sansAnimation = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var minuteries = {};

  function placerPastille(o) {
    if (!pastille || !o) return;
    pastille.style.width = o.offsetWidth + "px";
    pastille.style.transform = "translateX(" + o.offsetLeft + "px)";
    // Sur téléphone, la barre peut défiler : l'onglet choisi reste en vue.
    if (barreOnglets.scrollWidth > barreOnglets.clientWidth) {
      var cible = o.offsetLeft - (barreOnglets.clientWidth - o.offsetWidth) / 2;
      barreOnglets.scrollTo({ left: cible, behavior: sansAnimation ? "auto" : "smooth" });
    }
  }

  function choisirOnglet(o, focus) {
    var nouveau = document.getElementById(o.getAttribute("aria-controls"));
    onglets.forEach(function (x) {
      var actif = x === o;
      var panneau = document.getElementById(x.getAttribute("aria-controls"));
      var etaitVisible = !panneau.hidden;
      x.setAttribute("aria-selected", actif ? "true" : "false");
      x.tabIndex = actif ? 0 : -1;
      if (actif) return;
      panneau.classList.remove("entree");
      if (etaitVisible && !sansAnimation) {
        panneau.classList.add("sortie");
        clearTimeout(minuteries[panneau.id]);
        minuteries[panneau.id] = setTimeout(function () { panneau.classList.remove("sortie"); }, 420);
      }
      panneau.hidden = true;
    });
    if (nouveau.hidden) {
      clearTimeout(minuteries[nouveau.id]);
      nouveau.classList.remove("sortie");
      nouveau.hidden = false;
      if (!sansAnimation) {
        nouveau.classList.remove("entree");
        void nouveau.offsetWidth; // relance l'animation d'entrée
        nouveau.classList.add("entree");
      }
    }
    placerPastille(o);
    // Le ciel de la section suit l'heure de l'onglet (voir .journee__ciel).
    var section = document.getElementById("journee");
    if (section) section.setAttribute("data-moment", String(onglets.indexOf(o) + 1));
    if (focus) o.focus();
  }

  if (pastille && onglets.length) {
    var ongletActif = function () {
      return onglets.filter(function (x) { return x.getAttribute("aria-selected") === "true"; })[0] || onglets[0];
    };
    placerPastille(ongletActif());
    // Première pose sans glissement, puis la pastille s'anime.
    requestAnimationFrame(function () { barreOnglets.classList.add("journee__onglets--pret"); });
    window.addEventListener("resize", function () { placerPastille(ongletActif()); });
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { placerPastille(ongletActif()); });
  }

  onglets.forEach(function (o, i) {
    o.addEventListener("click", function () { choisirOnglet(o, false); });
    o.addEventListener("keydown", function (e) {
      if (e.key === "ArrowRight") { e.preventDefault(); choisirOnglet(onglets[(i + 1) % onglets.length], true); }
      if (e.key === "ArrowLeft") { e.preventDefault(); choisirOnglet(onglets[(i - 1 + onglets.length) % onglets.length], true); }
    });
  });

  // ── Formulaire de démo (index.html) ──
  var form = document.getElementById("formulaire-demo");
  if (form) {
    var etatForm = form.querySelector(".formulaire__etat");
    var afficherEtat = function (html) { etatForm.innerHTML = html; };

    // Venu du calculateur : taille d'équipe et forfait préremplis.
    var q = new URLSearchParams(location.search);
    var n = parseInt(q.get("places"), 10);
    if (n >= 1) {
      var taille = n <= 10 ? "1 à 10 personnes" : n <= 25 ? "11 à 25 personnes" : n <= 50 ? "26 à 50 personnes" :
        n <= 100 ? "51 à 100 personnes" : "Plus de 100 personnes";
      form.elements.taille.value = taille;
      form.elements.profil.value = "Un employeur";
      form.elements.message.value = "Je souhaite Quieto pour " + n + " personnes, paiement " +
        (q.get("rythme") === "mensuel" ? "mensuel" : "annuel") + ".";
    }

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      var manque = null;
      ["profil", "prenom", "nom", "email", "entreprise"].forEach(function (nom) {
        var c = form.elements[nom];
        var vide = !c.value.trim() || (nom === "email" && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(c.value.trim()));
        c.setAttribute("aria-invalid", vide ? "true" : "false");
        if (vide && !manque) manque = c;
      });
      if (manque) {
        afficherEtat("Il manque une information (ou l'e-mail n'est pas valide).");
        manque.focus();
        return;
      }
      var donnees = {};
      ["profil", "prenom", "nom", "email", "entreprise", "telephone", "taille", "message", "site"].forEach(function (k) {
        donnees[k] = form.elements[k].value.trim();
      });
      var bouton = form.querySelector("button[type=submit]");
      bouton.disabled = true;
      afficherEtat("Envoi en cours…");
      fetch(API + "demandeEntreprise", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(donnees),
      }).then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        form.reset();
        afficherEtat("Merci, votre demande est bien arrivée. Nous vous répondons en moins de 24\u00a0heures.");
      }).catch(function () {
        afficherEtat("L'envoi n'a pas fonctionné. Écrivez-nous directement à <a href=\"mailto:" + EMAIL +
          "?subject=Quieto%20pour%20mon%20entreprise\">" + EMAIL + "</a>.");
      }).then(function () { bouton.disabled = false; });
    });
  }

  // ── « Demander une démo » : on voit clairement qu'on arrive au formulaire ──
  // (depuis le pied de page, le formulaire est juste au-dessus : sans ça, la
  // page ne bouge presque pas et on croit que le lien ne marche pas.)
  var formDemo = document.getElementById("formulaire-demo");
  var douxDefilement = !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  function allerALaDemo(defiler) {
    if (!formDemo) return;
    if (defiler) document.getElementById("demo").scrollIntoView({ behavior: douxDefilement ? "smooth" : "auto" });
    setTimeout(function () {
      formDemo.elements.profil.focus({ preventScroll: true });
      formDemo.classList.remove("formulaire--appel");
      void formDemo.offsetWidth;
      formDemo.classList.add("formulaire--appel");
    }, douxDefilement && defiler ? 650 : 50);
  }
  if (formDemo) {
    document.addEventListener("click", function (e) {
      var lien = e.target.closest && e.target.closest('a[href="#demo"]');
      if (!lien) return;
      e.preventDefault();
      if (location.hash !== "#demo") history.pushState(null, "", "#demo");
      allerALaDemo(true);
    });
    // Arrivée depuis une autre page (tarifs.html → index.html#demo).
    if (location.hash === "#demo") window.addEventListener("load", function () { allerALaDemo(false); });
  }

  // ── Adresse e-mail : sur ordinateur, une fenêtre pour écrire tout de suite ──
  // Un lien mailto ne fait souvent rien dans un navigateur sans logiciel de
  // messagerie. Sur ordinateur, on ouvre donc une fenêtre : l'adresse à
  // copier, et Gmail, Outlook ou la messagerie de l'ordinateur, avec un
  // nouveau message déjà adressé. Sur téléphone, le lien ouvre directement
  // l'app Mail : on le laisse faire.
  var surOrdinateur = window.matchMedia("(hover: hover) and (pointer: fine)").matches;
  var fenetreMail = null;
  function ouvrirFenetreMail(adresse) {
    var sujet = "Quieto pour mon entreprise";
    if (!fenetreMail) {
      fenetreMail = document.createElement("dialog");
      fenetreMail.className = "courriel";
      fenetreMail.tabIndex = -1;
      fenetreMail.setAttribute("aria-labelledby", "courriel-titre");
      fenetreMail.innerHTML =
        '<button type="button" class="courriel__fermer" aria-label="Fermer">×</button>' +
        '<p class="surtitre">Nous écrire</p>' +
        '<h2 id="courriel-titre">Une question&nbsp;?<br /><em>Écrivez-nous</em></h2>' +
        '<p class="courriel__intro">Nous vous répondons en moins de 24&nbsp;heures.</p>' +
        '<div class="courriel__adresse"><span class="courriel__texte"></span>' +
        '<button type="button" class="courriel__copier">Copier</button></div>' +
        '<p class="courriel__ou">Ou ouvrez un nouveau message dans&nbsp;:</p>' +
        '<div class="courriel__choix">' +
        '<a class="bouton" data-courriel="gmail" target="_blank" rel="noopener">Gmail</a>' +
        '<a class="bouton bouton--contour" data-courriel="outlook" target="_blank" rel="noopener">Outlook</a>' +
        '<a class="bouton bouton--contour" data-courriel="direct">Ma messagerie</a>' +
        "</div>";
      document.body.appendChild(fenetreMail);
      fenetreMail.querySelector(".courriel__fermer").addEventListener("click", function () { fenetreMail.close(); });
      // Un clic sur le voile autour de la fenêtre la ferme.
      fenetreMail.addEventListener("click", function (e) { if (e.target === fenetreMail) fenetreMail.close(); });
      fenetreMail.querySelector(".courriel__copier").addEventListener("click", function () {
        var b = this;
        var fait = function () { b.textContent = "Copiée"; setTimeout(function () { b.textContent = "Copier"; }, 1800); };
        if (navigator.clipboard) navigator.clipboard.writeText(fenetreMail.dataset.adresse).then(fait, function () {});
        else {
          var sel = window.getSelection(), r = document.createRange();
          r.selectNodeContents(fenetreMail.querySelector(".courriel__texte"));
          sel.removeAllRanges(); sel.addRange(r);
        }
      });
    }
    var enc = encodeURIComponent;
    fenetreMail.dataset.adresse = adresse;
    fenetreMail.querySelector(".courriel__texte").textContent = adresse;
    fenetreMail.querySelector('[data-courriel="gmail"]').href =
      "https://mail.google.com/mail/?view=cm&fs=1&to=" + enc(adresse) + "&su=" + enc(sujet);
    fenetreMail.querySelector('[data-courriel="outlook"]').href =
      "https://outlook.office.com/mail/deeplink/compose?to=" + enc(adresse) + "&subject=" + enc(sujet);
    fenetreMail.querySelector('[data-courriel="direct"]').href = "mailto:" + adresse + "?subject=" + enc(sujet);
    if (fenetreMail.showModal) fenetreMail.showModal(); else fenetreMail.setAttribute("open", "");
    fenetreMail.focus();
  }
  if (surOrdinateur) {
    document.addEventListener("click", function (e) {
      var lien = e.target.closest && e.target.closest('a[href^="mailto:"]');
      if (!lien || lien.closest(".courriel")) return; // « Ma messagerie » part directement
      e.preventDefault();
      ouvrirFenetreMail(lien.getAttribute("href").replace(/^mailto:/, "").split("?")[0]);
    });
  }

  // ── Page merci : le code de la commande, tout de suite à l'écran ──
  // Stripe renvoie ici avec ?session_id=cs_… ; le code est créé par le
  // webhook quelques secondes plus tôt (202 tant qu'il n'est pas prêt).
  var blocCommande = document.querySelector("[data-commande]");
  var idSession = new URLSearchParams(location.search).get("session_id") || "";
  if (blocCommande && /^cs_(test|live)_/.test(idSession)) {
    var essaisCommande = 0;
    var remplir = function (sel, texte) {
      var el = document.querySelector(sel);
      if (el) el.textContent = texte;
    };
    var afficherCommande = function (c) {
      remplir("[data-commande-code]", c.code);
      remplir("[data-commande-places]", c.places ? " · " + c.places + " personnes" : "");
      remplir("[data-commande-email]", c.email || "votre adresse");
      remplir("[data-commande-message]", c.message || "");
      blocCommande.hidden = false;
      document.querySelector("[data-commande-bloc]").hidden = !c.message;
      var sans = document.querySelector("[data-sans-commande]");
      if (sans) sans.hidden = true;
      var facture = document.querySelector("[data-commande-facture]");
      if (facture && c.factureUrl) {
        facture.href = c.factureUrl;
        facture.hidden = false;
      }
      var portail = document.querySelector("[data-commande-portail]");
      if (portail && c.gererUrl) {
        portail.querySelector("a").href = c.gererUrl;
        portail.hidden = false;
      }
      blocCommande.dataset.code = c.code;
      blocCommande.dataset.message = c.message || "";
    };
    var lireCommande = function () {
      fetch(API + "commandeEntreprise?session=" + encodeURIComponent(idSession))
        .then(function (r) { return r.json().then(function (j) { return { statut: r.status, j: j }; }); })
        .then(function (rep) {
          if (rep.statut === 200 && rep.j.pret) afficherCommande(rep.j);
          else if (rep.statut === 202 && ++essaisCommande < 10) setTimeout(lireCommande, 2000);
        })
        .catch(function () { /* l'e-mail reste le chemin de secours */ });
    };
    lireCommande();
    Array.prototype.forEach.call(document.querySelectorAll("[data-copier]"), function (b) {
      b.addEventListener("click", function () {
        var texte = b.dataset.copier === "code" ? blocCommande.dataset.code : blocCommande.dataset.message;
        var libelle = b.textContent;
        var fait = function () {
          b.textContent = "Copié";
          setTimeout(function () { b.textContent = libelle; }, 1800);
        };
        if (navigator.clipboard && texte) navigator.clipboard.writeText(texte).then(fait, function () {});
      });
    });
  }

  var annee = document.querySelector("[data-annee]");
  if (annee) annee.textContent = new Date().getFullYear();
})();
