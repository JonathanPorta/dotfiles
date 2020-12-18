# Random Snippets and Notes

Dropping various configs here as I work to consolidate.

# Backup Gnome/Gnome Shell Settings

`dconf dump / > \$(hostname)-gnome-dconf-dump`




DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo $DIR



# exists curl  || { echo "I require curl but it's not installed.  Aborting." >&2; exit 1; }
# exists jq1 || { echo "I require jq but it's not installed.  Aborting." >&2; exit 1; }

# TODO: Figure out a reliable way to find this path without so much hardcoding.
# source $HOME/devel/portaj/dotfiles/installation/include/vars.sh
# source "$(dirname \"$0\")/include/vars.sh"


# TODO: enable debug output with an arg, for now, uncomment the following:
# echo_cyan "INCLUDE_DIR=$INCLUDE_DIR"
# echo_cyan "INSTALLATION_SOURCE_DIR=$INSTALLATION_SOURCE_DIR"
# echo_cyan "DEVEL_DIR=$DEVEL_DIR"
# echo_cyan "DOTFILES_CHECKOUT=$DOTFILES_CHECKOUT"
# echo_cyan "NOW=$NOW"
# echo_cyan "OS=$OS"
# echo_cyan "PKG_INSTALLER=$PKG_INSTALLER"
