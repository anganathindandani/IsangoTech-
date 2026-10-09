#!/usr/bin/env bash
# Build command for Cloudflare Workers Builds, which has no Flutter installed.
# Downloads a pinned Flutter release, then builds the web app.
# Needs two build variables in Cloudflare: SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.
set -euo pipefail

FLUTTER_VERSION="3.47.6"

if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
  echo "Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY as build variables in Cloudflare." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  sdk="${FLUTTER_HOME:-$HOME/flutter-sdk}"
  if [ ! -x "$sdk/flutter/bin/flutter" ]; then
    mkdir -p "$sdk"
    echo "Downloading Flutter $FLUTTER_VERSION…"
    curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      | tar -xJ -C "$sdk"
  fi
  export PATH="$sdk/flutter/bin:$PATH"
  git config --global --add safe.directory "$sdk/flutter" || true
fi

flutter --disable-analytics >/dev/null 2>&1 || true
flutter --version
flutter pub get
flutter build web --release --no-web-resources-cdn \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
