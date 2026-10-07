# Narrations des séances

Un script = un fichier `scripts/fr/<id-de-la-séance>.md`. Le texte est écrit ici et nulle part ailleurs : l'app lit le fichier `Resources/Narration/narration-fr.json` produit par `generate.mjs`.

## Format d'un script

```markdown
---
id: express_1              # ID de la séance dans SessionCatalog.swift
title: Avant un appel difficile
duration: 120              # durée visée, en secondes
ending: day                # day = retour au quotidien, sleep = la voix s'éteint (20 s de silence final)
---
Premier paragraphe, lu d'un seul tenant.

[pause 6s]

Deuxième paragraphe.
Un paragraphe sans [pause] avant lui est séparé du précédent par 2,5 s.
```

- `[pause Ns]` est seul sur sa ligne. Les pauses explicites sont ajustées automatiquement (proportionnellement, entre 2 et 45 s chacune) pour atteindre la durée visée, que la voix soit plus rapide ou plus lente que prévu.
- Pas d'écriture inclusive à point (« prêt·e ») : la voix ne sait pas la lire. Reformuler sans accord.

## Étapes

```bash
cd app/ios/QuietoNative/Narration
node generate.mjs --dry-run      # nombre de caractères = coût ElevenLabs
node generate.mjs --preview      # voix gratuite du Mac dans out-preview/ : écouter le rythme avant de payer
node generate.mjs --text-only    # l'app lit les nouveaux textes avec la voix Apple, sans audio ElevenLabs
```

Génération réelle, une seule fois :

```bash
ELEVENLABS_API_KEY=... ELEVENLABS_VOICE_ID=... node generate.mjs
SUPABASE_URL=https://<projet>.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node upload.mjs
```

Puis compiler l'app : le JSON mis à jour contient le chemin `fr/<id>.m4a` et la durée réelle de chaque séance.

- Chaque paragraphe est mis en cache dans `.cache/` : relancer `generate.mjs` après avoir corrigé un paragraphe ne refacture que ce paragraphe et ses voisins.
- `--only express_1,express_4` limite la génération ou l'envoi à quelques séances.
- `ELEVENLABS_MODEL` choisit le modèle (défaut `eleven_multilingual_v2`). Les réglages de voix sont en haut de `generate.mjs`.
- Sortie : AAC mono 96 kbit/s, 44,1 kHz, niveau sonore homogène entre les séances.

## Côté app

1. Fichier téléchargé sur l'iPhone, s'il existe.
2. Sinon, lecture en streaming depuis le bucket privé `session-audio` (URL signée, abonnement requis).
3. Sinon (hors ligne, fichier absent), lecture du même script avec la voix Apple.

Une séance qui a un script mais pas encore d'audio passe directement à l'étape 3.
