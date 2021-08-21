{
  description = "";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable#";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in
  {

    packages.x86_64-linux.script = pkgs.callPackage ./default.nix {inherit pkgs;};

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.script;

  };
}
