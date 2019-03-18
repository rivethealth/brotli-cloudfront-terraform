data "archive_file" "lambda" {
  source_dir  = "${path.module}/edge"
  output_path = "${path.module}/edge.zip"
  type        = "zip"
}

resource "aws_iam_role" "edge" {
  name = "${var.prefix}edge"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "edgelambda.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      }
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "edge-lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.edge.id}"
}

resource "aws_lambda_function" "edge" {
  description      = "Detect and adjust for brotli support"
  filename         = "${path.module}/edge.zip"
  function_name    = "${var.prefix}edge"
  handler          = "index.handler"
  publish          = true
  role             = "${aws_iam_role.edge.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  timeout          = 10
}
