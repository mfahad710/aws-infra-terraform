variable "env" {
  description = "Environment name (stg or prod)"
  type        = string
}

variable "storage_type" {
  description = "Storage type for the Aurora cluster"
  type        = string
}

# ---- Primary region (Singapore) — pre-existing networking ----

variable "primary_db_subnet_group_name" {
  description = "Name of the pre-existing DB subnet group in the primary region"
  type        = string
}

variable "primary_security_group_id" {
  description = "ID of the pre-existing security group attached to the primary cluster"
  type        = string
}

# ---- Secondary region (Tokyo) — networking created by the VPC module ----

variable "secondary_db_subnet_group_name" {
  description = "Name of the DB subnet group in the secondary region (created by the VPC module)"
  type        = string
}

variable "secondary_security_group_id" {
  description = "ID of the security group in the secondary region (created by the VPC module)"
  type        = string
}

variable "secondary_kms_key_arn" {
  description = "ARN of the aws/rds KMS key in the secondary region (required for cross-region Aurora Global encryption)"
  type        = string
}

# ---- Aurora engine + sizing ----

variable "engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
}

variable "instance_class" {
  description = "Instance class for cluster instances"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
}

variable "source_master_secret_id" {
  description = "Name or ARN of an existing Secrets Manager secret to seed master credentials from. Read once at cluster creation; future rotations of this secret are NOT propagated to the new cluster."
  type        = string
}

variable "primary_instance_count" {
  description = "Number of instances in the primary cluster"
  type        = number
  default     = 1
}

variable "secondary_instance_count" {
  description = "Number of instances in the secondary cluster"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on cluster deletion"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the global cluster and both regional clusters"
  type        = bool
}

variable "monitoring_role_name" {
  description = "Name of the existing IAM role used for Enhanced Monitoring"
  type        = string
}

variable "monitoring_interval" {
  description = "Interval in seconds between Enhanced Monitoring metrics. 0 disables it; valid values: 1, 5, 10, 15, 30, 60."
  type        = number
}

variable "performance_insights_enabled" {
  description = "Whether to enable Performance Insights on cluster instances"
  type        = bool
}

variable "performance_insights_retention_period" {
  description = "Retention period in days for Performance Insights data. 7 = free tier; 731 = 2 years (paid)."
  type        = number
}
