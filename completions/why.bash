_why() {
    local cur prev
    COMPREPLY=()

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ "$prev" == "--completion" ]]; then
        COMPREPLY=($(compgen -W "bash zsh fish" -- "$cur"))
        return 0
    fi

    if [[ "$cur" == --* ]]; then
        COMPREPLY=($(compgen -W "--completion --help --version" -- "$cur"))
        return 0
    fi

    if (( COMP_CWORD == 1 )); then
        COMPREPLY=($(compgen -c -- "$cur"))
        return 0
    fi
}

complete -F _why why
