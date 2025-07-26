#!/bin/bash

# ERP Suite Infrastructure Setup Script
# This script sets up the complete development infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service to be ready
wait_for_service() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service to be ready on port $port..."
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost $port 2>/dev/null; then
            print_success "$service is ready!"
            return 0
        fi
        
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service failed to start within expected time"
    return 1
}

# Main setup function
main() {
    echo "🚀 ERP Suite Infrastructure Setup"
    echo "=================================="
    echo ""
    
    # Check prerequisites
    print_status "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command_exists docker-compose; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    if ! command_exists make; then
        print_error "Make is not installed. Please install Make first."
        exit 1
    fi
    
    print_success "All prerequisites are installed!"
    echo ""
    
    # Create necessary directories and files
    print_status "Setting up configuration files..."
    
    mkdir -p config/grafana/provisioning/datasources
    mkdir -p config/grafana/provisioning/dashboards
    mkdir -p config/grafana/dashboards
    mkdir -p websocket-server
    
    # Copy example files if they don't exist
    [ ! -f config/prometheus.yml ] && cp config/prometheus.yml.example config/prometheus.yml
    [ ! -f config/pgadmin/servers.json ] && cp config/pgadmin/servers.json.example config/pgadmin/servers.json
    [ ! -f websocket-server/package.json ] && cp websocket-server/package.json.example websocket-server/package.json
    [ ! -f websocket-server/server.js ] && cp websocket-server/server.js.example websocket-server/server.js
    
    print_success "Configuration files ready!"
    echo ""
    
    # Start infrastructure
    print_status "Starting ERP Suite infrastructure..."
    docker-compose up -d
    echo ""
    
    # Wait for core services
    print_status "Waiting for core services to be ready..."
    wait_for_service "PostgreSQL" 5432
    wait_for_service "MongoDB" 27017
    wait_for_service "Redis" 6379
    wait_for_service "Kafka" 9092
    echo ""
    
    # Initialize databases
    print_status "Initializing databases..."
    sleep 10  # Give services more time to fully initialize
    
    # Create Kafka topics
    print_status "Creating Kafka topics..."
    docker-compose exec -T kafka kafka-topics --create --topic auth-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
    docker-compose exec -T kafka kafka-topics --create --topic user-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
    docker-compose exec -T kafka kafka-topics --create --topic business-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
    docker-compose exec -T kafka kafka-topics --create --topic system-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
    docker-compose exec -T kafka kafka-topics --create --topic ai-events --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists
    
    print_success "Kafka topics created!"
    echo ""
    
    # Wait for additional services
    wait_for_service "Elasticsearch" 9200
    wait_for_service "Prometheus" 9090
    wait_for_service "Grafana" 3000
    wait_for_service "Qdrant" 6333
    wait_for_service "WebSocket Server" 3001
    echo ""
    
    # Display service information
    print_success "🎉 ERP Suite Infrastructure is ready!"
    echo ""
    echo "📋 Service URLs:"
    echo "  PostgreSQL:      localhost:5432 (postgres/postgres)"
    echo "  MongoDB:         localhost:27017 (root/password)"
    echo "  Redis:           localhost:6379 (password: redispassword)"
    echo "  Qdrant:          http://localhost:6333"
    echo "  Kafka:           localhost:9092"
    echo "  Elasticsearch:   http://localhost:9200 (elastic/password)"
    echo "  Prometheus:      http://localhost:9090"
    echo "  Grafana:         http://localhost:3000 (admin/admin)"
    echo "  Jaeger:          http://localhost:16686"
    echo "  pgAdmin:         http://localhost:8081 (admin@erp.com/admin)"
    echo "  Mongo Express:   http://localhost:8082 (admin/pass)"
    echo "  Redis Commander: http://localhost:8083"
    echo "  Kafka UI:        http://localhost:8084"
    echo "  Kibana:          http://localhost:5601 (elastic/password)"
    echo "  WebSocket:       http://localhost:3001"
    echo ""
    echo "🔧 Management Commands:"
    echo "  make dev-up      - Start all services"
    echo "  make dev-down    - Stop all services"
    echo "  make logs        - View logs"
    echo "  make status      - Check service status"
    echo "  make health      - Health check"
    echo "  make clean       - Clean up everything"
    echo ""
    echo "📚 Next Steps:"
    echo "  1. Check service status: make status"
    echo "  2. View connection config: cat config/connections.yaml"
    echo "  3. Start developing your ERP modules!"
    echo ""
}

# Handle script interruption
trap 'print_error "Setup interrupted"; exit 1' INT

# Run main function
main "$@"