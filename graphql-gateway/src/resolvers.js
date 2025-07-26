const { GraphQLScalarType } = require('graphql');
const { Kind } = require('graphql/language');

// Custom scalar types
const DateTimeType = new GraphQLScalarType({
  name: 'DateTime',
  description: 'Date custom scalar type',
  serialize(value) {
    return new Date(value).toISOString();
  },
  parseValue(value) {
    return new Date(value);
  },
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) {
      return new Date(ast.value);
    }
    return null;
  },
});

const JSONType = new GraphQLScalarType({
  name: 'JSON',
  description: 'JSON custom scalar type',
  serialize(value) {
    return value;
  },
  parseValue(value) {
    return value;
  },
  parseLiteral(ast) {
    if (ast.kind === Kind.STRING) {
      return JSON.parse(ast.value);
    }
    return null;
  },
});

// Helper function to handle gRPC calls with error handling
const grpcCall = (client, method, params = {}) => {
  return new Promise((resolve, reject) => {
    client[method](params, (error, response) => {
      if (error) {
        console.error(`gRPC call failed: ${method}`, error);
        reject(error);
      } else {
        resolve(response);
      }
    });
  });
};

// Helper function to convert gRPC timestamp to JavaScript Date
const timestampToDate = (timestamp) => {
  return timestamp ? new Date(parseInt(timestamp) * 1000) : null;
};

// Helper function to convert JavaScript Date to gRPC timestamp
const dateToTimestamp = (date) => {
  return date ? Math.floor(date.getTime() / 1000) : null;
};

const resolvers = {
  // Custom scalars
  DateTime: DateTimeType,
  JSON: JSONType,

  // Root Query resolvers
  Query: {
    // User queries
    me: async (parent, args, { grpcClients, user, dataLoaders }) => {
      if (!user) throw new Error('Authentication required');
      return await dataLoaders.userLoader.load(user.id);
    },

    users: async (parent, { filter, pagination, sort }, { grpcClients, dataLoaders }) => {
      const response = await grpcCall(grpcClients.auth, 'getUsers', {
        search: filter?.search,
        role: filter?.role,
        isActive: filter?.isActive,
        organizationId: filter?.organizationId,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0,
        sortField: sort?.field || 'created_at',
        sortDirection: sort?.direction || 'DESC'
      });

      return {
        edges: response.users.map((user, index) => ({
          node: user,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.users.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.users.length > 0 ? Buffer.from((pagination?.after || 0) + response.users.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    },

    user: async (parent, { id }, { dataLoaders }) => {
      return await dataLoaders.userLoader.load(id);
    },

    // CRM queries
    contacts: async (parent, { filter, pagination, sort }, { grpcClients }) => {
      const response = await grpcCall(grpcClients.crm, 'getContacts', {
        search: filter?.search,
        company: filter?.company,
        source: filter?.source,
        assignedTo: filter?.assignedTo,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0,
        sortField: sort?.field || 'created_at',
        sortDirection: sort?.direction || 'DESC'
      });

      return {
        edges: response.contacts.map((contact, index) => ({
          node: contact,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.contacts.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.contacts.length > 0 ? Buffer.from((pagination?.after || 0) + response.contacts.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    },

    contact: async (parent, { id }, { dataLoaders }) => {
      return await dataLoaders.contactLoader.load(id);
    },

    leads: async (parent, { filter, pagination, sort }, { grpcClients }) => {
      const response = await grpcCall(grpcClients.crm, 'getLeads', {
        status: filter?.status,
        source: filter?.source,
        assignedTo: filter?.assignedTo,
        dateFrom: filter?.dateRange?.from ? dateToTimestamp(filter.dateRange.from) : null,
        dateTo: filter?.dateRange?.to ? dateToTimestamp(filter.dateRange.to) : null,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0,
        sortField: sort?.field || 'created_at',
        sortDirection: sort?.direction || 'DESC'
      });

      return {
        edges: response.leads.map((lead, index) => ({
          node: lead,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.leads.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.leads.length > 0 ? Buffer.from((pagination?.after || 0) + response.leads.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    },

    // HRM queries
    employees: async (parent, { filter, pagination, sort }, { grpcClients }) => {
      const response = await grpcCall(grpcClients.hrm, 'getEmployees', {
        search: filter?.search,
        departmentId: filter?.department,
        status: filter?.status,
        managerId: filter?.manager,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0,
        sortField: sort?.field || 'created_at',
        sortDirection: sort?.direction || 'DESC'
      });

      return {
        edges: response.employees.map((employee, index) => ({
          node: employee,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.employees.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.employees.length > 0 ? Buffer.from((pagination?.after || 0) + response.employees.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    },

    employee: async (parent, { id }, { dataLoaders }) => {
      return await dataLoaders.employeeLoader.load(id);
    },

    // Finance queries
    invoices: async (parent, { filter, pagination, sort }, { grpcClients }) => {
      const response = await grpcCall(grpcClients.finance, 'getInvoices', {
        status: filter?.status,
        customerId: filter?.customer,
        dateFrom: filter?.dateRange?.from ? dateToTimestamp(filter.dateRange.from) : null,
        dateTo: filter?.dateRange?.to ? dateToTimestamp(filter.dateRange.to) : null,
        amountMin: filter?.amountRange?.min,
        amountMax: filter?.amountRange?.max,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0,
        sortField: sort?.field || 'created_at',
        sortDirection: sort?.direction || 'DESC'
      });

      return {
        edges: response.invoices.map((invoice, index) => ({
          node: invoice,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.invoices.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.invoices.length > 0 ? Buffer.from((pagination?.after || 0) + response.invoices.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    },

    invoice: async (parent, { id }, { dataLoaders }) => {
      return await dataLoaders.invoiceLoader.load(id);
    },

    // Inventory queries
    products: async (parent, { filter, pagination, sort }, { grpcClients }) => {
      const response = await grpcCall(grpcClients.inventory, 'getProducts', {
        search: filter?.search,
        categoryId: filter?.category,
        isActive: filter?.isActive,
        lowStock: filter?.lowStock,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0,
        sortField: sort?.field || 'created_at',
        sortDirection: sort?.direction || 'DESC'
      });

      return {
        edges: response.products.map((product, index) => ({
          node: product,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.products.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.products.length > 0 ? Buffer.from((pagination?.after || 0) + response.products.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    },

    product: async (parent, { id }, { dataLoaders }) => {
      return await dataLoaders.productLoader.load(id);
    },

    // Dashboard stats
    dashboardStats: async (parent, args, { grpcClients, user }) => {
      if (!user) throw new Error('Authentication required');

      // Fetch stats from multiple services in parallel
      const [contactsResponse, leadsResponse, invoicesResponse] = await Promise.all([
        grpcCall(grpcClients.crm, 'getContacts', { limit: 1 }),
        grpcCall(grpcClients.crm, 'getLeads', { limit: 1 }),
        grpcCall(grpcClients.finance, 'getInvoices', { limit: 1 })
      ]);

      // Calculate total revenue from invoices
      const paidInvoices = await grpcCall(grpcClients.finance, 'getInvoices', {
        status: 'INVOICE_STATUS_PAID',
        limit: 1000
      });

      const totalRevenue = paidInvoices.invoices.reduce((sum, invoice) => sum + invoice.totalAmount, 0);

      return {
        totalContacts: contactsResponse.totalCount,
        totalLeads: leadsResponse.totalCount,
        totalInvoices: invoicesResponse.totalCount,
        totalRevenue,
        recentActivities: [], // TODO: Implement activities
        topPerformers: [] // TODO: Implement top performers
      };
    },

    // Activities
    activities: async (parent, { filter, pagination }, { grpcClients }) => {
      const response = await grpcCall(grpcClients.crm, 'getActivities', {
        type: filter?.type,
        userId: filter?.userId,
        relatedEntityType: filter?.relatedEntityType,
        relatedEntityId: filter?.relatedEntityId,
        dateFrom: filter?.dateRange?.from ? dateToTimestamp(filter.dateRange.from) : null,
        dateTo: filter?.dateRange?.to ? dateToTimestamp(filter.dateRange.to) : null,
        limit: pagination?.first || 20,
        offset: pagination?.after ? parseInt(pagination.after) : 0
      });

      return {
        edges: response.activities.map((activity, index) => ({
          node: activity,
          cursor: Buffer.from((pagination?.after || 0) + index + 1).toString('base64')
        })),
        pageInfo: {
          hasNextPage: response.hasNextPage,
          hasPreviousPage: (pagination?.after || 0) > 0,
          startCursor: response.activities.length > 0 ? Buffer.from((pagination?.after || 0) + 1).toString('base64') : null,
          endCursor: response.activities.length > 0 ? Buffer.from((pagination?.after || 0) + response.activities.length).toString('base64') : null
        },
        totalCount: response.totalCount
      };
    }
  },

  // Root Mutation resolvers
  Mutation: {
    // User mutations
    updateProfile: async (parent, { input }, { grpcClients, user, dataLoaders }) => {
      if (!user) throw new Error('Authentication required');

      const updatedUser = await grpcCall(grpcClients.auth, 'updateUser', {
        id: user.id,
        name: input.firstName && input.lastName ? `${input.firstName} ${input.lastName}` : undefined,
        ...input
      });

      // Clear cache
      dataLoaders.clearEntityCache('user', user.id);

      return updatedUser;
    },

    changePassword: async (parent, { input }, { grpcClients, user }) => {
      if (!user) throw new Error('Authentication required');

      await grpcCall(grpcClients.auth, 'changePassword', {
        userId: user.id,
        currentPassword: input.currentPassword,
        newPassword: input.newPassword
      });

      return true;
    },

    // CRM mutations
    createContact: async (parent, { input }, { grpcClients, dataLoaders, pubsub, user }) => {
      const contact = await grpcCall(grpcClients.crm, 'createContact', input);

      // Publish real-time update
      pubsub.publish('ACTIVITY_ADDED', {
        activityAdded: {
          id: Date.now().toString(),
          type: 'CONTACT_CREATED',
          title: 'New Contact Created',
          description: `Contact ${contact.name} was created`,
          userId: user.id,
          organizationId: user.organizationId,
          createdAt: new Date()
        }
      });

      return contact;
    },

    updateContact: async (parent, { id, input }, { grpcClients, dataLoaders }) => {
      const updatedContact = await grpcCall(grpcClients.crm, 'updateContact', { id, ...input });

      // Clear cache
      dataLoaders.clearEntityCache('contact', id);

      return updatedContact;
    },

    deleteContact: async (parent, { id }, { grpcClients, dataLoaders }) => {
      const response = await grpcCall(grpcClients.crm, 'deleteContact', { id });

      // Clear cache
      dataLoaders.clearEntityCache('contact', id);

      return response.success;
    },

    createLead: async (parent, { input }, { grpcClients, pubsub, user }) => {
      const lead = await grpcCall(grpcClients.crm, 'createLead', input);

      // Publish real-time update
      pubsub.publish('ACTIVITY_ADDED', {
        activityAdded: {
          id: Date.now().toString(),
          type: 'LEAD_CREATED',
          title: 'New Lead Created',
          description: `Lead ${lead.title} was created`,
          userId: user.id,
          organizationId: user.organizationId,
          createdAt: new Date()
        }
      });

      return lead;
    },

    updateLead: async (parent, { id, input }, { grpcClients, dataLoaders, pubsub }) => {
      const updatedLead = await grpcCall(grpcClients.crm, 'updateLead', { id, ...input });

      // Clear cache
      dataLoaders.clearEntityCache('lead', id);

      // Publish real-time update
      pubsub.publish('LEAD_UPDATED', {
        leadUpdated: updatedLead
      });

      return updatedLead;
    },

    convertLead: async (parent, { id, input }, { grpcClients, dataLoaders }) => {
      const opportunity = await grpcCall(grpcClients.crm, 'convertLead', { id, ...input });

      // Clear cache
      dataLoaders.clearEntityCache('lead', id);

      return opportunity;
    },

    // HRM mutations
    createEmployee: async (parent, { input }, { grpcClients }) => {
      return await grpcCall(grpcClients.hrm, 'createEmployee', input);
    },

    updateEmployee: async (parent, { id, input }, { grpcClients, dataLoaders }) => {
      const updatedEmployee = await grpcCall(grpcClients.hrm, 'updateEmployee', { id, ...input });

      // Clear cache
      dataLoaders.clearEntityCache('employee', id);

      return updatedEmployee;
    },

    submitLeave: async (parent, { input }, { grpcClients, user }) => {
      return await grpcCall(grpcClients.hrm, 'submitLeave', {
        employeeId: user.employeeId,
        ...input
      });
    },

    approveLeave: async (parent, { id, approved }, { grpcClients, user, dataLoaders }) => {
      const updatedLeave = await grpcCall(grpcClients.hrm, 'approveLeave', {
        id,
        approved,
        approvedBy: user.id
      });

      // Clear cache
      dataLoaders.clearEntityCache('leave', id);

      return updatedLeave;
    },

    // Finance mutations
    createInvoice: async (parent, { input }, { grpcClients, pubsub, user }) => {
      const invoice = await grpcCall(grpcClients.finance, 'createInvoice', input);

      // Publish real-time update
      pubsub.publish('ACTIVITY_ADDED', {
        activityAdded: {
          id: Date.now().toString(),
          type: 'INVOICE_CREATED',
          title: 'New Invoice Created',
          description: `Invoice ${invoice.invoiceNumber} was created`,
          userId: user.id,
          organizationId: user.organizationId,
          createdAt: new Date()
        }
      });

      return invoice;
    },

    updateInvoice: async (parent, { id, input }, { grpcClients, dataLoaders }) => {
      const updatedInvoice = await grpcCall(grpcClients.finance, 'updateInvoice', { id, ...input });

      // Clear cache
      dataLoaders.clearEntityCache('invoice', id);

      return updatedInvoice;
    },

    sendInvoice: async (parent, { id }, { grpcClients, pubsub }) => {
      const response = await grpcCall(grpcClients.finance, 'sendInvoice', { id });

      if (response.success) {
        // Publish real-time update
        pubsub.publish('INVOICE_STATUS_CHANGED', {
          invoiceStatusChanged: await grpcCall(grpcClients.finance, 'getInvoice', { id })
        });
      }

      return response.success;
    },

    recordPayment: async (parent, { input }, { grpcClients, pubsub }) => {
      const payment = await grpcCall(grpcClients.finance, 'recordPayment', input);

      // Publish real-time update
      pubsub.publish('ACTIVITY_ADDED', {
        activityAdded: {
          id: Date.now().toString(),
          type: 'PAYMENT_RECEIVED',
          title: 'Payment Received',
          description: `Payment of ${payment.amount} received`,
          createdAt: new Date()
        }
      });

      return payment;
    },

    // Inventory mutations
    createProduct: async (parent, { input }, { grpcClients }) => {
      return await grpcCall(grpcClients.inventory, 'createProduct', input);
    },

    updateProduct: async (parent, { id, input }, { grpcClients, dataLoaders }) => {
      const updatedProduct = await grpcCall(grpcClients.inventory, 'updateProduct', { id, ...input });

      // Clear cache
      dataLoaders.clearEntityCache('product', id);

      return updatedProduct;
    },

    adjustStock: async (parent, { input }, { grpcClients, pubsub, user }) => {
      const stockMovement = await grpcCall(grpcClients.inventory, 'adjustStock', input);

      // Publish real-time update
      pubsub.publish('ACTIVITY_ADDED', {
        activityAdded: {
          id: Date.now().toString(),
          type: 'STOCK_ADJUSTED',
          title: 'Stock Adjusted',
          description: `Stock adjusted for product ${input.productId}`,
          userId: user.id,
          organizationId: user.organizationId,
          createdAt: new Date()
        }
      });

      return stockMovement;
    }
  },

  // Root Subscription resolvers
  Subscription: {
    activityAdded: {
      subscribe: (parent, { organizationId }, { pubsub }) => {
        return pubsub.asyncIterator(['ACTIVITY_ADDED']);
      }
    },

    notificationReceived: {
      subscribe: (parent, { userId }, { pubsub }) => {
        return pubsub.asyncIterator(['NOTIFICATION_RECEIVED']);
      }
    },

    dashboardUpdated: {
      subscribe: (parent, { organizationId }, { pubsub }) => {
        return pubsub.asyncIterator(['DASHBOARD_UPDATED']);
      }
    },

    invoiceStatusChanged: {
      subscribe: (parent, { invoiceId }, { pubsub }) => {
        return pubsub.asyncIterator(['INVOICE_STATUS_CHANGED']);
      }
    },

    leadUpdated: {
      subscribe: (parent, { leadId }, { pubsub }) => {
        return pubsub.asyncIterator(['LEAD_UPDATED']);
      }
    }
  },

  // Type resolvers for relationships
  User: {
    profile: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.userProfileLoader.load(parent.id);
    },

    permissions: async (parent, args, { dataLoaders }) => {
      const userPermissions = await dataLoaders.userPermissionsLoader.load(parent.id);
      return userPermissions.permissions || [];
    },

    organization: async (parent, args, { grpcClients }) => {
      if (!parent.organizationId) return null;
      return await grpcCall(grpcClients.auth, 'getOrganization', { id: parent.organizationId });
    },

    createdAt: (parent) => timestampToDate(parent.createdAt),
    updatedAt: (parent) => timestampToDate(parent.updatedAt),
    lastLogin: (parent) => timestampToDate(parent.lastLogin)
  },

  Contact: {
    leads: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.contactLeadsLoader.load(parent.id);
    },

    opportunities: async (parent, args, { grpcClients }) => {
      const response = await grpcCall(grpcClients.crm, 'getOpportunities', {
        contactId: parent.id
      });
      return response.opportunities || [];
    },

    activities: async (parent, args, { grpcClients }) => {
      const response = await grpcCall(grpcClients.crm, 'getActivities', {
        relatedEntityType: 'contact',
        relatedEntityId: parent.id
      });
      return response.activities || [];
    },

    assignedTo: async (parent, args, { dataLoaders }) => {
      return parent.assignedTo ? await dataLoaders.userLoader.load(parent.assignedTo) : null;
    },

    customFields: (parent) => {
      try {
        return parent.customFields ? JSON.parse(parent.customFields) : {};
      } catch {
        return {};
      }
    },

    createdAt: (parent) => timestampToDate(parent.createdAt),
    updatedAt: (parent) => timestampToDate(parent.updatedAt)
  },

  Lead: {
    contact: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.contactLoader.load(parent.contactId);
    },

    assignedTo: async (parent, args, { dataLoaders }) => {
      return parent.assignedTo ? await dataLoaders.userLoader.load(parent.assignedTo) : null;
    },

    activities: async (parent, args, { grpcClients }) => {
      const response = await grpcCall(grpcClients.crm, 'getActivities', {
        relatedEntityType: 'lead',
        relatedEntityId: parent.id
      });
      return response.activities || [];
    },

    expectedCloseDate: (parent) => timestampToDate(parent.expectedCloseDate),
    createdAt: (parent) => timestampToDate(parent.createdAt),
    updatedAt: (parent) => timestampToDate(parent.updatedAt)
  },

  Employee: {
    department: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.departmentLoader.load(parent.departmentId);
    },

    manager: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.employeeManagerLoader.load(parent.id);
    },

    leaves: async (parent, args, { grpcClients }) => {
      const response = await grpcCall(grpcClients.hrm, 'getLeaves', {
        employeeId: parent.id
      });
      return response.leaves || [];
    },

    timesheets: async (parent, args, { grpcClients }) => {
      const response = await grpcCall(grpcClients.hrm, 'getTimesheets', {
        employeeId: parent.id
      });
      return response.timesheets || [];
    },

    hireDate: (parent) => timestampToDate(parent.hireDate),
    createdAt: (parent) => timestampToDate(parent.createdAt),
    updatedAt: (parent) => timestampToDate(parent.updatedAt)
  },

  Invoice: {
    customer: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.contactLoader.load(parent.customerId);
    },

    lineItems: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.invoiceLineItemsLoader.load(parent.id);
    },

    payments: async (parent, args, { grpcClients }) => {
      const response = await grpcCall(grpcClients.finance, 'getPayments', {
        invoiceId: parent.id
      });
      return response.payments || [];
    },

    issueDate: (parent) => timestampToDate(parent.issueDate),
    dueDate: (parent) => timestampToDate(parent.dueDate),
    createdAt: (parent) => timestampToDate(parent.createdAt),
    updatedAt: (parent) => timestampToDate(parent.updatedAt)
  },

  Product: {
    category: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.categoryLoader.load(parent.categoryId);
    },

    supplier: async (parent, args, { dataLoaders }) => {
      return parent.supplierId ? await dataLoaders.supplierLoader.load(parent.supplierId) : null;
    },

    stockMovements: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.productStockMovementsLoader.load(parent.id);
    },

    createdAt: (parent) => timestampToDate(parent.createdAt),
    updatedAt: (parent) => timestampToDate(parent.updatedAt)
  },

  Activity: {
    user: async (parent, args, { dataLoaders }) => {
      return await dataLoaders.userLoader.load(parent.userId);
    },

    relatedEntity: async (parent, args, { dataLoaders }) => {
      if (!parent.relatedEntityType || !parent.relatedEntityId) return null;

      switch (parent.relatedEntityType) {
        case 'contact':
          return await dataLoaders.contactLoader.load(parent.relatedEntityId);
        case 'lead':
          return await dataLoaders.leadLoader.load(parent.relatedEntityId);
        case 'invoice':
          return await dataLoaders.invoiceLoader.load(parent.relatedEntityId);
        case 'employee':
          return await dataLoaders.employeeLoader.load(parent.relatedEntityId);
        case 'product':
          return await dataLoaders.productLoader.load(parent.relatedEntityId);
        default:
          return null;
      }
    },

    createdAt: (parent) => timestampToDate(parent.createdAt)
  }
};

module.exports = resolvers;