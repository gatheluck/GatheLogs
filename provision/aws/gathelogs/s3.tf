resource "aws_s3_bucket" "gathelogs" {
    bucket = "gathelogs"

    acl = "private"
    force_destroy = true

    website {
        index_document = "index.html"
        error_document = "error.html"
    } 
}

resource "aws_s3_bucket_policy" "gathelogs" {
    bucket = aws_s3_bucket.gathelogs.id
    policy = data.aws_iam_policy_document.gathelogs.json
}

data "aws_iam_policy_document" "gathelogs" {
    statement {
        sid = "Allow CloudFront"
        effect = "Allow"
        principals {
            type = "AWS"
            identifiers = [aws_cloudfront_origin_access_identity.gathelogs.iam_arn]
        }
        actions = [
            "s3:GetObject"
        ]

        resources = [
            "${aws_s3_bucket.gathelogs.arn}/*"
        ]
    }
}