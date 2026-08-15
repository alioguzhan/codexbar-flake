{
  description = "CodexBar CLI packaged from the upstream static musl release";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in rec {
          default = pkgs.callPackage ./codexbar-cli.nix { };
          codexbar-cli = default;
        });

      overlays.default = final: _prev: {
        codexbar-cli = final.callPackage ./codexbar-cli.nix { };
      };

      apps = forAllSystems (system: rec {
        default = codexbar;
        codexbar = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/codexbar";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          # Exactly what update.sh needs, so the workflow and a local run agree.
          default = pkgs.mkShell {
            packages = with pkgs; [ curl jq ];
          };
        });
    };
}
