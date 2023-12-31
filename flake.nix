{
  description = "NixOS in MicroVMs";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.openhab.url = "gitlab:peterhoeg/openhab-flake";
  inputs.openhab.inputs.nixpkgs.follows = "nixpkgs";

  inputs.microvm.url = "github:astro/microvm.nix";
  inputs.microvm.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, microvm, openhab }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          openhab.overlays.default
        ];
      };

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

      nixosConfigurations.my-microvm = nixpkgs.lib.nixosSystem
        {
          inherit pkgs system;
          modules = [
            openhab.nixosModules.openhab
            {
              services.openhab = {
                enable = true;
                # configOnly = true;
                package = pkgs.openhab.openhab34;
              };
              system.stateVersion = "23.05";

            }
            microvm.nixosModules.microvm
            {

              networking.hostName = "my-microvm";
              users.users.root.password = "";
              microvm = {
                mem = 4096;
                volumes = [{
                  mountPoint = "/var";
                  image = "var.img";
                  size = 1024; # the default bindings take up a fair bit of space
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
        };
    };
}
