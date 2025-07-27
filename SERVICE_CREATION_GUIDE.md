# ERP Service Creation Guide

## Quick Service Creation

Use the simple command format:

```bash
./create-service.sh <port> <service-name> <language>
```

### Examples

```bash
# Create a Go CRM service on port 8082
./create-service.sh 8082 crm go

# Create a Python HRM service on port 8083  
./create-service.sh 8083 hrm python

# Create a Node.js Inventory service on port 8084
./create-service.sh 8084 inventory node
```

## Database Options

When you run the script, you'll be prompted to choose:

1. **Use existing database** - Uses `erp_servicename` database
2. **Create new database** - Creates a new `erp_servicename` database  
3. **Use shared database** - Uses the shared `erp_core` database

## Supported Languages

### Go
- **Framework**: Gin
- **Database**: lib/pq (PostgreSQL)
- **Cache**: go-redis
- **File**: `main.go`

### Python  
- **Framework**: FastAPI
- **Database**: psycopg2 (PostgreSQL)
- **Cache**: redis-py
- **File**: `main.py`

### Node.js
- **Framework**: Express
- **Database**: pg (PostgreSQL) 
- **Cache**: redis
- **File**: `server.js`

## Generated Structure

Each service gets:

```
erp-servicename-service/
├── main.go|main.py|server.js    # Main application file
├── Dockerfile                   # Container configuration
├── .env                        # Environment variables
├── README.md                   # Service documentation
├── go.mod|requirements.txt|package.json  # Dependencies
└── .git/                       # Git repository
```

## Service Features

All generated services include:

- **Health Check**: `GET /health`
- **CRUD API**: Full REST API for the service
- **Database Connection**: PostgreSQL integration
- **Redis Cache**: Ready for caching
- **Docker Support**: Complete containerization
- **Infrastructure Integration**: Auto-added to docker-compose

## API Endpoints

Each service automatically gets these endpoints:

- `GET /health` - Health check
- `GET /api/v1/servicename` - List items
- `POST /api/v1/servicename` - Create item  
- `GET /api/v1/servicename/:id` - Get item by ID
- `PUT /api/v1/servicename/:id` - Update item
- `DELETE /api/v1/servicename/:id` - Delete item

## Next Steps After Creation

1. **Review the code**: `cd ../erp-servicename-service`
2. **Start infrastructure**: `cd ../erp-suit-infrastructure && make start-dev`
3. **Run your service**: `docker compose up -d servicename-service`
4. **Test it**: `curl http://localhost:PORT/health`

## Development Workflow

```bash
# Start infrastructure
make start-dev

# Create your service
./create-service.sh 8085 finance go

# Start your service  
docker compose up -d finance-service

# View logs
make logs APP=finance-service

# Test the service
curl http://localhost:8085/health
curl http://localhost:8085/api/v1/finance
```

## Service Integration

Your service automatically integrates with:

- **PostgreSQL**: Database access
- **Redis**: Caching layer
- **Kafka**: Message broker (ready to use)
- **Infrastructure**: Monitoring, logging, etc.

## Customization

After generation, you can:

- Add business logic to the handlers
- Implement database models
- Add authentication middleware
- Integrate with other services
- Add custom endpoints

The generated code is a starting template - customize it for your needs!