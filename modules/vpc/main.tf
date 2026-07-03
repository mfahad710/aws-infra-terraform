# Aurora PostgreSQL Global Database.
# Secondary cluster lives in aws.secondary (Tokyo) — its VPC, subnets, and
# security group are created here.

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.secondary]
    }
  }
}

# ============================================================================
# Secondary region networking (Tokyo)
# ============================================================================

resource "aws_vpc" "aurora_secondary" {
  provider             = aws.secondary
  cidr_block           = var.secondary_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.env}-vpc"
    env  = var.env
  }
}

resource "aws_subnet" "aurora_secondary_private_subnet" {
  provider          = aws.secondary
  count             = length(var.secondary_azs)
  vpc_id            = aws_vpc.aurora_secondary.id
  cidr_block        = var.secondary_private_subnet_cidrs[count.index]
  availability_zone = var.secondary_azs[count.index]

  tags = {
    Name = "${var.env}-private-subnet-${count.index + 1}"
    env  = var.env
    Tier = "private"
  }
}

resource "aws_route_table" "aurora_secondary_private_rt" {
  provider = aws.secondary
  vpc_id   = aws_vpc.aurora_secondary.id

  tags = {
    Name = "${var.env}-private-rt"
    env  = var.env
  }
}

resource "aws_route_table_association" "aurora_secondary_rt_association" {
  provider       = aws.secondary
  count          = length(var.secondary_azs)
  subnet_id      = aws_subnet.aurora_secondary_private_subnet[count.index].id
  route_table_id = aws_route_table.aurora_secondary_private_rt.id
}

resource "aws_db_subnet_group" "aurora_secondary_db_subnet_group" {
  provider   = aws.secondary
  name       = "${var.env}-aurora-secondary"
  subnet_ids = aws_subnet.aurora_secondary_private_subnet[*].id

  tags = {
    Name = "${var.env}-aurora-secondary"
    env  = var.env
  }
}

data "aws_kms_alias" "aurora_secondary_kms_alias" {
  provider = aws.secondary
  name     = "alias/aws/rds"
}

resource "aws_security_group" "aurora_secondary_security_group" {
  provider    = aws.secondary
  name        = "${var.env}-aurora-secondary-sg"
  description = "Allow PostgreSQL traffic to Aurora secondary cluster"
  vpc_id      = aws_vpc.aurora_secondary.id

  ingress {
    description = "PostgreSQL from secondary VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.secondary_vpc_cidr]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.env}-aurora-secondary-sg"
    env  = var.env
  }
}