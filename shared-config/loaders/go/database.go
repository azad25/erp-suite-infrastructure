package sharedconfig

import (
	"fmt"
	"time"
)

// PostgreSQLConfig holds PostgreSQL configuration
type PostgreSQLConfig struct {
	Host               string                    `yaml:"host"`
	Port               int                       `yaml:"port"`
	Username           string                    `yaml:"username"`
	Password           string                    `yaml:"password"`
	SSLMode            string                    `yaml:"ssl_mode"`
	MaxConnections     int                       `yaml:"max_connections"`
	ConnectionTimeout  int                       `yaml:"connection_timeout"`
	Databases          PostgreSQLDatabasesConfig `yaml:"databases"`
	Pool               PostgreSQLPoolConfig      `yaml:"pool"`
}

type PostgreSQLDatabasesConfig struct {
	Auth      string `yaml:"auth"`
	CRM       string `yaml:"crm"`
	HRM       string `yaml:"hrm"`
	Finance   string `yaml:"finance"`
	Inventory string `yaml:"inventory"`
	Projects  string `yaml:"projects"`
	Analytics string `yaml:"analytics"`
}

type PostgreSQLPoolConfig struct {
	MaxOpenConnections    int `yaml:"max_open_connections"`
	MaxIdleConnections    int `yaml:"max_idle_connections"`
	ConnectionMaxLifetime int `yaml:"connection_max_lifetime"`
	ConnectionMaxIdleTime int `yaml:"connection_max_idle_time"`
}

// MongoDBConfig holds MongoDB configuration
type MongoDBConfig struct {
	Host       string                 `yaml:"host"`
	Port       int                    `yaml:"port"`
	Username   string                 `yaml:"username"`
	Password   string                 `yaml:"password"`
	AuthSource string                 `yaml:"auth_source"`
	Databases  MongoDBDatabasesConfig `yaml:"databases"`
	Options    MongoDBOptionsConfig   `yaml:"options"`
}

type MongoDBDatabasesConfig struct {
	Analytics       string `yaml:"analytics"`
	Logs            string `yaml:"logs"`
	AIConversations string `yaml:"ai_conversations"`
	AuditTrail      string `yaml:"audit_trail"`
}

type MongoDBOptionsConfig struct {
	MaxPoolSize              int `yaml:"max_pool_size"`
	MinPoolSize              int `yaml:"min_pool_size"`
	MaxIdleTime              int `yaml:"max_idle_time"`
	ServerSelectionTimeout   int `yaml:"server_selection_timeout"`
}

// GetConnectionString returns the PostgreSQL connection string for a specific database
func (p *PostgreSQLConfig) GetConnectionString(database string) string {
	dbName := p.getDatabaseName(database)
	return fmt.Sprintf("postgresql://%s:%s@%s:%d/%s?sslmode=%s",
		p.Username, p.Password, p.Host, p.Port, dbName, p.SSLMode)
}

// GetDSN returns the PostgreSQL DSN for a specific database
func (p *PostgreSQLConfig) GetDSN(database string) string {
	dbName := p.getDatabaseName(database)
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		p.Host, p.Port, p.Username, p.Password, dbName, p.SSLMode)
}

// getDatabaseName returns the database name for a given module
func (p *PostgreSQLConfig) getDatabaseName(module string) string {
	switch module {
	case "auth":
		return p.Databases.Auth
	case "crm":
		return p.Databases.CRM
	case "hrm":
		return p.Databases.HRM
	case "finance":
		return p.Databases.Finance
	case "inventory":
		return p.Databases.Inventory
	case "projects":
		return p.Databases.Projects
	case "analytics":
		return p.Databases.Analytics
	default:
		return p.Databases.Auth // Default fallback
	}
}

// GetConnectionString returns the MongoDB connection string for a specific database
func (m *MongoDBConfig) GetConnectionString(database string) string {
	dbName := m.getDatabaseName(database)
	return fmt.Sprintf("mongodb://%s:%s@%s:%d/%s?authSource=%s",
		m.Username, m.Password, m.Host, m.Port, dbName, m.AuthSource)
}

// GetURI returns the MongoDB URI for a specific database
func (m *MongoDBConfig) GetURI(database string) string {
	return m.GetConnectionString(database)
}

// getDatabaseName returns the database name for a given purpose
func (m *MongoDBConfig) getDatabaseName(purpose string) string {
	switch purpose {
	case "analytics":
		return m.Databases.Analytics
	case "logs":
		return m.Databases.Logs
	case "ai_conversations", "ai":
		return m.Databases.AIConversations
	case "audit_trail", "audit":
		return m.Databases.AuditTrail
	default:
		return m.Databases.Analytics // Default fallback
	}
}

// GetMaxOpenConnections returns the maximum number of open connections
func (p *PostgreSQLPoolConfig) GetMaxOpenConnections() int {
	if p.MaxOpenConnections <= 0 {
		return 25 // Default
	}
	return p.MaxOpenConnections
}

// GetMaxIdleConnections returns the maximum number of idle connections
func (p *PostgreSQLPoolConfig) GetMaxIdleConnections() int {
	if p.MaxIdleConnections <= 0 {
		return 5 // Default
	}
	return p.MaxIdleConnections
}

// GetConnectionMaxLifetime returns the maximum lifetime of a connection
func (p *PostgreSQLPoolConfig) GetConnectionMaxLifetime() time.Duration {
	if p.ConnectionMaxLifetime <= 0 {
		return 5 * time.Minute // Default
	}
	return time.Duration(p.ConnectionMaxLifetime) * time.Second
}

// GetConnectionMaxIdleTime returns the maximum idle time of a connection
func (p *PostgreSQLPoolConfig) GetConnectionMaxIdleTime() time.Duration {
	if p.ConnectionMaxIdleTime <= 0 {
		return 1 * time.Minute // Default
	}
	return time.Duration(p.ConnectionMaxIdleTime) * time.Second
}

// GetMaxPoolSize returns the maximum pool size for MongoDB
func (m *MongoDBOptionsConfig) GetMaxPoolSize() uint64 {
	if m.MaxPoolSize <= 0 {
		return 10 // Default
	}
	return uint64(m.MaxPoolSize)
}

// GetMinPoolSize returns the minimum pool size for MongoDB
func (m *MongoDBOptionsConfig) GetMinPoolSize() uint64 {
	if m.MinPoolSize <= 0 {
		return 1 // Default
	}
	return uint64(m.MinPoolSize)
}

// GetMaxIdleTime returns the maximum idle time for MongoDB connections
func (m *MongoDBOptionsConfig) GetMaxIdleTime() time.Duration {
	if m.MaxIdleTime <= 0 {
		return 1 * time.Minute // Default
	}
	return time.Duration(m.MaxIdleTime) * time.Second
}

// GetServerSelectionTimeout returns the server selection timeout for MongoDB
func (m *MongoDBOptionsConfig) GetServerSelectionTimeout() time.Duration {
	if m.ServerSelectionTimeout <= 0 {
		return 30 * time.Second // Default
	}
	return time.Duration(m.ServerSelectionTimeout) * time.Second
}