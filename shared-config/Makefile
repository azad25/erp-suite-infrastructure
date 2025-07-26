# ERP Suite Shared Configuration Makefile
# This Makefile provides convenient commands for managing shared configurations

.PHONY: help generate-env generate-all-envs validate clean install-deps test

# Default target
help:
	@echo "ERP Suite Shared Configuration System"
	@echo ""
	@echo "Available commands:"
	@echo "  help                    Show this help message"
	@echo "  generate-env            Generate environment file for a specific module"
	@echo "  generate-all-envs       Generate environment files for all modules"
	@echo "  validate                Validate configuration files"
	@echo "  clean                   Clean generated files"
	@echo "  install-deps            Install required dependencies"
	@echo "  test                    Test configuration generators"
	@echo ""
	@echo "Environment variables:"
	@echo "  ENV=<environment>       Environment (development, staging, production, testing)"
	@echo "  MODULE=<module>         Module name (auth, crm, hrm, finance, inventory, projects, ai, frontend, admin)"
	@echo "  OUTPUT=<file>           Output file path (optional)"
	@echo ""
	@echo "Examples:"
	@echo "  make generate-env ENV=development MODULE=auth"
	@echo "  make generate-env ENV=production MODULE=frontend OUTPUT=.env.prod"
	@echo "  make generate-all-envs ENV=staging"
	@echo "  make validate"

# Configuration variables
ENV ?= development
MODULE ?= auth
OUTPUT ?=

# Go modules that use the Go generator
GO_MODULES = auth crm hrm finance inventory projects notification

# Python modules that use the Python generator
PYTHON_MODULES = ai

# Node.js modules that use the Node.js generator
NODEJS_MODULES = frontend admin websocket

# All modules
ALL_MODULES = $(GO_MODULES) $(PYTHON_MODULES) $(NODEJS_MODULES)

# Generate environment file for a specific module
generate-env:
	@echo "Generating environment file for $(MODULE) in $(ENV) environment..."
	@if echo "$(GO_MODULES)" | grep -wq "$(MODULE)"; then \
		echo "Using Go generator..."; \
		cd generators && go run generate-env.go --env=$(ENV) --module=$(MODULE) $(if $(OUTPUT),--output=$(OUTPUT)) --verbose; \
	elif echo "$(PYTHON_MODULES)" | grep -wq "$(MODULE)"; then \
		echo "Using Python generator..."; \
		cd generators && python3 generate-env.py --env=$(ENV) --module=$(MODULE) $(if $(OUTPUT),--output=$(OUTPUT)) --verbose; \
	elif echo "$(NODEJS_MODULES)" | grep -wq "$(MODULE)"; then \
		echo "Using Node.js generator..."; \
		cd generators && node generate-env.js --env=$(ENV) --module=$(MODULE) $(if $(OUTPUT),--output=$(OUTPUT)) --verbose; \
	else \
		echo "Error: Unknown module '$(MODULE)'"; \
		echo "Available modules: $(ALL_MODULES)"; \
		exit 1; \
	fi

# Generate environment files for all modules
generate-all-envs:
	@echo "Generating environment files for all modules in $(ENV) environment..."
	@for module in $(GO_MODULES); do \
		echo "Generating for $$module (Go)..."; \
		cd generators && go run generate-env.go --env=$(ENV) --module=$$module --verbose; \
	done
	@for module in $(PYTHON_MODULES); do \
		echo "Generating for $$module (Python)..."; \
		cd generators && python3 generate-env.py --env=$(ENV) --module=$$module --verbose; \
	done
	@for module in $(NODEJS_MODULES); do \
		echo "Generating for $$module (Node.js)..."; \
		cd generators && node generate-env.js --env=$(ENV) --module=$$module --verbose; \
	done
	@echo "All environment files generated successfully!"

# Generate for specific environment and all modules
generate-dev:
	@$(MAKE) generate-all-envs ENV=development

generate-test:
	@$(MAKE) generate-all-envs ENV=testing

generate-staging:
	@$(MAKE) generate-all-envs ENV=staging

generate-prod:
	@$(MAKE) generate-all-envs ENV=production

# Validate configuration files
validate:
	@echo "Validating configuration files..."
	@echo "Checking YAML syntax..."
	@for file in environments/*.yaml; do \
		echo "Validating $$file..."; \
		python3 -c "import yaml; yaml.safe_load(open('$$file'))" || exit 1; \
	done
	@echo "Validating main config..."
	@python3 -c "import yaml; yaml.safe_load(open('config.yaml'))" || exit 1
	@echo "All configuration files are valid!"

# Test configuration generators
test:
	@echo "Testing configuration generators..."
	@echo "Testing Go generator..."
	@cd generators && go run generate-env.go --env=testing --module=auth --output=test-auth.env --verbose
	@echo "Testing Python generator..."
	@cd generators && python3 generate-env.py --env=testing --module=ai --output=test-ai.env --verbose
	@echo "Testing Node.js generator..."
	@cd generators && node generate-env.js --env=testing --module=frontend --output=test-frontend.env --verbose
	@echo "Cleaning up test files..."
	@rm -f generators/test-*.env
	@echo "All generators tested successfully!"

# Clean generated files
clean:
	@echo "Cleaning generated environment files..."
	@find . -name ".env.*" -type f -delete
	@find generators -name "test-*.env" -type f -delete
	@echo "Cleaned up generated files!"

# Install required dependencies
install-deps:
	@echo "Installing dependencies..."
	@echo "Installing Go dependencies..."
	@cd generators && go mod tidy || echo "Go modules not initialized, skipping..."
	@echo "Installing Python dependencies..."
	@pip3 install pyyaml || echo "Failed to install Python dependencies"
	@echo "Installing Node.js dependencies..."
	@cd generators && npm install js-yaml commander || echo "Failed to install Node.js dependencies"
	@echo "Dependencies installed!"

# Initialize Go module for generators
init-go:
	@echo "Initializing Go module for generators..."
	@cd generators && go mod init erp-suite/shared-config/generators
	@cd generators && go get gopkg.in/yaml.v3
	@echo "Go module initialized!"

# Create package.json for Node.js generators
init-nodejs:
	@echo "Creating package.json for Node.js generators..."
	@cd generators && echo '{"name": "erp-suite-config-generators", "version": "1.0.0", "dependencies": {"js-yaml": "^4.1.0", "commander": "^11.1.0"}}' > package.json
	@cd generators && npm install
	@echo "Node.js package initialized!"

# Show configuration for a specific environment
show-config:
	@echo "Configuration for $(ENV) environment:"
	@cat environments/$(ENV).yaml

# Show available environments
show-environments:
	@echo "Available environments:"
	@ls -1 environments/*.yaml | sed 's/environments\///g' | sed 's/\.yaml//g'

# Show available modules
show-modules:
	@echo "Available modules:"
	@echo "Go modules: $(GO_MODULES)"
	@echo "Python modules: $(PYTHON_MODULES)"
	@echo "Node.js modules: $(NODEJS_MODULES)"

# Backup configurations
backup:
	@echo "Creating backup of configurations..."
	@tar -czf config-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz environments/ config.yaml generators/
	@echo "Backup created successfully!"

# Restore from backup
restore:
	@echo "Available backups:"
	@ls -1 config-backup-*.tar.gz 2>/dev/null || echo "No backups found"
	@echo "To restore, run: tar -xzf <backup-file>"

# Check configuration differences between environments
diff-envs:
	@if [ -z "$(ENV1)" ] || [ -z "$(ENV2)" ]; then \
		echo "Usage: make diff-envs ENV1=<env1> ENV2=<env2>"; \
		echo "Example: make diff-envs ENV1=development ENV2=production"; \
		exit 1; \
	fi
	@echo "Differences between $(ENV1) and $(ENV2):"
	@diff -u environments/$(ENV1).yaml environments/$(ENV2).yaml || true

# Generate documentation
docs:
	@echo "Generating configuration documentation..."
	@echo "# ERP Suite Configuration Documentation" > CONFIG_DOCS.md
	@echo "" >> CONFIG_DOCS.md
	@echo "## Environments" >> CONFIG_DOCS.md
	@for env in development testing staging production; do \
		echo "### $$env" >> CONFIG_DOCS.md; \
		echo "\`\`\`yaml" >> CONFIG_DOCS.md; \
		head -20 environments/$$env.yaml >> CONFIG_DOCS.md; \
		echo "\`\`\`" >> CONFIG_DOCS.md; \
		echo "" >> CONFIG_DOCS.md; \
	done
	@echo "Documentation generated in CONFIG_DOCS.md"

# Quick setup for new developers
setup:
	@echo "Setting up ERP Suite shared configuration system..."
	@$(MAKE) install-deps
	@$(MAKE) init-go
	@$(MAKE) init-nodejs
	@$(MAKE) validate
	@$(MAKE) test
	@echo "Setup completed successfully!"
	@echo ""
	@echo "Quick start:"
	@echo "  make generate-env ENV=development MODULE=auth"
	@echo "  make generate-all-envs ENV=development"
	@echo "  make help"