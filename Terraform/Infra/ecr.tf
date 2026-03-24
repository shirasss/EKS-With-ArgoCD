resource "aws_ecr_repository" "ecr_repo" {
  name = "app-ecr"
  image_tag_mutability = "MUTABLE"
}

# ECR LifeCycle Policy
resource "aws_ecr_lifecycle_policy" "policy" {
  repository = aws_ecr_repository.ecr_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}
