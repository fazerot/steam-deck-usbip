{
  description = "A flake for running steam-deck-usbip client";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      forAllSystems = function: nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: function (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          name = "steam-deck-usbip-client-shell";
          buildInputs = [
            pkgs.bash
            pkgs.linuxPackages.usbip
            pkgs.usbutils
            pkgs.kmod
          ];
          shellHook = ''
            echo "Entering shell for steam-deck-usbip client"
            echo "Run 'sudo -E ./client.sh <steam-deck-ip>'"
            echo "The -E flag is important to preserve the environment for sudo."
          '';
        };
      });
    };
}
