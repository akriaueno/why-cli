{
  lib,
  buildNimPackage,
}:

buildNimPackage {
  pname = "why-cli";
  version = "0.1.0";

  src = lib.cleanSource ../.;
  lockFile = ./nim-lock.json;

  meta = {
    description = "Tells you why a command is installed on your system";
    homepage = "https://github.com/akriaueno/why-cli";
    license = lib.licenses.mit;
    mainProgram = "why";
    platforms = lib.platforms.unix;
  };
}
