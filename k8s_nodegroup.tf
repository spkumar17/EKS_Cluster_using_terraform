resource "aws_security_group" "control_plane_sg" {
  name        = "control-plane-sg"
  description = "Security group for Kubernetes control plane"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "control-plane-sg"
  }
}
resource "aws_security_group" "eks_worker_sg" {
  name        = "eks_worker_sg"
  description = "EKS Worker Nodes Security Group"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description     = "Allow pods to communicate with the cluster API Server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.control_plane_sg.id]
  }

  ingress {
    description = "Allow nodes to communicate with each other"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.prisub1a_cidr_block, var.prisub1b_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
   tags = {
    Name = "eks-nodegroup-sg"
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
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "ec2_describe_instances" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
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
    desired_size = 3
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
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.attach_ssm_policy,
    aws_iam_role_policy_attachment.ec2_describe_instances
    
  ]
}
