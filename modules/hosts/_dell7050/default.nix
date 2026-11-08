{
  configuration = import ./configuration.nix;
  postgres = import ./postgres.nix;
  seaweedfs = import ./seaweedfs.nix;
}
