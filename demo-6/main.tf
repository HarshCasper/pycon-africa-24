resource "aws_s3_bucket" "original_images" {
  bucket = "original-images"

  force_destroy = true

  tags = {
    Name = "Original Images Bucket"
  }
}

resource "aws_s3_bucket" "resized_images" {
  bucket = "resized-images"

  force_destroy = true

  tags = {
    Name = "Resized Images Bucket"
  }
}

resource "aws_dynamodb_table" "image_metadata" {
  name           = "ImageMetaData"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "ImageID"

  attribute {
    name = "ImageID"
    type = "S"
  }

  tags = {
    Name = "Image MetaData Table"
  }
}

resource "aws_sns_topic" "failed_resize_topic" {
  name = "failed-resize-topic"
}

resource "aws_ses_email_identity" "verified_email" {
  email = "my-email@example.com"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.failed_resize_topic.arn
  protocol  = "email"
  endpoint  = "my-email@example.com"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda_policy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:*"
        ],
        "Resource": "arn:aws:logs:*:*:*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        "Resource": [
          "${aws_s3_bucket.original_images.arn}/*",
          "${aws_s3_bucket.resized_images.arn}/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:PutItem"
        ],
        "Resource": "${aws_dynamodb_table.image_metadata.arn}"
      },
      {
        "Effect": "Allow",
        "Action": [
          "sns:Publish"
        ],
        "Resource": "${aws_sns_topic.failed_resize_topic.arn}"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "image_resizer" {
  filename         = "lambda.zip"
  function_name    = "ImageResizerFunction"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  role             = aws_iam_role.lambda_role.arn
  timeout          = 60

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.image_metadata.name
      SNS_TOPIC_ARN  = aws_sns_topic.failed_resize_topic.arn
    }
  }

  dead_letter_config {
    target_arn = aws_sns_topic.failed_resize_topic.arn
  }

  depends_on = [aws_iam_role_policy.lambda_policy]
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_resizer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.original_images.arn
}

resource "aws_s3_bucket_notification" "original_images_notification" {
  bucket = aws_s3_bucket.original_images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_resizer.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}
