##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

locals {
  is_t_instance_type = replace(var.asg.type, "/^t(2|3|3a|4g){1}\\..*$/", "1") == "1" ? true : false
  name               = var.name_prefix != "" ? "${var.name_prefix}-${local.system_name}" : var.name
  instance_tags = merge(
    local.all_tags,
    local.backup_tags,
    try(var.asg.extra_tags, {}),
    {
      Name = local.name
    }
  )
}

data "aws_ami" "this" {
  count       = try(var.asg.create, true) && try(var.asg.ami.name, "") != "" ? 1 : 0
  most_recent = try(var.asg.ami.most_recent, true)
  owners      = try(var.asg.ami.owners, ["self"])
  filter {
    name   = "name"
    values = [var.asg.ami.name]
  }
  filter {
    name   = "architecture"
    values = [try(var.asg.ami.architecture, "x86_64")]
  }
  dynamic "filter" {
    for_each = try(var.asg.ami.filters, [])
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

resource "aws_launch_template" "this" {
  count                  = try(var.asg.create, true) ? 1 : 0
  name                   = "${local.name}-lt"
  image_id               = try(var.asg.ami.id, length(data.aws_ami.this) > 0 ? data.aws_ami.this[0].id : null)
  instance_type          = try(var.asg.type, null)
  key_name               = try(var.asg.key_pair.create, false) ? aws_key_pair.this[0].key_name : null
  update_default_version = true
  ebs_optimized          = try(var.asg.ebs.ebs_optimized, null)
  user_data              = try(var.asg.user_data, "") != "" ? base64encode(var.asg.user_data) : try(var.asg.user_data_base64, null)

  dynamic "block_device_mappings" {
    for_each = try(var.asg.ebs.block_device, [])
    content {
      device_name = block_device_mappings.value.device_name
      ebs {
        delete_on_termination = try(block_device_mappings.value.delete_on_termination, true)
        volume_size           = block_device_mappings.value.volume_size
        volume_type           = try(block_device_mappings.value.volume_type, "gp3")
        iops                  = try(block_device_mappings.value.iops, null)
        throughput            = try(block_device_mappings.value.throughput, null)
        encrypted             = try(block_device_mappings.value.encrypted, false)
        kms_key_id            = try(block_device_mappings.value.kms_key_id, null)
      }
      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)
    }
  }
  dynamic "instance_market_options" {
    for_each = try(var.asg.spot.enabled, false) ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = try(var.asg.spot.interruption_behavior, "terminate")
        spot_instance_type             = try(var.asg.spot.instance_type, null)
        block_duration_minutes         = try(var.asg.spot.block_duration_minutes, null)
      }
    }
  }
  dynamic "instance_requirements" {
    for_each = length(try(var.asg.instance_requirements, {})) > 0 ? [1] : []
    content {
      allowed_instance_types = try(var.asg.instance_requirements.instance_types, null)
      memory_mib {
        min = try(var.asg.instance_requirements.memory_mib.min, 0)
        max = try(var.asg.instance_requirements.memory_mib.max, null)
      }
      vcpu_count {
        min = try(var.asg.instance_requirements.vcpu_count.min, 0)
        max = try(var.asg.instance_requirements.vcpu_count.max, null)
      }
    }
  }
  dynamic "iam_instance_profile" {
    for_each = try(var.iam.create, true) ? [1] : []
    content {
      arn = aws_iam_instance_profile.this[0].arn
    }
  }
  dynamic "monitoring" {
    for_each = try(var.asg.monitoring, false) ? [1] : []
    content {
      enabled = true
    }
  }
  dynamic "metadata_options" {
    for_each = length(try(var.asg.metadata_options, {})) > 0 ? [var.asg.metadata_options] : []
    content {
      http_endpoint               = try(metadata_options.value.http_endpoint, null)
      http_put_response_hop_limit = try(metadata_options.value.http_put_response_hop_limit, null)
      http_tokens                 = try(metadata_options.value.http_tokens, null)
      instance_metadata_tags      = try(metadata_options.value.instance_metadata_tags, null)
    }
  }
  vpc_security_group_ids = try(var.asg.security_group.create, false) ? concat([aws_security_group.this[0].id], try(var.asg.vpc.security_group_ids, [])) : try(var.asg.vpc.security_group_ids, null)
  tag_specifications {
    resource_type = "instance"
    tags          = local.instance_tags
  }
  tags = local.all_tags
}

resource "aws_autoscaling_group" "this" {
  count                     = try(var.asg.create, true) ? 1 : 0
  name                      = "${local.name}-asg"
  max_size                  = try(var.asg.max_size, 1)
  min_size                  = try(var.asg.min_size, 1)
  desired_capacity          = try(var.asg.desired_capacity, var.asg.desired, 1)
  health_check_grace_period = try(var.asg.health_check.grace_period, 300)
  health_check_type         = try(var.asg.health_check.type, "ELB")
  force_delete              = try(var.asg.force_delete, false)
  vpc_zone_identifier       = var.asg.vpc.subnet_ids
  enabled_metrics           = try(var.asg.enabled_metrics, null)
  termination_policies      = try(var.asg.termination_policies, null)
  suspended_processes       = try(var.asg.suspended_processes, null)
  availability_zones        = try(var.asg.vpc.availability_zones, null)
  dynamic "availability_zone_distribution" {
    for_each = try(var.asg.availability_zone_distribution, "") != "" ? [1] : []
    content {
      capacity_distribution_strategy = var.asg.availability_zone_distribution
    }
  }
  dynamic "launch_template" {
    for_each = try(var.asg.mixed_instances, false) ? [] : [1]
    content {
      id      = aws_launch_template.this[0].id
      version = aws_launch_template.this[0].latest_version
    }
  }
  dynamic "mixed_instances_policy" {
    for_each = try(var.asg.mixed_instances, false) ? [1] : []
    content {
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.this[0].id
          version            = aws_launch_template.this[0].latest_version
        }
        dynamic "override" {
          for_each = try(var.asg.instance_types, [])
          content {
            instance_type     = override.value.type
            weighted_capacity = try(override.value.capacity, "1")
          }
        }
      }
    }
  }

  dynamic "instance_refresh" {
    for_each = try(var.asg.instance_refresh.enabled, false) ? [1] : []
    content {
      strategy = try(var.asg.instance_refresh.strategy, "Rolling")
      preferences {
        min_healthy_percentage = try(var.asg.instance_refresh.min_healthy_percentage, 90)
        max_healthy_percentage = try(var.asg.instance_refresh.max_healthy_percentage, null)
        instance_warmup        = try(var.asg.instance_refresh.instance_warmup, null)
      }
      triggers = try(var.asg.instance_refresh.triggers, null)
    }
  }

  dynamic "tag" {
    for_each = local.all_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  timeouts {
    update = try(var.timeouts.update, "20m")
    delete = try(var.timeouts.delete, "20m")
  }
}

resource "aws_autoscaling_policy" "this" {
  for_each = {
    for policy in try(var.asg.scaling_policies, {}) : policy.name => policy if try(var.asg.create, true)
  }
  autoscaling_group_name = aws_autoscaling_group.this[0].name
  name                   = "${local.name}-${each.value.name}-pol"
  adjustment_type        = try(each.value.adjustment_type, "ChangeInCapacity")
  scaling_adjustment     = try(each.value.scaling_adjustment, null)
  cooldown               = try(each.value.cooldown, 300)
  dynamic "target_tracking_configuration" {
    for_each = length(try(each.value.tracking_configuration, {})) > 0 ? [1] : []
    content {
      target_value = each.value.tracking_configuration.target_value
      dynamic "predefined_metric_specification" {
        for_each = try(each.value.tracking_configuration.predefined, null) != null ? [1] : []
        content {
          predefined_metric_type = each.value.tracking_configuration.predefined.metric_type
          resource_label         = try(each.value.tracking_configuration.predefined.resource_label, null)
        }
      }
      dynamic "customized_metric_specification" {
        for_each = try(each.value.tracking_configuration.customized, null) != null ? [1] : []
        content {
          dynamic "metrics" {
            for_each = try(each.value.tracking_configuration.customized.metrics, [])
            content {
              label       = try(metrics.value.label, null)
              id          = metrics.value.id
              expression  = try(metrics.value.expression, null)
              return_data = try(metrics.value.return_data, true)
              dynamic "metric_stat" {
                for_each = try(metrics.value.metric_stat, null) != null ? [1] : []
                content {
                  metric {
                    namespace   = metric_stat.value.metric.namespace
                    metric_name = metric_stat.value.metric.metric_name
                    dynamic "dimensions" {
                      for_each = try(metric_stat.value.metric.dimensions, [])
                      content {
                        name  = dimensions.value.name
                        value = dimensions.value.value
                      }
                    }
                  }
                  stat   = metric_stat.value.stat
                  period = metric_stat.value.period
                  unit   = try(metric_stat.value.unit, null)
                }
              }
            }
          }
        }
      }
    }
  }
  dynamic "predictive_scaling_configuration" {
    for_each = length(try(each.value.predictive_scaling, {})) > 0 ? [1] : []
    content {
      metric_specification {
        target_value = each.value.predictive_scaling.target_value
        dynamic "predefined_metric_pair_specification" {
          for_each = try(each.value.predictive_scaling.metric_pair, null) != null ? [1] : []
          content {
            predefined_metric_type = each.value.predictive_scaling.metric_pair.metric_type
            resource_label         = each.value.predictive_scaling.metric_pair.resource_label
          }
        }
        dynamic "customized_load_metric_specification" {
          for_each = try(each.value.predictive_scaling.customized_load, null) != null ? [1] : []
          content {
            metric_data_queries {
              label       = try(each.value.predictive_scaling.customized_load.label, null)
              id          = each.value.predictive_scaling.customized_load.id
              expression  = try(each.value.predictive_scaling.customized_load.expression, null)
              return_data = try(each.value.predictive_scaling.customized_load.return_data, true)
              dynamic "metric_stat" {
                for_each = try(each.value.predictive_scaling.customized_load.metric_stat, null)
                content {
                  metric {
                    namespace   = metric_stat.value.metric.namespace
                    metric_name = metric_stat.value.metric.metric_name
                    dynamic "dimensions" {
                      for_each = try(metric_stat.value.metric.dimensions, [])
                      content {
                        name  = dimensions.value.name
                        value = dimensions.value.value
                      }
                    }
                  }
                  stat = metric_stat.value.stat
                  unit = try(metric_stat.value.unit, null)
                  # period = metric_stat.value.period
                }
              }
            }
          }
        }
        dynamic "customized_capacity_metric_specification" {
          for_each = try(each.value.predictive_scaling.customized_capacity, null) != null ? [1] : []
          content {
            metric_data_queries {
              label       = try(each.value.predictive_scaling.customized_capacity.label, null)
              id          = each.value.predictive_scaling.customized_capacity.id
              expression  = try(each.value.predictive_scaling.customized_capacity.expression, null)
              return_data = try(each.value.predictive_scaling.customized_capacity.return_data, true)
              dynamic "metric_stat" {
                for_each = try(each.value.predictive_scaling.customized_capacity.metric_stat, null)
                content {
                  metric {
                    namespace   = metric_stat.value.metric.namespace
                    metric_name = metric_stat.value.metric.metric_name
                    dynamic "dimensions" {
                      for_each = try(metric_stat.value.metric.dimensions, [])
                      content {
                        name  = dimensions.value.name
                        value = dimensions.value.value
                      }
                    }
                  }
                  stat = metric_stat.value.stat
                  unit = try(metric_stat.value.unit, null)
                  # period = metric_stat.value.period
                }
              }
            }
          }
        }
        dynamic "customized_scaling_metric_specification" {
          for_each = try(each.value.predictive_scaling.customized_scaling, null) != null ? [1] : []
          content {
            dynamic "metric_data_queries" {
              for_each = try(each.value.predictive_scaling.customized_scaling.data_queries, [])
              content {
                label       = try(metric_data_queries.value.label, null)
                id          = metric_data_queries.value.id
                expression  = try(metric_data_queries.value.expression, null)
                return_data = try(metric_data_queries.value.return_data, true)
                dynamic "metric_stat" {
                  for_each = try(metric_data_queries.value.metric_stat, null)
                  content {
                    metric {
                      namespace   = metric_stat.value.metric.namespace
                      metric_name = metric_stat.value.metric.metric_name
                      dynamic "dimensions" {
                        for_each = try(metric_stat.value.metric.dimensions, [])
                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }
                    }
                    stat = metric_stat.value.stat
                    unit = try(metric_stat.value.unit, null)
                    # period = metric_stat.value.period
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}