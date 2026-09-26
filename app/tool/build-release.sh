#!/usr/bin/env bash
# Build release de Quieto avec OBFUSCATION du code Dart (audit du 02/09/2026).
#
#   tool/build-release.sh ipa        # iOS  → build/ios/ipa/quieto.ipa
#   tool/build-release.sh appbundle  # Android → build/app/outputs/bundle/release/app-release.aab
#
# --obfuscate : les noms de classes/fonctions Dart disparaissent du binaire
#   (un IPA/APK décompilé ne livre plus la logique en clair).
# --split-debug-info : les symboles vont dans symbols/<version>/ — À GARDER
#   (hors git) pour lire les crashs de cette version. Sans ce dossier, une
#   pile d'erreur obfusquée est illisible.
set -euo pipefail
cd "$(dirname "$0")/.."
cible="${1:-ipa}"
version="$(grep -E '^version:' pubspec.yaml | awk '{print $2}')"
dossier="symbols/${version}"
mkdir -p "$dossier"
echo "▶ flutter build ${cible} — version ${version}, symboles dans ${dossier}/"
flutter build "${cible}" \
  --dart-define-from-file=.env.json \
  --obfuscate \
  --split-debug-info="${dossier}" \
  "${@:2}"
echo "✓ Build terminé. Archive ${dossier}/ avec la release (jamais dans git)."
