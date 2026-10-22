{
  description = "Lolka for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Upstream ships Linux x86_64 packages only.
      systems = [ "x86_64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      packages = forAll (pkgs: {
        default = pkgs.callPackage ./package.nix { };
      });

      overlays.default = final: prev: {
        lolka = final.callPackage ./package.nix { };
      };
    };
}
