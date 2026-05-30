function __why_needs_command
    set -l tokens (commandline -opc)

    for token in $tokens
        switch $token
            case --completion --help --version
                return 1
        end
    end

    test (count $tokens) -eq 1
end

complete -c why -f
complete -c why -l completion -x -a "bash zsh fish" -d "Print a shell completion script"
complete -c why -l help -d "Show help"
complete -c why -l version -d "Show version"
complete -c why -n "__why_needs_command" -a "(__fish_complete_command)" -d "Command"
