# Fluent Bit CloudWatch Integration

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "eks_logs" {
  name              = "/aws/eks/fluentbit-cloudwatch/logs"
  retention_in_days = 7

  tags = {
    Name = "eks-fluent-bit-logs"
  }
}

data "aws_region" "current" {}

# Pod Identity Agent addon
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"
}

# IAM Role for Fluent Bit (Pod Identity)
resource "aws_iam_role" "fluent_bit" {
  name = "eks-fluent-bit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}
# IAM Policy for CloudWatch access
resource "aws_iam_role_policy" "fluent_bit_cloudwatch" {
  name = "fluent-bit-cloudwatch"
  role = aws_iam_role.fluent_bit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        aws_cloudwatch_log_group.eks_logs.arn,        # the group itself
        "${aws_cloudwatch_log_group.eks_logs.arn}:*"  # streams within it
      ]
    }]
  })
}

# Pod Identity association — binds role to namespace + service account
resource "aws_eks_pod_identity_association" "fluent_bit" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "amazon-cloudwatch"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluent_bit.arn

  depends_on = [aws_eks_addon.pod_identity_agent]
}

