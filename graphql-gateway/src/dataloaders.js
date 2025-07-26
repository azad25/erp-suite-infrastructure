const DataLoader = require('dataloader');

/**
 * DataLoader factory for efficient batching and caching
 * Prevents N+1 queries and provides automatic caching
 */
function createDataLoaders(grpcClients, redis) {
  const CACHE_TTL = parseInt(process.env.DATALOADER_CACHE_TTL) || 60; // 60 seconds

  // Generic cache key generator
  const getCacheKey = (service, method, id) => `dl:${service}:${method}:${id}`;

  // Generic batch loader with Redis caching
  const createBatchLoader = (service, method, keyField = 'id') => {
    return new DataLoader(
      async (keys) => {
        try {
          // Check Redis cache first
          const cacheKeys = keys.map(key => getCacheKey(service, method, key));
          const cachedResults = await redis.mget(cacheKeys);
          
          const uncachedKeys = [];
          const results = [];
          
          // Separate cached and uncached keys
          keys.forEach((key, index) => {
            if (cachedResults[index]) {
              results[index] = JSON.parse(cachedResults[index]);
            } else {
              uncachedKeys.push({ key, index });
            }
          });

          // Fetch uncached data via gRPC
          if (uncachedKeys.length > 0) {
            const grpcRequest = {
              ids: uncachedKeys.map(item => item.key)
            };

            const grpcResponse = await new Promise((resolve, reject) => {
              grpcClients[service][method](grpcRequest, (error, response) => {
                if (error) reject(error);
                else resolve(response);
              });
            });

            // Process gRPC response and cache results
            const fetchedData = grpcResponse.items || grpcResponse.data || [];
            const dataMap = new Map();
            
            fetchedData.forEach(item => {
              dataMap.set(item[keyField], item);
            });

            // Fill in results and cache
            const cachePromises = [];
            uncachedKeys.forEach(({ key, index }) => {
              const data = dataMap.get(key) || null;
              results[index] = data;
              
              if (data) {
                const cacheKey = getCacheKey(service, method, key);
                cachePromises.push(
                  redis.setex(cacheKey, CACHE_TTL, JSON.stringify(data))
                );
              }
            });

            // Cache in background
            Promise.all(cachePromises).catch(error => {
              console.error('Cache write error:', error);
            });
          }

          return results;
        } catch (error) {
          console.error(`DataLoader error for ${service}.${method}:`, error);
          // Return null for all keys on error
          return keys.map(() => null);
        }
      },
      {
        // DataLoader options
        maxBatchSize: 100,
        cacheKeyFn: (key) => String(key),
        cacheMap: new Map() // In-memory cache for request duration
      }
    );
  };

  // User-related loaders
  const userLoader = createBatchLoader('auth', 'getUsersByIds');
  const userProfileLoader = createBatchLoader('auth', 'getUserProfilesByIds');
  const userPermissionsLoader = createBatchLoader('auth', 'getUserPermissionsByIds');

  // CRM loaders
  const contactLoader = createBatchLoader('crm', 'getContactsByIds');
  const leadLoader = createBatchLoader('crm', 'getLeadsByIds');
  const opportunityLoader = createBatchLoader('crm', 'getOpportunitiesByIds');
  const activityLoader = createBatchLoader('crm', 'getActivitiesByIds');

  // HRM loaders
  const employeeLoader = createBatchLoader('hrm', 'getEmployeesByIds');
  const departmentLoader = createBatchLoader('hrm', 'getDepartmentsByIds');
  const leaveLoader = createBatchLoader('hrm', 'getLeavesByIds');
  const timesheetLoader = createBatchLoader('hrm', 'getTimesheetsByIds');

  // Finance loaders
  const invoiceLoader = createBatchLoader('finance', 'getInvoicesByIds');
  const paymentLoader = createBatchLoader('finance', 'getPaymentsByIds');
  const invoiceLineItemLoader = createBatchLoader('finance', 'getInvoiceLineItemsByIds');

  // Inventory loaders
  const productLoader = createBatchLoader('inventory', 'getProductsByIds');
  const categoryLoader = createBatchLoader('inventory', 'getCategoriesByIds');
  const supplierLoader = createBatchLoader('inventory', 'getSuppliersByIds');
  const stockMovementLoader = createBatchLoader('inventory', 'getStockMovementsByIds');

  // Relationship loaders (for foreign key relationships)
  const contactLeadsLoader = new DataLoader(
    async (contactIds) => {
      try {
        const cacheKeys = contactIds.map(id => `dl:crm:contactLeads:${id}`);
        const cachedResults = await redis.mget(cacheKeys);
        
        const uncachedIds = [];
        const results = [];
        
        contactIds.forEach((id, index) => {
          if (cachedResults[index]) {
            results[index] = JSON.parse(cachedResults[index]);
          } else {
            uncachedIds.push({ id, index });
          }
        });

        if (uncachedIds.length > 0) {
          const grpcResponse = await new Promise((resolve, reject) => {
            grpcClients.crm.getLeadsByContactIds({
              contactIds: uncachedIds.map(item => item.id)
            }, (error, response) => {
              if (error) reject(error);
              else resolve(response);
            });
          });

          const leadsMap = new Map();
          (grpcResponse.leads || []).forEach(lead => {
            if (!leadsMap.has(lead.contactId)) {
              leadsMap.set(lead.contactId, []);
            }
            leadsMap.get(lead.contactId).push(lead);
          });

          const cachePromises = [];
          uncachedIds.forEach(({ id, index }) => {
            const leads = leadsMap.get(id) || [];
            results[index] = leads;
            
            const cacheKey = `dl:crm:contactLeads:${id}`;
            cachePromises.push(
              redis.setex(cacheKey, CACHE_TTL, JSON.stringify(leads))
            );
          });

          Promise.all(cachePromises).catch(error => {
            console.error('Cache write error:', error);
          });
        }

        return results;
      } catch (error) {
        console.error('ContactLeadsLoader error:', error);
        return contactIds.map(() => []);
      }
    },
    { maxBatchSize: 50 }
  );

  // Employee manager loader
  const employeeManagerLoader = new DataLoader(
    async (employeeIds) => {
      try {
        const employees = await Promise.all(
          employeeIds.map(id => employeeLoader.load(id))
        );
        
        const managerIds = employees
          .map(emp => emp?.managerId)
          .filter(Boolean);
        
        if (managerIds.length === 0) {
          return employees.map(() => null);
        }

        const managers = await Promise.all(
          managerIds.map(id => employeeLoader.load(id))
        );
        
        const managerMap = new Map();
        managers.forEach(manager => {
          if (manager) {
            managerMap.set(manager.id, manager);
          }
        });

        return employees.map(emp => 
          emp?.managerId ? managerMap.get(emp.managerId) || null : null
        );
      } catch (error) {
        console.error('EmployeeManagerLoader error:', error);
        return employeeIds.map(() => null);
      }
    },
    { maxBatchSize: 50 }
  );

  // Invoice line items loader
  const invoiceLineItemsLoader = new DataLoader(
    async (invoiceIds) => {
      try {
        const grpcResponse = await new Promise((resolve, reject) => {
          grpcClients.finance.getInvoiceLineItemsByInvoiceIds({
            invoiceIds
          }, (error, response) => {
            if (error) reject(error);
            else resolve(response);
          });
        });

        const itemsMap = new Map();
        (grpcResponse.lineItems || []).forEach(item => {
          if (!itemsMap.has(item.invoiceId)) {
            itemsMap.set(item.invoiceId, []);
          }
          itemsMap.get(item.invoiceId).push(item);
        });

        return invoiceIds.map(id => itemsMap.get(id) || []);
      } catch (error) {
        console.error('InvoiceLineItemsLoader error:', error);
        return invoiceIds.map(() => []);
      }
    },
    { maxBatchSize: 50 }
  );

  // Product stock movements loader
  const productStockMovementsLoader = new DataLoader(
    async (productIds) => {
      try {
        const grpcResponse = await new Promise((resolve, reject) => {
          grpcClients.inventory.getStockMovementsByProductIds({
            productIds,
            limit: 10 // Recent movements only
          }, (error, response) => {
            if (error) reject(error);
            else resolve(response);
          });
        });

        const movementsMap = new Map();
        (grpcResponse.movements || []).forEach(movement => {
          if (!movementsMap.has(movement.productId)) {
            movementsMap.set(movement.productId, []);
          }
          movementsMap.get(movement.productId).push(movement);
        });

        return productIds.map(id => movementsMap.get(id) || []);
      } catch (error) {
        console.error('ProductStockMovementsLoader error:', error);
        return productIds.map(() => []);
      }
    },
    { maxBatchSize: 50 }
  );

  // Clear cache function for mutations
  const clearCache = (service, method, id) => {
    const cacheKey = getCacheKey(service, method, id);
    redis.del(cacheKey).catch(error => {
      console.error('Cache clear error:', error);
    });
  };

  // Clear all related caches for an entity
  const clearEntityCache = (entityType, id) => {
    const patterns = [
      `dl:*:*${entityType}*:${id}`,
      `dl:*:*:${id}:*`,
      `dl:${entityType}:*:${id}`
    ];
    
    patterns.forEach(pattern => {
      redis.keys(pattern).then(keys => {
        if (keys.length > 0) {
          redis.del(keys);
        }
      }).catch(error => {
        console.error('Cache pattern clear error:', error);
      });
    });
  };

  return {
    // Entity loaders
    userLoader,
    userProfileLoader,
    userPermissionsLoader,
    contactLoader,
    leadLoader,
    opportunityLoader,
    activityLoader,
    employeeLoader,
    departmentLoader,
    leaveLoader,
    timesheetLoader,
    invoiceLoader,
    paymentLoader,
    invoiceLineItemLoader,
    productLoader,
    categoryLoader,
    supplierLoader,
    stockMovementLoader,

    // Relationship loaders
    contactLeadsLoader,
    employeeManagerLoader,
    invoiceLineItemsLoader,
    productStockMovementsLoader,

    // Cache management
    clearCache,
    clearEntityCache,

    // Utility functions
    prime: (loader, id, data) => {
      loader.prime(id, data);
      // Also cache in Redis
      const service = loader.name?.split('Loader')[0] || 'unknown';
      const cacheKey = getCacheKey(service, 'get', id);
      redis.setex(cacheKey, CACHE_TTL, JSON.stringify(data)).catch(error => {
        console.error('Cache prime error:', error);
      });
    }
  };
}

module.exports = {
  createDataLoaders
};