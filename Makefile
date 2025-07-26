# ERP Suite Infrastructure Makefile

.PHONY: help dev-up dev-down db-up monitoring-up tools-up logs clean k8s-deploy k8s-clean k8s-ports
.PHONY: dev-infrastructure dev-full-stack dev-full-stack-down status health backup restore setup restart
.PHONY: kafka-topics init-dbs generate-config generate-all-configs generate-go-config validate-config show-config-info

# Variables
BACKUP_DIR ?= backups/$(shell date +%Y%m%d_%H%M%S)
MODULE ?=
ENV ?= development

# Default target
help:
	@echo "ERP Suite Infrastructure Commands:"
	@echo ""
	@echo "Docker Compose Commands:"
	@echo "  dev-up               - Start all infrastructure services"
	@echo "  dev-infrastructure   - Start infrastructure services (recommended)"
	@echo "  dev-down             - Stop all services"
	@echo "  dev-full-stack       - Start infrastructure + core application services"
	@echo "  dev-full-stack-down  - Stop full development stack"
	@echo "  db-up                - Start database services only"
	@echo "  monitoring-up        - Start monitoring stack only"
	@echo "  tools-up             - Start development tools only"
	@echo "  logs                 - Show logs from all services"
	@echo "  clean                - Clean up all containers and volumes"
	@echo ""
	@echo "Kubernetes Commands:"
	@echo "  k8s-deploy           - Deploy to Kubernetes"
	@echo "  k8s-clean            - Clean up Kubernetes resources"
	@echo "  k8s-ports            - Port forward services"
	@echo ""
	@echo "Configuration Commands:"
	@echo "  generate-config      - Generate config for module (MODULE=name ENV=env)"
	@echo "  generate-all-configs - Generate configs for all modules"
	@echo "  generate-go-config   - Generate Go config loader (MODULE=name)"
	@echo "  validate-config      - Validate configuration files"
	@echo "  show-config-info     - Show available modules and environments"
	@echo ""
	@echo "Utility Commands:"
	@echo "  status               - Show service status"
	@echo "  health               - Check service health"
	@echo "  backup               - Backup all data"
	@echo "  restore              - Restore from backup (BACKUP_DIR=path)"
	@echo "  setup                - Full setup for first time"
	@echo "  restart              - Stop and start infrastructure (one command)"

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
	@mkdir -p backups
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

# Start all development services
dev-up: prepare-environment
	@echo "🚀 Starting ERP Suite infrastructure..."
	@echo "Checking Docker Compose configuration..."
	@docker compose config > /dev/null || { echo "❌ Docker Compose configuration is invalid!"; exit 1; }
	@echo "Starting containers..."
	@docker compose up -d || { echo "❌ Failed to start containers!"; exit 1; }
	@echo "✅ All services started!"
	@$(MAKE) print-service-urls

# Print service URLs
print-service-urls:
	@echo ""
	@echo "📋 Service URLs:"
	@echo "  PostgreSQL:      localhost:5432"
	@echo "  MongoDB:         localhost:27017"
	@echo "  Redis:           localhost:6379"
	@echo "  Qdrant:          http://localhost:6333"
	@echo "  Kafka:           localhost:9092"
	@echo "  Elasticsearch:   http://localhost:9200"
	@echo "  Prometheus:      http://localhost:9090"
	@echo "  Grafana:         http://localhost:3000 (admin/admin)"
	@echo "  Jaeger:          http://localhost:16686"
	@echo "  pgAdmin:         http://localhost:8081 (admin@erp.com/admin)"
	@echo "  Mongo Express:   http://localhost:8082 (admin/pass)"
	@echo "  Redis Commander: http://localhost:8083"
	@echo "  Kafka UI:        http://localhost:8084"
	@echo "  Kibana:          http://localhost:5601 (elastic/password)"
	@echo "  WebSocket:       http://localhost:3001"

# Stop all services
dev-down:
	@echo "🛑 Stopping ERP Suite infrastructure..."
	@docker compose down --remove-orphans || docker compose down
	@echo "✅ All services stopped!"

# Start database services only
db-up: prepare-environment
	@echo "🗄️ Starting database services..."
	@docker compose up -d postgres mongodb redis qdrant
	@echo "✅ Database services started!"

# Start monitoring stack only
monitoring-up: prepare-environment
	@echo "📊 Starting monitoring services..."
	@docker compose up -d prometheus grafana jaeger
	@echo "✅ Monitoring services started!"

# Start development tools only
tools-up: prepare-environment
	@echo "🔧 Starting development tools..."
	@docker compose up -d pgadmin mongo-express redis-commander kafka-ui
	@echo "✅ Development tools started!"

# Show logs from all services
logs:
	@docker compose logs -f

# Show logs from specific service (usage: make logs-postgres)
logs-%:
	@docker compose logs -f $*

# Show service status
status:
	@echo "📊 Service Status:"
	@docker compose ps

# Check service health
health:
	@echo "🏥 ERP Suite Health Check:"
	@echo ""
	@echo "📊 Service Status:"
	@docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "🔍 Quick Connectivity Tests:"
	@echo -n "PostgreSQL: "
	@docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@echo -n "Redis: "
	@docker compose exec -T redis redis-cli --no-auth-warning -a redispassword ping > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@echo -n "MongoDB: "
	@docker compose exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@echo -n "Kafka: "
	@docker compose exec -T kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"
	@echo -n "Elasticsearch: "
	@curl -s -u elastic:password http://localhost:9200/_cluster/health > /dev/null 2>&1 && echo "✅ Ready" || echo "❌ Not Ready"

# Clean up all containers and volumes
clean:
	@echo "🧹 Cleaning up..."
	@docker compose down -v --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup complete!"

# ============================================================================
# KUBERNETES COMMANDS
# ============================================================================

# Deploy to Kubernetes
k8s-deploy:
	@echo "☸️ Deploying to Kubernetes..."
	@if [ ! -f k8s/namespace.yaml ]; then echo "❌ k8s/namespace.yaml not found!"; exit 1; fi
	@kubectl apply -f k8s/namespace.yaml
	@kubectl apply -f k8s/
	@echo "✅ Deployed to Kubernetes!"

# Clean up Kubernetes resources
k8s-clean:
	@echo "🧹 Cleaning up Kubernetes resources..."
	@kubectl delete -f k8s/ --ignore-not-found=true
	@echo "✅ Kubernetes cleanup complete!"

# Port forward services
k8s-ports:
	@echo "🔌 Port forwarding commands:"
	@echo "Run these commands in separate terminals:"
	@echo "kubectl port-forward svc/postgres 5432:5432 -n erp-system"
	@echo "kubectl port-forward svc/mongodb 27017:27017 -n erp-system"
	@echo "kubectl port-forward svc/redis 6379:6379 -n erp-system"
	@echo "kubectl port-forward svc/qdrant 6333:6333 -n erp-system"
	@echo "kubectl port-forward svc/kafka 9092:9092 -n erp-system"
	@echo "kubectl port-forward svc/elasticsearch 9200:9200 -n erp-system"
	@echo "kubectl port-forward svc/prometheus 9090:9090 -n erp-system"
	@echo "kubectl port-forward svc/grafana 3000:3000 -n erp-system"
	@echo "kubectl port-forward svc/jaeger 16686:16686 -n erp-system"

# ============================================================================
# UTILITY COMMANDS
# ============================================================================

# Backup all data
backup:
	@echo "💾 Creating backup in $(BACKUP_DIR)..."
	@mkdir -p $(BACKUP_DIR)
	@echo "Backing up PostgreSQL..."
	@docker compose exec -T postgres pg_dumpall -U postgres > $(BACKUP_DIR)/postgres.sql || echo "⚠️ PostgreSQL backup failed"
	@echo "Backing up MongoDB..."
	@docker compose exec -T mongodb mongodump --out /tmp/backup > /dev/null 2>&1 || echo "⚠️ MongoDB backup failed"
	@docker cp $$(docker compose ps -q mongodb):/tmp/backup $(BACKUP_DIR)/mongodb 2>/dev/null || echo "⚠️ MongoDB backup copy failed"
	@echo "✅ Backup created in $(BACKUP_DIR)/"

# Restore from backup
restore:
	@if [ -z "$(BACKUP_DIR)" ] || [ ! -d "$(BACKUP_DIR)" ]; then \
		echo "❌ BACKUP_DIR not specified or doesn't exist. Usage: make restore BACKUP_DIR=backups/20231201_120000"; \
		exit 1; \
	fi
	@echo "📥 Restoring from $(BACKUP_DIR)..."
	@if [ -f "$(BACKUP_DIR)/postgres.sql" ]; then \
		echo "Restoring PostgreSQL..."; \
		docker compose exec -T postgres psql -U postgres < $(BACKUP_DIR)/postgres.sql; \
	fi
	@if [ -d "$(BACKUP_DIR)/mongodb" ]; then \
		echo "Restoring MongoDB..."; \
		docker cp $(BACKUP_DIR)/mongodb $$(docker compose ps -q mongodb):/tmp/restore; \
		docker compose exec -T mongodb mongorestore /tmp/restore; \
	fi
	@echo "✅ Restore complete!"

# Wait for services to be ready
wait-for-services:
	@echo "⏳ Waiting for services to be ready..."
	@timeout=60; \
	while [ $$timeout -gt 0 ]; do \
		if docker compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then \
			echo "✅ PostgreSQL is ready"; \
			break; \
		fi; \
		echo "Waiting for PostgreSQL... ($$timeout seconds remaining)"; \
		sleep 5; \
		timeout=$$((timeout - 5)); \
	done
	@sleep 5

# Create Kafka topics
kafka-topics: wait-for-services
	@echo "📝 Creating Kafka topics..."
	@topics="auth-events user-events business-events system-events"; \
	for topic in $$topics; do \
		echo "Creating topic: $$topic"; \
		docker compose exec -T kafka kafka-topics --create --topic $$topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 > /dev/null 2>&1 || echo "Topic $$topic already exists"; \
	done
	@echo "✅ Kafka topics initialized!"

# Initialize databases
init-dbs: wait-for-services
	@echo "🔧 Initializing databases..."
	@databases="erp_auth erp_core erp_crm erp_hrm erp_finance erp_inventory erp_projects"; \
	for db in $$databases; do \
		echo "Creating database: $$db"; \
		docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE $$db;" > /dev/null 2>&1 || echo "Database $$db already exists"; \
	done
	@echo "✅ Databases initialized!"

# Full setup (for first time)
setup: dev-up kafka-topics init-dbs
	@echo "🎉 Full setup complete!"

# Restart infrastructure (stop and start in one command)
restart: dev-down
	@sleep 3
	@$(MAKE) dev-infrastructure
	@echo "🎉 Infrastructure restarted successfully!"

# ============================================================================
# FULL STACK DEVELOPMENT COMMANDS
# ============================================================================

# Check if application repositories exist
check-app-repos:
	@missing_repos=""; \
	for repo in "auth-module" "erp-django-core-app" "erp-core-frontend"; do \
		if [ ! -d "../$$repo" ]; then \
			missing_repos="$$missing_repos ../$$repo"; \
		fi; \
	done; \
	if [ -n "$$missing_repos" ]; then \
		echo "❌ Missing required application repositories:$$missing_repos"; \
		echo ""; \
		echo "For now, use 'make dev-infrastructure' to start just the infrastructure services."; \
		exit 1; \
	fi

# Start infrastructure services only (recommended for development)
dev-infrastructure: prepare-environment
	@echo "🚀 Starting ERP Suite infrastructure services..."
	@echo "This includes all databases, message brokers, monitoring, and development tools"
	@echo "Checking Docker Compose configuration..."
	@docker compose config > /dev/null || { echo "❌ Docker Compose configuration is invalid!"; exit 1; }
	@echo "Starting containers..."
	@docker compose up -d || { echo "❌ Failed to start containers!"; exit 1; }
	@$(MAKE) kafka-topics
	@$(MAKE) init-dbs
	@echo "✅ Infrastructure services started!"
	@$(MAKE) print-infrastructure-info

# Print infrastructure information
print-infrastructure-info:
	@echo ""
	@echo "📋 Infrastructure Services:"
	@echo "  PostgreSQL:          localhost:5432 (postgres/postgres)"
	@echo "  MongoDB:             localhost:27017 (root/password)"
	@echo "  Redis:               localhost:6379 (password: redispassword)"
	@echo "  Qdrant:              http://localhost:6333"
	@echo "  Kafka:               localhost:9092"
	@echo "  Elasticsearch:       http://localhost:9200 (elastic/password)"
	@echo "  Prometheus:          http://localhost:9090"
	@echo "  Grafana:             http://localhost:3000 (admin/admin)"
	@echo "  Jaeger:              http://localhost:16686"
	@echo "  WebSocket:           http://localhost:3001"
	@echo ""
	@echo "📋 Development Tools:"
	@echo "  pgAdmin:             http://localhost:8081 (admin@erp.com/admin)"
	@echo "  Mongo Express:       http://localhost:8082 (admin/pass)"
	@echo "  Redis Commander:     http://localhost:8083"
	@echo "  Kafka UI:            http://localhost:8084"
	@echo "  Kibana:              http://localhost:5601 (elastic/password)"
	@echo ""
	@echo "🎯 Infrastructure ready! You can now:"
	@echo "   1. Start developing your microservices"
	@echo "   2. Connect to databases and message brokers"
	@echo "   3. Use development tools for debugging"

# Start full stack (infrastructure + application services) - requires app repos
dev-full-stack: prepare-environment check-app-repos
	@echo "🚀 Starting ERP Suite full development stack..."
	@echo "This includes infrastructure + core application services"
	@if [ ! -f docker-compose.full-stack.yml ]; then \
		echo "❌ docker-compose.full-stack.yml not found!"; \
		exit 1; \
	fi
	@docker compose -f docker-compose.full-stack.yml up -d
	@$(MAKE) kafka-topics
	@$(MAKE) init-dbs
	@echo "✅ Full development stack started!"
	@echo ""
	@echo "📋 Core Services:"
	@echo "  🔐 Auth Service:     http://localhost:8080 (gRPC: 50051)"
	@echo "  🚪 Core Gateway:     http://localhost:8000"
	@echo "  ⚛️  Frontend:         http://localhost:3000"
	@$(MAKE) print-infrastructure-info
	@echo "🎯 Full stack ready for development!"

# Stop full development stack
dev-full-stack-down:
	@echo "🛑 Stopping ERP Suite full development stack..."
	@if [ -f docker-compose.full-stack.yml ]; then \
		docker compose -f docker-compose.full-stack.yml down --remove-orphans; \
	else \
		echo "❌ docker-compose.full-stack.yml not found!"; \
	fi
	@echo "✅ Full development stack stopped!"

# ============================================================================
# SHARED CONFIGURATION COMMANDS
# ============================================================================

# Generate shared configuration for a module
generate-config:
	@echo "🔧 Generating shared configuration..."
	@if [ -z "$(MODULE)" ]; then \
		echo "❌ MODULE parameter required. Usage: make generate-config MODULE=auth ENV=development"; \
		exit 1; \
	fi
	@if [ ! -d shared-config ]; then \
		echo "❌ shared-config directory not found!"; \
		exit 1; \
	fi
	@echo "Generating config for module: $(MODULE), environment: $(ENV)"
	@cd shared-config && python3 generators/generate-env.py --module=$(MODULE) --env=$(ENV)
	@echo "✅ Configuration generated: shared-config/.env.$(MODULE).$(ENV)"

# Generate configurations for all common modules
generate-all-configs:
	@echo "🔧 Generating configurations for all modules..."
	@modules="auth crm hrm finance inventory projects ai notification frontend"; \
	for module in $$modules; do \
		$(MAKE) generate-config MODULE=$$module ENV=$(ENV) || echo "⚠️ Failed to generate config for $$module"; \
	done
	@echo "✅ All configurations generated!"

# Generate Go configuration loader
generate-go-config:
	@echo "🔧 Generating Go configuration loader for module: $(MODULE)"
	@if [ -z "$(MODULE)" ]; then \
		echo "❌ MODULE parameter required. Usage: make generate-go-config MODULE=auth"; \
		exit 1; \
	fi
	@if [ ! -d shared-config ]; then \
		echo "❌ shared-config directory not found!"; \
		exit 1; \
	fi
	@cd shared-config && go run generators/generate-env.go --module=$(MODULE) --env=$(ENV)
	@echo "✅ Go configuration generated for $(MODULE)"

# Validate configuration files
validate-config:
	@echo "🔍 Validating configuration files..."
	@if [ ! -d shared-config ]; then \
		echo "❌ shared-config directory not found!"; \
		exit 1; \
	fi
	@if [ -f shared-config/config.yaml ]; then \
		cd shared-config && python3 -c "import yaml; yaml.safe_load(open('config.yaml'))" && echo "✅ config.yaml is valid"; \
	else \
		echo "⚠️ config.yaml not found"; \
	fi
	@if [ -d shared-config/environments ]; then \
		cd shared-config && find environments -name "*.yaml" -exec python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" {} \; && echo "✅ All environment files are valid"; \
	else \
		echo "⚠️ environments directory not found"; \
	fi
	@echo "✅ Configuration validation complete!"

# Show available modules and environments
show-config-info:
	@if [ ! -d shared-config ] || [ ! -f shared-config/config.yaml ]; then \
		echo "❌ shared-config/config.yaml not found!"; \
		exit 1; \
	fi
	@echo "📋 Available Modules:"
	@cd shared-config && python3 -c "import yaml; config=yaml.safe_load(open('config.yaml')); [print(f'  - {m[\"name\"]}: {m[\"description\"]}') for m in config.get('modules', [])]"
	@echo ""
	@echo "📋 Available Environments:"
	@cd shared-config && python3 -c "import yaml; config=yaml.safe_load(open('config.yaml')); [print(f'  - {e[\"name\"]}: {e[\"description\"]}') for e in config.get('environments', [])]"