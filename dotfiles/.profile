#!/usr/bin/env zsh

# Set OS variable for consistency with installation scripts
UNAME_OUTPUT=`uname`
if [[ "$UNAME_OUTPUT" == 'Linux' ]]; then
   export OS='linux'
elif [[ "$UNAME_OUTPUT" == 'Darwin' ]]; then
   export OS='darwin'
fi


# source homebrew shell environment if on macOS
if [[ "$OS" == "darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi


# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi


# GPG Agentry
if [ ! -n "$SSH_CLIENT" ]; then
  export GPG_TTY=$(tty)

  # Check if gpg-agent is running and start it if it isn't
  gpg-connect-agent /bye || gpg-agent --daemon --enable-ssh-support

  export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  gpg-connect-agent updatestartuptty /bye >/dev/null
fi


# uneff GPG Agent
alias gpg_reboot='gpgconf --kill gpg-agent; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; export SSH_AUTH_SOCK="$HOME/.gnupg/S.gpg-agent.ssh" ; gpgconf --launch gpg-agent; echo UPDATESTARTUPTTY | gpg-connect-agent'


# The following should be handled further down
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# The following are handled better further down. We don't really want shit in our Downloads folder, riiiiight?
# The next line updates PATH for the Google Cloud SDK.
# if [ -f '/Users/portaj/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/portaj/Downloads/google-cloud-sdk/path.zsh.inc'; fi
# The next line enables shell command completion for gcloud.
# if [ -f '/Users/portaj/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/portaj/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

# hub git alias
# eval "$(hub alias -s)"
# alias gpr='git push origin $(git rev-parse --abbrev-ref HEAD) && hub pull-request'


# gh cli replacements
alias woot='gh screensaver -s fireworks -- --message="w00t!"'
# alias gpr='git push origin $(git rev-parse --abbrev-ref HEAD) && gh pr create --web'
alias gpr='git push origin $(git rev-parse --abbrev-ref HEAD) && gh pr create --editor'


# git aliases
alias gs='git status'
alias gd='git diff'
alias ga='git add --all'
alias gc='git commit -v'
alias gp='git push origin'
alias gpf='git push origin --force-with-lease'


# curl aliases
alias c="curl -ivso /dev/null"
alias cl="curl -Livso /dev/null"
alias cb="curl -ivs"
alias cbl="curl -Livs"
alias cr="curl -ivso /dev/null --resolve"
alias cl="curl -Livso /dev/null --resolve"
alias cb="curl -ivs --resolve"
alias cbl="curl -Livs --resolve"


# curl: NOW WITH MORE TORBIT DEBUGGING
alias ctb="curl -ivso /dev/null -H 'x-tb-debug:1'"
alias cltb="curl -Livso /dev/null -H 'x-tb-debug:1'"
alias cbtb="curl -ivs -H 'x-tb-debug:1'"
alias cbltb="curl -Livs -H 'x-tb-debug:1'"
alias crtb="curl -ivso /dev/null --resolve -H 'x-tb-debug:1'"
alias cltb="curl -Livso /dev/null --resolve -H 'x-tb-debug:1'"
alias cbtb="curl -ivs --resolve -H 'x-tb-debug:1'"
alias cbltb="curl -Livs --resolve -H 'x-tb-debug:1'"


# kubectl setup
[[ $commands[kubectl] ]] && source <(kubectl completion zsh)
export KUBECONFIG="/home/portaj/.kube/gemini-config"
export PATH="$HOME/.kube:$PATH"
[[ $commands[istioctl] ]] && istioctl completion zsh > "${fpath[1]}/_istioctl"


# kubectl aliases
alias kp="kubectl --namespace=production"
alias ks="kubectl --namespace=sandbox"
alias kc="kubectl --namespace=compute"
alias k="kubectl --namespace=default"
alias ki="kubectl --namespace=istio-system"
alias kin="kubectl --namespace=istio-ingress"
alias kdc="kubectl --namespace=democratic-csi"
alias kmp="kubectl --namespace=mainline-production"


# googcloud
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then source "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then source "$HOME/google-cloud-sdk/completion.zsh.inc"; fi


#go - "golang" when googling.
#export GOROOT=$HOME/go wtf, who set this? -- Leaving this as a reminder of what not to do.
export GOPATH=$HOME/go
export PATH="$GOPATH/bin:$PATH:/usr/local/go/bin:$PATH"


# nvm (node.js crap)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


#node environment manager
export PATH="$HOME/.nenv/bin:$PATH"
eval "$(nenv init -)"


# nvmrc - autoloader thingery
autoload -U add-zsh-hook
load-nvmrc() {
  local node_version="$(nvm version)"
  local nvmrc_path="$(nvm_find_nvmrc)"

  if [ -n "$nvmrc_path" ]; then
    local nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [ "$nvmrc_node_version" = "N/A" ]; then
      nvm install > /dev/null 2>&1
    elif [ "$nvmrc_node_version" != "$node_version" ]; then
      nvm use > /dev/null 2>&1
    fi
  elif [ "$node_version" != "$(nvm version default)" ]; then
    # echo "Reverting to nvm default version"
    nvm use default > /dev/null 2>&1
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc


# Ruby Shite
source $HOME/.chruby
alias plz='foreman run bundle exec'


# Docker poo
alias destroy_the_child='df -h ; docker system df ; docker rm $(docker ps -a -q) ; docker rmi -f $(docker images -q) ; docker volume ls -qf dangling=true | xargs docker volume rm ; docker system prune -af ; docker system prune -af --volumes ; docker system df ; df -h'


# Eff this shit. It hijacks curl by placing a curl binary in it's bin dir. What is this garbage?
# anaconda (python residue)
#export PATH="$HOME/anaconda3/bin:$HOME/.local/bin:$PATH"
#source $HOME/anaconda3/etc/profile.d/conda.sh


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


# kafka "cli"
# export PATH="/opt/kafka_2.13-3.1.0/bin:$PATH"

export AWS_PROFILE=portaj


# family cookie recipes
source $HOME/dotfiles/.secrets


# helpers
source $HOME/dotfiles/util.sh


# Git Config
source $HOME/dotfiles/generate_gitconfig.sh
