# Outputs for the VPC module, which creates the VPC, subnets, and security group for the secondary cluster in the Tokyo region.

output "secondary_vpc_id" {
  value       = aws_vpc.aurora_secondary.id
  description = "VPC ID created in the secondary region"
}

output "secondary_security_group_id" {
  value       = aws_security_group.aurora_secondary_security_group.id
  description = "Security group ID for the secondary cluster"
}

output "secondary_db_subnet_group_name" {
  value       = aws_db_subnet_group.aurora_secondary_db_subnet_group.name
  description = "DB subnet group name for the secondary cluster"
}

output "secondary_kms_key_arn" {
  value       = data.aws_kms_alias.aurora_secondary_kms_alias.target_key_arn
  description = "ARN of the aws/rds KMS key in the secondary region"
}
