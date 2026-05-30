{
  bash,
  homePath,
  runCommand,
}:

runCommand "why-home-manager-completions-e2e"
  {
    nativeBuildInputs = [
      bash
      homePath
    ];
  }
  ''
    set -eu

    test -x "${homePath}/bin/why"
    test -x "${homePath}/bin/zsh"
    test -x "${homePath}/bin/fish"

    test -f "${homePath}/share/bash-completion/completions/why.bash"
    test -f "${homePath}/share/zsh/site-functions/_why"
    test -f "${homePath}/share/fish/vendor_completions.d/why.fish"

    "${homePath}/bin/why" --version | grep -E '^why [0-9]+\.[0-9]+\.[0-9]+'

    BASH_COMPLETION_FILE="${homePath}/share/bash-completion/completions/why.bash" \
      PATH="${homePath}/bin:$PATH" \
      bash --noprofile --norc > "$TMPDIR/bash.out" <<'BASH'
    set -euo pipefail
    source "$BASH_COMPLETION_FILE"
    COMP_WORDS=(why l)
    COMP_CWORD=1
    _why
    printf '%s\n' "''${COMPREPLY[@]}"
BASH
    grep -Fx "ls" "$TMPDIR/bash.out"

    ZSH_COMPLETION_DIR="${homePath}/share/zsh/site-functions" \
      PATH="${homePath}/bin:$PATH" \
      zsh -f > "$TMPDIR/zsh.out" <<'ZSH'
    set -e
    fpath=("$ZSH_COMPLETION_DIR" $fpath)
    autoload -Uz compinit
    compinit -D
    test "$_comps[why]" = "_why"
    autoload -Uz _why
    autoload +X _why
    functions _why
ZSH
    grep -F "_path_commands" "$TMPDIR/zsh.out"

    FISH_COMPLETION_FILE="${homePath}/share/fish/vendor_completions.d/why.fish" \
      PATH="${homePath}/bin:$PATH" \
      fish --no-config > "$TMPDIR/fish.out" <<'FISH'
    source "$FISH_COMPLETION_FILE"
    complete -C "why l"
FISH
    cut -f1 "$TMPDIR/fish.out" | grep -Fx "ls"

    touch "$out"
  ''
