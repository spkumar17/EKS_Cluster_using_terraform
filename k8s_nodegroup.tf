resource "aws_iam_role" "node" {
  name = "${var.cluster-name}-eks-node-role"

   assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

}
#attaching polices 
resource "aws_iam_role_policy_attachment" "amazon_eks_workr_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_eks_node_group" "nodegroup" {
  cluster_name    = aws_eks_cluster.eks.name
  version = var.eks_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.prisubnet1a.id,aws_subnet.prisubnet1b.id]
  instance_types = [var.instance_types]
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.amazon_eks_workr_node_policy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy
  ]
}

