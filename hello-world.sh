#!/bin/bash
set -e


GH_USERNAME='JonathanPorta'

echo "Ensure GitHub keys are synced to local authorized_keys..."
# we want to be able to run this and update the authorized keys with whatever we have on GH
curl https://api.github.com/users/${GH_USERNAME}/keys | jq -r '.[] | .key' > $HOME/.ssh/authorized_keys
echo "Updated '$HOME/.ssh/authorized_keys' to:"
cat $HOME/.ssh/authorized_keys
echo "Truncated and wrote $(cat $HOME/.ssh/authorized_keys | wc -l) keys to '$HOME/.ssh/authorized_keys'."
echo "Done."

echo "Ensure sshd is enabled and running..."
sudo systemctl enable sshd
sudo systemctl start sshd
sudo systemctl status sshd
echo "Done."
