const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');
const consul = require('consul')({
  host: process.env.CONSUL_HOST || 'grpc-registry',
  port: process.env.CONSUL_PORT || 8500,
  promisify: true
});

// gRPC client configuration
const GRPC_OPTIONS = {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
  'grpc.keepalive_time_ms': 30000,
  'grpc.keepalive_timeout_ms': 5000,
  'grpc.keepalive_permit_without_calls': true,
  'grpc.http2.max_pings_without_data': 0,
  'grpc.http2.min_time_between_pings_ms': 10000,
  'grpc.http2.min_ping_interval_without_data_ms': 300000
};

// Service definitions
const SERVICES = {
  auth: {
    protoPath: path.join(__dirname, '../proto/auth.proto'),
    packageName: 'auth',
    serviceName: 'AuthService',
    defaultAddress: process.env.GRPC_AUTH_SERVICE || 'auth-service:50051'
  },
  crm: {
    protoPath: path.join(__dirname, '../proto/crm.proto'),
    packageName: 'crm',
    serviceName: 'CRMService',
    defaultAddress: process.env.GRPC_CRM_SERVICE || 'crm-service:50052'
  },
  hrm: {
    protoPath: path.join(__dirname, '../proto/hrm.proto'),
    packageName: 'hrm',
    serviceName: 'HRMService',
    defaultAddress: process.env.GRPC_HRM_SERVICE || 'hrm-service:50053'
  },
  finance: {
    protoPath: path.join(__dirname, '../proto/finance.proto'),
    packageName: 'finance',
    serviceName: 'FinanceService',
    defaultAddress: process.env.GRPC_FINANCE_SERVICE || 'finance-service:50054'
  },
  inventory: {
    protoPath: path.join(__dirname, '../proto/inventory.proto'),
    packageName: 'inventory',
    serviceName: 'InventoryService',
    defaultAddress: process.env.GRPC_INVENTORY_SERVICE || 'inventory-service:50055'
  },
  projects: {
    protoPath: path.join(__dirname, '../proto/projects.proto'),
    packageName: 'projects',
    serviceName: 'ProjectService',
    defaultAddress: process.env.GRPC_PROJECT_SERVICE || 'project-service:50056'
  }
};

class GrpcClientManager {
  constructor() {
    this.clients = {};
    this.healthChecks = {};
    this.circuitBreakers = {};
  }

  async initialize() {
    for (const [serviceName, config] of Object.entries(SERVICES)) {
      await this.createClient(serviceName, config);
    }
    
    // Start health checking (disabled for infrastructure-only mode)
    // this.startHealthChecking();
    
    return this.clients;
  }

  async createClient(serviceName, config) {
    try {
      // Load proto definition
      const packageDefinition = protoLoader.loadSync(config.protoPath, GRPC_OPTIONS);
      const protoDescriptor = grpc.loadPackageDefinition(packageDefinition);
      
      // Get service address (with service discovery fallback)
      const serviceAddress = await this.getServiceAddress(serviceName, config.defaultAddress);
      
      // Create gRPC client with connection pooling
      // Access the service client using the package structure
      let ServiceClient;
      if (protoDescriptor[config.packageName] && protoDescriptor[config.packageName][config.serviceName]) {
        ServiceClient = protoDescriptor[config.packageName][config.serviceName];
      } else if (protoDescriptor[config.serviceName]) {
        ServiceClient = protoDescriptor[config.serviceName];
      } else {
        // Fallback: try to find the service in any available package
        const availablePackages = Object.keys(protoDescriptor);
        console.log(`Available packages for ${serviceName}:`, availablePackages);
        
        for (const packageName of availablePackages) {
          if (protoDescriptor[packageName][config.serviceName]) {
            ServiceClient = protoDescriptor[packageName][config.serviceName];
            break;
          }
        }
        
        if (!ServiceClient) {
          throw new Error(`Service ${config.serviceName} not found in proto definition. Available packages: ${availablePackages.join(', ')}`);
        }
      }
      
      const client = new ServiceClient(serviceAddress, grpc.credentials.createInsecure(), {
        'grpc.max_connection_idle_ms': 300000,
        'grpc.max_connection_age_ms': 600000,
        'grpc.max_connection_age_grace_ms': 30000,
        'grpc.http2.max_pings_without_data': 0,
        'grpc.keepalive_time_ms': 30000,
        'grpc.keepalive_timeout_ms': 5000
      });

      // Wrap client with circuit breaker and retry logic
      this.clients[serviceName] = this.wrapClientWithResilience(client, serviceName);
      
      console.log(`✅ gRPC client for ${serviceName} connected to ${serviceAddress}`);
    } catch (error) {
      console.error(`❌ Failed to create gRPC client for ${serviceName}:`, error.message);
      // Create a fallback client that returns errors
      this.clients[serviceName] = this.createFallbackClient(serviceName);
    }
  }

  async getServiceAddress(serviceName, defaultAddress) {
    try {
      // Try service discovery first with timeout
      const services = await Promise.race([
        consul.health.service({
          service: `erp-${serviceName}-service`,
          passing: true
        }),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Service discovery timeout')), 5000)
        )
      ]);
      
      if (services && services.length > 0) {
        const service = services[Math.floor(Math.random() * services.length)];
        console.log(`✅ Service discovery found ${serviceName} at ${service.Service.Address}:${service.Service.Port}`);
        return `${service.Service.Address}:${service.Service.Port}`;
      }
    } catch (error) {
      console.warn(`Service discovery failed for ${serviceName}, using default address:`, error.message);
    }
    
    return defaultAddress;
  }

  wrapClientWithResilience(client, serviceName) {
    const circuitBreaker = {
      failures: 0,
      lastFailureTime: null,
      state: 'CLOSED', // CLOSED, OPEN, HALF_OPEN
      threshold: 5,
      timeout: 60000 // 1 minute
    };

    this.circuitBreakers[serviceName] = circuitBreaker;

    return new Proxy(client, {
      get: (target, prop) => {
        if (typeof target[prop] === 'function') {
          return this.wrapMethodWithResilience(target[prop].bind(target), serviceName, prop);
        }
        return target[prop];
      }
    });
  }

  wrapMethodWithResilience(method, serviceName, methodName) {
    return (request, callback) => {
      const circuitBreaker = this.circuitBreakers[serviceName];
      
      // Check circuit breaker state
      if (circuitBreaker.state === 'OPEN') {
        const timeSinceLastFailure = Date.now() - circuitBreaker.lastFailureTime;
        if (timeSinceLastFailure < circuitBreaker.timeout) {
          return callback(new Error(`Circuit breaker OPEN for ${serviceName}`));
        } else {
          circuitBreaker.state = 'HALF_OPEN';
        }
      }

      // Add timeout and retry logic
      const deadline = new Date(Date.now() + 10000); // 10 second timeout
      
      const callWithRetry = (attempt = 1) => {
        method(request, { deadline }, (error, response) => {
          if (error) {
            console.error(`gRPC call failed: ${serviceName}.${methodName}`, error.message);
            
            // Update circuit breaker
            circuitBreaker.failures++;
            circuitBreaker.lastFailureTime = Date.now();
            
            if (circuitBreaker.failures >= circuitBreaker.threshold) {
              circuitBreaker.state = 'OPEN';
              console.warn(`Circuit breaker OPEN for ${serviceName}`);
            }

            // Retry logic for transient errors
            if (attempt < 3 && this.isRetryableError(error)) {
              console.log(`Retrying ${serviceName}.${methodName} (attempt ${attempt + 1})`);
              setTimeout(() => callWithRetry(attempt + 1), Math.pow(2, attempt) * 1000);
              return;
            }
            
            callback(error);
          } else {
            // Reset circuit breaker on success
            circuitBreaker.failures = 0;
            circuitBreaker.state = 'CLOSED';
            callback(null, response);
          }
        });
      };

      callWithRetry();
    };
  }

  isRetryableError(error) {
    const retryableCodes = [
      grpc.status.UNAVAILABLE,
      grpc.status.DEADLINE_EXCEEDED,
      grpc.status.RESOURCE_EXHAUSTED
    ];
    return retryableCodes.includes(error.code);
  }

  createFallbackClient(serviceName) {
    return new Proxy({}, {
      get: () => {
        return (request, callback) => {
          callback(new Error(`${serviceName} service unavailable`));
        };
      }
    });
  }

  startHealthChecking() {
    setInterval(async () => {
      for (const [serviceName, client] of Object.entries(this.clients)) {
        try {
          // Perform health check if the service supports it
          if (client.healthCheck) {
            client.healthCheck({}, (error, response) => {
              if (error) {
                console.warn(`Health check failed for ${serviceName}:`, error.message);
              } else {
                console.log(`✅ ${serviceName} service healthy`);
              }
            });
          }
        } catch (error) {
          console.error(`Health check error for ${serviceName}:`, error.message);
        }
      }
    }, 30000); // Check every 30 seconds
  }

  async shutdown() {
    for (const [serviceName, client] of Object.entries(this.clients)) {
      try {
        if (client.close) {
          client.close();
        }
        console.log(`🔌 Closed gRPC client for ${serviceName}`);
      } catch (error) {
        console.error(`Error closing ${serviceName} client:`, error.message);
      }
    }
  }
}

// Singleton instance
const grpcClientManager = new GrpcClientManager();

async function createGrpcClients() {
  return await grpcClientManager.initialize();
}

module.exports = {
  createGrpcClients,
  grpcClientManager
};