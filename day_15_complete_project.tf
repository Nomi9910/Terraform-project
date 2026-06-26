# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 15 - Complete Project: Multi-Environment Infrastructure
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  This final lesson brings EVERYTHING together into a complete, production-
#  ready Terraform project structure. It demonstrates:
#
#   ✔ Proper file structure (providers, variables, locals, resources, outputs)
#   ✔ Multi-environment support (dev/staging/prod via workspaces)
#   ✔ Modules pattern
#   ✔ For-each and count
#   ✔ Locals for computed values
#   ✔ Validation on all inputs
#   ✔ Sensitive variables
#   ✔ Outputs for all important values
#   ✔ Lifecycle rules
#   ✔ Full comments and documentation
#
#  In a real project this would be split into multiple files.
#  Here everything is in one file for learning clarity.
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ─── providers.tf content ──────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    time   = { source = "hashicorp/time",   version = "~> 0.11" }
  }

  # Production backend (enable for real projects):
  # backend "s3" {
  #   bucket         = "mycompany-terraform-state"
  #   key            = "myapp/${terraform.workspace}/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "local" {}
provider "random" {}
provider "time" {}

# ─── variables.tf content ──────────────────────────────────────────────────

variable "project_name" {
  description = "Short project name — used as prefix in all resource names"
  type        = string
  default     = "platform"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "Must be 3-20 lowercase letters, numbers, or hyphens, starting with a letter."
  }
}

variable "owner_team" {
  description = "Team responsible for this infrastructure"
  type        = string
  default     = "platform-engineering"
}

variable "services" {
  description = "Map of services to deploy with their configuration"
  type = map(object({
    replicas      = number
    port          = number
    memory_mb     = number
    cpu_units     = number
    health_check  = string
    enabled       = bool
  }))
  default = {
    frontend = {
      replicas     = 2
      port         = 80
      memory_mb    = 512
      cpu_units    = 256
      health_check = "/health"
      enabled      = true
    }
    api = {
      replicas     = 3
      port         = 8080
      memory_mb    = 1024
      cpu_units    = 512
      health_check = "/api/health"
      enabled      = true
    }
    worker = {
      replicas     = 2
      port         = 0
      memory_mb    = 768
      cpu_units    = 256
      health_check = ""
      enabled      = true
    }
    scheduler = {
      replicas     = 1
      port         = 0
      memory_mb    = 256
      cpu_units    = 128
      health_check = ""
      enabled      = false
    }
  }
}

variable "feature_flags" {
  description = "Feature toggles for optional functionality"
  type = object({
    enable_monitoring = bool
    enable_tracing    = bool
    enable_caching    = bool
    blue_green_deploy = bool
  })
  default = {
    enable_monitoring = true
    enable_tracing    = false
    enable_caching    = true
    blue_green_deploy = false
  }
}

variable "alert_email" {
  description = "Email address for infrastructure alerts"
  type        = string
  default     = "ops@example.com"
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alert_email))
    error_message = "Must be a valid email address."
  }
}

variable "db_password" {
  description = "Database master password. Set via TF_VAR_db_password."
  type        = string
  sensitive   = true
  default     = "demo-change-in-production-use-vault"
}

# ─── locals.tf content ─────────────────────────────────────────────────────

locals {
  # Current workspace = environment
  env     = terraform.workspace
  is_prod = local.env == "prod"
  is_dev  = local.env == "dev"

  # Name prefix for all resources
  prefix = "${var.project_name}-${local.env}"

  # Environment-tier sizing multipliers
  sizing = {
    dev     = { multiplier = 1, ha_min = 1 }
    staging = { multiplier = 1, ha_min = 1 }
    prod    = { multiplier = 2, ha_min = 2 }
  }
  tier = lookup(local.sizing, local.env, local.sizing["dev"])

  # Only enabled services
  active_services = {
    for name, cfg in var.services : name => cfg if cfg.enabled
  }

  # Compute effective replica count (prod gets doubled + HA minimum enforced)
  effective_replicas = {
    for name, cfg in local.active_services :
    name => max(
      cfg.replicas * local.tier.multiplier,
      local.tier.ha_min
    )
  }

  # Common tags applied to every resource
  common_tags = {
    Project     = var.project_name
    Environment = local.env
    Owner       = var.owner_team
    ManagedBy   = "terraform"
    Workspace   = terraform.workspace
  }

  # Features summary for config rendering
  features_summary = join(", ", [
    for feat, enabled in var.feature_flags : feat if enabled
  ])
}

# ─── main.tf content ───────────────────────────────────────────────────────

resource "time_static" "deployed_at" {}
resource "random_id"   "deploy_id"  { byte_length = 4 }
resource "random_pet"  "deploy_name" {
  length = 2
  prefix = local.prefix
}

# ── Service configuration files ────────────────────────────────────────────

resource "local_file" "service_configs" {
  for_each = local.active_services

  filename = "${path.module}/configs/${local.env}/${each.key}.yaml"
  content  = <<-YAML
    # ${upper(each.key)} Service Configuration
    # Environment : ${local.env}
    # Generated by Terraform — do not edit manually
    service:
      name: ${each.key}
      environment: ${local.env}
      deployment_id: ${random_id.deploy_id.hex}

    compute:
      replicas: ${local.effective_replicas[each.key]}
      memory_mb: ${each.value.memory_mb * local.tier.multiplier}
      cpu_units: ${each.value.cpu_units * local.tier.multiplier}

    %{if each.value.port > 0~}
    network:
      port: ${each.value.port}
      health_check: "${each.value.health_check}"
    %{endif~}

    features:
      monitoring: ${var.feature_flags.enable_monitoring}
      tracing: ${var.feature_flags.enable_tracing}
      caching: ${var.feature_flags.enable_caching}

    tags:
    %{for key, value in local.common_tags~}
      ${key}: "${value}"
    %{endfor~}
  YAML

  file_permission = "0644"

  lifecycle {
    create_before_destroy = true
  }
}

# ── Secrets / credentials file ─────────────────────────────────────────────

resource "local_sensitive_file" "secrets" {
  filename = "${path.module}/configs/${local.env}/secrets.env"
  content  = <<-ENV
    # SENSITIVE — Generated by Terraform
    # Environment: ${local.env}
    ENVIRONMENT=${local.env}
    DEPLOY_ID=${random_id.deploy_id.hex}
    DB_PASSWORD=${var.db_password}
    ALERT_EMAIL=${var.alert_email}
  ENV
  file_permission = "0600"
}

# ── Deployment manifest ────────────────────────────────────────────────────

resource "local_file" "deployment_manifest" {
  filename = "${path.module}/configs/${local.env}/deployment-manifest.json"
  content = jsonencode({
    project       = var.project_name
    environment   = local.env
    workspace     = terraform.workspace
    deployment_id = random_id.deploy_id.hex
    deploy_name   = random_pet.deploy_name.id
    deployed_at   = time_static.deployed_at.rfc3339
    is_production = local.is_prod
    active_services = [for name, cfg in local.active_services : {
      name     = name
      replicas = local.effective_replicas[name]
      port     = cfg.port
    }]
    features_enabled = local.features_summary
    tags             = local.common_tags
  })
  file_permission = "0644"
}

# ── Environment README ─────────────────────────────────────────────────────

resource "local_file" "env_readme" {
  filename = "${path.module}/configs/${local.env}/README.md"
  content  = <<-MD
    # ${upper(local.env)} Environment — ${var.project_name}

    > Generated by Terraform. Do not edit manually.

    ## Deployment Info
    | Field | Value |
    |-------|-------|
    | Environment | ${local.env} |
    | Deployment ID | ${random_id.deploy_id.hex} |
    | Deploy Name | ${random_pet.deploy_name.id} |
    | Deployed At | ${time_static.deployed_at.rfc3339} |
    | Production | ${local.is_prod} |

    ## Active Services
    | Service | Replicas | Port |
    |---------|----------|------|
    %{for name, cfg in local.active_services~}
    | ${name} | ${local.effective_replicas[name]} | ${cfg.port > 0 ? tostring(cfg.port) : "N/A"} |
    %{endfor~}

    ## Features
    ${local.features_summary}

    ## How to manage this environment
    ```bash
    # Switch to this workspace
    terraform workspace select ${local.env}

    # Preview changes
    terraform plan -out=${local.env}.tfplan

    # Apply changes
    terraform apply ${local.env}.tfplan

    # View outputs
    terraform output

    # Destroy (careful in prod!)
    terraform plan -destroy
    terraform destroy
    ```
  MD
  file_permission = "0644"
}

# ─── outputs.tf content ─────────────────────────────────────────────────────

output "deployment_summary" {
  description = "Complete deployment summary"
  value = {
    project         = var.project_name
    environment     = local.env
    deployment_id   = random_id.deploy_id.hex
    deploy_name     = random_pet.deploy_name.id
    deployed_at     = time_static.deployed_at.rfc3339
    is_production   = local.is_prod
    active_services = keys(local.active_services)
    disabled_services = [
      for name, cfg in var.services : name if !cfg.enabled
    ]
  }
}

output "service_replicas" {
  description = "Effective replica count per service"
  value       = local.effective_replicas
}

output "config_files" {
  description = "Paths to all generated configuration files"
  value = {
    services = { for k, v in local_file.service_configs : k => v.filename }
    manifest = local_file.deployment_manifest.filename
    readme   = local_file.env_readme.filename
  }
}

output "features_enabled" {
  description = "List of enabled feature flags"
  value       = local.features_summary
}

output "common_tags" {
  description = "Tags applied to all resources"
  value       = local.common_tags
}

# ─────────────────────────────────────────────────────────────────────────────
# GRADUATION CHECKLIST — what you've learned in 15 days:
# ─────────────────────────────────────────────────────────────────────────────
# Day 01 ✔ Introduction, installation, first resource
# Day 02 ✔ HCL syntax, types, variables, locals, outputs
# Day 03 ✔ init, validate, fmt, plan, apply, destroy
# Day 04 ✔ Providers, version constraints, multiple providers
# Day 05 ✔ Variables, tfvars, precedence, sensitive, outputs
# Day 06 ✔ State management, backends, remote state, state commands
# Day 07 ✔ Resources, data sources, count, for_each, depends_on, lifecycle
# Day 08 ✔ Modules, sources, inputs/outputs, registry
# Day 09 ✔ 100+ built-in functions, terraform console, expressions
# Day 10 ✔ Workspaces, multi-environment patterns
# Day 11 ✔ AWS provider: VPC, EC2, S3, IAM, security groups
# Day 12 ✔ count, for_each, for expressions, dynamic blocks, conditionals
# Day 13 ✔ CI/CD with GitHub Actions, GitLab CI, Atlantis
# Day 14 ✔ Best practices: structure, naming, security, documentation
# Day 15 ✔ Complete multi-environment project combining everything
