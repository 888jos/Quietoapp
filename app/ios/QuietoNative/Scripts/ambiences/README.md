# Ambiances

16 sons, déclarés dans `QuietoAmbience.catalog` (`QuietoModels.swift`). L'app ne propose que ceux dont le fichier est présent dans `Resources/Ambiences/`.

- **Bruits blanc, rose et brun** : générés par `build_ambiences.py` (stéréo décorrélée, 30 s, boucle sans couture). Déjà fait.
- **Enregistrements réels** : 7 sons Pixabay (pluie, orage, océan, rivière, forêt, vent, feu), listés dans `ambiences.json`. Chaque son est une boucle courte (30 s ou moins), répétée sans fin par le lecteur : l’app reste légère.

## Importer les enregistrements

1. Pour chaque entrée de `ambiences.json` avec une `url` : ouvrir la page, télécharger le fichier original (bouton *Download*), le renommer `<id>.<extension d'origine>` et le placer dans `sources/` (par exemple `sources/rain.flac`). Ce dossier n'est pas versionné.
2. Écouter `cafe` et `night-train` : aucune voix compréhensible ni annonce ne doit rester. Ajuster `start` et `length` dans `ambiences.json` pour garder le bon segment.
3. Lancer, depuis `app/ios/QuietoNative` :

   ```bash
   python3 Scripts/ambiences/build_ambiences.py
   ```

   Chaque son est découpé, bouclé par un fondu enchaîné de 4 s, ramené au même niveau sonore, puis encodé en AAC stéréo 160 kbit/s dans `Resources/Ambiences/ambience-<id>.m4a`. L'ancienne boucle synthétique MP3 de même nom est supprimée.
4. `xcodegen generate`, puis compiler.

`python3 Scripts/ambiences/build_ambiences.py rain ocean` ne traite que ces sons. Le script liste à la fin les sources encore manquantes.

## Licences

Garder une trace de chaque page Freesound (URL, auteur, licence CC0, date de téléchargement) : c'est l'auteur qui déclare la licence, et Freesound ne la garantit pas. Ne pas utiliser de son CC-BY-NC (interdit en usage commercial). Un son CC-BY imposerait de créditer l'auteur dans l'app.
