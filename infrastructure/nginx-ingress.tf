################################################################################
# Create ingress-nginx namespace
################################################################################
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      name = "ingress-nginx"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# Install NGINX Ingress Controller using Helm
################################################################################
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = "4.8.3"

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress_nginx]
}

################################################################################
# Get the NLB hostname from nginx ingress controller
################################################################################
data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
  depends_on = [helm_release.nginx_ingress]
}
