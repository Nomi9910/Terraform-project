# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 13 - Terraform in CI/CD Pipelines
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  Automating Terraform in CI/CD ensures infrastructure changes are:
#   - Reviewed (plan output in PR comments)
#   - Tested (validate + lint in CI)
#   - Applied consistently (no manual drift)
#   - Audited (all changes tracked in Git and pipeline logs)
#
#  CI/CD WORKFLOW:
#   PR opened   → fmt check → validate → plan (post output to PR)
#   PR merged   → plan again → apply (on main branch only)
#   PR closed   → optional: destroy (for ephemeral environments)
#
#  TOOLS:
#   GitHub Actions, GitLab CI, Jenkins, CircleCI, Atlantis, Terraform Cloud
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# GITHUB ACTIONS WORKFLOW — .github/workflows/terraform.yml
# ─────────────────────────────────────────────────────────────────────────────
# Save this as .github/workflows/terraform.yml in your repo
#
# name: Terraform CI/CD
#
# on:
#   push:
#     branches: [main]
#   pull_request:
#     branches: [main]
#
# env:
#   TF_VERSION: "1.7.0"
#   AWS_DEFAULT_REGION: "us-east-1"
#
# jobs:
#   terraform:
#     name: Terraform
#     runs-on: ubuntu-latest
#
#     steps:
#       - name: Checkout
#         uses: actions/checkout@v4
#
#       - name: Setup Terraform
#         uses: hashicorp/setup-terraform@v3
#         with:
#           terraform_version: ${{ env.TF_VERSION }}
#           cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
#
#       - name: Configure AWS Credentials
#         uses: aws-actions/configure-aws-credentials@v4
#         with:
#           aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
#           aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
#           aws-region:            ${{ env.AWS_DEFAULT_REGION }}
#
#       - name: Terraform Format Check
#         id: fmt
#         run: terraform fmt -check -recursive
#         continue-on-error: true
#
#       - name: Terraform Init
#         id: init
#         run: terraform init
#
#       - name: Terraform Validate
#         id: validate
#         run: terraform validate -no-color
#
#       - name: Terraform Plan
#         id: plan
#         if: github.event_name == 'pull_request'
#         run: terraform plan -no-color -out=tfplan
#         continue-on-error: true
#
#       - name: Comment Plan on PR
#         uses: actions/github-script@v7
#         if: github.event_name == 'pull_request'
#         with:
#           script: |
#             const output = `#### Terraform Format: \`${{ steps.fmt.outcome }}\`
#             #### Terraform Init: \`${{ steps.init.outcome }}\`
#             #### Terraform Validate: \`${{ steps.validate.outcome }}\`
#             #### Terraform Plan: \`${{ steps.plan.outcome }}\`
#             <details><summary>Show Plan</summary>
#             \`\`\`terraform
#             ${{ steps.plan.outputs.stdout }}
#             \`\`\`
#             </details>`;
#             github.rest.issues.createComment({
#               issue_number: context.issue.number,
#               owner: context.repo.owner,
#               repo: context.repo.repo,
#               body: output
#             })
#
#       - name: Terraform Apply
#         if: github.ref == 'refs/heads/main' && github.event_name == 'push'
#         run: terraform apply -auto-approve tfplan

# ─────────────────────────────────────────────────────────────────────────────
# ATLANTIS — Pull Request Automation for Terraform
# ─────────────────────────────────────────────────────────────────────────────
# Atlantis runs terraform plan/apply from PR comments:
#   atlantis.yaml — per-repo workflow config

# project_hcl_files: ["**/*.tf"]
# projects:
# - name: myapp-dev
#   dir: .
#   workspace: dev
#   terraform_version: v1.7.0
#   autoplan:
#     when_modified: ["*.tf", "*.tfvars"]
#     enabled: true
#   apply_requirements: [approved, mergeable]

# ─────────────────────────────────────────────────────────────────────────────
# GITLAB CI — .gitlab-ci.yml
# ─────────────────────────────────────────────────────────────────────────────
# image: hashicorp/terraform:1.7.0
#
# variables:
#   TF_ROOT: ${CI_PROJECT_DIR}
#   TF_STATE_NAME: ${CI_PROJECT_NAME}
#
# cache:
#   key: "${TF_ROOT}"
#   paths: [.terraform]
#
# stages: [validate, plan, apply, destroy]
#
# validate:
#   stage: validate
#   script:
#     - terraform init
#     - terraform validate
#     - terraform fmt -check
#
# plan:
#   stage: plan
#   script:
#     - terraform init
#     - terraform plan -out=tfplan
#   artifacts:
#     paths: [tfplan]
#
# apply:
#   stage: apply
#   script:
#     - terraform init
#     - terraform apply tfplan
#   when: manual   # Requires human approval
#   only: [main]

# ─────────────────────────────────────────────────────────────────────────────
# WORKING TERRAFORM CONFIG (demonstrates CI/CD-friendly patterns)
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    local  = { source = "hashicorp/local",  version = "~> 2.4" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # In CI/CD, use remote backend for shared state:
  # backend "s3" {
  #   bucket         = "my-tf-state"
  #   key            = "myapp/${terraform.workspace}/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }
}

provider "local" {}
provider "random" {}

variable "ci_build_number" {
  description = "CI build number — passed in via -var in pipelines"
  type        = string
  default     = "local"
}

variable "git_commit_sha" {
  description = "Git commit SHA — for traceability"
  type        = string
  default     = "unknown"
}

variable "environment" {
  type    = string
  default = "dev"
}

resource "random_id" "deployment_id" { byte_length = 4 }

resource "local_file" "deployment_manifest" {
  filename = "${path.module}/deployment-${var.environment}.json"
  content  = jsonencode({
    deployment_id  = random_id.deployment_id.hex
    environment    = var.environment
    build_number   = var.ci_build_number
    git_sha        = var.git_commit_sha
    deployed_at    = timestamp()
    managed_by     = "terraform"
  })
  file_permission = "0644"
}

output "deployment_id"  { value = random_id.deployment_id.hex }
output "manifest_path"  { value = local_file.deployment_manifest.filename }

# ─────────────────────────────────────────────────────────────────────────────
# CI/CD BEST PRACTICES:
# ─────────────────────────────────────────────────────────────────────────────
# ✅ Always run: fmt → validate → plan → (manual approval) → apply
# ✅ Store state in remote backend with locking
# ✅ Never run terraform apply with -auto-approve in production
# ✅ Use -input=false in CI (no interactive prompts)
# ✅ Use -no-color in CI (clean log output)
# ✅ Save plan with -out=tfplan; apply the SAVED plan (ensures what you reviewed is applied)
# ✅ Post plan output as PR comment for review
# ✅ Use workspaces or separate state keys per environment
# ✅ Store secrets in CI/CD secret manager (never in .tf files or tfvars)
# ✅ Pin Terraform and provider versions (.terraform.lock.hcl in Git)
# ✅ Run terraform validate in pre-commit hooks
