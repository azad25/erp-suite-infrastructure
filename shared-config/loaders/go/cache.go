package sharedconfig

import (
	"fmt"
	"time"
)

// RedisConfig holds Redis configuration
type RedisConfig struct {
	Host      string              `yaml:"host"`
	Port      int                 `yaml:"port"`
	Password  string              `yaml:"password"`
	Databases RedisDatabasesConfig `yaml:"databases"`
	Pool      RedisPoolConfig     `yaml:"pool"`
}

type RedisDatabasesConfig struct {
	Default   int `yaml:"default"`
	Sessions  int `yaml:"sessions"`
	Queues    int `yaml:"queues"`
	WebSocket int `yaml:"websocket"`
	Cache     int `yaml:"cache"`
}

type RedisPoolConfig struct {
	MaxActive    int `yaml:"max_active"`
	MaxIdle      int `yaml:"max_idle"`
	IdleTimeout  int `yaml:"idle_timeout"`
	DialTimeout  int `yaml:"dial_timeout"`
	ReadTimeout  int `yaml:"read_timeout"`
	WriteTimeout int `yaml:"write_timeout"`
}

// KafkaConfig holds Kafka configuration
type KafkaConfig struct {
	Brokers        []string                `yaml:"brokers"`
	Topics         KafkaTopicsConfig       `yaml:"topics"`
	ConsumerGroups KafkaConsumerGroupsConfig `yaml:"consumer_groups"`
	Producer       KafkaProducerConfig     `yaml:"producer"`
	Consumer       KafkaConsumerConfig     `yaml:"consumer"`
}

type KafkaTopicsConfig struct {
	AuthEvents         string `yaml:"auth_events"`
	UserEvents         string `yaml:"user_events"`
	BusinessEvents     string `yaml:"business_events"`
	SystemEvents       string `yaml:"system_events"`
	AIEvents           string `yaml:"ai_events"`
	NotificationEvents string `yaml:"notification_events"`
}

type KafkaConsumerGroupsConfig struct {
	AuthService         string `yaml:"auth_service"`
	NotificationService string `yaml:"notification_service"`
	AnalyticsService    string `yaml:"analytics_service"`
	AuditService        string `yaml:"audit_service"`
	AIService           string `yaml:"ai_service"`
}

type KafkaProducerConfig struct {
	BatchSize       int    `yaml:"batch_size"`
	LingerMs        int    `yaml:"linger_ms"`
	CompressionType string `yaml:"compression_type"`
	Acks            string `yaml:"acks"`
	Retries         int    `yaml:"retries"`
}

type KafkaConsumerConfig struct {
	AutoOffsetReset         string `yaml:"auto_offset_reset"`
	EnableAutoCommit        bool   `yaml:"enable_auto_commit"`
	AutoCommitIntervalMs    int    `yaml:"auto_commit_interval_ms"`
	SessionTimeoutMs        int    `yaml:"session_timeout_ms"`
	HeartbeatIntervalMs     int    `yaml:"heartbeat_interval_ms"`
}

// QdrantConfig holds Qdrant vector database configuration
type QdrantConfig struct {
	Host        string                 `yaml:"host"`
	HTTPPort    int                    `yaml:"http_port"`
	GRPCPort    int                    `yaml:"grpc_port"`
	APIKey      string                 `yaml:"api_key"`
	Collections QdrantCollectionsConfig `yaml:"collections"`
	Vector      QdrantVectorConfig     `yaml:"vector"`
}

type QdrantCollectionsConfig struct {
	Documents     string `yaml:"documents"`
	Products      string `yaml:"products"`
	Conversations string `yaml:"conversations"`
	KnowledgeBase string `yaml:"knowledge_base"`
}

type QdrantVectorConfig struct {
	Size     int    `yaml:"size"`
	Distance string `yaml:"distance"`
}

// ElasticsearchConfig holds Elasticsearch configuration
type ElasticsearchConfig struct {
	Host     string                       `yaml:"host"`
	Port     int                          `yaml:"port"`
	Username string                       `yaml:"username"`
	Password string                       `yaml:"password"`
	Scheme   string                       `yaml:"scheme"`
	Indices  ElasticsearchIndicesConfig   `yaml:"indices"`
	Settings ElasticsearchSettingsConfig  `yaml:"settings"`
}

type ElasticsearchIndicesConfig struct {
	Contacts     string `yaml:"contacts"`
	Products     string `yaml:"products"`
	Documents    string `yaml:"documents"`
	Employees    string `yaml:"employees"`
	Transactions string `yaml:"transactions"`
}

type ElasticsearchSettingsConfig struct {
	MaxRetries     int    `yaml:"max_retries"`
	RetryOnStatus  string `yaml:"retry_on_status"`
	Timeout        int    `yaml:"timeout"`
}

// GetConnectionString returns the Redis connection string for a specific database
func (r *RedisConfig) GetConnectionString(database string) string {
	dbNum := r.getDatabaseNumber(database)
	if r.Password != "" {
		return fmt.Sprintf("redis://:%s@%s:%d/%d", r.Password, r.Host, r.Port, dbNum)
	}
	return fmt.Sprintf("redis://%s:%d/%d", r.Host, r.Port, dbNum)
}

// GetAddress returns the Redis address
func (r *RedisConfig) GetAddress() string {
	return fmt.Sprintf("%s:%d", r.Host, r.Port)
}

// getDatabaseNumber returns the database number for a given purpose
func (r *RedisConfig) getDatabaseNumber(purpose string) int {
	switch purpose {
	case "default":
		return r.Databases.Default
	case "sessions":
		return r.Databases.Sessions
	case "queues":
		return r.Databases.Queues
	case "websocket":
		return r.Databases.WebSocket
	case "cache":
		return r.Databases.Cache
	default:
		return r.Databases.Default // Default fallback
	}
}

// GetDialTimeout returns the dial timeout duration
func (r *RedisPoolConfig) GetDialTimeout() time.Duration {
	if r.DialTimeout <= 0 {
		return 5 * time.Second
	}
	return time.Duration(r.DialTimeout) * time.Second
}

// GetReadTimeout returns the read timeout duration
func (r *RedisPoolConfig) GetReadTimeout() time.Duration {
	if r.ReadTimeout <= 0 {
		return 3 * time.Second
	}
	return time.Duration(r.ReadTimeout) * time.Second
}

// GetWriteTimeout returns the write timeout duration
func (r *RedisPoolConfig) GetWriteTimeout() time.Duration {
	if r.WriteTimeout <= 0 {
		return 3 * time.Second
	}
	return time.Duration(r.WriteTimeout) * time.Second
}

// GetIdleTimeout returns the idle timeout duration
func (r *RedisPoolConfig) GetIdleTimeout() time.Duration {
	if r.IdleTimeout <= 0 {
		return 240 * time.Second
	}
	return time.Duration(r.IdleTimeout) * time.Second
}

// GetBrokerList returns the Kafka broker list as a comma-separated string
func (k *KafkaConfig) GetBrokerList() string {
	if len(k.Brokers) == 0 {
		return "localhost:9092"
	}
	return fmt.Sprintf("%v", k.Brokers)
}

// GetTopicName returns the topic name for a given event type
func (k *KafkaTopicsConfig) GetTopicName(eventType string) string {
	switch eventType {
	case "auth":
		return k.AuthEvents
	case "user":
		return k.UserEvents
	case "business":
		return k.BusinessEvents
	case "system":
		return k.SystemEvents
	case "ai":
		return k.AIEvents
	case "notification":
		return k.NotificationEvents
	default:
		return k.SystemEvents // Default fallback
	}
}

// GetConsumerGroup returns the consumer group for a given service
func (k *KafkaConsumerGroupsConfig) GetConsumerGroup(service string) string {
	switch service {
	case "auth":
		return k.AuthService
	case "notification":
		return k.NotificationService
	case "analytics":
		return k.AnalyticsService
	case "audit":
		return k.AuditService
	case "ai":
		return k.AIService
	default:
		return fmt.Sprintf("%s-group", service)
	}
}

// GetHTTPURL returns the Qdrant HTTP URL
func (q *QdrantConfig) GetHTTPURL() string {
	return fmt.Sprintf("http://%s:%d", q.Host, q.HTTPPort)
}

// GetGRPCAddress returns the Qdrant gRPC address
func (q *QdrantConfig) GetGRPCAddress() string {
	return fmt.Sprintf("%s:%d", q.Host, q.GRPCPort)
}

// GetCollectionName returns the collection name for a given purpose
func (q *QdrantCollectionsConfig) GetCollectionName(purpose string) string {
	switch purpose {
	case "documents":
		return q.Documents
	case "products":
		return q.Products
	case "conversations":
		return q.Conversations
	case "knowledge", "knowledge_base":
		return q.KnowledgeBase
	default:
		return q.Documents // Default fallback
	}
}

// GetURL returns the Elasticsearch URL
func (e *ElasticsearchConfig) GetURL() string {
	return fmt.Sprintf("%s://%s:%d", e.Scheme, e.Host, e.Port)
}

// GetIndexName returns the index name for a given purpose
func (e *ElasticsearchIndicesConfig) GetIndexName(purpose string) string {
	switch purpose {
	case "contacts":
		return e.Contacts
	case "products":
		return e.Products
	case "documents":
		return e.Documents
	case "employees":
		return e.Employees
	case "transactions":
		return e.Transactions
	default:
		return fmt.Sprintf("erp_%s", purpose)
	}
}

// GetTimeout returns the timeout duration
func (e *ElasticsearchSettingsConfig) GetTimeout() time.Duration {
	if e.Timeout <= 0 {
		return 30 * time.Second
	}
	return time.Duration(e.Timeout) * time.Second
}