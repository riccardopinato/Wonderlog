#!/usr/bin/env bash
# Shared by the PR foundation and the actual GitHub Pages distribution build.
set -euo pipefail

python3 tool/check_web_bundle.py --deps
test -d web
curl --fail --location --retry 3 --retry-delay 2 \
  https://github.com/simolus3/drift/releases/download/drift-2.31.0/drift_worker.js \
  --output web/drift_worker.js
curl --fail --location --retry 3 --retry-delay 2 \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-2.9.4/sqlite3.wasm \
  --output web/sqlite3.wasm
python3 tool/check_web_bundle.py --assets
