# CineMaya (Lumen) release pin.
#
# This is the single file a release bumps. Procedure is documented in
# docs/infra/lumen-releases.md:
#   1. Cut a `lumen-vX.Y.Z` tag on System-Nebula/maya-unified main
#      (apps/lumen must be merged there first — see the runbook).
#   2. Set `version` and `rev` below, then re-derive the three hashes with
#      lib.fakeHash + nix build (never hand-write hashes).
#   3. Deploy with infra/lumen/deploy.sh.
{
  version = "0-unstable-2026-08-13";
  rev = "27cecccc3bb5242907875611587037cbca94d665";
  srcHash = "sha256-3WbpEpGsfpg7LhdWsY8BMwHD4kJzXVWi+z1nrQRAjoo=";
  webNpmDepsHash = "sha256-yuY8uD/EARRyWE0LBQFK2TaZWwP0NSewX3fm3Ky75aE=";
  labNpmDepsHash = "sha256-qvagkp7NAtmDQqJWXq6wuACrAprkO50+bDvGl10cn00=";
}
