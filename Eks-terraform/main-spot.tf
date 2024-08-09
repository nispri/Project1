# IAM Policy Document for Assume Role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "KES" {
  name               = "eks-cluster-cloud"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Attach Amazon EKS Cluster Policy to IAM Role
resource "aws_iam_role_policy_attachment" "KES_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.KES.name
}

# Get VPC Data
data "aws_vpc" "default" {
  default = true
}

# Get Public Subnets for Cluster
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Provision EKS Cluster
resource "aws_eks_cluster" "KES" {
  name     = "EKS_CLOUD"
  role_arn = aws_iam_role.KES.arn

  vpc_config {
    subnet_ids = data.aws_subnets.public.ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.KES_AmazonEKSClusterPolicy,
  ]
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "KES_node_group" {
  name = "eks-node-group-cloud"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

# Attach Required Policies for EKS Nodes
resource "aws_iam_role_policy_attachment" "KES_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.KES_node_group.name
}

resource "aws_iam_role_policy_attachment" "KES_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.KES_node_group.name
}

resource "aws_iam_role_policy_attachment" "KES_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.KES_node_group.name
}

# Create EKS Node Group with Multiple Spot Instance Types
resource "aws_eks_node_group" "KES" {
  cluster_name    = aws_eks_cluster.KES.name
  node_group_name = "Node-cloud"
  node_role_arn   = aws_iam_role.KES_node_group.arn
  subnet_ids      = data.aws_subnets.public.ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  # Specify multiple instance types in the order of preference
  instance_types = ["t3a.medium", "t3.medium", "m5.medium"]

  # Define that this node group should use Spot Instances
  capacity_type = "SPOT"

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.KES_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.KES_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.KES_AmazonEC2ContainerRegistryReadOnly,
  ]
}
