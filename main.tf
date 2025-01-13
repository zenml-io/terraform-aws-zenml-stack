terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    zenml = {
      source = "zenml-io/zenml"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "zenml_server" "zenml_info" {}

locals {
  zenml_pro_tenant_id = try(data.zenml_server.zenml_info.metadata["tenant_id"], null)
  dashboard_url = try(data.zenml_server.zenml_info.dashboard_url, "")
  # Check if the dashboard URL indicates a ZenML Cloud deployment
  is_zenml_cloud = length(regexall("^https://(staging\\.)?cloud\\.zenml\\.io/", local.dashboard_url)) > 0
  zenml_version = data.zenml_server.zenml_info.version
  zenml_version_minor = local.zenml_version != null ? tonumber(split(".", local.zenml_version)[1]) : 0
  zenml_version_patch = local.zenml_version != null ? tonumber(split(".", local.zenml_version)[2]) : 0
  zenml_pro_tenant_iam_role_name = local.zenml_pro_tenant_id != null ? "zenml-${local.zenml_pro_tenant_id}" : ""
  zenml_pro_tenant_iam_role = local.zenml_pro_tenant_id != null ? "arn:aws:iam::${var.zenml_pro_aws_account}:role/${local.zenml_pro_tenant_iam_role_name}" : ""
  # Use inter-AWS-account implicit authentication when connected to a ZenML Pro tenant and
  # not using SkyPilot. SkyPilot cannot be used with implicit authentication because it does
  # not support the AWS temporary credentials generated by ZenML from the implicit authentication
  # flow.
  use_implicit_auth = local.is_zenml_cloud != null && var.orchestrator != "skypilot"
  # CodeBuild is only available as an image builder in ZenML versions higher than 0.70.0
  use_codebuild = local.zenml_version_minor > 70 || local.zenml_version_minor == 70 && local.zenml_version_patch > 0
}

resource "random_id" "resource_name_suffix" {
  # This will generate a string of 12 characters, encoded as base64 which makes
  # it 8 characters long
  byte_length = 6
}

resource "aws_s3_bucket" "artifact_store" {
  bucket = "zenml-${data.aws_caller_identity.current.account_id}-${random_id.resource_name_suffix.hex}"
}

resource "aws_ecr_repository" "container_registry" {
  name = "zenml-${random_id.resource_name_suffix.hex}"
}


resource "aws_iam_user" "iam_user" {
  count = local.use_implicit_auth ? 0 : 1
  name = "zenml-${random_id.resource_name_suffix.hex}"
}

resource "aws_iam_user_policy" "assume_role_policy" {
  count = local.use_implicit_auth ? 0 : 1
  name = "AssumeRole"
  user = aws_iam_user.iam_user[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "iam_user_access_key" {
  count = local.use_implicit_auth ? 0 : 1
  user = aws_iam_user.iam_user[0].name
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [local.use_implicit_auth ? local.zenml_pro_tenant_iam_role : aws_iam_user.iam_user[0].arn]
    }
  }
}

resource "aws_iam_role" "stack_access_role" {
  name               = "zenml-${random_id.resource_name_suffix.hex}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy" "s3_policy" {
  name = "S3Policy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.artifact_store.arn,
          "${aws_s3_bucket.artifact_store.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_policy" {
  name = "ECRPolicy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRegistry",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.container_registry.arn
      },
      {
        Effect = "Allow"
        Action = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:ListRepositories"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

# Client permissions needed for the SageMaker step operator
resource "aws_iam_role_policy" "sagemaker_training_jobs_policy" {
  name = "SageMakerTrainingJobsPolicy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "logs:Describe*",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.sagemaker_runtime_role.arn
      }
    ]
  })
}


# Client permissions needed for the SageMaker orchestrator
resource "aws_iam_role_policy" "sagemaker_pipelines_policy" {
  count = var.orchestrator == "sagemaker" ? 1 : 0
  name = "SageMakerPipelinesPolicy"
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:CreatePipeline",
          "sagemaker:StartPipelineExecution",
          "sagemaker:DescribePipeline",
          "sagemaker:DescribePipelineExecution"
        ]
        Resource = "*"
      }
    ]
  })
}


resource "aws_iam_role_policy" "skypilot_policy" {
  count = var.orchestrator == "skypilot" ? 1 : 0
  name = "SkyPilotPolicy"
  role = aws_iam_role.stack_access_role.id

  # NOTE: these are minimal AWS SkyPilot permissions taken from https://skypilot.readthedocs.io/en/latest/cloud-setup/cloud-permissions/aws.html#aws
  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
          Effect: "Allow",
          Action: "ec2:RunInstances",
          Resource: "arn:aws:ec2:*::image/ami-*"
      },
      {
          Effect: "Allow",
          Action: "ec2:RunInstances",
          Resource: [
              "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
              "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:network-interface/*",
              "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:subnet/*",
              "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:volume/*",
              "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:security-group/*"
          ]
      },
      {
          Effect: "Allow",
          Action: [
              "ec2:TerminateInstances",
              "ec2:DeleteTags",
              "ec2:StartInstances",
              "ec2:CreateTags",
              "ec2:StopInstances"
          ],
          Resource: "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*"
      },
      {
          Effect: "Allow",
          Action: [
              "ec2:Describe*"
          ],
          Resource: "*"
      },
      {
          Effect: "Allow",
          Action: [
              "ec2:CreateSecurityGroup",
              "ec2:AuthorizeSecurityGroupIngress"
          ],
          Resource: "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:*"
      },
      {
          Effect: "Allow",
          Action: [
              "iam:GetRole",
              "iam:PassRole"
          ],
          Resource: [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/skypilot-v1"
          ]
      },
      {
          Effect: "Allow",
          Action: [
              "iam:GetInstanceProfile"
          ],
          Resource: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/skypilot-v1"
      },
      {
          Effect: "Allow",
          Action: "iam:CreateServiceLinkedRole",
          Resource: "*",
          Condition: {
              StringEquals: {
                  "iam:AWSServiceName": "spot.amazonaws.com"
              }
          }
      },
      {
          Effect: "Allow",
          Action: [
              "iam:GetRole",
              "iam:PassRole",
              "iam:CreateRole",
              "iam:AttachRolePolicy"
          ],
          Resource: [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/skypilot-v1"
          ]
      },
      {
          Effect: "Allow",
          Action: [
              "iam:GetInstanceProfile",
              "iam:CreateInstanceProfile",
              "iam:AddRoleToInstanceProfile"
          ],
          Resource: "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/skypilot-v1"
      }
    ]
  })
}

resource "aws_iam_role" "sagemaker_runtime_role" {
  name               = "zenml-${random_id.resource_name_suffix.hex}-sagemaker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
  ]
}

# SageMaker runtime permissions
resource "aws_iam_role_policy" "sagemaker_runtime_policy" {
  name = "SageMakerRuntimePolicy"
  role = aws_iam_role.sagemaker_runtime_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          aws_s3_bucket.artifact_store.arn,
          "${aws_s3_bucket.artifact_store.arn}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role" "codebuild_runtime_role" {
  name               = "zenml-${random_id.resource_name_suffix.hex}-codebuild"
  count              = local.use_codebuild ? 1 : 0
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# CodeBuild runtime permissions
resource "aws_iam_role_policy" "codebuild_runtime_policy" {
  name = "CodeBuildRuntimePolicy"
  count = local.use_codebuild ? 1 : 0
  role = aws_iam_role.codebuild_runtime_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.artifact_store.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = aws_ecr_repository.container_registry.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/zenml-codebuild-${random_id.resource_name_suffix.hex}",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/zenml-codebuild-${random_id.resource_name_suffix.hex}:*"
        ]
      }
    ]
  })
}

resource "aws_codebuild_project" "image_builder" {
  name          = "zenml-${random_id.resource_name_suffix.hex}"
  count         = local.use_codebuild ? 1 : 0
  build_timeout = 20
  service_role  = aws_iam_role.codebuild_runtime_role[0].arn

  source {
    type            = "S3"
    location        = "${aws_s3_bucket.artifact_store.bucket}/codebuild"
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "bentolor/docker-dind-awscli"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    privileged_mode             = false
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/zenml-codebuild-${random_id.resource_name_suffix.hex}"
    }
  }
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildPolicy"
  count = local.use_codebuild ? 1 : 0
  role = aws_iam_role.stack_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
        ]
        Resource = "${aws_codebuild_project.image_builder[0].arn}"
      }
    ]
  })
}

locals {
  # The service connector configuration is different depending on whether we are
  # using the ZenML Pro tenant or not.
  service_connector_config = {
    iam_role = {
      region = data.aws_region.current.name
      role_arn = aws_iam_role.stack_access_role.arn
      aws_access_key_id = local.use_implicit_auth ? "": aws_iam_access_key.iam_user_access_key[0].id
      aws_secret_access_key = local.use_implicit_auth ? "": aws_iam_access_key.iam_user_access_key[0].secret
    }
    implicit = {
      region = "${data.aws_region.current.name}"
      role_arn = "${aws_iam_role.stack_access_role.arn}"
    }
  }
}

# Artifact Store Component

resource "zenml_service_connector" "s3" {
  name           = "${var.zenml_stack_name == "" ? "terraform-s3-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-s3"}"
  type           = "aws"
  auth_method    = local.use_implicit_auth ? "implicit" : "iam-role"
  resource_type  = "s3-bucket"
  resource_id    = aws_s3_bucket.artifact_store.bucket

  configuration = local.service_connector_config[local.use_implicit_auth ? "implicit" : "iam_role"]

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    aws_iam_user.iam_user,
    aws_iam_role.stack_access_role,
    aws_iam_user_policy.assume_role_policy,
    aws_iam_role_policy.s3_policy,
  ]
}

resource "zenml_stack_component" "artifact_store" {
  name      = "${var.zenml_stack_name == "" ? "terraform-s3-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-s3"}"
  type      = "artifact_store"
  flavor    = "s3"

  configuration = {
    path = "s3://${aws_s3_bucket.artifact_store.bucket}"
  }

  connector_id = zenml_service_connector.s3.id

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Container Registry Component

resource "zenml_service_connector" "ecr" {
  name           = "${var.zenml_stack_name == "" ? "terraform-ecr-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-ecr"}"
  type           = "aws"
  auth_method    = local.use_implicit_auth ? "implicit" : "iam-role"
  resource_type  = "docker-registry"
  resource_id    = aws_ecr_repository.container_registry.repository_url

  configuration = local.service_connector_config[local.use_implicit_auth ? "implicit" : "iam_role"]

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    aws_iam_user.iam_user,
    aws_iam_role.stack_access_role,
    aws_iam_user_policy.assume_role_policy,
    aws_iam_role_policy.ecr_policy,
  ]
}

resource "zenml_stack_component" "container_registry" {
  name      = "${var.zenml_stack_name == "" ? "terraform-ecr-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-ecr"}"
  type      = "container_registry"
  flavor    = "aws"

  configuration = {
    uri = regex("^([^/]+)/?", aws_ecr_repository.container_registry.repository_url)[0]
    default_repository = "${aws_ecr_repository.container_registry.name}"
  }

  connector_id = zenml_service_connector.ecr.id

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Orchestrator

locals {
  # The orchestrator configuration is different depending on the orchestrator
  # chosen by the user. We use the `orchestrator` variable to determine which
  # configuration to use and construct a local variable `orchestrator_config` to
  # hold the configuration.
  orchestrator_config = {
    local = {}
    sagemaker = {
      execution_role = "${aws_iam_role.sagemaker_runtime_role.arn}"
      output_data_s3_uri = "s3://${aws_s3_bucket.artifact_store.bucket}/sagemaker"
    }
    skypilot = {
      region = "${data.aws_region.current.name}"
    }
  }
}

resource "zenml_service_connector" "aws" {
  name           = "${var.zenml_stack_name == "" ? "terraform-aws-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-aws"}"
  type           = "aws"
  auth_method    = local.use_implicit_auth ? "implicit" : "iam-role"
  resource_type  = "aws-generic"

  configuration = local.service_connector_config[local.use_implicit_auth ? "implicit" : "iam_role"]

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }

  depends_on = [
    aws_iam_user.iam_user,
    aws_iam_role.stack_access_role,
    aws_iam_role.sagemaker_runtime_role,
    aws_iam_user_policy.assume_role_policy,
    aws_iam_role_policy.s3_policy,
    aws_iam_role_policy.ecr_policy,
    aws_iam_role_policy.sagemaker_training_jobs_policy,
    aws_iam_role_policy.sagemaker_pipelines_policy,
    aws_iam_role_policy.skypilot_policy,
    aws_iam_role_policy.sagemaker_runtime_policy,
    aws_iam_role_policy.codebuild_runtime_policy,
  ]
}

resource "zenml_stack_component" "orchestrator" {
  name      = "${var.zenml_stack_name == "" ? "terraform-${var.orchestrator}-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-${var.orchestrator}"}"
  type      = "orchestrator"
  flavor    = var.orchestrator == "skypilot" ? "vm_aws" : var.orchestrator

  configuration = local.orchestrator_config[var.orchestrator]

  connector_id = var.orchestrator == "local" ? "" : zenml_service_connector.aws.id

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}


# Step Operator
resource "zenml_stack_component" "step_operator" {
  name      = "${var.zenml_stack_name == "" ? "terraform-sagemaker-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-sagemaker"}"
  type      = "step_operator"
  flavor    = "sagemaker"

  configuration = {
    role = "${aws_iam_role.sagemaker_runtime_role.arn}",
    bucket = "${aws_s3_bucket.artifact_store.bucket}"
  }

  connector_id = zenml_service_connector.aws.id

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Image Builder

locals {
  # The image builder configuration is different depending on the zenml version.
  image_builder_type = local.use_codebuild ? "codebuild" : "local"
  image_builder_config = {
    local = {}
    codebuild = {
      code_build_project = local.use_codebuild ? aws_codebuild_project.image_builder[0].name : ""
    }
  }
}


resource "zenml_stack_component" "image_builder" {
  name      = "${var.zenml_stack_name == "" ? "terraform-${local.image_builder_type}-${random_id.resource_name_suffix.hex}" : "${var.zenml_stack_name}-${local.image_builder_type}"}"
  type      = "image_builder"
  flavor    = local.use_codebuild ? "aws" : "local"

  configuration = local.image_builder_config[local.image_builder_type]

  connector_id = local.use_codebuild ? zenml_service_connector.aws.id : null

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

# Complete Stack
resource "zenml_stack" "stack" {
  name = "${var.zenml_stack_name == "" ? "terraform-aws-${random_id.resource_name_suffix.hex}" : var.zenml_stack_name}"

  components = {
    artifact_store     = zenml_stack_component.artifact_store.id
    container_registry = zenml_stack_component.container_registry.id
    orchestrator      = zenml_stack_component.orchestrator.id
    step_operator      = zenml_stack_component.step_operator.id
    image_builder      = zenml_stack_component.image_builder.id
  }

  labels = {
    "zenml:provider" = "aws"
    "zenml:deployment" = "${var.zenml_stack_deployment}"
  }
}

data "zenml_service_connector" "s3" {
  id = zenml_service_connector.s3.id
}

data "zenml_service_connector" "ecr" {
  id = zenml_service_connector.ecr.id
}

data "zenml_service_connector" "aws" {
  id = zenml_service_connector.aws.id
}

data "zenml_stack_component" "artifact_store" {
  id = zenml_stack_component.artifact_store.id
}

data "zenml_stack_component" "container_registry" {
  id = zenml_stack_component.container_registry.id
}

data "zenml_stack_component" "orchestrator" {
  id = zenml_stack_component.orchestrator.id
}

data "zenml_stack_component" "step_operator" {
  id = zenml_stack_component.step_operator.id
}

data "zenml_stack_component" "image_builder" {
  id = zenml_stack_component.image_builder.id
}

data "zenml_stack" "stack" {
  id = zenml_stack.stack.id
}