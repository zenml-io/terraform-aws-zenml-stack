# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Terraform module that provisions AWS infrastructure for a ZenML ML stack and automatically registers it with a ZenML server. It is published to the Terraform Registry as `zenml-io/zenml-stack/aws`.

## Commands

```bash
# Format all .tf files (required before committing)
terraform fmt

# Validate configuration syntax
terraform validate

# Preview changes (requires AWS credentials + ZenML server)
terraform plan

# Apply changes
terraform apply

# Test using the example configuration
cd test && terraform init && terraform plan
```

Formatting and validation don't need cloud credentials. Anything beyond that (plan/apply) requires both AWS CLI configured (`aws configure`) and ZenML server env vars:
```bash
export ZENML_SERVER_URL="https://your-zenml-server.com"
export ZENML_API_KEY="your-api-key"
```

## Architecture

**Single-module, three-file structure:**

| File | Purpose |
|------|---------|
| `main.tf` | All resources, data sources, locals, and ZenML stack registration |
| `variables.tf` | Five input variables (orchestrator, stack name, s3_force_destroy, ecr_force_delete, zenml_stack_deployment) |
| `outputs.tf` | Exposes all created service connectors, stack components, and the stack itself |
| `test/main.tf` | Example consumer of the module (`source = "../"`) for integration testing |

**Providers:** `hashicorp/aws` (~> 4.0) and `zenml-io/zenml`.

### Key Conditional Logic in main.tf

The module's behavior branches on three axes — understanding these is essential for making changes:

1. **Auth method** (`local.use_implicit_auth`): ZenML Pro uses cross-account IAM role assumption (no secrets shared). Self-hosted ZenML or SkyPilot on Pro falls back to creating an IAM user with access keys. Controls whether `aws_iam_user` and `aws_iam_access_key` resources are created (count = 0/1).

2. **Orchestrator** (`var.orchestrator`): `"sagemaker"` | `"skypilot"` | `"local"`. Each path creates different IAM policies and stack component configurations. SageMaker adds EventBridge scheduler permissions; SkyPilot adds EC2/instance profile permissions; local creates no orchestrator-specific IAM.

3. **ZenML version** (`local.use_codebuild`, `local.use_app_runner`): CodeBuild image builder requires ZenML >0.70.0; App Runner deployer requires >0.85.0. Older versions get a local image builder and no deployer.

### Resource Naming

All AWS resources use the pattern `zenml-${random_id.resource_name_suffix.hex}` to avoid collisions. The random suffix is a 6-byte random ID (12 hex chars).

### ZenML Stack Registration Flow

After creating AWS resources, the module registers them with ZenML in this order:
1. Three **service connectors** (S3, ECR, generic AWS) — each with auth config matching the implicit/IAM-role decision
2. **Stack components** (artifact_store, container_registry, orchestrator, step_operator, image_builder, optionally deployer)
3. A **zenml_stack** resource that ties all components together

Each ZenML resource is re-read via a `data` source after creation so the outputs reflect server-side state.
