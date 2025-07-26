# ERP Suite Shared Configuration System

This directory contains the shared configuration system that allows all ERP modules to connect to the infrastructure services with consistent settings and environment variables.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                 Shared Configuration System                  │
├─────────────────────────────────────────────────────────────┤
│  Configuration Sources:                                     │
│  • YAML files (environment-specific)                       │
│  • Generated .env files (module-specific)                  │
│  • Environment variables (runtime overrides)               │
│  • Kubernetes ConfigMaps/Secrets (production)              │
│                                                             │
│  Configuration Generators:                                 │
│  • Go: generate-env.go (for Go services)                  │
│  • Python: generate-env.py (for Python services)         │
│  • Node.js: generate-env.js (for frontend/websocket)     │
│                                                             │
│  Configuration Loaders:                                    │
│  • Go: config.go (runtime configuration loading)          │
│  • Database helpers: database.go, cache.go                │
│                                                             │
│  Features:                                                  │
│  • Environment-specific configs (dev/test/staging/prod)    │
│  • Module-specific environment generation                  │
│  • Automatic service discovery                             │
│  • Health check endpoints                                  │
│  • Connection pooling settings                             │
│  • Security configurations                                 │
│  • Monitoring and logging configs                          │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Generate Environment Files
```bash
# Generate for specific module and environment
make generate-env ENV=development MODULE=auth

# Generate for all modules in development
make generate-all-envs ENV=development

# Generate for production
make generate-env ENV=production MODULE=frontend
```

### For Go Services (like auth-module)
```go
import "erp-suite/shared-config/loaders/go"

// Load from YAML configuration
config, err := config.Load("development", "auth")
if err != nil {
    log.Fatal(err)
}

// Or load from environment variables
config := config.LoadFromEnv()

// Use configuration
dbURL := config.GetDatabaseURL("postgresql", "erp_auth")
serviceURL := config.GetServiceURL("crm_service", "http")
```

### For Python Services (AI module)
```bash
# Generate environment file
python3 generators/generate-env.py --env=development --module=ai

# Use in your Python application
from dotenv import load_dotenv
import os

load_dotenv('.env.ai.development')
DATABASE_URL = os.getenv('DATABASE_URL')
MONGODB_URL = os.getenv('MONGODB_URL')
QDRANT_URL = os.getenv('QDRANT_URL')
```

### For Node.js Services (Frontend)
```bash
# Generate environment file
node generators/generate-env.js --env=development --module=frontend

# Use in your Next.js application
# The .env.frontend.development file will be automatically loaded
```

## 📁 Directory Structure

```
shared-config/
├── README.md                    # This file
├── config.yaml                 # Main configuration metadata
├── Makefile                    # Build and generation commands
├── environments/               # Environment-specific configurations
│   ├── development.yaml        # Development environment
│   ├── testing.yaml           # Testing environment
│   ├── staging.yaml           # Staging environment
│   └── production.yaml        # Production environment
├── generators/                 # Configuration generators
│   ├── generate-env.go        # Go environment generator
│   ├── generate-env.py        # Python environment generator
│   └── generate-env.js        # Node.js environment generator
└── loaders/                   # Runtime configuration loaders
    └── go/                    # Go configuration loader
        ├── config.go          # Main configuration loader
        ├── database.go        # Database configuration helpers
        └── cache.go           # Cache configuration helpers
```

## 🔧 Configuration Management

### Environment Priority (highest to lowest)
1. Runtime environment variables
2. Environment-specific .env files
3. config.yaml defaults
4. Hardcoded fallbacks

### Service Discovery
- Automatic detection of development vs production
- Health check integration
- Connection pooling and retry logic
- Circuit breaker patterns

## 📚 Usage Examples

See the language-specific documentation in the `loaders/` directory for detailed usage examples.