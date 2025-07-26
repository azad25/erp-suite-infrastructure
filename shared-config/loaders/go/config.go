package sharedconfig

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
	"gopkg.in/yaml.v3"
)

// Config represents the complete configuration structure
type Config struct {
	Environment      EnvironmentConfig      `yaml:"environment"`
	Database         DatabaseConfig         `yaml:"database"`
	Cache            CacheConfig            `yaml:"cache"`
	MessageBroker    MessageBrokerConfig    `yaml:"message_broker"`
	VectorDatabase   VectorDatabaseConfig   `yaml:"vector_database"`
	Search           SearchConfig           `yaml:"search"`
	Monitoring       MonitoringConfig       `yaml:"monitoring"`
	Realtime         RealtimeConfig         `yaml:"realtime"`
	Security         SecurityConfig         `yaml:"security"`
	ServiceDiscovery ServiceDiscoveryConfig `yaml:"service_discovery"`
	Logging          LoggingConfig          `yaml:"logging"`
	HealthCheck      HealthCheckConfig      `yaml:"health_check"`
	Features         FeaturesConfig         `yaml:"features"`
}

type EnvironmentConfig struct {
	Current   string   `yaml:"current"`
	Available []string `yaml:"available"`
}

type DatabaseConfig struct {
	PostgreSQL PostgreSQLConfig `yaml:"postgresql"`
	MongoDB    MongoDBConfig    `yaml:"mongodb"`
}

type CacheConfig struct {
	Redis RedisConfig `yaml:"redis"`
}

type MessageBrokerConfig struct {
	Kafka KafkaConfig `yaml:"kafka"`
}

type VectorDatabaseConfig struct {
	Qdrant QdrantConfig `yaml:"qdrant"`
}

type SearchConfig struct {
	Elasticsearch ElasticsearchConfig `yaml:"elasticsearch"`
}

type MonitoringConfig struct {
	Prometheus PrometheusConfig `yaml:"prometheus"`
	Grafana    GrafanaConfig    `yaml:"grafana"`
	Jaeger     JaegerConfig     `yaml:"jaeger"`
}

type RealtimeConfig struct {
	WebSocket WebSocketConfig `yaml:"websocket"`
}

type SecurityConfig struct {
	JWT        JWTConfig        `yaml:"jwt"`
	Encryption EncryptionConfig `yaml:"encryption"`
	CORS       CORSConfig       `yaml:"cors"`
}

type ServiceDiscoveryConfig struct {
	Consul     ConsulConfig     `yaml:"consul"`
	Kubernetes KubernetesConfig `yaml:"kubernetes"`
}

type LoggingConfig struct {
	Level        string                 `yaml:"level"`
	Format       string                 `yaml:"format"`
	Output       string                 `yaml:"output"`
	Destinations LogDestinationsConfig  `yaml:"destinations"`
	Fields       map[string]interface{} `yaml:"fields"`
}

type HealthCheckConfig struct {
	Enabled      bool                    `yaml:"enabled"`
	Endpoint     string                  `yaml:"endpoint"`
	Interval     int                     `yaml:"interval"`
	Timeout      int                     `yaml:"timeout"`
	Dependencies []HealthCheckDependency `yaml:"dependencies"`
}

type HealthCheckDependency struct {
	Name     string `yaml:"name"`
	Type     string `yaml:"type"`
	Critical bool   `yaml:"critical"`
}

type FeaturesConfig struct {
	AIEnabled         bool `yaml:"ai_enabled"`
	AnalyticsEnabled  bool `yaml:"analytics_enabled"`
	MonitoringEnabled bool `yaml:"monitoring_enabled"`
	TracingEnabled    bool `yaml:"tracing_enabled"`
	WebSocketEnabled  bool `yaml:"websocket_enabled"`
}

// Load loads the configuration from various sources
func Load() (*Config, error) {
	config := &Config{}

	// Determine environment
	env := getEnv("ERP_ENVIRONMENT", "development")

	// Load environment-specific .env file
	envFile := fmt.Sprintf("shared-config/environments/%s.env", env)
	if _, err := os.Stat(envFile); err == nil {
		if err := godotenv.Load(envFile); err != nil {
			return nil, fmt.Errorf("error loading %s: %w", envFile, err)
		}
	}

	// Load main config.yaml
	configFile := "shared-config/config.yaml"
	if _, err := os.Stat(configFile); err == nil {
		data, err := os.ReadFile(configFile)
		if err != nil {
			return nil, fmt.Errorf("error reading config file: %w", err)
		}

		// Expand environment variables in YAML
		expandedData := os.ExpandEnv(string(data))

		if err := yaml.Unmarshal([]byte(expandedData), config); err != nil {
			return nil, fmt.Errorf("error parsing config file: %w", err)
		}
	}

	// Override with environment variables
	config.overrideWithEnvVars()

	return config, nil
}

// LoadFromPath loads configuration from a specific path
func LoadFromPath(configPath string) (*Config, error) {
	config := &Config{}

	// Change to the specified directory
	originalDir, err := os.Getwd()
	if err != nil {
		return nil, err
	}
	defer os.Chdir(originalDir)

	if err := os.Chdir(configPath); err != nil {
		return nil, fmt.Errorf("failed to change to config directory: %w", err)
	}

	return Load()
}

// overrideWithEnvVars overrides configuration with environment variables
func (c *Config) overrideWithEnvVars() {
	// Environment
	c.Environment.Current = getEnv("ERP_ENVIRONMENT", c.Environment.Current)

	// Database - PostgreSQL
	c.Database.PostgreSQL.Host = getEnv("POSTGRES_HOST", c.Database.PostgreSQL.Host)
	c.Database.PostgreSQL.Port = getEnvAsInt("POSTGRES_PORT", c.Database.PostgreSQL.Port)
	c.Database.PostgreSQL.Username = getEnv("POSTGRES_USER", c.Database.PostgreSQL.Username)
	c.Database.PostgreSQL.Password = getEnv("POSTGRES_PASSWORD", c.Database.PostgreSQL.Password)
	c.Database.PostgreSQL.SSLMode = getEnv("POSTGRES_SSL_MODE", c.Database.PostgreSQL.SSLMode)

	// Database - MongoDB
	c.Database.MongoDB.Host = getEnv("MONGODB_HOST", c.Database.MongoDB.Host)
	c.Database.MongoDB.Port = getEnvAsInt("MONGODB_PORT", c.Database.MongoDB.Port)
	c.Database.MongoDB.Username = getEnv("MONGODB_USER", c.Database.MongoDB.Username)
	c.Database.MongoDB.Password = getEnv("MONGODB_PASSWORD", c.Database.MongoDB.Password)

	// Cache - Redis
	c.Cache.Redis.Host = getEnv("REDIS_HOST", c.Cache.Redis.Host)
	c.Cache.Redis.Port = getEnvAsInt("REDIS_PORT", c.Cache.Redis.Port)
	c.Cache.Redis.Password = getEnv("REDIS_PASSWORD", c.Cache.Redis.Password)

	// Message Broker - Kafka
	if brokers := getEnv("KAFKA_BROKERS", ""); brokers != "" {
		c.MessageBroker.Kafka.Brokers = strings.Split(brokers, ",")
	}

	// Security - JWT
	c.Security.JWT.Secret = getEnv("JWT_SECRET", c.Security.JWT.Secret)
	c.Security.JWT.AccessExpiry = getEnvAsInt("JWT_ACCESS_EXPIRY", c.Security.JWT.AccessExpiry)
	c.Security.JWT.RefreshExpiry = getEnvAsInt("JWT_REFRESH_EXPIRY", c.Security.JWT.RefreshExpiry)

	// Logging
	c.Logging.Level = getEnv("LOG_LEVEL", c.Logging.Level)
	c.Logging.Format = getEnv("LOG_FORMAT", c.Logging.Format)
	c.Logging.Output = getEnv("LOG_OUTPUT", c.Logging.Output)
}

// Helper functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvAsBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}

func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}

// GetServiceName returns the service name from environment or default
func (c *Config) GetServiceName() string {
	return getEnv("SERVICE_NAME", "erp-service")
}

// GetServiceVersion returns the service version from environment or default
func (c *Config) GetServiceVersion() string {
	return getEnv("SERVICE_VERSION", "1.0.0")
}

// IsProduction returns true if running in production environment
func (c *Config) IsProduction() bool {
	return c.Environment.Current == "production"
}

// IsDevelopment returns true if running in development environment
func (c *Config) IsDevelopment() bool {
	return c.Environment.Current == "development"
}

// GetConfigPath returns the path to the shared config directory
func GetConfigPath() string {
	if path := os.Getenv("ERP_CONFIG_PATH"); path != "" {
		return path
	}
	
	// Try to find the shared-config directory
	currentDir, _ := os.Getwd()
	for {
		configPath := filepath.Join(currentDir, "shared-config")
		if _, err := os.Stat(configPath); err == nil {
			return configPath
		}
		
		parent := filepath.Dir(currentDir)
		if parent == currentDir {
			break
		}
		currentDir = parent
	}
	
	return "shared-config"
}