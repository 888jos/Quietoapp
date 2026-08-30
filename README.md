# Quieto

Application de méditation guidée en français (iOS + Android, Flutter) : séances courtes ancrées dans le quotidien + **Louane**, compagnonne IA (chat + programme 7 jours). Version actuelle : **1.0.21+30** (branche `feat/vigie-conversion`, ipa buildé — reste l'upload Transporter + la soumission ; la 1.0.20 est approuvée sur les deux stores — maj 30/08/2026).

> Pour comprendre le produit en 5 minutes : lire **`QUIETO.md`**.

## Lancer l'app

```bash
flutter run --dart-define-from-file=.env.json
```

⚠️ Le fichier `.env.json` (clés RevenueCat, non versionné) est **obligatoire** — sans lui, `String.fromEnvironment('REVENUE_CAT_KEY')` est vide et les achats ne fonctionnent pas. Même flag pour les builds (`flutter build ipa/appbundle`).

## Les docs du repo

| Fichier | Rôle |
|---|---|
| `QUIETO.md` | Présentation produit + direction artistique (à jour à chaque release) |
| `ARCHITECTURE.md` | Structure du code, stack, navigation |
| `SPECS.md` | Spécifications produit |
| `CONFIG.md` | Configuration (Firebase, RevenueCat…) |
| `DECISIONS.md` | Décisions techniques datées (append-only) |
| `BUGS_A_CORRIGER.md` | Bugs connus et leur statut |
| `AMELIORATIONS.md` | Backlog produit conversion & rétention (chiffres Vigie) |
| `DIRECTION-ARTISTIQUE.md` | Parti pris visuel (gouache, anti-« look IA ») |
| `PROMPTS-VISUELS.md` | Méthode de génération des images (API Gemini) |
| `AUDIO_SCRIPTS.md` | Scripts des séances audio |
| `CONTRIBUTING.md` | Règles de contribution |
| `~/dev/JOURNAL-QUIETO.md` | Journal de bord du projet (hors repo — source de vérité entre sessions) |

Backend (Cloud Functions) : `~/dev/quieto-backend`. Analytics maison (la Vigie) : `~/dev/Quieto IA/analytics`.

*(README réécrit le 12/08/2026 — remplaçait le boilerplate Flutter d'origine.)*
