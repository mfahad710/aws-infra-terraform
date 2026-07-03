# Aurora PostgreSQL Global Database.
# Primary cluster lives in the caller's default aws provider region (Singapore).
# Secondary cluster lives in aws.secondary (Tokyo) — its VPC, subnets, and
# security group are created by the VPC module and passed in as variables.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.secondary]
    }
  }
}

data "aws_iam_role" "monitoring" {
  name = var.monitoring_role_name
}

# ============================================================================
# Global cluster
# ============================================================================

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = "${var.env}-aurora-global-cluster"
  engine                    = "aurora-postgresql"
  engine_version            = var.engine_version
  database_name             = var.db_name
  storage_encrypted         = true
  deletion_protection       = var.deletion_protection

  tags = {
    Name = "${var.env}-aurora-global-cluster"
    env  = var.env
  }
}

# ============================================================================
# Master credentials (Aurora Global doesn't support manage_master_user_password)
#
# Creds are seeded once from var.source_master_secret_id at cluster creation,
# then copied into a new user-managed secret. ignore_changes below stops future
# rotations of the source secret from drifting the cluster or the new secret.
# ============================================================================

data "aws_secretsmanager_secret" "source" {
  name = var.source_master_secret_id
}

data "aws_secretsmanager_secret_version" "source" {
  secret_id = data.aws_secretsmanager_secret.source.id
}

locals {
  source_creds = jsondecode(data.aws_secretsmanager_secret_version.source.secret_string)
}

resource "aws_secretsmanager_secret" "master" {
  name        = "${var.env}/aurora/master-secret"
  description = "Aurora Global master credentials for ${var.env}"

  tags = {
    Name = "${var.env}/aurora/master-secret"
    env  = var.env
  }
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = local.source_creds.username
    password = local.source_creds.password
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ============================================================================
# Primary cluster (Singapore)
# ============================================================================

resource "aws_rds_cluster" "primary" {
  cluster_identifier        = "${var.env}-aurora-primary"
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  global_cluster_identifier = aws_rds_global_cluster.this.id

  database_name   = var.db_name
  master_username = local.source_creds.username
  master_password = local.source_creds.password

  db_subnet_group_name   = var.primary_db_subnet_group_name
  vpc_security_group_ids = [var.primary_security_group_id]

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection
  storage_encrypted       = true
  storage_type            = var.storage_type

  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = data.aws_iam_role.monitoring.arn
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  lifecycle {
    ignore_changes = [
      global_cluster_identifier,
      master_username,
      master_password,
    ]
  }

  tags = {
    Name = "${var.env}-aurora-primary"
    env  = var.env
  }
}

resource "aws_rds_cluster_instance" "primary" {
  count                = var.primary_instance_count
  identifier           = "${var.env}-aurora-primary-${count.index}"
  cluster_identifier   = aws_rds_cluster.primary.id
  instance_class       = var.instance_class
  engine               = aws_rds_cluster.primary.engine
  engine_version       = aws_rds_cluster.primary.engine_version
  db_subnet_group_name = var.primary_db_subnet_group_name

  tags = {
    Name = "${var.env}-aurora-primary-${count.index}"
    env  = var.env
  }
}

# ============================================================================
# Secondary cluster (Tokyo)
# ============================================================================

resource "aws_rds_cluster" "secondary" {
  provider = aws.secondary

  cluster_identifier        = "${var.env}-aurora-secondary"
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  global_cluster_identifier = aws_rds_global_cluster.this.id

  db_subnet_group_name   = var.secondary_db_subnet_group_name
  vpc_security_group_ids = [var.secondary_security_group_id]

  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection
  storage_encrypted       = true
  storage_type            = var.storage_type
  # Aurora Global requires an explicit KMS key in the secondary region —
  # the default aws/rds key is not auto-selected for cross-region replicas.
  kms_key_id = var.secondary_kms_key_arn

  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = data.aws_iam_role.monitoring.arn
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  # Secondary cluster must wait for the primary writer instance to exist.
  depends_on = [aws_rds_cluster_instance.primary]

  lifecycle {
    ignore_changes = [global_cluster_identifier, replication_source_identifier]
  }

  tags = {
    Name = "${var.env}-aurora-secondary"
    env  = var.env
  }
}

resource "aws_rds_cluster_instance" "secondary" {
  provider = aws.secondary

  count                = var.secondary_instance_count
  identifier           = "${var.env}-aurora-secondary-${count.index}"
  cluster_identifier   = aws_rds_cluster.secondary.id
  instance_class       = var.instance_class
  engine               = aws_rds_cluster.secondary.engine
  engine_version       = aws_rds_cluster.secondary.engine_version
  db_subnet_group_name = var.secondary_db_subnet_group_name

  tags = {
    Name = "${var.env}-aurora-secondary-${count.index}"
    env  = var.env
  }
}
