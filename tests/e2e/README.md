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

## Notes

- Alpine uses a glibc compatibility layer (`gcompat`/`libc6-compat`) to run the binary built in the builder stage.
- Portage (Gentoo) is not covered here due to container limitations; it remains covered by unit tests.
- Windows-only providers (Scoop/Chocolatey/winget) are covered by unit tests.
