# zmodload zsh/zprof
# https://unix.stackexchange.com/a/71258/103099
# https://stackoverflow.com/a/18187389

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.bin" ] ; then
    PATH="$HOME/.bin:$PATH"
fi


# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi


# set PATH so it includes user's helpers if it exists
if [ -d "$HOME/.helpers" ] ; then
    PATH="$HOME/.helpers:$PATH"
fi


# set PATH so it includes user's private .local/bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi


# source ~/.local/bin/env if present so tools can extend PATH without duplicating logic here
if [ -f "$HOME/.local/bin/env" ] ; then
    . "$HOME/.local/bin/env"
fi


# set PATH so it includes Antigravity if .antigravity/antigravity/bin exists
if [ -d "$HOME/.antigravity/antigravity/bin" ] ; then
    PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi


# set PATH so it includes Rust's cargo bin if it exists
if [ -f "$HOME/.cargo/env" ] ; then
    . "$HOME/.cargo/env"
fi


# set PATH so it includes Rancher's Desktop if .rd/bin exists
if [ -d "$HOME/.rd/bin" ] ; then
    PATH="$HOME/.rd/bin:$PATH"
fi


# go - "golang" when googling.
# export GOROOT=$HOME/go wtf, who set this? -- Leaving this as a reminder of what not to do.
# Go - set GOPATH and add go bin paths to PATH - if it exists.
if [ -d "$HOME/go" ] ; then
    export GOPATH=$HOME/go
    if [ -d "$GOPATH/bin" ] ; then
        PATH="$GOPATH/bin:$PATH"
    fi

    # Go - standard installation location
    if [ -d "/usr/local/go/bin" ] ; then
        PATH="/usr/local/go/bin:$PATH"
    fi
fi

# Kubernetes tools - check if .kube directory exists
if [ -d "$HOME/.kube" ] ; then
    PATH="$HOME/.kube:$PATH"
fi


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

# Export the final PATH with all modifications
export PATH
