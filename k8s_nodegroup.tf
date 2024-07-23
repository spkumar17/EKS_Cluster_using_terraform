data "aws_security_group" "eks_control_plane_sg" {
  filter {
    name   = "tag:kubernetes.io/cluster/${var.cluster-name}"
    values = ["owned", "shared"]
  }

  vpc_id = aws_vpc.myvpc.id
}

resource "aws_security_group" "eks_worker_sg" {
  name        = "eks_worker_sg"
  description = "EKS Worker Nodes Security Group"
  vpc_id      = aws_vpc.myvpc.id

    ingress {
    description      = "Allow pods to communicate with the cluster API Server"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    security_groups  = [data.aws_security_group.eks_control_plane_sg.id]
  }

  ingress {
    description      = "Allow nodes to communicate with each other"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = [var.prisub1a_cidr_block, var.prisub1b_cidr_block]
  }

  ingress {
    description      = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
    from_port        = 1025
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = [var.prisub1a_cidr_block, var.prisub1b_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
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
  ami_type = "AL2_x86_64"

  
  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  remote_access {
    # Specify a valid SSH key pair name or remove if SSH access is not needed
    ec2_ssh_key = "ssm"  
    source_security_group_ids = [aws_security_group.eks_worker_sg.id]
  }

  depends_on = [
    aws_iam_role.node,
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy
  ]
}
