# ==================== envs/test/providers.tf ====================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.12.2"
  backend "s3" {}
}

provider "aws" {
  region = var.Region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = var.Project
      Environment = var.Environment
    }
  }
}