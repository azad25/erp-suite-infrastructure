# ERP Suite Infrastructure

![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white)
![Redis](https://img.shields.io/badge/redis-%23DD0031.svg?style=for-the-badge&logo=redis&logoColor=white)
![Apache Kafka](https://img.shields.io/badge/Apache%20Kafka-000?style=for-the-badge&logo=apachekafka)
![ElasticSearch](https://img.shields.io/badge/-ElasticSearch-005571?style=for-the-badge&logo=elasticsearch)

Complete infrastructure setup for the ERP Suite development environment with **sequential startup**, **dependency management**, and **cross-platform compatibility**.

## 🚀 Quick Start

### Prerequisites
- **Docker Desktop** (Windows/macOS) or **Docker Engine** (Linux)
- **Docker Compose** v2.0+
- **Make** utility

### Essential Commands

```bash
# Start development infrastructure (recommended)
make start-dev

# Start all services (faster startup)
make start

# Stop all services
make stop

# Reload specific service with dependencies
make reload SERVICE=postgres

# Show logs from all services
make logs

# Show logs from specific service
make logs APP=postgres

# Check service status and health
make services
```

## 🏗️ Infrastructure Services

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

## 📋 Verified Service URLs & Endpoints

### **🚪 API Layer**
| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| GraphQL Gateway | 4000 | http://localhost:4000/graphql | - |
| GraphQL Playground | 4000 | http://localhost:4000/playground | - |
| gRPC Registry (Consul) | 8500 | http://localhost:8500 | - |
| WebSocket Server | 3001 | http://localhost:3001 | - |

### **🏗️ Infrastructure Services**
| Service | Port | URL/Connection | Credentials |
|---------|------|----------------|-------------|
| PostgreSQL | 5432 | localhost:5432 | postgres/postgres |
| MongoDB | 27017 | localhost:27017 | root/password |
| Redis | 6379 | localhost:6379 | password: redispassword |
| Qdrant (HTTP) | 6333 | http://localhost:6333 | - |
| Qdrant (gRPC) | 6334 | grpc://localhost:6334 | - |
| **Kafka** | **9092** | localhost:9092 | - |
| Elasticsearch | 9200 | http://localhost:9200 | elastic/password |

### **🔧 Development Tools**
| Service | Port | URL | Credentials |
|---------|------|-----|-------------|
| pgAdmin | 8081 | http://localhost:8081 | admin@erp.com/admin |
| Mongo Express | 8082 | http://localhost:8082 | admin/pass |
| Redis Commander | 8083 | http://localhost:8083 | - |
| Kafka UI | 8084 | http://localhost:8084 | - |
| Kibana | 5601 | http://localhost:5601 | elastic/password |

### **⚡ Application Services (Full Stack)**
| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| Auth Service (HTTP) | 8080 | http://localhost:8080 | REST API |
| Auth Service (gRPC) | 50051 | grpc://localhost:50051 | gRPC API |
| Django Core | 8000 | http://localhost:8000 | Main API Gateway |
| Next.js Frontend | 3000 | http://localhost:3000 | Web Application |

## � Seequential Startup System

The `start-dev` command uses an **8-phase sequential startup** to reduce resource load and ensure proper dependency management:

### Phase-by-Phase Startup
1. **Phase 1**: Core Databases (PostgreSQL, Redis)
2. **Phase 2**: Document & Vector Stores (MongoDB, Qdrant)
3. **Phase 3**: Message Broker (Kafka)
4. **Phase 4**: Search Engine (Elasticsearch)
5. **Phase 5**: API Layer (GraphQL Gateway, gRPC Registry)
6. **Phase 6**: WebSocket Server
7. **Phase 7**: Logging (Kibana)
8. **Phase 8**: Development Tools

### Benefits
- ✅ **Reduced resource contention** during startup
- ✅ **Proper dependency ordering** ensures stability
- ✅ **Better error isolation** and debugging
- ✅ **Optimized for macOS** Docker performance
- ✅ **Automatic health checks** between phases

## 🌍 Cross-Platform Compatibility

### Supported Operating Systems

#### 🪟 **Windows**
- **Git Bash/WSL**: ✅ Full compatibility
- **PowerShell**: ✅ Works with Docker Desktop
- **Port checking**: Uses `netstat` (native Windows command)

#### 🐧 **Linux**
- **Ubuntu/Debian/CentOS/Arch**: ✅ Full compatibility
- **Port checking**: Multiple fallbacks (`lsof`, `netstat`, `ss`)

#### 🍎 **macOS**
- **Terminal/Zsh**: ✅ Full compatibility + optimizations
- **Port checking**: Uses `lsof` (native macOS command)
- **Special optimizations**: Resource limits and sequential startup

### Cross-Platform Features
- **Automatic OS detection** and command adaptation
- **Universal Docker commands** work identically across platforms
- **Smart port conflict detection** with OS-specific tools
- **Platform-specific troubleshooting** guidance

## 🍎 macOS Optimizations

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

## 🔧 Environment Setup & Configuration

### **Automatic Environment Setup (Recommended)**
```bash
# No manual setup needed - everything is automatic!
make start-dev
```

### **Available Environment Setup Commands**

#### **1. Basic Environment Setup (Automatic)**
```bash
# This is called automatically by start-dev and start
make start-dev  # Includes prepare-environment
make start      # Includes prepare-environment
```

#### **2. Manual Environment Setup**
```bash
# Manually run environment preparation
make prepare-environment
```

#### **3. macOS Optimized Environment**
```bash
# Switch to macOS-optimized configuration
make macos-config

# This switches from .env.example to .env.macos with:
# - Reduced Elasticsearch memory (256MB instead of 512MB)
# - Optimized Kafka memory usage
# - Reduced health check frequency
# - Disabled optional services by default
# - Set log level to 'warn' to reduce I/O
```

### **Available Environment Files**

| File | Purpose | Usage |
|------|---------|-------|
| `.env.example` | Default configuration template | Base template for all environments |
| `.env.macos` | macOS-optimized settings | Use `make macos-config` to activate |
| `.env` | Active configuration | Created automatically or manually |

### **What Gets Set Up Automatically**

When you run `make start-dev` or `make start`, the system creates:

#### **Main Configuration:**
- ✅ `.env` (from `.env.example`)

#### **Service-Specific Configurations:**
- ✅ `websocket-server/.env` (from example)
- ✅ `graphql-gateway/.env` (from example)
- ✅ `config/prometheus.yml` (from example)
- ✅ `config/pgadmin/servers.json` (from example)

#### **Required Directories:**
- ✅ `config/grafana/provisioning/datasources`
- ✅ `config/grafana/provisioning/dashboards`
- ✅ `websocket-server`
- ✅ `graphql-gateway/src`
- ✅ `backups`

### **Key Environment Variables You Can Customize**

```bash
# Database Configuration
POSTGRES_PASSWORD=your_secure_password
MONGODB_ROOT_PASSWORD=your_mongo_password
REDIS_PASSWORD=your_redis_password
ELASTIC_PASSWORD=your_elastic_password

# Service Ports (if you have conflicts)
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

## 🔄 Service Management

### **How to Reload a Service**

```bash
# Basic syntax
make reload SERVICE=service-name

# Examples:
make reload SERVICE=postgres
make reload SERVICE=redis
make reload SERVICE=kafka
make reload SERVICE=mongodb
make reload SERVICE=elasticsearch
make reload SERVICE=graphql-gateway
make reload SERVICE=websocket-server
```

### **Smart Dependency Management**

The `reload` command automatically restarts dependent services:

#### **PostgreSQL Reload:**
```bash
make reload SERVICE=postgres
```
**Also restarts:** GraphQL Gateway, pgAdmin

#### **Redis Reload:**
```bash
make reload SERVICE=redis
```
**Also restarts:** GraphQL Gateway, WebSocket Server, Redis Commander

#### **MongoDB Reload:**
```bash
make reload SERVICE=mongodb
```
**Also restarts:** Mongo Express

#### **Elasticsearch Reload:**
```bash
make reload SERVICE=elasticsearch
```
**Also restarts:** Kibana

#### **Kafka Reload:**
```bash
make reload SERVICE=kafka
```
**Also restarts:** Kafka UI

### **Available Service Names for Reload**

| Service Name | Description | Dependents |
|--------------|-------------|------------|
| `postgres` | PostgreSQL database | GraphQL Gateway, pgAdmin |
| `redis` | Redis cache | GraphQL Gateway, WebSocket Server, Redis Commander |
| `mongodb` | MongoDB database | Mongo Express |
| `kafka` | Kafka message broker | Kafka UI |
| `elasticsearch` | Elasticsearch search | Kibana |
| `qdrant` | Qdrant vector database | - |
| `graphql-gateway` | GraphQL API gateway | - |
| `grpc-registry` | gRPC service registry | - |
| `websocket-server` | WebSocket server | - |
| `kibana` | Kibana UI | - |
| `pgadmin` | pgAdmin UI | - |
| `mongo-express` | Mongo Express UI | - |
| `redis-commander` | Redis Commander UI | - |
| `kafka-ui` | Kafka UI | - |

### Logging and Monitoring
```bash
# View all service logs
make logs

# View specific service logs
make logs APP=postgres
make logs APP=graphql-gateway
make logs APP=kafka

# Check service status and health
make services
```

## 🏗️ Architecture Overview

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

## 🚀 Development Workflow

### For New Module Development
```bash
# 1. Start infrastructure
make start-dev

# 2. Check all services are running
make services

# 3. Connect your module to:
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379  
# - Kafka: localhost:9092
# - MongoDB: localhost:27017
# - Elasticsearch: localhost:9200

# 4. Use development tools:
# - pgAdmin: http://localhost:8081
# - GraphQL Playground: http://localhost:4000/playground
```

### For Infrastructure Development
```bash
# Start specific service groups
make start                    # All services
make stop                     # Stop all services

# Monitor and debug
make logs                     # All logs
make logs APP=postgres        # Specific service
make services                 # Status check

# Reload services
make reload SERVICE=redis     # Restart with dependencies
```

### **Service Connection Examples**

#### **Database Connections:**
```bash
# PostgreSQL
psql -h localhost -p 5432 -U postgres -d erp_system

# MongoDB
mongosh mongodb://root:password@localhost:27017/erp_analytics

# Redis
redis-cli -h localhost -p 6379 -a redispassword
```

#### **API Testing:**
```bash
# GraphQL Health Check
curl http://localhost:4000/health

# Elasticsearch Health
curl -u elastic:password http://localhost:9200/_cluster/health

# Consul Services
curl http://localhost:8500/v1/catalog/services
```

## 🔍 Troubleshooting

### **Common Issues and Solutions**

#### **1. Port Conflicts**
The system automatically checks for port conflicts before starting:
```bash
# Manual port conflict check
make check-ports

# If conflicts found, kill processes:
# Windows: netstat -ano | findstr :PORT
# macOS/Linux: sudo lsof -ti:PORT | xargs kill -9
```

#### **2. Service Health Issues**
```bash
# Check service status
make services

# View service logs
make logs APP=service-name

# Restart problematic service
make reload SERVICE=service-name
```

#### **3. Kafka Topic Creation Taking Too Long**
If Kafka topic creation gets stuck:
```bash
# Skip topic creation and start manually later
make start  # Instead of start-dev

# Check Kafka status
make services
make logs APP=kafka

# Create topics manually when Kafka is ready
make kafka-topics

# Or restart Kafka if needed
make reload SERVICE=kafka
```

#### **4. Docker Dependency Issues**
If you see errors like "service depends on undefined service":
- The infrastructure uses **sequential startup** instead of strict Docker dependencies
- Services connect via environment variables and Docker networking
- Dependencies are managed through the 8-phase startup process

#### **5. macOS Performance Issues**
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

### **Docker Issues**
```bash
# Clean up Docker resources
make macos-clean              # macOS-specific cleanup
docker system prune -f       # General cleanup
docker compose down -v       # Stop and remove volumes
```

### **Environment Issues**
```bash
# Reset environment configuration
rm .env
make start-dev  # Will recreate .env from .env.example

# Check current configuration
cat .env

# Switch to macOS optimized config
make macos-config
```

## 📚 Additional Resources

### **Recommended Setup Workflows**

#### **For General Development:**
```bash
# 1. Basic setup (automatic)
make start-dev
```

#### **For macOS Users (Recommended):**
```bash
# 1. Switch to macOS optimized config
make macos-config

# 2. Start with optimizations
make start-dev
```

#### **For Custom Configuration:**
```bash
# 1. Copy example to create your own
cp .env.example .env

# 2. Edit the configuration
vim .env

# 3. Start infrastructure
make start-dev
```

### **Pro Tips**

#### **Quick Start (No Manual Setup Needed):**
```bash
# Just run this - everything is automatic!
make start-dev
```

#### **For macOS Performance:**
```bash
# Optimize for macOS first, then start
make macos-config
make start-dev
```

#### **Check Your Configuration:**
```bash
# See what environment is active
cat .env

# Check if all required files exist
ls -la .env*
ls -la websocket-server/.env
ls -la graphql-gateway/.env
```

#### **Reset Environment:**
```bash
# Remove current config and start fresh
rm .env
make start-dev  # Will recreate .env from .env.example
```

### Configuration Management
- Environment variables in `.env` file
- Service-specific configuration in `config/` directory
- Docker Compose profiles for flexible service management

### Monitoring and Observability
- Service health checks with automatic restarts
- Centralized logging via Docker Compose
- Development tools for database and service management

### Development Support
- Hot reload support for development
- Persistent volumes for data retention
- Network isolation via Docker networks
- Resource limits for optimal performance

---

## 🎯 Summary

This infrastructure provides a **complete, production-ready development environment** with:

- ✅ **Sequential startup** with dependency management
- ✅ **Cross-platform compatibility** (Windows, macOS, Linux)
- ✅ **Simplified commands** (`start-dev`, `start`, `stop`, `reload`, `logs`, `services`)
- ✅ **Automatic environment setup** - No manual configuration needed
- ✅ **Smart service reloading** with dependency management
- ✅ **Verified service URLs** and endpoints
- ✅ **macOS optimizations** for Docker Desktop performance
- ✅ **Comprehensive troubleshooting** guidance
- ✅ **Development tools** for database and service management
- ✅ **Event-driven architecture** ready for microservices

### **Get started in seconds:**
```bash
make start-dev
```

### **For macOS users:**
```bash
make macos-config
make start-dev
```

That's it! Your complete ERP infrastructure is ready for development with optimized performance, cross-platform compatibility, and intelligent dependency management. 🚀