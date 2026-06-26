# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 9 - Built-in Functions & Expressions
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  Terraform has 100+ built-in functions for transforming and combining values.
#  You CANNOT define custom functions in HCL (use modules instead).
#
#  FUNCTION CATEGORIES:
#   String   — format, upper, lower, trim, split, join, replace, regex...
#   Numeric  — abs, ceil, floor, max, min, pow, log...
#   List     — length, concat, flatten, distinct, sort, reverse, slice...
#   Map      — keys, values, merge, lookup, zipmap, tomap...
#   Type     — tostring, tonumber, tobool, tolist, toset, tomap...
#   File     — file, filebase64, templatefile, fileset...
#   Date     — formatdate, timeadd, timestamp...
#   Hash     — md5, sha256, base64encode, base64decode...
#   IP       — cidrhost, cidrnetmask, cidrsubnet, cidrsubnets...
#   Encoding — jsonencode, jsondecode, yamlencode, yamldecode...
#
#  TEST FUNCTIONS INTERACTIVELY:
#   terraform console
#   > upper("hello")
#   > split(",", "a,b,c")
#   > cidrsubnet("10.0.0.0/16", 8, 1)
#   > Ctrl+D to exit
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

variable "raw_name"    { default = "  My App Server  " }
variable "region"      { default = "us-east-1" }
variable "cidr_block"  { default = "10.0.0.0/16" }
variable "servers"     { default = ["web-01", "web-02", "db-01", "cache-01"] }
variable "env_map"     { default = { dev = "d", staging = "s", prod = "p" } }
variable "json_input"  { default = "{\"name\":\"alice\",\"role\":\"admin\"}" }

locals {
  # ─── STRING FUNCTIONS ──────────────────────────────────────────────────
  name_trimmed  = trimspace(var.raw_name)            # "My App Server"
  name_lower    = lower(local.name_trimmed)           # "my app server"
  name_upper    = upper(local.name_trimmed)           # "MY APP SERVER"
  name_slug     = replace(local.name_lower, " ", "-") # "my-app-server"

  # format() — printf-style formatting
  formatted_id  = format("APP-%04d-%s", 42, var.region)  # "APP-0042-us-east-1"
  padded_num    = format("%05d", 7)                        # "00007"

  # split() and join()
  parts         = split("-", var.region)       # ["us", "east", "1"]
  rejoined      = join("_", local.parts)       # "us_east_1"
  csv_servers   = join(", ", var.servers)      # "web-01, web-02, db-01, cache-01"

  # substr(), length(), contains(), startswith(), endswith()
  region_prefix = substr(var.region, 0, 2)    # "us"
  server_count  = length(var.servers)          # 4
  has_cache     = contains(var.servers, "cache-01")   # true
  starts_us     = startswith(var.region, "us")         # true

  # regex and regexall()
  digits_only   = regex("[0-9]+", var.region)          # "1"
  all_digits    = regexall("[0-9]+", "v1.2.3")         # ["1", "2", "3"]

  # ─── NUMERIC FUNCTIONS ─────────────────────────────────────────────────
  rounded_up    = ceil(4.2)    # 5
  rounded_down  = floor(4.9)   # 4
  absolute      = abs(-42)     # 42
  maximum       = max(1, 5, 3, 9, 2)   # 9
  minimum       = min(1, 5, 3, 9, 2)   # 1

  # ─── COLLECTION FUNCTIONS ──────────────────────────────────────────────
  # concat() — merge lists
  all_servers   = concat(var.servers, ["monitor-01", "lb-01"])

  # distinct() — remove duplicates
  deduped       = distinct(["a", "b", "a", "c", "b"])  # ["a","b","c"]

  # flatten() — collapse nested lists
  nested        = [["a", "b"], ["c", "d"]]
  flat          = flatten(local.nested)     # ["a","b","c","d"]

  # sort() and reverse()
  sorted        = sort(var.servers)
  reversed      = reverse(local.sorted)

  # slice(list, start, end)
  first_two     = slice(var.servers, 0, 2)   # ["web-01","web-02"]

  # index() — find position of value
  db_index      = index(var.servers, "db-01")   # 2

  # toset() — convert list to set (removes duplicates, loses order)
  unique_items  = toset(["c", "a", "b", "a"])   # {"a","b","c"}

  # ─── MAP FUNCTIONS ─────────────────────────────────────────────────────
  map_keys      = keys(var.env_map)               # ["dev","prod","staging"]
  map_values    = values(var.env_map)             # ["d","p","s"]

  # lookup(map, key, default) — safe map lookup with default
  prod_short    = lookup(var.env_map, "prod", "unknown")  # "p"
  missing_key   = lookup(var.env_map, "dr", "n/a")        # "n/a"

  # merge() — combine maps (later maps override earlier ones)
  base_tags     = { ManagedBy = "terraform", Owner = "ops" }
  extra_tags    = { Environment = "dev", Owner = "dev-team" }
  merged_tags   = merge(local.base_tags, local.extra_tags)
  # Result: { ManagedBy="terraform", Owner="dev-team", Environment="dev" }

  # zipmap(keys, values) — create a map from two lists
  short_names   = zipmap(var.servers, ["WEB1", "WEB2", "DB1", "CACHE1"])

  # ─── TYPE CONVERSION ───────────────────────────────────────────────────
  num_as_str    = tostring(42)         # "42"
  str_as_num    = tonumber("3.14")     # 3.14
  str_as_bool   = tobool("true")       # true

  # ─── JSON ENCODING / DECODING ──────────────────────────────────────────
  parsed_json   = jsondecode(var.json_input)           # { name="alice", role="admin" }
  json_user     = local.parsed_json["name"]            # "alice"
  encoded_map   = jsonencode({ host = "db", port = 5432 })
  # Result: "{\"host\":\"db\",\"port\":5432}"

  # ─── CONDITIONAL EXPRESSION ────────────────────────────────────────────
  env_label     = var.region == "us-east-1" ? "primary" : "secondary"
  min_replicas  = local.server_count > 2 ? 3 : 1

  # ─── IP / CIDR FUNCTIONS ───────────────────────────────────────────────
  # cidrsubnet(prefix, newbits, netnum) — calculate a subnet CIDR
  subnet_1      = cidrsubnet(var.cidr_block, 8, 1)    # "10.0.1.0/24"
  subnet_2      = cidrsubnet(var.cidr_block, 8, 2)    # "10.0.2.0/24"
  subnet_pub    = cidrsubnet(var.cidr_block, 8, 100)  # "10.0.100.0/24"

  # cidrhost — get specific host IP in a subnet
  gateway_ip    = cidrhost(local.subnet_1, 1)          # "10.0.1.1"
  broadcast_ip  = cidrhost(local.subnet_1, -1)         # "10.0.1.255"

  # ─── HASH & ENCODING ───────────────────────────────────────────────────
  content_hash  = md5("hello world")                   # md5 checksum
  sha_hash      = sha256("hello world")                # sha256 checksum
  b64_encoded   = base64encode("user:password")        # "dXNlcjpwYXNzd29yZA=="
  b64_decoded   = base64decode("dXNlcjpwYXNzd29yZA==")# "user:password"
}

resource "local_file" "functions_demo" {
  filename = "${path.module}/functions-demo.txt"
  content  = <<-EOT
    ========================================
     Terraform Functions Demo
    ========================================
    STRING FUNCTIONS:
      Trimmed name  : "${local.name_trimmed}"
      Lower slug    : "${local.name_slug}"
      Formatted ID  : "${local.formatted_id}"
      Padded num    : "${local.padded_num}"
      Split region  : ${jsonencode(local.parts)}
      Region prefix : "${local.region_prefix}"
      Has cache?    : ${local.has_cache}
      Starts 'us'?  : ${local.starts_us}

    NUMERIC FUNCTIONS:
      ceil(4.2)     : ${local.rounded_up}
      floor(4.9)    : ${local.rounded_down}
      max(1,5,3,9,2): ${local.maximum}
      min(1,5,3,9,2): ${local.minimum}

    COLLECTION FUNCTIONS:
      Server count  : ${local.server_count}
      First two     : ${jsonencode(local.first_two)}
      DB index      : ${local.db_index}
      Sorted        : ${jsonencode(local.sorted)}
      Deduped       : ${jsonencode(local.deduped)}
      Flattened     : ${jsonencode(local.flat)}

    MAP FUNCTIONS:
      Env keys      : ${jsonencode(local.map_keys)}
      Prod short    : "${local.prod_short}"
      Missing key   : "${local.missing_key}"
      Merged tags   : ${jsonencode(local.merged_tags)}

    TYPE & JSON:
      JSON user     : "${local.json_user}"
      Num as str    : "${local.num_as_str}"
      Encoded map   : ${local.encoded_map}

    CONDITIONAL:
      env_label     : "${local.env_label}"
      min_replicas  : ${local.min_replicas}

    IP / CIDR:
      Subnet 1      : "${local.subnet_1}"
      Subnet 2      : "${local.subnet_2}"
      Gateway IP    : "${local.gateway_ip}"

    HASHING:
      MD5           : "${local.content_hash}"
      Base64        : "${local.b64_encoded}"
  EOT
  file_permission = "0644"
}

output "name_slug"    { value = local.name_slug }
output "subnet_1"     { value = local.subnet_1 }
output "merged_tags"  { value = local.merged_tags }
output "json_user"    { value = local.json_user }
