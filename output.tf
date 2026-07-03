output "env" {
  value       = var.env
  description = "Environment this state belongs to"
}

output "region" {
  value       = var.region
  description = "AWS region for this environment"
}

# ---- Aurora Global Database ----

output "aurora_global_cluster_id" {
  value       = module.rds.global_cluster_id
  description = "Aurora global cluster identifier"
}

output "aurora_primary_endpoint" {
  value       = module.rds.primary_cluster_endpoint
  description = "Aurora primary (Singapore) writer endpoint"
}

output "aurora_primary_reader_endpoint" {
  value       = module.rds.primary_cluster_reader_endpoint
  description = "Aurora primary (Singapore) reader endpoint"
}

output "aurora_secondary_reader_endpoint" {
  value       = module.rds.secondary_cluster_reader_endpoint
  description = "Aurora secondary (Tokyo) reader endpoint"
}

output "aurora_master_user_secret_arn" {
  value       = module.rds.master_user_secret_arn
  description = "ARN of Secrets Manager secret holding the Aurora master password"
}
