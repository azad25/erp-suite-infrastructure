package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"text/template"
	"time"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Environment struct {
		Name      string `yaml:"name"`
		Debug     bool   `yaml:"debug"`
		LogLevel  string `yaml:"log_level"`
		HotReload bool   `yaml:"hot_reload"`
	} `yaml:"environment"`

	Databases struct {
		PostgreSQL struct {
			Host               string            `yaml:"host"`
			Port               int               `yaml:"port"`
			Username           string            `yaml:"username"`
			Password           string            `yaml:"password"`
			SSLMode            string            `yaml:"ssl_mode"`
			MaxConnections     int               `yaml:"max_connections"`
			ConnectionTimeout  int               `yaml:"connection_timeout"`
			Databases          map[string]string `yaml:"databases"`
		} `yaml:"postgresql"`

		MongoDB struct {
			Host         string            `yaml:"host"`
			Port         int               `yaml:"port"`
			Username     string            `yaml:"username"`
			Password     string            `yaml:"password"`
			AuthSource   string            `yaml:"auth_source"`
			MaxPoolSize  int               `yaml:"max_pool_size"`
			SSL          bool              `yaml:"ssl,omitempty"`
			Databases    map[string]string `yaml:"databases"`
		} `yaml:"mongodb"`

		Redis struct {
			Host           string         `yaml:"host"`
			Port           int            `yaml:"port"`
			Password       string         `yaml:"password"`
			MaxConnections int            `yaml:"max_connections"`
			SSL            bool           `yaml:"ssl,omitempty"`
			Databases      map[string]int `yaml:"databases"`
		} `yaml:"redis"`

		Qdrant struct {
			Host        string            `yaml:"host"`
			HTTPPort    int               `yaml:"http_port"`
			GRPCPort    int               `yaml:"grpc_port"`
			APIKey      string            `yaml:"api_key"`
			SSL         bool              `yaml:"ssl,omitempty"`
			Collections map[string]string `yaml:"collections"`
		} `yaml:"qdrant"`
	} `yaml:"databases"`

	Messaging struct {
		Kafka struct {
			Brokers          []string          `yaml:"brokers"`
			SecurityProtocol string            `yaml:"security_protocol"`
			SASLMechanism    string            `yaml:"sasl_mechanism"`
			SASLUsername     string            `yaml:"sasl_username,omitempty"`
			SASLPassword     string            `yaml:"sasl_password,omitempty"`
			Topics           map[string]string `yaml:"topics"`
			ConsumerGroups   map[string]string `yaml:"consumer_groups"`
		} `yaml:"kafka"`
	} `yaml:"messaging"`

	Search struct {
		Elasticsearch struct {
			Host        string            `yaml:"host"`
			Port        int               `yaml:"port"`
			Username    string            `yaml:"username"`
			Password    string            `yaml:"password"`
			UseSSL      bool              `yaml:"use_ssl"`
			VerifyCerts bool              `yaml:"verify_certs"`
			CACert      string            `yaml:"ca_cert,omitempty"`
			Indices     map[string]string `yaml:"indices"`
		} `yaml:"elasticsearch"`
	} `yaml:"search"`

	Monitoring struct {
		Prometheus struct {
			Host               string `yaml:"host"`
			Port               int    `yaml:"port"`
			ScrapeInterval     string `yaml:"scrape_interval"`
			EvaluationInterval string `yaml:"evaluation_interval"`
		} `yaml:"prometheus"`

		Grafana struct {
			Host     string `yaml:"host"`
			Port     int    `yaml:"port"`
			Username string `yaml:"username"`
			Password string `yaml:"password"`
		} `yaml:"grafana"`

		Jaeger struct {
			Host      string `yaml:"host"`
			Port      int    `yaml:"port"`
			GRPCPort  int    `yaml:"grpc_port"`
			HTTPPort  int    `yaml:"http_port"`
			AgentHost string `yaml:"agent_host"`
			AgentPort int    `yaml:"agent_port"`
		} `yaml:"jaeger"`

		Logging struct {
			Level  string `yaml:"level"`
			Format string `yaml:"format"`
			Output string `yaml:"output"`
		} `yaml:"logging"`
	} `yaml:"monitoring"`

	Realtime struct {
		WebSocket struct {
			Host        string   `yaml:"host"`
			Port        int      `yaml:"port"`
			Path        string   `yaml:"path"`
			CORSOrigins []string `yaml:"cors_origins"`
			SSL         bool     `yaml:"ssl,omitempty"`
			Transports  []string `yaml:"transports"`
		} `yaml:"websocket"`
	} `yaml:"realtime"`

	Security struct {
		JWT struct {
			Secret             string `yaml:"secret"`
			AccessTokenExpiry  int    `yaml:"access_token_expiry"`
			RefreshTokenExpiry int    `yaml:"refresh_token_expiry"`
			Algorithm          string `yaml:"algorithm"`
		} `yaml:"jwt"`

		CORS struct {
			AllowedOrigins   []string `yaml:"allowed_origins"`
			AllowedMethods   []string `yaml:"allowed_methods"`
			AllowedHeaders   []string `yaml:"allowed_headers"`
			AllowCredentials bool     `yaml:"allow_credentials"`
		} `yaml:"cors"`

		RateLimiting struct {
			Enabled           bool `yaml:"enabled"`
			RequestsPerMinute int  `yaml:"requests_per_minute"`
			BurstSize         int  `yaml:"burst_size"`
		} `yaml:"rate_limiting"`

		Encryption struct {
			Key       string `yaml:"key,omitempty"`
			Algorithm string `yaml:"algorithm,omitempty"`
		} `yaml:"encryption,omitempty"`
	} `yaml:"security"`

	Services map[string]struct {
		Host           string `yaml:"host"`
		HTTPPort       int    `yaml:"http_port,omitempty"`
		GRPCPort       int    `yaml:"grpc_port,omitempty"`
		Port           int    `yaml:"port,omitempty"`
		HealthEndpoint string `yaml:"health_endpoint,omitempty"`
	} `yaml:"services"`

	External struct {
		Email struct {
			Provider     string `yaml:"provider"`
			SMTPHost     string `yaml:"smtp_host"`
			SMTPPort     int    `yaml:"smtp_port"`
			SMTPUsername string `yaml:"smtp_username"`
			SMTPPassword string `yaml:"smtp_password"`
			FromAddress  string `yaml:"from_address"`
			UseTLS       bool   `yaml:"use_tls,omitempty"`
		} `yaml:"email"`

		Storage struct {
			Provider    string `yaml:"provider"`
			LocalPath   string `yaml:"local_path,omitempty"`
			S3Bucket    string `yaml:"s3_bucket,omitempty"`
			S3Region    string `yaml:"s3_region,omitempty"`
			S3AccessKey string `yaml:"s3_access_key,omitempty"`
			S3SecretKey string `yaml:"s3_secret_key,omitempty"`
		} `yaml:"storage"`

		AI struct {
			OpenAI struct {
				APIKey    string `yaml:"api_key"`
				Model     string `yaml:"model"`
				MaxTokens int    `yaml:"max_tokens"`
			} `yaml:"openai"`
		} `yaml:"ai"`

		Payment struct {
			Stripe struct {
				PublishableKey string `yaml:"publishable_key"`
				SecretKey      string `yaml:"secret_key"`
				WebhookSecret  string `yaml:"webhook_secret"`
			} `yaml:"stripe"`
		} `yaml:"payment"`
	} `yaml:"external"`

	FeatureFlags map[string]bool `yaml:"feature_flags"`
}

const envTemplate = `# Generated environment file for {{.Module}} module
# Environment: {{.Environment}}
# Generated at: {{.Timestamp}}

# ============================================================================
# ENVIRONMENT
# ============================================================================
ENVIRONMENT={{.Config.Environment.Name}}
DEBUG={{.Config.Environment.Debug}}
LOG_LEVEL={{.Config.Environment.LogLevel}}
HOT_RELOAD={{.Config.Environment.HotReload}}

# ============================================================================
# DATABASE CONNECTIONS
# ============================================================================

# PostgreSQL
DB_HOST={{.Config.Databases.PostgreSQL.Host}}
DB_PORT={{.Config.Databases.PostgreSQL.Port}}
DB_USER={{.Config.Databases.PostgreSQL.Username}}
DB_PASSWORD={{.Config.Databases.PostgreSQL.Password}}
DB_SSL_MODE={{.Config.Databases.PostgreSQL.SSLMode}}
DB_MAX_CONNECTIONS={{.Config.Databases.PostgreSQL.MaxConnections}}
DB_CONNECTION_TIMEOUT={{.Config.Databases.PostgreSQL.ConnectionTimeout}}

# Module-specific database
{{- if eq .Module "auth"}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.auth}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.auth}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- else if eq .Module "crm"}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.crm}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.crm}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- else if eq .Module "hrm"}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.hrm}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.hrm}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- else if eq .Module "finance"}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.finance}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.finance}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- else if eq .Module "inventory"}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.inventory}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.inventory}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- else if eq .Module "projects"}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.projects}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.projects}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- else}}
DB_NAME={{.Config.Databases.PostgreSQL.Databases.auth}}
DATABASE_URL=postgresql://{{.Config.Databases.PostgreSQL.Username}}:{{.Config.Databases.PostgreSQL.Password}}@{{.Config.Databases.PostgreSQL.Host}}:{{.Config.Databases.PostgreSQL.Port}}/{{.Config.Databases.PostgreSQL.Databases.auth}}?sslmode={{.Config.Databases.PostgreSQL.SSLMode}}
{{- end}}

# MongoDB
MONGODB_HOST={{.Config.Databases.MongoDB.Host}}
MONGODB_PORT={{.Config.Databases.MongoDB.Port}}
MONGODB_USER={{.Config.Databases.MongoDB.Username}}
MONGODB_PASSWORD={{.Config.Databases.MongoDB.Password}}
MONGODB_AUTH_SOURCE={{.Config.Databases.MongoDB.AuthSource}}
MONGODB_MAX_POOL_SIZE={{.Config.Databases.MongoDB.MaxPoolSize}}
MONGODB_URL=mongodb://{{.Config.Databases.MongoDB.Username}}:{{.Config.Databases.MongoDB.Password}}@{{.Config.Databases.MongoDB.Host}}:{{.Config.Databases.MongoDB.Port}}/{{.Config.Databases.MongoDB.Databases.analytics}}?authSource={{.Config.Databases.MongoDB.AuthSource}}

# Redis
REDIS_HOST={{.Config.Databases.Redis.Host}}
REDIS_PORT={{.Config.Databases.Redis.Port}}
REDIS_PASSWORD={{.Config.Databases.Redis.Password}}
REDIS_MAX_CONNECTIONS={{.Config.Databases.Redis.MaxConnections}}
REDIS_URL=redis://:{{.Config.Databases.Redis.Password}}@{{.Config.Databases.Redis.Host}}:{{.Config.Databases.Redis.Port}}/{{.Config.Databases.Redis.Databases.cache}}

# Qdrant
QDRANT_HOST={{.Config.Databases.Qdrant.Host}}
QDRANT_HTTP_PORT={{.Config.Databases.Qdrant.HTTPPort}}
QDRANT_GRPC_PORT={{.Config.Databases.Qdrant.GRPCPort}}
{{- if .Config.Databases.Qdrant.APIKey}}
QDRANT_API_KEY={{.Config.Databases.Qdrant.APIKey}}
{{- end}}
QDRANT_URL=http{{- if .Config.Databases.Qdrant.SSL}}s{{- end}}://{{.Config.Databases.Qdrant.Host}}:{{.Config.Databases.Qdrant.HTTPPort}}

# ============================================================================
# MESSAGE BROKERS
# ============================================================================

# Kafka
KAFKA_BROKERS={{join .Config.Messaging.Kafka.Brokers ","}}
KAFKA_SECURITY_PROTOCOL={{.Config.Messaging.Kafka.SecurityProtocol}}
{{- if .Config.Messaging.Kafka.SASLMechanism}}
KAFKA_SASL_MECHANISM={{.Config.Messaging.Kafka.SASLMechanism}}
{{- end}}
{{- if .Config.Messaging.Kafka.SASLUsername}}
KAFKA_SASL_USERNAME={{.Config.Messaging.Kafka.SASLUsername}}
{{- end}}
{{- if .Config.Messaging.Kafka.SASLPassword}}
KAFKA_SASL_PASSWORD={{.Config.Messaging.Kafka.SASLPassword}}
{{- end}}

# Kafka Topics
KAFKA_TOPIC_AUTH={{.Config.Messaging.Kafka.Topics.auth_events}}
KAFKA_TOPIC_USER={{.Config.Messaging.Kafka.Topics.user_events}}
KAFKA_TOPIC_BUSINESS={{.Config.Messaging.Kafka.Topics.business_events}}
KAFKA_TOPIC_SYSTEM={{.Config.Messaging.Kafka.Topics.system_events}}
KAFKA_TOPIC_AI={{.Config.Messaging.Kafka.Topics.ai_events}}
KAFKA_TOPIC_NOTIFICATIONS={{.Config.Messaging.Kafka.Topics.notification_events}}

# Module-specific consumer group
{{- if eq .Module "auth"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.auth_service}}
{{- else if eq .Module "crm"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.crm_service}}
{{- else if eq .Module "hrm"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.hrm_service}}
{{- else if eq .Module "finance"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.finance_service}}
{{- else if eq .Module "inventory"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.inventory_service}}
{{- else if eq .Module "projects"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.projects_service}}
{{- else if eq .Module "ai"}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.ai_service}}
{{- else}}
KAFKA_CONSUMER_GROUP={{.Config.Messaging.Kafka.ConsumerGroups.auth_service}}
{{- end}}

# ============================================================================
# SEARCH & ANALYTICS
# ============================================================================

# Elasticsearch
ELASTICSEARCH_HOST={{.Config.Search.Elasticsearch.Host}}
ELASTICSEARCH_PORT={{.Config.Search.Elasticsearch.Port}}
ELASTICSEARCH_USERNAME={{.Config.Search.Elasticsearch.Username}}
ELASTICSEARCH_PASSWORD={{.Config.Search.Elasticsearch.Password}}
ELASTICSEARCH_USE_SSL={{.Config.Search.Elasticsearch.UseSSL}}
ELASTICSEARCH_VERIFY_CERTS={{.Config.Search.Elasticsearch.VerifyCerts}}
ELASTICSEARCH_URL=http{{- if .Config.Search.Elasticsearch.UseSSL}}s{{- end}}://{{.Config.Search.Elasticsearch.Username}}:{{.Config.Search.Elasticsearch.Password}}@{{.Config.Search.Elasticsearch.Host}}:{{.Config.Search.Elasticsearch.Port}}

# ============================================================================
# MONITORING & OBSERVABILITY
# ============================================================================

# Prometheus
PROMETHEUS_HOST={{.Config.Monitoring.Prometheus.Host}}
PROMETHEUS_PORT={{.Config.Monitoring.Prometheus.Port}}
PROMETHEUS_URL=http://{{.Config.Monitoring.Prometheus.Host}}:{{.Config.Monitoring.Prometheus.Port}}

# Grafana
GRAFANA_HOST={{.Config.Monitoring.Grafana.Host}}
GRAFANA_PORT={{.Config.Monitoring.Grafana.Port}}
GRAFANA_USERNAME={{.Config.Monitoring.Grafana.Username}}
GRAFANA_PASSWORD={{.Config.Monitoring.Grafana.Password}}
GRAFANA_URL=http://{{.Config.Monitoring.Grafana.Username}}:{{.Config.Monitoring.Grafana.Password}}@{{.Config.Monitoring.Grafana.Host}}:{{.Config.Monitoring.Grafana.Port}}

# Jaeger
JAEGER_HOST={{.Config.Monitoring.Jaeger.Host}}
JAEGER_PORT={{.Config.Monitoring.Jaeger.Port}}
JAEGER_GRPC_PORT={{.Config.Monitoring.Jaeger.GRPCPort}}
JAEGER_HTTP_PORT={{.Config.Monitoring.Jaeger.HTTPPort}}
JAEGER_AGENT_HOST={{.Config.Monitoring.Jaeger.AgentHost}}
JAEGER_AGENT_PORT={{.Config.Monitoring.Jaeger.AgentPort}}
JAEGER_ENDPOINT=http://{{.Config.Monitoring.Jaeger.Host}}:{{.Config.Monitoring.Jaeger.HTTPPort}}/api/traces

# Logging
LOG_LEVEL={{.Config.Monitoring.Logging.Level}}
LOG_FORMAT={{.Config.Monitoring.Logging.Format}}
LOG_OUTPUT={{.Config.Monitoring.Logging.Output}}

# ============================================================================
# REAL-TIME COMMUNICATION
# ============================================================================

# WebSocket
WEBSOCKET_HOST={{.Config.Realtime.WebSocket.Host}}
WEBSOCKET_PORT={{.Config.Realtime.WebSocket.Port}}
WEBSOCKET_PATH={{.Config.Realtime.WebSocket.Path}}
WEBSOCKET_URL=http{{- if .Config.Realtime.WebSocket.SSL}}s{{- end}}://{{.Config.Realtime.WebSocket.Host}}:{{.Config.Realtime.WebSocket.Port}}
WEBSOCKET_CORS_ORIGINS={{join .Config.Realtime.WebSocket.CORSOrigins ","}}

# ============================================================================
# SECURITY
# ============================================================================

# JWT
JWT_SECRET={{.Config.Security.JWT.Secret}}
JWT_ACCESS_EXPIRY={{.Config.Security.JWT.AccessTokenExpiry}}
JWT_REFRESH_EXPIRY={{.Config.Security.JWT.RefreshTokenExpiry}}
JWT_ALGORITHM={{.Config.Security.JWT.Algorithm}}

# CORS
ALLOWED_ORIGINS={{join .Config.Security.CORS.AllowedOrigins ","}}
ALLOWED_METHODS={{join .Config.Security.CORS.AllowedMethods ","}}
ALLOWED_HEADERS={{join .Config.Security.CORS.AllowedHeaders ","}}
ALLOW_CREDENTIALS={{.Config.Security.CORS.AllowCredentials}}

# Rate Limiting
RATE_LIMITING_ENABLED={{.Config.Security.RateLimiting.Enabled}}
RATE_LIMIT_RPM={{.Config.Security.RateLimiting.RequestsPerMinute}}
RATE_LIMIT_BURST={{.Config.Security.RateLimiting.BurstSize}}

{{- if .Config.Security.Encryption.Key}}
# Encryption
ENCRYPTION_KEY={{.Config.Security.Encryption.Key}}
ENCRYPTION_ALGORITHM={{.Config.Security.Encryption.Algorithm}}
{{- end}}

# ============================================================================
# SERVICE DISCOVERY
# ============================================================================

{{- range $name, $service := .Config.Services}}
# {{$name | title}} Service
{{$name | upper}}_HOST={{$service.Host}}
{{- if $service.HTTPPort}}
{{$name | upper}}_HTTP_PORT={{$service.HTTPPort}}
{{- end}}
{{- if $service.GRPCPort}}
{{$name | upper}}_GRPC_PORT={{$service.GRPCPort}}
{{- end}}
{{- if $service.Port}}
{{$name | upper}}_PORT={{$service.Port}}
{{- end}}
{{- if $service.HealthEndpoint}}
{{$name | upper}}_HEALTH_ENDPOINT={{$service.HealthEndpoint}}
{{- end}}
{{- end}}

# ============================================================================
# EXTERNAL INTEGRATIONS
# ============================================================================

# Email
EMAIL_PROVIDER={{.Config.External.Email.Provider}}
SMTP_HOST={{.Config.External.Email.SMTPHost}}
SMTP_PORT={{.Config.External.Email.SMTPPort}}
SMTP_USERNAME={{.Config.External.Email.SMTPUsername}}
SMTP_PASSWORD={{.Config.External.Email.SMTPPassword}}
EMAIL_FROM_ADDRESS={{.Config.External.Email.FromAddress}}
{{- if .Config.External.Email.UseTLS}}
SMTP_USE_TLS={{.Config.External.Email.UseTLS}}
{{- end}}

# Storage
STORAGE_PROVIDER={{.Config.External.Storage.Provider}}
{{- if .Config.External.Storage.LocalPath}}
STORAGE_LOCAL_PATH={{.Config.External.Storage.LocalPath}}
{{- end}}
{{- if .Config.External.Storage.S3Bucket}}
S3_BUCKET={{.Config.External.Storage.S3Bucket}}
S3_REGION={{.Config.External.Storage.S3Region}}
S3_ACCESS_KEY={{.Config.External.Storage.S3AccessKey}}
S3_SECRET_KEY={{.Config.External.Storage.S3SecretKey}}
{{- end}}

# AI
OPENAI_API_KEY={{.Config.External.AI.OpenAI.APIKey}}
OPENAI_MODEL={{.Config.External.AI.OpenAI.Model}}
OPENAI_MAX_TOKENS={{.Config.External.AI.OpenAI.MaxTokens}}

# Payment
STRIPE_PUBLISHABLE_KEY={{.Config.External.Payment.Stripe.PublishableKey}}
STRIPE_SECRET_KEY={{.Config.External.Payment.Stripe.SecretKey}}
STRIPE_WEBHOOK_SECRET={{.Config.External.Payment.Stripe.WebhookSecret}}

# ============================================================================
# FEATURE FLAGS
# ============================================================================

{{- range $flag, $enabled := .Config.FeatureFlags}}
FEATURE_{{$flag | upper}}={{$enabled}}
{{- end}}

# ============================================================================
# MODULE-SPECIFIC CONFIGURATIONS
# ============================================================================

# Module identification
MODULE_NAME={{.Module}}
SERVICE_NAME={{.Module}}-service

{{- if eq .Module "auth"}}
# Auth service specific
GRPC_PORT={{.Config.Services.auth_service.GRPCPort}}
HTTP_PORT={{.Config.Services.auth_service.HTTPPort}}
{{- else if eq .Module "crm"}}
# CRM service specific
GRPC_PORT={{.Config.Services.crm_service.GRPCPort}}
HTTP_PORT={{.Config.Services.crm_service.HTTPPort}}
{{- else if eq .Module "hrm"}}
# HRM service specific
GRPC_PORT={{.Config.Services.hrm_service.GRPCPort}}
HTTP_PORT={{.Config.Services.hrm_service.HTTPPort}}
{{- else if eq .Module "finance"}}
# Finance service specific
GRPC_PORT={{.Config.Services.finance_service.GRPCPort}}
HTTP_PORT={{.Config.Services.finance_service.HTTPPort}}
{{- else if eq .Module "inventory"}}
# Inventory service specific
GRPC_PORT={{.Config.Services.inventory_service.GRPCPort}}
HTTP_PORT={{.Config.Services.inventory_service.HTTPPort}}
{{- else if eq .Module "projects"}}
# Projects service specific
GRPC_PORT={{.Config.Services.projects_service.GRPCPort}}
HTTP_PORT={{.Config.Services.projects_service.HTTPPort}}
{{- else if eq .Module "ai"}}
# AI service specific
GRPC_PORT={{.Config.Services.ai_service.GRPCPort}}
HTTP_PORT={{.Config.Services.ai_service.HTTPPort}}
{{- else if eq .Module "frontend"}}
# Frontend specific
PORT={{.Config.Services.frontend.Port}}
NEXT_PUBLIC_API_URL=http://{{.Config.Services.auth_service.Host}}:{{.Config.Services.auth_service.HTTPPort}}
NEXT_PUBLIC_WEBSOCKET_URL={{.Config.Realtime.WebSocket.Host}}:{{.Config.Realtime.WebSocket.Port}}
{{- end}}
`

type TemplateData struct {
	Module      string
	Environment string
	Timestamp   string
	Config      Config
}

func main() {
	var (
		environment = flag.String("env", "development", "Environment (development, staging, production, testing)")
		module      = flag.String("module", "auth", "Module name (auth, crm, hrm, finance, inventory, projects, ai, frontend)")
		output      = flag.String("output", "", "Output file path (default: .env.{module}.{environment})")
		verbose     = flag.Bool("verbose", false, "Verbose output")
	)
	flag.Parse()

	if *verbose {
		log.Printf("Generating environment file for module '%s' in environment '%s'", *module, *environment)
	}

	// Get the workspace root
	workspaceRoot, err := findWorkspaceRoot()
	if err != nil {
		log.Fatalf("Failed to find workspace root: %v", err)
	}

	// Load configuration
	configPath := filepath.Join(workspaceRoot, "erp-suite", "shared-config", "environments", *environment+".yaml")
	
	data, err := os.ReadFile(configPath)
	if err != nil {
		log.Fatalf("Failed to read config file %s: %v", configPath, err)
	}

	// Expand environment variables in the YAML content
	expandedData := os.ExpandEnv(string(data))

	var config Config
	if err := yaml.Unmarshal([]byte(expandedData), &config); err != nil {
		log.Fatalf("Failed to unmarshal config: %v", err)
	}

	// Prepare template data
	templateData := TemplateData{
		Module:      *module,
		Environment: *environment,
		Timestamp:   time.Now().Format(time.RFC3339),
		Config:      config,
	}

	// Parse and execute template
	tmpl, err := template.New("env").Funcs(template.FuncMap{
		"join": strings.Join,
		"upper": strings.ToUpper,
		"title": strings.Title,
	}).Parse(envTemplate)
	if err != nil {
		log.Fatalf("Failed to parse template: %v", err)
	}

	// Determine output file
	outputFile := *output
	if outputFile == "" {
		outputFile = fmt.Sprintf(".env.%s.%s", *module, *environment)
	}

	// Create output file
	file, err := os.Create(outputFile)
	if err != nil {
		log.Fatalf("Failed to create output file %s: %v", outputFile, err)
	}
	defer file.Close()

	// Execute template
	if err := tmpl.Execute(file, templateData); err != nil {
		log.Fatalf("Failed to execute template: %v", err)
	}

	if *verbose {
		log.Printf("Successfully generated environment file: %s", outputFile)
	}

	fmt.Printf("Environment file generated: %s\n", outputFile)
}

func findWorkspaceRoot() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}

	for {
		if _, err := os.Stat(filepath.Join(dir, ".git")); err == nil {
			return dir, nil
		}
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir, nil
		}
		if _, err := os.Stat(filepath.Join(dir, "package.json")); err == nil {
			return dir, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", fmt.Errorf("workspace root not found")
}