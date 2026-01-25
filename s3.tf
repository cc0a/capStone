resource "aws_s3_bucket" "vpc_logs" {
  bucket = "my-vpc-flow-logs-bucket-123458878"
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc_logs" {
  bucket = aws_s3_bucket.vpc_logs.id

  rule {
    id     = "logs"
    status = "Enabled"

    # Apply to all objects
    filter {
      prefix = ""
    }

    # Multiple transitions must use `transition` blocks (one per transition)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 365
    }
  }
}  
