# Terraform variables for production environment

env              = "prod"
region           = "ap-southeast-1" # Singapore region (primary)
secondary_region = "ap-northeast-1" # Tokyo region (secondary)
profile          = "prod"

# ---- Aurora Global Database ----

# Primary (Singapore), reuse the existing prod-vpc resources
rds_primary_db_subnet_group_name = "<rds-primary-db-subnet-group>"
rds_primary_security_group_id    = "<rds_primary_security_group_id>"

# Secondary (Tokyo), networking is created by the vpc module
rds_secondary_vpc_cidr             = "10.2.0.0/16"
rds_secondary_azs                  = ["ap-northeast-1a", "ap-northeast-1c"]
rds_secondary_private_subnet_cidrs = ["10.2.16.0/20", "10.2.48.0/20"]

# RDS Aurora cluster settings
rds_engine_version          = "16.11"
rds_instance_class          = "db.r6g.large"
rds_db_name                 = "<prod_db_name>" # prod_db
rds_source_master_secret_id = "prod/rds/prod-db-root-secret"
rds_skip_final_snapshot     = false
rds_deletion_protection     = true
rds_storage_type            = "aurora-iopt1"

# Enhanced Monitoring and Performance Insights
rds_monitoring_role_name                  = "rds-aurora-monitoring-role"
rds_monitoring_interval                   = 60
rds_performance_insights_enabled          = true
rds_performance_insights_retention_period = 7
