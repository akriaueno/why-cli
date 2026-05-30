{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "why-cli";
  version = (builtins.fromTOML (builtins.readFile ../Cargo.toml)).package.version;

  src = lib.cleanSource ../.;
  cargoLock.lockFile = ../Cargo.lock;

  meta = {
    description = "Tells you why a command is installed on your system";
    homepage = "https://github.com/akriaueno/why-cli";
    license = lib.licenses.mit;
    mainProgram = "why";
    platforms = lib.platforms.unix;
  };
}
