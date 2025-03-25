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
    source  = "../"

    orchestrator = "sagemaker" # or "skypilot" or "local"
    zenml_stack_name = "aws-stack"
}

output "zenml_stack_id" {
    value = module.zenml_stack.zenml_stack_id
    sensitive = true
}
output "zenml_stack_name" {
    value = module.zenml_stack.zenml_stack_name
    sensitive = true
}
output "s3_service_connector" {
    value = module.zenml_stack.s3_service_connector
    sensitive = true
}
output "ecr_service_connector" {
    value = module.zenml_stack.ecr_service_connector
    sensitive = true
}
output "aws_service_connector" {
    value = module.zenml_stack.aws_service_connector
    sensitive = true
}
output "artifact_store" {
    value = module.zenml_stack.artifact_store
    sensitive = true
}
output "container_registry" {
    value = module.zenml_stack.container_registry
    sensitive = true
}
output "orchestrator" {
    value = module.zenml_stack.orchestrator
    sensitive = true
}
output "step_operator" {
    value = module.zenml_stack.step_operator
    sensitive = true
}
output "image_builder" {
    value = module.zenml_stack.image_builder
    sensitive = true
}
output "zenml_stack" {
    value = module.zenml_stack.zenml_stack
}