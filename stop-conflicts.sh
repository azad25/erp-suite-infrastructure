#!/bin/bash

echo "🔍 Checking for port conflicts..."

# Check and stop conflicting Docker containers
echo "Stopping any existing ERP containers..."
docker stop $(docker ps -q --filter "name=erp-suite") 2>/dev/null || true
docker rm $(docker ps -aq --filter "name=erp-suite") 2>/dev/null || true

# List what's using common ports
echo ""
echo "📋 Current port usage:"
echo "Port 5432 (PostgreSQL):"
lsof -i :5432 | head -5
echo ""
echo "Port 27017 (MongoDB):"
lsof -i :27017 | head -5
echo ""
echo "Port 6379 (Redis):"
lsof -i :6379 | head -5
echo ""
echo "Port 9092 (Kafka):"
lsof -i :9092 | head -5
echo ""

echo "✅ Conflict check complete. Now using alternative ports:"
echo "  PostgreSQL: 5433 (instead of 5432)"
echo "  MongoDB: 27018 (instead of 27017)"
echo "  Redis: 6380 (instead of 6379)"
echo "  Kafka: 9093 (instead of 9092)"
echo "  Zookeeper: 2182 (instead of 2181)"