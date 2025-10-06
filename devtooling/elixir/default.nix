# ============================================================================
# Elixir Development Tooling Module
# ============================================================================
#
# This module provides comprehensive Elixir development tools including:
# - Elixir: Functional programming language
# - Erlang: BEAM virtual machine and runtime
# - Livebook: Interactive Elixir notebooks (see modules/dev.nix for container)
# - Rebar3: Erlang build tool and package manager
#
# ELIXIR ECOSYSTEM FEATURES:
# ==========================
# - Phoenix Framework: Web framework (installed via mix archive)
# - Livebook: Interactive notebooks for Elixir (containerized)
# - Mix: Build tool and dependency manager
# - Hex: Package repository
# - IEx: Interactive shell
#
# CONTAINER INTEGRATION:
# ======================
# Livebook runs in a separate container (see modules/dev.nix) with:
# - Port: 8081
# - Password: devsandbox123
# - Data directory: ~/Workspace/Kino (persistent notebooks)
#
# DEVELOPMENT WORKFLOW:
# =====================
# 1. Local development: Use system Elixir/Mix for coding
# 2. Interactive exploration: Use Livebook for notebooks
# 3. Phoenix apps: mix phx.new my_app
# 4. Dependencies: mix deps.get
# 5. Testing: mix test
#
# OPTIMIZATION NOTES:
# ===================
# - Livebook container uses custom minimal image (when enabled)
# - Removes documentation/examples to reduce footprint
# - Maintains full functionality for development
# ============================================================================

{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
{
  options = {
    elixir.enable = lib.mkEnableOption "Enable elixir module";
  };
  config = lib.mkIf config.elixir.enable {
    home.packages = with pkgs; [
      elixir        # Elixir programming language
      erlang        # Erlang/OTP runtime
      livebook      # Interactive notebooks (CLI tool)
      rebar3        # Erlang build tool
    ];
  };
}