module "eks" {
  source = "./Infra"
}

module "eks-config" {
  source = "./eks-config"

  cloudwatch_log_group = module.eks.cloudwatch_log_group
  aws_region           = module.eks.aws_region
  github_token         = var.github_token

  depends_on = [module.eks]
}