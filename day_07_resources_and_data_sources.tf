# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 7 - Resources & Data Sources
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  RESOURCES vs DATA SOURCES:
#
#  resource "type" "name" { }   ← CREATES and MANAGES infrastructure
#    - Terraform owns it: creates, updates, destroys
#    - Tracked in state file
#    - Shown in plan as + (create) or ~ (update) or - (destroy)
#
#  data "type" "name" { }       ← READS existing infrastructure
#    - Read-only: Terraform never modifies it
#    - Data is fetched fresh on every plan/apply
#    - Used to reference things not managed by THIS config
#    - Shown in plan as <= (data read)
#
#  RESOURCE META-ARGUMENTS (apply to ALL resource types):
#   depends_on   — explicit dependency ordering
#   count        — create N copies of a resource
#   for_each     — create one resource per map/set item
#   provider     — specify which provider instance to use
#   lifecycle    — control create/update/destroy behaviour
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    http   = { source = "hashicorp/http",   version = "~> 3.4" }
  }
}
provider "local" {}
provider "random" {}
provider "http" {}

# ─────────────────────────────────────────────────────────────────────────────
# DATA SOURCES — reading existing/external information
# ─────────────────────────────────────────────────────────────────────────────

# Read a local file that already exists (not managed by this config)
data "local_file" "hosts" {
  filename = "/etc/hosts"
  # Explanation: reads /etc/hosts content; doesn't modify or track it
  # Access with: data.local_file.hosts.content
}

# Make an HTTP GET request and read the response
data "http" "public_ip" {
  url = "https://api.ipify.org?format=text"
  # Explanation: fetches your public IP from an external API
  # Access with: data.http.public_ip.response_body
}

# ─────────────────────────────────────────────────────────────────────────────
# RESOURCE META-ARGUMENT: count — create multiple identical resources
# ─────────────────────────────────────────────────────────────────────────────

variable "file_count" {
  type    = number
  default = 3
  # Creates 3 files: server-0.txt, server-1.txt, server-2.txt
}

resource "local_file" "servers" {
  count    = var.file_count
  # count.index = current iteration (0, 1, 2, ...)
  filename = "${path.module}/server-${count.index}.txt"
  content  = <<-EOT
    Server ${count.index + 1} of ${var.file_count}
    Hostname: server-${count.index + 1}.example.com
    Role: ${count.index == 0 ? "primary" : "replica"}
  EOT
  file_permission = "0644"
}
# Reference individual instances: local_file.servers[0].filename
# Reference all:                  local_file.servers[*].filename

# ─────────────────────────────────────────────────────────────────────────────
# RESOURCE META-ARGUMENT: for_each — create one resource per item
# Better than count when items have meaningful names
# ─────────────────────────────────────────────────────────────────────────────

variable "environments" {
  type = map(object({
    replicas  = number
    log_level = string
  }))
  default = {
    dev = {
      replicas  = 1
      log_level = "debug"
    }
    staging = {
      replicas  = 2
      log_level = "info"
    }
    prod = {
      replicas  = 3
      log_level = "warn"
    }
  }
}

resource "local_file" "env_configs" {
  for_each = var.environments
  # each.key   = map key   (e.g. "dev", "staging", "prod")
  # each.value = map value (e.g. { replicas = 1, log_level = "debug" })
  filename = "${path.module}/config-${each.key}.yaml"
  content  = <<-YAML
    environment: ${each.key}
    replicas: ${each.value.replicas}
    log_level: ${each.value.log_level}
  YAML
  file_permission = "0644"
}
# Reference: local_file.env_configs["prod"].filename

# ─────────────────────────────────────────────────────────────────────────────
# RESOURCE META-ARGUMENT: depends_on — explicit ordering
# ─────────────────────────────────────────────────────────────────────────────

resource "local_file" "base_config" {
  filename        = "${path.module}/base.yaml"
  content         = "base: true\npublic_ip: ${data.http.public_ip.response_body}"
  file_permission = "0644"
}

resource "local_file" "app_config" {
  filename        = "${path.module}/app.yaml"
  content         = "app: myapp\nbase_config: ${local_file.base_config.filename}"
  file_permission = "0644"
  depends_on      = [local_file.base_config]
  # Explanation: Terraform usually infers dependencies from references.
  # Use depends_on only when the dependency is not captured in expressions.
}

# ─────────────────────────────────────────────────────────────────────────────
# RESOURCE META-ARGUMENT: lifecycle — control behaviour
# ─────────────────────────────────────────────────────────────────────────────

resource "random_password" "api_key" {
  length  = 32
  special = false

  lifecycle {
    # ignore_changes: don't update resource when these attributes change in config
    ignore_changes = [length]

    # create_before_destroy: spin up replacement BEFORE destroying old one
    # (avoids downtime during replacement)
    create_before_destroy = true

    # prevent_destroy: block terraform destroy for this resource (safety net)
    # prevent_destroy = true   # Uncomment for production critical resources

    # replace_triggered_by: force replacement when another resource changes
    # replace_triggered_by = [local_file.base_config]
  }
}

resource "local_file" "summary" {
  filename = "${path.module}/summary.txt"
  content  = <<-EOT
    ========================================
     Resources & Data Sources Summary
    ========================================
    Public IP (from data source): ${data.http.public_ip.response_body}
    /etc/hosts lines: ${length(split("\n", data.local_file.hosts.content))}

    Server files created (count):
    %{for i in range(var.file_count)~}
      ${i + 1}. ${local_file.servers[i].filename}
    %{endfor~}

    Environment configs (for_each):
    %{for env in keys(var.environments)~}
      - ${env}: ${local_file.env_configs[env].filename}
    %{endfor~}

    API Key length: ${length(random_password.api_key.result)} chars
  EOT
  file_permission = "0644"
}

output "public_ip"     { value = data.http.public_ip.response_body }
output "server_files"  { value = local_file.servers[*].filename }
output "env_configs"   { value = { for k, v in local_file.env_configs : k => v.filename } }
output "summary_path"  { value = local_file.summary.filename }
