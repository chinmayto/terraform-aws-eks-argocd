variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "CT-EKS-Cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}



####################################################################################
### ArgoCD Variables
####################################################################################
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}



variable "argocd_hostname" {
  description = "Hostname for ArgoCD ingress"
  type        = string
  default     = "argocd.chinmayto.com"
}



variable "argocd_admin_password" {
  description = "Custom admin password for ArgoCD (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

####################################################################################
### DNS Variables
####################################################################################
variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
  default     = "chinmayto.com"
}

variable "argocd_subdomain" {
  description = "Subdomain for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "app_subdomain" {
  description = "Subdomain for Node.js application"
  type        = string
  default     = "app"
}
