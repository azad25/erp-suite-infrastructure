# ERP Suite Logging Setup Guide

## Quick Start

### 1. Start Infrastructure Services
```bash
cd erp-suite-infrastructure
docker-compose --profile infrastructure up -d
```

### 2. Setup Logging Components
```bash
# Wait for services to be ready and setup logging
./scripts/setup-logging.sh
```

### 3. Start Application Services
```bash
# Start all services including logging
docker-compose --profile full-stack up -d
```

### 4. Verify Setup
```bash
# Monitor logging health
./scripts/monitor-logging.sh
```

## Access URLs

- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601
- **Kafka UI**: http://localhost:8084
- **API Gateway**: http://localhost:8000
- **Auth Service**: http://localhost:8080

## Kibana Dashboard Setup

### 1. Create Index Patterns
1. Go to Kibana → Stack Management → Index Patterns
2. Create patterns for:
   - `erp-*-logs-*` (All logs)
   - `erp-*-request-*` (Request logs)
   - `erp-*-error-*` (Error logs)
   - `erp-*-event-*` (Event logs)

### 2. Import Dashboards
1. Go to Kibana → Stack Management → Saved Objects
2. Import the dashboard configurations from `config/kibana/dashboards.json`

### 3. Create Custom Visualizations
1. Go to Kibana → Visualize Library
2. Create visualizations for:
   - Request volume over time
   - Error rate by service
   - Response time percentiles
   - Top error messages
   - User activity patterns

## Monitoring and Alerting

### Key Metrics to Watch
1. **Log Volume**: Sudden drops may indicate service issues
2. **Error Rate**: Should be <5% under normal conditions
3. **Response Times**: 95th percentile should be <1000ms
4. **Disk Usage**: Elasticsearch disk usage should be <80%
5. **Kafka Lag**: Consumer lag should be minimal

### Setting Up Alerts
1. Use Kibana Watcher for log-based alerts
2. Monitor Elasticsearch cluster health
3. Set up Kafka consumer lag monitoring
4. Create dashboards for real-time monitoring

## Troubleshooting

### Common Issues

#### 1. Services Not Starting
```bash
# Check service logs
docker-compose logs elasticsearch
docker-compose logs kibana
docker-compose logs kafka

# Check service health
curl http://localhost:9200/_cluster/health
curl http://localhost:5601/api/status
```

#### 2. No Logs Appearing
```bash
# Check if indices are being created
curl http://localhost:9200/_cat/indices/erp-*

# Check Kafka topics
docker exec -it erp-suite-kafka kafka-topics.sh --list --bootstrap-server localhost:9092

# Check application logs
docker-compose logs auth-service
docker-compose logs api-gateway
```

#### 3. High Resource Usage
```bash
# Check resource usage
docker stats

# Adjust Elasticsearch heap size in docker-compose.yml
# Reduce log levels in application configuration
# Implement log sampling for high-volume endpoints
```

#### 4. Elasticsearch Issues
```bash
# Check cluster health
curl http://localhost:9200/_cluster/health

# Check node stats
curl http://localhost:9200/_nodes/stats

# Clear old indices if needed
curl -X DELETE http://localhost:9200/erp-*-2025.01.01
```

## Configuration

### Environment Variables

#### Global Settings
```bash
# Logging levels
LOG_LEVEL=info                    # debug, info, warn, error
ENV=development                   # development, staging, production

# Elasticsearch
ELASTICSEARCH_URL=http://elasticsearch:9200
ELASTICSEARCH_INDEX_PREFIX=erp

# Kafka
KAFKA_BROKERS=kafka:29092
KAFKA_LOGGING_ENABLED=true
```

#### Service-Specific Settings

**Auth Service**
```bash
KAFKA_LOG_TOPIC=application-logs
SERVICE_VERSION=1.0.0
```

**API Gateway**
```bash
ERP_LOGGING_ELASTICSEARCH_URLS=http://elasticsearch:9200
ERP_LOGGING_ELASTICSEARCH_INDEX_NAME=erp-api-gateway-logs
ERP_LOGGING_LEVEL=info
ERP_LOGGING_FORMAT=json
```

### Docker Compose Profiles

```bash
# Infrastructure only (databases, message queues, logging)
docker-compose --profile infrastructure up -d

# Full stack (infrastructure + applications)
docker-compose --profile full-stack up -d

# Development tools (pgAdmin, Kafka UI, etc.)
docker-compose --profile dev-tools up -d

# Logging services only
docker-compose --profile logging up -d
```

## Performance Tuning

### Elasticsearch Optimization
```yaml
# In docker-compose.yml
elasticsearch:
  environment:
    - "ES_JAVA_OPTS=-Xms2g -Xmx2g"
    - "bootstrap.memory_lock=false"
    - "cluster.routing.allocation.disk.threshold_enabled=false"
```

### Kafka Optimization
```yaml
# In docker-compose.yml
kafka:
  environment:
    - "KAFKA_HEAP_OPTS=-Xmx256m -Xms256m"
    - "KAFKA_LOG_RETENTION_HOURS=24"
    - "KAFKA_LOG_SEGMENT_BYTES=268435456"
```

### Application Optimization
```go
// In Go services
// Use buffered logging
logger := logging.NewLoggingService(logging.LoggingServiceConfig{
    KafkaConfig: logging.KafkaLoggerConfig{
        BatchSize:     100,
        FlushInterval: 5 * time.Second,
        BufferSize:    1000,
    },
})

// Implement log sampling for high-volume endpoints
if shouldSampleLog(requestPath) {
    logger.LogRequest(ctx, requestEntry)
}
```

## Security Considerations

### Production Setup
1. **Enable Elasticsearch Security**
   ```yaml
   elasticsearch:
     environment:
       - "xpack.security.enabled=true"
       - "xpack.security.authc.api_key.enabled=true"
   ```

2. **Secure Kafka**
   ```yaml
   kafka:
     environment:
       - "KAFKA_SECURITY_PROTOCOL=SASL_SSL"
       - "KAFKA_SASL_MECHANISM=PLAIN"
   ```

3. **Network Security**
   - Use internal networks for service communication
   - Implement proper firewall rules
   - Use TLS for external connections

4. **Data Privacy**
   - Mask sensitive data in logs
   - Implement log retention policies
   - Regular security audits

### Log Data Sanitization
```go
// Example of sensitive data masking
func maskSensitiveData(data map[string]interface{}) {
    sensitiveFields := []string{"password", "token", "secret", "key"}
    for _, field := range sensitiveFields {
        if _, exists := data[field]; exists {
            data[field] = "***MASKED***"
        }
    }
}
```

## Maintenance

### Regular Tasks
1. **Index Management**
   ```bash
   # Clean up old indices
   curl -X DELETE "http://localhost:9200/erp-*-$(date -d '30 days ago' +%Y.%m.%d)"
   
   # Optimize indices
   curl -X POST "http://localhost:9200/erp-*/_forcemerge?max_num_segments=1"
   ```

2. **Kafka Maintenance**
   ```bash
   # Check consumer lag
   kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups
   
   # Clean up old topics
   kafka-topics.sh --delete --topic old-topic --bootstrap-server localhost:9092
   ```

3. **Health Monitoring**
   ```bash
   # Run health checks
   ./scripts/monitor-logging.sh
   
   # Set up cron job for regular monitoring
   echo "0 */6 * * * /path/to/monitor-logging.sh" | crontab -
   ```

### Backup and Recovery
1. **Elasticsearch Snapshots**
   ```bash
   # Create snapshot repository
   curl -X PUT "http://localhost:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
   {
     "type": "fs",
     "settings": {
       "location": "/usr/share/elasticsearch/backup"
     }
   }'
   
   # Create snapshot
   curl -X PUT "http://localhost:9200/_snapshot/backup_repo/snapshot_$(date +%Y%m%d)"
   ```

2. **Kafka Backup**
   - Use Kafka Connect for data replication
   - Regular topic configuration backups
   - Consumer offset backups

## Advanced Features

### Custom Log Processors
```go
// Example custom log processor
type CustomLogProcessor struct {
    enricher *LogEnricher
    filter   *LogFilter
}

func (p *CustomLogProcessor) ProcessLog(entry LogEntry) LogEntry {
    // Enrich log with additional context
    enriched := p.enricher.Enrich(entry)
    
    // Apply filters
    if p.filter.ShouldProcess(enriched) {
        return enriched
    }
    
    return LogEntry{}
}
```

### Machine Learning Integration
```bash
# Enable Elasticsearch ML features
curl -X PUT "http://localhost:9200/_cluster/settings" -H 'Content-Type: application/json' -d'
{
  "persistent": {
    "xpack.ml.enabled": true
  }
}'

# Create anomaly detection job
curl -X PUT "http://localhost:9200/_ml/anomaly_detectors/error-rate-anomaly" -H 'Content-Type: application/json' -d'
{
  "analysis_config": {
    "bucket_span": "15m",
    "detectors": [
      {
        "function": "count",
        "by_field_name": "service"
      }
    ]
  },
  "data_description": {
    "time_field": "@timestamp"
  }
}'
```

## Support and Resources

### Documentation
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/7.17/index.html)
- [Kafka Documentation](https://kafka.apache.org/documentation/)

### Community Resources
- [Elastic Community](https://discuss.elastic.co/)
- [Kafka Community](https://kafka.apache.org/community)
- [ERP Suite GitHub Issues](https://github.com/your-org/erp-suite/issues)

### Getting Help
1. Check the troubleshooting section above
2. Review service logs for error messages
3. Run the monitoring script for health status
4. Create an issue with detailed error information