#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
variant="${1:-rootless}"
case "$variant" in rootless|rootful|rootful-legacy) ;; *) echo 'Unknown variant' >&2; exit 2;; esac
cp "packaging/$variant.control" control
builder="${MAKE:-}"
if [[ -z "$builder" ]]; then
  if command -v gmake >/dev/null; then builder=gmake; else builder=make; fi
fi
"$builder" clean PACKAGE_VARIANT="$variant"
"$builder" package FINALPACKAGE=1 PACKAGE_VARIANT="$variant"
