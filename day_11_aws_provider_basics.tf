# ╔══════════════════════════════════════════════════════════════════════════════╗
#  Day 11 - AWS Provider Basics (EC2, S3, VPC, IAM)
# ╠══════════════════════════════════════════════════════════════════════════════╣
#  This file shows real-world AWS resources using the hashicorp/aws provider.
#  These are REFERENCE configs — you need AWS credentials to actually apply.
#
#  SETUP AWS CREDENTIALS (choose one method):
#   Method 1 — Environment variables (best for CI/CD):
#     export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
#     export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
#     export AWS_DEFAULT_REGION="us-east-1"
#
#   Method 2 — AWS CLI profile:
#     aws configure --profile myprofile
#     # Then in provider: profile = "myprofile"
#
#   Method 3 — IAM Role (on EC2/ECS — automatic, most secure)
#     No config needed; AWS SDK picks up the role automatically
#
#   Method 4 — ~/.aws/credentials file (populated by aws configure)
# ╚══════════════════════════════════════════════════════════════════════════════╝

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Credentials from environment variables or ~/.aws/credentials
  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

variable "aws_region"    { default = "us-east-1" }
variable "environment"   { default = "dev" }
variable "project_name"  { default = "myapp" }

# ─────────────────────────────────────────────────────────────────────────────
# DATA SOURCES — look up existing AWS resources
# ─────────────────────────────────────────────────────────────────────────────

# Get the latest Amazon Linux 2023 AMI (no hardcoded AMI IDs!)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get the default VPC
data "aws_vpc" "default" { default = true }

# Get availability zones in the region
data "aws_availability_zones" "available" { state = "available" }

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# VPC & NETWORKING
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags              = { Name = "${var.project_name}-public-${count.index + 1}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP/HTTPS/SSH inbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22; to_port = 22; protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Restrict to your IP in production!
  }
  ingress {
    description = "HTTP"
    from_port   = 80; to_port = 80; protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443; to_port = 443; protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0; to_port = 0; protocol = "-1"   # All outbound
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-web-sg" }
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2 INSTANCE
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/id_ed25519.pub")   # Your SSH public key
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  # User data runs on first boot
  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx
    systemctl enable --now nginx
    echo "<h1>Deployed by Terraform</h1>" > /var/www/html/index.html
  EOF

  tags = { Name = "${var.project_name}-web-server" }
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 BUCKET
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "app_assets" {
  bucket = "${var.project_name}-assets-${data.aws_caller_identity.current.account_id}"
  tags   = { Name = "${var.project_name}-assets" }
}

resource "aws_s3_bucket_versioning" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_assets" {
  bucket = aws_s3_bucket.app_assets.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM — Instance Role (so EC2 can access S3)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

output "vpc_id"         { value = aws_vpc.main.id }
output "instance_id"    { value = aws_instance.web.id }
output "public_ip"      { value = aws_instance.web.public_ip }
output "s3_bucket"      { value = aws_s3_bucket.app_assets.id }
output "ami_used"        { value = data.aws_ami.amazon_linux.id }
output "account_id"     { value = data.aws_caller_identity.current.account_id }
