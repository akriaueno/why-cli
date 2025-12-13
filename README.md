# Why are you in my computer? 

**"Why is this command here? Who installed it?"**

`why` is a CLI tool that identifies the installation source (provider) of a command.
It resolves symlinks, checks path patterns, and queries system package managers to tell you if a command is managed by Homebrew, apt, npm, Mise, Flatpak, or simply a system file.

## Features

- Provider Identification: Instantly detects if a binary is from Homebrew, apt/dpkg, yum/rpm, npm, pip, Cargo, Go, etc.
- Symlink Resolution: Traces the "Origin Path" (where your shell finds it) to the "Real Path" (where the binary actually lives).
- System Package Manager Integration: Automatically queries `dpkg` or `rpm` for system files to identify the package name.

## Installation

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

### Build from Source

Requirements: [Nim](https://nim-lang.org/) compiler (`nim` and `nimble`).

```bash
git clone [https://github.com/akriaueno/why-cli.git](https://github.com/akriaueno/why-cli.git)
cd why-cli
nimble build -d:release
# The binary is created as './why'
# Add it to your PATH (e.g., cp why /usr/local/bin/)
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
Hint: Command 'steam' not found in PATH, but found 'com.valvesoftware.Steam' in Flatpak.
Command:     steam
Provider:    Flatpak
Origin Path: /var/lib/flatpak/exports/bin/com.valvesoftware.Steam
Real Path:   /var/lib/flatpak/app/com.valvesoftware.Steam/current/active/export/bin/com.valvesoftware.Steam
```

## Supported Providers

`why` currently supports detection for:

- Package Managers: Homebrew, apt (Debian/Ubuntu), yum/rpm (RHEL/CentOS), Snap, Flatpak
- Version Managers: Mise, Volta
- Language Managers: npm (Global), pip/pipx (Python), Cargo (Rust), Go
- System: Standard system paths (`/usr/bin`, etc.)

## License

MIT License.
