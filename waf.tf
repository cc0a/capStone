resource "aws_wafv2_web_acl" "wp_waf" {
  name        = "wordpress-waf"
  description = "WAF for WordPress"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "wp_waf_assoc" {
  resource_arn = aws_lb.wp_lb.arn   # <-- corrected
  web_acl_arn  = aws_wafv2_web_acl.wp_waf.arn
}
