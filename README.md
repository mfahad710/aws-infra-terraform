# AWS Infrastructure Terraform

Terraform configurations for managing AWS infrastructure.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with appropriate credentials
- AWS account with necessary permissions


## Authentication

Configure AWS credentials before running any Terraform commands:

```bash
aws configure --profile stg
aws configure --profile prod
```

This will prompt you to enter the `access key` and `secret key` for the specified environment, and create a corresponding profile in the `credentials` file under the `.aws` directory.

The provider configuration references these profiles per environment.

## State Management

Remote state is stored in S3 using **S3 native locking** (`use_lockfile = true`, Terraform ≥ 1.10) — no DynamoDB table is required.

A single Terraform root is reused for both accounts. The `backend "s3" {}` block is intentionally empty, backend settings are supplied at `init` time from per-environment `.hcl` files, and variable values are supplied at `apply` time from per-environment `.tfvars` files:

- [`stg.backend.hcl`](./stg.backend.hcl) + [`stg.tfvars`](./stg.tfvars) --> staging
- [`prod.backend.hcl`](./prod.backend.hcl) + [`/prod.tfvars`](./prod.tfvars) --> production

Initialize and apply from the root directory, switching backends with `-reconfigure`:

```bash

# Staging
terraform init -reconfigure -backend-config=stg.backend.hcl
terraform validate
terraform plan -var-file=stg.tfvars
terraform apply -var-file=stg.tfvars -auto-approve

# Production
terraform init -reconfigure -backend-config=prod.backend.hcl
terraform validate
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars -auto-approve
```

## Destroying infrastructure

To tear down an environment, run `terraform destroy` against the same backend and tfvars used to create it. Always re-init with `-reconfigure` first so the correct backend is targeted — running `destroy` against the wrong environment is unrecoverable.

Preview what will be removed before committing:

```bash
# Staging
terraform init -reconfigure -backend-config=stg.backend.hcl
terraform plan -destroy -var-file=stg.tfvars
terraform destroy -var-file=stg.tfvars

# Production
terraform init -reconfigure -backend-config=prod.backend.hcl
terraform plan -destroy -var-file=prod.tfvars
terraform destroy -var-file=prod.tfvars
```

Notes for the Aurora Global Database:

- Terraform detaches the secondary cluster from the global cluster, then deletes the secondary, primary, and global cluster in order. Do not interrupt mid-destroy — a partially torn-down global cluster has to be cleaned up by hand in the AWS console.
- `rds_skip_final_snapshot` controls whether a final snapshot is taken. It is set to `true` in `stg.tfvars`; flip it to `false` and set a `final_snapshot_identifier` if you want a snapshot retained.
- The master password secret managed by Secrets Manager is scheduled for deletion with a recovery window — it is not removed immediately.
- If deletion protection is enabled on the cluster, set it to `false` and run `apply` once before `destroy`.
- Pre-existing primary-region networking referenced by ID in `stg.tfvars` (DB subnet group, security group) is not managed by this root and will not be touched. The Tokyo (secondary) VPC, subnets, and security group **are** module-managed and will be destroyed.
- The S3 state buckets (`stg-infra-tfstate`, `prod-infra-tfstate`) are provisioned manually and are not affected by this destroy.

## Contributing

1. Create a feature branch from `master`
2. Make changes and run `terraform fmt` and `terraform validate`
3. Open a pull request for review
