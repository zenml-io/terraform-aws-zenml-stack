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
- To authenticate with AWS, you need to have [the AWS CLI](https://aws.amazon.com/cli/) installed on your machine and you need to have run `aws configure` to set up your credentials.
- You'll need a Zenml server (version >= 0.62.0) deployed in a remote setting where it can be accessed from AWS. You have the option to either [self-host a ZenML server](https://docs.zenml.io/getting-started/deploying-zenml) or [register for a free ZenML Pro account](https://cloud.zenml.io/signup). Once you have a ZenML Server set up, you also need to create [a ZenML Service Account API key](https://docs.zenml.io/how-to/connecting-to-zenml/connect-with-a-service-account) for your ZenML Server. You can do this by running the following command in a terminal where you have the ZenML CLI installed:

```bash
zenml service-account create <service-account-name>
```

- This Terraform module uses [the ZenML Terraform provider](https://registry.terraform.io/providers/zenml-io/zenml/latest/docs). It is recommended to use environment variables to configure the ZenML Terraform provider with the API key and server URL. You can set the environment variables as follows:

```bash
export ZENML_SERVER_URL="https://your-zenml-server.com"
export ZENML_API_KEY="your-api-key"
```

## 🏗 AWS Resources Created

The Terraform module in this repository creates the following resources in your AWS account:

1. an S3 bucket
2. an ECR repository
3. a CloudBuild project
4. an IAM role with the minimum necessary permissions to access the S3 bucket, the ECR repository and the CloudBuild project to build and push container images, store artifacts, run pipelines with SageMaker or SkyPilot and deploy pipelines with App Runner.
5. an IAM role is created to be used as the service role for the CloudBuild project. It has the minimum necessary permissions to access the S3 bucket to read build contexts and to access the ECR repository to push container images.
6. if the `orchestrator` input variable is set to `sagemaker`, another IAM role is created to be used as the service role for the SageMaker Orchestrator. It has the minimum necessary permissions to access the S3 bucket to read and write pipeline artifacts and full SageMaker permissions to create and run SageMaker jobs.
7. an IAM role is created to be used as the service role for the App Runner instances created by the App Runner Deployer. It has the minimum necessary permissions to access the AWS secrets manager to read deployment secrets.
8. depending on the target ZenML Server capabilities, different authentication methods are used:
  * for a self-hosted ZenML server, an IAM user is created and a secret key is configured for it and shared with the ZenML server
  * for a ZenML Pro account, direct inter-account AWS role assumption is used to authenticate implicitly with the ZenML server, so that no sensitive credentials are shared with the ZenML server. There's only one exception: when the SkyPilot orchestrator is used, this authentication method is not supported, so the IAM user and secret key are used instead.

## 🧩 ZenML Stack Components

The Terraform module automatically registers a fully functional AWS [ZenML stack](https://docs.zenml.io/user-guide/production-guide/understand-stacks) directly with your ZenML server. The ZenML stack is based on the provisioned AWS resources and is ready to be used to run machine learning pipelines.

The ZenML stack configuration is the following:

1. an S3 Artifact Store linked to the S3 bucket via an AWS Service Connector configured with IAM role credentials
2. an ECR Container Registry linked to the ECR repository via an AWS Service Connector configured with IAM role credentials
3. depending on the `orchestrator` input variable:
  * a local Orchestrator, if `orchestrator` is set to `local`. This can be used in combination with the SageMaker Step Operator to selectively run some steps locally and some on SageMaker.
  * if `orchestrator` is set to `sagemaker` (default): a SageMaker Orchestrator linked to the AWS account via an AWS Service Connector configured with IAM role credentials
  * if `orchestrator` is set to `skypilot`: a SkyPilot Orchestrator linked to the AWS account via an AWS Service Connector configured with IAM role credentials
4. an App Runner Deployer linked to the AWS account via an AWS Service Connector configured with IAM role credentials
5. an AWS Image Builder linked to the CloudBuild project via an AWS Service Connector configured with IAM role credentials
6. a SageMaker Step Operator linked to the AWS account via an AWS Service Connector configured with IAM role credentials

To use the ZenML stack, you will need to install the required integrations:

* for SageMaker:

```shell
zenml integration install aws s3
```

* for SkyPilot:

```shell
zenml integration install aws s3 skypilot_aws
```


## 🚀 Usage

### Basic Configuration

```hcl
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
        }
        zenml = {
            source = "zenml-io/zenml"
        }
    }
}

provider "aws" {
    region = "eu-central-1"
}

provider "zenml" {
    # server_url = <taken from the ZENML_SERVER_URL environment variable if not set here>
    # api_key = <taken from the ZENML_API_KEY environment variable if not set here>
}

module "zenml_stack" {
  source  = "zenml-io/zenml-stack/aws"

  orchestrator = "sagemaker" # or "skypilot" or "local"
  zenml_stack_name = "my-zenml-stack"
}

output "zenml_stack_id" {
  value = module.zenml_stack.zenml_stack.id
}

output "zenml_stack_name" {
  value = module.zenml_stack.zenml_stack.name
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
