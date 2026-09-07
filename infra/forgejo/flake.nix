{
  description = "Forgejo deployment tooling for stage-db";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let systems = [ "x86_64-linux" "aarch64-linux" ]; in
    { devShells = builtins.listToAttrs (map (system: {
        name = system;
        value.default = let pkgs = import nixpkgs { inherit system; }; in pkgs.mkShell {
          packages = with pkgs; [ opentofu docker-compose openssl jq postgresql_16 ];
        };
      }) systems); };
}
