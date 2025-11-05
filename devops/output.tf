output "s3_details" {
  description = "S3 bucket details"
  value       = module.s3.course_mfe_s3_bucket_details
}

output "dns_alias_records" {
  description = "Alias A/AAAA records created for the subdomain pointing to CloudFront"
  value       = module.roue53.route53_alias_records
}

output "cloudfront_certificate_details" {
  description = "Cloudfront ACM certificate details"
  value       = module.acm.certificate_details
}
