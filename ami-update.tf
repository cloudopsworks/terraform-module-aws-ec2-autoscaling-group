##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

resource "aws_cloudwatch_event_rule" "update_asg" {
  count          = try(var.asg.ami.update_enabled, false) ? 1 : 0
  name           = "${local.name}-asg-upd-rule"
  description    = "Event Rule to trigger AMI update for ASG ${local.name}"
  event_bus_name = data.aws_cloudwatch_event_bus.default.name
  state          = "ENABLED"
  event_pattern = jsonencode({
    source      = "aws.backup"
    detail-type = "Recovery Point State Change"
    detail = {
      status       = ["COMPLETED"]
      resourceType = ["EC2"]
    }
  })
  tags = local.all_tags
}

resource "aws_ssm_document" "update_asg" {
  count         = try(var.asg.ami.update_enabled, false) ? 1 : 0
  name          = "${local.name}-asg-upd-ssm-doc"
  document_type = "Automation"
  content = jsonencode({
    description   = "Update ASG with new AMI"
    schemaVersion = "0.3"
    assumeRole    = "{{ AutomationAssumeRole }}"
    parameters = {
      AutomationAssumeRole = {
        type        = "String"
        description = "The ARN of the role that allows Automation to perform the actions on your behalf."
        default     = ""
      }
      imageId = {
        type        = "String"
        description = "The ID of the AMI to use for the update."
      }
      autoscalingGroupName = {
        type        = "String"
        description = "The ARN of the Auto Scaling group to update."
      }
      launchTemplateId = {
        type        = "String"
        description = "The ID of the Launch Template associated with the ASG."
      }
      tags = {
        type        = "Array"
        description = "Tags array to filter instances in the ASG."
        default     = []
      }
    }
    mainSteps : [
      {
        name           = "updateASG"
        action         = "aws:executeScript"
        timeoutSeconds = 300
        maxAttempts    = 1
        onFailure      = "Abort"
        InputPayload = {
          imageId              = "{{ imageId }}"
          autoscalingGroupName = "{{ autoscalingGroupName }}"
          launchTemplateId     = "{{ launchTemplateId }}"
          tags                 = "{{ tags }}"
        }
        inputs = {
          Runtime = "python3.12"
          Handler = "update_asg"
          Script  = <<-EOF
from __future__ import print_function
import datetime
import json
import time
import boto3

# create auto scaling and ec2 client
asg = boto3.client('autoscaling')
ec2 = boto3.client('ec2')

# function to compare tags
# inputs:
#  required Tags = list of dicts with 'name' as key and 'values' (array) as possible values
#  image_tags = list of dicts with 'Key' and 'Value'
# must match all required_tags match to return True, required_tags['values'] can have multiple values for OR logic applies only on that field
def compare_tags(required_tags, image_tags):
  required_count = len(required_tags)
  matched_count = 0
  for req_tag in required_tags:
    req_name = req_tag['name']
    req_values = req_tag['values']
    for img_tag in image_tags:
      img_key = img_tag['Key']
      img_value = img_tag['Value']
      if req_name == img_key:
        if img_value in req_values:
        matched_count += 1
        break
  return matched_count >= required_count

# Main function
def update_asg(event, context):
  print("Received event: " + json.dumps(event, indent=2))
  image_id = event['imageId']
  asg_name = event['autoscalingGroupName']
  launch_template_id = event['launchTemplateId']
  tags = event['tags']
  print(f"Updating ASG {asg_name} with new AMI {image_id}")
  update_image = ec2.describe_images(ImageIds=[image_id])['Images'][0]
  if compare_tags(tags, update_image.get('Tags', [])):
    print(f"Image details: {json.dumps(update_image)}")
    response = ec2.create_launch_template_version(
      LaunchTemplateId=launch_template_id,
      SourceVersion='$latest',
      LaunchTemplateData={
        'ImageId': image_id,
      }
    )
    new_version_number = response['LaunchTemplateVersion']['VersionNumber']
    autoscaling.update_auto_scaling_group(
      AutoScalingGroupName=auto_scaling_group_name,
      LaunchTemplate={
        'LaunchTemplateId': launch_template_id,
        'Version': str(new_version_number)
      }
    )

    return {
      'statusCode': 200,
      'body': f'ASG updated successfully to use AMI {image_id} with Launch Template version {new_version_number}'
    }
  else:
    print("No matching tags found. Skipping ASG update.")
    return {
      'statusCode': 200,
      'body': 'No matching tags found. ASG update skipped.'
    }
EOF
        }
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "update_asg" {
  count          = try(var.asg.ami.update_enabled, false) ? 1 : 0
  rule           = aws_cloudwatch_event_rule.update_asg[0].name
  event_bus_name = data.aws_cloudwatch_event_bus.default.name
  target_id      = "${local.name}-asg-upd-target"
  arn            = aws_ssm_document.update_asg[0].arn
  role_arn       = aws_iam_role.update_asg[0].arn
  input_transformer {
    input_paths = {
      resourceId = "$.resources[0]"
    }
    input_template = jsonencode({
      imageId              = "<resourceId>"
      autoscalingGroupName = aws_autoscaling_group.this[0].name
      launchTemplateId     = aws_launch_template.this[0].id
      tags                 = try(var.asg.ami.filters, [])
    })
  }

}

### SSM ROLE
data "aws_iam_policy_document" "update_asg_trust" {
  count = try(var.asg.ami.update_enabled, false) ? 1 : 0
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "update_asg" {
  count = try(var.asg.ami.update_enabled, false) ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      aws_ssm_document.update_asg[0].arn
    ]
  }
}

resource "aws_iam_role" "update_asg" {
  count              = try(var.asg.ami.update_enabled, false) ? 1 : 0
  name               = "${local.name}-eventbridge-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.update_asg_trust[0].json
}

resource "aws_iam_role_policy" "update_asg" {
  count  = try(var.asg.ami.update_enabled, false) ? 1 : 0
  name   = "SSMLifecycle"
  role   = aws_iam_role.update_asg[0].id
  policy = data.aws_iam_policy_document.update_asg[0].json
}
