#!/usr/bin/env node
/* eslint-disable */
// ============================================================
//  Accès entreprise (B2B) — outil d'administration en ligne de commande.
//  Les entreprises qui paient via Stripe sont créées TOUTES SEULES (webhook
//  "stripe"). Cet outil sert au reste : démo pour la review Apple, CSE qui
//  paie par virement, nom à corriger, place à libérer, places à ajouter.
//
//  Usage (depuis quieto-backend/) :
//    node scripts/entreprise.js liste
//    node scripts/entreprise.js creer "Nom de l'entreprise" 20 2027-09-30
//    node scripts/entreprise.js prolonger ACME-7K2P 2028-09-30
//    node scripts/entreprise.js places ACME-7K2P 30
//    node scripts/entreprise.js renommer ACME-7K2P "Acme France"
//    node scripts/entreprise.js membres ACME-7K2P
//    node scripts/entreprise.js retirer ACME-7K2P <uid>
//    node scripts/entreprise.js desactiver ACME-7K2P
//    node scripts/entreprise.js stripe-installer https://quietopro.com
//    node scripts/entreprise.js stripe-places ACME-7K2P 40
//
//  Stripe : la clé est lue dans Secret Manager (STRIPE_SECRET_KEY, posée
//  par Paul avec `firebase functions:secrets:set STRIPE_SECRET_KEY`).
//  « stripe-installer » crée le produit, le portail client et le webhook,
//  range le secret du webhook dans Secret Manager et écrit les paramètres
//  dans functions/.env. À relancer en passant du mode test au mode réel.
//
//  Clé de service : ~/.config/quieto/serviceAccount.json (comme la Vigie).
//  Un membre retiré garde Premium jusqu'à la fin de ce qui lui a déjà été
//  accordé (période payée + 10 jours), puis n'est plus prolongé.
// ============================================================
const path = require("path");
const fs = require("fs");
const os = require("os");
const crypto = require("crypto");
const requireFonctions = require("module").createRequire(
  path.join(__dirname, "..", "functions", "package.json"));
const { initializeApp, cert, applicationDefault } = requireFonctions("firebase-admin/app");
const { getFirestore, FieldValue } = requireFonctions("firebase-admin/firestore");
const { getAuth } = requireFonctions("firebase-admin/auth");

const cle = path.join(os.homedir(), ".config", "quieto", "serviceAccount.json");
initializeApp({
  credential: fs.existsSync(cle) ? cert(require(cle)) : applicationDefault(),
  projectId: "quieto-06",
});
const db = getFirestore();

// Même logique que functions/index.js (section ACCÈS ENTREPRISE).
const ALPHABET_CODE = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const normaliserCode = (brut) => String(brut || "").normalize("NFD")
  .replace(/[̀-ͯ]/g, "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 24);

async function nouveauCode(nom) {
  let prefixe = normaliserCode(nom).replace(/[0-9]/g, "").slice(0, 6);
  if (prefixe.length < 3) prefixe = "QUIETO";
  for (let i = 0; i < 10; i++) {
    let suffixe = "";
    for (const o of crypto.randomBytes(4)) suffixe += ALPHABET_CODE[o % ALPHABET_CODE.length];
    const code = prefixe + "-" + suffixe;
    const deja = await db.collection("entreprises").where("codeCle", "==", normaliserCode(code)).limit(1).get();
    if (deja.empty) return code;
  }
  throw new Error("aucun code libre trouvé");
}

// « 2027-09-30 » → 30/09/2027 à 23:59 heure de Paris (≈ UTC+2).
function finDeJour(date) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date || "")) throw new Error("date attendue au format AAAA-MM-JJ");
  return Date.parse(date + "T23:59:00+02:00");
}

async function trouver(code) {
  const s = await db.collection("entreprises").where("codeCle", "==", normaliserCode(code)).limit(1).get();
  if (s.empty) throw new Error("aucune entreprise avec le code " + code);
  return s.docs[0];
}

const jour = (ms) => (ms ? new Date(ms).toLocaleDateString("fr-FR") : "—");

// ── Stripe (mêmes conventions que functions/index.js) ──
const { execFileSync } = require("child_process");
const STRIPE_VERSION = "2024-06-20";
const URL_WEBHOOK = "https://us-central1-quieto-06.cloudfunctions.net/stripe";
const EVENEMENTS = [
  "checkout.session.completed", "checkout.session.async_payment_succeeded", "checkout.session.async_payment_failed",
  "customer.subscription.created", "customer.subscription.updated", "customer.subscription.deleted",
  "invoice.paid", "invoice.payment_failed",
];
const racine = path.join(__dirname, "..");
let cleStripe = null;
function lireCleStripe() {
  if (cleStripe) return cleStripe;
  cleStripe = process.env.STRIPE_SECRET_KEY || execFileSync("firebase",
    ["functions:secrets:access", "STRIPE_SECRET_KEY", "--project", "quieto-06"],
    { cwd: racine, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
  if (!/^(sk|rk)_/.test(cleStripe)) throw new Error("STRIPE_SECRET_KEY introuvable ou invalide dans Secret Manager");
  return cleStripe;
}
function formStripe(obj, prefixe = "", sortie = []) {
  for (const [k, v] of Object.entries(obj || {})) {
    if (v === undefined || v === null) continue;
    const cle = prefixe ? `${prefixe}[${k}]` : k;
    if (typeof v === "object") formStripe(v, cle, sortie);
    else sortie.push(encodeURIComponent(cle) + "=" + encodeURIComponent(String(v)));
  }
  return sortie.join("&");
}
async function stripe(methode, chemin, params) {
  const corps = params ? formStripe(params) : "";
  const r = await fetch("https://api.stripe.com/v1" + chemin + (methode === "GET" && corps ? "?" + corps : ""), {
    method: methode,
    headers: {
      "Authorization": "Bearer " + lireCleStripe(), "Stripe-Version": STRIPE_VERSION,
      ...(methode === "GET" ? {} : { "Content-Type": "application/x-www-form-urlencoded" }),
    },
    body: methode === "GET" ? undefined : corps,
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`Stripe ${r.status} : ${(j.error && j.error.message) || ""}`);
  return j;
}
// Pose (ou remplace) une ligne CLE=valeur dans functions/.env.
function ecrireEnv(cle, valeur) {
  const fichier = path.join(racine, "functions", ".env");
  let texte = fs.existsSync(fichier) ? fs.readFileSync(fichier, "utf8") : "";
  const ligne = `${cle}=${valeur}`;
  const motif = new RegExp(`^${cle}=.*$`, "m");
  texte = motif.test(texte) ? texte.replace(motif, ligne) : texte.replace(/\n?$/, "\n") + ligne + "\n";
  fs.writeFileSync(fichier, texte);
}
// La grille de prix est lue dans functions/index.js : une seule source.
function tarif(places, rythme) {
  const src = fs.readFileSync(path.join(racine, "functions", "index.js"), "utf8");
  const bloc = src.match(/const GRILLE_ENTREPRISE = \[([\s\S]*?)\];/);
  const grille = [...bloc[1].matchAll(/\[(\d+),\s*([\d.]+)\]/g)].map((x) => [+x[1], +x[2]]);
  const annuel = grille.find(([min]) => places >= min)[1];
  return Math.round((rythme === "mensuel" ? annuel / 10 : annuel) * 100) / 100;
}

const commandes = {
  async liste() {
    const s = await db.collection("entreprises").get();
    if (s.empty) return console.log("Aucune entreprise.");
    for (const d of s.docs) {
      const e = d.data();
      console.log(`${e.actif ? "🟢" : "⚪️"} ${e.code}  ${e.nom}  ${e.nbMembres || 0}/${e.places} places  ` +
        `fin ${jour(e.finMs)}  (${e.source}${e.statut ? ", " + e.statut : ""})  ${e.email || ""}`);
    }
  },

  async creer(nom, places, date) {
    if (!nom || !(parseInt(places, 10) > 0)) throw new Error('usage : creer "Nom" places AAAA-MM-JJ');
    const code = await nouveauCode(nom);
    const ref = db.collection("entreprises").doc("manuel_" + crypto.randomBytes(6).toString("hex"));
    await ref.set({
      nom: String(nom).slice(0, 60), nomManuel: true, code, codeCle: normaliserCode(code),
      places: parseInt(places, 10), nbMembres: 0, finMs: finDeJour(date), actif: true,
      statut: "manuel", source: "manuel", email: "", codeEnvoye: true,
      creeLe: FieldValue.serverTimestamp(), majLe: FieldValue.serverTimestamp(),
    });
    console.log(`✅ ${nom} créée — code ${code}, ${places} places, jusqu'au ${jour(finDeJour(date))}`);
  },

  async prolonger(code, date) {
    const d = await trouver(code);
    await d.ref.update({ finMs: finDeJour(date), actif: true, majLe: FieldValue.serverTimestamp() });
    console.log(`✅ ${d.data().nom} prolongée jusqu'au ${jour(finDeJour(date))}`);
  },

  async places(code, n) {
    const d = await trouver(code);
    await d.ref.update({ places: parseInt(n, 10), majLe: FieldValue.serverTimestamp() });
    console.log(`✅ ${d.data().nom} : ${n} places (${d.data().nbMembres || 0} prises)`);
    if (d.data().source === "stripe") console.log("⚠️  Client Stripe : utilise plutôt « stripe-places » (sinon le prochain événement Stripe remet les places payées).");
  },

  async renommer(code, nom) {
    const d = await trouver(code);
    await d.ref.update({ nom: String(nom).slice(0, 60), nomManuel: true, majLe: FieldValue.serverTimestamp() });
    console.log(`✅ ${d.data().nom} → ${nom}`);
  },

  async membres(code) {
    const d = await trouver(code);
    const s = await d.ref.collection("membres").get();
    console.log(`${d.data().nom} : ${s.size} membre(s)`);
    for (const m of s.docs) {
      let qui = "";
      try {
        const u = await getAuth().getUser(m.id);
        qui = [u.displayName, u.email].filter(Boolean).join(" · ");
      } catch (_) {
        qui = "(compte supprimé)";
      }
      console.log(`  ${m.id}  ${qui}  depuis ${m.data().depuis ? m.data().depuis.toDate().toLocaleDateString("fr-FR") : "—"}`);
    }
  },

  async retirer(code, uid) {
    const d = await trouver(code);
    const mRef = d.ref.collection("membres").doc(uid);
    const lienRef = db.collection("acces_entreprise").doc(uid);
    await db.runTransaction(async (t) => {
      const [m, lien] = await Promise.all([t.get(mRef), t.get(lienRef)]);
      if (!m.exists) throw new Error("ce compte n'est pas membre de " + d.data().nom);
      t.delete(mRef);
      t.set(d.ref, { nbMembres: FieldValue.increment(-1) }, { merge: true });
      if (lien.exists && lien.data().entreprise === d.id) t.delete(lienRef);
    });
    console.log(`✅ place libérée chez ${d.data().nom}`);
  },

  async desactiver(code) {
    const d = await trouver(code);
    await d.ref.update({ actif: false, majLe: FieldValue.serverTimestamp() });
    console.log(`✅ ${d.data().nom} désactivée (plus de nouvelles activations ni de prolongations)`);
    if (d.data().source === "stripe") console.log("⚠️  Client Stripe : le prochain paiement la réactivera. Résilie plutôt l'abonnement dans Stripe.");
  },

  // Produit, portail client et webhook Stripe, puis paramètres dans .env.
  async "stripe-installer"(site) {
    if (!/^https?:\/\//.test(site || "")) throw new Error("usage : stripe-installer https://adresse-du-site");
    const mode = lireCleStripe().includes("_test_") ? "TEST" : "RÉEL";
    console.log(`Stripe en mode ${mode}`);

    const produits = await stripe("GET", "/products", { limit: 100, active: "true" });
    let produit = produits.data.find((x) => x.metadata && x.metadata.origine === "quieto-entreprise");
    if (!produit) {
      produit = await stripe("POST", "/products", {
        name: "Quieto Entreprise",
        description: "Quieto Premium pour chaque salarié couvert : séances guidées, Louane, programme de 7 jours.",
        metadata: { origine: "quieto-entreprise" },
      });
    }
    console.log("✅ produit", produit.id);

    const configs = await stripe("GET", "/billing_portal/configurations", { limit: 100 });
    let portail = configs.data.find((x) => x.metadata && x.metadata.origine === "quieto-entreprise");
    if (!portail) {
      portail = await stripe("POST", "/billing_portal/configurations", {
        business_profile: { headline: "Quieto Entreprise : votre abonnement" },
        features: {
          invoice_history: { enabled: true },
          payment_method_update: { enabled: true },
          customer_update: { enabled: true, allowed_updates: ["email", "address", "tax_id", "name"] },
          subscription_cancel: { enabled: true, mode: "at_period_end" },
        },
        login_page: { enabled: true },
        metadata: { origine: "quieto-entreprise" },
      });
    }
    console.log("✅ portail client", portail.login_page.url);

    const webhooks = await stripe("GET", "/webhook_endpoints", { limit: 100 });
    const ancien = webhooks.data.find((x) => x.url === URL_WEBHOOK);
    if (ancien) {
      // Le secret d'un webhook existant ne se relit pas : on le recrée.
      await stripe("DELETE", "/webhook_endpoints/" + ancien.id);
      console.log("♻️  ancien webhook supprimé", ancien.id);
    }
    const webhook = await stripe("POST", "/webhook_endpoints", {
      url: URL_WEBHOOK, api_version: STRIPE_VERSION, enabled_events: EVENEMENTS,
      description: "Quieto Entreprise : abonnements → codes entreprise (Cloud Function stripe)",
    });
    const tmp = path.join(os.tmpdir(), "whsec-" + crypto.randomBytes(4).toString("hex"));
    fs.writeFileSync(tmp, webhook.secret, { mode: 0o600 });
    try {
      execFileSync("firebase", ["functions:secrets:set", "STRIPE_WEBHOOK_SECRET", "--data-file", tmp, "--project", "quieto-06", "--force"],
        { cwd: racine, stdio: ["ignore", "ignore", "inherit"] });
    } finally {
      fs.unlinkSync(tmp);
    }
    console.log("✅ webhook", webhook.id, "(secret rangé dans Secret Manager)");

    ecrireEnv("STRIPE_PRODUIT", produit.id);
    ecrireEnv("STRIPE_PORTAIL", portail.login_page.url);
    ecrireEnv("SITE_ENTREPRISE", site.replace(/\/$/, ""));
    console.log("✅ functions/.env : STRIPE_PRODUIT, STRIPE_PORTAIL, SITE_ENTREPRISE");
    console.log("Reste à déployer : firebase deploy --only functions:stripe,functions:paiementEntreprise");
  },

  // Change le nombre de places d'un client Stripe : nouveau prix par
  // salarié selon la grille, facturation au prorata par Stripe. Le webhook
  // met ensuite les places à jour dans Firestore.
  async "stripe-places"(code, n) {
    const places = parseInt(n, 10);
    if (!(places >= 10 && places <= 999)) throw new Error("usage : stripe-places CODE 10..999");
    const d = await trouver(code);
    if (d.data().source !== "stripe") throw new Error("pas un client Stripe : utilise « places »");
    const abo = await stripe("GET", "/subscriptions/" + d.id);
    const item = abo.items.data[0];
    const rythme = item.price.recurring.interval === "month" ? "mensuel" : "annuel";
    const unitaire = tarif(places, rythme);
    await stripe("POST", "/subscription_items/" + item.id, {
      quantity: places,
      price_data: {
        currency: "eur", product: item.price.product, unit_amount: Math.round(unitaire * 100),
        recurring: { interval: item.price.recurring.interval },
      },
      proration_behavior: "create_prorations",
    });
    await stripe("POST", "/subscriptions/" + d.id, { metadata: { places: String(places) } });
    console.log(`✅ ${d.data().nom} : ${places} places à ${unitaire.toFixed(2)} € par salarié (${rythme}), prorata facturé par Stripe`);
  },
};

const [cmd, ...args] = process.argv.slice(2);
if (!commandes[cmd]) {
  console.log("Commandes : " + Object.keys(commandes).join(", ") + " (détail en tête du fichier)");
  process.exit(1);
}
commandes[cmd](...args).then(() => process.exit(0)).catch((e) => {
  console.error("❌ " + e.message);
  process.exit(1);
});
