# ============================================================================
# NixOS Configuration Management Makefile
# ============================================================================
#
# This Makefile provides convenient targets for managing NixOS configurations,
# including testing, building, and deployment operations.
#
# Targets:
#   test           - Run all tests for dell-potato configuration
#   test-all       - Run tests for all configured hosts
#   build          - Build system configuration
#   switch         - Build and switch to new configuration
#   dry-run        - Test configuration without applying changes
#   vm-test        - Test configuration in QEMU VM
#   flake-check    - Validate flake configuration
#   update         - Update flake inputs
#   clean          - Clean build artifacts
#   help           - Show this help message
#
# Variables:
#   HOST           - Target host configuration (default: dell-potato)
#   VERBOSE        - Enable verbose output (default: false)
#
# Examples:
#   make test                    # Test dell-potato configuration
#   make HOST=kraken switch      # Switch kraken to new configuration
#   make VERBOSE=1 dry-run       # Verbose dry-run for dell-potato
#
# ============================================================================

.PHONY: test test-all build switch dry-run vm-test flake-check update clean help

# Default host
HOST ?= dell-potato
VERBOSE ?= false

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Helper functions
define log_info
	@echo -e "$(BLUE)[INFO]$(NC) $(1)"
endef

define log_success
	@echo -e "$(GREEN)[SUCCESS]$(NC) $(1)"
endef

define log_warning
	@echo -e "$(YELLOW)[WARNING]$(NC) $(1)"
endef

define log_error
	@echo -e "$(RED)[ERROR]$(NC) $(1)"
endef

# Check if host exists in flake
check_host:
	@nix eval ".#nixosConfigurations.$(HOST)" >/dev/null 2>&1 || (echo -e "$(RED)[ERROR]$(NC) Host '$(HOST)' not found in flake" && exit 1)

# Test targets
test: check_host
	$(call log_info,Running tests for $(HOST))
	@if [ "$(VERBOSE)" = "true" ]; then \
		./test-nixos-config.sh $(HOST) --all; \
	else \
		./test-nixos-config.sh $(HOST) --all 2>/dev/null; \
	fi
	$(call log_success,Tests completed for $(HOST))

test-all:
	$(call log_info,Running tests for all hosts)
	@for host in dell-potato kraken; do \
		if nix eval ".#nixosConfigurations.$$host" >/dev/null 2>&1; then \
			$(call log_info,Testing $$host); \
			if [ "$(VERBOSE)" = "true" ]; then \
				./test-nixos-config.sh $$host --all || exit 1; \
			else \
				./test-nixos-config.sh $$host --all 2>/dev/null || exit 1; \
			fi; \
		else \
			$(call log_warning,Skipping $$host - not found in flake); \
		fi; \
	done
	$(call log_success,All tests completed)

# Build targets
build: check_host
	$(call log_info,Building configuration for $(HOST))
	@if [ "$(VERBOSE)" = "true" ]; then \
		nix build ".#nixosConfigurations.$(HOST).config.system.build.toplevel" --verbose; \
	else \
		nix build ".#nixosConfigurations.$(HOST).config.system.build.toplevel"; \
	fi
	$(call log_success,Build completed for $(HOST))

# Deployment targets
switch: check_host
	$(call log_info,Switching to new configuration for $(HOST))
	@if [ "$(VERBOSE)" = "true" ]; then \
		sudo nixos-rebuild switch --flake ".#$(HOST)" --verbose; \
	else \
		sudo nixos-rebuild switch --flake ".#$(HOST)"; \
	fi
	$(call log_success,Switch completed for $(HOST))

dry-run: check_host
	$(call log_info,Running dry-run for $(HOST))
	@if [ "$(VERBOSE)" = "true" ]; then \
		sudo nixos-rebuild dry-run --flake ".#$(HOST)" --verbose; \
	else \
		sudo nixos-rebuild dry-run --flake ".#$(HOST)"; \
	fi
	$(call log_success,Dry-run completed for $(HOST))

# VM testing
vm-test: check_host
	$(call log_info,Building VM test for $(HOST))
	@nix build ".#nixosConfigurations.$(HOST).config.system.build.vm"
	$(call log_success,VM build completed for $(HOST))
	$(call log_info,Starting VM (press Ctrl+C to stop))
	@./result/bin/run-*-vm

# Flake operations
flake-check:
	$(call log_info,Validating flake configuration)
	@if [ "$(VERBOSE)" = "true" ]; then \
		nix flake check --verbose; \
	else \
		nix flake check; \
	fi
	$(call log_success,Flake validation completed)

update:
	$(call log_info,Updating flake inputs)
	@nix flake update
	$(call log_success,Flake inputs updated)

# Cleanup
clean:
	$(call log_info,Cleaning build artifacts)
	@rm -rf result
	$(call log_success,Cleanup completed)

# CI/CD pipeline
ci-pipeline: check_host
	$(call log_info,Running CI/CD pipeline for $(HOST))
	@if [ "$(VERBOSE)" = "true" ]; then \
		VERBOSE=true ./nixos-ci-pipeline.sh $(HOST); \
	else \
		./nixos-ci-pipeline.sh $(HOST); \
	fi
	$(call log_success,CI/CD pipeline completed)

# Help target
help:
	@echo "NixOS Configuration Management"
	@echo ""
	@echo "Available targets:"
	@echo "  test          - Run all tests for dell-potato configuration"
	@echo "  test-all      - Run tests for all configured hosts"
	@echo "  build         - Build system configuration"
	@echo "  switch        - Build and switch to new configuration"
	@echo "  dry-run       - Test configuration without applying changes"
	@echo "  vm-test       - Test configuration in QEMU VM"
	@echo "  flake-check   - Validate flake configuration"
	@echo "  update        - Update flake inputs"
	@echo "  clean         - Clean build artifacts"
	@echo "  ci-pipeline   - Run CI/CD pipeline"
	@echo "  help          - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  HOST=dell-potato  - Target host configuration"
	@echo "  VERBOSE=1         - Enable verbose output"
	@echo ""
	@echo "Examples:"
	@echo "  make test"
	@echo "  make HOST=kraken switch"
	@echo "  make VERBOSE=1 dry-run"