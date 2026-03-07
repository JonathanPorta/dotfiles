#!/usr/bin/env zsh

# Set OS variable for consistency with installation scripts
UNAME_OUTPUT=`uname`
if [[ "$UNAME_OUTPUT" == 'Linux' ]]; then
   export OS='linux'
elif [[ "$UNAME_OUTPUT" == 'Darwin' ]]; then
   export OS='darwin'
fi


# homebrew shell environment moved to .zprofile (runs once on login, not every shell)


# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi


# GPG Agentry
if [ -z "$SSH_CLIENT" ] && command -v gpgconf >/dev/null 2>&1; then
  export GPG_TTY=$(tty)

  # Check if gpg-agent is running and start it if it isn't
  gpg-connect-agent /bye || gpg-agent --daemon --enable-ssh-support

  export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  gpg-connect-agent updatestartuptty /bye >/dev/null
fi


# uneff GPG Agent
alias gpg_reboot='gpgconf --kill gpg-agent; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; killall gpg-agent ; export SSH_AUTH_SOCK="$HOME/.gnupg/S.gpg-agent.ssh" ; gpgconf --launch gpg-agent; echo UPDATESTARTUPTTY | gpg-connect-agent'


# hub git alias
# eval "$(hub alias -s)"
# alias gpr='git push origin $(git rev-parse --abbrev-ref HEAD) && hub pull-request'


# gh cli replacements
alias woot='gh screensaver -s fireworks -- --message="w00t!"'
alias gpr='git push origin -- "$(git rev-parse --abbrev-ref HEAD)" && gh pr create --editor'
alias gprw='git push origin -- "$(git rev-parse --abbrev-ref HEAD)" && gh pr create --web'


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


# kubectl setup - completion cached to file for fast startup
if [[ $commands[kubectl] ]]; then
  _kubectl_comp="$HOME/.zsh_kubectl_completion"
  if [[ ! -f "$_kubectl_comp" || "$_kubectl_comp" -ot "$(command -v kubectl)" ]]; then
    kubectl completion zsh > "$_kubectl_comp"
  fi
  source "$_kubectl_comp"
  unset _kubectl_comp
fi
export KUBECONFIG="/home/portaj/.kube/gemini-config"
export PATH="$HOME/.kube:$PATH"
if [[ $commands[istioctl] ]]; then
  _istioctl_comp="$HOME/.zsh_istioctl_completion"
  if [[ ! -f "$_istioctl_comp" || "$_istioctl_comp" -ot "$(command -v istioctl)" ]]; then
    istioctl completion zsh > "$_istioctl_comp"
  fi
  source "$_istioctl_comp"
  unset _istioctl_comp
fi


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


# nvm (node.js crap) - lazy loaded for fast shell startup
export NVM_DIR="$HOME/.nvm"

_nvm_lazy_load() {
  unset -f nvm node npm npx yarn pnpm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

nvm() { _nvm_lazy_load; nvm "$@"; }
node() { _nvm_lazy_load; node "$@"; }
npm() { _nvm_lazy_load; npm "$@"; }
npx() { _nvm_lazy_load; npx "$@"; }
yarn() { _nvm_lazy_load; yarn "$@"; }
pnpm() { _nvm_lazy_load; pnpm "$@"; }


# Ruby Shite
[[ -f "$HOME/.chruby" ]] && source "$HOME/.chruby"
alias plz='foreman run bundle exec'


# Docker poo
alias destroy_the_child='df -h ; docker system df ; docker rm $(docker ps -a -q) ; docker rmi -f $(docker images -q) ; docker volume ls -qf dangling=true | xargs docker volume rm ; docker system prune -af ; docker system prune -af --volumes ; docker system df ; df -h'

# Rancher Desktop (Replacement for Docker Desktop)
export PATH="$HOME/.rd/bin:~/.rd/bin:$PATH"


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

# openjdk nonsense
# export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"

# kafka "cli"
# export PATH="/opt/kafka_2.13-3.1.0/bin:$PATH"

# family cookie recipes
source $HOME/dotfiles/.secrets

# helpers
source $HOME/dotfiles/util.sh


# Git Config
source $HOME/dotfiles/generate_gitconfig.sh
