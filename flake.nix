{
  description = "NixOS in MicroVMs";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/master";
  inputs.openhab.url = "gitlab:peterhoeg/openhab-flake";
  inputs.openhab.inputs.nixpkgs.follows = "nixpkgs";

  inputs.microvm.url = "github:astro/microvm.nix";
  inputs.microvm.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, microvm, openhab }:
    let
      system = "x86_64-linux";
    in
    {
      defaultPackage.${system} = self.packages.${system}.my-microvm;

      packages.${system}.my-microvm =
        let
          inherit (self.nixosConfigurations.my-microvm) config;
          # quickly build with another hypervisor if this MicroVM is built as a package
          hypervisor = "qemu";
        in
        config.microvm.runner.${hypervisor};

      nixosConfigurations.my-microvm = nixpkgs.lib.nixosSystem (
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              openhab.overlays.default
            ];
          };

        in
        {
          inherit system;
          modules = [
            openhab.nixosModules.openhab
            {
              services.openhab = {
                enable = true;
                configOnly = true;
                package = pkgs.openhab.openhab34;
              };
              system.stateVersion = "23.05";

            }
            microvm.nixosModules.microvm
            {

              networking.hostName = "my-microvm";
              users.users.root.password = "";
              microvm = {
                volumes = [{
                  mountPoint = "/var";
                  image = "var.img";
                  size = 256;
                }];
                shares = [{
                  # use "virtiofs" for MicroVMs that are started by systemd
                  proto = "9p";
                  tag = "ro-store";
                  # a host's /nix/store will be picked up so that the
                  # size of the /dev/vda can be reduced.
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                }];
                socket = "control.socket";
                # relevant for delarative MicroVM management
                hypervisor = "qemu";
              };
            }
          ];
        }
      );
    };
}
