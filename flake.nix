{
  description = "edgedb-server";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };
  };

  outputs = inputs@{ flake-parts, nixpkgs, crane, fenix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      perSystem = { config, system, ... }:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          mk_edgedb_server = { source }:
            pkgs.stdenvNoCC.mkDerivation {
              name = "edgedb-server";
              buildInputs = with pkgs; [ ];
              nativeBuildInputs = with pkgs;
                [ zstd ]
                ++ lib.optionals (!pkgs.stdenv.isDarwin) [ autoPatchelfHook ];

              dontPatchELF = pkgs.stdenv.isDarwin;
              dontFixup = pkgs.stdenv.isDarwin;
              src = pkgs.fetchurl source;
              installPhase = ''
                mkdir $out
                cp -r ./* $out
              '';
            };

          mk_edgedb_cli = { source }:
            (let
              inherit (pkgs) lib;

              craneLib = crane.lib.${system};
            in craneLib.buildPackage {
              strictDeps = true;

              src = craneLib.cleanCargoSource (pkgs.fetchgit source);
              nativeBuildInputs = [ pkgs.pkg-config ];
              buildInputs = [ pkgs.openssl pkgs.perl ]
                ++ lib.optionals pkgs.stdenv.isDarwin [ pkgs.libiconv ];
              # we use native-tls/vendored, but here we override that so cargo does not try to build it
              # since it lacks a proper build env
              OPENSSL_NO_VENDOR = true;

              # don't check as we rely on GitHub Action tests for correctness
              # running clippy and tests here would require:
              # - starting edgedb-server,
              # - cloning shared-client-testcases git submodule, so shared-client-test
              #   crate can be generated
              doCheck = false;
            });
        in {
          packages.edgedb-server = mk_edgedb_server {
            source = {
              x86_64-linux = {
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu/edgedb-server-5.7+a084c4f.tar.zst";
                sha256 = "9ee607f75e042bba785e520f0125b0486b6d59161f26ae2689d4029f129df6e9";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu/edgedb-server-5.7+afc35ce.tar.zst";
                sha256 = "9a7936b498dcce1bcb77d0ca3c35166d8ffd2134e5756c3c7ecc2b7215485c11";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin/edgedb-server-5.7+2cade1b.tar.zst";
                sha256 = "2b452f66a2e5ebbad36e2c282905702db47f7d3df2fcbff8ae13061d1cee7aa5";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin/edgedb-server-5.7+05319d5.tar.zst";
                sha256 = "17f0616615ba1203c5faebfabf3d1127f887fe826f612d3eaf1aeca08582b2ce";
              };
            }.${system};
          };
          packages.edgedb-server-nightly = mk_edgedb_server {
            source = {
              x86_64-linux = {
                url = "https://packages.edgedb.com/archive/x86_64-unknown-linux-gnu.nightly/edgedb-server-7.0-dev.9185+889af10.tar.zst";
                sha256 = "0ece6a666c0eb34f4d0f47527cafe6580e667d31ad54198f787cb7b2eb83abd6";
              };
              aarch64-linux = {
                url = "https://packages.edgedb.com/archive/aarch64-unknown-linux-gnu.nightly/edgedb-server-7.0-dev.9185+5d20d6b.tar.zst";
                sha256 = "002d375421e4d43f42ed654c2f25547d7fcc7b7d6e52a7b305186771bc3e012a";
              };
              x86_64-darwin = {
                url = "https://packages.edgedb.com/archive/x86_64-apple-darwin.nightly/edgedb-server-7.0-dev.9191+b6b6aa2.tar.zst";
                sha256 = "b860e9e620f02607475ae384d40b16834527d14cc838a526ffb4da8ac6620186";
              };
              aarch64-darwin = {
                url = "https://packages.edgedb.com/archive/aarch64-apple-darwin.nightly/edgedb-server-7.0-dev.9191+85eff99.tar.zst";
                sha256 = "63af36e472ad2f53a751e8b7af53c9d10139e8bfb9512addc5df401641e72579";
              };
            }.${system};
          };

          packages.edgedb-cli = mk_edgedb_cli {
            source = {
              url = "https://github.com/edgedb/edgedb-cli";
              rev = "v5.1.0";
              hash = "sha256-znxAtfSeepLQqkPsEzQBp3INZym5BLap6m29C/9z+h8=";
            };
          };
        };
    };
}
