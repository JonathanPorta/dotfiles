#!/bin/zsh

# Update PATH for my homiedir bin
export PATH="$HOME/bin:$PATH"


# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi


# GPG Agentry
if [ ! -n "$SSH_CLIENT" ]; then
  gpgconf --launch gpg-agent
  GPG_TTY=$(tty); export GPG_TTY;
  unset SSH_AGENT_PID
  if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  fi
  # only necessary if using pinentry in the tty (instead of GUI)
  echo UPDATESTARTUPTTY | gpg-connect-agent > /dev/null 2>&1
fi

# uneff GPG Agent
alias gpg_reboot='killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; export SSH_AUTH_SOCK="$HOME/.gnupg/S.gpg-agent.ssh" ; gpgconf --launch gpg-agent'


# hub git alias
eval "$(hub alias -s)"
alias gpr='git push origin $(git rev-parse --abbrev-ref HEAD) && hub pull-request'
alias gs='git status'
alias gd='git diff'
alias ga='git add --all'
alias gpo='git push origin'


# kube aliases
alias pk="kubectl --namespace=production"
alias sk="kubectl --namespace=sandbox"  #--context gke_pantheon-dev_us-central1-b_sandbox-01


# googcloud
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then source "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then source "$HOME/google-cloud-sdk/completion.zsh.inc"; fi


#go - "golang" when googling.
#export GOROOT=$HOME/go wtf, who set this? -- Leaving this as a reminder of what not to do.
export GOPATH=$HOME/go
export PATH="$GOPATH/bin:$PATH"


# nvm (node.js crap)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

#node environment manager
export PATH="$HOME/.nenv/bin:$PATH"
eval "$(nenv init -)"



# Ruby Shite
source $HOME/.chruby
alias plz='foreman run bundle exec'


# Docker poo
alias destroy_the_child='docker rm $(docker ps -a -q) ; docker rmi $(docker images -q)'


# anaconda (python residue)
export PATH="$HOME/anaconda3/bin:$HOME/.local/bin:$PATH"
source $HOME/anaconda3/etc/profile.d/conda.sh

#TODO: Uncomment as needed
## special bullshitters
# Chromium build tools
#export PATH="$HOME/devel/depot_tools:$PATH"

#TODO: Handle for multiple OS'
# nvidia cuda libs
#export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/extras/CUPTI/lib64

#TODO: Handle for multiple OS'
# imagemagick binary
#export PATH="/usr/local/opt/imagemagick@6/bin:$PATH"


#TODO: Handle for multiple OS'
# Android Studio Crap + Other Mobile Dev
#export PATH="/opt/google/android-studio/bin:$PATH"
#export PATH="/Users/portaj/Library/Android/sdk/platform-tools:$PATH" # Mac OS
#export PATH="$HOME/Android/Sdk/platform-tools:$PATH" # Linux
#export PATH="$HOME/.fastlane/bin:/Users/portaj/Library/Android/sdk/ndk-bundle:$PATH"


# family cookie recipes
source $HOME/dotfiles/.secrets
