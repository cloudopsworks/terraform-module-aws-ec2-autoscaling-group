##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  cloudwatch_agent_settings                    = try(var.asg.cloudwatch_agent, {})
  cloudwatch_agent_enabled                     = coalesce(try(tobool(local.cloudwatch_agent_settings.enabled), null), false)
  cloudwatch_agent_install_enabled             = local.cloudwatch_agent_enabled && coalesce(try(tobool(local.cloudwatch_agent_settings.install), null), true)
  cloudwatch_agent_configure_enabled           = local.cloudwatch_agent_enabled && coalesce(try(tobool(local.cloudwatch_agent_settings.configure), null), true)
  cloudwatch_agent_managed_policies_enabled    = local.cloudwatch_agent_enabled && coalesce(try(tobool(local.cloudwatch_agent_settings.attach_managed_policies), null), true) && try(var.iam.create, true)
  cloudwatch_agent_workload_detection_settings = try(local.cloudwatch_agent_settings.workload_detection, {})
  cloudwatch_agent_workload_detection_enabled  = coalesce(try(tobool(local.cloudwatch_agent_workload_detection_settings.enabled), null), false)
  cloudwatch_agent_targeting_enabled           = local.cloudwatch_agent_enabled || local.cloudwatch_agent_workload_detection_enabled
  cloudwatch_agent_target_tag_key              = coalesce(try(tostring(local.cloudwatch_agent_workload_detection_settings.tag_key), null), "CloudWatchAgent")
  cloudwatch_agent_target_tag_value            = coalesce(try(tostring(local.cloudwatch_agent_workload_detection_settings.tag_value), null), "enabled")
  cloudwatch_agent_tags                        = local.cloudwatch_agent_targeting_enabled ? { (local.cloudwatch_agent_target_tag_key) = local.cloudwatch_agent_target_tag_value } : {}
  cloudwatch_agent_target_key                  = coalesce(try(tostring(local.cloudwatch_agent_settings.target.key), null), "tag:${local.cloudwatch_agent_target_tag_key}")
  cloudwatch_agent_target_values               = length(try(local.cloudwatch_agent_settings.target.values, [])) > 0 ? local.cloudwatch_agent_settings.target.values : [local.cloudwatch_agent_target_tag_value]
  cloudwatch_agent_config_parameter_name       = coalesce(try(tostring(local.cloudwatch_agent_settings.config_parameter_name), null), "AmazonCloudWatch-${local.name}-config")
  cloudwatch_agent_create_config_parameter     = coalesce(try(tobool(local.cloudwatch_agent_settings.create_config_parameter), null), true)
  cloudwatch_agent_custom_configuration        = try(local.cloudwatch_agent_settings.configuration, {})
  cloudwatch_agent_append_default_config       = coalesce(try(tobool(local.cloudwatch_agent_settings.append_default_configuration), null), true)

  cloudwatch_agent_default_configuration = {
    agent = {
      metrics_collection_interval = coalesce(try(tonumber(local.cloudwatch_agent_settings.metrics_collection_interval), null), 60)
      run_as_user                 = coalesce(try(tostring(local.cloudwatch_agent_settings.run_as_user), null), "root")
    }
    metrics = {
      namespace = coalesce(try(tostring(local.cloudwatch_agent_settings.namespace), null), "CWAgent")
      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
        ImageId              = "$${aws:ImageId}"
        InstanceId           = "$${aws:InstanceId}"
        InstanceType         = "$${aws:InstanceType}"
      }
      aggregation_dimensions = [
        [
          "AutoScalingGroupName"
        ]
      ]
      metrics_collected = {
        mem = {
          measurement = [
            "mem_used_percent"
          ]
        }
        disk = {
          measurement = [
            "used_percent"
          ]
          resources = [
            "*"
          ]
        }
      }
    }
  }

  cloudwatch_agent_configuration = merge(concat(
    local.cloudwatch_agent_append_default_config ? [local.cloudwatch_agent_default_configuration] : [],
    [local.cloudwatch_agent_custom_configuration]
  )...)

  # Install and configure run as ordered steps of ONE association. Two separate State Manager
  # associations are scheduled independently on every instance, so on boot, scale-out, instance
  # refresh and every scheduled run, AmazonCloudWatch-ManageAgent could start before
  # AWS-ConfigureAWSPackage had installed the agent. Terraform depends_on only orders the API
  # calls at apply time, never the executions on the instances.
  cloudwatch_agent_ssm_enabled = try(var.asg.create, true) && (local.cloudwatch_agent_install_enabled || local.cloudwatch_agent_configure_enabled)
  cloudwatch_agent_install_parameters = local.cloudwatch_agent_install_enabled ? {
    installationType = coalesce(try(tostring(local.cloudwatch_agent_settings.installation_type), null), "Uninstall and reinstall")
    packageName      = coalesce(try(tostring(local.cloudwatch_agent_settings.package_name), null), "AmazonCloudWatchAgent")
    packageVersion   = coalesce(try(tostring(local.cloudwatch_agent_settings.package_version), null), "latest")
  } : {}
  cloudwatch_agent_configure_parameters = local.cloudwatch_agent_configure_enabled ? {
    configurationLocation = local.cloudwatch_agent_config_parameter_name
    mode                  = coalesce(try(tostring(local.cloudwatch_agent_settings.mode), null), "ec2")
    restart               = coalesce(try(tostring(local.cloudwatch_agent_settings.restart), null), "yes")
  } : {}
  # Values travel as association parameters, so changing any of them updates the association and
  # re-runs it on the targets. The document content only changes when a step is toggled.
  cloudwatch_agent_association_parameters = merge(local.cloudwatch_agent_install_parameters, local.cloudwatch_agent_configure_parameters)
  cloudwatch_agent_document_steps = concat(
    local.cloudwatch_agent_install_enabled ? [
      {
        action = "aws:runDocument"
        name   = "installCloudWatchAgent"
        inputs = tomap({
          documentType = "SSMDocument"
          documentPath = "AWS-ConfigureAWSPackage"
          documentParameters = jsonencode({
            action           = "Install"
            installationType = "{{ installationType }}"
            name             = "{{ packageName }}"
            version          = "{{ packageVersion }}"
          })
          # Stop here when the install fails, so the configure step never runs without the agent.
          # Requires SSM Agent 3.0.502 or later.
          onFailure = "exit"
        })
      }
    ] : [],
    local.cloudwatch_agent_configure_enabled ? [
      {
        action = "aws:runDocument"
        name   = "configureCloudWatchAgent"
        inputs = tomap({
          documentType = "SSMDocument"
          documentPath = "AmazonCloudWatch-ManageAgent"
          documentParameters = jsonencode({
            action                        = "configure"
            mode                          = "{{ mode }}"
            optionalConfigurationSource   = "ssm"
            optionalConfigurationLocation = "{{ configurationLocation }}"
            optionalRestart               = "{{ restart }}"
          })
        })
      }
    ] : []
  )
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  count = try(var.asg.create, true) && local.cloudwatch_agent_configure_enabled && local.cloudwatch_agent_create_config_parameter ? 1 : 0

  name        = local.cloudwatch_agent_config_parameter_name
  description = "CloudWatch Agent configuration for ${local.name}"
  type        = "String"
  value       = jsonencode(local.cloudwatch_agent_configuration)
  tags        = local.all_tags
}

resource "aws_ssm_document" "cloudwatch_agent" {
  count = local.cloudwatch_agent_ssm_enabled ? 1 : 0

  name            = "${local.name}-cwagent-ssm-doc"
  document_type   = "Command"
  document_format = "JSON"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Install and then configure the CloudWatch Agent for ${local.name}. Steps run in order."
    parameters = {
      for key in keys(local.cloudwatch_agent_association_parameters) : key => {
        type = "String"
      }
    }
    mainSteps = local.cloudwatch_agent_document_steps
  })
  tags = local.all_tags
}

resource "aws_ssm_association" "cloudwatch_agent" {
  count = local.cloudwatch_agent_ssm_enabled ? 1 : 0

  name                             = aws_ssm_document.cloudwatch_agent[0].name
  association_name                 = "${local.name}-cwagent"
  parameters                       = local.cloudwatch_agent_association_parameters
  max_concurrency                  = try(local.cloudwatch_agent_settings.max_concurrency, null)
  max_errors                       = try(local.cloudwatch_agent_settings.max_errors, null)
  schedule_expression              = try(local.cloudwatch_agent_settings.schedule_expression, null)
  wait_for_success_timeout_seconds = try(local.cloudwatch_agent_settings.wait_for_success_timeout_seconds, null)
  tags                             = local.all_tags

  targets {
    key    = local.cloudwatch_agent_target_key
    values = local.cloudwatch_agent_target_values
  }

  # SSM ANDs multiple targets, so this scopes the association to this ASG's instances only
  # (Name tag is propagated from the launch template) even when a user-specified target key/value
  # matches instances from other ASGs.
  targets {
    key    = "tag:Name"
    values = [local.name]
  }

  depends_on = [
    aws_autoscaling_group.this,
    aws_iam_instance_profile.this,
    aws_iam_role_policy_attachment.this,
    aws_iam_role_policy_attachment.ssm_managed_instance_core,
    aws_iam_role_policy.cloudwatch_agent_parameter,
    aws_ssm_parameter.cloudwatch_agent_config
  ]
}
