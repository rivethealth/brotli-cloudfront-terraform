# brotli-cloudfront-terraform

Support [brotli](https://github.com/google/brotli)
compression in Cloudfront.

* [Usage](#usage)
  * [Inputs](#inputs)
  * [Outputs](#outputs)
  * [Setup](#setup)
* [Examples](#examples)
  * [Fallback](#fallback)


## Usage

### Inputs

| Name | Type | Description | Default |
|------|:----:|-------------|:-------:|
| prefix | string | Namespace for AWS items | "" |

### Outputs

| Name | Type | Description |
|------|:----:|-------------|
| lambda_arn | string | Qualified ARN of Lambda function |

### Setup 

1. Establish service-linked roles

```hcl
resource "aws_iam_service_linked_role" "lambda-replicator" {
  aws_service_name = "replicator.lambda.amazonaws.com"
}
```

and if logging is desired

```hcl
resource "aws_iam_service_linked_role" "cloudfront-logger" {
  aws_service_name = "logger.cloudfront.amazonaws.com"
}
```

2. Install the module

```hcl
module "brotli-cloudfront" {
  source = "github.com/rivethealth/brotli-cloudfront-terraform" # ?ref=<commit>
  # ...
}
```

3.  Forward the "Accept-Encoding" header and add the lambda function as an "origin-request"
handler.

``` hcl
forwarded_values {
  headers = ["Accept-Encoding"]
  # ...
}

lambda_function_association {
  event_type = "origin-request"
  lambda_arn = "..."
}
```

4. Upload brotli-compressed objects in the origin S3 bucket, with the ".br"
suffix and Content-Encoding
"br".

### Additional

A custom origin header "X-Check-Brotli: false" prevents the request from being
modified.

## Examples

### Fallback

This uses an
[Origin Group](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/high_availability_origin_failover.html)
to gracefully fallback if there is no ".br"-suffixed object.

```hcl
module "brotli_cloudfront" {
  source = "../../../brotli-cloudfront-terraform"
  prefix = "brotli-cloudfront-"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    target_origin_id       = "web"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers      = ["Accept-Encoding"]
      query_string = false

      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type = "origin-request"
      lambda_arn = "${module.brotli_cloudfront.lambda_arn}"
    }
  }

  origin {
    domain_name = "example.s3.amazonaws.com"
    origin_id   = "br"
  }

  origin {
    domain_name = "example.s3.amazonaws.com"
    origin_id   = "raw"

    # prevents request modification
    custom_header {
      name  = "X-Check-Brotli"
      value = "false"
    }
  }

  origin_group {
    origin_id = "web"

    failover_criteria {
      status_codes = [404]
    }

    member {
      origin_id = "br"
    }

    member {
      origin_id = "raw"
    }
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
```
