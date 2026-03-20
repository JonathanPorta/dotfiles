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

# set PATH so it includes user's private .local/bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# set PATH so it includes user's private .local/bin/env if it exists
if [ -d "$HOME/.local/bin/env" ] ; then
    PATH="$HOME/.local/bin/env:$PATH"
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
