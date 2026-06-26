# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 12 - Loops & Conditionals (count, for_each, for, dynamic, if)
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  Terraform provides several mechanisms for programmatic resource creation
#  and conditional logic — avoiding repetition in your configs.
#
#  LOOPING MECHANISMS:
#   count        — create N identical resources; indexed by count.index
#   for_each     — create one resource per map/set item; keyed by each.key
#   for           — transform lists/maps in expressions (not a resource loop)
#   dynamic block — generate repeated nested blocks inside resources
#
#  CONDITIONAL MECHANISMS:
#   condition ? true_val : false_val   — ternary expression
#   count = condition ? 1 : 0          — conditional resource creation
#   for_each = condition ? map : {}    — conditional resource creation
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

variable "create_backup"  { type = bool;   default = true }
variable "environment"    { type = string; default = "dev" }
variable "replica_count"  { type = number; default = 3 }
variable "services" {
  type = map(object({ port = number; enabled = bool; replicas = number }))
  default = {
    web   = { port = 80;   enabled = true;  replicas = 3 }
    api   = { port = 8080; enabled = true;  replicas = 2 }
    cache = { port = 6379; enabled = false; replicas = 1 }
    db    = { port = 5432; enabled = true;  replicas = 1 }
  }
}

locals {
  is_prod          = var.environment == "prod"
  active_services  = { for k, v in var.services : k => v if v.enabled }

  # for expression — transform a list
  upper_envs       = [for e in ["dev","staging","prod"] : upper(e)]
  # Result: ["DEV","STAGING","PROD"]

  # for expression — transform a map
  service_ports    = { for k, v in var.services : k => v.port }
  # Result: { web=80, api=8080, cache=6379, db=5432 }

  # for expression with filter
  enabled_ports    = { for k, v in var.services : k => v.port if v.enabled }
  # Result: { web=80, api=8080, db=5432 }  (cache excluded)

  # for expression — convert map to list of strings
  service_labels   = [for k, v in var.services : "${k}:${v.port}"]
  # Result: ["web:80","api:8080","cache:6379","db:5432"]

  # Conditional values
  log_level        = local.is_prod ? "warn" : "debug"
  instance_type    = local.is_prod ? "t3.large" : "t3.micro"
  replicas         = local.is_prod ? max(var.replica_count, 2) : var.replica_count
}

# ── count — create N resources ─────────────────────────────────────────────
resource "random_id" "replica_ids" {
  count       = var.replica_count
  byte_length = 2
}

resource "local_file" "replicas" {
  count    = var.replica_count
  filename = "${path.module}/replica-${count.index + 1}.txt"
  content  = <<-EOT
    Replica ${count.index + 1} of ${var.replica_count}
    ID: ${random_id.replica_ids[count.index].hex}
    Role: ${count.index == 0 ? "primary" : "replica"}
    Env: ${var.environment}
  EOT
  file_permission = "0644"
}

# ── for_each — create one resource per map item ────────────────────────────
resource "local_file" "service_configs" {
  for_each = local.active_services   # Only enabled services

  filename = "${path.module}/service-${each.key}.yaml"
  content  = <<-YAML
    service: ${each.key}
    port: ${each.value.port}
    replicas: ${each.value.replicas}
    environment: ${var.environment}
  YAML
  file_permission = "0644"
}

# ── Conditional resource — count = condition ? 1 : 0 ──────────────────────
resource "local_file" "backup_config" {
  count    = var.create_backup ? 1 : 0
  filename = "${path.module}/backup.yaml"
  content  = "backup_enabled: true\nenvironment: ${var.environment}"
  file_permission = "0644"
}
# Access with: local_file.backup_config[0].filename (only if created)

resource "local_file" "summary" {
  filename = "${path.module}/loops-summary.txt"
  content  = <<-EOT
    ========================================
     Loops & Conditionals Demo
    ========================================
    Environment  : ${var.environment}
    Is Production: ${local.is_prod}
    Log Level    : ${local.log_level}
    Instance Type: ${local.instance_type}

    Replicas created (count): ${var.replica_count}
    Files: ${join(", ", local_file.replicas[*].filename)}

    Active services (for_each):
    %{for k, v in local.active_services~}
      - ${k}: port ${v.port}, replicas ${v.replicas}
    %{endfor~}

    For expressions:
      Upper envs  : ${jsonencode(local.upper_envs)}
      Service ports: ${jsonencode(local.service_ports)}
      Enabled ports: ${jsonencode(local.enabled_ports)}
      Labels      : ${jsonencode(local.service_labels)}

    Backup created: ${var.create_backup}
  EOT
  file_permission = "0644"
}

output "replica_ids"      { value = random_id.replica_ids[*].hex }
output "active_services"  { value = keys(local.active_services) }
output "service_files"    { value = { for k, v in local_file.service_configs : k => v.filename } }
output "backup_created"   { value = var.create_backup }
output "enabled_ports"    { value = local.enabled_ports }
