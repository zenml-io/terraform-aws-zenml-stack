# Contributing

## Development

Format your code before committing:

```bash
terraform fmt
```

Validate syntax:

```bash
terraform validate
```

Test against the example configuration in `test/`:

```bash
cd test && terraform init && terraform plan
```

## Releasing to the Terraform Registry

This module is published to the [Terraform Registry](https://registry.terraform.io/modules/zenml-io/zenml-stack/aws). The Registry updates are triggered by **Git tags**, not by merging to `main`.

After merging a PR that should be published as a new version:

```bash
git tag v<next-version>
git push origin v<next-version>
```

Use semantic versioning. The Registry typically picks up new tags within a few minutes.
