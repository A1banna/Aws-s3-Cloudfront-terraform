terraform {
  backend "s3" {
    bucket       = "albanna-tfstate-489863"
    key          = "portfolio/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
  }
}
provider "aws" {
  region = "eu-central-1"
}

resource "aws_s3_bucket" "this_bucket" {
  bucket = "albanna-portfolio-dec2025-48213" # must be globally unique
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.this_bucket.id
  key          = "index.html"
  source       = "index.html"
  content_type = "text/html"
  etag         = filemd5("index.html")
}

resource "aws_cloudfront_origin_access_control" "this_oac" {
  name                              = "site-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this_distr" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.this_bucket.bucket_regional_domain_name
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.this_oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this_bucket.id
  depends_on = [aws_s3_bucket_public_access_block.this]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.this_bucket.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.this_distr.arn }
      }
    }]
  })
}

output "site_url" {
  value = "https://${aws_cloudfront_distribution.this_distr.domain_name}"
}