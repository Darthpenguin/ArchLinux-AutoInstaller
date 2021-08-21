#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ $DISPLAY ]] && shopt -s checkwinsize

if [ $(id -u) -eq 0 ];
then # you are root, make the prompt red
    PS1="\[\e[01;31m\]\u \[\e[0;37m\]\W\[\e[0;37m\]# \[\e[0m\]"
else
    PS1="\[\e[01;32m\]\u \[\e[0;37m\]\W\[\e[0;37m\]# \[\e[0m\]"
fi

alias ls='ls --color=auto'
alias diff='diff --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'
export LS_COLORS=$LS_COLORS:'di=0;35:' ; export LS_COLORS
export LESS='-R --use-color -Dd+r$Du+b'
export MANPAGER="less -R --use-color -Dd+r -Du+b"

case ${TERM} in
  xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'

    ;;
  screen*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
esac

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

if [ -e $HOME/.bash_aliases ]; then
    source $HOME/.bash_aliases
fi
