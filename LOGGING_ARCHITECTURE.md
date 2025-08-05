# ERP Suite Logging Architecture

## Overview

The ERP Suite implements a comprehensive logging architecture that integrates multiple technologies to provide robust monitoring, debugging, and analytics capabilities. The system uses a multi-tier approach combining structured logging, message queuing, search indexing, and visualization.

## Architecture Components

### 1. Structured Logging Layer
- **Technology**: Logrus (Go), Custom structured logger
- **Purpose**: Generate consistent, structured log entries
- **Features**:
  - JSON formatted logs
  - Contextual information (request ID, user ID, correlation ID)
  - Multiple log levels (debug, info, warn, error, fatal)
  - Stack trace capture for errors

### 2. Message Queue Layer (Kafka)
- **Technology**: Apache Kafka
- **Purpose**: Reliable log message transport and buffering
- **Features**:
  - Asynchronous log processing
  - Message durability and replication
  - Topic-based log segregation
  - Dead letter queue for failed messages
  - Batch processing for performance

### 3. Search and Analytics Layer (Elasticsearch)
- **Technology**: Elasticsearch 7.17.3
- **Purpose**: Log storage, indexing, and search
- **Features**:
  - Full-text search capabilities
  - Time-based index management
  - Index lifecycle management (ILM)
  - Aggregations and analytics
  - Scalable storage

### 4. Visualization Layer (Kibana)
- **Technology**: Kibana 7.17.3
- **Purpose**: Log visualization and dashboard creation
- **Features**:
  - Real-time log monitoring
  - Custom dashboards
  - Alerting capabilities
  - Data exploration tools

### 5. Message Queue Management (Kafka UI)
- **Technology**: Kafka UI
- **Purpose**: Kafka cluster monitoring and management
- **Features**:
  - Topic management
  - Consumer group monitoring
  - Message browsing
  - Performance metrics

## Log Types and Structure

### 1. Request Logs
```json
{
  "@timestamp": "2025-01-08T10:30:00.000Z",
  "log_type": "request",
  "service": "auth-service",
  "request_id": "req-123456",
  "user_id": "user-789",
  "method": "POST",
  "path": "/api/v1/auth/login",
  "status_code": 200,
  "duration_ms": 150,
  "remote_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "request_size_bytes": 256,
  "response_size_bytes": 512
}
```

### 2. Error Logs
```json
{
  "@timestamp": "2025-01-08T10:30:00.000Z",
  "log_type": "error",
  "service": "auth-service",
  "component": "authentication",
  "level": "error",
  "message": "Authentication failed",
  "error": "Invalid credentials provided",
  "stack_trace": "...",
  "request_id": "req-123456",
  "user_id": "user-789",
  "context": {
    "email": "user@example.com",
    "attempt_count": 3
  }
}
```

### 3. Event Logs
```json
{
  "@timestamp": "2025-01-08T10:30:00.000Z",
  "log_type": "event",
  "service": "auth-service",
  "event_id": "evt-123456",
  "event_type": "user_logged_in",
  "user_id": "user-789",
  "correlation_id": "corr-456",
  "success": true,
  "data": {
    "login_method": "password",
    "session_duration": 3600
  }
}
```

### 4. Metric Logs
```json
{
  "@timestamp": "2025-01-08T10:30:00.000Z",
  "log_type": "metric",
  "service": "auth-service",
  "metric_name": "login_attempts",
  "metric_type": "counter",
  "value": 1,
  "unit": "count",
  "labels": {
    "method": "password",
    "status": "success"
  }
}
```

## Service Integration

### Auth Service
- **Logging Framework**: Custom structured logger with Logrus
- **Kafka Integration**: Direct Kafka producer for event streaming
- **Log Types**: Authentication events, user management, security events
- **Middleware**: Request logging, error handling, panic recovery

### API Gateway
- **Logging Framework**: Elasticsearch + Kafka integration
- **Features**: Request/response logging, error tracking, performance metrics
- **Middleware**: Request tracing, authentication logging, rate limiting logs

## Kafka Topics

### Topic Structure
```
application-logs     # General application logs
request-logs        # HTTP request/response logs
error-logs          # Error and exception logs
event-logs          # Business event logs
metric-logs         # Performance and business metrics
auth-events         # Authentication-specific events
api-events          # API Gateway events
system-events       # System-level events
dead-letter-queue   # Failed message handling
```

### Topic Configuration
- **Partitions**: 3 (for load distribution)
- **Replication Factor**: 1 (development), 3 (production)
- **Retention**: 7 days (logs), 30 days (events)
- **Compression**: Snappy

## Elasticsearch Index Management

### Index Patterns
```
erp-{service}-{log-type}-{date}

Examples:
- erp-auth-service-logs-2025.01.08
- erp-api-gateway-request-2025.01.08
- erp-auth-service-error-2025.01.08
```

### Index Lifecycle Management (ILM)
- **Hot Phase**: Active indexing, 1 day or 1GB rollover
- **Warm Phase**: After 2 days, reduce replicas
- **Cold Phase**: After 7 days, move to cold storage
- **Delete Phase**: After 30 days, delete indices

### Index Templates
- **Base Template**: Common fields and settings
- **Specialized Templates**: Request, error, event, metric specific mappings
- **Dynamic Mapping**: Flexible field addition

## Kibana Dashboards

### 1. System Overview Dashboard
- **Request Volume**: Requests per minute across all services
- **Error Rate**: Error percentage and trends
- **Response Times**: Latency percentiles and distributions
- **Service Health**: Service availability and performance
- **Top Errors**: Most frequent error messages

### 2. Auth Service Dashboard
- **Login Attempts**: Success/failure rates
- **User Activity**: Active users and session metrics
- **Security Events**: Failed logins, suspicious activity
- **Token Operations**: JWT creation, validation, refresh
- **Performance Metrics**: Response times, throughput

### 3. API Gateway Dashboard
- **Throughput**: Requests per second
- **Latency Distribution**: Response time percentiles
- **Status Code Distribution**: HTTP status breakdown
- **Top Endpoints**: Most accessed API endpoints
- **Error Analysis**: Error rates by endpoint

## Configuration

### Environment Variables

#### Auth Service
```bash
# Logging Configuration
LOG_LEVEL=info
KAFKA_LOGGING_ENABLED=true
KAFKA_BROKERS=kafka:29092
KAFKA_LOG_TOPIC=application-logs

# Service Information
SERVICE_VERSION=1.0.0
ENV=development
```

#### API Gateway
```bash
# Elasticsearch Configuration
ERP_LOGGING_ELASTICSEARCH_URLS=http://elasticsearch:9200
ERP_LOGGING_ELASTICSEARCH_INDEX_NAME=erp-api-gateway-logs

# Kafka Configuration
ERP_KAFKA_BROKERS=kafka:29092
ERP_LOGGING_LEVEL=info
ERP_LOGGING_FORMAT=json
```

### Docker Compose Configuration
```yaml
# Elasticsearch
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:7.17.3
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
  ports:
    - "9200:9200"

# Kibana
kibana:
  image: docker.elastic.co/kibana/kibana:7.17.3
  environment:
    ELASTICSEARCH_HOSTS: http://elasticsearch:9200
  ports:
    - "5601:5601"

# Kafka
kafka:
  image: confluentinc/cp-kafka:7.4.0
  environment:
    KAFKA_NODE_ID: 1
    KAFKA_PROCESS_ROLES: broker,controller
    KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:29092
  ports:
    - "9092:9092"

# Kafka UI
kafka-ui:
  image: provectuslabs/kafka-ui:latest
  environment:
    KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
  ports:
    - "8084:8080"
```

## Setup and Deployment

### 1. Infrastructure Setup
```bash
# Start infrastructure services
cd erp-suite-infrastructure
docker-compose --profile infrastructure up -d

# Wait for services to be ready
./scripts/setup-logging.sh
```

### 2. Service Deployment
```bash
# Start application services
docker-compose --profile full-stack up -d
```

### 3. Verification
```bash
# Check Elasticsearch
curl http://localhost:9200/_cluster/health

# Check Kibana
curl http://localhost:5601/api/status

# Check Kafka
curl http://localhost:8084/api/clusters
```

## Monitoring and Alerting

### Key Metrics to Monitor
1. **Log Volume**: Logs per minute/hour
2. **Error Rate**: Percentage of error logs
3. **Response Time**: API response latencies
4. **Service Availability**: Uptime and health checks
5. **Resource Usage**: CPU, memory, disk usage

### Alerting Rules
1. **High Error Rate**: >5% error rate for 5 minutes
2. **Service Down**: No logs from service for 2 minutes
3. **High Latency**: 95th percentile >1000ms for 5 minutes
4. **Disk Space**: Elasticsearch disk usage >80%
5. **Kafka Lag**: Consumer lag >1000 messages

## Best Practices

### 1. Log Structure
- Use consistent field names across services
- Include correlation IDs for request tracing
- Add contextual information (user ID, session ID)
- Use appropriate log levels
- Include stack traces for errors

### 2. Performance
- Use asynchronous logging to avoid blocking
- Implement log sampling for high-volume endpoints
- Use appropriate batch sizes for Kafka
- Monitor resource usage and adjust accordingly

### 3. Security
- Mask sensitive information (passwords, tokens)
- Use secure connections in production
- Implement proper access controls
- Regular security audits

### 4. Maintenance
- Regular index cleanup and optimization
- Monitor and adjust retention policies
- Update and patch logging infrastructure
- Regular backup of critical logs

## Troubleshooting

### Common Issues

#### 1. Elasticsearch Connection Issues
```bash
# Check Elasticsearch status
curl http://localhost:9200/_cluster/health

# Check logs
docker logs erp-suite-elasticsearch
```

#### 2. Kafka Connection Issues
```bash
# Check Kafka topics
kafka-topics.sh --list --bootstrap-server localhost:9092

# Check consumer lag
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups
```

#### 3. Missing Logs
- Check service configuration
- Verify Kafka topic creation
- Check Elasticsearch index templates
- Review service logs for errors

#### 4. High Resource Usage
- Adjust batch sizes and flush intervals
- Implement log sampling
- Optimize Elasticsearch mappings
- Scale infrastructure components

## Future Enhancements

1. **Distributed Tracing**: Implement OpenTelemetry for request tracing
2. **Machine Learning**: Anomaly detection for error patterns
3. **Real-time Alerting**: Integration with PagerDuty/Slack
4. **Log Aggregation**: Cross-service correlation and analysis
5. **Performance Optimization**: Advanced caching and indexing strategies