output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = module.eks.cluster_iam_role_name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

################################################################################
# ArgoCD Outputs
################################################################################
output "argocd_service_info" {
  description = "ArgoCD service information"
  value = {
    namespace    = kubernetes_namespace.argocd.metadata[0].name
    service_name = "argocd-server"
    service_type = "ClusterIP"
  }
}

output "argocd_access_commands" {
  description = "Commands to access ArgoCD"
  value = {
    dns_url              = "https://${var.argocd_subdomain}.${var.domain_name}"
    port_forward_command = "kubectl port-forward -n ${var.argocd_namespace} svc/argocd-server 8080:443"
    get_admin_password   = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    get_loadbalancer_url = "N/A - Service type is ClusterIP"
    web_ui_url           = "https://${var.argocd_subdomain}.${var.domain_name}"
    username             = "admin"
    dns_record_status    = "kubectl get route53record argocd -o wide"
  }
}

output "argocd_dns_info" {
  description = "ArgoCD DNS configuration information"
  value = {
    domain_name     = var.domain_name
    subdomain       = var.argocd_subdomain
    full_hostname   = "${var.argocd_subdomain}.${var.domain_name}"
    hosted_zone_id  = data.aws_route53_zone.devcloudproject_com.zone_id
    dns_record_type = "A (Alias to LoadBalancer)"
  }
}

################################################################################
# Node.js App DNS Outputs
################################################################################
output "nodejs_app_dns_info" {
  description = "Node.js application DNS configuration information"
  value = {
    domain_name     = var.domain_name
    subdomain       = var.app_subdomain
    full_hostname   = "${var.app_subdomain}.${var.domain_name}"
    app_url         = "http://${var.app_subdomain}.${var.domain_name}"
    hosted_zone_id  = data.aws_route53_zone.devcloudproject_com.zone_id
    dns_record_type = "A (Alias to NGINX Ingress NLB)"
  }
}
