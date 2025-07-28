# ERP Suite Infrastructure

![Python](https://img.shields.io/badge/Python_3.11+-3776AB?style=flat&logo=python&logoColor=white)
![Django](https://img.shields.io/badge/Django_4.2+-092E20?style=flat&logo=django&logoColor=white)
![Django REST](https://img.shields.io/badge/Django_REST_Framework-ff1709?style=flat&logo=django&logoColor=white)
![Go](https://img.shields.io/badge/Go_1.21+-00ADD8?style=flat&logo=go&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)
![Chi Router](https://img.shields.io/badge/Chi_Router-00ADD8?style=flat&logo=go&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-623CE4?style=flat&logo=terraform&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm&logoColor=white)

### Frontend & UI
![Next.js](https://img.shields.io/badge/Next.js-000000?style=flat&logo=next.js&logoColor=white)
![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=flat&logo=typescript&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=flat&logo=react&logoColor=61DAFB)
![Tailwind CSS](https://img.shields.io/badge/Tailwind_CSS-38B2AC?style=flat&logo=tailwind-css&logoColor=white)
![Zustand](https://img.shields.io/badge/Zustand-FF6B35?style=flat&logo=react&logoColor=white)
![React Query](https://img.shields.io/badge/React_Query-FF4154?style=flat&logo=react-query&logoColor=white)

### Databases & Storage
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat&logo=postgresql&logoColor=white)
![Graphql](https://img.shields.io/badge/GraphQL-007ACC?style=flat&logo=graphQL&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-69A31?style=flat&logo=mongodb&logoColor)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=flat&logo=redis&logoColor=white)
![WebSocket](https://img.shields.io/badge/WebSocket-FF6B6B?style=flat&logo=WebSocket&logoColor=white)
![GRPC](https://img.shields.io/badge/grpc-FF6B6B?style=flat&logo=grpc&logoColor=white)
![Qdrant](https://img.shields.io/badge/Qdrant-FF6B6B?style=flat&logo=qdrant&logoColor=white)

### Payment & SaaS
![Stripe](https://img.shields.io/badge/Stripe-008CDD?style=flat&logo=stripe&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-000000?style=flat&logo=json-web-tokens&logoColor=white)

Complete infrastructure setup for the ERP Suite development environment with sequential startup, dependency management, and cross-platform compatibility.

## Quick Start

### Prerequisites
- Docker Desktop (Windows/macOS) or Docker Engine (Linux)
- Docker Compose v2.0+
- Make utility

### Essential Commands

```bash
# Start development infrastructure (recommended)
make start-dev

# Start all services
make start

# Stop all services and free ports
make stop

# Quick status check
make status

# Reload specific service with dependencies
make reload SERVICE=postgres

# Show logs from all services
make logs

# Show logs from specific service
make logs APP=postgres

# Check service status and health
make services
```

## Infrastructure Services

### Core Services
- **PostgreSQL 15+** - Primary relational database
- **MongoDB 6+** - Document database for analytics
- **Redis 7+** - Cache, sessions, and message queues
- **Kafka** - Event streaming (KRaft mode, no Zookeeper)
- **Elasticsearch 8+** - Full-text search
- **Qdrant** - Vector database for AI features

### API Layer
- **GraphQL Gateway** - Unified API gateway
- **gRPC Registry (Consul)** - Service discovery
- **WebSocket Server** - Real-time communication

### Development Tools
- **pgAdmin** - PostgreSQL management
- **Mongo Express** - MongoDB interface
- **Redis Commander** - Redis browser
- **Kafka UI** - Kafka management
- **Kibana** - Elasticsearch visualization

## Service Endpoints

### API Layer
| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| GraphQL Gateway | 4000 | http://localhost:4000/graphql | - |
| GraphQL Playground | 4000 | http://localhost:4000/playground | - |
| gRPC Registry (Consul) | 8500 | http://localhost:8500 | - |
| WebSocket Server | 3001 | http://localhost:3001 | - |

### Infrastructure Services
| Service | Port | URL/Connection | Credentials |
|---------|------|----------------|-------------|
| PostgreSQL | 5432 | localhost:5432 | postgres/postgres |
| MongoDB | 27017 | localhost:27017 | root/password |
| Redis | 6379 | localhost:6379 | password: redispassword |
| Qdrant (HTTP) | 6333 | http://localhost:6333 | - |
| Qdrant (gRPC) | 6334 | grpc://localhost:6334 | - |
| Kafka | 9092 | localhost:9092 | - |
| Elasticsearch | 9200 | http://localhost:9200 | No auth required |

### Development Tools
| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| pgAdmin | 8081 | http://localhost:8081 | admin@erp.com/admin |
| Mongo Express | 8082 | http://localhost:8082 | admin/pass |
| Redis Commander | 8083 | http://localhost:8083 | - |
| Kafka UI | 8084 | http://localhost:8084 | - |
| Kibana | 5601 | http://localhost:5601 | No auth required |

## Sequential Startup System

The `start-dev` command uses an 8-phase sequential startup to reduce resource load and ensure proper dependency management:

### Startup Phases
1. **Phase 1**: Core Databases (PostgreSQL, Redis)
2. **Phase 2**: Document & Vector Stores (MongoDB, Qdrant)
3. **Phase 3**: Message Broker (Kafka)
4. **Phase 4**: Search Engine (Elasticsearch)
5. **Phase 5**: API Layer (GraphQL Gateway, gRPC Registry)
6. **Phase 6**: WebSocket Server
7. **Phase 7**: Logging (Kibana)
8. **Phase 8**: Development Tools

### Benefits
- Reduced resource contention during startup
- Proper dependency ordering ensures stability
- Better error isolation and debugging
- Optimized for macOS Docker performance
- Automatic health checks between phases

## Cross-Platform Compatibility

### Supported Operating Systems

#### Windows
- Git Bash/WSL: Full compatibility
- PowerShell: Works with Docker Desktop
- Port checking: Uses `netstat`

#### Linux
- Ubuntu/Debian/CentOS/Arch: Full compatibility
- Port checking: Multiple fallbacks (`lsof`, `netstat`, `ss`)

#### macOS
- Terminal/Zsh: Full compatibility with optimizations
- Port checking: Uses `lsof`
- Special optimizations: Resource limits and sequential startup

### Cross-Platform Features
- Automatic OS detection and command adaptation
- Universal Docker commands work identically across platforms
- Smart port conflict detection with OS-specific tools
- Platform-specific troubleshooting guidance

## macOS Optimizations

### Special Commands for macOS
```bash
# Switch to macOS-optimized configuration
make macos-config

# Check Docker performance on macOS
make macos-performance

# Clean up and optimize Docker for macOS
make macos-clean
```

### macOS Performance Tips
- Increase Docker Desktop memory allocation to 4GB+
- Enable 'Use gRPC FUSE for file sharing' in Docker Desktop
- Use `make start-dev` for optimized sequential startup
- Consider using Colima instead of Docker Desktop

## Environment Configuration

### Automatic Environment Setup
```bash
# No manual setup needed - everything is automatic
make start-dev
```

### Available Environment Files

| File | Purpose | Usage |
|------|---------|-------|
| `.env.example` | Default configuration template | Base template for all environments |
| `.env.macos` | macOS-optimized settings | Use `make macos-config` to activate |
| `.env` | Active configuration | Created automatically or manually |

### Key Environment Variables

```bash
# Database Configuration
POSTGRES_PASSWORD=your_secure_password
MONGODB_ROOT_PASSWORD=your_mongo_password
REDIS_PASSWORD=your_redis_password

# Service Ports
POSTGRES_PORT=5432
MONGODB_PORT=27017
REDIS_PORT=6379
KAFKA_PORT=9092
ELASTICSEARCH_PORT=9200

# API Layer Ports
GRAPHQL_GATEWAY_PORT=4000
CONSUL_PORT=8500
WEBSOCKET_PORT=3001

# Development Tools Ports
PGADMIN_PORT=8081
MONGO_EXPRESS_PORT=8082
REDIS_COMMANDER_PORT=8083
KAFKA_UI_PORT=8084
KIBANA_PORT=5601
```

## Service Management

### Service Reload

```bash
# Basic syntax
make reload SERVICE=service-name

# Examples
make reload SERVICE=postgres
make reload SERVICE=redis
make reload SERVICE=elasticsearch
```

### Smart Dependency Management

The `reload` command automatically restarts dependent services:

| Service | Dependents |
|---------|------------|
| postgres | GraphQL Gateway, pgAdmin |
| redis | GraphQL Gateway, WebSocket Server, Redis Commander |
| mongodb | Mongo Express |
| elasticsearch | Kibana |
| kafka | Kafka UI |

### Available Service Names

| Service Name | Description |
|--------------|-------------|
| `postgres` | PostgreSQL database |
| `redis` | Redis cache |
| `mongodb` | MongoDB database |
| `kafka` | Kafka message broker |
| `elasticsearch` | Elasticsearch search |
| `qdrant` | Qdrant vector database |
| `graphql-gateway` | GraphQL API gateway |
| `grpc-registry` | gRPC service registry |
| `websocket-server` | WebSocket server |
| `kibana` | Kibana UI |
| `pgadmin` | pgAdmin UI |
| `mongo-express` | Mongo Express UI |
| `redis-commander` | Redis Commander UI |
| `kafka-ui` | Kafka UI |

## Service Creation

### Quick Service Creation

Create new microservices with the automated service generator:

```bash
# Basic syntax
./create-service.sh <port> <service-name> <language>

# Examples
./create-service.sh 8082 crm go          # Go CRM service
./create-service.sh 8083 hrm python      # Python HRM service  
./create-service.sh 8084 inventory node  # Node.js Inventory service
```

### Supported Languages & Frameworks

| Language | Framework | Database | Cache | Generated File |
|----------|-----------|----------|-------|----------------|
| Go | Gin | lib/pq (PostgreSQL) | go-redis | `main.go` |
| Python | FastAPI | psycopg2 (PostgreSQL) | redis-py | `main.py` |
| Node.js | Express | pg (PostgreSQL) | redis | `server.js` |

### Database Configuration Options

When creating a service, choose from:

1. **Use existing database** - Uses `erp_servicename` database
2. **Create new database** - Creates a new `erp_servicename` database  
3. **Use shared database** - Uses the shared `erp_core` database

### Generated Service Structure

```
erp-servicename-service/
├── main.go|main.py|server.js    # Main application file
├── Dockerfile                   # Container configuration
├── .env                        # Environment variables
├── README.md                   # Service documentation
├── go.mod|requirements.txt|package.json  # Dependencies
└── .git/                       # Git repository
```

### Auto-Generated API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check endpoint |
| `GET` | `/api/v1/servicename` | List all items |
| `POST` | `/api/v1/servicename` | Create new item |
| `GET` | `/api/v1/servicename/:id` | Get item by ID |
| `PUT` | `/api/v1/servicename/:id` | Update item |
| `DELETE` | `/api/v1/servicename/:id` | Delete item |

### Service Creation Workflow

#### Step 1: Create the Service
```bash
cd erp-suit-infrastructure
./create-service.sh 8085 finance go
```

#### Step 2: Start Infrastructure
```bash
make start-dev
make status
```

#### Step 3: Start Your Service
```bash
docker compose up -d finance-service
make logs APP=finance-service
```

#### Step 4: Test Your Service
```bash
curl http://localhost:8085/health
curl http://localhost:8085/api/v1/finance
```

## Architecture Overview

```mermaid
graph TB
    subgraph "API Layer"
        GQL[GraphQL Gateway<br/>Port 4000]
        CONSUL[Service Registry<br/>Consul - Port 8500]
        WS[WebSocket Server<br/>Port 3001]
    end
    
    subgraph "Core Infrastructure"
        PG[(PostgreSQL<br/>Port 5432)]
        MONGO[(MongoDB<br/>Port 27017)]
        REDIS[(Redis<br/>Port 6379)]
        KAFKA[Kafka<br/>Port 9092]
        ES[(Elasticsearch<br/>Port 9200)]
        QDRANT[(Qdrant<br/>Port 6333)]
    end
    
    subgraph "Development Tools"
        PGADMIN[pgAdmin<br/>Port 8081]
        MONGOEXP[Mongo Express<br/>Port 8082]
        REDISCMD[Redis Commander<br/>Port 8083]
        KAFKAUI[Kafka UI<br/>Port 8084]
        KIBANA[Kibana<br/>Port 5601]
    end
    
    GQL --> PG
    GQL --> REDIS
    WS --> REDIS
    KIBANA --> ES
    PGADMIN --> PG
    MONGOEXP --> MONGO
    REDISCMD --> REDIS
    KAFKAUI --> KAFKA
```

## Development Workflow

### For New Module Development
```bash
# 1. Start infrastructure
make start-dev

# 2. Create your service
./create-service.sh 8085 finance go

# 3. Start your service
docker compose up -d finance-service

# 4. Check all services are running
make services

# 5. Use development tools:
# - pgAdmin: http://localhost:8081
# - GraphQL Playground: http://localhost:4000/playground
```

### Service Connection Examples

#### Database Connections
```bash
# PostgreSQL
psql -h localhost -p 5432 -U postgres -d erp_system

# MongoDB
mongosh mongodb://root:password@localhost:27017/erp_analytics

# Redis
redis-cli -h localhost -p 6379 -a redispassword
```

#### API Testing
```bash
# GraphQL Health Check
curl http://localhost:4000/health

# Elasticsearch Health
curl http://localhost:9200/_cluster/health

# WebSocket Health Check
curl http://localhost:3001/health

# Consul Services
curl http://localhost:8500/v1/catalog/services
```

## Troubleshooting

### Common Issues and Solutions

#### Port Conflicts
The system automatically checks for port conflicts before starting:
```bash
# Manual port conflict check
make check-ports

# Enhanced stop command handles this automatically
make stop

# For aggressive cleanup
make force-stop

# Quick status check
make status
```

#### Service Health Issues
```bash
# Check service status
make services

# View service logs
make logs APP=service-name

# Restart problematic service
make reload SERVICE=service-name
```

#### Kafka Topic Creation Issues
If Kafka topic creation gets stuck:
```bash
# Skip topic creation and start manually later
make start

# Check Kafka status
make services
make logs APP=kafka

# Create topics manually when Kafka is ready
make kafka-topics

# Or restart Kafka if needed
make reload SERVICE=kafka
```

#### macOS Performance Issues
```bash
# Switch to macOS optimized configuration
make macos-config

# Then start with optimizations
make start-dev

# Check Docker performance
make macos-performance

# Clean up if needed
make macos-clean
```

### Docker Issues
```bash
# Clean up Docker resources
make macos-clean              # macOS-specific cleanup
docker system prune -f       # General cleanup
docker compose down -v       # Stop and remove volumes
```

### Environment Issues
```bash
# Reset environment configuration
rm .env
make start-dev  # Will recreate .env from .env.example

# Check current configuration
cat .env

# Switch to macOS optimized config
make macos-config
```

## Summary

This infrastructure provides a complete, production-ready development environment with:

- Sequential startup with dependency management
- Cross-platform compatibility (Windows, macOS, Linux)
- Simplified commands (`start-dev`, `start`, `stop`, `reload`, `logs`, `services`)
- Automatic environment setup
- Smart service reloading with dependency management
- Comprehensive development tools
- Automated service creation
- Event-driven architecture ready for microservices

### Get Started

```bash
# Basic setup
make start-dev

# For macOS users
make macos-config
make start-dev

# Quick commands reference
make start-dev    # Start with sequential startup (recommended)
make status       # Quick status check
make stop         # Enhanced stop with port cleanup
make services     # Detailed health check
```

Your complete ERP infrastructure is ready for development with optimized performance, cross-platform compatibility, and intelligent dependency management.