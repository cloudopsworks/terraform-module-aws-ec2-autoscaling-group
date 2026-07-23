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
  iam_role_name              = "${local.name}-asg-role"
  iam_role_policy_input      = try(var.iam.role_policies, null)
  iam_role_policy_normalized = local.iam_role_policy_input == null ? {} : local.iam_role_policy_input
  iam_role_policies = can(tomap(local.iam_role_policy_normalized)) ? tomap(local.iam_role_policy_normalized) : {
    for index, policy_arn in local.iam_role_policy_normalized : tostring(index) => policy_arn
  }
  iam_role_policy_names = keys(local.iam_role_policies)
  iam_role_policy_arns  = values(local.iam_role_policies)
  cloudwatch_agent_policies = {
    CloudWatchAgentServerPolicy  = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
    AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  cloudwatch_agent_role_policies = {
    for name, arn in local.cloudwatch_agent_policies : name => arn
    if(
      (name == "CloudWatchAgentServerPolicy" && local.cloudwatch_agent_enabled) ||
      (name == "AmazonSSMManagedInstanceCore" && (local.cloudwatch_agent_install_enabled || local.cloudwatch_agent_configure_enabled))
    ) && !contains(local.iam_role_policy_names, name) && !contains(local.iam_role_policy_arns, arn)
  }
  effective_iam_role_policies = merge(local.iam_role_policies, local.cloudwatch_agent_role_policies)
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

data "aws_iam_policy_document" "policy" {
  count = try(var.asg.create, true) && try(var.iam.create, true) && length(try(var.iam.policies, [])) > 0 ? length(try(var.iam.policies, [])) : 0
  dynamic "statement" {
    for_each = try(var.iam.policies[count.index].statements, [])
    content {
      sid       = try(statement.value.sid, null)
      effect    = try(statement.value.effect, null)
      actions   = try(statement.value.actions, [])
      resources = try(statement.value.resources, [])
      dynamic "principals" {
        for_each = try(statement.value.principals, null) != null ? [statement.value.principals] : []
        content {
          type        = try(principals.value.type, null)
          identifiers = try(principals.value.identifiers, [])
        }
      }
      dynamic "condition" {
        for_each = try(statement.value.conditions, [])
        content {
          test     = try(condition.value.test, null)
          variable = try(condition.value.variable, null)
          values   = try(condition.value.values, [])
        }
      }
    }
  }
}

resource "aws_iam_role_policy" "policy" {
  count  = try(var.asg.create, true) && try(var.iam.create, true) && length(try(var.iam.policies, [])) > 0 ? length(try(var.iam.policies, [])) : 0
  role   = aws_iam_role.this[0].id
  name   = var.iam.policies[count.index].name
  policy = data.aws_iam_policy_document.policy[count.index].json
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = {
    for k, v in local.effective_iam_role_policies : k => v if try(var.asg.create, true) && try(var.iam.create, true)
  }
  policy_arn = each.value
  role       = aws_iam_role.this[0].name
}

data "aws_iam_policy_document" "cloudwatch_agent_parameter" {
  count = try(var.asg.create, true) && try(var.iam.create, true) && local.cloudwatch_agent_configure_enabled ? 1 : 0

  statement {
    sid    = "AllowCloudWatchAgentConfigParameterRead"
    effect = "Allow"
    actions = [
      "ssm:GetParameter"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(local.cloudwatch_agent_config_parameter_name, "/")}"
    ]
  }
}

resource "aws_iam_role_policy" "cloudwatch_agent_parameter" {
  count = try(var.asg.create, true) && try(var.iam.create, true) && local.cloudwatch_agent_configure_enabled ? 1 : 0

  role   = aws_iam_role.this[0].name
  name   = "CloudWatchAgentParameterReadPolicy"
  policy = data.aws_iam_policy_document.cloudwatch_agent_parameter[count.index].json
}

resource "aws_iam_role_policy" "logs" {
  count = try(var.asg.create, true) && try(var.iam.create, true) && try(var.iam.logs_enabled, false) ? 1 : 0
  role  = aws_iam_role.this[0].name
  name  = "CloudWatchDeliverLogsPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:PutLogEventsBatch",
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
