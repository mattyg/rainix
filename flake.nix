{
  description = "Rainix is a flake for Rain.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/ec750fd01963ab6b20ee1f0cb488754e8036d89d";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    foundry.url = "github:shazow/foundry.nix/main";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, rust-overlay, foundry, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays =[ (import rust-overlay) foundry.overlay ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };
        forge-bin = "${pkgs.foundry-bin}/bin/forge";
        slither-bin = "${pkgs.slither-analyzer}/bin/slither";
        rust-bin-pin = pkgs.rust-bin.stable."1.75.0".default;
        cargo-bin = "${rust-bin-pin}/bin/cargo";

        baseBuildInputs = [
          pkgs.rust-bin.stable."1.75.0".default
          pkgs.foundry-bin
          pkgs.slither-analyzer
        ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.darwin.apple_sdk.frameworks.SystemConfiguration
        ]);

        # https://ertt.ca/nix/shell-scripts/
        mkCITask = name: pkgs.symlinkJoin {
            name = name;
            paths = [
              ((pkgs.writeScriptBin name (builtins.readFile ./ci/${name}.sh)).overrideAttrs(old: {
                buildCommand = "${old.buildCommand}\n patchShebangs $out";
              }))
            ] ++ baseBuildInputs;
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
          };

      in {
        pkgs = pkgs;
        buildInputs = baseBuildInputs;

        packages = {
          ci-sol-test = mkCITask "ci-sol-test";
          ci-sol-artifacts = mkCITask "ci-sol-artifacts";
          ci-sol-static = mkCITask "ci-sol-static";

          ci-rs-test = mkCITask "ci-rs-test";
          ci-rs-artifacts = mkCITask "ci-rs-artifacts";
          ci-rs-static = mkCITask "ci-rs-static";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = baseBuildInputs;
        };
      }
    );
}