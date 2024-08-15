terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  
}
#Backend Configration

terraform {
  backend "s3" {
    bucket         = "tfstatefile-s3-store-acc2" # Backet name (Unique)
    key            = "eks_terraform.tfstate" # name of the file in Bucket
    region         = "us-east-1" 
  }
}



# Include your separate Terraform configuration files
# VPC resources configuration


resource "aws_vpc" "myvpc" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"
  enable_dns_support =  true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.cluster-name}-VPC"
  }
}

#internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "${var.cluster-name}-igw"

  }
}

data "aws_availability_zones" "available_zones" {
  state = "available"
}

#public subnets 
resource "aws_subnet" "pubsubnet1a" {
    vpc_id     = aws_vpc.myvpc.id
    availability_zone = data.aws_availability_zones.available_zones.names[0]
    cidr_block = var.pubsub1a_cidr_block
    map_public_ip_on_launch = true



  tags = {
    Name = "pubsubnet_1a"
    "kubernetes.io/role/elb" = "1" # Indicates that the subnet should be used for external load balancers.
    "kubernetes,io/cluster/$(var.cluster-name)" ="owned"

  }
}

resource "aws_subnet" "pubsubnet1b" {
    vpc_id     = aws_vpc.myvpc.id
    availability_zone = data.aws_availability_zones.available_zones.names[1]
    cidr_block = var.pubsub1b_cidr_block
    map_public_ip_on_launch = true



  tags = {
    Name = "pubsubnet_1b"
    "kubernetes.io/role/elb" = "1"
    "kubernetes,io/cluster/$(var.cluster-name)" ="owned"


  }
}

#private subnets
resource "aws_subnet" "prisubnet1a" {
    vpc_id     = aws_vpc.myvpc.id
    availability_zone = data.aws_availability_zones.available_zones.names[0]
    cidr_block = var.prisub1a_cidr_block
    map_public_ip_on_launch = false



  tags = {
    Name = "prisubnet_1a"
    "kubernetes.io/role/internal-elb" = "1" #Indicates that the subnet should be used for internal load balancers.
    "kubernetes,io/cluster/$(var.cluster-name)" ="owned"
 
 /*The tag kubernetes.io/cluster/${var.cluster-name} = "owned" is used to identify and 
 associate AWS resources, such as ELBs (Elastic Load Balancers), subnets, and other components,
 with a specific Kubernetes cluster. This is particularly useful when you have multiple clusters, 
 as it ensures that resources are correctly attributed to the appropriate cluster. */

  }
}

resource "aws_subnet" "prisubnet1b" {
    vpc_id     = aws_vpc.myvpc.id
    availability_zone = data.aws_availability_zones.available_zones.names[1]
    cidr_block = var.prisub1b_cidr_block
    map_public_ip_on_launch = false



  tags = {
    Name = "prisubnet_1b" 
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes,io/cluster/$(var.cluster-name)" ="owned"

  }
}
#elasticip  for NAT gateway in the public subnet pub-sub-1a
resource "aws_eip" "eip-nat-a" {
  domain = "vpc"

    

  tags   = {
    Name = "eip-nat-a"
  }
}

# allocate elastic ip this eip will be used for the nat-gateway in the public subnet pub-sub-1b
resource "aws_eip" "eip-nat-b" {
  domain = "vpc"


  tags   = {
    Name = "eip-nat-b"
  }
}

#NAT creation and eip's allocation for both 1a and 1b

resource "aws_nat_gateway" "nat-a" {
  allocation_id = aws_eip.eip-nat-a.id
  subnet_id     = aws_subnet.pubsubnet1a.id 

  tags   = {
    Name = "nat-a"
  }

  # to ensure proper ordering, it is recommended to add an explicit dependency
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat-b" {
  allocation_id = aws_eip.eip-nat-b.id
  subnet_id     = aws_subnet.pubsubnet1b.id 

  tags   = {
    Name = "nat-b"
  }

  # to ensure proper ordering, it is recommended to add an explicit dependency
  depends_on = [aws_internet_gateway.igw]
}

# public Route tables 

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  
  tags = {
    Name = "public_rt"
  }
}

#public route table association 

resource "aws_route_table_association" "publicsubnet1a_association" {
  subnet_id = aws_subnet.pubsubnet1a.id
  route_table_id = aws_route_table.public_rt.id
 
}

resource "aws_route_table_association" "publicsubnet1b_association" {
  subnet_id      = aws_subnet.pubsubnet1b.id
  route_table_id = aws_route_table.public_rt.id
}


#PRIVATE routetable creation for  1a

resource "aws_route_table" "private_rt_1a" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-a.id
  }

  
  tags = {
    Name = "private_rt_1a"
  }
}

#routetable association with private subnet 1a 

resource "aws_route_table_association" "private_subnet_1a_association" {
  subnet_id = aws_subnet.prisubnet1a.id
  route_table_id = aws_route_table.private_rt_1a.id
  
}

#PRIVATE routetable creation for 1b

resource "aws_route_table" "private_rt_1b" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-b.id
  }

  
  tags = {
    Name = "private_rt_1b"
  }
}
#routetable association with private subnet  1b 

resource "aws_route_table_association" "private_subnet_1b_association" {
  subnet_id = aws_subnet.prisubnet1b.id
  route_table_id = aws_route_table.private_rt_1b.id
  
}