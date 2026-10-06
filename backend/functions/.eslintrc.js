module.exports = {
  env: {
    es2022: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2022,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    // ── Règles de JUSTESSE (06/10/2026) : le lint doit attraper les vrais
    // bugs avant chaque déploiement (predeploy de firebase.json). ──
    "no-unused-vars": ["error", {"args": "none", "caughtErrors": "none"}],
    "no-undef": "error",
    // Utiliser une variable avant sa déclaration dans la même portée = zone
    // morte (TDZ) → ReferenceError. C'est exactement le bug du 15/08
    // (`const texte` qui masquait texte() dans accueilOnboarding). Les
    // usages depuis une fonction appelée plus tard restent permis.
    "no-use-before-define": ["error", {"functions": false, "classes": false, "variables": false}],
    // ── Règles de PURE MISE EN FORME, coupées (06/10/2026) : index.js
    // (~4 600 lignes) n'a jamais été linté (eslint-disable global). Les
    // appliquer produisait ~1 900 erreurs d'indentation, longueur de ligne,
    // espaces dans les accolades et JSDoc, sans aucun bug derrière. Mieux
    // vaut un lint qui tourne et passe (justesse) qu'un lint désactivé. ──
    "indent": "off",
    "max-len": "off",
    "object-curly-spacing": "off",
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "curly": "off",
    "brace-style": "off",
    "block-spacing": "off",
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
