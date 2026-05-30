# E2E Tests (Docker)

These tests run `why` inside distro containers to exercise real package-manager lookups.

## Run

```bash
./tests/e2e/run.sh
```

Run a subset:

```bash
./tests/e2e/run.sh ubuntu alpine
```

## Coverage

- ubuntu: apt/dpkg + path-based providers (asdf/SDKMAN!/nvm/fnm/pyenv/rbenv/rvm/rustup/conda/mise/volta/macports/nix)
- fedora: yum/rpm
- opensuse: zypper/rpm
- alpine: apk
- arch: pacman
- gentoo: portage (qfile)

## Notes

- The `why` binary is built once via `tests/e2e/Builder.Dockerfile` and copied into each distro image.
- Alpine uses a glibc compatibility layer (`gcompat`/`libc6-compat`) to run the glibc-based builder binary.
- Gentoo coverage is provided via a stage3 image with portage-utils (qfile).
- Windows-only providers (Scoop/Chocolatey/winget) are covered by unit tests.
