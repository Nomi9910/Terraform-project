# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 6 - State Management
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  WHAT IS TERRAFORM STATE?
#  Terraform stores information about managed infrastructure in a state file
#  (terraform.tfstate). This JSON file maps your config to real-world resources.
#
#  WHY STATE MATTERS:
#   - Tracks which real resources Terraform manages
#   - Remembers resource IDs, IPs, and attributes
#   - Used to compute the diff on next plan/apply
#   - Enables collaboration when stored remotely
#
#  LOCAL STATE (default):
#   - terraform.tfstate stored in your working directory
#   - NOT suitable for teams (race conditions, no locking)
#   - OK for personal projects and learning
#
#  REMOTE STATE (production):
#   - Stored in S3, GCS, Azure Blob, Terraform Cloud
#   - Supports state locking (prevents concurrent modifications)
#   - Enables team collaboration
#   - Encrypted at rest and in transit
#
#  STATE FILE WARNING:
#   ⚠ Contains sensitive data (passwords, keys, IPs)
#   ⚠ NEVER commit terraform.tfstate to Git
#   ⚠ Add to .gitignore: *.tfstate  *.tfstate.backup
#
#  STATE COMMANDS:
#   terraform state list               — list all managed resources
#   terraform state show <resource>    — show attributes of one resource
#   terraform state rm <resource>      — remove from state (not from cloud)
#   terraform state mv old new         — rename resource in state
#   terraform state pull               — download remote state to stdout
#   terraform state push               — upload local state to remote
#   terraform refresh                  — sync state with real infrastructure
#   terraform import <resource> <id>   — adopt existing resource into state
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local  = { source = "hashicorp/local", version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # ── LOCAL BACKEND (default — no configuration needed) ─────────────────
  # State is stored in ./terraform.tfstate
  # backend "local" {
  #   path = "terraform.tfstate"
  # }

  # ── S3 BACKEND (most common for AWS teams) ─────────────────────────────
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "myapp/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true                     # Encrypt state at rest
  #   dynamodb_table = "terraform-state-lock"   # DynamoDB table for locking
  # }
  # Setup DynamoDB for locking:
  #   aws dynamodb create-table \
  #     --table-name terraform-state-lock \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST

  # ── AZURE BACKEND ──────────────────────────────────────────────────────
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstatestorage"
  #   container_name       = "tfstate"
  #   key                  = "myapp.prod.tfstate"
  # }

  # ── GCS BACKEND (Google Cloud) ─────────────────────────────────────────
  # backend "gcs" {
  #   bucket = "my-tf-state-bucket"
  #   prefix = "terraform/state/myapp"
  # }

  # ── TERRAFORM CLOUD BACKEND ─────────────────────────────────────────────
  # cloud {
  #   organization = "my-org"
  #   workspaces {
  #     name = "myapp-production"
  #   }
  # }
}

provider "local" {}
provider "random" {}

# ─────────────────────────────────────────────────────────────────────────────
# DEMONSTRATING STATE CONCEPTS
# ─────────────────────────────────────────────────────────────────────────────

resource "random_id" "state_demo" { byte_length = 4 }
resource "random_pet" "resource_name" { length = 2 }
resource "random_integer" "priority" { min = 1; max = 100 }

resource "local_file" "app_a" {
  filename        = "${path.module}/app-a-${random_id.state_demo.hex}.txt"
  content         = "App A instance: ${random_pet.resource_name.id}"
  file_permission = "0644"
}

resource "local_file" "app_b" {
  filename        = "${path.module}/app-b-${random_id.state_demo.hex}.txt"
  content         = "App B instance: priority=${random_integer.priority.result}"
  file_permission = "0644"
}

# ── CROSS-STATE DATA SHARING (terraform_remote_state) ─────────────────────
# Read outputs from ANOTHER Terraform state file
# data "terraform_remote_state" "networking" {
#   backend = "s3"
#   config = {
#     bucket = "my-terraform-state"
#     key    = "networking/terraform.tfstate"
#     region = "us-east-1"
#   }
# }
# Then use: data.terraform_remote_state.networking.outputs.vpc_id

# ─────────────────────────────────────────────────────────────────────────────
# STATE MANIPULATION COMMANDS (run in terminal after apply)
# ─────────────────────────────────────────────────────────────────────────────
# terraform state list
# → local_file.app_a
# → local_file.app_b
# → random_id.state_demo
# → random_integer.priority
# → random_pet.resource_name

# terraform state show local_file.app_a
# → Shows all attributes: filename, content, id, file_permission, etc.

# Rename a resource in state (when you rename in .tf file without recreating)
# terraform state mv local_file.app_a local_file.primary_app

# Remove from state without destroying the real resource
# terraform state rm local_file.app_b
# (app_b file still exists on disk; Terraform just forgets about it)

# Import an existing resource into state
# Suppose you manually created a file and want Terraform to manage it:
# terraform import local_file.existing "/path/to/existing/file.txt"

# Pull remote state to inspect locally
# terraform state pull > state-backup.json

output "state_demo_id"    { value = random_id.state_demo.hex }
output "resource_name"    { value = random_pet.resource_name.id }
output "file_a_path"      { value = local_file.app_a.filename }
output "file_b_path"      { value = local_file.app_b.filename }
