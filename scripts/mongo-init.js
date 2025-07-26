// MongoDB initialization script
print('🚀 Initializing MongoDB for ERP Suite...');

// Switch to admin database
db = db.getSiblingDB('admin');

// Create databases and collections for each module
const databases = [
    'erp_analytics',
    'erp_logs',
    'erp_ai_conversations',
    'erp_audit_trail'
];

databases.forEach(function(dbName) {
    print(`Creating database: ${dbName}`);
    
    // Switch to the database
    db = db.getSiblingDB(dbName);
    
    // Create initial collections based on database purpose
    if (dbName === 'erp_analytics') {
        db.createCollection('user_analytics');
        db.createCollection('business_metrics');
        db.createCollection('performance_data');
        db.createCollection('usage_statistics');
        
        // Create indexes for analytics
        db.user_analytics.createIndex({ "user_id": 1, "timestamp": -1 });
        db.business_metrics.createIndex({ "organization_id": 1, "metric_type": 1, "timestamp": -1 });
        db.performance_data.createIndex({ "service": 1, "timestamp": -1 });
        db.usage_statistics.createIndex({ "organization_id": 1, "feature": 1, "timestamp": -1 });
        
    } else if (dbName === 'erp_logs') {
        db.createCollection('application_logs');
        db.createCollection('error_logs');
        db.createCollection('access_logs');
        
        // Create indexes for logs
        db.application_logs.createIndex({ "level": 1, "timestamp": -1 });
        db.error_logs.createIndex({ "service": 1, "timestamp": -1 });
        db.access_logs.createIndex({ "user_id": 1, "timestamp": -1 });
        
    } else if (dbName === 'erp_ai_conversations') {
        db.createCollection('conversations');
        db.createCollection('ai_actions');
        db.createCollection('knowledge_base');
        
        // Create indexes for AI data
        db.conversations.createIndex({ "user_id": 1, "organization_id": 1, "timestamp": -1 });
        db.ai_actions.createIndex({ "user_id": 1, "action_type": 1, "timestamp": -1 });
        db.knowledge_base.createIndex({ "organization_id": 1, "document_type": 1 });
        
    } else if (dbName === 'erp_audit_trail') {
        db.createCollection('user_actions');
        db.createCollection('system_events');
        db.createCollection('security_events');
        
        // Create indexes for audit trail
        db.user_actions.createIndex({ "user_id": 1, "organization_id": 1, "timestamp": -1 });
        db.system_events.createIndex({ "event_type": 1, "timestamp": -1 });
        db.security_events.createIndex({ "severity": 1, "timestamp": -1 });
    }
    
    print(`✅ Database ${dbName} initialized successfully`);
});

print('✅ MongoDB initialization completed!');

// Create a test document to verify everything works
db = db.getSiblingDB('erp_analytics');
db.user_analytics.insertOne({
    user_id: "test-user",
    organization_id: "test-org",
    event: "system_initialized",
    timestamp: new Date(),
    metadata: {
        version: "1.0.0",
        environment: "development"
    }
});

print('✅ Test document inserted successfully!');