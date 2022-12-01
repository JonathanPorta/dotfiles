# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# include .zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
  . "$HOME/.zshrc"
fi


if [ -f "$HOME/dotfiles/.profile" ]; then
  . $HOME/dotfiles/.profile
fi
