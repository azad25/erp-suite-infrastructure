# ERP Suite Infrastructure

Complete infrastructure setup for the ERP Suite development environment with sequential startup, dependency management, reverse proxy support, automatic network detection, and cross-platform compatibility.

## 🚀 Quick Start

### Option 1: Complete Setup (Recommended)
```bash
# Complete startup with all preparations
make start

# This will:
# 1. Prepare environment files
# 2. Check for port conflicts
# 3. Automatically detect network IP
# 4. Configure network exposure
# 5. Setup reverse proxy with detected IP
# 6. Start all services
```

### Option 2: Development Setup
```bash
# Sequential startup for development
make start-dev

# Access services on localhost
# Frontend: http://localhost:3000
# GraphQL: http://localhost:4000/graphql
# API Gateway: http://localhost:8000/api/v1/
```

### Option 3: Reverse Proxy Setup (Network Access)
```bash
# Start with reverse proxy (exposes all services through NGINX)
make start-with-proxy

# Access all services through single entry point
# Frontend: http://YOUR_DETECTED_IP/
# GraphQL: http://YOUR_DETECTED_IP/graphql
# API Gateway: http://YOUR_DETECTED_IP/api/v1/
```

### Option 4: HTTPS Setup (Production-like)
```bash
# Generate SSL certificates
make generate-ssl

# Enable HTTPS
make enable-https

# Start with proxy
make start-with-proxy

# Access via HTTPS
# https://YOUR_DETECTED_IP/
```

## 🌐 Automatic Network Detection

The infrastructure automatically detects your network IP and configures the reverse proxy accordingly:

### How It Works
1. **Cross-Platform Detection**: Works on Linux, macOS, and Windows
2. **Smart IP Selection**: Automatically finds the primary network interface
3. **Automatic Configuration**: Updates NGINX and environment files with detected IP
4. **Fallback Support**: Uses localhost if network detection fails

### Detection Methods
- **Linux**: Uses `hostname -I` to get primary network IP
- **macOS**: Uses `ifconfig` to find non-loopback interface
- **Windows**: Uses `ipconfig` to get IPv4 address
- **Fallback**: Uses localhost if detection fails

### Example Output
```bash
$ make start
🔍 Detecting network IP...
✅ Detected network IP: 192.168.1.100
📝 Updating NGINX configuration with network IP...
✅ Updated NGINX server_name to: 192.168.1.100
🌐 Reverse Proxy Information
============================
  Server IP: 192.168.1.100
  HTTP Port: 80
  HTTPS Port: 443 (if enabled)

📋 Public Endpoints:
  Frontend:           http://192.168.1.100/
  GraphQL API:        http://192.168.1.100/graphql
  GraphQL Playground: http://192.168.1.100/playground
  Django API:         http://192.168.1.100/api/v1/
  Auth Service:       http://192.168.1.100/auth/
  Log Service:        http://192.168.1.100/logs/
  WebSocket:          ws://192.168.1.100/socket.io/
```

## 📋 Command Reference

### 🚀 Core Commands

| Command | Description |
|---------|-------------|
| `make start` | Complete startup (env prep, port check, network config, proxy setup, start services) |
| `make start-dev` | Development startup with sequential service loading |
| `make start-with-proxy` | Start with reverse proxy (recommended for network access) |
| `make stop` | Stop all services and free ports |
| `make restart` | Complete restart (stop + start) |
| `make reload SERVICE=name` | Reload specific service (e.g., `make reload SERVICE=postgres`) |
| `make pause` | Pause all services |
| `make resume` | Resume all paused services |

### 🔧 Setup Commands

| Command | Description |
|---------|-------------|
| `make setup-proxy` | Setup reverse proxy configuration |
| `make configure-network` | Configure network exposure |
| `make prepare-environment` | Prepare environment files and directories |
| `make check-ports` | Check for port conflicts |
| `make detect-network-ip` | Detect and display network IP |

### 🔨 Build Commands

| Command | Description |
|---------|-------------|
| `make build-service SERVICE=name` | Build specific service |
| `make rebuild-service SERVICE=name` | Rebuild and restart service |
| `make build-all` | Build all services |

### 🌐 Network Commands

| Command | Description |
|---------|-------------|
| `make expose-dev` | Expose services to network |
| `make generate-ssl` | Generate SSL certificates |
| `make enable-https` | Enable HTTPS (requires SSL) |

### 📊 Status Commands

| Command | Description |
|---------|-------------|
| `make status` | Quick status check |
| `make services` | Show running services |
| `make logs` | Show logs from all services |
| `make logs APP=name` | Show logs from specific app |

### 🛠️ Utility Commands

| Command | Description |
|---------|-------------|
| `make force-stop` | Force stop with aggressive cleanup |
| `make full-stop` | Complete shutdown with cleanup |
| `make install-deps SERVICE=name` | Install dependencies for service |

### 🍎 macOS Optimization

| Command | Description |
|---------|-------------|
| `make macos-config` | Switch to macOS-optimized configuration |
| `make macos-performance` | Check Docker performance |
| `make macos-clean` | Clean up Docker for macOS |

## 🌐 Reverse Proxy Architecture

The infrastructure includes an **NGINX reverse proxy** that acts as a single entry point for all external traffic:

```
┌─────────────────┐
│   External      │
│   Clients       │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│   NGINX Proxy   │
│   Port 80/443   │
│   Auto-configured│
│   with detected │
│   network IP    │
└─────────┬───────┘
          │
    ┌─────┴─────┐
    ▼           ▼
┌─────────┐ ┌─────────┐
│Frontend │ │ GraphQL │
│Port 3000│ │Port 4000│
└─────────┘ └─────────┘
    │           │
    └─────┬─────┘
          ▼
┌─────────────────┐
│  Internal       │
│  Services       │
│  (localhost)    │
└─────────────────┘
```

### Public Endpoints (via Reverse Proxy)

| Service | URL Path | Description |
|---------|----------|-------------|
| Frontend | `/` | Next.js application |
| GraphQL API | `/graphql` | GraphQL endpoint |
| GraphQL Playground | `/playground` | GraphQL IDE |
| Django API | `/api/v1/` | REST API gateway |
| Auth Service | `/auth/` | Authentication API |
| Log Service | `/logs/` | Logging API |
| WebSocket | `/socket.io/` | Real-time communication |

### Admin Tools (Protected)

| Tool | URL Path | Credentials |
|------|----------|-------------|
| pgAdmin | `/admin/pgadmin/` | admin/admin123 |
| Mongo Express | `/admin/mongo/` | admin/admin123 |
| Redis Commander | `/admin/redis/` | admin/admin123 |
| Kafka UI | `/admin/kafka/` | admin/admin123 |
| Kibana | `/admin/kibana/` | admin/admin123 |
| Consul | `/admin/consul/` | admin/admin123 |

### Benefits of Reverse Proxy Setup

1. **Single Entry Point**: All traffic goes through one IP/domain
2. **Security**: Internal services remain on localhost
3. **SSL Termination**: HTTPS handled at proxy level
4. **Load Balancing**: Can easily add multiple instances
5. **Rate Limiting**: Built-in protection against abuse
6. **Caching**: Static assets cached at proxy level
7. **Monitoring**: Centralized logging and metrics
8. **Auto-Configuration**: Automatically detects and configures network IP

## 🔧 Service Management

### Service Reload

```bash
# Basic syntax
make reload SERVICE=service-name

# Examples
make reload SERVICE=postgres
make reload SERVICE=redis
make reload SERVICE=elasticsearch
make reload SERVICE=nginx-proxy
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
| nginx-proxy | All services (restarts proxy) |

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
| `nginx-proxy` | NGINX reverse proxy |

## 🏗️ Architecture Components

### Infrastructure Services
- **PostgreSQL** - Primary relational database
- **MongoDB** - Analytics, logs, AI conversations
- **Redis** - Cache, sessions, queues
- **Qdrant** - Vector database for AI/RAG
- **Kafka** - Message broker
- **Elasticsearch** - Search engine
- **Kibana** - Elasticsearch visualization

### API Layer
- **GraphQL Gateway** - Main API gateway (port 4000)
- **Django API Gateway** - Secondary gateway with auth proxy (port 8000)
- **WebSocket Server** - Real-time communication (port 3001)
- **gRPC Registry (Consul)** - Service discovery (port 8500)

### Application Services
- **Auth Service** - Authentication and authorization (port 8080)
- **Log Service** - Centralized logging (port 8001)
- **Frontend** - Next.js application (port 3000)

### Development Tools
- **pgAdmin** - PostgreSQL administration (port 8081)
- **Mongo Express** - MongoDB administration (port 8082)
- **Redis Commander** - Redis administration (port 8083)
- **Kafka UI** - Kafka administration (port 8084)
- **Kibana** - Elasticsearch visualization (port 5601)

## 🔄 Sequential Startup System

The `start-dev` command uses a 10-phase sequential startup to reduce resource load and ensure proper dependency management:

### Startup Phases
1. **Phase 1**: Core Databases (PostgreSQL, Redis)
2. **Phase 2**: Document & Vector Stores (MongoDB, Qdrant)
3. **Phase 3**: Message Broker (Kafka)
4. **Phase 4**: Search Engine (Elasticsearch)
5. **Phase 5**: API Layer (GraphQL Gateway, gRPC Registry)
6. **Phase 6**: WebSocket Server
7. **Phase 7**: Logging (Kibana)
8. **Phase 8**: Development Tools
9. **Phase 9**: Core Application Services (Auth, API Gateway, Log Service)
10. **Phase 10**: Frontend

### Benefits
- Reduced resource contention during startup
- Proper dependency ordering ensures stability
- Better error isolation and debugging
- Health checks between phases

## 🔐 Security Features

### Network Security
- **Rate Limiting**: API endpoints protected against abuse
- **Basic Auth**: Admin tools protected with credentials
- **Security Headers**: XSS protection, content type validation
- **Internal Services**: All services run on localhost by default

### SSL/HTTPS Support
```bash
# Generate self-signed certificates
make generate-ssl

# Enable HTTPS
make enable-https

# Access via HTTPS
https://YOUR_DETECTED_IP/
```

## 📊 Monitoring & Health Checks

### Health Check Endpoints
- **Proxy Health**: `http://YOUR_DETECTED_IP/health`
- **Service Status**: `make status`
- **Service Logs**: `make logs`
- **Individual Service**: `make logs APP=service-name`

### Service Health Monitoring
```bash
# Quick status check
make status

# Detailed service status
make services

# Monitor specific service
make logs APP=postgres
```

## 🛠️ Development Workflow

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

## 🔧 Configuration

### Environment Variables

Key environment variables for customization:

```bash
# Network Configuration
HOST_IP=0.0.0.0                    # Network exposure IP
NETWORK_SUBNET=172.20.0.0/16       # Docker network subnet

# Service Ports
POSTGRES_PORT=5432
REDIS_PORT=6379
MONGODB_PORT=27017
KAFKA_PORT=9092
ELASTICSEARCH_PORT=9200
GRAPHQL_GATEWAY_PORT=4000
WEBSOCKET_PORT=3001
FRONTEND_PORT=3000
AUTH_SERVICE_HTTP_PORT=8080
API_GATEWAY_PORT=8000
LOG_SERVICE_HTTP_PORT=8001

# Development Tools Ports
PGADMIN_PORT=8081
MONGO_EXPRESS_PORT=8082
REDIS_COMMANDER_PORT=8083
KAFKA_UI_PORT=8084
KIBANA_PORT=5601
```

### Custom Configuration

```bash
# Custom network IP
make start HOST_IP=192.168.1.100

# Custom environment
make start ENVIRONMENT=staging

# Custom build type
make start BUILD_TYPE=production
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### Port Conflicts
The system automatically checks for port conflicts before starting:
```bash
# Manual port check
make check-ports

# Kill processes using specific port
sudo lsof -ti:5432 | xargs kill -9
```

#### Service Startup Issues
```bash
# Check service logs
make logs APP=postgres

# Reload specific service
make reload SERVICE=postgres

# Rebuild service
make rebuild-service SERVICE=postgres
```

#### Network Access Issues
```bash
# Check proxy status
curl http://YOUR_DETECTED_IP/health

# Check firewall
sudo ufw status

# Restart proxy
make reload SERVICE=nginx-proxy
```

#### Docker Issues
```bash
# Clean Docker system
make macos-clean

# Force stop all containers
make force-stop

# Check Docker resources
make macos-performance
```

### Performance Optimization

#### macOS Optimization
```bash
# Switch to macOS-optimized config
make macos-config

# Check performance
make macos-performance

# Clean up Docker
make macos-clean
```

#### Resource Allocation
- **PostgreSQL**: 512MB RAM limit, 256MB reserved
- **Elasticsearch**: 1GB RAM limit, 512MB reserved
- **Kafka**: 256MB heap memory
- **Other services**: Default Docker limits

## 📈 Scaling Considerations

### Horizontal Scaling
The infrastructure supports horizontal scaling through:
- **Load Balancing**: NGINX proxy can distribute traffic
- **Service Replication**: Multiple instances of services
- **Database Clustering**: PostgreSQL read replicas, MongoDB replica sets
- **Cache Distribution**: Redis cluster support

### Vertical Scaling
- **Memory Allocation**: Adjust service memory limits in docker-compose.yml
- **CPU Limits**: Configure CPU limits for resource-intensive services
- **Storage**: Increase volume sizes for databases

## 🔄 Backup and Recovery

### Database Backups
```bash
# PostgreSQL backup
docker compose exec postgres pg_dump -U postgres erp_system > backup.sql

# MongoDB backup
docker compose exec mongodb mongodump --out /backup

# Redis backup
docker compose exec redis redis-cli SAVE
```

### Volume Management
```bash
# List volumes
docker volume ls

# Backup volumes
docker run --rm -v erp-suite_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_data.tar.gz -C /data .

# Restore volumes
docker run --rm -v erp-suite_postgres_data:/data -v $(pwd):/backup alpine tar xzf /backup/postgres_data.tar.gz -C /data
```

## 📚 Additional Resources

### Documentation
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [NGINX Configuration](https://nginx.org/en/docs/)
- [GraphQL Documentation](https://graphql.org/learn/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

### Community Support
- GitHub Issues: Report bugs and feature requests
- Documentation: Comprehensive setup and usage guides
- Examples: Sample configurations and use cases

---

**ERP Suite Infrastructure** - Complete development environment with reverse proxy, automatic network detection, monitoring, and cross-platform support.