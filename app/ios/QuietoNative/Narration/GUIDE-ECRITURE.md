# Guide d'écriture des scripts Quieto

Ces scripts seront lus par une voix de synthèse ElevenLabs (français, voix posée). Ils remplacent un texte générique que l'app lisait pour toutes les séances. Chaque script doit être un vrai contenu de méditation, humain, précis, qui tient la promesse de son titre. Un utilisateur paie 60 € par an pour ça.

Lis d'abord les 8 scripts déjà écrits (`scripts/fr/express_*.md`) : ils donnent le ton.

## Format (obligatoire)

```markdown
---
id: decouverte_1
title: Ma première méditation
duration: 300
ending: day
---
Premier paragraphe.

[pause 6s]

Deuxième paragraphe.
```

- `duration` = minutes du catalogue × 60. `ending` : voir `CATALOGUE.md` (`sleep` pour tout ce qui sert à s'endormir).
- Un paragraphe = 1 à 4 phrases lues d'un seul tenant. Une ligne vide entre deux paragraphes.
- `[pause Ns]` seul sur sa ligne, entre 2 et 30 secondes. Mets une pause après **chaque consigne qui demande de faire quelque chose** (respirer, sentir, imaginer, compter), d'une durée qui permet de le faire vraiment : 2 respirations ≈ 10 s, observer une zone du corps ≈ 10–20 s.
- Le générateur allonge les pauses proportionnellement pour atteindre la durée (45 s max chacune). Il ne crée pas de texte : s'il manque des mots, la séance est trop vide.

## Quantité de texte

La voix lit environ 2,2 mots par seconde. Vise ce nombre de **mots par minute de séance** :

| Durée | Mots par minute |
|---|---|
| 1 à 3 min | 60 à 75 |
| 4 à 8 min | 50 à 60 |
| 9 à 12 min | 45 à 55 |
| 15 min et plus | 38 à 45 |
| Séances `sleep` | retirer 15 % (plus d'espace, surtout à la fin) |
| `discover_open_sitting` (semi-silencieuse) | 25 à 30 |

Exemple : 10 min de jour ≈ 500 mots. 20 min de sommeil ≈ 680 mots.

Vérifie ton lot avec la voix gratuite du Mac (aucun coût) :

```bash
cd app/ios/QuietoNative/Narration
node generate.mjs --dry-run
node generate.mjs --preview --only id1,id2,id3
```

Chaque ligne doit afficher une durée à ±10 % de la cible, sans ligne `⚠︎`. Corrige le texte ou les pauses sinon.

## Structure d'une séance

1. **Accueil (1–2 paragraphes)** : reconnaître la situation concrète en une phrase vraie (« Tu sors d'une réunion où on a critiqué ton travail. »). Jamais « Bienvenue dans <titre> ».
2. **Installation** : posture adaptée au contexte (au bureau, au lit, debout dans le métro, en marchant), yeux ouverts ou fermés, 2 ou 3 respirations.
3. **Cœur de la séance** : **la technique annoncée dans le catalogue, réellement guidée pas à pas**. C'est 60 à 70 % du texte. Par exemple, une relaxation de Jacobson fait contracter 5 secondes puis relâcher chaque groupe musculaire, nommé un par un. Une metta donne les phrases de souhait et les fait répéter pour chaque personne.
4. **Approfondissement** : laisser pratiquer seul, avec des rappels de plus en plus espacés.
5. **Fin** :
   - `day` : revenir à la pièce, bouger doucement, une phrase qui relie à la suite de la journée. Pas de morale.
   - `sleep` : **aucune consigne de réveil ou de mouvement**. La voix ralentit, les phrases raccourcissent, la dernière est très courte (« Tu peux te laisser aller au sommeil. »), suivie d'une longue pause.

## Langue et ton

- Tutoiement. Phrases courtes, mots du quotidien, présent de l'indicatif. On parle à une personne, pas à un public.
- Concret et sensoriel : « le poids de tes talons sur le sol » plutôt que « ton ancrage ».
- Varier les verbes. Éviter les tics : « laisse aller », « simplement », « doucement » à chaque phrase, « prends conscience de ».
- Jamais d'injonction à réussir (« détends-toi », « vide ton esprit »). On propose : « tu peux », « si c'est possible », « remarque ».
- Rappeler, une fois, que l'esprit qui s'égare est normal et que revenir *est* la pratique.
- **Pas d'accord au masculin ou au féminin quand tu parles de la personne** : la voix ne sait pas lire « prêt·e ». Reformule (« si tu es en position assise », « quand c'est le bon moment pour toi »). En dernier recours, le doublet « assis ou assise », une seule fois par script.
- Chiffres en lettres (« quatre secondes »). Pas de listes, pas de titres, pas d'émojis, pas d'anglicismes inutiles.
- Aucune promesse médicale (« guérir », « soigner », « éliminer le stress »). Aucune mention de l'app ou d'autres séances.

## Sujets sensibles

Pour le lieu sûr, la panique, l'anxiété, la guerre, la solitude, la tristesse, la douleur et l'imposture :
- une phrase tôt dans la séance qui autorise à ouvrir les yeux ou à arrêter à tout moment ;
- ne jamais pousser à revivre un souvenir difficile en détail ;
- pour la douleur : rappeler que ce n'est pas un soin et qu'une douleur inhabituelle se montre à un médecin.

## À la fin de ton lot

Lance `node generate.mjs --dry-run` sur tout le dossier : aucune erreur de format ne doit apparaître.
