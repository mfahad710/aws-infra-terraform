variable "env" {
  description = "Environment name (stg or prod)"
  type        = string
}

variable "region" {
  description = "AWS region (primary)"
  type        = string
}

variable "secondary_region" {
  description = "AWS region for the Aurora Global Database secondary cluster"
  type        = string
}

variable "profile" {
  description = "AWS CLI profile used to authenticate"
  type        = string
}

# ---- Aurora RDS ----

variable "rds_primary_db_subnet_group_name" {
  description = "Name of the pre-existing DB subnet group in the primary region"
  type        = string
}

variable "rds_primary_security_group_id" {
  description = "ID of the pre-existing security group attached to the primary Aurora cluster"
  type        = string
}

variable "rds_secondary_vpc_cidr" {
  description = "CIDR block for the secondary-region VPC created for Aurora"
  type        = string
}

variable "rds_secondary_azs" {
  description = "Availability Zones for the secondary-region private subnets"
  type        = list(string)
}

variable "rds_secondary_private_subnet_cidrs" {
  description = "CIDR blocks for secondary-region private subnets (same order as rds_secondary_azs)"
  type        = list(string)
}

variable "rds_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
}

variable "rds_instance_class" {
  description = "Instance class for Aurora cluster instances"
  type        = string
}

variable "rds_db_name" {
  description = "Initial Aurora database name"
  type        = string
}

variable "rds_source_master_secret_id" {
  description = "Name or ARN of an existing Secrets Manager secret to seed Aurora master credentials from. Read once at cluster creation."
  type        = string
}

variable "rds_storage_type" {
  description = "Storage type for the Aurora cluster"
  type        = string
}

variable "rds_skip_final_snapshot" {
  description = "Whether to skip the final snapshot on Aurora cluster deletion"
  type        = bool
}

variable "rds_deletion_protection" {
  description = "Whether to enable deletion protection on the Aurora Global cluster and both regional clusters"
  type        = bool
}

variable "rds_monitoring_role_name" {
  description = "Name of the existing IAM role used for Enhanced Monitoring"
  type        = string
}

variable "rds_monitoring_interval" {
  description = "Interval in seconds between Enhanced Monitoring metrics. 0 disables it; valid values: 1, 5, 10, 15, 30, 60."
  type        = number
}

variable "rds_performance_insights_enabled" {
  description = "Whether to enable Performance Insights on cluster instances"
  type        = bool
}

variable "rds_performance_insights_retention_period" {
  description = "Retention period in days for Performance Insights data. 7 = free tier; 731 = 2 years (paid)."
  type        = number
}
