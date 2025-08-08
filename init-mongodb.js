// MongoDB Database Initialization Script
// This script creates multiple databases for the ERP Suite modules

// Switch to admin database for authentication
db = db.getSiblingDB('admin');

// Authenticate as root user
db.auth('root', 'password');

// List of databases to create for ERP Suite modules
const databases = [
    'erp_analytics',
    'erp_logs', 
    'erp_ai_conversations',
    'erp_audit_trail',
    'erp_notifications',
    'erp_sessions',
    'erp_cache'
];

// Create databases and collections
databases.forEach(function(dbName) {
    print('Creating database: ' + dbName);
    
    // Switch to the database (creates it if it doesn't exist)
    const targetDb = db.getSiblingDB(dbName);
    
    // Create a dummy collection to ensure database is created
    // MongoDB only creates databases when they have at least one collection
    targetDb.createCollection('_init');
    
    // Create a user for this database with read/write permissions
    try {
        targetDb.createUser({
            user: 'erp_user',
            pwd: 'erp_password',
            roles: [
                { role: 'readWrite', db: dbName },
                { role: 'dbAdmin', db: dbName }
            ]
        });
        print('Created user for database: ' + dbName);
    } catch (e) {
        // User might already exist, that's okay
        if (e.code !== 11000) { // 11000 is duplicate key error
            print('Warning: Could not create user for ' + dbName + ': ' + e.message);
        }
    }
    
    // Create some basic collections for each database based on purpose
    if (dbName === 'erp_analytics') {
        targetDb.createCollection('user_analytics');
        targetDb.createCollection('business_metrics');
        targetDb.createCollection('performance_data');
    } else if (dbName === 'erp_logs') {
        targetDb.createCollection('application_logs');
        targetDb.createCollection('error_logs');
        targetDb.createCollection('audit_logs');
    } else if (dbName === 'erp_ai_conversations') {
        targetDb.createCollection('conversations');
        targetDb.createCollection('embeddings');
        targetDb.createCollection('training_data');
    } else if (dbName === 'erp_audit_trail') {
        targetDb.createCollection('user_actions');
        targetDb.createCollection('system_events');
        targetDb.createCollection('data_changes');
    } else if (dbName === 'erp_notifications') {
        targetDb.createCollection('notifications');
        targetDb.createCollection('templates');
        targetDb.createCollection('delivery_status');
    } else if (dbName === 'erp_sessions') {
        targetDb.createCollection('user_sessions');
        targetDb.createCollection('api_sessions');
    } else if (dbName === 'erp_cache') {
        targetDb.createCollection('application_cache');
        targetDb.createCollection('query_cache');
    }
    
    // Remove the dummy collection
    targetDb.dropCollection('_init');
    
    print('Database ' + dbName + ' initialized successfully');
});

print('MongoDB initialization completed successfully');
print('Created ' + databases.length + ' databases for ERP Suite');

// List all databases to verify creation
print('Available databases:');
db.adminCommand('listDatabases').databases.forEach(function(database) {
    if (database.name.startsWith('erp_')) {
        print('  - ' + database.name);
    }
});