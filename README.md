<div align="center">
  <img referrerpolicy="no-referrer-when-downgrade" src="https://static.scarf.sh/a.png?x-pxid=0fcbab94-8fbe-4a38-93e8-c2348450a42e" />
  <h1 align="center">ZenML Cloud Infrastructure Setup</h1>
</div>

<div align="center">
  <a href="https://zenml.io">
    <img alt="ZenML Logo" src="https://raw.githubusercontent.com/zenml-io/zenml/main/docs/book/.gitbook/assets/header.png" alt="ZenML Logo">
  </a>
  <br />
</div>

---

## ⭐️ Show Your Support

If you find this project helpful, please consider giving ZenML a star on GitHub. Your support helps promote the project and lets others know it's worth checking out.

Thank you for your support! 🌟

[![Star this project](https://img.shields.io/github/stars/zenml-io/zenml?style=social)](https://github.com/zenml-io/zenml/stargazers)

## 🚀 Overview

This Terraform module sets up the necessary AWS infrastructure for a [ZenML](https://zenml.io) stack. It provisions various AWS services and resources, and registers [a ZenML stack](https://docs.zenml.io/user-guide/production-guide/understand-stacks) using these resources with your ZenML server, allowing you to create an internal MLOps platform for your entire machine learning team.

## 🛠 Prerequisites

- Terraform installed (version >= 1.9")
- AWS account set up
- To authenticate with AWS, you need to have [the AWS CLI](https://aws.amazon.com/cli/)
installed on your machine and you need to have run `aws configure` to set up your
credentials.
- [ZenML (version >= 0.62.0) installed and configured](https://docs.zenml.io/getting-started/installation). You'll need a Zenml server deployed in a remote setting where it can be accessed from AWS. You have the option to either [self-host a ZenML server](https://docs.zenml.io/getting-started/deploying-zenml) or [register for a free ZenML Pro account](https://cloud.zenml.io/signup).

## 🏗 AWS Resources Created

The Terraform module in this repository creates the following resources in your AWS account:

1. an S3 bucket
2. an ECR repository
3. an IAM role with the minimum necessary permissions to access the S3 bucket and the ECR repository to build and push container images, store artifacts and run pipelines with SageMaker or SkyPilot. 
4. depending on the target ZenML Server capabilities, different authentication methods are used:
  * for a self-hosted ZenML server, an IAM user is created and a secret key is configured for it and shared with the ZenML server
  * for a ZenML Pro account, direct inter-account AWS role assumption is used to authenticate implicitly with the ZenML server, so that no sensitive credentials are shared with the ZenML server. There's only one exception: when the SkyPilot orchestrator is used, this authentication method is not supported, so the IAM user and secret key are used instead.

To use the ZenML stack, you will need to install the required integrations:

* for SageMaker:

```shell
zenml integration install aws s3
```

* for SkyPilot:

```shell
zenml integration install aws s3 skypilot_aws
```

## 🧩 ZenML Stack Components

The Terraform module automatically registers a fully functional AWS [ZenML stack](https://docs.zenml.io/user-guide/production-guide/understand-stacks) directly with your ZenML server. The ZenML stack is based on the provisioned AWS resources and is ready to be used to run machine learning pipelines.

The ZenML stack configuration is the following:

1. an S3 Artifact Store linked to the S3 bucket
2. an ECR Container Registry linked to the ECR repository
3. depending on the `orchestrator` input variable:
  * a local Orchestrator, if `orchestrator` is set to `local`. This can be used in combination with the SageMaker Step Operator to selectively run some steps locally and some on SageMaker.
  * a SageMaker Orchestrator linked to the AWS account, if `orchestrator` is set to `sagemaker` (default)
  * a SkyPilot Orchestrator linked to the AWS account, if `orchestrator` is set to `skypilot`
4. a SageMaker Step Operator linked to the AWS account
5. an AWS Service Connector configured with the IAM role credentials and used to authenticate all ZenML components with the AWS account

## 🚀 Usage

To use this module, aside from the prerequisites mentioned above, you also need to create [a ZenML Service Account API key](https://docs.zenml.io/how-to/connecting-to-zenml/connect-with-a-service-account) for your ZenML Server. You can do this by running the following command in a terminal where you have the ZenML CLI installed:

```bash
zenml service-account create <service-account-name>
```

### Basic Configuration

```hcl
module "zenml_stack" {
  source  = "zenml-io/zenml-stack/aws"

  region = "us-west-2"
  orchestrator = "sagemaker" # or "skypilot" or "local"
  zenml_server_url = "https://your-zenml-server-url.com"
  zenml_api_key = "ZENKEY_1234567890..."
}
output "zenml_stack_id" {
  value = module.zenml_stack.zenml_stack_id
}
output "zenml_stack_name" {
  value = module.zenml_stack.zenml_stack_name
}
```

## 🎓 Learning Resources

[ZenML Documentation](https://docs.zenml.io/)
[ZenML Starter Guide](https://docs.zenml.io/user-guide/starter-guide)
[ZenML Examples](https://github.com/zenml-io/zenml/tree/main/examples)
[ZenML Blog](https://www.zenml.io/blog)

## 🆘 Getting Help
If you need assistance, join our Slack community or open an issue on our GitHub repo.


<div>
<p align="left">
    <div align="left">
      Join our <a href="https://zenml.io/slack" target="_blank">
      <img width="18" src="https://cdn3.iconfinder.com/data/icons/logos-and-brands-adobe/512/306_Slack-512.png" alt="Slack"/>
    <b>Slack Community</b> </a> and be part of the ZenML family.
    </div>
    <br />
    <a href="https://zenml.io/features">Features</a>
    ·
    <a href="https://zenml.io/roadmap">Roadmap</a>
    ·
    <a href="https://github.com/zenml-io/zenml/issues">Report Bug</a>
    ·
    <a href="https://zenml.io/cloud">Sign up for ZenML Pro</a>
    ·
    <a href="https://www.zenml.io/blog">Read Blog</a>
    ·
    <a href="https://github.com/zenml-io/zenml/issues?q=is%3Aopen+is%3Aissue+archived%3Afalse+label%3A%22good+first+issue%22">Contribute to Open Source</a>
    ·
    <a href="https://github.com/zenml-io/zenml-projects">Projects Showcase</a>
  </p>
</div>
