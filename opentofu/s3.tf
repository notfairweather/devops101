# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block

# Delare a bucket
resource "aws_s3_bucket" "logeverything_bucket" {
  bucket = "logeverything-site-${var.s3_bucket_suffix}"

  tags = {
    Name        = "Log Everything Bucket"
  }
}


# Allow public access for our website
resource "aws_s3_bucket_ownership_controls" "logeverything_bucket_controls" {
  bucket = aws_s3_bucket.logeverything_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "logeverything_bucket_pubblock" {
  bucket = aws_s3_bucket.logeverything_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "logeverything_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.logeverything_bucket_controls,
    aws_s3_bucket_public_access_block.logeverything_bucket_pubblock,
  ]

  bucket = aws_s3_bucket.logeverything_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_policy" "logeverything_bucket_policy" {
  bucket = aws_s3_bucket.logeverything_bucket.id
  policy = data.aws_iam_policy_document.logeverything_bucket_iam.json
}

data "aws_iam_policy_document" "logeverything_bucket_iam" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      aws_s3_bucket.logeverything_bucket.arn,
      "${aws_s3_bucket.logeverything_bucket.arn}/*",
    ]
  }
}

# Serve our bucket as a website
resource "aws_s3_bucket_website_configuration" "logeverything_website" {
  bucket = aws_s3_bucket.logeverything_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# Upload website files
module "template_files" {
  source = "hashicorp/dir/template"

  base_dir = "./html"
}

resource "aws_s3_object" "logeverything_website_files" {
  # https://registry.terraform.io/modules/hashicorp/dir/template/latest
  for_each = module.template_files.files

  bucket  = aws_s3_bucket.logeverything_bucket.id
  key     = each.key
  content = each.value.content
  source  = each.value.source_path
  content_type = each.value.content_type


  etag = each.value.digests.md5
}


# Output the URL of our website
output "s3_bucket_url" {
  value = "http://${aws_s3_bucket.logeverything_bucket.id}.s3-website-us-east-1.amazonaws.com"
}
