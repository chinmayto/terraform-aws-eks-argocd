####################################################################################
### Route53 DNS Record for Node.js App (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "nodejs_app" {
  zone_id = data.aws_route53_zone.devcloudproject_com.zone_id
  name    = var.app_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}
