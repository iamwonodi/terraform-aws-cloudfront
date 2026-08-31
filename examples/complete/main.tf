################################################################################
# CLOUDFRONT - COMPLETE EXAMPLE
################################################################################

module "cloudfront" {
  source = "../../"

  project_name = var.project_name
  environment  = var.environment
  comment      = var.comment

  # ---------------------------------------------------------------------------
  # Two independent origins demonstrate the primary reason for supporting
  # multiple CloudFront origins: static, Media & Error content can use S3 while application
  # traffic is routed to an ALB/custom HTTP origin.
  # ---------------------------------------------------------------------------
  origins = {
    s3 = {
      domain_name = var.s3_origin_domain_name
      origin_type = "s3"

      origin_access_control_id = var.s3_origin_access_control_id

      s3_origin_config = {}
    }

    application = {
      domain_name = var.application_origin_domain_name
      origin_type = "custom"

      custom_origin_config = {
        http_port                = 80
        https_port               = 443
        origin_protocol_policy   = "https-only"
        origin_ssl_protocols     = ["TLSv1.2"]
        origin_read_timeout      = 30
        origin_keepalive_timeout = 5
      }
    }
  }

  # The application origin handles everything that does not match an ordered
  # behavior.
  default_cache_behavior = {
    target_origin_id = "application"
  }

  # Static, Media & Error content is routed independently to S3.
  ordered_cache_behaviors = [
    {
      path_pattern     = "/static/*"
      target_origin_id = "s3"
    },
    {
      path_pattern     = "/media/*"
      target_origin_id = "s3"
    },
    {
      path_pattern     = "/errors/*"
      target_origin_id = "s3"
    },
  ]


  #################################################################################
  # CUSTOM ERROR RESPONSES
  #################################################################################

  custom_error_responses = [
    {
      error_code            = 404
      response_code         = 404
      response_page_path    = "/errors/404.html"
      error_caching_min_ttl = 60
    },
    {
      error_code            = 500
      response_code         = 500
      response_page_path    = "/errors/500.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 502
      response_code         = 502
      response_page_path    = "/errors/502.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 503
      response_code         = 503
      response_page_path    = "/errors/503.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 504
      response_code         = 504
      response_page_path    = "/errors/504.html"
      error_caching_min_ttl = 10
    }
  ]

  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2"
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  aliases             = var.aliases
  acm_certificate_arn = var.acm_certificate_arn

  ################################################################################
  # STANDARD LOGGING V2
  ################################################################################

  logging = {
    enabled = true

    source_name = "my-cloudfront-access-logs-source"

    destination_type = "s3"
    destination_arn  = var.logging_destination_arn
    destination_name = "my-cloudfront-access-logs-destination"

    region = "us-east-1"

    output_format = "json"

    field_delimiter = ","

    record_fields = [
      "date",
      "time",
      "x-edge-location",
      "sc-bytes",
      "c-ip",
      "cs-method",
      "cs(Host)",
      "cs-uri-stem",
      "sc-status",
      "cs(Referer)",
      "cs(User-Agent)",
      "cs-uri-query",
      "cs(Cookie)",
      "x-edge-result-type",
      "x-edge-request-id",
      "x-host-header",
      "cs-protocol",
      "cs-bytes",
      "time-taken"
    ]

    s3 = {
      suffix_path = "/cloudfront/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
    }
  }

  web_acl_id = var.web_acl_id

  tags = var.tags
}