# Why are you in my computer? 

**"Why is this command here? Who installed it?"**

`why` is a CLI tool that identifies the installation source (provider) of a command.
It resolves symlinks, checks path patterns, and queries system package managers to tell you if a command is managed by Homebrew, apt, npm, Mise, Flatpak, asdf, SDKMAN!, or simply a system file.

## Features

- Provider Identification: Instantly detects if a binary is from Homebrew, apt/dpkg, yum/rpm, zypper/rpm, apk, pacman, Nix, MacPorts, npm, pip, Cargo, Go, etc.
- Symlink Resolution: Traces the "Origin Path" (where your shell finds it) to the "Real Path" (where the binary actually lives).
- System Package Manager Integration: Automatically queries `dpkg`, `rpm`/`zypper`, `apk`, `pacman`, or Portage tools for system files to identify the package name.

## Installation

### Home Manager (Nix)

Add this repository as a flake input:

```nix
{
  inputs.why-cli = {
    url = "github:akriaueno/why-cli";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then install it with `home.packages`:

```nix
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.why-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

If your Home Manager modules do not already receive `inputs`, pass them from
`homeManagerConfiguration` with `extraSpecialArgs = { inherit inputs; };`.

Or import the included Home Manager module:

```nix
{ inputs, ... }:

{
  imports = [
    inputs.why-cli.homeManagerModules.default
  ];

  programs.why.enable = true;
}
```

### Homebrew (macOS & Linux) - Recommended

You can easily install `why` using Homebrew.
This method builds the binary from source on your machine, avoiding macOS Gatekeeper warnings.

```bash
brew install akriaueno/tap/why
```

Or, if you prefer to tap the repository first:

```bash
brew tap akriaueno/tap
brew install why
```

## Usage

Simply run `why` followed by the command name.

```bash
why <command_name>
```

## Examples

### 1. Version Managers (e.g., Mise, Volta)
It clearly shows which version manager is controlling the command.

```bash
$ why node
Command:     node
Provider:    Homebrew
Origin Path: /home/linuxbrew/.linuxbrew/bin/node
Real Path:   /home/linuxbrew/.linuxbrew/Cellar/node/25.2.1/bin/node
```

### 2. System Packages (apt/dpkg)
It queries `dpkg` to find the package name.

```bash
 $ why docker
Command:     docker
Provider:    apt/dpkg (docker-ce-cli)
Origin Path: /usr/bin/docker
Real Path:   /usr/bin/docker
```

### 3. Flatpak (Smart Fallback)
Even if the command name (e.g., `steam`) differs from the Flatpak ID, `why` can find it.

```bash
$ why steam
Hint: command 'steam' was not found in PATH, but found 'com.valvesoftware.Steam' in Flatpak.
Command:     steam
Provider:    Flatpak
Origin Path: /var/lib/flatpak/exports/bin/com.valvesoftware.Steam
Real Path:   /var/lib/flatpak/app/com.valvesoftware.Steam/current/active/export/bin/com.valvesoftware.Steam
```

## Supported Providers

`why` currently supports detection for:

- Package Managers: Homebrew, apt (Debian/Ubuntu), yum/rpm (RHEL/CentOS), zypper/rpm (SUSE), apk (Alpine), pacman (Arch), Portage (Gentoo), MacPorts, Nix, Snap, Flatpak, Scoop, Chocolatey, winget
- Version Managers: Mise, Volta, asdf, SDKMAN!, nvm, fnm, pyenv, rbenv, rvm, Rustup, Conda
- Language Managers: npm (Global), pip/pipx (Python), Cargo (Rust), Go
- System: Standard system paths (`/usr/bin`, etc.)

## Developer

### Build from Source

Requirements: [Rust](https://www.rust-lang.org/) toolchain (`cargo` and `rustc`).

```bash
git clone [https://github.com/akriaueno/why-cli.git](https://github.com/akriaueno/why-cli.git)
cd why-cli
cargo build --release
# The binary is created as './target/release/why'
# Add it to your PATH (e.g., cp target/release/why /usr/local/bin/)
```

If you change dependencies, run `cargo update` or `cargo generate-lockfile` to update `Cargo.lock`.

### Testing

```bash
cargo test
```

## License

MIT License.
