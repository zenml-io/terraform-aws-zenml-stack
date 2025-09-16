output "s3_service_connector" {
  description = "The S3 service connector that was registered with the ZenML server"
  value = data.zenml_service_connector.s3
}

output "ecr_service_connector" {
  description = "The ECR service connector that was registered with the ZenML server"
  value = data.zenml_service_connector.ecr
}

output "aws_service_connector" {
  description = "The generic AWS service connector that was registered with the ZenML server"
  value = data.zenml_service_connector.aws
}

output "artifact_store" {
  description = "The artifact store that was registered with the ZenML server"
  value = data.zenml_stack_component.artifact_store
}

output "container_registry" {
  description = "The container registry that was registered with the ZenML server"
  value = data.zenml_stack_component.container_registry
}

output "orchestrator" {
  description = "The orchestrator that was registered with the ZenML server"
  value = data.zenml_stack_component.orchestrator
}

output "step_operator" {
  description = "The step operator that was registered with the ZenML server"
  value = data.zenml_stack_component.step_operator
}

output "image_builder" {
  description = "The image builder that was registered with the ZenML server"
  value = data.zenml_stack_component.image_builder
}

output "deployer" {
  description = "The deployer that was registered with the ZenML server"
  value = local.use_app_runner ? data.zenml_stack_component.deployer[0] : null
}

output "zenml_stack" {
  description = "The ZenML stack that was registered with the ZenML server"
  value = data.zenml_stack.stack
}

output "zenml_stack_id" {
  description = "The ID of the ZenML stack that was registered with the ZenML server"
  value = zenml_stack.stack.id
}

output "zenml_stack_name" {
  description = "The name of the ZenML stack that was registered with the ZenML server"
  value = zenml_stack.stack.name
}