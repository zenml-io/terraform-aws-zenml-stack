# Repository Guidelines

## Project Structure & Module Organization
This repository is a single Terraform module published as `zenml-io/zenml-stack/aws`. Keep module logic in the root Terraform files: `main.tf` defines AWS and ZenML resources, `variables.tf` defines inputs, and `outputs.tf` exposes registered connectors and stack components. `test/main.tf` is the example consumer used for integration-style checks with `source = "../"`. When you add or change inputs or outputs, update `README.md` and the test fixture in the same change.

## Build, Test, and Development Commands
- `terraform fmt` formats all `.tf` files; run it before every commit.
- `terraform init` installs the AWS and ZenML providers in the current directory.
- `terraform validate` checks syntax and provider wiring after init.
- `terraform plan` previews changes for the root module; requires AWS credentials plus `ZENML_SERVER_URL` and `ZENML_API_KEY`.
- `cd test && terraform init && terraform plan` verifies the module from a consumer configuration.

Example setup:
```bash
export ZENML_SERVER_URL="https://your-zenml-server.com"
export ZENML_API_KEY="your-api-key"
aws configure
```

## Coding Style & Naming Conventions
Use standard HCL formatting with two-space indentation; `terraform fmt` is the source of truth. Prefer descriptive `snake_case` names for variables, locals, and outputs such as `zenml_stack_name` and `use_implicit_auth`. Follow the existing pattern of concise comments only where conditional auth or version-gated behavior would otherwise be hard to follow.

## Testing Guidelines
There is no separate unit-test suite here; validation is Terraform-based. At minimum, run `terraform fmt`, `terraform validate`, and the `test/` plan before opening a PR. If you touch conditional logic for `orchestrator`, implicit auth, or ZenML version checks, mention which path you exercised in your PR.

## Commit & Pull Request Guidelines
Recent history mixes Conventional Commit prefixes (`feat:`, `docs:`) with short imperative summaries (`Fix secrets manager permissions`). Prefer concise, imperative subjects and use a prefix when it adds clarity. PRs should explain the AWS or ZenML behavior changed, list any new variables or outputs, and include README/test updates when interface changes are user-facing.

## Security & Configuration Tips
Do not commit AWS credentials, ZenML API keys, or Terraform state. Use environment variables for ZenML provider auth, and keep account-specific values out of defaults and examples unless they are intentionally public constants.
