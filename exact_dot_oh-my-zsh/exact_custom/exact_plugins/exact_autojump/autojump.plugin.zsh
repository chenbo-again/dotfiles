path=("${0:A:h}/bin" $path)
fpath=("${0:A:h}/bin" $fpath)
autoload -Uz _j
compdef _j j
source "${0:A:h}/bin/autojump.zsh"
