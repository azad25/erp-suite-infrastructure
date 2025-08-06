#!/bin/bash

# ERP Suite Logging Setup Script
# This script sets up Elasticsearch indices, templates, and Kibana dashboards

set -e

# Configuration
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://localhost:9200}"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1

    log_info "Waiting for $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            log_success "$service_name is ready!"
            return 0
        fi
        
        log_info "Attempt $attempt/$max_attempts: $service_name not ready yet..."
        sleep 5
        ((attempt++))
    done
    
    log_error "$service_name is not ready after $max_attempts attempts"
    return 1
}

# Create Elasticsearch index templates
setup_elasticsearch_templates() {
    log_info "Setting up Elasticsearch index templates..."
    
    # Create index lifecycle policy
    log_info "Creating index lifecycle policy..."
    curl -X PUT "$ELASTICSEARCH_URL/_ilm/policy/erp-logs-policy" \
        -H "Content-Type: application/json" \
        -d '{
            "policy": {
                "phases": {
                    "hot": {
                        "actions": {
                            "rollover": {
                                "max_size": "1GB",
                                "max_age": "1d"
                            }
                        }
                    },
                    "warm": {
                        "min_age": "2d",
                        "actions": {
                            "allocate": {
                                "number_of_replicas": 0
                            }
                        }
                    },
                    "cold": {
                        "min_age": "7d",
                        "actions": {
                            "allocate": {
                                "number_of_replicas": 0
                            }
                        }
                    },
                    "delete": {
                        "min_age": "30d",
                        "actions": {}
                    }
                }
            }
        }'
    
    # Create component templates
    log_info "Creating component templates..."
    
    # Base component template
    curl -X PUT "$ELASTICSEARCH_URL/_component_template/erp-logs-base" \
        -H "Content-Type: application/json" \
        -d '{
            "template": {
                "settings": {
                    "number_of_shards": 1,
                    "number_of_replicas": 0,
                    "index.refresh_interval": "5s",
                    "index.codec": "best_compression"
                },
                "mappings": {
                    "properties": {
                        "@timestamp": {
                            "type": "date",
                            "format": "strict_date_optional_time||epoch_millis"
                        },
                        "level": {
                            "type": "keyword"
                        },
                        "message": {
                            "type": "text",
                            "analyzer": "standard",
                            "fields": {
                                "keyword": {
                                    "type": "keyword",
                                    "ignore_above": 256
                                }
                            }
                        },
                        "service": {
                            "type": "keyword"
                        },
                        "component": {
                            "type": "keyword"
                        },
                        "environment": {
                            "type": "keyword"
                        },
                        "request_id": {
                            "type": "keyword"
                        },
                        "user_id": {
                            "type": "keyword"
                        },
                        "correlation_id": {
                            "type": "keyword"
                        }
                    }
                }
            }
        }'
    
    # Create index templates
    log_info "Creating index templates..."
    
    # General logs template
    curl -X PUT "$ELASTICSEARCH_URL/_index_template/erp-logs-template" \
        -H "Content-Type: application/json" \
        -d '{
            "index_patterns": ["erp-*-logs-*"],
            "priority": 100,
            "composed_of": ["erp-logs-base"],
            "template": {
                "settings": {
                    "index.lifecycle.name": "erp-logs-policy"
                }
            }
        }'
    
    # Request logs template
    curl -X PUT "$ELASTICSEARCH_URL/_index_template/erp-request-logs-template" \
        -H "Content-Type: application/json" \
        -d '{
            "index_patterns": ["erp-*-request-*"],
            "priority": 110,
            "composed_of": ["erp-logs-base"],
            "template": {
                "mappings": {
                    "properties": {
                        "method": {
                            "type": "keyword"
                        },
                        "path": {
                            "type": "keyword"
                        },
                        "status_code": {
                            "type": "integer"
                        },
                        "duration_ms": {
                            "type": "long"
                        },
                        "remote_ip": {
                            "type": "ip"
                        },
                        "user_agent": {
                            "type": "text",
                            "fields": {
                                "keyword": {
                                    "type": "keyword",
                                    "ignore_above": 512
                                }
                            }
                        },
                        "request_size_bytes": {
                            "type": "long"
                        },
                        "response_size_bytes": {
                            "type": "long"
                        }
                    }
                }
            }
        }'
    
    # Error logs template
    curl -X PUT "$ELASTICSEARCH_URL/_index_template/erp-error-logs-template" \
        -H "Content-Type: application/json" \
        -d '{
            "index_patterns": ["erp-*-error-*"],
            "priority": 120,
            "composed_of": ["erp-logs-base"],
            "template": {
                "settings": {
                    "index.refresh_interval": "1s"
                },
                "mappings": {
                    "properties": {
                        "error": {
                            "type": "text",
                            "analyzer": "standard"
                        },
                        "stack_trace": {
                            "type": "text",
                            "analyzer": "standard"
                        },
                        "context": {
                            "type": "object",
                            "dynamic": true
                        }
                    }
                }
            }
        }'
    
    log_success "Elasticsearch templates created successfully!"
}

# Create initial indices
create_initial_indices() {
    log_info "Creating initial indices..."
    
    # Create bootstrap indices for each service
    services=("auth-service" "api-gateway" "log-service")
    log_types=("logs" "request" "error" "event" "metric")
    
    for service in "${services[@]}"; do
        for log_type in "${log_types[@]}"; do
            index_name="erp-${service}-${log_type}-$(date +%Y.%m.%d)"
            
            log_info "Creating index: $index_name"
            curl -X PUT "$ELASTICSEARCH_URL/$index_name" \
                -H "Content-Type: application/json" \
                -d '{
                    "settings": {
                        "number_of_shards": 1,
                        "number_of_replicas": 0
                    }
                }' > /dev/null 2>&1 || true
        done
    done
    
    log_success "Initial indices created!"
}

# Setup Kibana index patterns
setup_kibana_index_patterns() {
    log_info "Setting up Kibana index patterns..."
    
    # Create index patterns
    patterns=(
        "erp-*-logs-*:ERP Logs"
        "erp-*-request-*:ERP Request Logs"
        "erp-*-error-*:ERP Error Logs"
        "erp-*-event-*:ERP Event Logs"
        "erp-*-metric-*:ERP Metric Logs"
    )
    
    for pattern_info in "${patterns[@]}"; do
        IFS=':' read -r pattern title <<< "$pattern_info"
        
        log_info "Creating index pattern: $pattern"
        curl -X POST "$KIBANA_URL/api/saved_objects/index-pattern" \
            -H "Content-Type: application/json" \
            -H "kbn-xsrf: true" \
            -d "{
                \"attributes\": {
                    \"title\": \"$pattern\",
                    \"timeFieldName\": \"@timestamp\"
                }
            }" > /dev/null 2>&1 || true
    done
    
    log_success "Kibana index patterns created!"
}

# Create Kafka topics for logging
create_kafka_topics() {
    log_info "Creating Kafka topics for logging..."
    
    # Check if Kafka container is running
    if ! docker compose ps kafka | grep -q "Up"; then
        log_warning "Kafka container is not running, skipping Kafka topic creation"
        return 0
    fi
    
    # Wait for Kafka to be ready
    log_info "Waiting for Kafka to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker compose exec -T kafka kafka-broker-api-versions --bootstrap-server localhost:29092 > /dev/null 2>&1; then
            log_success "Kafka is ready!"
            break
        fi
        
        if [ $((attempt % 5)) -eq 0 ]; then
            log_info "Attempt $attempt/$max_attempts: Kafka not ready yet..."
        fi
        sleep 5
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_error "Kafka is not ready after $max_attempts attempts, skipping topic creation"
        return 1
    fi
    
    # Topics for different log types
    topics=(
        "application-logs"
        "request-logs"
        "error-logs"
        "event-logs"
        "metric-logs"
        "auth-events"
        "api-events"
        "system-events"
        "dead-letter-queue"
        "log-aggregation"
        "performance-metrics"
        "security-events"
        "audit-logs"
    )
    
    log_info "Creating Kafka topics..."
    for topic in "${topics[@]}"; do
        log_info "Creating Kafka topic: $topic"
        
        # Use docker compose exec to run kafka-topics inside the container
        if docker compose exec -T kafka kafka-topics \
            --create \
            --bootstrap-server localhost:29092 \
            --topic "$topic" \
            --partitions 3 \
            --replication-factor 1 \
            --if-not-exists > /dev/null 2>&1; then
            log_success "✅ Topic '$topic' created successfully"
        else
            log_warning "⚠️  Failed to create topic '$topic' (may already exist)"
        fi
    done
    
    # List created topics to verify
    log_info "Verifying created topics..."
    if docker compose exec -T kafka kafka-topics --list --bootstrap-server localhost:29092 > /tmp/kafka_topics.txt 2>/dev/null; then
        topic_count=$(wc -l < /tmp/kafka_topics.txt)
        log_success "Kafka topics verification complete! Found $topic_count topics:"
        while IFS= read -r topic; do
            log_info "  • $topic"
        done < /tmp/kafka_topics.txt
        rm -f /tmp/kafka_topics.txt
    else
        log_warning "Could not verify Kafka topics"
    fi
    
    log_success "Kafka topics setup completed!"
}

# Main setup function
main() {
    log_info "Starting ERP Suite logging setup..."
    
    # Wait for services to be ready
    wait_for_service "$ELASTICSEARCH_URL" "Elasticsearch"
    wait_for_service "$KIBANA_URL/api/status" "Kibana"
    
    # Setup Elasticsearch
    setup_elasticsearch_templates
    create_initial_indices
    
    # Setup Kibana
    setup_kibana_index_patterns
    
    # Setup Kafka (optional)
    create_kafka_topics
    
    log_success "ERP Suite logging setup completed successfully!"
    log_info ""
    log_info "Access URLs:"
    log_info "  Elasticsearch: $ELASTICSEARCH_URL"
    log_info "  Kibana: $KIBANA_URL"
    log_info "  Kafka UI: http://localhost:8084 (if running)"
    log_info ""
    log_info "Next steps:"
    log_info "  1. Start your ERP services"
    log_info "  2. Check Kibana for incoming logs"
    log_info "  3. Create custom dashboards as needed"
}

# Run main function
main "$@"