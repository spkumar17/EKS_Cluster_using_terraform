variable "vpc_cidr_block" {
  type=string
  default = "10.0.0.0/16"
}

variable "cluster-name" {
    type = string
    default = "eks-cluster"
}

variable "pubsub1a_cidr_block" {
  description = "cidr range for publicsubnet1a "
  type = string
  default = "10.0.1.0/24"
}

variable "pubsub1b_cidr_block" {
  description = "cidr range for publicsubnet1b "
  type = string
  default = "10.0.2.0/24"
}

variable "prisub1a_cidr_block" {
  description = "cidr range for publicsubnet1b "
  type = string
  default = "10.0.3.0/24"
}

variable "prisub1b_cidr_block" {
  description = "cidr range for publicsubnet1b "
  type = string
  default = "10.0.4.0/24"
}
variable "eks_version" {
    description = "eks_version"
    type = string
    default = "1.30"
}
variable "instance_types" {
    description = "instace type of the node"
    type = string
    default = "t3.medium"
}