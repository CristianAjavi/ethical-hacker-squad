terraform {
  required_version = ">= 1.6"
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "reports" {
  bucket = "acme-billing-reports-${var.env}"
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket" "public_site" {
  bucket = "acme-marketing-site-${var.env}"
}

resource "aws_cloudfront_origin_access_identity" "site" {
  comment = "marketing site"
}

resource "aws_s3_bucket_policy" "public_site" {
  bucket = aws_s3_bucket.public_site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_cloudfront_origin_access_identity.site.iam_arn }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.public_site.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy" "worker" {
  name = "worker-inline"
  role = aws_iam_role.worker.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "deployer" {
  name = "deployer-inline"
  role = aws_iam_role.deployer.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject", "s3:GetObject"]
      Resource = "${aws_s3_bucket.reports.arn}/*"
      Condition = { StringEquals = { "aws:ResourceAccount" = var.account_id } }
    }]
  })
}

resource "aws_db_instance" "billing" {
  identifier        = "billing-${var.env}"
  engine            = "postgres"
  instance_class    = "db.t4g.medium"
  allocated_storage = 100
  username          = "billing"
  password          = var.db_password
  storage_encrypted = false
  skip_final_snapshot = true
}

resource "aws_iam_role" "worker" {
  name               = "worker"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role" "deployer" {
  name               = "deployer"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

variable "region" { type = string }
variable "env" { type = string }
variable "account_id" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
