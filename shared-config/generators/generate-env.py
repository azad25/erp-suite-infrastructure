#!/usr/bin/env python3
"""
ERP Suite Environment Generator for Python modules
Generates environment files from YAML configurations for Python-based services
"""

import argparse
import os
import sys
import yaml
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional


class ConfigLoader:
    """Loads and processes configuration files"""
    
    def __init__(self, workspace_root: Path):
        self.workspace_root = workspace_root
        self.config_dir = workspace_root / "erp-suite" / "shared-config"
    
    def load_environment_config(self, environment: str) -> Dict[str, Any]:
        """Load configuration for a specific environment"""
        config_file = self.config_dir / "environments" / f"{environment}.yaml"
        
        if not config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {config_file}")
        
        with open(config_file, 'r') as f:
            content = f.read()
        
        # Expand environment variables
        expanded_content = os.path.expandvars(content)
        
        return yaml.safe_load(expanded_content)


class EnvironmentGenerator:
    """Generates environment files for Python modules"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
    
    def generate_env_content(self, module: str, environment: str) -> str:
        """Generate environment file content for a Python module"""
        
        content = []
        
        # Header
        content.extend([
            f"# Generated environment file for {module} module",
            f"# Environment: {environment}",
            f"# Generated at: {datetime.now().isoformat()}",
            "",
            "# ============================================================================",
            "# ENVIRONMENT",
            "# ============================================================================",
            f"ENVIRONMENT={self.config['environment']['name']}",
            f"DEBUG={str(self.config['environment']['debug']).lower()}",
            f"LOG_LEVEL={self.config['environment']['log_level']}",
            f"HOT_RELOAD={str(self.config['environment']['hot_reload']).lower()}",
            "",
        ])
        
        # Database connections
        content.extend([
            "# ============================================================================",
            "# DATABASE CONNECTIONS",
            "# ============================================================================",
            "",
        ])
        
        # PostgreSQL
        pg_config = self.config['databases']['postgresql']
        content.extend([
            "# PostgreSQL",
            f"DB_HOST={pg_config['host']}",
            f"DB_PORT={pg_config['port']}",
            f"DB_USER={pg_config['username']}",
            f"DB_PASSWORD={pg_config['password']}",
            f"DB_SSL_MODE={pg_config['ssl_mode']}",
            f"DB_MAX_CONNECTIONS={pg_config['max_connections']}",
            f"DB_CONNECTION_TIMEOUT={pg_config['connection_timeout']}",
        ])
        
        # Module-specific database
        if module in pg_config['databases']:
            db_name = pg_config['databases'][module]
            content.append(f"DB_NAME={db_name}")
            db_url = f"postgresql://{pg_config['username']}:{pg_config['password']}@{pg_config['host']}:{pg_config['port']}/{db_name}?sslmode={pg_config['ssl_mode']}"
            content.append(f"DATABASE_URL={db_url}")
        
        content.append("")
        
        # MongoDB
        mongo_config = self.config['databases']['mongodb']
        content.extend([
            "# MongoDB",
            f"MONGODB_HOST={mongo_config['host']}",
            f"MONGODB_PORT={mongo_config['port']}",
            f"MONGODB_USER={mongo_config['username']}",
            f"MONGODB_PASSWORD={mongo_config['password']}",
            f"MONGODB_AUTH_SOURCE={mongo_config['auth_source']}",
            f"MONGODB_MAX_POOL_SIZE={mongo_config['max_pool_size']}",
        ])
        
        # MongoDB URL
        mongo_db = mongo_config['databases'].get('analytics', 'erp_analytics')
        mongo_url = f"mongodb://{mongo_config['username']}:{mongo_config['password']}@{mongo_config['host']}:{mongo_config['port']}/{mongo_db}?authSource={mongo_config['auth_source']}"
        content.append(f"MONGODB_URL={mongo_url}")
        content.append("")
        
        # Redis
        redis_config = self.config['databases']['redis']
        content.extend([
            "# Redis",
            f"REDIS_HOST={redis_config['host']}",
            f"REDIS_PORT={redis_config['port']}",
            f"REDIS_PASSWORD={redis_config['password']}",
            f"REDIS_MAX_CONNECTIONS={redis_config['max_connections']}",
        ])
        
        # Redis URL
        redis_db = redis_config['databases'].get('cache', 0)
        redis_url = f"redis://:{redis_config['password']}@{redis_config['host']}:{redis_config['port']}/{redis_db}"
        content.append(f"REDIS_URL={redis_url}")
        content.append("")
        
        # Qdrant (for AI module)
        if module == 'ai':
            qdrant_config = self.config['databases']['qdrant']
            content.extend([
                "# Qdrant Vector Database",
                f"QDRANT_HOST={qdrant_config['host']}",
                f"QDRANT_HTTP_PORT={qdrant_config['http_port']}",
                f"QDRANT_GRPC_PORT={qdrant_config['grpc_port']}",
            ])
            
            if qdrant_config.get('api_key'):
                content.append(f"QDRANT_API_KEY={qdrant_config['api_key']}")
            
            ssl_prefix = "https" if qdrant_config.get('ssl') else "http"
            qdrant_url = f"{ssl_prefix}://{qdrant_config['host']}:{qdrant_config['http_port']}"
            content.append(f"QDRANT_URL={qdrant_url}")
            content.append("")
        
        # Kafka
        kafka_config = self.config['messaging']['kafka']
        content.extend([
            "# ============================================================================",
            "# MESSAGE BROKERS",
            "# ============================================================================",
            "",
            "# Kafka",
            f"KAFKA_BROKERS={','.join(kafka_config['brokers'])}",
            f"KAFKA_SECURITY_PROTOCOL={kafka_config['security_protocol']}",
        ])
        
        if kafka_config.get('sasl_mechanism'):
            content.append(f"KAFKA_SASL_MECHANISM={kafka_config['sasl_mechanism']}")
        if kafka_config.get('sasl_username'):
            content.append(f"KAFKA_SASL_USERNAME={kafka_config['sasl_username']}")
        if kafka_config.get('sasl_password'):
            content.append(f"KAFKA_SASL_PASSWORD={kafka_config['sasl_password']}")
        
        # Kafka topics
        content.extend([
            "",
            "# Kafka Topics",
            f"KAFKA_TOPIC_AUTH={kafka_config['topics']['auth_events']}",
            f"KAFKA_TOPIC_USER={kafka_config['topics']['user_events']}",
            f"KAFKA_TOPIC_BUSINESS={kafka_config['topics']['business_events']}",
            f"KAFKA_TOPIC_SYSTEM={kafka_config['topics']['system_events']}",
            f"KAFKA_TOPIC_AI={kafka_config['topics']['ai_events']}",
            f"KAFKA_TOPIC_NOTIFICATIONS={kafka_config['topics']['notification_events']}",
        ])
        
        # Module-specific consumer group
        service_key = f"{module}_service"
        if service_key in kafka_config['consumer_groups']:
            content.append(f"KAFKA_CONSUMER_GROUP={kafka_config['consumer_groups'][service_key]}")
        
        content.append("")
        
        # Elasticsearch
        es_config = self.config['search']['elasticsearch']
        content.extend([
            "# ============================================================================",
            "# SEARCH & ANALYTICS",
            "# ============================================================================",
            "",
            "# Elasticsearch",
            f"ELASTICSEARCH_HOST={es_config['host']}",
            f"ELASTICSEARCH_PORT={es_config['port']}",
            f"ELASTICSEARCH_USERNAME={es_config['username']}",
            f"ELASTICSEARCH_PASSWORD={es_config['password']}",
            f"ELASTICSEARCH_USE_SSL={str(es_config['use_ssl']).lower()}",
            f"ELASTICSEARCH_VERIFY_CERTS={str(es_config['verify_certs']).lower()}",
        ])
        
        # Elasticsearch URL
        es_protocol = "https" if es_config['use_ssl'] else "http"
        es_url = f"{es_protocol}://{es_config['username']}:{es_config['password']}@{es_config['host']}:{es_config['port']}"
        content.append(f"ELASTICSEARCH_URL={es_url}")
        content.append("")
        
        # Monitoring
        content.extend([
            "# ============================================================================",
            "# MONITORING & OBSERVABILITY",
            "# ============================================================================",
            "",
        ])
        
        # Prometheus
        prom_config = self.config['monitoring']['prometheus']
        content.extend([
            "# Prometheus",
            f"PROMETHEUS_HOST={prom_config['host']}",
            f"PROMETHEUS_PORT={prom_config['port']}",
            f"PROMETHEUS_URL=http://{prom_config['host']}:{prom_config['port']}",
            "",
        ])
        
        # Jaeger
        jaeger_config = self.config['monitoring']['jaeger']
        content.extend([
            "# Jaeger",
            f"JAEGER_HOST={jaeger_config['host']}",
            f"JAEGER_PORT={jaeger_config['port']}",
            f"JAEGER_GRPC_PORT={jaeger_config['grpc_port']}",
            f"JAEGER_HTTP_PORT={jaeger_config['http_port']}",
            f"JAEGER_AGENT_HOST={jaeger_config['agent_host']}",
            f"JAEGER_AGENT_PORT={jaeger_config['agent_port']}",
            f"JAEGER_ENDPOINT=http://{jaeger_config['host']}:{jaeger_config['http_port']}/api/traces",
            "",
        ])
        
        # Logging
        log_config = self.config['monitoring']['logging']
        content.extend([
            "# Logging",
            f"LOG_LEVEL={log_config['level']}",
            f"LOG_FORMAT={log_config['format']}",
            f"LOG_OUTPUT={log_config['output']}",
            "",
        ])
        
        # Security
        content.extend([
            "# ============================================================================",
            "# SECURITY",
            "# ============================================================================",
            "",
        ])
        
        # JWT
        jwt_config = self.config['security']['jwt']
        content.extend([
            "# JWT",
            f"JWT_SECRET={jwt_config['secret']}",
            f"JWT_ACCESS_EXPIRY={jwt_config['access_token_expiry']}",
            f"JWT_REFRESH_EXPIRY={jwt_config['refresh_token_expiry']}",
            f"JWT_ALGORITHM={jwt_config['algorithm']}",
            "",
        ])
        
        # CORS
        cors_config = self.config['security']['cors']
        content.extend([
            "# CORS",
            f"ALLOWED_ORIGINS={','.join(cors_config['allowed_origins'])}",
            f"ALLOWED_METHODS={','.join(cors_config['allowed_methods'])}",
            f"ALLOWED_HEADERS={','.join(cors_config['allowed_headers'])}",
            f"ALLOW_CREDENTIALS={str(cors_config['allow_credentials']).lower()}",
            "",
        ])
        
        # External integrations
        content.extend([
            "# ============================================================================",
            "# EXTERNAL INTEGRATIONS",
            "# ============================================================================",
            "",
        ])
        
        # AI (for AI module)
        if module == 'ai':
            ai_config = self.config['external']['ai']['openai']
            content.extend([
                "# OpenAI",
                f"OPENAI_API_KEY={ai_config['api_key']}",
                f"OPENAI_MODEL={ai_config['model']}",
                f"OPENAI_MAX_TOKENS={ai_config['max_tokens']}",
                "",
            ])
        
        # Service-specific configurations
        content.extend([
            "# ============================================================================",
            "# SERVICE-SPECIFIC CONFIGURATIONS",
            "# ============================================================================",
            "",
            f"# Module identification",
            f"MODULE_NAME={module}",
            f"SERVICE_NAME={module}-service",
        ])
        
        # Service ports
        service_key = f"{module}_service"
        if service_key in self.config['services']:
            service_config = self.config['services'][service_key]
            if 'http_port' in service_config:
                content.append(f"HTTP_PORT={service_config['http_port']}")
            if 'grpc_port' in service_config:
                content.append(f"GRPC_PORT={service_config['grpc_port']}")
            if 'port' in service_config:
                content.append(f"PORT={service_config['port']}")
        
        return '\n'.join(content) + '\n'


def find_workspace_root() -> Path:
    """Find the workspace root directory"""
    current = Path.cwd()
    
    while current != current.parent:
        if (current / '.git').exists() or \
           (current / 'go.mod').exists() or \
           (current / 'package.json').exists() or \
           (current / 'pyproject.toml').exists():
            return current
        current = current.parent
    
    raise FileNotFoundError("Workspace root not found")


def main():
    parser = argparse.ArgumentParser(
        description="Generate environment files for Python modules"
    )
    parser.add_argument(
        "--env", 
        default="development",
        choices=["development", "staging", "production", "testing"],
        help="Environment (default: development)"
    )
    parser.add_argument(
        "--module",
        default="ai",
        choices=["ai", "notification"],
        help="Module name (default: ai)"
    )
    parser.add_argument(
        "--output",
        help="Output file path (default: .env.{module}.{environment})"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Verbose output"
    )
    
    args = parser.parse_args()
    
    try:
        if args.verbose:
            print(f"Generating environment file for module '{args.module}' in environment '{args.env}'")
        
        # Find workspace root
        workspace_root = find_workspace_root()
        
        # Load configuration
        config_loader = ConfigLoader(workspace_root)
        config = config_loader.load_environment_config(args.env)
        
        # Generate environment content
        generator = EnvironmentGenerator(config)
        env_content = generator.generate_env_content(args.module, args.env)
        
        # Determine output file
        output_file = args.output or f".env.{args.module}.{args.env}"
        
        # Write output file
        with open(output_file, 'w') as f:
            f.write(env_content)
        
        if args.verbose:
            print(f"Successfully generated environment file: {output_file}")
        
        print(f"Environment file generated: {output_file}")
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()