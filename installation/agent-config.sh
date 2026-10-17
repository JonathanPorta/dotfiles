#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dotfiles_dir=$(cd "$script_dir/../dotfiles" && pwd)

if [ -n "${PYTHON3_BIN:-}" ]; then
  python_candidates=("$PYTHON3_BIN")
else
  python_candidates=(
    python3
    python3.14
    python3.13
    python3.12
    python3.11
    /opt/homebrew/bin/python3
    /usr/local/bin/python3
  )
fi

python_bin=""
for candidate in "${python_candidates[@]}"; do
  command -v "$candidate" >/dev/null 2>&1 || continue
  if "$candidate" -c \
    'import sys, tomllib; raise SystemExit(sys.version_info < (3, 11))' \
    >/dev/null 2>&1; then
    python_bin="$candidate"
    break
  fi
done

# No suitable system Python: let uv supply one, unless a caller pinned PYTHON3_BIN.
uv_bin=$(command -v uv || echo "$HOME/.local/bin/uv")
if [ -z "$python_bin" ] && [ -z "${PYTHON3_BIN:-}" ] && [ -x "$uv_bin" ]; then
  python_bin=$("$uv_bin" python find '>=3.11' 2>/dev/null) ||
    { "$uv_bin" python install 3.12 >/dev/null 2>&1 && python_bin=$("$uv_bin" python find 3.12 2>/dev/null); } ||
    python_bin=""
fi

if [ -z "$python_bin" ]; then
  echo "Skipping optional Claude/Codex agent config: Python 3.11+ with tomllib is unavailable." >&2
  echo "Re-run installation/agent-config.sh after installing a compatible Python." >&2
  exit 0
fi

exec "$python_bin" "$dotfiles_dir/helpers/install_agent_config.py" \
  --dotfiles-dir "$dotfiles_dir" \
  --home "$HOME"
