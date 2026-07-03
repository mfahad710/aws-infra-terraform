# context.md

Working context for Claude Code sessions in this repo. Unlike `CLAUDE.md` (durable architecture/commands), this file captures **point-in-time state** and **gotchas observed during work** — verify before relying on it.

_Last refreshed: 2026-06-18._

## Current state of the world

- **This repo is a single Terraform root.** The `1-tfstate-bucket/` bootstrap layer has been removed. S3 state buckets are now provisioned manually.
- **Both state buckets are provisioned manually:**
  - `stg`: `stg-infra-tfstate` in `ap-southeast-1` (Singapore). Versioning, SSE, public access blocked.
  - `prod`: `prod-infra-tfstate` in `ap-northeast-1` (Tokyo). Versioning, SSE, public access blocked.
- **VPC module is active and wired to the RDS module.** The secondary-region (Tokyo) networking is managed by `modules/vpc/`. The root `main.tf` applies the VPC module first (implicit dependency via output references), then the RDS module. Destroy is the reverse.
- **`prod.tfvars` may be incomplete.** Verify that all required `rds_*` variables are filled in before attempting a prod apply — specifically `rds_primary_db_subnet_group_name`, `rds_primary_security_group_id`, and `rds_source_master_secret_id`. A `terraform plan -var-file=prod.tfvars` will surface any missing values.

## Gotchas observed

### VPC module creates secondary-region networking, not primary

`modules/vpc/` creates the Tokyo VPC, private subnets, DB subnet group, security group, and KMS alias lookup for the Aurora secondary cluster. It does **not** create any primary-region (Singapore) networking — the primary still reuses pre-existing resources referenced by ID in `stg.tfvars` (`rds_primary_db_subnet_group_name`, `rds_primary_security_group_id`). The VPC module outputs (`secondary_db_subnet_group_name`, `secondary_security_group_id`, `secondary_kms_key_arn`) are passed directly into the RDS module in the root `main.tf`.

### Provider warning when child module lacks `required_providers`

If you add a new submodule and call it with `providers = { aws = aws.<alias> }` from the root, the child module **must** have its own `terraform { required_providers { aws = { source = "hashicorp/aws", ... } } }` block. Otherwise Terraform infers `hashicorp/aws` and emits a warning ("Reference to undefined provider"). Both `modules/rds/` and `modules/vpc/` already declare this block with `configuration_aliases = [aws.secondary]`.

### S3 bucket lifecycle rule needs `filter {}`

AWS provider v5 requires every `rule` in `aws_s3_bucket_lifecycle_configuration` to declare exactly one of `filter` or `prefix`. An empty `filter {}` applies to all objects — matches the legacy implicit behavior. Without it, `validate` warns and future provider versions will hard-error.

### Root variable defaults are misleading

`variables.tf` defaults `region` and `secondary_region` both to `ap-northeast-1` (Tokyo). For `stg`, `stg.tfvars` overrides `region` to `ap-southeast-1` (Singapore) and leaves `secondary_region` as Tokyo. Don't trust the defaults — always read the `.tfvars` for the env you're operating on.

### `-reconfigure` is mandatory when switching environments

`terraform init -reconfigure -backend-config=<env>.backend.hcl` must be run every time you switch from stg to prod or vice versa. Without `-reconfigure`, Terraform reuses the previously-cached backend and silently writes state to the wrong bucket.