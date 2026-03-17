.PHONY: test test-unit test-integration lint clean deps

# Directories
DEPS_DIR  := .deps
PLENARY   := $(DEPS_DIR)/plenary.nvim

# Find Neovim (prefer nvim, fall back to common locations)
NVIM ?= $(shell command -v nvim 2>/dev/null || echo nvim)

# Plenary test harness
PLENARY_OPTS := --headless -u tests/minimal_init.lua \
	-c "lua require('plenary.busted')"

# ──────────────────────────────────────────────
# Targets
# ──────────────────────────────────────────────

## Run all automated tests (unit + integration)
test: deps
	@echo "════════════════════════════════════════"
	@echo " Running unit tests"
	@echo "════════════════════════════════════════"
	$(NVIM) --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua', sequential = true}" 2>&1
	@echo ""
	@echo "All tests passed."

## Run only unit tests
test-unit: deps
	@echo "Running unit tests..."
	$(NVIM) --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedFile tests/pending_spec.lua" 2>&1

## Run only integration tests
test-integration: deps
	@echo "Running integration tests..."
	$(NVIM) --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedFile tests/integration_spec.lua" 2>&1

## Install test dependencies (plenary.nvim)
deps: $(PLENARY)

$(PLENARY):
	@echo "Installing plenary.nvim..."
	@mkdir -p $(DEPS_DIR)
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $(PLENARY)

## Remove test dependencies
clean:
	rm -rf $(DEPS_DIR)

## Show help
help:
	@echo "pending.nvim test targets:"
	@echo ""
	@echo "  make test              Run all tests (unit + integration)"
	@echo "  make test-unit         Run unit tests only"
	@echo "  make test-integration  Run integration tests only"
	@echo "  make deps              Install test dependencies"
	@echo "  make clean             Remove test dependencies"
	@echo ""
	@echo "Set NVIM to override the Neovim binary:"
	@echo "  make test NVIM=/path/to/nvim"
