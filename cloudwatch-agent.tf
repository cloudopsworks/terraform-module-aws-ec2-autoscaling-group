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
  cloudwatch_agent_workload_detection_settings = try(local.cloudwatch_agent_settings.workload_detection, {})
  cloudwatch_agent_workload_detection_enabled  = coalesce(try(tobool(local.cloudwatch_agent_workload_detection_settings.enabled), null), false)
  cloudwatch_agent_targeting_enabled           = local.cloudwatch_agent_enabled || local.cloudwatch_agent_workload_detection_enabled
  cloudwatch_agent_target_tag_key              = coalesce(try(tostring(local.cloudwatch_agent_workload_detection_settings.tag_key), null), "CloudWatchAgent")
  cloudwatch_agent_target_tag_value            = coalesce(try(tostring(local.cloudwatch_agent_workload_detection_settings.tag_value), null), "enabled")
  cloudwatch_agent_tags                        = local.cloudwatch_agent_targeting_enabled ? { (local.cloudwatch_agent_target_tag_key) = local.cloudwatch_agent_target_tag_value } : {}
  cloudwatch_agent_config_parameter_name       = coalesce(try(tostring(local.cloudwatch_agent_settings.config_parameter_name), null), "AmazonCloudWatch-${local.name}-config")
  cloudwatch_agent_create_config_parameter     = coalesce(try(tobool(local.cloudwatch_agent_settings.create_config_parameter), null), true)
  cloudwatch_agent_custom_configuration        = try(local.cloudwatch_agent_settings.configuration, null) != null ? local.cloudwatch_agent_settings.configuration : {}
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

  cloudwatch_agent_configuration = local.cloudwatch_agent_append_default_config ? merge(
    local.cloudwatch_agent_default_configuration,
    local.cloudwatch_agent_custom_configuration
  ) : local.cloudwatch_agent_custom_configuration
}

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  count = try(var.asg.create, true) && local.cloudwatch_agent_configure_enabled && local.cloudwatch_agent_create_config_parameter ? 1 : 0

  name        = local.cloudwatch_agent_config_parameter_name
  description = "CloudWatch Agent configuration for ${local.name}"
  type        = "String"
  value       = jsonencode(local.cloudwatch_agent_configuration)
  tags        = local.all_tags
}

resource "aws_ssm_association" "cloudwatch_agent_install" {
  count = try(var.asg.create, true) && local.cloudwatch_agent_install_enabled ? 1 : 0

  name             = "AWS-ConfigureAWSPackage"
  association_name = "${local.name}-cwagent-install"
  parameters = {
    action           = "Install"
    installationType = coalesce(try(tostring(local.cloudwatch_agent_settings.installation_type), null), "Uninstall and reinstall")
    name             = coalesce(try(tostring(local.cloudwatch_agent_settings.package_name), null), "AmazonCloudWatchAgent")
    version          = coalesce(try(tostring(local.cloudwatch_agent_settings.package_version), null), "latest")
  }
  max_concurrency                  = try(local.cloudwatch_agent_settings.max_concurrency, null)
  max_errors                       = try(local.cloudwatch_agent_settings.max_errors, null)
  schedule_expression              = try(local.cloudwatch_agent_settings.schedule_expression, null)
  wait_for_success_timeout_seconds = try(local.cloudwatch_agent_settings.wait_for_success_timeout_seconds, null)
  tags                             = local.all_tags

  targets {
    key = "tag:${local.cloudwatch_agent_target_tag_key}"
    values = [
      local.cloudwatch_agent_target_tag_value
    ]
  }
}

resource "aws_ssm_association" "cloudwatch_agent_configure" {
  count = try(var.asg.create, true) && local.cloudwatch_agent_configure_enabled ? 1 : 0

  name             = "AmazonCloudWatch-ManageAgent"
  association_name = "${local.name}-cwagent-configure"
  parameters = {
    action                        = "configure"
    mode                          = coalesce(try(tostring(local.cloudwatch_agent_settings.mode), null), "ec2")
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = local.cloudwatch_agent_config_parameter_name
    optionalRestart               = coalesce(try(tostring(local.cloudwatch_agent_settings.restart), null), "yes")
  }
  max_concurrency                  = try(local.cloudwatch_agent_settings.max_concurrency, null)
  max_errors                       = try(local.cloudwatch_agent_settings.max_errors, null)
  schedule_expression              = try(local.cloudwatch_agent_settings.schedule_expression, null)
  wait_for_success_timeout_seconds = try(local.cloudwatch_agent_settings.wait_for_success_timeout_seconds, null)
  tags                             = local.all_tags

  targets {
    key = "tag:${local.cloudwatch_agent_target_tag_key}"
    values = [
      local.cloudwatch_agent_target_tag_value
    ]
  }

  depends_on = [
    aws_ssm_association.cloudwatch_agent_install,
    aws_ssm_parameter.cloudwatch_agent_config
  ]
}
