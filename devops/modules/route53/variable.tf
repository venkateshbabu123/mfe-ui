variable "sub_domain_name" {
  type        = string
  description = "Sub domain name"
}

variable "default_tags" {
  type        = map(string)
  description = "Default tags for route53 hosted zone and records"
}

variable "root_domain_zone_id" {
  type        = string
  description = "Root domain hosted zone id for mapping NS records of sub domain to root."
}

variable "ns_record_ttl" {
  type        = number
  description = "NS record TTL"

  validation {
    condition     = (var.ns_record_ttl >= 0 && var.ns_record_ttl <= 172800)
    error_message = "Invalid TTL"
  }
}

variable "cloudfront_domain_name" {
  type        = string
  description = "CloudFront distribution domain name for alias record (e.g., dxxxx.cloudfront.net)"
}

variable "cloudfront_hosted_zone_id" {
  type        = string
  description = "CloudFront distribution hosted zone ID for alias record"
}
