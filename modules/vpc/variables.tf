variable "env" {
  description = "Environment name (stg or prod)"
  type        = string
}

# ---- Secondary region (Tokyo) Networking ----

variable "secondary_vpc_cidr" {
  description = "CIDR block for the secondary-region VPC"
  type        = string
}

variable "secondary_azs" {
  description = "Availability Zones for the secondary-region private subnets"
  type        = list(string)
}

variable "secondary_private_subnet_cidrs" {
  description = "CIDR blocks for secondary-region private subnets (same order as secondary_azs)"
  type        = list(string)
}
