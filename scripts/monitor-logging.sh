#!/bin/bash

# ERP Suite Logging Monitoring Script
# This script monitors the health of all logging components

set -e

# Configuration
ELASTICSEARCH_URL="${ELASTICSEARCH_URL:-http://localhost:9200}"
KIBANA_URL="${KIBANA_URL:-http://localhost:5601}"
KAFKA_UI_URL="${KAFKA_UI_URL:-http://localhost:8084}"
KAFKA_BOOTSTRAP_SERVERS="${KAFKA_BOOTSTRAP_SERVERS:-localhost:9092}"

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

# Check service health
check_service_health() {
    local url=$1
    local service_name=$2
    local timeout=${3:-5}

    if curl -s -f --max-time $timeout "$url" > /dev/null 2>&1; then
        log_success "$service_name is healthy"
        return 0
    else
        log_error "$service_name is not responding"
        return 1
    fi
}

# Check Elasticsearch health
check_elasticsearch() {
    log_info "Checking Elasticsearch health..."
    
    if ! check_service_health "$ELASTICSEARCH_URL/_cluster/health" "Elasticsearch"; then
        return 1
    fi
    
    # Get cluster health details
    local health_response=$(curl -s "$ELASTICSEARCH_URL/_cluster/health" 2>/dev/null)
    local status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
    local nodes=$(echo "$health_response" | jq -r '.number_of_nodes' 2>/dev/null || echo "unknown")
    local indices=$(echo "$health_response" | jq -r '.active_primary_shards' 2>/dev/null || echo "unknown")
    
    log_info "  Status: $status"
    log_info "  Nodes: $nodes"
    log_info "  Active Shards: $indices"
    
    # Check for ERP indices
    log_info "Checking ERP log indices..."
    local indices_response=$(curl -s "$ELASTICSEARCH_URL/_cat/indices/erp-*?format=json" 2>/dev/null)
    local index_count=$(echo "$indices_response" | jq length 2>/dev/null || echo "0")
    
    if [ "$index_count" -gt 0 ]; then
        log_success "Found $index_count ERP log indices"
        echo "$indices_response" | jq -r '.[] | "  - \(.index): \(.docs.count) docs, \(.store.size)"' 2>/dev/null || true
    else
        log_warning "No ERP log indices found"
    fi
    
    return 0
}

# Check Kibana health
check_kibana() {
    log_info "Checking Kibana health..."
    
    if ! check_service_health "$KIBANA_URL/api/status" "Kibana"; then
        return 1
    fi
    
    # Check Kibana status details
    local status_response=$(curl -s "$KIBANA_URL/api/status" 2>/dev/null)
    local overall_status=$(echo "$status_response" | jq -r '.status.overall.state' 2>/dev/null || echo "unknown")
    
    log_info "  Overall Status: $overall_status"
    
    # Check for index patterns
    log_info "Checking ERP index patterns..."
    local patterns_response=$(curl -s -H "kbn-xsrf: true" "$KIBANA_URL/api/saved_objects/_find?type=index-pattern&search=erp-*" 2>/dev/null)
    local pattern_count=$(echo "$patterns_response" | jq '.saved_objects | length' 2>/dev/null || echo "0")
    
    if [ "$pattern_count" -gt 0 ]; then
        log_success "Found $pattern_count ERP index patterns"
    else
        log_warning "No ERP index patterns found"
    fi
    
    return 0
}

# Check Kafka health
check_kafka() {
    log_info "Checking Kafka health..."
    
    # Check if kafka-topics.sh is available
    if ! command -v kafka-topics.sh &> /dev/null; then
        log_warning "kafka-topics.sh not found, skipping detailed Kafka checks"
        return 0
    fi
    
    # List topics
    log_info "Checking Kafka topics..."
    local topics=$(kafka-topics.sh --list --bootstrap-server "$KAFKA_BOOTSTRAP_SERVERS" 2>/dev/null || echo "")
    
    if [ -n "$topics" ]; then
        log_success "Kafka is responding"
        
        # Check for ERP-related topics
        local erp_topics=$(echo "$topics" | grep -E "(application-logs|request-logs|error-logs|event-logs|auth-events)" || echo "")
        
        if [ -n "$erp_topics" ]; then
            log_success "Found ERP logging topics:"
            echo "$erp_topics" | while read -r topic; do
                if [ -n "$topic" ]; then
                    log_info "  - $topic"
                fi
            done
        else
            log_warning "No ERP logging topics found"
        fi
        
        # Check consumer groups
        log_info "Checking consumer groups..."
        local groups=$(kafka-consumer-groups.sh --list --bootstrap-server "$KAFKA_BOOTSTRAP_SERVERS" 2>/dev/null || echo "")
        local group_count=$(echo "$groups" | wc -l)
        
        if [ "$group_count" -gt 0 ] && [ -n "$groups" ]; then
            log_info "  Active consumer groups: $group_count"
        else
            log_info "  No active consumer groups"
        fi
        
    else
        log_error "Kafka is not responding"
        return 1
    fi
    
    return 0
}

# Check Kafka UI
check_kafka_ui() {
    log_info "Checking Kafka UI health..."
    
    if check_service_health "$KAFKA_UI_URL/api/clusters" "Kafka UI"; then
        # Get cluster information
        local clusters_response=$(curl -s "$KAFKA_UI_URL/api/clusters" 2>/dev/null)
        local cluster_count=$(echo "$clusters_response" | jq length 2>/dev/null || echo "0")
        
        log_info "  Connected clusters: $cluster_count"
        return 0
    else
        return 1
    fi
}

# Check log volume and patterns
check_log_patterns() {
    log_info "Analyzing log patterns..."
    
    # Check recent log volume
    local now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
    local one_hour_ago=$(date -u -d '1 hour ago' +"%Y-%m-%dT%H:%M:%S.000Z")
    
    local query='{
        "query": {
            "range": {
                "@timestamp": {
                    "gte": "'$one_hour_ago'",
                    "lte": "'$now'"
                }
            }
        },
        "aggs": {
            "services": {
                "terms": {
                    "field": "service",
                    "size": 10
                }
            },
            "log_levels": {
                "terms": {
                    "field": "level",
                    "size": 10
                }
            }
        },
        "size": 0
    }'
    
    local search_response=$(curl -s -X POST "$ELASTICSEARCH_URL/erp-*/_search" \
        -H "Content-Type: application/json" \
        -d "$query" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$search_response" ]; then
        local total_hits=$(echo "$search_response" | jq '.hits.total.value // .hits.total' 2>/dev/null || echo "0")
        
        log_info "Log volume in the last hour: $total_hits entries"
        
        # Show service breakdown
        log_info "Logs by service:"
        echo "$search_response" | jq -r '.aggregations.services.buckets[]? | "  - \(.key): \(.doc_count) logs"' 2>/dev/null || true
        
        # Show log level breakdown
        log_info "Logs by level:"
        echo "$search_response" | jq -r '.aggregations.log_levels.buckets[]? | "  - \(.key): \(.doc_count) logs"' 2>/dev/null || true
        
        # Check for high error rates
        local error_count=$(echo "$search_response" | jq -r '.aggregations.log_levels.buckets[] | select(.key == "error") | .doc_count' 2>/dev/null || echo "0")
        local error_rate=$(echo "scale=2; $error_count * 100 / $total_hits" | bc -l 2>/dev/null || echo "0")
        
        if (( $(echo "$error_rate > 5" | bc -l 2>/dev/null || echo "0") )); then
            log_warning "High error rate detected: ${error_rate}%"
        else
            log_success "Error rate is normal: ${error_rate}%"
        fi
    else
        log_warning "Could not retrieve log statistics"
    fi
}

# Check disk usage
check_disk_usage() {
    log_info "Checking disk usage..."
    
    # Check Elasticsearch disk usage
    local nodes_stats=$(curl -s "$ELASTICSEARCH_URL/_nodes/stats/fs" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$nodes_stats" ]; then
        local total_bytes=$(echo "$nodes_stats" | jq '.nodes | to_entries[0].value.fs.total.total_in_bytes' 2>/dev/null || echo "0")
        local available_bytes=$(echo "$nodes_stats" | jq '.nodes | to_entries[0].value.fs.total.available_in_bytes' 2>/dev/null || echo "0")
        
        if [ "$total_bytes" -gt 0 ]; then
            local used_bytes=$((total_bytes - available_bytes))
            local usage_percent=$(echo "scale=1; $used_bytes * 100 / $total_bytes" | bc -l 2>/dev/null || echo "0")
            
            log_info "Elasticsearch disk usage: ${usage_percent}%"
            
            if (( $(echo "$usage_percent > 80" | bc -l 2>/dev/null || echo "0") )); then
                log_warning "High disk usage detected: ${usage_percent}%"
            fi
        fi
    fi
}

# Generate health report
generate_report() {
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    echo ""
    log_info "=== ERP Suite Logging Health Report ==="
    log_info "Generated: $timestamp"
    echo ""
    
    local overall_health=0
    
    # Check all components
    check_elasticsearch || overall_health=1
    echo ""
    
    check_kibana || overall_health=1
    echo ""
    
    check_kafka || overall_health=1
    echo ""
    
    check_kafka_ui || overall_health=1
    echo ""
    
    check_log_patterns
    echo ""
    
    check_disk_usage
    echo ""
    
    # Overall status
    if [ $overall_health -eq 0 ]; then
        log_success "=== Overall Status: HEALTHY ==="
    else
        log_error "=== Overall Status: ISSUES DETECTED ==="
    fi
    
    echo ""
    log_info "Access URLs:"
    log_info "  Elasticsearch: $ELASTICSEARCH_URL"
    log_info "  Kibana: $KIBANA_URL"
    log_info "  Kafka UI: $KAFKA_UI_URL"
    
    return $overall_health
}

# Main function
main() {
    # Check if required tools are available
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq is not installed, some features will be limited"
    fi
    
    if ! command -v bc &> /dev/null; then
        log_warning "bc is not installed, percentage calculations will be limited"
    fi
    
    # Generate health report
    generate_report
    
    exit $?
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "ERP Suite Logging Monitoring Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --continuous   Run continuously (every 60 seconds)"
        echo ""
        echo "Environment Variables:"
        echo "  ELASTICSEARCH_URL    Elasticsearch URL (default: http://localhost:9200)"
        echo "  KIBANA_URL          Kibana URL (default: http://localhost:5601)"
        echo "  KAFKA_UI_URL        Kafka UI URL (default: http://localhost:8084)"
        echo "  KAFKA_BOOTSTRAP_SERVERS  Kafka servers (default: localhost:9092)"
        exit 0
        ;;
    --continuous)
        log_info "Starting continuous monitoring (Ctrl+C to stop)..."
        while true; do
            main
            log_info "Waiting 60 seconds before next check..."
            sleep 60
            echo ""
        done
        ;;
    *)
        main
        ;;
esac