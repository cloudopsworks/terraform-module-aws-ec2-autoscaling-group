##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  iam_role_name = "${local.name}-asg-role"
}

data "aws_iam_policy_document" "assume_role" {
  count = try(var.asg.create, true) && try(var.iam.create, true) ? 1 : 0
  statement {
    sid    = "AllowAssumeRole"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "this" {
  count                 = try(var.asg.create, true) && try(var.iam.create, true) ? 1 : 0
  name                  = local.iam_role_name
  path                  = try(var.iam.path, null)
  description           = try(var.iam.role_description, "IAM Instance Role ${local.name}")
  assume_role_policy    = data.aws_iam_policy_document.assume_role[count.index].json
  permissions_boundary  = try(var.iam.permissions_boundary, null)
  force_detach_policies = true
  tags = merge(local.all_tags, try(var.iam.extra_tags, {}), {
    Name = local.iam_role_name
  })
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {
    for k, v in try(var.iam.role_policies, {}) : k => v if try(var.asg.create, true) && try(var.iam.create, true)
  }
  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

resource "aws_iam_role_policy" "logs" {
  count = try(var.asg.create, true) && try(var.iam.create, true) && try(var.iam.logs_enabled, false) ? 1 : 0
  role  = aws_iam_role.this[0].name
  name  = "CloudWatcjhLogsPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "this" {
  count = try(var.asg.create, true) && try(var.iam.create, true) ? 1 : 0
  role  = aws_iam_role.this[0].name
  name  = local.iam_role_name
  path  = try(var.iam.path, null)
  tags = merge(local.all_tags, try(var.iam.extra_tags, {}), {
    Name = local.iam_role_name
  })
  lifecycle {
    create_before_destroy = true
  }
}


