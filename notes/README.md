# Random Snippets and Notes

Dropping various configs here as I work to consolidate.

# Fedora/Linux

## Backup Gnome/Gnome Shell Settings

`dconf dump / > \$(hostname)-gnome-dconf-dump`

## Enable inotify settings by default

```
# Put the following in /etc/sysctl.d/90-override.conf
fs.inotify.max_user_watches=100000
fs.inotify.max_user_instances=1024
```

# Random Notes

## Find script's dir

```
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo $DIR
```
