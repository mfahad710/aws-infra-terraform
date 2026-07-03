output "global_cluster_id" {
  value       = aws_rds_global_cluster.this.id
  description = "Aurora global cluster identifier"
}

output "primary_cluster_endpoint" {
  value       = aws_rds_cluster.primary.endpoint
  description = "Writer endpoint for the primary cluster (Singapore)"
}

output "primary_cluster_reader_endpoint" {
  value       = aws_rds_cluster.primary.reader_endpoint
  description = "Reader endpoint for the primary cluster (Singapore)"
}

output "secondary_cluster_endpoint" {
  value       = aws_rds_cluster.secondary.endpoint
  description = "Writer endpoint for the secondary cluster (Tokyo) — only writable after failover"
}

output "secondary_cluster_reader_endpoint" {
  value       = aws_rds_cluster.secondary.reader_endpoint
  description = "Reader endpoint for the secondary cluster (Tokyo)"
}

output "master_user_secret_arn" {
  value       = aws_secretsmanager_secret.master.arn
  description = "ARN of the Secrets Manager secret holding the master password"
}
