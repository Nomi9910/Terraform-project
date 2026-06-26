# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 2 - HCL Syntax & Configuration Basics
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  WHAT IS HCL?
#  HCL (HashiCorp Configuration Language) is the language used to write
#  Terraform configurations. It is designed to be human-readable and writable,
#  while also being machine-parseable. Files use the .tf extension.
#
#  HCL BUILDING BLOCKS:
#   Arguments    — key = value pairs inside blocks
#   Blocks       — containers with a type, optional labels, and body { }
#   Expressions  — values, references, functions
#   Comments     — # single line   // single line   /* multi-line */
#
#  DATA TYPES:
#   string  — "hello"
#   number  — 42, 3.14
#   bool    — true, false
#   list    — ["a", "b", "c"]
#   set     — like list but unordered, no duplicates
#   map     — { key = "value" }
#   object  — { name = string, age = number }
#   tuple   — [string, number, bool]
#   any     — any type (dynamic)
#   null    — absence of a value
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "local" {}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1: COMMENTS
# ─────────────────────────────────────────────────────────────────────────────

# This is a single-line comment (hash style)
// This is also a single-line comment (slash style)

/*
  This is a multi-line comment.
  Use it for long explanations or
  temporarily disabling blocks of code.
*/

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2: ARGUMENT TYPES & EXPRESSIONS
# ─────────────────────────────────────────────────────────────────────────────

# String literals — always double quotes in HCL
# string_val = "hello world"

# Number literals
# number_val = 42
# float_val  = 3.14

# Boolean literals
# bool_true  = true
# bool_false = false

# Null — represents absence of value
# null_val = null

# String templates with interpolation — ${expression}
# greeting = "Hello, ${var.username}!"

# Multi-line strings — heredoc style
# content = <<-EOT
#   Line 1
#   Line 2
#   EOT
# <<-EOT strips leading whitespace; <<EOT does not

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3: VARIABLES — ALL TYPES DEMONSTRATED
# ─────────────────────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Name of the project — used in resource naming"
  type        = string
  default     = "my-terraform-project"
  # validation block ensures value meets requirements
  validation {
    condition     = length(var.project_name) > 3
    error_message = "project_name must be longer than 3 characters."
  }
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

variable "enable_feature" {
  description = "Toggle to enable/disable a feature"
  type        = bool
  default     = true
}

variable "allowed_regions" {
  description = "List of AWS regions where resources can be deployed"
  type        = list(string)
  default     = ["us-east-1", "eu-west-1", "ap-southeast-1"]
}

variable "server_ports" {
  description = "Set of allowed ports (no duplicates)"
  type        = set(number)
  default     = [22, 80, 443, 8080]
}

variable "tags" {
  description = "Map of tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Owner       = "platform-team"
    CostCenter  = "engineering"
    ManagedBy   = "terraform"
  }
}

variable "server_config" {
  description = "Object containing server configuration"
  type = object({
    name          = string
    instance_type = string
    disk_size_gb  = number
    enable_backup = bool
  })
  default = {
    name          = "web-server"
    instance_type = "t3.micro"
    disk_size_gb  = 20
    enable_backup = true
  }
}

variable "sensitive_password" {
  description = "A secret value — masked in logs and output"
  type        = string
  sensitive   = true  # Terraform will not show this in plan/apply output
  default     = "ch@ng3Me!"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4: LOCAL VALUES — computed values used within the module
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Combine variables into derived values
  resource_prefix = "${var.project_name}-${var.tags["Environment"]}"

  # Compute a timestamp-based name
  timestamp = formatdate("YYYY-MM-DD", timestamp())

  # Merge maps
  common_tags = merge(var.tags, {
    Project   = var.project_name
    CreatedAt = local.timestamp
  })

  # Conditional expression: condition ? true_val : false_val
  backup_label = var.server_config.enable_backup ? "backup-enabled" : "no-backup"

  # List operations
  primary_region = var.allowed_regions[0]           # First element
  region_count   = length(var.allowed_regions)       # Count elements
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5: RESOURCE WITH ALL CONCEPTS COMBINED
# ─────────────────────────────────────────────────────────────────────────────

resource "local_file" "config_demo" {
  filename = "${path.module}/${local.resource_prefix}-config.txt"

  content = <<-EOT
    =====================================
     Project Configuration
    =====================================
    Project Name   : ${var.project_name}
    Environment    : ${var.tags["Environment"]}
    Instance Count : ${var.instance_count}
    Feature Enabled: ${var.enable_feature}
    Primary Region : ${local.primary_region}
    Total Regions  : ${local.region_count}
    Backup Status  : ${local.backup_label}
    Resource Prefix: ${local.resource_prefix}

    Server Config:
      Name         : ${var.server_config.name}
      Type         : ${var.server_config.instance_type}
      Disk (GB)    : ${var.server_config.disk_size_gb}

    Tags:
    %{for key, value in local.common_tags~}
      ${key} = ${value}
    %{endfor~}

    Allowed Regions:
    %{for region in var.allowed_regions~}
      - ${region}
    %{endfor~}
  EOT

  file_permission = "0644"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6: OUTPUTS
# ─────────────────────────────────────────────────────────────────────────────

output "resource_prefix" {
  description = "The prefix used for all resources in this project"
  value       = local.resource_prefix
}

output "config_file_path" {
  description = "Path to the generated config file"
  value       = local_file.config_demo.filename
}

output "common_tags" {
  description = "The full set of tags applied to resources"
  value       = local.common_tags
}

output "server_name" {
  description = "Name of the server from the config object"
  value       = var.server_config.name
}
