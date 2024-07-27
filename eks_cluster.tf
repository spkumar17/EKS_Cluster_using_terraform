# EKS Cluster Resources

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster-name}-eks-cluster-role"

   assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

}
#attaching polices 
resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster.name
}
# creating eks cluster 
resource "aws_eks_cluster" "eks" {
  name     = "${var.cluster-name}"
  version = var.eks_version
  role_arn = aws_iam_role.eks_cluster.arn


  vpc_config {
    security_group_ids = [data.aws_security_group.eks_control_plane_sg.id]
    endpoint_private_access = false
    endpoint_public_access = true
    subnet_ids         = [
        aws_subnet.prisubnet1a.id,
        aws_subnet.prisubnet1b.id
        ]
  }
  access_config {
    authentication_mode = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
  ]
}
