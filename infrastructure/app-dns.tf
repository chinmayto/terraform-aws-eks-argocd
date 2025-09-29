####################################################################################
### Route53 DNS Record for Node.js App (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "nodejs_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.app_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}

####################################################################################
### Local values for NLB hosted zone IDs by region
####################################################################################
locals {
  # AWS NLB hosted zone IDs by region
  nlb_hosted_zone_ids = {
    "us-east-1"      = "Z35SXDOTRQ7X7K"
    "us-east-2"      = "ZLMOA37VPKANP"
    "us-west-1"      = "Z368ELLRRE2KJ0"
    "us-west-2"      = "Z1H1FL5HABSF5"
    "eu-west-1"      = "Z32O12XQLNTSW2"
    "eu-central-1"   = "Z3F0SRJ5LGBH90"
    "ap-southeast-1" = "ZKVM4W9LS7TM"
    "ap-northeast-1" = "Z31USIVHYNEOWT"
  }

  nlb_hosted_zone_id = local.nlb_hosted_zone_ids[var.aws_region]
}
