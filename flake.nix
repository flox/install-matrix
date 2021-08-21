{
  description = "Test matrix for various OS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {
    packages.x86_64-linux.matrix = pkgs.callPackage ./matrix.nix {};
    defaultPackage.x86_64-linux = self.packages.x86_64-linux.matrix;
  };
}
