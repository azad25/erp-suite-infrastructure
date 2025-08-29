-- Initialize multiple PostgreSQL databases for ERP Suite
-- This file creates separate databases for each module

-- Create databases if they don't exist
SELECT 'CREATE DATABASE erp_auth' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_auth')\gexec
SELECT 'CREATE DATABASE erp_crm' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_crm')\gexec
SELECT 'CREATE DATABASE erp_hrm' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_hrm')\gexec
SELECT 'CREATE DATABASE erp_finance' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_finance')\gexec
SELECT 'CREATE DATABASE erp_inventory' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_inventory')\gexec
SELECT 'CREATE DATABASE erp_projects' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_projects')\gexec
SELECT 'CREATE DATABASE erp_gateway' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_gateway')\gexec
SELECT 'CREATE DATABASE erp_analytics' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_analytics')\gexec
SELECT 'CREATE DATABASE erp_subscription' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_subscription')\gexec
SELECT 'CREATE DATABASE erp_sales' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'erp_sales')\gexec

-- Grant privileges to postgres user (already has superuser privileges, but explicit for clarity)
-- These commands will only run if the databases were created
\c erp_auth
GRANT ALL PRIVILEGES ON DATABASE erp_auth TO postgres;

\c erp_crm
GRANT ALL PRIVILEGES ON DATABASE erp_crm TO postgres;

\c erp_hrm
GRANT ALL PRIVILEGES ON DATABASE erp_hrm TO postgres;

\c erp_finance
GRANT ALL PRIVILEGES ON DATABASE erp_finance TO postgres;

\c erp_inventory
GRANT ALL PRIVILEGES ON DATABASE erp_inventory TO postgres;

\c erp_projects
GRANT ALL PRIVILEGES ON DATABASE erp_projects TO postgres;

\c erp_gateway
GRANT ALL PRIVILEGES ON DATABASE erp_gateway TO postgres;

\c erp_analytics
GRANT ALL PRIVILEGES ON DATABASE erp_analytics TO postgres;

\c erp_subscription
GRANT ALL PRIVILEGES ON DATABASE erp_subscription TO postgres;

\c erp_sales
GRANT ALL PRIVILEGES ON DATABASE erp_sales TO postgres;