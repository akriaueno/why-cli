{
  description = "why - identify why a command is installed on your system";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        why-cli = pkgs.callPackage ./nix/package.nix { };
      in
      {
        packages = {
          default = why-cli;
          inherit why-cli;
        };

        apps.default = {
          type = "app";
          program = "${why-cli}/bin/why";
          meta.description = "Run why";
        };
      }
    )
    // {

      overlays.default = final: _prev: {
        why-cli = final.callPackage ./nix/package.nix { };
      };

      homeManagerModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.why;
        in
        {
          options.programs.why = {
            enable = lib.mkEnableOption "why, a CLI for identifying command installation sources";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              defaultText = lib.literalExpression "inputs.why-cli.packages.\${pkgs.stdenv.hostPlatform.system}.default";
              description = "The why package to install.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
          };
        };
    };
}
