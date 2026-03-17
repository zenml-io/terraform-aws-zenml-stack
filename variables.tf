variable "orchestrator" {
  description = "The orchestrator to be used, either 'sagemaker', 'skypilot' or 'local'"
  type        = string
  default     = "sagemaker"

  validation {
    condition     = contains(["sagemaker", "skypilot", "local"], var.orchestrator)
    error_message = "The orchestrator must be either 'sagemaker', 'skypilot' or 'local'"
  }
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
