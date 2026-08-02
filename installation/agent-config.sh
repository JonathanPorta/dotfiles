#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dotfiles_dir=$(cd "$script_dir/../dotfiles" && pwd)

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: python3 is required to merge agent config fragments safely." >&2
  exit 1
fi

exec python3 "$dotfiles_dir/helpers/install_agent_config.py" \
  --dotfiles-dir "$dotfiles_dir" \
  --home "$HOME"
