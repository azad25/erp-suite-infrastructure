const express = require('express');
const { ApolloServer } = require('apollo-server-express');
const { createServer } = require('http');
const { execute, subscribe } = require('graphql');
const { SubscriptionServer } = require('subscriptions-transport-ws');
const { makeExecutableSchema } = require('@graphql-tools/schema');
const Redis = require('ioredis');
const { RedisPubSub } = require('graphql-redis-subscriptions');
const compression = require('compression');
const helmet = require('helmet');
const cors = require('cors');
const depthLimit = require('graphql-depth-limit');
const costAnalysis = require('graphql-query-complexity');
const { shield, rule, and, or } = require('graphql-shield');
const pino = require('pino');

// Import GraphQL schema and resolvers
const typeDefs = require('./schema');
const resolvers = require('./resolvers');
const { createDataLoaders } = require('./dataloaders');
const { createGrpcClients } = require('./grpc-clients');

// Logger setup
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  prettyPrint: process.env.NODE_ENV === 'development'
});

// Redis setup for caching and subscriptions
const redis = new Redis(process.env.REDIS_URL);
const pubsub = new RedisPubSub({
  publisher: new Redis(process.env.REDIS_URL),
  subscriber: new Redis(process.env.REDIS_URL)
});

async function startServer() {
  const app = express();
  
  // Security middleware
  app.use(helmet({
    contentSecurityPolicy: process.env.NODE_ENV === 'production' ? undefined : false,
  }));
  app.use(cors());
  app.use(compression());

  // Health check endpoint
  app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  });

  // Initialize gRPC clients
  const grpcClients = await createGrpcClients();
  
  // Create executable schema
  const schema = makeExecutableSchema({
    typeDefs,
    resolvers,
  });

  // GraphQL server configuration
  const server = new ApolloServer({
    schema,
    context: async ({ req, connection }) => {
      if (connection) {
        // WebSocket connection context
        return {
          ...connection.context,
          pubsub,
          redis,
          grpcClients,
          logger
        };
      }
      
      // HTTP request context
      const dataLoaders = createDataLoaders(grpcClients, redis);
      
      return {
        req,
        pubsub,
        redis,
        grpcClients,
        dataLoaders,
        logger,
        user: req.user // Set by auth middleware
      };
    },
    plugins: [
      // Query complexity analysis
      {
        requestDidStart() {
          return {
            didResolveOperation({ request, document }) {
              const complexity = costAnalysis.getComplexity({
                estimators: [
                  costAnalysis.fieldExtensionsEstimator(),
                  costAnalysis.simpleEstimator({ defaultComplexity: 1 })
                ],
                maximumComplexity: 1000,
                variables: request.variables,
                document,
                schema
              });
              
              if (complexity > 1000) {
                throw new Error(`Query complexity ${complexity} exceeds maximum allowed complexity of 1000`);
              }
              
              logger.info({ complexity }, 'Query complexity calculated');
            }
          };
        }
      },
      // Performance monitoring
      {
        requestDidStart() {
          return {
            willSendResponse(requestContext) {
              const { response, request } = requestContext;
              logger.info({
                query: request.query,
                variables: request.variables,
                operationName: request.operationName,
                duration: response.http.body.extensions?.tracing?.duration
              }, 'GraphQL request completed');
            }
          };
        }
      }
    ],
    validationRules: [depthLimit(10)],
    introspection: process.env.ENABLE_INTROSPECTION === 'true',
    playground: process.env.ENABLE_PLAYGROUND === 'true',
    tracing: true,
    cacheControl: {
      defaultMaxAge: 300, // 5 minutes default cache
    },
    formatError: (error) => {
      logger.error(error, 'GraphQL error occurred');
      return {
        message: error.message,
        code: error.extensions?.code,
        path: error.path
      };
    }
  });

  await server.start();
  server.applyMiddleware({ app, path: '/graphql' });

  const httpServer = createServer(app);
  
  // WebSocket server for subscriptions
  const subscriptionServer = SubscriptionServer.create({
    schema,
    execute,
    subscribe,
    onConnect: async (connectionParams, webSocket) => {
      logger.info('WebSocket client connected');
      return {
        pubsub,
        redis,
        grpcClients,
        logger
      };
    },
    onDisconnect: () => {
      logger.info('WebSocket client disconnected');
    }
  }, {
    server: httpServer,
    path: server.graphqlPath,
  });

  const PORT = process.env.PORT || 4000;
  
  httpServer.listen(PORT, () => {
    logger.info({
      port: PORT,
      graphqlPath: server.graphqlPath,
      subscriptionsPath: subscriptionServer.wsServer.options.path
    }, 'GraphQL Gateway server started');
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    subscriptionServer.close();
    httpServer.close(() => {
      redis.disconnect();
      process.exit(0);
    });
  });
}

startServer().catch(error => {
  logger.error(error, 'Failed to start server');
  process.exit(1);
});