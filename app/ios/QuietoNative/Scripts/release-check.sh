#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
REPOSITORY_DIR=${PROJECT_DIR:h:h:h}
STRICT=${1:-local}

cd "$REPOSITORY_DIR"

node backend/migration/validate-sql.mjs

for localization in en es de ja ko; do
  for table in Localizable Catalog Extended; do
    plutil -lint "app/ios/QuietoNative/Resources/${localization}.lproj/${table}.strings" >/dev/null
  done
done

if rg -n 'REPLACE_WITH_' app/ios/QuietoNative/project.yml >/dev/null; then
  if [[ "$STRICT" == "strict" ]]; then
    print -u2 "Release blocked: configure the public Supabase and Superwall values in project.yml."
    exit 2
  fi
  print "Local validation: remote Supabase/Superwall values are intentionally placeholders."
fi

xcodebuild \
  -project app/ios/QuietoNative/QuietoNative.xcodeproj \
  -scheme QuietoNative \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/quieto-release-check \
  build CODE_SIGNING_ALLOWED=NO

print "Quieto native validation completed (${STRICT})."
