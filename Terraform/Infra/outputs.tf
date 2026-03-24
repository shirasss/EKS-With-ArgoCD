output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "cluster_ca" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.eks_logs.name
}

output "aws_region" {
  value = data.aws_region.current.name
}