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
      inputs.self.modules.nixos.argus
      inputs.self.modules.nixos.argusHardware
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
      inputs.self.modules.nixos.tl0m2
      inputs.self.modules.nixos.tl0m2Hardware
      inputs.self.modules.nixos.tl0m2Postgres
      inputs.self.modules.nixos.tl0m2Seaweedfs
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
      inputs.self.modules.nixos.qmom2
      inputs.self.modules.nixos.qmom2Hardware
      inputs.self.modules.nixos.qmom2Postgres
      inputs.self.modules.nixos.qmom2Seaweedfs
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
      inputs.self.modules.nixos.lacie
      inputs.self.modules.nixos.lacieHardware
      inputs.self.modules.nixos.imaging
      inputs.self.modules.nixos.wifiProfiles
      inputs.self.modules.nixos.greeter
      inputs.self.modules.nixos.themeData
      inputs.self.modules.nixos.desktops
      inputs.self.modules.nixos.emulators
      inputs.self.modules.nixos.pentest
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
      inputs.self.modules.nixos.kaliVm
      inputs.self.modules.nixos.kaliVmHardware
      inputs.self.modules.nixos.themeData
      inputs.self.modules.nixos.desktops
    ];
    users.kali.homeModules = [ homeNix ];
    extraSpecialArgs.gpuType = "none";
  };
}
