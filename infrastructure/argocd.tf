####################################################################################
### Route53 Hosted Zone
####################################################################################
data "aws_route53_zone" "kubevpro.mlbinfo.net" {
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

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = [var.argocd_hostname]
          annotations = {
            "nginx.ingress.kubernetes.io/ssl-redirect"       = "false"
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
          }
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

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
  }

  data = {
    password = bcrypt(var.argocd_admin_password)
  }

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


