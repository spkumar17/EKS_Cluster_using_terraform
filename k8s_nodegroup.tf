data "aws_security_group" "eks_control_plane_sg" {
  filter {
    name   = "tag:kubernetes.io/cluster/${var.cluster-name}"
    values = ["owned"]
  }

  vpc_id = aws_vpc.myvpc.id
}

resource "aws_security_group" "node" {
  name        = "${var.cluster-name}-eks-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.myvpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group_rule" "node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.node.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node.id}"
  source_security_group_id = "${aws_security_group.cluster.id}"
  to_port                  = 65535
  type                     = "ingress"
}

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

resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role      = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role      = aws_iam_role.node.name
}
resource "aws_eks_node_group" "nodegroup" {
  cluster_name    = aws_eks_cluster.eks.name
  version         = var.eks_version
  node_group_name = "general"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [aws_subnet.prisubnet1a.id, aws_subnet.prisubnet1b.id]
  instance_types  = [var.instance_types]
  

  
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  remote_access {
    # Specify a valid SSH key pair name or remove if SSH access is not needed
    ec2_ssh_key = "ssm"  
    source_security_group_ids = [aws_security_group.node.id]
  }

  depends_on = [
    aws_iam_role.node,
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy
  ]
}
