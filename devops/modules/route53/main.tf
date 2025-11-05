#resource "aws_route53_zone" "skillsync" {
#  name = var.sub_domain_name
#  tags = merge(
#    var.default_tags
#  )
#}

resource "aws_route53_record" "cf_alias_a" {
  zone_id = var.root_domain_zone_id
  name    = var.sub_domain_name
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# resource "aws_route53_record" "cf_alias_aaaa" {
#   zone_id = var.root_domain_zone_id
#   name    = var.sub_domain_name
#   type    = "AAAA"

#   alias {
#     name                   = var.cloudfront_domain_name
#     zone_id                = var.cloudfront_hosted_zone_id
#     evaluate_target_health = false
#   }
# }
