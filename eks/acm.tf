resource "aws_acm_certificate" "default" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  validation_method         = "DNS"
  key_algorithm             = "EC_prime256v1"
  lifecycle {
    create_before_destroy = true
  }
}
