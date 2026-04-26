#!/usr/bin/env bash
set -eo pipefail

# Renders dotfiles/cmux-settings.json (JSONC template with __HOME__ placeholders)
# into $HOME/.config/cmux/settings.json, substituting __HOME__ with the live $HOME.
# Mirrors the generate_gitconfig.sh pattern: idempotent, prepends a header so the
# rendered file announces it is generated.

SCRIPT_GENERATOR_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
TEMPLATE="$HOME/dotfiles/cmux-settings.json"
TARGET="$HOME/.config/cmux/settings.json"

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: cmux template not found at $TEMPLATE" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"

echo "Generating $TARGET using $SCRIPT_GENERATOR_PATH..."

{
  printf '// This settings.json was generated via %s.\n' "$SCRIPT_GENERATOR_PATH"
  printf '// Edit dotfiles/cmux-settings.json (the template), not this file.\n'
  printf '// Re-run %s or installation/symlink.sh to regenerate.\n' "$SCRIPT_GENERATOR_PATH"
  echo
  sed "s|__HOME__|$HOME|g" "$TEMPLATE"
} > "$TARGET"
