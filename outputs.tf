output "s3_service_connector" {
  description = "The S3 service connector that was registered with the ZenML server"
  value       = data.zenml_service_connector.s3
}

output "ecr_service_connector" {
  description = "The ECR service connector that was registered with the ZenML server"
  value       = var.enable_container_registry ? data.zenml_service_connector.ecr[0] : null
}

output "aws_service_connector" {
  description = "The generic AWS service connector that was registered with the ZenML server"
  value       = data.zenml_service_connector.aws
}

output "artifact_store" {
  description = "The artifact store that was registered with the ZenML server"
  value       = data.zenml_stack_component.artifact_store
}

output "container_registry" {
  description = "The container registry that was registered with the ZenML server"
  value       = var.enable_container_registry ? data.zenml_stack_component.container_registry[0] : null
}

output "orchestrator" {
  description = "The orchestrator that was registered with the ZenML server"
  value       = data.zenml_stack_component.orchestrator
}

output "step_operator" {
  description = "The step operator that was registered with the ZenML server"
  value       = var.enable_step_operator ? data.zenml_stack_component.step_operator[0] : null
}

output "image_builder" {
  description = "The image builder that was registered with the ZenML server"
  value       = var.enable_image_builder ? data.zenml_stack_component.image_builder[0] : null
}

output "deployer" {
  description = "The deployer that was registered with the ZenML server"
  value       = local.use_app_runner && var.enable_deployer ? data.zenml_stack_component.deployer[0] : null
}

output "zenml_stack" {
  description = "The ZenML stack that was registered with the ZenML server"
  value       = data.zenml_stack.stack
}

output "zenml_stack_id" {
  description = "The ID of the ZenML stack that was registered with the ZenML server"
  value       = zenml_stack.stack.id
}

output "zenml_stack_name" {
  description = "The name of the ZenML stack that was registered with the ZenML server"
  value       = zenml_stack.stack.name
}
