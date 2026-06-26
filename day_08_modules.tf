# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 8 - Modules
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  WHAT IS A MODULE?
#  A module is a collection of Terraform files in a directory that are used
#  together. Every Terraform config is a module (the "root module").
#  You can call other modules (child modules) from the root module.
#
#  WHY USE MODULES?
#   ✔ Reusability — define once, use in many places (dev/staging/prod)
#   ✔ Encapsulation — hide complexity behind a clean interface
#   ✔ Consistency — enforce standards across teams
#   ✔ Composability — combine modules to build complex infrastructure
#
#  MODULE SOURCES:
#   Local path:         source = "./modules/webserver"
#   Terraform Registry: source = "terraform-aws-modules/vpc/aws"
#   GitHub:             source = "github.com/org/repo//modules/webserver"
#   S3:                 source = "s3::https://bucket/module.zip"
#   Git:                source = "git::https://example.com/module.git"
#
#  MODULE STRUCTURE:
#   modules/
#   └── application/
#       ├── main.tf       ← resources
#       ├── variables.tf  ← input variables (the module's interface)
#       ├── outputs.tf    ← outputs exposed to callers
#       └── README.md     ← documentation
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}
provider "local" {}
provider "random" {}

# ─────────────────────────────────────────────────────────────────────────────
# INLINE EXAMPLE: Simulating module calls
# In practice modules live in separate directories.
# This file shows the ROOT MODULE calling child modules.
# ─────────────────────────────────────────────────────────────────────────────

# Module call — instantiate a module
module "app_dev" {
  source = "./modules/application"    # Path to child module directory

  # Pass values to the module's input variables
  app_name    = "myapp"
  environment = "dev"
  replicas    = 1
  tags = {
    Team      = "backend"
    CostCode  = "eng-001"
  }
}

module "app_prod" {
  source = "./modules/application"    # Same module, different values

  app_name    = "myapp"
  environment = "prod"
  replicas    = 3
  tags = {
    Team      = "backend"
    CostCode  = "eng-001"
  }
}

# Public registry module (no local file needed — downloaded on init)
# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 5.0"
#
#   name = "my-vpc"
#   cidr = "10.0.0.0/16"
#   azs  = ["us-east-1a", "us-east-1b"]
#   private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
#   public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
# }

# Access module outputs with: module.<name>.<output>
output "dev_config_path"  { value = module.app_dev.config_file_path }
output "prod_config_path" { value = module.app_prod.config_file_path }
output "dev_app_id"       { value = module.app_dev.app_id }
output "prod_app_id"      { value = module.app_prod.app_id }

# ─────────────────────────────────────────────────────────────────────────────
# CHILD MODULE DEFINITION
# In a real project, the following goes in ./modules/application/
# Create these files manually to test:
# ─────────────────────────────────────────────────────────────────────────────

# === ./modules/application/variables.tf ===
# variable "app_name"    { type = string }
# variable "environment" { type = string }
# variable "replicas"    { type = number; default = 1 }
# variable "tags"        { type = map(string); default = {} }

# === ./modules/application/main.tf ===
# resource "random_id" "id" { byte_length = 4 }
# resource "local_file" "config" {
#   filename = "${path.module}/../../output/${var.app_name}-${var.environment}.yaml"
#   content  = <<-YAML
#     app: ${var.app_name}
#     env: ${var.environment}
#     id:  ${random_id.id.hex}
#     replicas: ${var.replicas}
#   YAML
#   file_permission = "0644"
# }

# === ./modules/application/outputs.tf ===
# output "app_id"          { value = random_id.id.hex }
# output "config_file_path"{ value = local_file.config.filename }

# ─────────────────────────────────────────────────────────────────────────────
# MODULE COMMANDS:
# ─────────────────────────────────────────────────────────────────────────────
# terraform init           ← downloads module sources + providers
# terraform get            ← download modules without full init
# terraform get -update    ← update cached modules to latest versions
#
# After refactoring (renaming a module call):
# terraform state mv module.old_name module.new_name
