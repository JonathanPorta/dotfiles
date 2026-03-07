#!/bin/bash
set -e

# Use dynamic username and home directory depending on the OS and available environment variables
if [[ -z "${USER}" ]]; then
    LOCAL_USERNAME=portaj
else
    LOCAL_USERNAME=${USER}
fi

if [[ -z "${HOME}" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        HOME_DIR=/Users/${LOCAL_USERNAME}
    else
        HOME_DIR=/home/${LOCAL_USERNAME}
    fi
else
    HOME_DIR=${HOME}
fi

GH_USERNAME=JonathanPorta
SSH_DIR=${HOME_DIR}/.ssh

echo "Setting up this machine using:"
echo "  Local Username: ${LOCAL_USERNAME}"
echo "  Github Username: ${GH_USERNAME}"
echo "  Home Directory: ${HOME_DIR}"
echo "  SSH Directory: ${SSH_DIR}"

echo "Ensure .ssh directory exists, is owned by $LOCAL_USERNAME, and has correct permissions"
mkdir -p ${SSH_DIR}
sudo chown -R ${LOCAL_USERNAME} ${SSH_DIR}
chmod 700 ${SSH_DIR}/

ls -lah ${SSH_DIR}
echo "Done."

if test -f "${SSH_DIR}/id_ed25519" && test -f "${SSH_DIR}/id_ed25519.pub"
then
    echo "${SSH_DIR}/id_ed25519 exists. Not regenerating."
else
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -f ${SSH_DIR}/id_ed25519 -q -N ""
    sudo chown ${LOCAL_USERNAME} ${SSH_DIR}/id_ed25519*
    echo "Done."
fi

echo "Ensuring jq is installed..."
if ! command -v jq >/dev/null 2>&1; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Ensure brew is discoverable in non-login shells
        if ! command -v brew >/dev/null 2>&1; then
            for _brew_dir in /opt/homebrew/bin /usr/local/bin; do
                if [[ -x "$_brew_dir/brew" ]]; then
                    export PATH="$_brew_dir:$PATH"
                    break
                fi
            done
        fi
        if command -v brew >/dev/null 2>&1; then
            brew install jq
        else
            echo "Error: Homebrew is not installed. Install it from https://brew.sh/ and re-run this script."
            exit 1
        fi
    else
        sudo dnf install -y jq
    fi
fi

echo "Ensure GitHub keys are synced to local authorized_keys..."
# we want to be able to run this and update the authorized keys with whatever we have on GH
curl https://api.github.com/users/${GH_USERNAME}/keys | jq -r '.[] | .key' > ${SSH_DIR}/authorized_keys
sudo chown ${LOCAL_USERNAME} ${SSH_DIR}/authorized_keys
echo "Updated '${SSH_DIR}/authorized_keys' to:"
cat ${SSH_DIR}/authorized_keys
echo "Truncated and wrote $(cat ${SSH_DIR}/authorized_keys | wc -l) keys to '${SSH_DIR}/authorized_keys'."
echo "Done."

echo "Ensure sshd is enabled and running..."
# Check if it's macOS or not, because it uses different commands to handle services
if [[ "$OSTYPE" == "darwin"* ]]; then
    sudo systemsetup -setremotelogin on
else
    sudo systemctl enable sshd
    sudo systemctl start sshd
    sudo systemctl status sshd
fi
echo "Done."

echo "Ensure .ssh files have the correct permissions..."
chmod 640 ${SSH_DIR}/authorized_keys
chmod 644 ${SSH_DIR}/*.pub
chmod 600 ${SSH_DIR}/id_ed25519

ls -lah ${SSH_DIR}
echo "Done."
