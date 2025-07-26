#!/usr/bin/env node
/**
 * ERP Suite Environment Generator for Node.js modules
 * Generates environment files from YAML configurations for Node.js-based services
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const { program } = require('commander');

class ConfigLoader {
    constructor(workspaceRoot) {
        this.workspaceRoot = workspaceRoot;
        this.configDir = path.join(workspaceRoot, 'erp-suite', 'shared-config');
    }

    loadEnvironmentConfig(environment) {
        const configFile = path.join(this.configDir, 'environments', `${environment}.yaml`);
        
        if (!fs.existsSync(configFile)) {
            throw new Error(`Configuration file not found: ${configFile}`);
        }

        let content = fs.readFileSync(configFile, 'utf8');
        
        // Simple environment variable expansion
        content = content.replace(/\$\{([^}]+)\}/g, (match, varName) => {
            const [name, defaultValue] = varName.split(':');
            return process.env[name] || defaultValue || match;
        });

        return yaml.load(content);
    }
}

class EnvironmentGenerator {
    constructor(config) {
        this.config = config;
    }

    generateEnvContent(module, environment) {
        const content = [];

        // Header
        content.push(
            `# Generated environment file for ${module} module`,
            `# Environment: ${environment}`,
            `# Generated at: ${new Date().toISOString()}`,
            '',
            '# ============================================================================',
            '# ENVIRONMENT',
            '# ============================================================================',
            `ENVIRONMENT=${this.config.environment.name}`,
            `DEBUG=${this.config.environment.debug}`,
            `LOG_LEVEL=${this.config.environment.log_level}`,
            `HOT_RELOAD=${this.config.environment.hot_reload}`,
            ''
        );

        // Node.js specific
        content.push(
            '# Node.js Environment',
            `NODE_ENV=${environment === 'production' ? 'production' : 'development'}`,
            ''
        );

        // Database connections
        content.push(
            '# ============================================================================',
            '# DATABASE CONNECTIONS',
            '# ============================================================================',
            ''
        );

        // PostgreSQL
        const pgConfig = this.config.databases.postgresql;
        content.push(
            '# PostgreSQL',
            `DB_HOST=${pgConfig.host}`,
            `DB_PORT=${pgConfig.port}`,
            `DB_USER=${pgConfig.username}`,
            `DB_PASSWORD=${pgConfig.password}`,
            `DB_SSL_MODE=${pgConfig.ssl_mode}`,
            `DB_MAX_CONNECTIONS=${pgConfig.max_connections}`,
            `DB_CONNECTION_TIMEOUT=${pgConfig.connection_timeout}`
        );

        // Module-specific database
        if (pgConfig.databases[module]) {
            const dbName = pgConfig.databases[module];
            content.push(`DB_NAME=${dbName}`);
            const dbUrl = `postgresql://${pgConfig.username}:${pgConfig.password}@${pgConfig.host}:${pgConfig.port}/${dbName}?sslmode=${pgConfig.ssl_mode}`;
            content.push(`DATABASE_URL=${dbUrl}`);
        }

        content.push('');

        // MongoDB
        const mongoConfig = this.config.databases.mongodb;
        content.push(
            '# MongoDB',
            `MONGODB_HOST=${mongoConfig.host}`,
            `MONGODB_PORT=${mongoConfig.port}`,
            `MONGODB_USER=${mongoConfig.username}`,
            `MONGODB_PASSWORD=${mongoConfig.password}`,
            `MONGODB_AUTH_SOURCE=${mongoConfig.auth_source}`,
            `MONGODB_MAX_POOL_SIZE=${mongoConfig.max_pool_size}`
        );

        // MongoDB URL
        const mongoDb = mongoConfig.databases.analytics || 'erp_analytics';
        const mongoUrl = `mongodb://${mongoConfig.username}:${mongoConfig.password}@${mongoConfig.host}:${mongoConfig.port}/${mongoDb}?authSource=${mongoConfig.auth_source}`;
        content.push(`MONGODB_URL=${mongoUrl}`, '');

        // Redis
        const redisConfig = this.config.databases.redis;
        content.push(
            '# Redis',
            `REDIS_HOST=${redisConfig.host}`,
            `REDIS_PORT=${redisConfig.port}`,
            `REDIS_PASSWORD=${redisConfig.password}`,
            `REDIS_MAX_CONNECTIONS=${redisConfig.max_connections}`
        );

        // Redis URL
        const redisDb = redisConfig.databases.cache || 0;
        const redisUrl = `redis://:${redisConfig.password}@${redisConfig.host}:${redisConfig.port}/${redisDb}`;
        content.push(`REDIS_URL=${redisUrl}`, '');

        // WebSocket configuration (for frontend modules)
        if (['frontend', 'admin', 'websocket'].includes(module)) {
            const wsConfig = this.config.realtime.websocket;
            content.push(
                '# ============================================================================',
                '# REAL-TIME COMMUNICATION',
                '# ============================================================================',
                '',
                '# WebSocket',
                `WEBSOCKET_HOST=${wsConfig.host}`,
                `WEBSOCKET_PORT=${wsConfig.port}`,
                `WEBSOCKET_PATH=${wsConfig.path}`
            );

            const wsProtocol = wsConfig.ssl ? 'wss' : 'ws';
            const wsUrl = `${wsProtocol}://${wsConfig.host}:${wsConfig.port}`;
            content.push(
                `WEBSOCKET_URL=${wsUrl}`,
                `WEBSOCKET_CORS_ORIGINS=${wsConfig.cors_origins.join(',')}`,
                ''
            );
        }

        // Security
        content.push(
            '# ============================================================================',
            '# SECURITY',
            '# ============================================================================',
            ''
        );

        // JWT
        const jwtConfig = this.config.security.jwt;
        content.push(
            '# JWT',
            `JWT_SECRET=${jwtConfig.secret}`,
            `JWT_ACCESS_EXPIRY=${jwtConfig.access_token_expiry}`,
            `JWT_REFRESH_EXPIRY=${jwtConfig.refresh_token_expiry}`,
            `JWT_ALGORITHM=${jwtConfig.algorithm}`,
            ''
        );

        // CORS
        const corsConfig = this.config.security.cors;
        content.push(
            '# CORS',
            `ALLOWED_ORIGINS=${corsConfig.allowed_origins.join(',')}`,
            `ALLOWED_METHODS=${corsConfig.allowed_methods.join(',')}`,
            `ALLOWED_HEADERS=${corsConfig.allowed_headers.join(',')}`,
            `ALLOW_CREDENTIALS=${corsConfig.allow_credentials}`,
            ''
        );

        // Service URLs (for frontend modules)
        if (['frontend', 'admin'].includes(module)) {
            content.push(
                '# ============================================================================',
                '# SERVICE URLS',
                '# ============================================================================',
                ''
            );

            // API URLs
            const authService = this.config.services.auth_service;
            const crmService = this.config.services.crm_service;
            const hrmService = this.config.services.hrm_service;
            const financeService = this.config.services.finance_service;
            const inventoryService = this.config.services.inventory_service;
            const projectsService = this.config.services.projects_service;
            const aiService = this.config.services.ai_service;

            content.push(
                '# API Service URLs',
                `NEXT_PUBLIC_AUTH_API_URL=http://${authService.host}:${authService.http_port}`,
                `NEXT_PUBLIC_CRM_API_URL=http://${crmService.host}:${crmService.http_port}`,
                `NEXT_PUBLIC_HRM_API_URL=http://${hrmService.host}:${hrmService.http_port}`,
                `NEXT_PUBLIC_FINANCE_API_URL=http://${financeService.host}:${financeService.http_port}`,
                `NEXT_PUBLIC_INVENTORY_API_URL=http://${inventoryService.host}:${inventoryService.http_port}`,
                `NEXT_PUBLIC_PROJECTS_API_URL=http://${projectsService.host}:${projectsService.http_port}`,
                `NEXT_PUBLIC_AI_API_URL=http://${aiService.host}:${aiService.http_port}`,
                ''
            );

            // WebSocket URL for frontend
            const wsConfig = this.config.realtime.websocket;
            const wsProtocol = wsConfig.ssl ? 'wss' : 'ws';
            content.push(
                '# Real-time Communication',
                `NEXT_PUBLIC_WEBSOCKET_URL=${wsProtocol}://${wsConfig.host}:${wsConfig.port}`,
                ''
            );
        }

        // External integrations
        content.push(
            '# ============================================================================',
            '# EXTERNAL INTEGRATIONS',
            '# ============================================================================',
            ''
        );

        // Email
        const emailConfig = this.config.external.email;
        content.push(
            '# Email',
            `EMAIL_PROVIDER=${emailConfig.provider}`,
            `SMTP_HOST=${emailConfig.smtp_host}`,
            `SMTP_PORT=${emailConfig.smtp_port}`,
            `SMTP_USERNAME=${emailConfig.smtp_username}`,
            `SMTP_PASSWORD=${emailConfig.smtp_password}`,
            `EMAIL_FROM_ADDRESS=${emailConfig.from_address}`
        );

        if (emailConfig.use_tls !== undefined) {
            content.push(`SMTP_USE_TLS=${emailConfig.use_tls}`);
        }

        content.push('');

        // Storage
        const storageConfig = this.config.external.storage;
        content.push(
            '# Storage',
            `STORAGE_PROVIDER=${storageConfig.provider}`
        );

        if (storageConfig.local_path) {
            content.push(`STORAGE_LOCAL_PATH=${storageConfig.local_path}`);
        }

        if (storageConfig.s3_bucket) {
            content.push(
                `S3_BUCKET=${storageConfig.s3_bucket}`,
                `S3_REGION=${storageConfig.s3_region}`,
                `S3_ACCESS_KEY=${storageConfig.s3_access_key}`,
                `S3_SECRET_KEY=${storageConfig.s3_secret_key}`
            );
        }

        content.push('');

        // Payment (for frontend modules)
        if (['frontend', 'admin'].includes(module)) {
            const stripeConfig = this.config.external.payment.stripe;
            content.push(
                '# Payment (Stripe)',
                `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=${stripeConfig.publishable_key}`,
                `STRIPE_SECRET_KEY=${stripeConfig.secret_key}`,
                `STRIPE_WEBHOOK_SECRET=${stripeConfig.webhook_secret}`,
                ''
            );
        }

        // Feature flags (for frontend modules)
        if (['frontend', 'admin'].includes(module)) {
            content.push(
                '# ============================================================================',
                '# FEATURE FLAGS',
                '# ============================================================================',
                ''
            );

            Object.entries(this.config.feature_flags).forEach(([flag, enabled]) => {
                content.push(`NEXT_PUBLIC_FEATURE_${flag.toUpperCase()}=${enabled}`);
            });

            content.push('');
        }

        // Module-specific configurations
        content.push(
            '# ============================================================================',
            '# MODULE-SPECIFIC CONFIGURATIONS',
            '# ============================================================================',
            '',
            '# Module identification',
            `MODULE_NAME=${module}`,
            `SERVICE_NAME=${module}-service`
        );

        // Service ports
        const serviceKey = `${module}_service`;
        if (this.config.services[serviceKey]) {
            const serviceConfig = this.config.services[serviceKey];
            if (serviceConfig.http_port) {
                content.push(`HTTP_PORT=${serviceConfig.http_port}`);
            }
            if (serviceConfig.grpc_port) {
                content.push(`GRPC_PORT=${serviceConfig.grpc_port}`);
            }
            if (serviceConfig.port) {
                content.push(`PORT=${serviceConfig.port}`);
            }
        } else if (this.config.services[module]) {
            const serviceConfig = this.config.services[module];
            if (serviceConfig.port) {
                content.push(`PORT=${serviceConfig.port}`);
            }
        }

        // Frontend-specific configurations
        if (['frontend', 'admin'].includes(module)) {
            content.push(
                '',
                '# Next.js specific',
                `NEXTAUTH_URL=http://localhost:${this.config.services[module]?.port || 3000}`,
                `NEXTAUTH_SECRET=${jwtConfig.secret}`
            );
        }

        return content.join('\n') + '\n';
    }
}

function findWorkspaceRoot() {
    let current = process.cwd();
    
    while (current !== path.dirname(current)) {
        if (fs.existsSync(path.join(current, '.git')) ||
            fs.existsSync(path.join(current, 'go.mod')) ||
            fs.existsSync(path.join(current, 'package.json'))) {
            return current;
        }
        current = path.dirname(current);
    }
    
    throw new Error('Workspace root not found');
}

function main() {
    program
        .option('--env <environment>', 'Environment (development, staging, production, testing)', 'development')
        .option('--module <module>', 'Module name (frontend, admin, websocket)', 'frontend')
        .option('--output <file>', 'Output file path (default: .env.{module}.{environment})')
        .option('--verbose', 'Verbose output')
        .parse();

    const options = program.opts();

    try {
        if (options.verbose) {
            console.log(`Generating environment file for module '${options.module}' in environment '${options.env}'`);
        }

        // Find workspace root
        const workspaceRoot = findWorkspaceRoot();

        // Load configuration
        const configLoader = new ConfigLoader(workspaceRoot);
        const config = configLoader.loadEnvironmentConfig(options.env);

        // Generate environment content
        const generator = new EnvironmentGenerator(config);
        const envContent = generator.generateEnvContent(options.module, options.env);

        // Determine output file
        const outputFile = options.output || `.env.${options.module}.${options.env}`;

        // Write output file
        fs.writeFileSync(outputFile, envContent);

        if (options.verbose) {
            console.log(`Successfully generated environment file: ${outputFile}`);
        }

        console.log(`Environment file generated: ${outputFile}`);

    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
}

// Check if required dependencies are available
try {
    require('js-yaml');
    require('commander');
} catch (error) {
    console.error('Missing required dependencies. Please install them with:');
    console.error('npm install js-yaml commander');
    process.exit(1);
}

if (require.main === module) {
    main();
}

module.exports = { ConfigLoader, EnvironmentGenerator, findWorkspaceRoot };