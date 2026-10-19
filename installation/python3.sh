#!/usr/bin/env zsh

set +e
INSTALL_DIR=$(dirname "$0")
source $INSTALLATION_SOURCE_DIR/include/lib.sh
set -eo pipefail

# An installer is a child process: detach from the caller's Python environment
# here without deactivating or changing their interactive shell.
for python_env in "${VIRTUAL_ENV:-}" "${CONDA_PREFIX:-}"; do
  [[ -n "$python_env" ]] || continue
  echo_cyan "Ignoring active Python environment for setup: $python_env"
  clean_path=()
  for path_entry in "${path[@]}"; do
    [[ "${path_entry%/}" == "${python_env%/}/bin" ]] || clean_path+=("$path_entry")
  done
  path=("${clean_path[@]}")
done
unset VIRTUAL_ENV VIRTUAL_ENV_PROMPT CONDA_PREFIX CONDA_DEFAULT_ENV CONDA_SHLVL PYTHONHOME PYTHONPATH
# Find an existing user-installed uv before considering a fresh installation.
export PATH="$HOME/.local/bin:$PATH"

# Python3 and dev deps
echo_green "Installing python3 requirements..."
if [[ $OS == 'linux' ]]; then
    pkg_install python3-devel
  elif [[ $OS == 'darwin' ]]; then
    pkg_install python-build
  fi
echo_green "Done."

# uv - yet-another python package manager
if ! (exists uv); then
  echo_green "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  echo_green "Done."
else
  echo_cyan "uv is already installed. Skipping..."
fi

# Reuse a suitable interpreter, including an existing uv-managed Python. Match
# the 3.11+ requirement of the agent-config step, ignoring project/venv selection.
if ! tool_python=$(uv python find --system --no-project --no-python-downloads '>=3.11' 2>/dev/null); then
  echo_green "No Python 3.11+ found outside a virtualenv. Installing with uv..."
  uv python install 3.12
  tool_python=$(uv python find --system --no-project --no-python-downloads 3.12)
fi
python_version=$("$tool_python" --version)
echo_cyan "Using $python_version at $tool_python"

# Python CLI tools belong in isolated environments, including on PEP 668 systems.
for python_tool in virtualenv pipenv poetry; do
  if exists "$python_tool"; then
    echo_cyan "$python_tool is already installed. Skipping..."
  else
    echo_green "Installing $python_tool..."
    uv tool install --python "$tool_python" "$python_tool"
    echo_green "Done."
  fi
done


# # conda
# if ! (exists conda); then
#   echo_green "Installing anaconda..."
#   if [[ $OS == 'linux' ]]; then
#     # https://docs.anaconda.com/anaconda/install/linux/
#     pkg_install libXcomposite libXcursor libXi libXtst libXrandr alsa-lib mesa-libEGL libXdamage mesa-libGL libXScrnSaver
#     curl -Lo $INSTALLATION_SOURCE_DIR/anaconda.sh https://repo.anaconda.com/archive/Anaconda3-2020.02-Linux-x86_64.sh
#     chmod +x $INSTALLATION_SOURCE_DIR/anaconda.sh
#     $INSTALLATION_SOURCE_DIR/anaconda.sh && rm $INSTALLATION_SOURCE_DIR/anaconda.sh
#   elif [[ $OS == 'darwin' ]]; then
#     # https://docs.anaconda.com/anaconda/install/mac-os/
#     curl -Lo Anaconda3-2020.11-MacOSX-x86_64.sh https://repo.anaconda.com/archive/Anaconda3-2020.11-MacOSX-x86_64.sh
#     chmod +x ./Anaconda3-2020.11-MacOSX-x86_64.sh
#     ./Anaconda3-2020.11-MacOSX-x86_64.sh
#   fi
#   echo_green "Done."
# else
#   echo_cyan "anaconda is already installed. Skipping..."
# fi
