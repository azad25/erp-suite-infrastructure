# ERP Suite Infrastructure Makefile

.PHONY: help start stop restart reload pause resume build-service rebuild-service setup-proxy start-with-proxy start-dev check-ports prepare-environment configure-network detect-network-ip update-proxy-config create-nginx-config get-network-ip run start-services start-proxy-services init-dbs wait-for-service detect-os install-deps logs services status print-service-info expose-dev print-network-info print-info print-dev generate-ssl enable-https print-proxy-info macos-config macos-performance macos-clean build-all restart-proxy

# Variables
SERVICE ?=
APP ?=
HOST_IP ?= 0.0.0.0  # Expose to all interfaces, can be changed to specific IP
ENVIRONMENT ?= development
BUILD_TYPE ?= dev

# Include modular Makefile sections
include core-commands.mk

# Default target
help:
	@echo "ERP Suite Infrastructure - Complete Management Commands"
	@echo ""
	@echo "🚀 Core Commands:"
	@echo "  start                - Complete startup (env prep, port check, network config, proxy setup, start services)"
	@echo "  start-dev            - Development startup with sequential service loading"
	@echo "  start-with-proxy     - Start with reverse proxy (recommended for network access)"
	@echo "  stop                 - Stop all services and free ports"
	@echo "  restart              - Complete restart (stop + start)"
	@echo "  reload               - Reload specific service (e.g., make reload SERVICE=postgres)"
	@echo "  pause                - Pause all services"
	@echo "  resume               - Resume all paused services"
	@echo ""
	@echo "🔧 Setup Commands:"
	@echo "  setup-proxy          - Setup reverse proxy configuration"
	@echo "  configure-network    - Configure network exposure"
	@echo "  prepare-environment  - Prepare environment files and directories"
	@echo "  check-ports          - Check for port conflicts"
	@echo ""
	@echo "🔨 Build Commands:"
	@echo "  build-service SERVICE= - Build specific service"
	@echo "  rebuild-service SERVICE= - Rebuild and restart service"
	@echo ""
	@echo "🌐 Network Commands:"
	@echo "  expose-dev           - Expose services to network"
	@echo "  generate-ssl         - Generate SSL certificates"
	@echo "  enable-https         - Enable HTTPS (requires SSL)"
	@echo ""
	@echo "📊 Status Commands:"
	@echo "  status               - Quick status check"
	@echo "  services             - Show running services"
	@echo "  logs                 - Show logs from all services"
	@echo "  logs APP=name        - Show logs from specific app"
	@echo ""
	@echo "🛠️  Utility Commands:"
	@echo "  force-stop           - Force stop with aggressive cleanup"
	@echo "  full-stop            - Complete shutdown with cleanup"
	@echo "  install-deps SERVICE= - Install dependencies for service"
	@echo ""
	@echo "🍎 macOS Optimization:"
	@echo "  macos-config         - Switch to macOS-optimized configuration"
	@echo "  macos-performance    - Check Docker performance"
	@echo "  macos-clean          - Clean up Docker for macOS"

# ============================================================================
# NETWORK DETECTION
# ============================================================================

# Internal target to ONLY get the local IP. No friendly messages.
_get-local-ip:
	@OS=$$(uname); \
	ip=""; \
	if [ "$$OS" = "Darwin" ]; then \
		ip=$$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $$2}'); \
	elif [ "$$OS" = "Linux" ]; then \
		ip=$$(hostname -I | awk '{print $$1}'); \
	elif [ "$$OS" = "Windows" ] || [ "$$(uname -s | cut -c1-5)" = "MINGW" ]; then \
		ip=$$(ipconfig | grep "IPv4" | head -1 | awk '{print $$NF}'); \
	else \
		ip=$$(hostname -I | awk '{print $$1}' 2>/dev/null); \
	fi; \
	if [ -z "$$ip" ]; then \
		echo "127.0.0.1"; \
	else \
		echo "$$ip"; \
	fi

# User-facing target to show detected IP
detect-network-ip:
	@echo "🔍 Detecting network IP..."
	@ip=$$($(MAKE) -s _get-local-ip); \
	if [ "$$ip" = "127.0.0.1" ]; then \
		echo "⚠️  Could not detect network IP, using localhost"; \
	else \
		echo "✅ Detected network IP: $$ip"; \
	fi

# ============================================================================
# CORE MANAGEMENT COMMANDS
# ============================================================================

# Stop all services and free ports
stop:
	@echo "🛑 Stopping ERP Suite infrastructure..."
	@echo "📋 Stopping all Docker Compose services..."
	@docker compose -f docker-compose.yml down --remove-orphans --volumes --timeout 30 2>/dev/null || true
	@echo "🔍 Killing any remaining ERP Suite containers..."
	@docker ps -a --filter "name=erp-suite" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true
	@echo "🧹 Cleaning up orphaned containers..."
	@docker container prune -f 2>/dev/null || true
	@echo "🌐 Cleaning up unused networks..."
	@docker network prune -f 2>/dev/null || true
	@echo "🔍 Checking for processes still using ERP ports..."
	@OS=$$(uname); \
	ports="5432 27017 6378 6333 9092 9200 5601 4000 8500 3001 8081 8082 8083 8084"; \
	killed_processes=0; \
	for port in $$ports; do \
		if [ "$$OS" = "Darwin" ]; then \
			pids=$$(lsof -ti :$$port 2>/dev/null || true); \
		elif [ "$$OS" = "Linux" ]; then \
			pids=$$(ss -tlnp | grep ":$$port " | sed 's/.*pid=\([0-9]*\).*/\1/' 2>/dev/null || true); \
		fi; \
		if [ -n "$$pids" ]; then \
			echo "⚠️  Found processes using port $$port: $$pids"; \
			for pid in $$pids; do \
				if ps -p $$pid > /dev/null 2>&1; then \
					echo "🔪 Killing process $$pid on port $$port"; \
					kill -9 $$pid 2>/dev/null || true; \
					killed_processes=$$((killed_processes + 1)); \
				fi; \
			done; \
		fi; \
	done; \
	if [ $$killed_processes -gt 0 ]; then \
		echo "⚡ Killed $$killed_processes processes"; \
		sleep 2; \
	fi
	@echo "🔍 Final port check..."
	@OS=$$(uname); \
	ports="5432 27017 6378 6333 9092 9200 5601 4000 8500 3001 8081 8082 8083 8084"; \
	still_in_use=0; \
	for port in $$ports; do \
		port_in_use=false; \
		if [ "$$OS" = "Darwin" ]; then \
			if lsof -i :$$port > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		elif [ "$$OS" = "Linux" ]; then \
			if ss -tuln | grep ":$$port " > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		fi; \
		if [ "$$port_in_use" = "true" ]; then \
			echo "⚠️  Port $$port is still in use"; \
			still_in_use=$$((still_in_use + 1)); \
		fi; \
	done; \
	if [ $$still_in_use -eq 0 ]; then \
		echo "✅ All ERP Suite ports are now free!"; \
	else \
		echo "⚠️  $$still_in_use ports are still in use (may be system services)"; \
	fi
	@echo "✅ ERP Suite infrastructure stopped and ports freed!"

# Force stop with aggressive cleanup
force-stop:
	@echo "💥 Force stopping ERP Suite infrastructure with aggressive cleanup..."
	@echo "⚠️  This will kill ALL Docker containers and clean up everything!"
	@read -p "Are you sure? This will stop ALL Docker containers (y/N): " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "🔥 Stopping all Docker containers..."; \
		docker stop $$(docker ps -q) 2>/dev/null || true; \
		echo "🗑️  Removing all Docker containers..."; \
		docker rm -f $$(docker ps -aq) 2>/dev/null || true; \
		echo "🌐 Removing all Docker networks..."; \
		docker network rm $$(docker network ls -q) 2>/dev/null || true; \
		echo "💾 Removing all Docker volumes..."; \
		docker volume rm $$(docker volume ls -q) 2>/dev/null || true; \
		echo "🧹 Pruning Docker system..."; \
		docker system prune -af --volumes 2>/dev/null || true; \
		echo "✅ Aggressive cleanup complete!"; \
	else \
		echo "❌ Force stop cancelled"; \
	fi


# Pause all services
pause:
	@echo "⏸️  Pausing all ERP Suite services..."
	@docker compose -f docker-compose.yml pause
	@echo "✅ All services paused"

# Resume all paused services
resume:
	@echo "▶️  Resuming all ERP Suite services..."
	@docker compose -f docker-compose.yml unpause
	@echo "✅ All services resumed"

# Reload specific service
reload:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE parameter required. Usage: make reload SERVICE=postgres"; \
		exit 1; \
	fi
	@echo "🔄 Reloading $(SERVICE)..."
	@docker compose -f docker-compose.yml restart $(SERVICE)
	@echo "✅ $(SERVICE) reloaded"

# Build specific service
build-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE parameter required. Usage: make build-service SERVICE=frontend"; \
		exit 1; \
	fi
	@echo "🔨 Building $(SERVICE)..."
	@docker compose -f docker-compose.yml build $(SERVICE)
	@echo "✅ $(SERVICE) built"

# Rebuild and restart service
rebuild-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE parameter required. Usage: make rebuild-service SERVICE=frontend"; \
		exit 1; \
	fi
	@echo "🔨 Rebuilding $(SERVICE)..."
	@docker compose -f docker-compose.yml stop $(SERVICE)
	@docker compose -f docker-compose.yml rm -f $(SERVICE)
	@docker compose -f docker-compose.yml build --no-cache $(SERVICE)
	@docker compose -f docker-compose.yml up -d $(SERVICE)
	@echo "✅ $(SERVICE) rebuilt and restarted"

# Full stop with cleanup
full-stop:
	@echo "🛑 Complete shutdown..."
	@docker compose -f docker-compose.yml down -v --remove-orphans
	@docker system prune -f --volumes
	@echo "✅ Complete shutdown finished"
	@echo "💡 Run 'make start' to restart"

# ============================================================================
# DOCKER COMPOSE COMMANDS
# ============================================================================

# Prepare required directories and files
prepare-environment:
	@echo "📁 Preparing environment..."
	@mkdir -p config/grafana/provisioning/datasources
	@mkdir -p config/grafana/provisioning/dashboards
	@mkdir -p config/grafana/dashboards
	@mkdir -p backups
	@echo "🔧 Setting up environment files..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Created .env from .env.example"; \
		echo "⚠️  Please review and customize .env file for your environment"; \
	fi
	@if [ ! -f config/prometheus.yml ] && [ -f config/prometheus.yml.example ]; then \
		cp config/prometheus.yml.example config/prometheus.yml; \
		echo "✅ Created config/prometheus.yml from example"; \
	fi
	@if [ ! -f config/pgadmin/servers.json ] && [ -f config/pgadmin/servers.json.example ]; then \
		cp config/pgadmin/servers.json.example config/pgadmin/servers.json; \
		echo "✅ Created config/pgadmin/servers.json from example"; \
	fi
	@echo "✅ Environment preparation complete!"

# Detect operating system
detect-os:
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "macOS"; \
	elif [ "$$(uname)" = "Linux" ]; then \
		echo "Linux"; \
	elif [ "$$(uname -s | cut -c1-5)" = "MINGW" ] || [ "$$(uname -s | cut -c1-4)" = "MSYS" ]; then \
		echo "Windows"; \
	else \
		echo "Unknown"; \
	fi

# Check for port conflicts before starting services (cross-platform)
check-ports:
	@echo "🔍 Checking for port conflicts..."
	@echo ""
	@echo "📋 Required Ports:"
	@OS=$$($(MAKE) -s detect-os); \
	ports="5432:PostgreSQL 27017:MongoDB 6378:Redis 6333:Qdrant 9092:Kafka 9200:Elasticsearch 5601:Kibana 8500:Consul 8081:pgAdmin 8082:MongoExpress 8083:RedisCommander 8084:KafkaUI 8080:AuthService 8000:APIGateway 8001:LogService 3000:Frontend"; \
	conflicts=0; \
	for port_info in $$ports; do \
		port=$$(echo $$port_info | cut -d: -f1); \
		service=$$(echo $$port_info | cut -d: -f2); \
		port_in_use=false; \
		if [ "$$OS" = "Windows" ]; then \
			if netstat -an | grep ":$$port " > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		elif [ "$$OS" = "Linux" ] || [ "$$OS" = "macOS" ]; then \
			if command -v lsof > /dev/null 2>&1; then \
				if lsof -i :$$port > /dev/null 2>&1; then \
					port_in_use=true; \
				fi; \
			elif command -v netstat > /dev/null 2>&1; then \
				if netstat -tuln | grep ":$$port " > /dev/null 2>&1; then \
					port_in_use=true; \
				fi; \
			elif command -v ss > /dev/null 2>&1; then \
				if ss -tuln | grep ":$$port " > /dev/null 2>&1; then \
					port_in_use=true; \
				fi; \
			fi; \
		fi; \
		if [ "$$port_in_use" = "true" ]; then \
			echo "❌ Port $$port ($$service) is already in use"; \
			conflicts=$$((conflicts + 1)); \
		else \
			echo "✅ Port $$port ($$service) is available"; \
		fi; \
	done; \
	echo ""; \
	if [ $$conflicts -gt 0 ]; then \
		echo "⚠️  Found $$conflicts port conflicts. Please stop conflicting services or change ports in .env"; \
		if [ "$$OS" = "Windows" ]; then \
			echo "💡 You can kill processes using: netstat -ano | findstr :PORT"; \
		else \
			echo "💡 You can kill processes using: sudo lsof -ti:PORT | xargs kill -9"; \
		fi; \
		exit 1; \
	else \
		echo "🎉 All required ports are available!"; \
	fi

# Wait for a specific service to be healthy (optimized for slower systems)
wait-for-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE parameter required. Usage: make wait-for-service SERVICE=postgres"; \
		exit 1; \
	fi
	@echo "⏳ Waiting for $(SERVICE) to be healthy..."
	@if [ "$(SERVICE)" = "kafka" ] || [ "$(SERVICE)" = "elasticsearch" ]; then \
		timeout=300; \
	elif [ "$(SERVICE)" = "kibana" ] || [ "$(SERVICE)" = "mongodb" ]; then \
		timeout=240; \
	else \
		timeout=180; \
	fi; \
	initial_timeout=$$timeout; \
	while [ $$timeout -gt 0 ]; do \
		if docker compose -f docker-compose.yml ps $(SERVICE) | grep -q "healthy\|Up"; then \
			echo "✅ $(SERVICE) is ready (took $$((initial_timeout - timeout)) seconds)"; \
			break; \
		fi; \
		if [ $$((timeout % 30)) -eq 0 ]; then \
			echo "⏳ Still waiting for $(SERVICE)... ($$timeout seconds remaining)"; \
			echo "💡 $(SERVICE) is starting up, this may take a while on slower systems"; \
		fi; \
		sleep 10; \
		timeout=$$((timeout - 10)); \
	done; \
	if [ $$timeout -le 0 ]; then \
		echo "❌ $(SERVICE) failed to start within timeout"; \
		echo "📋 Last 30 lines of $(SERVICE) logs:"; \
		docker compose -f docker-compose.yml logs $(SERVICE) | tail -30; \
		echo ""; \
		echo "💡 Troubleshooting tips:"; \
		echo "  • Check if Docker has enough memory allocated (4GB+ recommended)"; \
		echo "  • Try: make logs APP=$(SERVICE) for full logs"; \
		echo "  • Try: make reload SERVICE=$(SERVICE) to restart the service"; \
		exit 1; \
	fi

# Initialize PostgreSQL and MongoDB
init-dbs:
	@echo "🔧 Initializing databases..."
	@databases="erp_auth erp_core erp_crm erp_hrm erp_finance erp_inventory erp_projects"; \
	for db in $$databases; do \
		echo "Creating database: $$db"; \
		docker compose -f docker-compose.yml exec -T postgres psql -U postgres -c "CREATE DATABASE $$db;" > /dev/null 2>&1 || echo "Database $$db already exists"; \
	done
	@echo "✅ PostgreSQL databases initialized!"

	@echo "🔧 Initializing MongoDB..."
	@docker compose -f docker-compose.yml exec -T mongodb mongosh --quiet --eval "db.createCollection('init_collection')" > /dev/null 2>&1 || echo "MongoDB already initialized"
	@echo "✅ MongoDB initialized!"

# ============================================================================
# CORE STARTUP COMMANDS
# ============================================================================

# Complete startup with all preparations
start: prepare-environment check-ports configure-network setup-proxy start-services print-proxy-info
	@echo "✅ ERP Suite infrastructure started successfully!"

# Development startup (sequential)
start-dev: prepare-environment run print-dev
	@echo "✅ ERP Suite development infrastructure started!"

# Sequential startup for development
run:
	@echo "🚀 Starting ERP Suite infrastructure sequentially..."
	@echo "This reduces resource load by starting services in dependency order"
	@echo ""
	@echo "📋 Startup Sequence:"
	@echo "  Phase 1: Core Databases (PostgreSQL, Redis)"
	@echo "  Phase 2: Document & Vector Stores (MongoDB, Qdrant)"
	@echo "  Phase 3: Message Broker (Kafka)"
	@echo "  Phase 4: Search Engine (Elasticsearch)"
	@echo "  Phase 5: API Layer (gRPC Registry)"
	@echo "  Phase 6: Server"
	@echo "  Phase 7: Logging (Kibana)"
	@echo "  Phase 8: Development Tools"
	@echo "  Phase 9: Core Application Services"
	@echo ""
	@echo "🔄 Phase 1: Starting core databases..."
	@docker compose -f docker-compose.yml up -d postgres redis
	@$(MAKE) wait-for-service SERVICE=postgres
	@$(MAKE) wait-for-service SERVICE=redis
	@$(MAKE) init-dbs
	@echo "✅ Phase 1 complete: Core databases ready"
	@sleep 2
	@echo "🔄 Phase 2: Starting document and vector stores..."
	@docker compose -f docker-compose.yml up -d mongodb qdrant
	@$(MAKE) wait-for-service SERVICE=mongodb
	@$(MAKE) wait-for-service SERVICE=qdrant
	@echo "✅ Phase 2 complete: Document and vector stores ready"
	@sleep 2
	@echo "🔄 Phase 3: Starting message broker..."
	@docker compose -f docker-compose.yml up -d kafka
	@$(MAKE) wait-for-service SERVICE=kafka
	@echo "✅ Phase 3 complete: Message broker ready"
	@sleep 2
	@echo "🔄 Phase 4: Starting search engine..."
	@docker compose -f docker-compose.yml up -d elasticsearch
	@$(MAKE) wait-for-service SERVICE=elasticsearch
	@echo "✅ Phase 4 complete: Search engine ready"
	@sleep 2
	@echo "🔄 Phase 5: Starting API layer..."
	@docker compose -f docker-compose.yml up -d grpc-registry
	@$(MAKE) wait-for-service SERVICE=grpc-registry
	@echo "✅ Phase 5 complete: API layer ready"
	@sleep 2
	@echo "✅ Phase 6 complete: server ready"
	@sleep 2
	@echo "🔄 Phase 7: Starting logging services..."
	@docker compose -f docker-compose.yml up -d kibana
	@cd ./ && ./scripts/setup-logging.sh
	@echo "✅ Phase 7 complete: Logging services ready"
	@sleep 2
	@echo "🔄 Phase 8: Starting development tools..."
	@docker compose -f docker-compose.yml --profile dev-tools up -d
	@echo "✅ Phase 8 complete: Development tools ready"
	@echo "🔄 Phase 9: Starting core application services..."

	@echo "🔄 Phase 9a: Starting Auth Service..."
	@cd ../erp-auth-service && go mod tidy && go build && cd ..
	@docker compose -f docker-compose.yml --profile full-stack up -d auth-service
	@$(MAKE) wait-for-service SERVICE=auth-service
	@echo "🔄 Phase 9b: Starting API Gateway..."
	@docker compose -f docker-compose.yml --profile full-stack up -d api-gateway
	@$(MAKE) wait-for-service SERVICE=api-gateway
	@echo "🔄 Phase 9c: Starting Log Service..."
	@docker compose -f docker-compose.yml --profile full-stack up -d log-service
	@echo "🔄 Phase 10: Starting Frontend..."
	@docker compose -f docker-compose.yml --profile full-stack up -d erp-frontend
	@echo "✅ Phase 9-10 complete: All core application services up and running..."
	@echo ""
	@echo "🔄 Phase 11: Starting Reverse Proxy..."
	@echo "🌐 Configuring nginx proxy server"
	@docker compose -f docker-compose.yml up -d nginx-proxy
	@docker compose -f docker-compose.yml --profile proxy --profile full-stack --profile api-layer up -d nginx-proxy
	@$(MAKE) wait-for-service SERVICE=nginx-proxy
	@echo "✅ Phase 11 complete: proxy server is ready."
	@echo "✅ All services with proxy started!"

	@echo "✅ ERP Infrastructure online"

# Start with reverse proxy
start-with-proxy: prepare-environment check-ports setup-proxy start-proxy-services print-proxy-info
	@echo "✅ ERP Suite with reverse proxy started successfully!"

# Start all services (standard)
start-services:
	@echo "🚀 Starting all ERP Suite services..."
	@docker compose -f docker-compose.yml --profile infrastructure --profile api-layer --profile logging --profile dev-tools --profile full-stack up -d
	@$(MAKE) init-dbs
	@echo "✅ All services started!"

# Start services with proxy (sequentially)
start-proxy-services:
	@echo "🚀 Starting ERP Suite services sequentially with reverse proxy..."
	@echo "This reduces resource load by starting services in dependency order"
	@echo ""
	@echo "📋 Startup Sequence:"
	@echo "  Phase 1: Core Databases (PostgreSQL, Redis)"
	@echo "  Phase 2: Document & Vector Stores (MongoDB, Qdrant)"
	@echo "  Phase 3: Message Broker (Kafka)"
	@echo "  Phase 4: Search Engine (Elasticsearch)"
	@echo "  Phase 5: API Layer (gRPC Registry)"
	@echo "  Phase 6: Server"
	@echo "  Phase 7: Logging (Kibana)"
	@echo "  Phase 8: Development Tools"
	@echo "  Phase 9: Core Application Services"
	@echo "  Phase 10: Reverse Proxy"
	@echo ""
	@echo "🔄 Phase 1: Starting core databases..."
	@docker compose -f docker-compose.yml up -d postgres redis
	@$(MAKE) wait-for-service SERVICE=postgres
	@$(MAKE) wait-for-service SERVICE=redis
	@echo "✅ Phase 1 complete: Core databases ready"
	@sleep 2
	@echo "🔄 Phase 2: Starting document and vector stores..."
	@docker compose -f docker-compose.yml up -d mongodb qdrant
	@$(MAKE) wait-for-service SERVICE=mongodb
	@$(MAKE) wait-for-service SERVICE=qdrant
	@echo "✅ Phase 2 complete: Document and vector stores ready"
	@sleep 2
	@echo "🔄 Phase 3: Starting message broker..."
	@docker compose -f docker-compose.yml up -d kafka
	@$(MAKE) wait-for-service SERVICE=kafka
	@echo "✅ Phase 3 complete: Message broker ready"
	@sleep 2
	@echo "🔄 Phase 4: Starting search engine..."
	@docker compose -f docker-compose.yml up -d elasticsearch
	@$(MAKE) wait-for-service SERVICE=elasticsearch
	@echo "✅ Phase 4 complete: Search engine ready"
	@sleep 2
	@echo "🔄 Phase 5: Starting API layer..."
	@docker compose -f docker-compose.yml up -d grpc-registry
	@$(MAKE) wait-for-service SERVICE=grpc-registry
	@echo "✅ Phase 5 complete: API layer ready"
	@sleep 2
	@echo "✅ Phase 6 complete: server ready"
	@sleep 2
	@echo "🔄 Phase 7: Starting logging services..."
	@docker compose -f docker-compose.yml up -d kibana
	@echo "✅ Phase 7 complete: Logging services ready"
	@sleep 2
	@echo "🔄 Phase 8: Starting development tools..."
	@docker compose -f docker-compose.yml --profile dev-tools up -d

	@echo "✅ Phase 8 complete: Development tools ready"
	@echo "🔄 Phase 9: Starting core application services..."
	@echo "🔄 Configuring Database..."
	@$(MAKE) init-dbs
	@echo "🔄 Phase 9a: Starting Auth Service..."
	@cd ../erp-auth-service && go mod tidy && go build && cd ..
	@docker compose -f docker-compose.yml --profile full-stack up -d auth-service
	@$(MAKE) wait-for-service SERVICE=auth-service
	@echo "🔄 Phase 9b: Starting API Gateway..."
	@docker compose -f docker-compose.yml --profile full-stack up -d api-gateway
	@$(MAKE) wait-for-service SERVICE=api-gateway
	@echo "🔄 Phase 9c: Starting Log Service..."
	@docker compose -f docker-compose.yml --profile full-stack up -d log-service
	@$(MAKE) wait-for-service SERVICE=log-service
	@echo "🔄 Phase 10: Starting Frontend..."
	@docker compose -f docker-compose.yml --profile full-stack up -d erp-frontend
	@$(MAKE) wait-for-service SERVICE=erp-frontend
	@echo "✅ Phase 9-10 complete: All core application services up and running..."
	@echo ""
	@echo "🔄 Phase 11: Starting Reverse Proxy..."
	@echo "🌐 Configuring nginx proxy server"
	@docker compose -f docker-compose.yml up -d nginx-proxy
	@docker compose -f docker-compose.yml --profile proxy --profile full-stack --profile api-layer up -d nginx-proxy
	@$(MAKE) wait-for-service SERVICE=nginx-proxy
	@echo "✅ Phase 11 complete: Reverse proxy is ready."
	@echo "✅ All services with proxy started!"


# ============================================================================
# SETUP COMMANDS
# ============================================================================

# Setup reverse proxy only
setup-proxy:
	@echo "🔧 Setting up reverse proxy configuration..."
	@mkdir -p nginx/conf.d nginx/ssl
	@if [ ! -f nginx/.htpasswd ]; then \
		echo "🔐 Creating basic auth file for admin tools..."; \
		echo "admin:$$(openssl passwd -apr1 admin123)" > nginx/.htpasswd; \
		echo "✅ Admin credentials: admin/admin123"; \
	fi
	@echo "🌐 Configuring proxy for detected network..."
	@$(MAKE) update-proxy-config
	@echo "✅ Reverse proxy setup complete!"

# Update proxy configuration with detected IP
update-proxy-config:
	@echo "📝 Updating NGINX configuration with network IP..."
	@network_ip=$$($(MAKE) -s _get-local-ip); \
	if [ -f nginx/nginx.conf ]; then \
		sed -i.bak "s#server_name .*;#server_name $$network_ip;#g" nginx/nginx.conf; \
		echo "✅ Updated NGINX server_name to: $$network_ip"; \
	else \
		echo "⚠️  nginx/nginx.conf not found, creating from template..."; \
		$(MAKE) create-nginx-config; \
	fi

# Create NGINX configuration if it doesn't exist
create-nginx-config:
	@echo "📝 Creating NGINX configuration..."
	@network_ip=$$($(MAKE) -s _get-local-ip); \
	mkdir -p nginx; \
	cat > nginx/nginx.conf << 'EOF' ; \
user nginx; \
worker_processes auto; \
error_log /var/log/nginx/error.log warn; \
pid /var/run/nginx.pid; \
\
events { \
    worker_connections 1024; \
    use epoll; \
    multi_accept on; \
} \
\
http { \
    include /etc/nginx/mime.types; \
    default_type application/octet-stream; \
\
    # Logging \
    log_format main '$$remote_addr - $$remote_user [$$time_local] "$$request" ' \
                    '$$status $$body_bytes_sent "$$http_referer" ' \
                    '"$$http_user_agent" "$$http_x_forwarded_for"'; \
    access_log /var/log/nginx/access.log main; \
\
    # Performance \
    sendfile on; \
    tcp_nopush on; \
    tcp_nodelay on; \
    keepalive_timeout 65; \
    types_hash_max_size 2048; \
    client_max_body_size 100M; \
\
    # Gzip compression \
    gzip on; \
    gzip_vary on; \
    gzip_min_length 1024; \
    gzip_proxied any; \
    gzip_comp_level 6; \
    gzip_types \
        text/plain \
        text/css \
        text/xml \
        text/javascript \
        application/json \
        application/javascript \
        application/xml+rss \
        application/atom+xml \
        image/svg+xml; \
\
    # Rate limiting \
    limit_req_zone $$binary_remote_addr zone=api:10m rate=10r/s; \
    limit_req_zone $$binary_remote_addr zone=admin:10m rate=5r/s; \
\
    upstream api_gateway_backend { \
        server api-gateway:8000; \
    } \
\
    upstream frontend_backend { \
        server erp-frontend:3000; \
    } \
\
    upstream auth_service_backend { \
        server auth-service:8080; \
    } \
\
    upstream log_service_backend { \
        server log-service:8001; \
    } \
\
    # Development tools upstreams \
    upstream pgadmin_backend { \
        server pgadmin:80; \
    } \
\
    upstream mongo_express_backend { \
        server mongo-express:8081; \
    } \
\
    upstream redis_commander_backend { \
        server redis-commander:8081; \
    } \
\
    upstream kafka_ui_backend { \
        server kafka-ui:8080; \
    } \
\
    upstream kibana_backend { \
        server kibana:5601; \
    } \
\
    upstream consul_backend { \
        server grpc-registry:8500; \
    } \
\
    # Main server block \
    server { \
        listen 80; \
        server_name _; \
\
        # Security headers \
        add_header X-Frame-Options "SAMEORIGIN" always; \
        add_header X-Content-Type-Options "nosniff" always; \
        add_header X-XSS-Protection "1; mode=block" always; \
        add_header Referrer-Policy "no-referrer-when-downgrade" always; \
        add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always; \
\
        # Health check \
        location /health { \
            access_log off; \
            return 200 "healthy\n"; \
            add_header Content-Type text/plain; \
        } \
\
        # Frontend (Next.js) \
        location / { \
            proxy_pass http://frontend_backend; \
            proxy_http_version 1.1; \
            proxy_set_header Upgrade $$http_upgrade; \
            proxy_set_header Connection 'upgrade'; \
            proxy_set_header Host $$host; \
            proxy_set_header X-Real-IP $$remote_addr; \
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for; \
            proxy_set_header X-Forwarded-Proto $$scheme; \
            proxy_cache_bypass $$http_upgrade; \
        } \
\
        # GraphQL API \
        location /graphql { \
            limit_req zone=api burst=20 nodelay; \
            proxy_pass http://api_gateway_backend/graphql; \
            proxy_http_version 1.1; \
            proxy_set_header Host $$host; \
            proxy_set_header X-Real-IP $$remote_addr; \
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for; \
            proxy_set_header X-Forwarded-Proto $$scheme; \
        } \
\
        # API Gateway \
        location /api/v1/ { \
            limit_req zone=api burst=20 nodelay; \
            proxy_pass http://api_gateway_backend; \
            proxy_http_version 1.1; \
            proxy_set_header Host $$host; \
            proxy_set_header X-Real-IP $$remote_addr; \
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for; \
            proxy_set_header X-Forwarded-Proto $$scheme; \
        } \
\
        # Auth Service \
        location /auth/ { \
            limit_req zone=api burst=20 nodelay; \
            proxy_pass http://auth_service_backend; \
            proxy_http_version 1.1; \
            proxy_set_header Host $$host; \
            proxy_set_header X-Real-IP $$remote_addr; \
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for; \
            proxy_set_header X-Forwarded-Proto $$scheme; \
        } \
\
        # Log Service \
        location /logs/ { \
            limit_req zone=api burst=20 nodelay; \
            proxy_pass http://log_service_backend; \
            proxy_http_version 1.1; \
            proxy_set_header Host $$host; \
            proxy_set_header X-Real-IP $$remote_addr; \
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for; \
            proxy_set_header X-Forwarded-Proto $$scheme; \
        } \
\
        # WebSocket \
        location /socket.io/ { \
            proxy_pass http://api_gateway_backend/ws; \
            proxy_http_version 1.1; \
            proxy_set_header Upgrade $$http_upgrade; \
            proxy_set_header Connection "upgrade"; \
            proxy_set_header Host $$host; \
            proxy_set_header X-Real-IP $$remote_addr; \
            proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for; \
            proxy_set_header X-Forwarded-Proto $$scheme; \
        } \
\
        # Admin tools (protected with basic auth) \
        location /admin/ { \
            limit_req zone=admin burst=10 nodelay; \
            auth_basic "Admin Area"; \
            auth_basic_user_file /etc/nginx/.htpasswd; \
\
            # pgAdmin \
            location /admin/pgadmin/ { \
                proxy_pass http://pgadmin_backend; \
                proxy_http_version 1.1; \
                proxy_set_header Host $$host; \
                proxy_set_header X-Real-IP $remote_addr; \
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
                proxy_set_header X-Forwarded-Proto $scheme; \
            } \
\
            # Mongo Express \
            location /admin/mongo/ { \
                proxy_pass http://mongo_express_backend; \
                proxy_http_version 1.1; \
                proxy_set_header Host $host; \
                proxy_set_header X-Real-IP $remote_addr; \
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
                proxy_set_header X-Forwarded-Proto $scheme; \
            } \
\
            # Redis Commander \
            location /admin/redis/ { \
                proxy_pass http://redis_commander_backend; \
                proxy_http_version 1.1; \
                proxy_set_header Host $host; \
                proxy_set_header X-Real-IP $remote_addr; \
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
                proxy_set_header X-Forwarded-Proto $scheme; \
            } \
\
            # Kafka UI \
            location /admin/kafka/ { \
                proxy_pass http://kafka_ui_backend; \
                proxy_http_version 1.1; \
                proxy_set_header Host $host; \
                proxy_set_header X-Real-IP $remote_addr; \
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
                proxy_set_header X-Forwarded-Proto $scheme; \
            } \
\
            # Kibana \
            location /admin/kibana/ { \
                proxy_pass http://kibana_backend; \
                proxy_http_version 1.1; \
                proxy_set_header Host $host; \
                proxy_set_header X-Real-IP $remote_addr; \
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
                proxy_set_header X-Forwarded-Proto $scheme; \
            } \
\
            # Consul \
            location /admin/consul/ { \
                proxy_pass http://consul_backend; \
                proxy_http_version 1.1; \
                proxy_set_header Host $host; \
                proxy_set_header X-Real-IP $remote_addr; \
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
                proxy_set_header X-Forwarded-Proto $scheme; \
            } \
        } \
    } \
} \
EOF
	sed -i "s/server_name _;/server_name $$network_ip;/g" nginx/nginx.conf; \
	echo "✅ Created NGINX configuration for $$network_ip"

# Configure network exposure
configure-network:
	@echo "🌐 Configuring network exposure..."
	@network_ip=$$($(MAKE) -s _get-local-ip); \
	if [ "$$network_ip" != "127.0.0.1" ]; then \
		echo "✅ Detected network IP: $$network_ip"; \
		echo "📝 Updating environment configuration..."; \
		if [ -f .env ]; then \
			sed -i.bak \
				-e "s#localhost:#$$network_ip:#g" \
				-e "s#127.0.0.1:#$$network_ip:#g" \
				.env; \
			echo "✅ Network configuration updated for $$network_ip"; \
		else \
			echo "⚠️  No .env file found, creating from example..."; \
			cp .env.example .env 2>/dev/null || echo "No .env.example found"; \
		fi; \
	else \
		echo "⚠️  Using localhost for network configuration"; \
	fi

# ============================================================================
# RESTART COMMANDS
# ============================================================================

# Complete restart
restart:
	@echo "🔄 Restarting ERP Suite infrastructure..."
	@echo "⏸️  Step 1: Stopping services..."
	@$(MAKE) stop
	@echo "⌛ Waiting for cleanup..."
	@sleep 5
	@echo "🚀 Step 2: Starting services..."
	@$(MAKE) start
	@echo "✅ Restart complete"

# Restart with proxy
restart-proxy:
	@echo "🔄 Restarting ERP Suite with reverse proxy..."
	@echo "⏸️  Step 1: Stopping services..."
	@$(MAKE) stop
	@echo "⌛ Waiting for cleanup..."
	@sleep 5
	@echo "🚀 Step 2: Starting services with proxy..."
	@$(MAKE) start-with-proxy
	@echo "✅ Restart with proxy complete"

# ============================================================================
# BUILD COMMANDS
# ============================================================================

# Build all services
build-all:
	@echo "🔨 Building all ERP Suite services..."
	@docker compose -f docker-compose.yml build --no-cache
	@echo "✅ All services built successfully"

# ============================================================================
# UTILITY COMMANDS
# ============================================================================

# Install dependencies for a specific service
install-deps:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE parameter required. Usage: make install-deps SERVICE=frontend"; \
		exit 1; \
	fi
	@echo "📦 Installing dependencies for $(SERVICE)..."
	@case "$(SERVICE)" in \
		"frontend") \
			cd ../erp-frontend && npm install ;; \
		"auth-service") \
			cd ../erp-auth-service && go mod tidy ;; \
		"api-gateway") \
			cd ../erp-api-gateway && poetry install ;; \
		"log-service") \
			cd ../erp-log-viewer-service && go mod tidy ;; \
		*) \
			echo "❌ Unknown service: $(SERVICE)" && exit 1 ;; \
	esac
	@echo "✅ Dependencies installed for $(SERVICE)"

# Show logs from all services or specific app
logs:
	@if [ -n "$(APP)" ]; then \
		echo "📋 Showing logs for $(APP)..."; \
		docker compose -f docker-compose.yml logs -f $(APP); \
	else \
		echo "📋 Showing logs from all services..."; \
		docker compose -f docker-compose.yml logs -f; \
	fi

# Show running services status
services:
	@echo "📊 Service Status:"
	@docker compose -f docker-compose.yml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose -f docker-compose.yml ps
	@echo ""
	@echo "🔍 Quick Health Check:"
	@printf "PostgreSQL: "
	@docker compose -f docker-compose.yml exec -T postgres pg_isready -U postgres > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "Redis: "
	@docker compose -f docker-compose.yml exec -T redis redis-cli --no-auth-warning -a redispassword ping > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "MongoDB: "
	@docker compose -f docker-compose.yml exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "Kafka: "
	@docker compose -f docker-compose.yml exec -T kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "Elasticsearch: "
	@curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "NGINX Proxy: "
	@curl -s http://localhost/health > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"

# Quick status check
status:
	@echo "🔍 ERP Suite Infrastructure Status"
	@echo "=================================="
	@echo ""
	@echo "📊 Container Status:"
	@containers=$$(docker ps --filter "name=erp-suite" --format "{{.Names}}" 2>/dev/null || true); \
	if [ -z "$$containers" ]; then \
		echo "❌ No ERP Suite containers running"; \
	else \
		for container in $$containers; do \
			status=$$(docker inspect --format='{{.State.Status}}' $$container 2>/dev/null || echo "unknown"); \
			health=$$(docker inspect --format='{{.State.Health.Status}}' $$container 2>/dev/null || echo "none"); \
			if [ "$$status" = "running" ]; then \
				if [ "$$health" = "healthy" ]; then \
					echo "✅ $$container: running (healthy)"; \
				elif [ "$$health" = "unhealthy" ]; then \
					echo "⚠️  $$container: running (unhealthy)"; \
				elif [ "$$health" = "starting" ]; then \
					echo "🔄 $$container: running (starting)"; \
				else \
					echo "🟡 $$container: running (no health check)"; \
				fi; \
			else \
				echo "❌ $$container: $$status"; \
			fi; \
		done; \
	fi
	@echo ""
	@echo "🌐 Port Status:"
	@OS=$(uname); \
	ports="5432:PostgreSQL 27017:MongoDB 6378:Redis 6333:Qdrant 9092:Kafka 9200:Elasticsearch 5601:Kibana 8500:Consul 8081:pgAdmin 8082:MongoExpress 8083:RedisCommander 8084:KafkaUI 8080:AuthService 8000:APIGateway 8001:LogService 3000:Frontend"; \
	for port_info in $ports; do \
		port=$(echo $port_info | cut -d: -f1); \
		service=$(echo $port_info | cut -d: -f2); \
		port_in_use=false; \
		if [ "$OS" = "Darwin" ]; then \
			if lsof -i :$port > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		elif [ "$OS" = "Linux" ]; then \
			if ss -tuln | grep ":$port " > /dev/null 2>&1; then \
				port_in_use=true; \
			fi; \
		fi; \
		if [ "$port_in_use" = "true" ]; then \
			echo "✅ Port $port ($service): in use"; \
		else \
			echo "❌ Port $port ($service): free"; \
		fi; \
	done

# Print service information
print-service-info:
	@echo "📋 ERP Suite Service Information:"
	@echo "================================="
	@echo "  Auth Service:        http://localhost:8080/api/v1/ (HTTP) | gRPC: localhost:50051"
	@echo "  API Gateway:         http://localhost:8000/api/v1/ (Django)"
	@echo "  Log Service:         http://localhost:8001/api/v1/ (HTTP) | gRPC: localhost:50052"
	@echo "  Frontend:            http://localhost:3000 (Next.js)"
	@echo ""
	@$(MAKE) print-info

# Expose services to network (use with caution)
expose-dev:
	@echo "🌐 Exposing development services to network..."
	@echo "⚠️  Warning: This will make services accessible from other devices"
	@read -p "Enter host IP (default: 0.0.0.0): " ip; \
	if [ -n "$$ip" ]; then \
		HOST_IP=$$ip; \
	fi; \
	echo "📝 Updating environment configuration..."; \
	sed -i.bak \
		-e "s/localhost:/$${HOST_IP}:/g" \
		-e "s/127.0.0.1:/$${HOST_IP}:/g" \
		.env; \
	echo "✅ Services will be exposed on $${HOST_IP}"
	@echo "🔄 Restart required: run 'make restart' to apply changes"

print-dev:
	echo "🌐 Network Access:"; \
	echo "📋 API Layer:"; \
	echo "  gRPC Registry:       http://localhost:8500"; \
	echo ""; \
	echo "📋 Infrastructure Services:"; \
	echo "  PostgreSQL:          localhost:5432 (postgres/postgres)"; \
	echo "  MongoDB:             localhost:27017 (root/password)"; \
	echo "  Redis:               localhost:6378 (password: redispassword)"; \
	echo "  Qdrant:              http://localhost:6333"; \
	echo "  Kafka:               localhost:9092"; \
	echo "  Elasticsearch:       http://localhost:9200 (elastic/password)"; \
	echo ""; \
	echo "📋 Development Tools:"; \
	echo "  pgAdmin:             http://localhost:8081 (admin@erp.com/admin)"; \
	echo "  Mongo Express:       http://localhost:8082 (admin/pass)"; \
	echo "  Redis Commander:     http://localhost:8083"; \
	echo "  Kafka UI:            http://localhost:8084"; \
	echo "  Kibana:              http://localhost:5601 (elastic/password)"; \
	echo "📋 Application Services:"; \
	echo "  Auth Service:        http://localhost:8080/api/v1/ (HTTP) | gRPC: $$network_ip:50051"; \
	echo "  API Gateway:         http://localhost:8000/api/v1/ (Django)"; \
	echo "  Log Service:         http://localhost:8001/api/v1/ (HTTP) | gRPC: $$network_ip:50052"; \
	echo "  Frontend:            http://localhost:3000 (Next.js)";

print-info:
	@network_ip=$$($(MAKE) -s _get-local-ip); \
	echo ""; \
	echo "🌐 Network Access:"; \
	echo "  Local Network IP: $$network_ip"; \
	echo "  Replace 'localhost' with '$$network_ip' to access from other devices"; \
	echo ""; \
	echo "📋 API Layer:"; \
	echo "  gRPC Registry:       http://$$network_ip:8500"; \
	echo ""; \
	echo "📋 Infrastructure Services:"; \
	echo "  PostgreSQL:          $$network_ip:5432 (postgres/postgres)"; \
	echo "  MongoDB:             $$network_ip:27017 (root/password)"; \
	echo "  Redis:               $$network_ip:6378 (password: redispassword)"; \
	echo "  Qdrant:              http://$$network_ip:6333"; \
	echo "  Kafka:               $$network_ip:9092"; \
	echo "  Elasticsearch:       http://$$network_ip:9200 (elastic/password)"; \
	echo ""; \
	echo "📋 Development Tools:"; \
	echo "  pgAdmin:             http://$$network_ip:8081 (admin@erp.com/admin)"; \
	echo "  Mongo Express:       http://$$network_ip:8082 (admin/pass)"; \
	echo "  Redis Commander:     http://$$network_ip:8083"; \
	echo "  Kafka UI:            http://$$network_ip:8084"; \
	echo "  Kibana:              http://$$network_ip:5601 (elastic/password)"; \
	echo "📋 Application Services:"; \
	echo "  Auth Service:        http://$$network_ip:8080/api/v1/ (HTTP) | gRPC: $$network_ip:50051"; \
	echo "  API Gateway:         http://$$network_ip:8000/api/v1/ (Django)"; \
	echo "  Log Service:         http://$$network_ip:8001/api/v1/ (HTTP) | gRPC: $$network_ip:50052"; \
	echo "  Frontend:            http://$$network_ip:3000 (Next.js)";

# ============================================================================
# REVERSE PROXY COMMANDS
# ============================================================================

# Generate SSL certificates (self-signed for development)
generate-ssl:
	@echo "🔐 Generating self-signed SSL certificates..."
	@mkdir -p nginx/ssl
	@openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout nginx/ssl/key.pem \
		-out nginx/ssl/cert.pem \
		-subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
	@echo "✅ SSL certificates generated!"
	@echo "⚠️  These are self-signed certificates for development only"

# Enable HTTPS (requires SSL certificates)
enable-https:
	@echo "🔐 Enabling HTTPS..."
	@if [ ! -f nginx/ssl/cert.pem ] || [ ! -f nginx/ssl/key.pem ]; then \
		echo "❌ SSL certificates not found. Run 'make generate-ssl' first"; \
		exit 1; \
	fi
	@echo "📝 Updating NGINX configuration for HTTPS..."
	@sed -i 's/# server {/server {/g' nginx/nginx.conf
	@sed -i 's/#     listen 443 ssl http2;/    listen 443 ssl http2;/g' nginx/nginx.conf
	@sed -i 's/#     server_name your-domain.com;/    server_name _;/g' nginx/nginx.conf
	@sed -i 's/#     ssl_certificate \/etc\/nginx\/ssl\/cert.pem;/    ssl_certificate \/etc\/nginx\/ssl\/cert.pem;/g' nginx/nginx.conf
	@sed -i 's/#     ssl_certificate_key \/etc\/nginx\/ssl\/key.pem;/    ssl_certificate_key \/etc\/nginx\/ssl\/key.pem;/g' nginx/nginx.conf
	@echo "✅ HTTPS enabled! Restart with 'make restart'"

# Print proxy information
print-proxy-info:
	@network_ip=$$($(MAKE) -s _get-local-ip); \
	echo ""; \
	echo "🌐 Reverse Proxy Information"; \
	echo "============================"; \
	echo "  Server IP: $$network_ip"; \
	echo "  HTTP Port: 80"; \
	echo "  HTTPS Port: 443 (if enabled)"; \
	echo ""; \
	echo "📋 Public Endpoints:"; \
	echo "  Frontend:           http://$$network_ip/"; \
	echo "  Django API:         http://$$network_ip/api/v1/"; \
	echo "  Auth Service:       http://$$network_ip/auth/"; \
	echo "  Log Service:        http://$$network_ip/logs/"; \
	echo ""; \
	echo "🔧 Admin Tools (admin/admin123):"; \
	echo "  pgAdmin:            http://$$network_ip/admin/pgadmin/"; \
	echo "  Mongo Express:      http://$$network_ip/admin/mongo/"; \
	echo "  Redis Commander:    http://$$network_ip/admin/redis/"; \
	echo "  Kafka UI:           http://$$network_ip/admin/kafka/"; \
	echo "  Kibana:             http://$$network_ip/admin/kibana/"; \
	echo "  Consul:             http://$$network_ip/admin/consul/"; \
	echo ""; \
	echo "💡 Health Check: http://$$network_ip/health"

# ============================================================================
# MACOS OPTIMIZED COMMANDS
# ============================================================================

# Switch to macOS-optimized configuration
macos-config:
	@echo "🍎 Switching to macOS-optimized configuration..."
	@if [ -f .env.macos ]; then \
		cp .env.macos .env; \
		echo "✅ Switched to macOS-optimized .env configuration"; \
		echo ""; \
		echo "📋 Optimizations applied:"; \
		echo "  • Reduced Elasticsearch memory (256MB instead of 512MB)"; \
		echo "  • Optimized Kafka memory usage"; \
		echo "  • Reduced health check frequency"; \
		echo "  • Disabled optional services by default"; \
		echo "  • Set log level to 'warn' to reduce I/O"; \
		echo ""; \
		echo "🚀 Now run: make start-dev"; \
	else \
		echo "❌ .env.macos file not found!"; \
		exit 1; \
	fi

# Check macOS Docker performance
macos-performance:
	@echo "🍎 macOS Docker Performance Check:"
	@echo ""
	@echo "📊 Docker Desktop Status:"
	@docker system df
	@echo ""
	@echo "💾 Memory Usage:"
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
	@echo ""
	@echo "💡 Performance Tips:"
	@echo "  • Increase Docker Desktop memory allocation to 4GB+"
	@echo "  • Enable 'Use gRPC FUSE for file sharing' in Docker Desktop"
	@echo "  • Use 'make macos-config && make start-dev' for best performance"
	@echo "  • Consider using Colima instead of Docker Desktop"

# Clean up and optimize for macOS
macos-clean:
	@echo "🍎 Cleaning up Docker for macOS optimization..."
	@docker compose -f docker-compose.yml down -v --remove-orphans
	@docker system prune -f --volumes
	@docker builder prune -f
	@echo "✅ macOS Docker cleanup complete!"
	@echo ""
	@echo "💡 Next steps:"
	@echo "  • Restart Docker Desktop"
	@echo "  • Run 'make start-dev' for optimized startup"
