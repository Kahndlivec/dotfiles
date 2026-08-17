
# history QoL
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY
HISTSIZE=50000; SAVEHIST=50000

bindkey -e

source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
eval "$(starship init zsh)"

# compile + run one file against input.txt in the same folder
cprun() {
  g++ -std=c++17 -O2 -Wall -Wextra -DLOCAL "$1" -o /tmp/sol \
    && /tmp/sol < "${2:-input.txt}"
}

# compile with every safety net on — use when you get a wrong answer
cpdbg() {
  g++ -std=c++17 -g -Wall -Wextra -DLOCAL \
    -fsanitize=address,undefined -D_GLIBCXX_DEBUG \
    "$1" -o /tmp/sol && /tmp/sol < "${2:-input.txt}"
}

# stage, commit, push in one shot
cpush() { git add -A && git commit -m "$1" && git push; }

alias wake-khandlab='wakeonlan b4:2e:99:88:8e:d8'
alias wake-khandlab='wakeonlan b4:2e:99:88:8e:d8'
