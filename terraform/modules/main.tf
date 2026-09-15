terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}


resource "aws_budgets_budget" "monthly" {
  count       = var.budget_email != "" ? 1 : 0
  name        = "lacrei-${var.environment}-budget"
  budget_type = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}

module "vpc" {
  source      = "./vpc"
  environment = var.environment
}

module "ecr" {
  source      = "./ecr"
  environment = var.environment
}

module "ec2" {
  source        = "./ec2"
  environment   = var.environment
  aws_region    = var.aws_region
  vpc_id        = module.vpc.vpc_id
  public_subnet = module.vpc.public_subnet_id
}

output "instance_id" {
  value = module.ec2.instance_id
}

output "public_ip" {
  value = module.ec2.public_ip
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
