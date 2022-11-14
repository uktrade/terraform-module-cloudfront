locals {

  defaults = {
    enabled = try( var.defaults.enabled, true )
    is_ipv6_enabled = try( var.defaults.is_ipv6_enabled, true )
    aliases = try( var.defaults.aliases, null )
    web_acl_id = try( var.defaults.web_acl_id, null )
    origin = {
      connection_attempts = try( var.defaults.origin.connection_attempts, null )
      connection_timeout = try( var.defaults.origin.connection_timeout, null )
      custom_origin_config = try( var.defaults.origin.custom_origin_config, [] ) # Sub-map defaults set in-line
      custom_header = try( var.defaults.origin.custom_header, [] ) # Sub-map defaults set in-line
    }
    geo_restriction = {
      restriction_type = try( var.defaults.geo_restriction.restriction_type, "none" )
      locations = try( var.defaults.geo_restriction.locations, [] )
    }
    viewer_certificate = {
      acm_certificate_arn = try( var.defaults.viewer_certificate.acm_certificate_arn, null )
      iam_certificate_id = try( var.defaults.viewer_certificate.iam_certificate_id, null )
      minimum_protocol_version = try( var.defaults.viewer_certificate.minimum_protocol_version, "TLSv1" )
      ssl_support_method = try( var.defaults.viewer_certificate.ssl_support_method, null )
    }
    default_cache_behavior = {
      allowed_methods  = try( var.defaults.default_cache_behavior.allowed_methods, ["GET", "HEAD", "DELETE", "POST", "OPTIONS", "PUT", "PATCH"] )
      cached_methods   = try( var.defaults.default_cache_behavior.cached_methods, ["GET", "HEAD"] )
      viewer_protocol_policy = try( var.defaults.default_cache_behavior.viewer_protocol_policy, "allow-all" )
      compress = try( var.defaults.default_cache_behavior.compress, true )
      min_ttl = try( var.defaults.default_cache_behavior.min_ttl, 0 )
      default_ttl = try( var.defaults.default_cache_behavior.default_ttl, 86400 )
      max_ttl = try( var.defaults.default_cache_behavior.max_ttl, 31536000 )
      cache_policy_id = try( var.defaults.default_cache_behavior.cache_policy_id, null )
      field_level_encryption_id = try( var.defaults.default_cache_behavior.field_level_encryption_id, null )
      forwarded_values = {
        query_string = try( var.defaults.default_cache_behavior.forwarded_values.query_string, true )
        query_string_cache_keys = try( var.defaults.default_cache_behavior.forwarded_values.query_string_cache_keys, [] )
        headers = try( var.defaults.default_cache_behavior.forwarded_values.headers, [] )
        cookies = {
          forward = try( var.defaults.default_cache_behavior.forwarded_values.cookies.forward, "all" )
          whitelisted_names = try( var.defaults.default_cache_behavior.forwarded_values.cookies.whitelisted_names, null )
        }
      }
    }
    logging_config = try ( var.defaults.logging_config, [] ) # Sub-map defaults set in-line
    origin_group = try ( var.defaults.origin_group, [] ) # Sub-map defaults set in-line
  }

  tags = merge(
    { "Terraform_source_repo" = "terraform-module-cloudfront" },
    var.tags
  )

}


resource "aws_cloudfront_distribution" "standard" {

  enabled = try( var.args.enabled, local.defaults.enabled )
  is_ipv6_enabled = try( var.args.is_ipv6_enabled, local.defaults.is_ipv6_enabled )
  aliases = try( var.args.aliases, local.defaults.aliases )
  web_acl_id = try( var.args.web_acl_id, local.defaults.web_acl_id )

  dynamic "origin" { # There must be at least one origin.
    for_each = var.args.origin
    content {
      domain_name = origin.value.domain_name
      origin_id = try( # If no ID is specified, use the domain name as the ID. No defaults here.
        origin.value.origin_id,
        origin.value.domain_name
      ) 
      connection_attempts = try( origin.value.connection_attempts, local.defaults.origin.connection_attempts )
      connection_timeout = try( origin.value.connection_timeout, local.defaults.origin.connection_timeout )
      dynamic "custom_header" { 
        for_each = can( origin.value.custom_header ) ? origin.value.custom_header : local.defaults.origin.custom_header
        content {
          name = custom_header.value.name
          value = custom_header.value.value
        }
      }
      dynamic "custom_origin_config" {
        for_each = can( origin.value.custom_origin_config ) ? origin.value.custom_origin_config : local.defaults.origin.custom_origin_config
        content {
          http_port = try(
            custom_origin_config.value.http_port,
            local.defaults.origin.custom_origin_config.http_port,
            80
          )
          https_port = try(
            custom_origin_config.value.https_port,
            local.defaults.origin.custom_origin_config.https_port,
            443
          )
          origin_protocol_policy = try(
            custom_origin_config.value.origin_protocol_policy,
            local.defaults.origin.custom_origin_config.origin_protocol_policy,
            "https-only"
          )
          origin_ssl_protocols = try(
            custom_origin_config.value.origin_ssl_protocols,
            local.defaults.origin.custom_origin_config.origin_ssl_protocols,
            ["TLSv1","TLSv1.1","TLSv1.2"]
          )
          origin_keepalive_timeout = try(
            custom_origin_config.value.origin_keepalive_timeout,
            local.defaults.origin.custom_origin_config.origin_keepalive_timeout,
            null
          )
          origin_read_timeout = try(
            custom_origin_config.value.origin_read_timeout,
            local.defaults.origin.custom_origin_config.origin_read_timeout,
            null
          )
        }
      }
    }
  }

  default_cache_behavior {
    target_origin_id = try(
      var.args.default_cache_behavior.target_origin_id,
      var.args.origin[0].origin_id,
      var.args.origin[0].domain_name
    )
    allowed_methods = try( var.args.default_cache_behavior.allowed_methods, local.defaults.default_cache_behavior.allowed_methods )
    cached_methods = try( var.args.default_cache_behavior.cached_methods, local.defaults.default_cache_behavior.cached_methods )
    cache_policy_id = try( var.args.default_cache_behavior.cache_policy_id, local.defaults.default_cache_behavior.cache_policy_id )
    compress = try( var.args.default_cache_behavior.compress, local.defaults.default_cache_behavior.compress )
    default_ttl = try( var.args.default_cache_behavior.default_ttl, local.defaults.default_cache_behavior.default_ttl )
    field_level_encryption_id = try( var.args.default_cache_behavior.field_level_encryption_id, local.defaults.default_cache_behavior.field_level_encryption_id )
    max_ttl = try( var.args.default_cache_behavior.max_ttl, local.defaults.default_cache_behavior.max_ttl )
    min_ttl = try( var.args.default_cache_behavior.min_ttl, local.defaults.default_cache_behavior.min_ttl )
    viewer_protocol_policy = try( var.args.default_cache_behavior.viewer_protocol_policy, local.defaults.default_cache_behavior.viewer_protocol_policy )

    forwarded_values {
      query_string = try(
        var.args.default_cache_behavior.forwarded_values.query_string,
        local.defaults.default_cache_behavior.forwarded_values.query_string
      )
      query_string_cache_keys = try(
        var.args.default_cache_behavior.forwarded_values.query_string_cache_keys,
        local.defaults.default_cache_behavior.forwarded_values.query_string_cache_keys
      )
      headers = try(
        var.args.default_cache_behavior.forwarded_values.headers,
        local.defaults.default_cache_behavior.forwarded_values.headers
      )
      cookies {
        forward = try(
          var.args.default_cache_behavior.forwarded_values.cookies.forward,
          local.defaults.default_cache_behavior.forwarded_values.cookies.forward
        )
        whitelisted_names = try(
          var.args.default_cache_behavior.forwarded_values.cookies.whitelisted_names,
          local.defaults.default_cache_behavior.forwarded_values.cookies.whitelisted_names
        )
      }
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = try(
      var.args.viewer_certificate.cloudfront_default_certificate, # Can specify the default cert here...
      can( var.args.viewer_certificate.acm_certificate_arn ) ? false : true # ...otherwise set to false if an arn is provided, true otherwise.
    )
    acm_certificate_arn = try( var.args.viewer_certificate.acm_certificate_arn, local.defaults.viewer_certificate.acm_certificate_arn )
    iam_certificate_id = try( var.args.viewer_certificate.iam_certificate_id, local.defaults.viewer_certificate.iam_certificate_id )
    minimum_protocol_version = try( var.args.viewer_certificate.minimum_protocol_version, local.defaults.viewer_certificate.minimum_protocol_version )
    ssl_support_method = try( var.args.viewer_certificate.ssl_support_method, local.defaults.viewer_certificate.ssl_support_method )
  }

  restrictions {
    geo_restriction {
      restriction_type = try( var.args.geo_restriction.restriction_type, local.defaults.geo_restriction.restriction_type )
      locations = try( var.args.geo_restriction.locations, local.defaults.geo_restriction.locations )
    }
  }

  dynamic "logging_config" {
    for_each = can( var.args.logging_config ) ? var.args.logging_config : local.defaults.logging_config
    content {
      bucket = try(
        logging_config.value.bucket,
        local.defaults.logging_config[0].bucket
      )
      include_cookies = try(
        logging_config.value.include_cookies,
        local.defaults.logging_config[0].include_cookies,
        false
      )
      prefix = try(
        logging_config.value.prefix,
        local.defaults.logging_config[0].prefix,
        null
      )
    }
  }

  dynamic "origin_group" {
    for_each = can( var.args.origin_group ) ? var.args.origin_group : local.defaults.origin_group
    content {
      origin_id = origin_group.value.origin_id
      failover_criteria {
        status_codes = try(
          origin_group.value.failover_criteria.status_codes,
          local.defaults.origin_group[0].failover_criteria.status_codes,
          [500]
        )
      }
      dynamic "member" {
        for_each = origin_group.value.member
        content {
          origin_id = member.value.origin_id
        }
      }
    }
  }

  tags = local.tags

}
