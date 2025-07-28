# ERP Suite Infrastructure Makefile

.PHONY: help start-dev start stop reload logs services

# Variables
SERVICE ?=
APP ?=

# Default target
help:
	@echo "ERP Suite Infrastructure - Simplified Commands"
	@echo ""
	@echo "Essential Commands:"
	@echo "  start-dev            - Start development infrastructure with sequential startup"
	@echo "  start                - Start all services"
	@echo "  stop                 - Stop all services and free ports"
	@echo "  force-stop           - Force stop with aggressive cleanup (kills ALL Docker containers)"
	@echo "  reload SERVICE=name  - Reload specific service (e.g., make reload SERVICE=postgres)"
	@echo "  logs                 - Show logs from all services"
	@echo "  logs APP=name        - Show logs from specific app (e.g., make logs APP=postgres)"
	@echo "  services             - Show running services status"
	@echo "  status               - Quick status check of all services"
	@echo ""
	@echo "macOS Optimization Commands:"
	@echo "  macos-config         - Switch to macOS-optimized configuration"
	@echo "  macos-performance    - Check Docker performance on macOS"
	@echo "  macos-clean          - Clean up and optimize Docker for macOS"

# ============================================================================
# DOCKER COMPOSE COMMANDS
# ============================================================================

# Prepare required directories and files
prepare-environment:
	@echo "📁 Preparing environment..."
	@mkdir -p config/grafana/provisioning/datasources
	@mkdir -p config/grafana/provisioning/dashboards
	@mkdir -p config/grafana/dashboards
	@mkdir -p websocket-server
	@mkdir -p graphql-gateway/src
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
	@if [ ! -f websocket-server/package.json ] && [ -f websocket-server/package.json.example ]; then \
		cp websocket-server/package.json.example websocket-server/package.json; \
		echo "✅ Created websocket-server/package.json from example"; \
	fi
	@if [ ! -f websocket-server/server.js ] && [ -f websocket-server/server.js.example ]; then \
		cp websocket-server/server.js.example websocket-server/server.js; \
		echo "✅ Created websocket-server/server.js from example"; \
	fi
	@if [ ! -f websocket-server/.env ] && [ -f websocket-server/.env.example ]; then \
		cp websocket-server/.env.example websocket-server/.env; \
		echo "✅ Created websocket-server/.env from example"; \
	fi
	@if [ ! -f graphql-gateway/.env ] && [ -f graphql-gateway/.env.example ]; then \
		cp graphql-gateway/.env.example graphql-gateway/.env; \
		echo "✅ Created graphql-gateway/.env from example"; \
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
	@OS=$$($(MAKE) detect-os); \
	ports="5432:PostgreSQL 27017:MongoDB 6379:Redis 6333:Qdrant 9092:Kafka 9200:Elasticsearch 5601:Kibana 4000:GraphQL 8500:Consul 3001:WebSocket 8081:pgAdmin 8082:MongoExpress 8083:RedisCommander 8084:KafkaUI 8080:AuthService 8000:APIGateway 8001:LogService 3000:Frontend"; \
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
	@# Set different timeouts based on service type
	@if [ "$(SERVICE)" = "kafka" ] || [ "$(SERVICE)" = "elasticsearch" ]; then \
		timeout=300; \
	elif [ "$(SERVICE)" = "kibana" ] || [ "$(SERVICE)" = "mongodb" ]; then \
		timeout=240; \
	else \
		timeout=180; \
	fi; \
	initial_timeout=$$timeout; \
	while [ $$timeout -gt 0 ]; do \
		if docker compose ps $(SERVICE) | grep -q "healthy\|Up"; then \
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
		docker compose logs $(SERVICE) | tail -30; \
		echo ""; \
		echo "💡 Troubleshooting tips:"; \
		echo "  • Check if Docker has enough memory allocated (4GB+ recommended)"; \
		echo "  • Try: make logs APP=$(SERVICE) for full logs"; \
		echo "  • Try: make reload SERVICE=$(SERVICE) to restart the service"; \
		exit 1; \
	fi

# Initialize databases
init-dbs:
	@echo "🔧 Initializing databases..."
	@databases="erp_auth erp_core erp_crm erp_hrm erp_finance erp_inventory erp_projects"; \
	for db in $$databases; do \
		echo "Creating database: $$db"; \
		docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE $$db;" > /dev/null 2>&1 || echo "Database $$db already exists"; \
	done
	@echo "✅ Databases initialized!"

# Create Kafka topics with enhanced timeout and retry logic
# kafka-topics:
# 	@echo "📝 Creating Kafka topics..."
# 	@echo "⏳ Waiting for Kafka to be fully ready for topic operations..."
# 	@sleep 15
# 	@echo "🔍 Testing Kafka connectivity first..."
# 	@if timeout 30 docker compose exec -T kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then \
# 		echo "✅ Kafka is ready for topic operations"; \
# 		topics="auth-events user-events business-events system-events"; \
# 		for topic in $$topics; do \
# 			echo "Creating topic: $$topic"; \
# 			timeout 20 docker compose exec -T kafka kafka-topics --create --topic $$topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 --if-not-exists > /dev/null 2>&1 && echo "✅ Topic $$topic created" || echo "⚠️ Topic $$topic already exists or creation failed"; \
# 		done; \
# 		echo "✅ Kafka topics initialization complete!"; \
# 	else \
# 		echo "⚠️ Kafka not ready after waiting, skipping topic creation"; \
# 		echo "💡 You can create topics later with: make kafka-topics"; \
# 		echo "✅ Continuing with infrastructure startup..."; \
# 	fi

# ============================================================================
# ESSENTIAL COMMANDS
# ============================================================================

# Start development infrastructure with sequential startup
start-dev: prepare-environment check-ports
	@echo "🚀 Starting ERP Suite infrastructure sequentially..."
	@echo "This reduces resource load by starting services in dependency order"
	@echo ""
	@echo "📋 Startup Sequence:"
	@echo "  Phase 1: Core Databases (PostgreSQL, Redis)"
	@echo "  Phase 2: Document & Vector Stores (MongoDB, Qdrant)"
	@echo "  Phase 3: Message Broker (Kafka)"
	@echo "  Phase 4: Search Engine (Elasticsearch)"
	@echo "  Phase 5: API Layer (GraphQL Gateway, gRPC Registry)"
	@echo "  Phase 6: WebSocket Server"
	@echo "  Phase 7: Logging (Kibana)"
	@echo "  Phase 8: Development Tools"
	@echo "  Phase 9: Core Application Services"
	@echo ""
	@echo "🔄 Phase 1: Starting core databases..."
	@docker compose up -d postgres redis
	@$(MAKE) wait-for-service SERVICE=postgres
	@$(MAKE) wait-for-service SERVICE=redis
	@echo "✅ Phase 1 complete: Core databases ready"
	@sleep 2
	@echo "🔄 Phase 2: Starting document and vector stores..."
	@docker compose up -d mongodb qdrant
	@$(MAKE) wait-for-service SERVICE=mongodb
	@$(MAKE) wait-for-service SERVICE=qdrant
	@echo "✅ Phase 2 complete: Document and vector stores ready"
	@sleep 2
	@echo "🔄 Phase 3: Starting message broker..."
	@docker compose up -d kafka
	@$(MAKE) wait-for-service SERVICE=kafka
	@echo "✅ Phase 3 complete: Message broker ready"
	@sleep 2
	@echo "🔄 Phase 4: Starting search engine..."
	@docker compose up -d elasticsearch
	@$(MAKE) wait-for-service SERVICE=elasticsearch
	@echo "✅ Phase 4 complete: Search engine ready"
	@sleep 2
	@echo "🔄 Phase 5: Starting API layer..."
	@docker compose up -d grpc-registry
	@$(MAKE) wait-for-service SERVICE=grpc-registry
	@docker compose up -d graphql-gateway
	@$(MAKE) wait-for-service SERVICE=graphql-gateway
	@echo "✅ Phase 5 complete: API layer ready"
	@sleep 2
	@echo "🔄 Phase 6: Starting WebSocket server..."
	@docker compose up -d websocket-server
	@$(MAKE) wait-for-service SERVICE=websocket-server
	@echo "✅ Phase 6 complete: WebSocket server ready"
	@sleep 2
	@echo "🔄 Phase 7: Starting logging services..."
	@docker compose up -d kibana
	@echo "✅ Phase 7 complete: Logging services ready"
	@sleep 2
	@echo "🔄 Phase 8: Starting development tools..."
	@docker compose --profile dev-tools up -d
	@echo "✅ Phase 8 complete: Development tools ready"

	@echo "🔄 Phase 9: Starting core application services..."

	@echo "🔄 Configuring Database..."
	@$(MAKE) init-dbs

	@echo "🔄 Phase 9a: Starting Auth Service..."
	@docker compose --profile full-stack up -d auth-service
	@$(MAKE) wait-for-service SERVICE=auth-service

	@echo "🔄 Phase 9b: Starting API Gateway..."
	@docker compose --profile full-stack up -d api-gateway
	@$(MAKE) wait-for-service SERVICE=api-gateway

	@echo "🔄 Phase 9c: Starting Log Service..."
	@docker compose --profile full-stack up -d log-service
	@$(MAKE) wait-for-service SERVICE=log-service

	@echo "🔄 Phase 10: Starting Frontend..."
	@docker compose --profile full-stack up -d erp-frontend
	@$(MAKE) wait-for-service SERVICE=erp-frontend

	@echo "✅ Phase 9-10 complete: All core application services up and running..."

	@echo ""

	@echo "✅ ERP Infrastructure online"
	@$(MAKE) print-info
# Add later 	@$(MAKE) kafka-topics 
# Start all services
start: prepare-environment
	@echo "🚀 Starting ERP Suite infrastructure..."
	@echo "Checking Docker Compose configuration..."
	@docker compose --profile infrastructure config > /dev/null || { echo "❌ Docker Compose configuration is invalid!"; exit 1; }
	@echo "Starting containers..."
	@docker compose --profile infrastructure --profile api-layer --profile logging --profile dev-tools up -d || { echo "❌ Failed to start containers!"; exit 1; }
	@$(MAKE) kafka-topics
	@$(MAKE) init-dbs
	@echo "✅ All services started!"
	@$(MAKE) print-info

# Stop all services and free ports
stop:
	@echo "🛑 Stopping ERP Suite infrastructure..."
	@echo "📋 Stopping all Docker Compose services..."
	@docker compose down --remove-orphans --volumes --timeout 30 2>/dev/null || true
	@echo "🔍 Killing any remaining ERP Suite containers..."
	@docker ps -a --filter "name=erp-suite" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true
	@echo "🧹 Cleaning up orphaned containers..."
	@docker container prune -f 2>/dev/null || true
	@echo "🌐 Cleaning up unused networks..."
	@docker network prune -f 2>/dev/null || true
	@echo "🔍 Checking for processes still using ERP ports..."
	@OS=$$(uname); \
	ports="5432 27017 6379 6333 9092 9200 5601 4000 8500 3001 8081 8082 8083 8084 8080 8000 8001 3000"; \
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
	ports="5432 27017 6379 6333 9092 9200 5601 4000 8500 3001 8081 8082 8083 8084 8080 8000 8001 3000"; \
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
	@echo "🛑 ERP Suite infrastructure offlione and ports freed!"

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

# Reload specific service
reload:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ SERVICE parameter required. Usage: make reload SERVICE=postgres"; \
		exit 1; \
	fi
	@echo "🔄 Reloading $(SERVICE) and checking dependents..."
	@docker compose restart $(SERVICE)
	@$(MAKE) wait-for-service SERVICE=$(SERVICE)
	@echo "✅ $(SERVICE) reloaded successfully"
	@if [ "$(SERVICE)" = "postgres" ]; then \
		echo "🔄 Restarting services that depend on PostgreSQL..."; \
		docker compose restart graphql-gateway pgadmin; \
	elif [ "$(SERVICE)" = "redis" ]; then \
		echo "🔄 Restarting services that depend on Redis..."; \
		docker compose restart graphql-gateway websocket-server redis-commander; \
	elif [ "$(SERVICE)" = "mongodb" ]; then \
		echo "🔄 Restarting services that depend on MongoDB..."; \
		docker compose restart mongo-express; \
	elif [ "$(SERVICE)" = "elasticsearch" ]; then \
		echo "🔄 Restarting services that depend on Elasticsearch..."; \
		docker compose restart kibana; \
	elif [ "$(SERVICE)" = "kafka" ]; then \
		echo "🔄 Restarting services that depend on Kafka..."; \
		docker compose restart kafka-ui; \
	fi
	@echo "✅ Dependent services restarted"

# Show logs from all services or specific app
logs:
	@if [ -n "$(APP)" ]; then \
		echo "📋 Showing logs for $(APP)..."; \
		docker compose logs -f $(APP); \
	else \
		echo "📋 Showing logs for all services..."; \
		docker compose logs -f; \
	fi

# Show running services status
services:
	@echo "📊 Service Status:"
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || docker compose ps
	@echo ""
	@echo "🔍 Quick Health Check:"
	@printf "PostgreSQL: "
	@docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "Redis: "
	@docker compose exec -T redis redis-cli --no-auth-warning -a redispassword ping > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "MongoDB: "
	@docker compose exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "Kafka: "
	@docker compose exec -T kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@printf "Elasticsearch: "
	@curl -s http://localhost:9200/_cluster/health > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"

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
	@OS=$$(uname); \
	ports="5432:PostgreSQL 27017:MongoDB 6379:Redis 6333:Qdrant 9092:Kafka 9200:Elasticsearch 5601:Kibana 4000:GraphQL 8500:Consul 3001:WebSocket 8080:AuthService 8000:APIGateway 8001:LogService 3000:Frontend"; \
	for port_info in $$ports; do \
		port=$$(echo $$port_info | cut -d: -f1); \
		service=$$(echo $$port_info | cut -d: -f2); \
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
			echo "✅ Port $$port ($$service): in use"; \
		else \
			echo "❌ Port $$port ($$service): free"; \
		fi; \
	done

# Print service information
print-info:
	@echo ""
	@echo "📋 API Layer:"
	@echo "  GraphQL Gateway:     http://localhost:4000/graphql"
	@echo "  GraphQL Playground:  http://localhost:4000/playground"
	@echo "  gRPC Registry:       http://localhost:8500"
	@echo ""
	@echo "📋 Infrastructure Services:"
	@echo "  PostgreSQL:          localhost:5432 (postgres/postgres)"
	@echo "  MongoDB:             localhost:27017 (root/password)"
	@echo "  Redis:               localhost:6379 (password: redispassword)"
	@echo "  Qdrant:              http://localhost:6333"
	@echo "  Kafka:               localhost:9092"
	@echo "  Elasticsearch:       http://localhost:9200 (elastic/password)"
	@echo "  WebSocket:           http://localhost:3001"
	@echo ""
	@echo "📋 Development Tools:"
	@echo "  pgAdmin:             http://localhost:8081 (admin@erp.com/admin)"
	@echo "  Mongo Express:       http://localhost:8082 (admin/pass)"
	@echo "  Redis Commander:     http://localhost:8083"
	@echo "  Kafka UI:            http://localhost:8084"
	@echo "  Kibana:              http://localhost:5601 (elastic/password)"

	@echo "📋 Application Services:"
	@echo "  Auth Service:        http://localhost:8080/api/v1/ (HTTP) | gRPC: localhost:50051"
	@echo "  API Gateway:         http://localhost:8000/api/v1/ (Django)"
	@echo "  Log Service:         http://localhost:8001/api/v1/ (HTTP) | gRPC: localhost:50052"
	@echo "  Frontend:            http://localhost:3000 (Next.js)"

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
	@docker compose down -v --remove-orphans
	@docker system prune -f --volumes
	@docker builder prune -f
	@echo "✅ macOS Docker cleanup complete!"
	@echo ""
	@echo "💡 Next steps:"
	@echo "  • Restart Docker Desktop"
	@echo "  • Run 'make start-dev' for optimized startup"