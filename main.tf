terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# S3 Bucket para el sitio estático
resource "aws_s3_bucket" "angular_app" {
  bucket = "my-angular-app-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Configuración de sitio web estático
resource "aws_s3_bucket_website_configuration" "angular_app" {
  bucket = aws_s3_bucket.angular_app.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Política del bucket para CloudFront
resource "aws_s3_bucket_policy" "angular_app" {
  bucket = aws_s3_bucket.angular_app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.angular_app.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.angular_app.arn
          }
        }
      }
    ]
  })
}

# Origin Access Control para CloudFront
resource "aws_cloudfront_origin_access_control" "angular_app" {
  name                              = "angular-app-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "angular_app" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.angular_app.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.angular_app.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.angular_app.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.angular_app.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Manejo de errores para SPA Angular
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
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

# Outputs
output "cloudfront_url" {
  value       = "https://${aws_cloudfront_distribution.angular_app.domain_name}"
  description = "URL de CloudFront para acceder a tu aplicación Angular"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.angular_app.id
  description = "Nombre del bucket S3 (sube aquí los archivos de tu app Angular)"
}