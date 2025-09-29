/*
################################################################################
# Create Route53 A records for Prometheus and Grafana
################################################################################
resource "aws_route53_record" "prometheus" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "prometheus.chinmayto.com"
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana.chinmayto.com"
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}

################################################################################
# Create monitoring namespace
################################################################################
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# Install Prometheus using Helm (after nginx ingress)
################################################################################
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "55.5.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"
        }
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["prometheus.chinmayto.com"]
          paths            = ["/"]
          annotations = {
            "nginx.ingress.kubernetes.io/rewrite-target" = "/"
          }
        }
      }
      grafana = {
        enabled       = true
        adminPassword = "admin123"
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["grafana.chinmayto.com"]
          path             = "/"
          annotations = {
            "nginx.ingress.kubernetes.io/rewrite-target" = "/"
          }
        }
        persistence = {
          enabled = false
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring, helm_release.nginx_ingress]
}
*/
