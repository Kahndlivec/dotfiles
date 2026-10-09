# ~/.zprofile  →  symlink to dotfiles/zsh/.zprofile
#
# Read by zsh LOGIN shells — including the one GNOME starts your whole desktop
# session through. Ubuntu normally puts ~/.local/bin on PATH from ~/.profile,
# but zsh never reads ~/.profile, so without this file apps launched from
# GNOME (VS Code → nvim, Sublime Text → clangd) can't find anything in there.
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.npm-global/bin"
  $path
)
export PATH
