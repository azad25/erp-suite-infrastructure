#!/bin/bash

# Simple ERP Service Generator
# Usage: ./create-service.sh <port> <service-name> <language>
# Example: ./create-service.sh 8082 crm go

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ $# -ne 3 ]; then
    print_error "Usage: $0 <port> <service-name> <language>"
    print_info "Example: $0 8082 crm go"
    print_info "Languages: go, python, node"
    exit 1
fi

SERVICE_PORT=$1
SERVICE_NAME=$2
LANGUAGE=$3
SERVICE_DIR="../erp-${SERVICE_NAME}-service"

print_info "Creating ${SERVICE_NAME} service on port ${SERVICE_PORT} using ${LANGUAGE}"

# Check if directory exists
if [ -d "$SERVICE_DIR" ]; then
    print_error "Directory $SERVICE_DIR already exists!"
    exit 1
fi

# Database selection
echo ""
print_info "Database Configuration:"
echo "1) Use existing database (erp_${SERVICE_NAME})"
echo "2) Create new database"
echo "3) Use shared database (erp_core)"
read -p "Select option [1-3]: " db_choice

case $db_choice in
    1) DATABASE_NAME="erp_${SERVICE_NAME}" ;;
    2) DATABASE_NAME="erp_${SERVICE_NAME}" 
       CREATE_DB=true ;;
    3) DATABASE_NAME="erp_core" ;;
    *) print_error "Invalid choice"; exit 1 ;;
esac

print_info "Using database: ${DATABASE_NAME}"

# Create service directory
mkdir -p "$SERVICE_DIR"
cd "$SERVICE_DIR"

# Initialize git
git init > /dev/null 2>&1
print_success "Created service directory and initialized git"

# Go service creation
create_go_service() {
    print_info "Creating Go service..."
    
    cat > go.mod << EOF
module erp-${SERVICE_NAME}-service

go 1.23

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    github.com/go-redis/redis/v8 v8.11.5
)
EOF

    cat > main.go << EOF
package main

import (
    "database/sql"
    "log"
    "net/http"
    "os"
    "time"
    
    "github.com/gin-gonic/gin"
    _ "github.com/lib/pq"
)

type Server struct {
    db *sql.DB
}

func main() {
    server := &Server{}
    
    // Connect to database
    var err error
    server.db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal("Database connection failed:", err)
    }
    defer server.db.Close()
    
    // Setup routes
    r := gin.Default()
    
    // Health check
    r.GET("/health", func(c *gin.Context) {
        c.JSON(200, gin.H{
            "status":  "healthy",
            "service": "${SERVICE_NAME}-service",
            "port":    "${SERVICE_PORT}",
            "time":    time.Now(),
        })
    })
    
    // API routes
    api := r.Group("/api/v1")
    {
        api.GET("/${SERVICE_NAME}", server.getItems)
        api.POST("/${SERVICE_NAME}", server.createItem)
        api.GET("/${SERVICE_NAME}/:id", server.getItem)
        api.PUT("/${SERVICE_NAME}/:id", server.updateItem)
        api.DELETE("/${SERVICE_NAME}/:id", server.deleteItem)
    }
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "${SERVICE_PORT}"
    }
    
    log.Printf("Starting ${SERVICE_NAME} service on port %s", port)
    r.Run(":" + port)
}

func (s *Server) getItems(c *gin.Context) {
    c.JSON(200, gin.H{"message": "Get ${SERVICE_NAME} items"})
}

func (s *Server) createItem(c *gin.Context) {
    c.JSON(201, gin.H{"message": "Create ${SERVICE_NAME} item"})
}

func (s *Server) getItem(c *gin.Context) {
    id := c.Param("id")
    c.JSON(200, gin.H{"message": "Get ${SERVICE_NAME} item", "id": id})
}

func (s *Server) updateItem(c *gin.Context) {
    id := c.Param("id")
    c.JSON(200, gin.H{"message": "Update ${SERVICE_NAME} item", "id": id})
}

func (s *Server) deleteItem(c *gin.Context) {
    id := c.Param("id")
    c.JSON(204, gin.H{"message": "Delete ${SERVICE_NAME} item", "id": id})
}
EOF

    print_success "Go service created"
}

# Python service creation
create_python_service() {
    print_info "Creating Python service..."
    
    cat > requirements.txt << EOF
fastapi==0.104.1
uvicorn==0.24.0
psycopg2-binary==2.9.9
redis==5.0.1
python-dotenv==1.0.0
EOF

    cat > main.py << EOF
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import psycopg2
import os
from datetime import datetime
import uvicorn

app = FastAPI(title="${SERVICE_NAME} Service")

# Database connection
def get_db_connection():
    return psycopg2.connect(os.getenv("DATABASE_URL"))

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "${SERVICE_NAME}-service",
        "port": "${SERVICE_PORT}",
        "time": datetime.now().isoformat()
    }

@app.get("/api/v1/${SERVICE_NAME}")
async def get_items():
    return {"message": "Get ${SERVICE_NAME} items"}

@app.post("/api/v1/${SERVICE_NAME}")
async def create_item():
    return {"message": "Create ${SERVICE_NAME} item"}

@app.get("/api/v1/${SERVICE_NAME}/{item_id}")
async def get_item(item_id: str):
    return {"message": f"Get ${SERVICE_NAME} item", "id": item_id}

@app.put("/api/v1/${SERVICE_NAME}/{item_id}")
async def update_item(item_id: str):
    return {"message": f"Update ${SERVICE_NAME} item", "id": item_id}

@app.delete("/api/v1/${SERVICE_NAME}/{item_id}")
async def delete_item(item_id: str):
    return {"message": f"Delete ${SERVICE_NAME} item", "id": item_id}

if __name__ == "__main__":
    port = int(os.getenv("PORT", "${SERVICE_PORT}"))
    uvicorn.run(app, host="0.0.0.0", port=port)
EOF

    print_success "Python service created"
}

# Node.js service creation
create_node_service() {
    print_info "Creating Node.js service..."
    
    cat > package.json << EOF
{
  "name": "erp-${SERVICE_NAME}-service",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    cat > server.js << EOF
const express = require('express');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const port = process.env.PORT || ${SERVICE_PORT};

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL
});

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        service: '${SERVICE_NAME}-service',
        port: '${SERVICE_PORT}',
        time: new Date().toISOString()
    });
});

// API routes
app.get('/api/v1/${SERVICE_NAME}', (req, res) => {
    res.json({ message: 'Get ${SERVICE_NAME} items' });
});

app.post('/api/v1/${SERVICE_NAME}', (req, res) => {
    res.status(201).json({ message: 'Create ${SERVICE_NAME} item' });
});

app.get('/api/v1/${SERVICE_NAME}/:id', (req, res) => {
    res.json({ message: 'Get ${SERVICE_NAME} item', id: req.params.id });
});

app.put('/api/v1/${SERVICE_NAME}/:id', (req, res) => {
    res.json({ message: 'Update ${SERVICE_NAME} item', id: req.params.id });
});

app.delete('/api/v1/${SERVICE_NAME}/:id', (req, res) => {
    res.status(204).json({ message: 'Delete ${SERVICE_NAME} item', id: req.params.id });
});

app.listen(port, () => {
    console.log(\`${SERVICE_NAME} service running on port \${port}\`);
});
EOF

    print_success "Node.js service created"
}

# Create Dockerfile
create_dockerfile() {
    print_info "Creating Dockerfile..."
    
    case $LANGUAGE in
        "go")
            cat > Dockerfile << EOF
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates curl
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE ${SERVICE_PORT}
CMD ["./main"]
EOF
            ;;
        "python")
            cat > Dockerfile << EOF
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE ${SERVICE_PORT}
CMD ["python", "main.py"]
EOF
            ;;
        "node")
            cat > Dockerfile << EOF
FROM node:18-alpine
RUN apk add --no-cache curl
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE ${SERVICE_PORT}
CMD ["npm", "start"]
EOF
            ;;
    esac
    
    print_success "Dockerfile created"
}

# Create .env file
create_env_file() {
    cat > .env << EOF
# ${SERVICE_NAME} Service Configuration
PORT=${SERVICE_PORT}
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/${DATABASE_NAME}
REDIS_URL=redis://:redispassword@localhost:6379/0
EOF
    print_success "Environment file created"
}

# Create README
create_readme() {
    cat > README.md << EOF
# ${SERVICE_NAME} Service

${SERVICE_NAME} microservice for ERP Suite.

## Quick Start

\`\`\`bash
# Start infrastructure
cd ../erp-suit-infrastructure
make start-dev

# Start this service
docker compose up -d ${SERVICE_NAME}-service
\`\`\`

## Endpoints

- \`GET /health\` - Health check
- \`GET /api/v1/${SERVICE_NAME}\` - List items
- \`POST /api/v1/${SERVICE_NAME}\` - Create item
- \`GET /api/v1/${SERVICE_NAME}/:id\` - Get item
- \`PUT /api/v1/${SERVICE_NAME}/:id\` - Update item
- \`DELETE /api/v1/${SERVICE_NAME}/:id\` - Delete item

## Development

\`\`\`bash
EOF

    case $LANGUAGE in
        "go") echo "go run main.go" >> README.md ;;
        "python") echo "python main.py" >> README.md ;;
        "node") echo "npm run dev" >> README.md ;;
    esac

    cat >> README.md << EOF
\`\`\`

Service runs on port ${SERVICE_PORT}
EOF

    print_success "README created"
}

# Update infrastructure configuration
update_infrastructure() {
    print_info "Updating infrastructure..."
    
    # Add to .env
    echo "" >> ../erp-suit-infrastructure/.env
    echo "# ${SERVICE_NAME} Service" >> ../erp-suit-infrastructure/.env
    SERVICE_NAME_UPPER=$(echo "${SERVICE_NAME}" | tr '[:lower:]' '[:upper:]')
    echo "${SERVICE_NAME_UPPER}_SERVICE_PORT=${SERVICE_PORT}" >> ../erp-suit-infrastructure/.env
    
    # Create docker-compose service
    mkdir -p ../erp-suit-infrastructure/services
    cat > ../erp-suit-infrastructure/services/${SERVICE_NAME}-service.yml << EOF
  ${SERVICE_NAME}-service:
    build:
      context: ../erp-${SERVICE_NAME}-service
      dockerfile: Dockerfile
    container_name: erp-suite-${SERVICE_NAME}-service
    environment:
      PORT: ${SERVICE_PORT}
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/${DATABASE_NAME}
      REDIS_URL: redis://:redispassword@redis:6379/0
    ports:
      - "${SERVICE_PORT}:${SERVICE_PORT}"
    depends_on:
      - postgres
      - redis
    networks:
      - erp-network
    profiles:
      - full-stack
EOF

    # Create database init script if needed
    if [ "$CREATE_DB" = true ]; then
        cat > ../erp-suit-infrastructure/scripts/init-${SERVICE_NAME}-db.sql << EOF
CREATE DATABASE ${DATABASE_NAME};
EOF
        print_success "Database initialization script created"
    fi
    
    print_success "Infrastructure updated"
}

# Main execution
# Create service based on language
case $LANGUAGE in
    "go") create_go_service ;;
    "python") create_python_service ;;
    "node") create_node_service ;;
    *) print_error "Unsupported language: $LANGUAGE"; exit 1 ;;
esac

# Create common files
create_dockerfile
create_env_file
create_readme

# Update infrastructure
update_infrastructure

print_success "Service ${SERVICE_NAME} created successfully!"
print_info ""
print_info "Next steps:"
print_info "1. cd ${SERVICE_DIR}"
print_info "2. Review the generated code"
print_info "3. cd ../erp-suit-infrastructure && make start-dev"
print_info "4. docker compose up -d ${SERVICE_NAME}-service"
print_info ""
print_info "Service URL: http://localhost:${SERVICE_PORT}/health"