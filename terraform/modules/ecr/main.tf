variable "environment" {
  type = string
}

resource "aws_ecr_repository" "app" {
  name                 = "lacrei-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = "LacreiChallenge"
  }
}

output "repository_url" {
  value = aws_ecr_repository.app.repository_url
}
