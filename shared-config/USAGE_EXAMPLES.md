# ERP Suite Shared Configuration Usage Examples

This document provides comprehensive examples of how to use the shared configuration system across different modules and environments.

## 🚀 Quick Start Commands

### Generate Environment Files

```bash
# Navigate to shared-config directory
cd erp-suite/shared-config

# Generate environment file for auth module in development
make generate-env ENV=development MODULE=auth

# Generate environment files for all modules in development
make generate-all-envs ENV=development

# Generate for specific environment and module
make generate-env ENV=production MODULE=frontend OUTPUT=.env.prod

# Generate for testing environment
make generate-test
```

### Validate Configurations

```bash
# Validate all YAML configuration files
make validate

# Test all generators
make test

# Show available environments and modules
make show-environments
make show-modules
```

## 📋 Module-Specific Examples

### 1. Authentication Service (Go)

```bash
# Generate environment file
make generate-env ENV=development MODULE=auth
```

This creates `.env.auth.development` with:
```env
# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/erp_auth?sslmode=disable
REDIS_URL=redis://:redispassword@localhost:6379/0

# Service ports
HTTP_PORT=8080
GRPC_PORT=9090

# Kafka
KAFKA_CONSUMER_GROUP=auth-service-group
```

**Usage in Go code:**
```go
package main

import (
    "log"
    "erp-suite/shared-config/loaders/go"
)

func main() {
    // Load configuration from YAML
    config, err := config.Load("development", "auth")
    if err != nil {
        log.Fatal(err)
    }

    // Or load from environment variables
    envConfig := config.LoadFromEnv()

    // Get database URL
    dbURL := config.GetDatabaseURL("postgresql", "erp_auth")
    
    // Get service URLs
    crmServiceURL := config.GetServiceURL("crm_service", "http")
    
    // Generate environment file programmatically
    envContent, err := config.GenerateEnvFile("auth", "development")
    if err != nil {
        log.Fatal(err)
    }
}
```

### 2. AI Service (Python)

```bash
# Generate environment file
make generate-env ENV=development MODULE=ai
```

This creates `.env.ai.development` with:
```env
# Databases
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/erp_auth?sslmode=disable
MONGODB_URL=mongodb://root:password@localhost:27017/erp_analytics?authSource=admin
QDRANT_URL=http://localhost:6333

# AI specific
OPENAI_API_KEY=your-api-key
OPENAI_MODEL=gpt-3.5-turbo
OPENAI_MAX_TOKENS=1000

# Service ports
HTTP_PORT=8086
GRPC_PORT=9096
```

**Usage in Python code:**
```python
#!/usr/bin/env python3
import os
from dotenv import load_dotenv

# Load environment file
load_dotenv('.env.ai.development')

# Database connections
DATABASE_URL = os.getenv('DATABASE_URL')
MONGODB_URL = os.getenv('MONGODB_URL')
QDRANT_URL = os.getenv('QDRANT_URL')

# AI configuration
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-3.5-turbo')

# Service configuration
HTTP_PORT = int(os.getenv('HTTP_PORT', 8086))
GRPC_PORT = int(os.getenv('GRPC_PORT', 9096))

print(f"AI Service starting on port {HTTP_PORT}")
print(f"Using OpenAI model: {OPENAI_MODEL}")
```

### 3. Frontend Application (Next.js)

```bash
# Generate environment file
make generate-env ENV=development MODULE=frontend
```

This creates `.env.frontend.development` with:
```env
# Next.js environment
NODE_ENV=development
PORT=3000

# API URLs
NEXT_PUBLIC_AUTH_API_URL=http://localhost:8080
NEXT_PUBLIC_CRM_API_URL=http://localhost:8081
NEXT_PUBLIC_HRM_API_URL=http://localhost:8082
NEXT_PUBLIC_AI_API_URL=http://localhost:8086

# WebSocket
NEXT_PUBLIC_WEBSOCKET_URL=ws://localhost:3001

# Authentication
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=dev-super-secret-jwt-key-change-in-production

# Feature flags
NEXT_PUBLIC_FEATURE_AI_ASSISTANT=true
NEXT_PUBLIC_FEATURE_REAL_TIME_NOTIFICATIONS=true

# Payment
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
```

**Usage in Next.js:**
```javascript
// next.config.js
module.exports = {
  env: {
    AUTH_API_URL: process.env.NEXT_PUBLIC_AUTH_API_URL,
    WEBSOCKET_URL: process.env.NEXT_PUBLIC_WEBSOCKET_URL,
  },
  publicRuntimeConfig: {
    apiUrl: process.env.NEXT_PUBLIC_AUTH_API_URL,
    wsUrl: process.env.NEXT_PUBLIC_WEBSOCKET_URL,
  }
}

// pages/api/auth.js
export default function handler(req, res) {
  const authApiUrl = process.env.NEXT_PUBLIC_AUTH_API_URL;
  // Make API calls to auth service
}

// components/FeatureFlag.jsx
export function AIAssistant() {
  const isEnabled = process.env.NEXT_PUBLIC_FEATURE_AI_ASSISTANT === 'true';
  
  if (!isEnabled) return null;
  
  return <div>AI Assistant Component</div>;
}
```

## 🌍 Environment-Specific Examples

### Development Environment

```bash
# Generate all development environment files
make generate-dev

# This creates:
# .env.auth.development
# .env.crm.development
# .env.hrm.development
# .env.finance.development
# .env.inventory.development
# .env.projects.development
# .env.ai.development
# .env.frontend.development
# .env.admin.development
```

**Characteristics:**
- Debug mode enabled
- Local database connections
- Permissive CORS settings
- Rate limiting disabled
- Mock external services

### Production Environment

```bash
# Generate production environment files
make generate-prod

# This creates production-ready configurations with:
# - Encrypted secrets
# - SSL/TLS enabled
# - Restrictive CORS
# - Rate limiting enabled
# - External service integrations
```

**Key differences:**
```env
# Development
DEBUG=true
DB_SSL_MODE=disable
RATE_LIMITING_ENABLED=false
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# Production
DEBUG=false
DB_SSL_MODE=require
RATE_LIMITING_ENABLED=true
ALLOWED_ORIGINS=https://app.erp-suite.com
```

## 🔧 Advanced Usage

### Custom Environment Generation

```bash
# Generate with custom output file
make generate-env ENV=staging MODULE=auth OUTPUT=.env.auth.staging.custom

# Generate for specific module with verbose output
cd generators
go run generate-env.go --env=production --module=crm --verbose

# Python generator with custom output
python3 generate-env.py --env=staging --module=ai --output=.env.ai.staging

# Node.js generator
node generate-env.js --env=production --module=frontend --verbose
```

### Configuration Validation

```bash
# Validate all configurations
make validate

# Check differences between environments
make diff-envs ENV1=development ENV2=production

# Show configuration for specific environment
make show-config ENV=staging
```

### Docker Integration

```dockerfile
# Dockerfile example
FROM node:18-alpine

WORKDIR /app

# Copy shared configuration
COPY erp-suite/shared-config ./shared-config

# Generate environment file during build
RUN cd shared-config && \
    node generators/generate-env.js --env=production --module=frontend

# Use the generated environment file
ENV NODE_ENV=production
COPY .env.frontend.production .env.local

COPY . .
RUN npm install && npm run build

EXPOSE 3000
CMD ["npm", "start"]
```

### Kubernetes Integration

```yaml
# ConfigMap from generated environment
apiVersion: v1
kind: ConfigMap
metadata:
  name: auth-service-config
data:
  # Generated from .env.auth.production
  DATABASE_URL: "postgresql://user:pass@postgres:5432/erp_auth"
  REDIS_URL: "redis://:pass@redis:6379/0"
  HTTP_PORT: "8080"
  GRPC_PORT: "9090"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auth-service
spec:
  template:
    spec:
      containers:
      - name: auth-service
        image: erp-suite/auth-service:latest
        envFrom:
        - configMapRef:
            name: auth-service-config
```

## 🔍 Troubleshooting

### Common Issues

1. **Missing dependencies:**
```bash
make install-deps
```

2. **Go module not initialized:**
```bash
make init-go
```

3. **Node.js packages missing:**
```bash
make init-nodejs
```

4. **Configuration validation errors:**
```bash
make validate
# Fix YAML syntax errors in environments/*.yaml
```

5. **Generator failures:**
```bash
make test
# Check generator output for specific errors
```

### Debug Mode

```bash
# Run generators with verbose output
cd generators

# Go generator debug
go run generate-env.go --env=development --module=auth --verbose

# Python generator debug
python3 generate-env.py --env=development --module=ai --verbose

# Node.js generator debug
node generate-env.js --env=development --module=frontend --verbose
```

## 📚 Best Practices

### 1. Environment File Management

- **Never commit generated .env files** to version control
- Use `.gitignore` to exclude `.env.*` files
- Generate environment files during deployment
- Use different configurations for different environments

### 2. Secret Management

- Use environment variables for sensitive data in production
- Use encrypted secrets in staging/production
- Keep development secrets simple but not empty
- Rotate secrets regularly

### 3. Configuration Updates

- Update YAML files in `environments/` directory
- Regenerate environment files after changes
- Test configuration changes in development first
- Validate configurations before deployment

### 4. Module Integration

- Use the appropriate generator for your language
- Load configurations at application startup
- Implement configuration hot-reloading for development
- Add health checks for external dependencies

## 🎯 Next Steps

1. **Set up your development environment:**
```bash
make setup
make generate-dev
```

2. **Integrate with your module:**
- Choose the appropriate generator (Go/Python/Node.js)
- Generate environment file for your module
- Load configuration in your application code
- Test connectivity to shared services

3. **Deploy to other environments:**
```bash
make generate-staging
make generate-prod
```

4. **Monitor and maintain:**
- Set up configuration validation in CI/CD
- Monitor configuration changes
- Keep environments in sync
- Update shared configurations as needed