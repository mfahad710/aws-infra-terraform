# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout — single Terraform root

This repo holds a **single Terraform root module** at the repo root (`./`). Both the VPC module and the Aurora PostgreSQL Global Database module are active. The VPC module creates the secondary-region (Tokyo) networking that the RDS module depends on.

**S3 state buckets are created manually** (not managed by Terraform). The `1-tfstate-bucket/` bootstrap layer has been removed. State is stored remotely using **S3 native locking** (`use_lockfile = true`, no DynamoDB table).

## Common commands

### Main infra (re-run per environment switch)

A single Terraform root is reused for both accounts. Backend config and variables come from per-environment files:

| Env  | Backend config       | Variables       | Bucket                    | Region           |
| ---- | -------------------- | --------------- | ------------------------- | ---------------- |
| stg  | `stg.backend.hcl`    | `stg.tfvars`    | `stg-infra-tfstate`  | `ap-southeast-1` |
| prod | `prod.backend.hcl`   | `prod.tfvars`   | `prod-infra-tfstate` | `ap-northeast-1` |

```bash
# Staging
terraform init -reconfigure -backend-config=stg.backend.hcl
terraform plan  -var-file=stg.tfvars
terraform apply -var-file=stg.tfvars

# Production
terraform init -reconfigure -backend-config=prod.backend.hcl
terraform plan  -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

`-reconfigure` is required when switching environments — without it Terraform reuses the previously-cached backend and silently writes state to the wrong bucket.

### Validation / formatting

```bash
terraform fmt -recursive
terraform validate
```

`terraform validate` requires `terraform init` to have been run first (modules must be installed).

## Architecture

### Provider configuration

- The **main layer** declares a single default `aws` provider (profile chosen via `var.profile`) plus an `aws.secondary` alias for the Aurora Global Database's secondary region. Both the VPC module and the RDS module receive both providers via `providers = { aws = aws, aws.secondary = aws.secondary }`.
- AWS credentials come from named CLI profiles (`aws configure --profile stg` / `--profile prod`). No access keys live in the repo.

### Aurora Global Database (modules/rds)

Aurora Global spans two regions: a writable primary in Singapore and a read-only standby in Tokyo. The module has non-obvious wiring that matters when editing it:

- **Primary region networking is BYO.** The module accepts `primary_db_subnet_group_name` and `primary_security_group_id` as variables — it does **not** create them. Those IDs are hardcoded in `stg.tfvars` and reference pre-existing resources in the stg account (e.g. `sg-0b9c2b335dbb049c5`).
- **Secondary region networking is created by the VPC module**, not the RDS module. The Tokyo VPC, private subnets, route table, DB subnet group, and security group are all built in `modules/vpc/main.tf`. The root `main.tf` passes the VPC module outputs into the RDS module as `secondary_db_subnet_group_name`, `secondary_security_group_id`, and `secondary_kms_key_arn`. This reference is what makes Terraform apply the VPC module before the RDS module (and destroy in reverse).
- **Ordering:** the secondary cluster has `depends_on = [aws_rds_cluster_instance.primary]` because Aurora Global requires the primary writer instance to exist before the secondary cluster can be created.
- **`lifecycle.ignore_changes`** on `global_cluster_identifier` (and `replication_source_identifier` on the secondary) is intentional — Aurora Global manages these through promotion/failover, and without `ignore_changes` Terraform will fight the AWS control plane. Do not remove these.
- **Master credentials are seeded from an existing Secrets Manager secret**, not auto-generated. Aurora Global does **not** support `manage_master_user_password = true`, so the module reads username + password once from the secret named in `rds_source_master_secret_id` (per-env tfvars) via a `data "aws_secretsmanager_secret_version"`, passes them to the cluster, and writes them into a new user-managed secret `<env>-aurora-master` (ARN surfaced as `aurora_master_user_secret_arn`). To stop future rotations of the source secret from drifting the cluster or the copied secret, the cluster has `lifecycle.ignore_changes = [master_username, master_password]` and the copied secret version has `ignore_changes = [secret_string]` — do not remove these. The IAM principal behind `var.profile` needs `secretsmanager:GetSecretValue` on the source secret, and the source secret must live in the **primary region** (the data source uses the default `aws` provider).

### VPC module (modules/vpc)

Creates the **secondary-region (Tokyo) private networking** required by the Aurora Global secondary cluster. Resources managed:

- VPC (`aws_vpc.secondary`)
- Private subnets across the configured AZs (`aws_subnet.secondary_private`)
- Private route table + associations (`aws_route_table.secondary_private`)
- DB subnet group (`aws_db_subnet_group.secondary`)
- Security group allowing PostgreSQL (5432) intra-VPC (`aws_security_group.secondary`)
- Data lookup for the regional `aws/rds` KMS alias (`data.aws_kms_alias.secondary_rds`)

**No NAT gateway** — private subnets have no internet egress by design. Don't add one as a "fix"; if egress is needed, that is a deliberate design change.

Outputs consumed by the RDS module: `secondary_db_subnet_group_name`, `secondary_security_group_id`, `secondary_kms_key_arn`. The VPC module requires both `aws` (default) and `aws.secondary` providers — the root passes them via `providers = { aws.secondary = aws.secondary }`.

### State backends

S3 native locking only — `use_lockfile = true` requires Terraform ≥ 1.10. Do not add a DynamoDB lock table; the `required_version = ">= 1.10.0"` constraint exists specifically to enable this.

State buckets are provisioned manually (not via Terraform):

- **stg:** `stg-infra-tfstate` in `ap-southeast-1`
- **prod:** `prod-infra-tfstate` in `ap-northeast-1`

## Conventions

- **Default tags** (`ManagedBy`, `Environment`, sometimes `Purpose`) are applied at the provider level, not on individual resources — don't duplicate them on resource `tags` blocks unless adding a resource-specific `Name`.
- **Region defaults in `variables.tf` are misleading** — the `region` and `secondary_region` defaults are both Tokyo, but `stg.tfvars` overrides `region` to Singapore. Always check the `.tfvars` file for the actual region in use; don't trust the variable defaults.
- The branching workflow is feature branch → PR → merge to `master`. Run `terraform fmt` and `terraform validate` before opening a PR (per README).