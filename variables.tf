variable "orchestrator" {
  description = "The orchestrator to be used, either 'sagemaker', 'skypilot' or 'local'"
  type        = string
  default     = "sagemaker"

  validation {
    condition     = contains(["sagemaker", "skypilot", "local"], var.orchestrator)
    error_message = "The orchestrator must be either 'sagemaker', 'skypilot' or 'local'"
  }
}

variable "artifact_store_config" {
  description = "Additional configuration for the artifact store"
  type        = map(string)
  default     = {}
}

variable "orchestrator_config" {
  description = "Additional configuration for the orchestrator"
  type        = map(string)
  default     = {}
}

variable "enable_step_operator" {
  description = "Whether to include the step operator in the stack"
  type        = bool
  default     = true
}

variable "step_operator_config" {
  description = "Additional configuration for the step operator"
  type        = map(string)
  default     = {}
}

variable "enable_container_registry" {
  description = "Whether to include the container registry in the stack"
  type        = bool
  default     = true
}

variable "container_registry_config" {
  description = "Additional configuration for the container registry"
  type        = map(string)
  default     = {}
}

variable "enable_image_builder" {
  description = "Whether to include the image builder in the stack"
  type        = bool
  default     = true
}

variable "image_builder_config" {
  description = "Additional configuration for the image builder"
  type        = map(string)
  default     = {}
}

variable "enable_deployer" {
  description = "Whether to include the deployer in the stack"
  type        = bool
  default     = true
}

variable "deployer_config" {
  description = "Additional configuration for the deployer"
  type        = map(string)
  default     = {}
}

variable "zenml_stack_name" {
  description = "A custom name for the ZenML stack that will be registered with the ZenML server"
  type        = string
  default     = ""
}

variable "s3_force_destroy" {
  description = "Whether to force destroy the S3 artifact bucket when deleting the stack. If set to false, destroying the stack will fail if the bucket is not empty."
  type        = bool
  default     = false
}

variable "ecr_force_delete" {
  description = "Whether to force delete the ECR container registry when deleting the stack. If set to false, destroying the stack will fail if the repository contains images."
  type        = bool
  default     = false
}

variable "zenml_stack_deployment" {
  description = "The deployment type for the ZenML stack. Used as a label for the registered ZenML stack."
  type        = string
  default     = "terraform"
}
