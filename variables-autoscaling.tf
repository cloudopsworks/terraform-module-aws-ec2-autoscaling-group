##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

##
# name: "" # (Optional) The name of the EC2 Instance. Default: "".
variable "name" {
  description = "The name of the EC2 Instance"
  type        = string
  default     = ""
}

##
# name_prefix: "" # (Optional) The name prefix of the EC2 Instance. Default: "".
variable "name_prefix" {
  description = "The name prefix of the EC2 Instance"
  type        = string
  default     = ""
}

##
# asg:  # (Optional) Auto Scaling Group and Launch Template configuration. Created when asg.create = true (default).
#   create: true  # (Optional) Whether to create ASG resources. Default: true.
#   type: "t3.micro"  # (Optional) Instance type for the Launch Template. Required if not using asg.instance_requirements and asg.mixed_instances = false.
#   ami:  # (Required) AMI selection. One of ami.id or ami.name must be provided to resolve an AMI.
#     id: "ami-0123456789abcdef0"  # (Optional) AMI ID. If set, takes precedence over ami.name.
#     name: "my-ami-*"  # (Optional) AMI name/pattern to search for when ami.id is not provided.
#     architecture: "x86_64"  # (Optional) Restrict search by architecture. Default: "x86_64". Allowed values: "x86_64", "arm64".
#     most_recent: true  # (Optional) Select most recent AMI when using name/filters. Default: true.
#     owners: ["self"]  # (Optional) AMI owners to search. Default: ["self"]. Allowed values: "self", "amazon", "aws-marketplace", or specific AWS account IDs.
#     filters:  # (Optional) Additional filters for AMI lookup.
#       - name: "tag:Build"  # (Optional) Filter name as supported by EC2 describe-images API (e.g., name, tag:*, architecture, etc.).
#         values: ["2025-*"]  # (Optional) Values for the above filter.
#     auto_update:  # (Optional) Enable automated AMI roll-out via EventBridge + SSM Automation.
#       enabled: false  # (Optional) When true, creates EventBridge rule and SSM doc to update the Launch Template to the latest AMI matching filters on backup completion events. Default: false.
#   user_data: |  # (Optional) Plain-text user data. Will be base64-encoded automatically if non-empty. Default: "".
#     #!/bin/bash
#     echo "hello"
#   user_data_base64: ""  # (Optional) Base64-encoded user data. Used only when user_data is empty. Default: "".
#   monitoring: false  # (Optional) Detailed monitoring for instances (Launch Template). Default: false.
#   ebs:  # (Optional) EBS and block device settings for the Launch Template.
#     ebs_optimized: true  # (Optional) Enable EBS optimization. Default: AWS/AMI default.
#     block_device:  # (Optional) List of block device mappings.
#       - device_name: "/dev/xvda"  # (Required) Device name as recognized by the OS.
#         volume_size: 8  # (Required) EBS volume size in GiB.
#         volume_type: "gp3"  # (Optional) Default: "gp3". Allowed values: "gp3", "gp2", "io1", "io2", "sc1", "st1", "standard".
#         iops: 3000  # (Optional) IOPS (required for io1/io2, ignored for gp2/gp3 unless specified).
#         throughput: 125  # (Optional) MiB/s throughput (gp3 only).
#         encrypted: false  # (Optional) Encrypt the volume. Default: false.
#         kms_key_id: ""  # (Optional) KMS key ID/ARN when encrypted = true.
#         delete_on_termination: true  # (Optional) Delete volume on instance termination. Default: true.
#         no_device: false  # (Optional) Suppress the specified device mapping. Default: false.
#         virtual_name: ""  # (Optional) For ephemeral devices (rarely used). Default: "".
#   spot:  # (Optional) Spot instance options on the Launch Template.
#     enabled: false  # (Optional) Enable Spot market. Default: false.
#     interruption_behavior: "terminate"  # (Optional) Action on interruption. Default: "terminate". Allowed values: "hibernate", "stop", "terminate".
#     instance_type: "one-time"  # (Optional) Spot request type. Default: null. Allowed values: "one-time", "persistent".
#     block_duration_minutes: 60  # (Optional) Fixed hourly block duration (multiples of 60). Default: null. Allowed values: 60, 120, 180, 240, 300, 360.
#   instance_requirements:  # (Optional) Flexible instance selection instead of a fixed asg.type (Launch Template).
#     instance_types: ["t3a.micro"]  # (Optional) Allowed instance type names (e.g., t3a.micro).
#     memory_mib:  # (Optional) Memory requirement in MiB.
#       min: 0  # (Optional) Minimum memory in MiB. Default: 0.
#       max: 4096  # (Optional) Maximum memory in MiB. Default: null.
#     vcpu_count:  # (Optional) vCPU requirement.
#       min: 0  # (Optional) Minimum vCPUs. Default: 0.
#       max: 2  # (Optional) Maximum vCPUs. Default: null.
#   metadata_options:  # (Optional) Instance Metadata Service (IMDS) options (Launch Template).
#     http_endpoint: "enabled"  # (Optional) Control IMDS endpoint availability. Default: "enabled". Allowed values: "enabled", "disabled".
#     http_put_response_hop_limit: 1  # (Optional) Allowed network hops for PUT (1-64). Default: 1.
#     http_tokens: "optional"  # (Optional) Require IMDSv2 session tokens. Default: "optional". Allowed values: "required", "optional".
#     instance_metadata_tags: "disabled"  # (Optional) Include instance tags in IMDS. Default: "disabled". Allowed values: "enabled", "disabled".
#   key_pair:  # (Optional) Module-managed EC2 key pair.
#     create: false  # (Optional) Create and attach a key pair. Default: false.
#     name: ""  # (Optional) Key pair name when create = true. Default: "key/${local.name}".
#   secrets_manager_enabled: true  # (Optional) When key_pair.create = true, save keys to Secrets Manager. Default: true.
#   vpc:  # (Required) Networking configuration for the ASG.
#     subnet_ids: ["subnet-12345"]  # (Required) Subnet IDs where instances will be launched.
#     security_group_ids: ["sg-12345"]  # (Optional) Additional SGs to attach.
#     availability_zones: ["us-east-1a"]  # (Optional) Explicit AZs for the ASG. Default: provider computes from subnets.
#   security_group:  # (Optional) Module-managed Security Group and its rules.
#     create: false  # (Optional) Create a security group. Default: false.
#     rules:  # (Optional) Map of ingress/egress rules (key = rule id).
#       ssh-ingress:  # (Optional) Example rule key.
#         description: "Allow SSH"  # (Optional) Description. Default: "Rule for ${local.name} access".
#         type: "ingress"  # (Optional) Rule direction. Default: "ingress". Allowed values: "ingress", "egress".
#         protocol: "tcp"  # (Optional) Protocol. Default: "-1". Allowed values: "tcp", "udp", "icmp", "-1", etc.
#         from_port: 22  # (Optional) From port (or ICMP type). Default: 0.
#         to_port: 22  # (Optional) To port (or ICMP code). Default: 0.
#         cidr_blocks: ["0.0.0.0/0"]  # (Optional) IPv4 CIDR ranges.
#         ipv6_cidr_blocks: []  # (Optional) IPv6 CIDR ranges.
#         self: false  # (Optional) If true, the SG itself is a source/destination.
#         source_security_group_id: ""  # (Optional) Source SG for ingress.
#   min_size: 1  # (Optional) Minimum number of instances in the ASG. Default: 1.
#   max_size: 2  # (Optional) Maximum number of instances in the ASG. Default: 1.
#   desired_capacity: 1  # (Optional) Desired capacity. Default: 1.
#   desired: 1  # (Optional) Alias for desired_capacity. Default: 1.
#   enabled_metrics: ["GroupMinSize"]  # (Optional) List of ASG metrics to collect. Default: [].
#   termination_policies: ["Default"]  # (Optional) Termination policies. Default: ["Default"]. Allowed values: "OldestInstance", "OldestLaunchTemplate", "ClosestToNextInstanceHour", "Default".
#   suspended_processes: ["HealthCheck"]  # (Optional) Processes to suspend. Default: []. Allowed values: "HealthCheck", "AZRebalance", "ReplaceUnhealthy", "AlarmNotification", "ScheduledActions", "AddToLoadBalancer".
#   health_check:  # (Optional) Health check configuration for the ASG.
#     type: "ELB"  # (Optional) Health check type. Default: "ELB". Allowed values: "EC2", "ELB".
#     grace_period: 300  # (Optional) Seconds to ignore unhealthy checks after launch. Default: 300.
#   force_delete: false  # (Optional) Force delete the ASG and all instances. Default: false.
#   availability_zone_distribution: "balanced"  # (Optional) Capacity distribution strategy across AZs. Default: null. Allowed values: "balanced", "prioritized".
#   mixed_instances: false  # (Optional) Use Mixed Instances Policy with overrides. Default: false.
#   instance_types:  # (Optional) Overrides; required when mixed_instances = true.
#     - type: "t3.micro"  # (Required) Instance type for this override.
#       capacity: "1"  # (Optional) Weighted capacity as string. Default: "1".
#   instance_refresh:  # (Optional) Rolling instance refresh strategy.
#     enabled: false  # (Optional) Enable instance refresh. Default: false.
#     strategy: "Rolling"  # (Optional) Refresh strategy. Default: "Rolling". Allowed values: "Rolling".
#     min_healthy_percentage: 90  # (Optional) Minimum healthy percentage during refresh. Default: 90.
#     max_healthy_percentage: 100  # (Optional) Maximum healthy percentage during refresh. Default: null.
#     instance_warmup: 300  # (Optional) Warm-up time in seconds. Default: null.
#     triggers: ["launch_template"]  # (Optional) Events that trigger refresh. Default: [].
#   extra_tags:  # (Optional) Extra tags applied to instances.
#     Owner: "you@example.com"
#   backup:  # (Optional) Backup tagging for AWS Backup plan discovery.
#     enabled: false  # (Optional) Add backup discovery tags. Default: false.
#     only_tag: true  # (Optional) Apply only tags (no backup resources). Default: true.
#     schedule: "daily"  # (Optional) Tag to indicate backup schedule. Default: "daily". Allowed values: "hourly", "daily", "weekly", "monthly".
#   scaling_policies:  # (Optional) List of Auto Scaling policies to attach to the ASG.
#     - name: "cpu-target"  # (Required) Unique policy name key.
#       adjustment_type: "ChangeInCapacity"  # (Optional) For simple/step scaling. Default: "ChangeInCapacity". Allowed values: "ChangeInCapacity", "ExactCapacity", "PercentChangeInCapacity".
#       scaling_adjustment: 1  # (Optional) Change amount for simple/step scaling.
#       cooldown: 300  # (Optional) Cooldown in seconds. Default: 300.
#       tracking_configuration:  # (Optional) Target tracking configuration.
#         target_value: 50.0  # (Required) Target value for the metric.
#         predefined:  # (Optional) Use a predefined ASG metric.
#           metric_type: "ASGAverageCPUUtilization"  # (Required) Metric type. Allowed values: "ASGAverageCPUUtilization", "ASGAverageNetworkIn", "ASGAverageNetworkOut", "ALBRequestCountPerTarget".
#           resource_label: "app/my-alb/50dc6c495c0c"  # (Optional) Required only for ALB metrics.
#         customized:  # (Optional) Use CloudWatch metric math/metrics.
#           metrics:  # (Optional) List of metric data queries.
#             - label: "MyMetric"  # (Optional) Label for the time series.
#               id: "m1"  # (Required) Unique within the policy.
#               expression: "m2 / m3"  # (Optional) Metric math expression.
#               return_data: true  # (Optional) Whether to return this time series. Default: true.
#               metric_stat:  # (Optional) Required when not using expression.
#                 metric:
#                   namespace: "AWS/EC2"  # (Required) Metric namespace.
#                   metric_name: "CPUUtilization"  # (Required) Metric name.
#                   dimensions:  # (Optional) Metric dimensions.
#                     - name: "AutoScalingGroupName"  # (Required) Dimension name.
#                       value: "my-asg"  # (Required) Dimension value.
#                 stat: "Average"  # (Required) Statistic.
#                 period: 60  # (Required) Period in seconds.
#                 unit: "Percent"  # (Optional) Unit for the metric.
#       predictive_scaling:  # (Optional) Predictive scaling configuration.
#         target_value: 50.0  # (Required) Target capacity utilization.
#         metric_pair:  # (Optional) Predefined pair metric for load vs. capacity.
#           metric_type: "ALBRequestCountPerTarget"  # (Required) Predefined pair type.
#           resource_label: "app/my-alb/50dc6c495c0c"  # (Required for ALB metrics) Resource label.
#         customized_load:  # (Optional) Customized load metric.
#           id: "load1"  # (Required) Unique identifier.
#           label: "Load"  # (Optional) Label for the metric.
#           expression: ""  # (Optional) Math expression.
#           return_data: true  # (Optional) Default: true.
#           metric_stat:  # (Optional) Metric statistics.
#             metric:
#               namespace: "AWS/EC2"
#               metric_name: "CPUUtilization"
#               dimensions:
#                 - name: "AutoScalingGroupName"
#                   value: "my-asg"
#             stat: "Average"
#             unit: "Percent"
#         customized_capacity:  # (Optional) Customized capacity metric.
#           id: "cap1"  # (Required) Unique identifier.
#           label: "Capacity"  # (Optional) Label for the metric.
#           expression: ""  # (Optional) Math expression.
#           return_data: true  # (Optional) Default: true.
#           metric_stat:
#             metric:
#               namespace: "AWS/EC2"
#               metric_name: "CPUUtilization"
#               dimensions:
#                 - name: "AutoScalingGroupName"
#                   value: "my-asg"
#             stat: "Average"
#             unit: "Percent"
#         customized_scaling:  # (Optional) Customized scaling metric.
#           data_queries:  # (Optional) List of metric data queries.
#             - id: "scale1"  # (Required) Unique identifier.
#               label: "Scaling"  # (Optional) Label for the metric.
#               expression: ""  # (Optional) Math expression.
#               return_data: true  # (Optional) Default: true.
#               metric_stat:
#                 metric:
#                   namespace: "AWS/EC2"
#                   metric_name: "CPUUtilization"
#                   dimensions:
#                     - name: "AutoScalingGroupName"
#                       value: "my-asg"
#                 stat: "Average"
#                 unit: "Percent"
variable "asg" {
  description = "The instance type to use for the EC2 Instance"
  type        = any
  default     = {}
}

##
# timeouts:  # (Optional) Operation timeouts for the Auto Scaling Group resource.
#   update: "20m"  # (Optional) Timeout for create/update operations. Default: "20m".
#   delete: "20m"  # (Optional) Timeout for delete operations. Default: "20m".
variable "timeouts" {
  description = "The timeouts of the EC2 Instance"
  type        = any
  default     = {}
}

##
# iam:  # (Optional) IAM resources configuration for EC2 instances (role and instance profile).
#   create: true  # (Optional) Create IAM role and instance profile and attach to instances. Default: true.
#   path: "/service-role/"  # (Optional) Path for the IAM role and instance profile. Default: null.
#   role_description: "Role for ${name}"  # (Optional) Description for the IAM role. Default: "IAM Instance Role ${local.name}".
#   permissions_boundary: "arn:aws:iam::...:policy/..."  # (Optional) ARN of the permissions boundary policy. Default: null.
#   logs_enabled: false  # (Optional) Enable CloudWatch Logs delivery policy. Default: false.
#   role_policies:  # (Optional) Array of managed policy attachments. Default: [].
#     - "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
#   extra_tags:  # (Optional) Extra tags to apply to IAM resources. Default: {}.
#     Team: "Platform"
variable "iam" {
  description = "The IAM role to use for the EC2 Instance"
  type        = any
  default     = {}
}