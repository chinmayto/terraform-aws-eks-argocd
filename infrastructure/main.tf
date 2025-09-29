####################################################################################
# Data source for availability zones
####################################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

####################################################################################
### VPC Module Configuration
####################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-VPC"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true
  #one_nat_gateway_per_az = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
###  EKS Cluster Module Configuration
####################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    EKS_Node_Group = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      subnet_ids = module.vpc.private_subnets
    }
  }

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  tags = {
    Name        = var.cluster_name
    Environment = var.environment
    Terraform   = "true"
  }
}


/*
####################################################################################
###  EFS Module Configuration
####################################################################################
module "efs" {
  source = "./modules/efs"

  cluster_name       = var.cluster_name
  environment        = var.environment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.vpc.private_subnets

  depends_on = [module.eks, module.vpc]
}

####################################################################################
###  EBS Module Configuration
####################################################################################
module "ebs" {
  source = "./modules/ebs"

  cluster_name       = var.cluster_name
  environment        = var.environment
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # EBS volume configuration
  ebs_volume_type       = "gp3"
  ebs_volume_size       = 20
  ebs_volume_iops       = 3000
  ebs_volume_throughput = 125
  ebs_encrypted         = true

  # Static volume for testing
  create_static_volume = true
  static_volume_size   = 10

  depends_on = [module.eks, module.vpc]
}

####################################################################################
###  S3 Module Configuration
####################################################################################
module "s3" {
  source = "./modules/s3"

  cluster_name       = var.cluster_name
  environment        = var.environment
  bucket_name        = var.s3_bucket_name
  versioning_enabled = true

  depends_on = [module.eks]
}

####################################################################################
###  EFS CSI Driver Addon (deployed after EFS module)
####################################################################################
resource "aws_eks_addon" "efs_csi_driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-efs-csi-driver"

  # Ensure this addon is created after the EFS module creates the IAM role and pod identity association
  depends_on = [module.efs]

  tags = {
    Name        = "${var.cluster_name}-efs-csi-driver"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
###  EBS CSI Driver Addon (deployed after EBS module)
####################################################################################
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  # Ensure this addon is created after the EBS module creates the IAM role and pod identity association
  depends_on = [module.ebs]

  tags = {
    Name        = "${var.cluster_name}-ebs-csi-driver"
    Environment = var.environment
    Terraform   = "true"
  }
}

####################################################################################
###  S3 Mountpoint CSI Driver Addon (deployed after S3 module)
####################################################################################
resource "aws_eks_addon" "s3_mountpoint_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-mountpoint-s3-csi-driver"
  service_account_role_arn = module.s3.s3_csi_driver_role_arn
  # Using IRSA for CSI driver, Pod Identity for application pods

  # Ensure this addon is created after the S3 module creates the IAM role and pod identity association
  depends_on = [module.s3]

  tags = {
    Name        = "${var.cluster_name}-s3-mountpoint-csi-driver"
    Environment = var.environment
    Terraform   = "true"
  }
}
*/
####################################################################################
###  Null Resource to update the kubeconfig file
####################################################################################
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}"
  }

  depends_on = [module.eks]
}

