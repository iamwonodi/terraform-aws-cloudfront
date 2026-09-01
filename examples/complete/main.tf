################################################################################
# TERRAFORM AWS CLOUDFRONT MODULE
#
# Complete example demonstrating:
#   - Multiple CloudFront origins
#   - Private S3 origin
#   - Automatically created CloudFront Origin Access Control (OAC)
#   - Application Load Balancer custom origin
#   - /static/* routing to S3
#   - /media/* routing to S3
#   - /errors/* routing to S3
#   - Default application routing to ALB
#   - CloudFront custom error responses
#   - HTTPS/custom domain configuration
#   - AWS WAF integration
#   - CloudFront Standard Logging v2
#
# This example intentionally consumes externally managed infrastructure.
# The S3 bucket, ALB, ACM certificate, WAF Web ACL, and logging destination
# are expected to exist outside this example.
################################################################################




################################################################################
# CLOUDFRONT DISTRIBUTION
################################################################################

module "cloudfront" {
  source = "../../"

  ##############################################################################
  # GENERAL CONFIGURATION
  ##############################################################################

  project_name = var.project_name
  environment  = var.environment

  comment = var.comment

  enabled         = true
  is_ipv6_enabled = true

  http_version = "http2"

  price_class = "PriceClass_100"

  default_root_object = null


  ##############################################################################
  # CUSTOM DOMAIN / HTTPS
  ##############################################################################

  aliases = var.aliases

  # CloudFront ACM certificates must be provisioned in us-east-1.
  acm_certificate_arn = var.acm_certificate_arn

  minimum_protocol_version = "TLSv1.2_2021"


  ##############################################################################
  # AUTOMATIC S3 ORIGIN ACCESS CONTROL
  ##############################################################################

  # The module automatically creates one CloudFront Origin Access Control
  # whenever at least one S3 origin exists.
  #
  # The generated OAC is automatically attached to every S3 origin.
  #
  # The caller therefore does NOT need to provide:
  #
  #   origin_access_control_id
  #
  # and should NOT configure an Origin Access Identity when automatic OAC
  # creation is enabled.
  create_s3_origin_access_control = true


  ##############################################################################
  # ORIGINS
  ##############################################################################

  origins = {

    ##########################################################################
    # PRIVATE S3 ORIGIN
    ##########################################################################
    #
    # This origin contains:
    #
    #   static/*
    #   media/*
    #   errors/*
    #
    # The bucket remains private and CloudFront accesses it through OAC.
    #
    static = {
      domain_name = var.s3_origin_domain_name
      origin_type = "s3"

      # OAC is automatically attached by the module.
      s3_origin_config = {}
    }


    ##########################################################################
    # APPLICATION LOAD BALANCER ORIGIN
    ##########################################################################
    #
    # All requests that do not match an ordered cache behavior are sent here.
    #
    application = {
      domain_name = var.application_origin_domain_name
      origin_type = "custom"

      custom_origin_config = {
        http_port  = 80
        https_port = 443

        # Encrypt traffic between CloudFront and the ALB.
        origin_protocol_policy = "https-only"

        origin_ssl_protocols = [
          "TLSv1.2"
        ]

        origin_read_timeout      = 30
        origin_keepalive_timeout = 5
      }
    }
  }


  ##############################################################################
  # DEFAULT CACHE BEHAVIOR
  ##############################################################################
  #
  # The default behavior is the application path.
  #
  # Therefore:
  #
  #   /                     -> ALB
  #   /login/               -> ALB
  #   /api/users            -> ALB
  #   /dashboard/           -> ALB
  #   /anything-else        -> ALB
  #
  # Specialized paths are handled by ordered cache behaviors below.
  #
  default_cache_behavior = {
    target_origin_id       = "application"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
      "PUT",
      "POST",
      "PATCH",
      "DELETE"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host_header.id

    response_headers_policy_id = null

    compress = true
  }


  ##############################################################################
  # ORDERED CACHE BEHAVIORS
  ##############################################################################
  #
  # CloudFront evaluates these paths before the default behavior.
  #
  # Routing:
  #
  #   /static/* -> S3
  #   /media/*  -> S3
  #   /errors/* -> S3
  #   /*        -> ALB
  #
  ordered_cache_behaviors = [

    ##########################################################################
    # STATIC ASSETS
    ##########################################################################

    {
      path_pattern           = "/static/*"
      target_origin_id       = "s3"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = [
        "GET",
        "HEAD",
        "OPTIONS"
      ]

      cached_methods = [
        "GET",
        "HEAD"
      ]

      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id   = null
      response_headers_policy_id = null

      compress = true
    },


    ##########################################################################
    # MEDIA ASSETS
    ##########################################################################

    {
      path_pattern           = "/media/*"
      target_origin_id       = "s3"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = [
        "GET",
        "HEAD",
        "OPTIONS"
      ]

      cached_methods = [
        "GET",
        "HEAD"
      ]

      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id   = null
      response_headers_policy_id = null

      compress = true
    },


    ##########################################################################
    # CUSTOM ERROR PAGES
    ##########################################################################
    #
    # Custom error responses below reference /errors/*.html.
    #
    # Because the error pages live in the S3 origin, CloudFront needs an
    # appropriate cache behavior capable of retrieving them.
    #
    {
      path_pattern           = "/errors/*"
      target_origin_id       = "s3"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = [
        "GET",
        "HEAD",
        "OPTIONS"
      ]

      cached_methods = [
        "GET",
        "HEAD"
      ]

      cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
      origin_request_policy_id   = null
      response_headers_policy_id = null

      compress = true
    }
  ]


  ##############################################################################
  # CUSTOM ERROR RESPONSES
  ##############################################################################
  #
  # When the application origin returns one of these status codes, CloudFront
  # retrieves the corresponding error page from the S3 origin.
  #
  # Example:
  #
  #   ALB -> 404
  #        -> CloudFront
  #        -> S3 /errors/404.html
  #        -> Viewer
  #
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


  ##############################################################################
  # ORIGIN GROUPS
  ##############################################################################
  #
  # Disabled in this example.
  #
  # Origin groups are intentionally demonstrated separately from custom error
  # responses because they solve a different problem:
  #
  #   Custom error response -> viewer-facing error page
  #   Origin group          -> origin failover
  #
  origin_groups = {}


  ##############################################################################
  # AWS WAF
  ##############################################################################

  # The WAF Web ACL is externally managed.
  #
  # Set web_acl_id = null when WAF integration is not required.
  web_acl_id = var.web_acl_id


  ##############################################################################
  # STANDARD LOGGING V2
  ##############################################################################
  #
  # The logging destination is externally managed.
  #
  # The module creates:
  #
  #   - CloudWatch Log Delivery Source
  #   - CloudWatch Log Delivery Destination
  #   - CloudWatch Log Delivery
  #
  logging = {
    enabled = var.logging_enabled

    source_name      = var.logging_source_name
    destination_name = var.logging_destination_name

    destination_type = var.logging_destination_type
    destination_arn  = var.logging_destination_arn

    region = var.logging_region

    output_format   = "json"
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
      "time-taken"
    ]

    s3 = {
      suffix_path = "/cloudfront/{DistributionId}/{yyyy}/{MM}/{dd}/{HH}"
    }
  }


  ##############################################################################
  # TAGS
  ##############################################################################

  tags = var.tags
}




################################################################################
# S3 BUCKET POLICY RESOURCE
################################################################################

resource "aws_s3_bucket_policy" "cloudfront" {
  bucket = var.s3_bucket_id
  policy = data.aws_iam_policy_document.cloudfront_s3.json

  depends_on = [
    module.cloudfront
  ]
}