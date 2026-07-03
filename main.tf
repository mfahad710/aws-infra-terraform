# Main terraform configuration file.
# It calls the modules and set up the providers and backend configuration

terraform {
  required_version = ">= 1.10.0" # terraform version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # aws provider version
    }
  }

  backend "s3" {}
}

provider "aws" {
  profile = var.profile
  region  = var.region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      env       = var.env
    }
  }
}

# Secondary region used by the Aurora Global Database's secondary cluster
provider "aws" {
  alias   = "secondary"
  profile = var.profile
  region  = var.secondary_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      env       = var.env
    }
  }
}

# ------ VPC ------
module "vpc" {
  source = "./modules/vpc"

  providers = {
    aws.secondary = aws.secondary
  }

  env = var.env

  # Secondary region (Tokyo), networking created by the VPC module
  secondary_vpc_cidr             = var.rds_secondary_vpc_cidr
  secondary_azs                  = var.rds_secondary_azs
  secondary_private_subnet_cidrs = var.rds_secondary_private_subnet_cidrs
}


# ------ RDS Aurora Postgres ------
module "rds" {
  source = "./modules/rds"

  providers = {
    aws           = aws
    aws.secondary = aws.secondary
  }

  env = var.env

  # Primary region (Singapore), reuse existing networking
  primary_db_subnet_group_name = var.rds_primary_db_subnet_group_name
  primary_security_group_id    = var.rds_primary_security_group_id

  # Secondary region (Tokyo), reuse networking created by the VPC module
  secondary_db_subnet_group_name = module.vpc.secondary_db_subnet_group_name
  secondary_security_group_id    = module.vpc.secondary_security_group_id
  secondary_kms_key_arn          = module.vpc.secondary_kms_key_arn

  # RDS Aurora cluster settings
  engine_version          = var.rds_engine_version
  instance_class          = var.rds_instance_class
  db_name                 = var.rds_db_name
  source_master_secret_id = var.rds_source_master_secret_id
  skip_final_snapshot     = var.rds_skip_final_snapshot
  deletion_protection     = var.rds_deletion_protection
  storage_type            = var.rds_storage_type

  monitoring_role_name                  = var.rds_monitoring_role_name
  monitoring_interval                   = var.rds_monitoring_interval
  performance_insights_enabled          = var.rds_performance_insights_enabled
  performance_insights_retention_period = var.rds_performance_insights_retention_period
}
