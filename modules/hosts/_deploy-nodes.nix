{ inputs, ... }:
let
  inherit (inputs) self;
  serverHome = "${self}/modules/profiles/_server-home.nix";
  homeNix = "${self}/modules/_home.nix";
in
{
  argus = {
    tags = [
      "headless"
      "gpu"
    ];
    desktop = false;
    modules = [
      inputs.self.nixosModules.argus
      inputs.self.nixosModules.argusHardware
    ];
    users.warby.homeModules = [ serverHome ];
  };

  "94tl0m2" = {
    tags = [
      "7050"
      "staging"
    ];
    desktop = false;
    modules = [
      inputs.self.nixosModules.tl0m2
      inputs.self.nixosModules.tl0m2Hardware
      inputs.self.nixosModules.tl0m2Postgres
      inputs.self.nixosModules.tl0m2Seaweedfs
    ];
    users.warby.homeModules = [ serverHome ];
  };

  "95qmom2" = {
    targetHost = "192.168.0.49";
    tags = [
      "7050"
      "storage"
      "data-core"
      "postgres"
      "seaweedfs"
    ];
    desktop = false;
    modules = [
      inputs.self.nixosModules.qmom2
      inputs.self.nixosModules.qmom2Hardware
      inputs.self.nixosModules.qmom2Postgres
      inputs.self.nixosModules.qmom2Seaweedfs
    ];
    users.warby.homeModules = [ serverHome ];
  };

  lacie = {
    tags = [
      "laptop"
      "imaging"
    ];
    desktop = true;
    modules = [
      inputs.self.nixosModules.lacie
      inputs.self.nixosModules.lacieHardware
      inputs.self.nixosModules.imaging
      inputs.self.nixosModules.wifiProfiles
      inputs.self.nixosModules.greeter
      inputs.self.nixosModules.themeData
      inputs.self.nixosModules.desktops
      inputs.self.nixosModules.emulators
      inputs.self.nixosModules.pentest
    ];
    users.warby = {
      homeModules = [ homeNix ];
      ageIdentity = "/home/warby/.ssh/age";
    };
    extraSpecialArgs.gpuType = "none";
  };

  kali-vm = {
    tags = [
      "vm"
      "kali"
    ];
    desktop = true;
    modules = [
      inputs.self.nixosModules.kaliVm
      inputs.self.nixosModules.kaliVmHardware
      inputs.self.nixosModules.themeData
      inputs.self.nixosModules.desktops
    ];
    users.kali.homeModules = [ homeNix ];
    extraSpecialArgs.gpuType = "none";
  };
}
