# API Gateway Migration: Django to Go

This document outlines the changes made to migrate from the Django API Gateway to the Go API Gateway in the ERP Suite infrastructure.

## Changes Made

### 1. API Gateway Docker Configuration

**File**: `erp-api-gateway/Dockerfile.dev`
- Created new Dockerfile.dev for Go API Gateway
- Uses Go 1.23 Alpine base image
- Includes Air for hot reloading in development
- Exposes port 8000 (matching original Django configuration)
- Multi-stage build with development and production targets

**File**: `erp-api-gateway/.air.toml`
- Created Air configuration for hot reloading
- Watches Go files, YAML, and template files
- Excludes test files and generated code
- Builds to `tmp/main` binary

**File**: `erp-api-gateway/config.yaml`
- Created default configuration file for Go API Gateway
- Includes all service connections (PostgreSQL, Redis, Kafka, gRPC services)
- Configured for Docker Compose environment
- JWT configuration pointing to auth service

### 2. Infrastructure Docker Compose Updates

**File**: `erp-suit-infrastructure/docker-compose.yml`
- Updated `api-gateway` service configuration:
  - Changed from Django/Python to Go environment variables
  - Updated environment variables to use `ERP_` prefix
  - Changed port from 8080 to 8000 (matching original)
  - Updated command to use Air for hot reloading
  - Added Go-specific configuration for gRPC services
  - Updated health check endpoint

### 3. Environment Configuration

**File**: `erp-suit-infrastructure/.env.example`
- Added `API_GATEWAY_PORT=8000` variable
- Added `API_GATEWAY_CONFIG_FILE=/app/config.yaml` variable
- Kept legacy Django variables for backward compatibility

### 4. NGINX Proxy Configuration

**File**: `erp-suit-infrastructure/nginx/nginx.conf`
- Updated `api_gateway_backend` upstream to use port 8000
- Updated comment from "Django API Gateway" to "Go API Gateway"
- No changes to routing paths - maintains backward compatibility

## Environment Variables

The Go API Gateway uses environment variables with the `ERP_` prefix:

### Server Configuration
- `ERP_SERVER_HOST=0.0.0.0`
- `ERP_SERVER_PORT=8000`
- `ERP_SERVER_READ_TIMEOUT=30s`
- `ERP_SERVER_WRITE_TIMEOUT=30s`
- `ERP_SERVER_SHUTDOWN_TIMEOUT=10s`

### Database Configuration
- `ERP_DATABASE_HOST=postgres`
- `ERP_DATABASE_PORT=5432`
- `ERP_DATABASE_NAME=erp_gateway`
- `ERP_DATABASE_USER=postgres`
- `ERP_DATABASE_PASSWORD=postgres`
- `ERP_DATABASE_SSL_MODE=disable`

### Redis Configuration
- `ERP_REDIS_HOST=redis`
- `ERP_REDIS_PORT=6379`
- `ERP_REDIS_PASSWORD=redispassword`
- `ERP_REDIS_DB=1`

### Kafka Configuration
- `ERP_KAFKA_BROKERS=kafka:29092`
- `ERP_KAFKA_CLIENT_ID=go-api-gateway`

### gRPC Services Configuration
- `ERP_GRPC_AUTH_SERVICE_HOST=auth-service`
- `ERP_GRPC_AUTH_SERVICE_PORT=50051`
- `ERP_GRPC_CRM_SERVICE_HOST=crm-service`
- `ERP_GRPC_CRM_SERVICE_PORT=50052`
- `ERP_GRPC_HRM_SERVICE_HOST=hrm-service`
- `ERP_GRPC_HRM_SERVICE_PORT=50053`
- `ERP_GRPC_FINANCE_SERVICE_HOST=finance-service`
- `ERP_GRPC_FINANCE_SERVICE_PORT=50054`

### JWT Configuration
- `ERP_JWT_JWKS_URL=http://auth-service:8080/api/v1/.well-known/jwks.json`
- `ERP_JWT_CACHE_TTL=1h`
- `ERP_JWT_ALGORITHM=RS256`
- `ERP_JWT_ISSUER=erp-auth-service`

### CORS Configuration
- `ERP_SERVER_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://localhost,http://erp-frontend:3000,http://graphql-gateway:4000,http://websocket-server:3001`
- `ERP_SERVER_CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS,PATCH`
- `ERP_SERVER_CORS_ALLOWED_HEADERS=Authorization,Content-Type,X-Requested-With,Accept,Origin`
- `ERP_SERVER_CORS_ALLOW_CREDENTIALS=true`

### Logging Configuration
- `ERP_LOGGING_LEVEL=info`
- `ERP_LOGGING_FORMAT=json`
- `ERP_LOGGING_OUTPUT=stdout`
- `ERP_LOGGING_ELASTICSEARCH_URLS=http://elasticsearch:9200`
- `ERP_LOGGING_ELASTICSEARCH_INDEX_NAME=go-api-gateway-logs`

## API Endpoints

The Go API Gateway maintains the same REST API endpoints as the Django version:

- `GET /health` - Health check endpoint
- `GET /ready` - Readiness probe
- `POST /api/v1/auth/login` - User authentication
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/refresh` - Token refresh
- `POST /api/v1/auth/logout` - User logout
- `GET /api/v1/auth/me` - Current user profile

Additional endpoints:
- `GET /graphql` - GraphQL endpoint (if enabled)
- `GET /metrics` - Prometheus metrics
- `GET /debug/pprof/` - Go profiling endpoints

## Service Dependencies

The Go API Gateway depends on:
1. PostgreSQL (for gateway-specific data)
2. Redis (for caching and sessions)
3. Kafka (for event publishing)
4. Elasticsearch (for logging)
5. Auth Service (for JWT validation)
6. Other gRPC services (CRM, HRM, Finance)

## Migration Notes

1. **Port Consistency**: The Go API Gateway uses port 8000 to maintain consistency with the original Django setup
2. **Environment Variables**: All configuration uses the `ERP_` prefix for consistency
3. **Backward Compatibility**: API endpoints remain the same for seamless frontend integration
4. **Configuration**: Both file-based (config.yaml) and environment variable configuration supported
5. **Development**: Hot reloading enabled with Air for development efficiency

## Testing the Migration

To test the migration:

1. Start the infrastructure:
   ```bash
   cd erp-suit-infrastructure
   make start
   ```

2. Verify API Gateway is running:
   ```bash
   curl http://localhost:8000/health
   ```

3. Test through NGINX proxy:
   ```bash
   curl http://localhost/api/v1/health
   ```

4. Check logs:
   ```bash
   docker logs erp-suite-api-gateway
   ```

## Rollback Plan

If rollback is needed:
1. Revert docker-compose.yml changes
2. Restore Django-specific environment variables
3. Update NGINX configuration back to Django setup
4. Restart services

The migration maintains API compatibility, so frontend applications should continue working without changes.