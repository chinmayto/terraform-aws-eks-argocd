####################################################################################
### Route53 Hosted Zone for chinmayto.com (if not exists)
####################################################################################
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

####################################################################################
### ArgoCD Namespace
####################################################################################
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }

  depends_on = [module.eks]
}

####################################################################################
### ArgoCD Helm Release
####################################################################################
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # ArgoCD Server configuration
  set {
    name  = "server.service.type"
    value = var.argocd_server_service_type
  }

  set {
    name  = "server.ingress.enabled"
    value = var.argocd_ingress_enabled
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = var.argocd_ingress_class
  }

  set {
    name  = "server.ingress.hosts[0]"
    value = var.argocd_hostname
  }

  # Configure ingress annotations for NGINX
  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "false"
  }

  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/force-ssl-redirect"
    value = "false"
  }

  set {
    name  = "server.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol"
    value = "HTTP"
  }

  # Enable insecure mode for easier access (disable TLS) - NEW FORMAT
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Configure RBAC - NEW FORMAT
  set {
    name  = "configs.rbac.policy\\.default"
    value = "role:readonly"
  }

  # Configure Redis for high availability (optional)
  set {
    name  = "redis-ha.enabled"
    value = var.argocd_ha_enabled
  }

  # Configure ApplicationSet controller
  set {
    name  = "applicationSet.enabled"
    value = "true"
  }

  # Configure Notifications controller
  set {
    name  = "notifications.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.argocd]
}



####################################################################################
### ArgoCD Admin Password Secret (Optional - for custom password)
####################################################################################
resource "kubernetes_secret" "argocd_admin_password" {
  count = var.argocd_admin_password != "" ? 1 : 0

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-initial-admin-secret"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    password = bcrypt(var.argocd_admin_password)
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.argocd]
}

####################################################################################
### Route53 DNS Record for ArgoCD (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.argocd_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.argocd, data.kubernetes_service.nginx_ingress_controller]
}


