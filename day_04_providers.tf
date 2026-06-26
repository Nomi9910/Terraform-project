# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 4 - Providers
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  WHAT IS A PROVIDER?
#  A provider is a plugin that enables Terraform to interact with a specific
#  API or service. Providers handle authentication, API calls, and translating
#  your HCL config into real infrastructure.
#
#  Every resource type belongs to a provider:
#   aws_instance        → AWS provider
#   azurerm_vm          → Azure provider
#   google_compute_instance → GCP provider
#   local_file          → Local provider
#   random_password     → Random provider
#   kubernetes_deployment → Kubernetes provider
#
#  Providers are published at: registry.terraform.io
#  HashiCorp maintains "official" providers; community maintains others.
#
#  PROVIDER CONFIGURATION:
#   - Declared in required_providers block (what to download)
#   - Configured in provider block (how to authenticate/connect)
#   - Providers are downloaded to .terraform/ on terraform init
#   - .terraform.lock.hcl pins exact versions (commit to Git!)
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    # ── Local provider — works with files on the local filesystem ─────────
    local = {
      source  = "hashicorp/local"  # registry.terraform.io/hashicorp/local
      version = "~> 2.4"           # Compatible with 2.4.x, 2.5.x etc (not 3.x)
    }

    # ── Random provider — generates random values ─────────────────────────
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }

    # ── HTTP provider — makes HTTP requests ───────────────────────────────
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }

    # ── Time provider — creates time-based resources ───────────────────────
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }

    # ─────────────────────────────────────────────────────────────────────
    # REAL-WORLD PROVIDERS (shown for reference — need credentials to use)
    # ─────────────────────────────────────────────────────────────────────

    # AWS provider
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 5.0"
    # }

    # Azure provider
    # azurerm = {
    #   source  = "hashicorp/azurerm"
    #   version = "~> 3.0"
    # }

    # GCP provider
    # google = {
    #   source  = "hashicorp/google"
    #   version = "~> 5.0"
    # }

    # Kubernetes provider
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "~> 2.0"
    # }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# PROVIDER BLOCKS — Configure how each provider connects/authenticates
# ─────────────────────────────────────────────────────────────────────────────

# Local provider — no configuration needed
provider "local" {}

# Random provider — no configuration needed
provider "random" {}

# HTTP provider — no configuration needed
provider "http" {}

# Time provider — no configuration needed
provider "time" {}

# ── AWS provider configuration (for reference) ────────────────────────────
# provider "aws" {
#   region  = "us-east-1"
#
#   # Credentials — NEVER hardcode these! Use environment variables instead:
#   #   export AWS_ACCESS_KEY_ID="your-key"
#   #   export AWS_SECRET_ACCESS_KEY="your-secret"
#   #   export AWS_DEFAULT_REGION="us-east-1"
#   # Or use AWS profiles:
#   #   profile = "my-aws-profile"
#   # Or use IAM roles on EC2/ECS (automatic, most secure)
#
#   # Default tags applied to ALL resources created by this provider
#   default_tags {
#     tags = {
#       ManagedBy   = "terraform"
#       Environment = var.environment
#       Project     = var.project_name
#     }
#   }
# }

# ── Multiple provider instances (aliases) ─────────────────────────────────
# Use aliases when you need the same provider configured differently
# e.g., two AWS regions, two accounts, two Kubernetes clusters

# provider "aws" {
#   alias  = "us_east"
#   region = "us-east-1"
# }
# provider "aws" {
#   alias  = "eu_west"
#   region = "eu-west-1"
# }
# Then reference with: provider = aws.eu_west

# ─────────────────────────────────────────────────────────────────────────────
# VERSION CONSTRAINT SYNTAX
# ─────────────────────────────────────────────────────────────────────────────
# "= 1.2.3"   — Exactly version 1.2.3
# "!= 1.2.3"  — Anything except 1.2.3
# "> 1.2.3"   — Greater than 1.2.3
# ">= 1.2.3"  — 1.2.3 or higher
# "< 2.0.0"   — Less than 2.0.0
# "~> 1.2"    — >=1.2, <2.0  (patch-level updates ok)
# "~> 1.2.3"  — >=1.2.3, <1.3.0 (only patch updates)
# Best practice: use ~> to allow patch fixes but prevent breaking changes

# ─────────────────────────────────────────────────────────────────────────────
# WORKING EXAMPLES USING MULTIPLE PROVIDERS
# ─────────────────────────────────────────────────────────────────────────────

# Random provider — generate a unique suffix
resource "random_id" "suffix" {
  byte_length = 3
}

resource "random_pet" "server_name" {
  length    = 2       # "adjective-noun" format: e.g. "happy-whale"
  separator = "-"
  prefix    = "rhel9"
}

resource "random_integer" "port" {
  min = 8000
  max = 9000
  # Generates a random port number in range
}

# Time provider — create a timestamp resource
resource "time_static" "deployed_at" {
  # Creates a fixed timestamp when first applied; doesn't change on re-apply
  # Useful for tracking when a resource was first created
}

# HTTP provider — fetch data from a URL
data "http" "terraform_version_check" {
  url = "https://checkpoint-api.hashicorp.com/v1/check/terraform"
  # Explanation: "data" sources READ information; they don't create anything
  # This fetches the latest available Terraform version from HashiCorp's API
}

# Local provider — create files using data from other providers
resource "local_file" "provider_demo" {
  filename = "${path.module}/provider-demo.txt"
  content  = <<-EOT
    ========================================
     Terraform Provider Demo
    ========================================
    Random ID       : ${random_id.suffix.hex}
    Server Name     : ${random_pet.server_name.id}
    Random Port     : ${random_integer.port.result}
    Deployed At     : ${time_static.deployed_at.rfc3339}

    API Response (Terraform version check):
    ${data.http.terraform_version_check.response_body}
  EOT
  file_permission = "0644"
}

# ─────────────────────────────────────────────────────────────────────────────
# PROVIDER COMMANDS (run in terminal)
# ─────────────────────────────────────────────────────────────────────────────
# terraform providers            # List all providers required by config
# terraform providers lock       # Update .terraform.lock.hcl
# terraform providers mirror ./  # Download providers to a local directory
# terraform version              # Show Terraform + provider versions in use

output "demo_file" {
  value = local_file.provider_demo.filename
}
output "server_name" {
  value = random_pet.server_name.id
}
output "random_port" {
  value = random_integer.port.result
}
output "deploy_timestamp" {
  value = time_static.deployed_at.rfc3339
}
