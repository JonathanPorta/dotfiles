
# We only want to run gpg-agent on our local workstation. We accomplish that by trying to
# detect if this shell was spawned from ssh or not. If the SSH_CLIENT env var is set, then
# this is probably a remote login and we don't want to run gpg-agent.

if [ ! -n "$SSH_CLIENT" ]; then
  gpgconf --launch gpg-agent

  if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
      export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  fi

  GPG_TTY=$(tty)
  export GPG_TTY
  # only necessary if using pinentry in the tty (instead of GUI)
  echo UPDATESTARTUPTTY | gpg-connect-agent > /dev/null 2>&1
fi



# We only want to run gpg-agent on our local workstation. We accomplish that by trying to
# detect if this shell was spawned from ssh or not. If the SSH_CLIENT env var is set, then
# this is probably a remote login and we don't want to run gpg-agent.

# if [ ! -n "$SSH_CLIENT" ]; then
#   gpgconf --launch gpg-agent
#
#   if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
#       export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
#   fi
#
#   GPG_TTY=$(tty)
#   export GPG_TTY
#   # only necessary if using pinentry in the tty (instead of GUI)
#   echo UPDATESTARTUPTTY | gpg-connect-agent > /dev/null 2>&1
# fi

# gpg-connect-agent /bye
