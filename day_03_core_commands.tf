# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 3 - Core Terraform Commands (init, validate, fmt, plan, apply, destroy)
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  This file documents every core Terraform CLI command with full explanation
#  of flags, use cases, and what happens under the hood.
#
#  THE TERRAFORM WORKFLOW:
#   Write (.tf files) → Init → Validate → Plan → Apply → Destroy
#
#  ALL COMMANDS RUN IN THE TERMINAL — not inside .tf files.
#  This .tf file also includes working configuration to practice with.
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# COMMAND REFERENCE (run these in your terminal)
# ─────────────────────────────────────────────────────────────────────────────
#
# ══ terraform init ════════════════════════════════════════════════════════════
# WHAT: Initialises a Terraform working directory.
#       Downloads providers, sets up backend, creates .terraform/ directory.
# WHEN: Run FIRST in any new project, and after adding new providers/modules.
#
#   terraform init
#   terraform init -upgrade          # Upgrade providers to latest allowed version
#   terraform init -reconfigure      # Reconfigure backend (force re-init)
#   terraform init -backend=false    # Skip backend initialisation
#   terraform init -input=false      # Non-interactive (for CI/CD pipelines)
#
# What init creates:
#   .terraform/            ← provider binaries and module cache
#   .terraform.lock.hcl   ← dependency lock file (COMMIT THIS TO GIT)
#
# ══ terraform validate ════════════════════════════════════════════════════════
# WHAT: Checks configuration files for syntax errors and type errors.
#       Does NOT check if resources will actually work (that needs plan).
# WHEN: After writing or modifying .tf files, before plan.
#
#   terraform validate
#   terraform validate -json          # Machine-readable JSON output (for CI)
#
# Exit codes: 0 = valid   1 = error
#
# ══ terraform fmt ═════════════════════════════════════════════════════════════
# WHAT: Rewrites .tf files to the canonical HCL style (indentation, alignment).
#       Like "prettier" for Terraform. ALWAYS run before committing.
# WHEN: Before every git commit, as a pre-commit hook.
#
#   terraform fmt                     # Format current directory
#   terraform fmt -recursive          # Format all .tf files recursively
#   terraform fmt -check              # Check only — exit 1 if formatting needed
#   terraform fmt -diff               # Show diff of what would change
#   terraform fmt -write=false        # Display formatted output, don't write
#
# ══ terraform plan ════════════════════════════════════════════════════════════
# WHAT: Creates an execution plan — shows EXACTLY what Terraform will do.
#       Reads current state, calls provider APIs to check real infrastructure,
#       and computes the diff between desired and actual state.
# WHEN: ALWAYS before apply. Treat it as a mandatory review step.
#
#   terraform plan                    # Standard plan (outputs to terminal)
#   terraform plan -out=tfplan        # Save plan to file (recommended for CI/CD)
#   terraform plan -var="region=us-east-1"        # Override a variable
#   terraform plan -var-file="prod.tfvars"        # Use a variables file
#   terraform plan -target=resource_type.name     # Plan only one resource
#   terraform plan -destroy           # Preview what destroy would do
#   terraform plan -refresh=false     # Skip refresh (faster, less accurate)
#   terraform plan -json              # JSON output for automation
#
# Plan output symbols:
#   + create    ← new resource will be created
#   - destroy   ← existing resource will be deleted
#   ~ update    ← resource will be modified in-place
#   -/+ replace ← resource must be destroyed and recreated
#   <= read     ← data source will be read
#
# ══ terraform apply ═══════════════════════════════════════════════════════════
# WHAT: Executes the plan and creates/updates/deletes real infrastructure.
#       Writes results to state file after each resource operation.
# WHEN: After reviewing plan. Requires explicit "yes" confirmation.
#
#   terraform apply                   # Interactive (shows plan + asks yes/no)
#   terraform apply tfplan            # Apply a saved plan file (no prompts)
#   terraform apply -auto-approve     # Skip confirmation (CI/CD only!)
#   terraform apply -var="env=prod"   # Override variable
#   terraform apply -target=aws_instance.web  # Apply only one resource
#   terraform apply -parallelism=5    # Limit parallel operations (default: 10)
#   terraform apply -replace=aws_instance.web # Force replace a specific resource
#
# ══ terraform destroy ═════════════════════════════════════════════════════════
# WHAT: Destroys ALL infrastructure managed by this Terraform config.
#       Reads state, creates a reverse plan, executes it.
# WHEN: Tear down dev/test environments, cleanup after learning.
#
#   terraform destroy                 # Interactive — shows plan, asks yes/no
#   terraform destroy -auto-approve   # No confirmation (DANGEROUS!)
#   terraform destroy -target=aws_instance.web  # Destroy only one resource
#
# ══ OTHER IMPORTANT COMMANDS ══════════════════════════════════════════════════
#
#   terraform show                    # Show current state in human-readable form
#   terraform show tfplan             # Show a saved plan file
#   terraform output                  # Print all output values
#   terraform output instance_ip      # Print specific output
#   terraform output -json            # JSON format (for scripting)
#   terraform state list              # List all resources in state
#   terraform state show aws_instance.web  # Show details of one resource
#   terraform state rm aws_instance.web    # Remove resource from state (not real)
#   terraform state mv old_name new_name   # Rename resource in state
#   terraform import aws_instance.web i-1234abcd  # Import existing resource
#   terraform refresh                 # Sync state with real infrastructure
#   terraform graph                   # Output dependency graph (DOT format)
#   terraform graph | dot -Tsvg > graph.svg  # Visualise with Graphviz
#
# ─────────────────────────────────────────────────────────────────────────────
# WORKING CONFIGURATION TO PRACTICE WITH
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "local" {}
provider "random" {}

# Generate a random ID (simulates cloud resource IDs)
resource "random_id" "project_id" {
  byte_length = 4
  # Explanation: generates a random 4-byte (8 hex char) ID
  # e.g. "a1b2c3d4" — used to make resource names globally unique
}

resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  # Explanation: generates a strong random password for use in resources
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

locals {
  project_name = "tf-core-demo-${random_id.project_id.hex}"
}

resource "local_file" "environment_config" {
  filename = "${path.module}/${local.project_name}.env"
  content  = <<-EOT
    # Generated by Terraform
    ENVIRONMENT=${var.environment}
    PROJECT_ID=${random_id.project_id.hex}
    DB_PASSWORD=${random_password.db_password.result}
    CONFIG_VERSION=1.0.0
  EOT
  file_permission = "0600"  # Restrictive permissions for secrets file
}

output "project_name" {
  value       = local.project_name
  description = "Unique project name with random suffix"
}

output "config_file" {
  value       = local_file.environment_config.filename
  description = "Path to the generated config file"
}

output "db_password" {
  value       = random_password.db_password.result
  description = "Generated database password"
  sensitive   = true  # Will show as <sensitive> in terminal output
}

# ─────────────────────────────────────────────────────────────────────────────
# PRACTICE STEPS:
# ─────────────────────────────────────────────────────────────────────────────
# mkdir day3 && cd day3
# cp day_03_core_commands.tf main.tf
# terraform init          ← notice: downloads local + random providers
# terraform fmt           ← auto-formats the file
# terraform validate      ← should say "Success!"
# terraform plan          ← see what will be created (2 resources)
# terraform plan -out=myplan   ← save the plan
# terraform apply myplan  ← apply without being prompted again
# terraform show          ← view the state
# terraform output        ← see output values
# terraform output -json  ← machine-readable outputs
# terraform state list    ← list tracked resources
# terraform state show local_file.environment_config  ← resource details
# terraform destroy       ← clean up everything
