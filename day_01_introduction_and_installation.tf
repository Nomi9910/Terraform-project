# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 1 - Introduction to Terraform & Installation on RHEL 9
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  WHAT IS TERRAFORM?
#  Terraform is an open-source Infrastructure as Code (IaC) tool by HashiCorp.
#  It lets you define, provision, and manage cloud/on-prem infrastructure using
#  a declarative configuration language called HCL (HashiCorp Configuration
#  Language). You describe WHAT you want, Terraform figures out HOW to build it.
#
#  KEY CONCEPTS:
#   - Declarative: describe desired end-state, not step-by-step instructions
#   - Provider: plugin that talks to a cloud/service API (AWS, Azure, GCP, etc.)
#   - Resource: a single infrastructure object (VM, bucket, VPC, DNS record)
#   - State: Terraform tracks real-world resources in a state file (.tfstate)
#   - Plan: preview of what Terraform will create/change/destroy
#   - Apply: execute the plan to make real changes
#
#  WHY TERRAFORM?
#   ✔ Multi-cloud: same tool for AWS, Azure, GCP, on-prem
#   ✔ Version-controlled infrastructure (store .tf files in Git)
#   ✔ Repeatable and idempotent deployments
#   ✔ Team collaboration via remote state (S3, Terraform Cloud)
#   ✔ 3000+ providers in the Terraform Registry
#
#  INSTALLATION ON RHEL 9:
#  ─────────────────────────────────────────────────────────────────────────────
#  # Step 1: Add the HashiCorp repository
#  sudo dnf install -y dnf-plugins-core
#  sudo dnf config-manager --add-repo \
#    https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
#
#  # Step 2: Install Terraform
#  sudo dnf install -y terraform
#
#  # Step 3: Verify installation
#  terraform version
#  # Expected: Terraform v1.x.x on linux_amd64
#
#  # Step 4: Enable tab completion (optional but useful)
#  terraform -install-autocomplete
#  source ~/.bashrc
#
#  # Step 5: Install useful companion tools
#  sudo dnf install -y git curl unzip jq   # Essential sysadmin tools
#
# ─────────────────────────────────────────────────────────────────────────────
#  CORE TERRAFORM COMMANDS (reference — details in Day 3)
# ─────────────────────────────────────────────────────────────────────────────
#  terraform init       — Download providers, initialise working directory
#  terraform validate   — Check syntax/configuration for errors
#  terraform fmt        — Auto-format .tf files to canonical style
#  terraform plan       — Preview changes before applying
#  terraform apply      — Create/update real infrastructure
#  terraform destroy    — Tear down all managed infrastructure
#  terraform show       — Show current state or a saved plan
#  terraform output     — Print output values from state
#  terraform state list — List resources tracked in state
#  terraform import     — Import existing resource into state
#  terraform taint      — Mark a resource for recreation on next apply
#  terraform workspace  — Manage workspaces (dev/staging/prod environments)
#
# ─────────────────────────────────────────────────────────────────────────────
#  YOUR FIRST TERRAFORM CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
#  Every Terraform project lives in a directory of .tf files.
#  Terraform reads ALL .tf files in the directory at once.
#
#  Typical project structure:
#  my-project/
#  ├── main.tf          ← primary resource definitions
#  ├── variables.tf     ← input variable declarations
#  ├── outputs.tf       ← output value declarations
#  ├── providers.tf     ← provider configuration
#  ├── terraform.tfvars ← actual variable values (DO NOT commit secrets!)
#  └── .terraform/      ← auto-created by terraform init (add to .gitignore)
# ══════════════════════════════════════════════════════════════════════════════

# This is the simplest possible Terraform configuration.
# It declares which Terraform version is required and uses the
# "local" provider (no cloud account needed) to create a file on disk.

terraform {
  # Specify minimum Terraform version required for this config
  required_version = ">= 1.6.0"

  # Declare which providers this project uses
  required_providers {
    local = {
      source  = "hashicorp/local"   # From the Terraform Registry
      version = "~> 2.4"            # ~> means >=2.4.0 and <3.0.0
    }
  }
}

# The "local" provider manages local files and directories.
# No credentials needed — perfect for learning Terraform concepts.
provider "local" {}

# This is your first RESOURCE.
# A resource is an infrastructure object Terraform will create and manage.
# Syntax: resource "<PROVIDER_TYPE>" "<LOCAL_NAME>" { ... }
resource "local_file" "hello" {
  # The path where Terraform will create this file
  filename = "${path.module}/hello_terraform.txt"

  # The content that will be written into the file
  content = <<-EOT
    Hello from Terraform!
    =====================
    This file was created by Terraform on Day 1.

    Key facts:
    - Tool   : Terraform
    - Purpose: Infrastructure as Code
    - Author : ${var.author_name}
    - Created: Day 1 of the Terraform course
  EOT

  # File permission (octal) — 0644 = rw-r--r--
  file_permission = "0644"
}

# Variables make your config dynamic and reusable
variable "author_name" {
  description = "Your name — written into the hello file"
  type        = string
  default     = "Terraform Student"
}

# Outputs print values after apply — useful for showing created resource IDs, IPs, etc.
output "file_path" {
  description = "The path of the created file"
  value       = local_file.hello.filename
}

output "file_content_length" {
  description = "Number of bytes in the created file"
  value       = local_file.hello.content_length
}

# ─────────────────────────────────────────────────────────────────────────────
# HOW TO RUN THIS:
# ─────────────────────────────────────────────────────────────────────────────
# 1. Save this file as main.tf in a new directory
# 2. cd into that directory
# 3. terraform init        ← downloads the "local" provider
# 4. terraform validate    ← checks for syntax errors
# 5. terraform fmt         ← auto-formats the file
# 6. terraform plan        ← shows what will be created
# 7. terraform apply       ← creates hello_terraform.txt
# 8. cat hello_terraform.txt
# 9. terraform destroy     ← deletes hello_terraform.txt
