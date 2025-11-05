output "route53_alias_records" {
  description = "Alias records created for CloudFront in the existing hosted zone"
  value = {
    name        = aws_route53_record.cf_alias_a.name
    zone_id     = var.root_domain_zone_id
    a_fqdn      = aws_route53_record.cf_alias_a.fqdn
    target      = var.cloudfront_domain_name
    target_zone = var.cloudfront_hosted_zone_id
  }
}
