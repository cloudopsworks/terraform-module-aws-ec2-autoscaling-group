##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#

variable "name" {
  description = "The name of the EC2 Instance"
  type        = string
  default     = ""
}

variable "name_prefix" {
  description = "The name prefix of the EC2 Instance"
  type        = string
  default     = ""
}

##
# YAML Structure (module configuration reference)
# Each item is annotated with (Required) or (Optional), a brief description, default value, and allowed values when applicable.
#
# asg:  # (Optional) Auto Scaling Group and Launch Template configuration. Created when asg.create = true (default).
#   create: true | false  # (Optional) Whether to create ASG resources. Default: true.
#   type: "t3.micro"  # (Optional) Instance type for the Launch Template. Required if not using asg.instance_requirements and asg.mixed_instances = false.
#   ami:  # (Conditionally required) AMI selection. One of ami.id or ami.name must be provided to resolve an AMI.
#     id: "ami-0123456789abcdef0"  # (Optional) AMI ID. If set, takes precedence over ami.name.
#     name: "my-ami-*"  # (Optional) AMI name/pattern to search for when ami.id is not provided.
#     architecture: "x86_64" | "arm64"  # (Optional) Restrict search by architecture. Default: "x86_64".
#     most_recent: true | false  # (Optional) Select most recent AMI when using name/filters. Default: true.
#     owners: ["self"]  # (Optional) AMI owners to search. Allowed: "self", "amazon", "aws-marketplace", or specific AWS account IDs. Default: ["self"].
#     filters:  # (Optional) Additional filters for AMI lookup.
#       - name: "tag:Build"  # (Optional) Filter name as supported by EC2 describe-images API (e.g., name, tag:*, architecture, etc.).
#         values: ["2025-*"]  # (Optional) Values for the above filter.
#
#   user_data: |  # (Optional) Plain-text user data. Will be base64-encoded automatically if non-empty.
#     #!/bin/bash
#     echo "hello"
#   user_data_base64: "..."  # (Optional) Base64-encoded user data. Used only when user_data is empty.
#   monitoring: true | false  # (Optional) Detailed monitoring for instances (Launch Template). Default: false.
#
#   ebs:  # (Optional) EBS and block device settings for the Launch Template.
#     ebs_optimized: true | false  # (Optional) Enable EBS optimization. Default: AWS/AMI default.
#     block_device:  # (Optional) List of block device mappings.
#       - device_name: "/dev/xvda"  # (Required) Device name as recognized by the OS.
#         volume_size: 8  # (Required) EBS volume size in GiB.
#         volume_type: "gp3" | "gp2" | "io1" | "io2" | "sc1" | "st1" | "standard"  # (Optional) Default: "gp3".
#         iops: 3000  # (Optional) IOPS (required for io1/io2, ignored for gp2/gp3 unless specified).
#         throughput: 125  # (Optional) MiB/s throughput (gp3 only).
#         encrypted: true | false  # (Optional) Encrypt the volume. Default: false.
#         kms_key_id: "arn:aws:kms:...:key/..."  # (Optional) KMS key ID/ARN when encrypted = true.
#         delete_on_termination: true | false  # (Optional) Delete volume on instance termination. Default: true.
#         no_device: false  # (Optional) Suppress the specified device mapping. Default: false.
#         virtual_name: null  # (Optional) For ephemeral devices (rarely used). Default: null.
#
#   spot:  # (Optional) Spot instance options on the Launch Template.
#     enabled: true | false  # (Optional) Enable Spot market. Default: false.
#     interruption_behavior: hibernate | stop | terminate  # (Optional) Action on interruption. Default: terminate.
#     instance_type: one-time | persistent  # (Optional) Spot request type. Default: null.
#     block_duration_minutes: 60 | 120 | 180 | 240 | 300 | 360  # (Optional) Fixed hourly block duration (multiples of 60). Default: null.
#
#   instance_requirements:  # (Optional) Flexible instance selection instead of a fixed asg.type (Launch Template).
#     instance_types:  # (Optional) Allowed instance type names (e.g., t3a.micro). If omitted, rely on constraints below.
#       - t3a.micro
#       - t3a.small
#     memory_mib:  # (Optional) Memory requirement in MiB.
#       min: 0  # (Optional) Minimum memory in MiB. Default: 0.
#       max: 4096  # (Optional) Maximum memory in MiB. Default: null (no max).
#     vcpu_count:  # (Optional) vCPU requirement.
#       min: 1  # (Optional) Minimum vCPUs. Default: 0.
#       max: 2  # (Optional) Maximum vCPUs. Default: null (no max).
#
#   metadata_options:  # (Optional) Instance Metadata Service (IMDS) options (Launch Template).
#     http_endpoint: "enabled" | "disabled"  # (Optional) Control IMDS endpoint availability. Default: "enabled".
#     http_put_response_hop_limit: 1  # (Optional) Allowed network hops for PUT (1-64). Default: provider default (1).
#     http_tokens: "required" | "optional"  # (Optional) Require IMDSv2 session tokens. Default: "optional".
#     instance_metadata_tags: "enabled" | "disabled"  # (Optional) Include instance tags in IMDS. Default: provider default (usually "disabled").
#
#   key_pair:  # (Optional) Module-managed EC2 key pair.
#     create: true | false  # (Optional) Create and attach a key pair. Default: false.
#     name: "key/my-app"  # (Optional) Key pair name when create = true. Default: "key/${local.name}".
#   secrets_manager_enabled: true | false  # (Optional) When key_pair.create = true, save keys to Secrets Manager. Default: true.
#
#   vpc:  # (Required) Networking configuration for the ASG.
#     subnet_ids: ["subnet-aaa", "subnet-bbb"]  # (Required) Subnet IDs where instances will be launched.
#     subnet_id: "subnet-aaa"  # (Conditionally required) Required when security_group.create = true, to derive VPC ID.
#     security_group_ids: ["sg-0123456789abcdef0"]  # (Optional) Additional SGs to attach along with the module-created SG (if any).
#
#   security_group:  # (Optional) Module-managed Security Group and its rules.
#     create: true | false  # (Optional) Create a security group. Default: false.
#     rules:  # (Optional) Map of ingress/egress rules (key = rule id).
#       ssh-ingress:  # (Example rule key)
#         description: "Allow SSH"  # (Optional) Description. Default: "Rule for ${local.name} access".
#         type: "ingress" | "egress"  # (Optional) Rule direction. Default: "ingress".
#         protocol: "tcp" | "udp" | "icmp" | "-1"  # (Optional) Protocol. "-1" means all. Default: "-1".
#         from_port: 22  # (Optional) From port (or ICMP type). Default: 0.
#         to_port: 22  # (Optional) To port (or ICMP code). Default: 0.
#         cidr_blocks: ["0.0.0.0/0"]  # (Optional) IPv4 CIDR ranges. Provide one of cidr_blocks | ipv6_cidr_blocks | self | source_security_group_id.
#         ipv6_cidr_blocks: []  # (Optional) IPv6 CIDR ranges.
#         self: false  # (Optional) If true, the SG itself is a source/destination.
#         source_security_group_id: null  # (Optional) Source SG for ingress (mutually exclusive with cidr/self).
#
#   min_size: 1  # (Optional) Minimum number of instances in the ASG. Default: 1.
#   max_size: 2  # (Optional) Maximum number of instances in the ASG. Default: 1.
#   desired_capacity: 1  # (Optional) Desired capacity (alias: asg.desired). Default: 1.
#   health_check:  # (Optional) Health check configuration for the ASG.
#     type: "EC2" | "ELB"  # (Optional) Health check type. Default: "ELB".
#     grace_period: 300  # (Optional) Seconds to ignore unhealthy checks after launch. Default: 300.
#   force_delete: true | false  # (Optional) Force delete the ASG and all instances. Default: false.
#
#   mixed_instances: true | false  # (Optional) Use Mixed Instances Policy with overrides. Default: false.
#   instance_types:  # (Conditionally required) Overrides; required when mixed_instances = true.
#     - type: "t3a.micro"  # (Required) Instance type for this override.
#       capacity: "1"  # (Optional) Weighted capacity as string. Default: "1".
#
#   instance_refresh:  # (Optional) Rolling instance refresh strategy.
#     enabled: true | false  # (Optional) Enable instance refresh. Default: false.
#     strategy: "Rolling"  # (Optional) Refresh strategy. Allowed: "Rolling". Default: "Rolling".
#     min_healthy_percentage: 90  # (Optional) Minimum healthy percentage during refresh. Default: 90.
#     max_healthy_percentage: 100  # (Optional) Maximum healthy percentage during refresh. Default: null.
#     instance_warmup: 120  # (Optional) Warm-up time in seconds. Default: null.
#     triggers: ["launch_template", "tag"]  # (Optional) Events that trigger refresh. Default: null.
#
#   extra_tags:  # (Optional) Extra tags applied to instances (merged with common module tags).
#     Owner: "you@example.com"
#
#   backup:  # (Optional) Backup tagging for AWS Backup plan discovery.
#     enabled: true | false  # (Optional) Add backup discovery tags. Default: false.
#     only_tag: true | false  # (Optional) Apply only tags (no backup resources). Default: true.
#     schedule: hourly | daily | weekly | monthly  # (Optional) Tag to indicate backup schedule. Default: daily.
#
#   scaling_policies:  # (Optional) List of Auto Scaling policies to attach to the ASG.
#     - name: "cpu-target"  # (Required) Unique policy name key.
#       adjustment_type: "ChangeInCapacity" | "ExactCapacity" | "PercentChangeInCapacity"  # (Optional) For simple/step scaling. Default: "ChangeInCapacity".
#       scaling_adjustment: 1  # (Optional) Change amount for simple/step scaling.
#       cooldown: 300  # (Optional) Cooldown in seconds. Default: 300.
#       tracking_configuration:  # (Optional) Target tracking configuration.
#         target_value: 50.0  # (Required) Target value for the metric.
#         predefined:  # (Optional) Use a predefined ASG metric.
#           metric_type: "ASGAverageCPUUtilization" | "ASGAverageNetworkIn" | "ASGAverageNetworkOut" | "ALBRequestCountPerTarget"  # (Required) Metric type.
#           resource_label: "app/my-alb/50dc6c495c0c"  # (Optional) Required only for ALB metrics (format: app/<alb-name>/<alb-id>/<targetgroup-name>/<targetgroup-id>).
#         customized:  # (Optional) Use CloudWatch metric math/metrics.
#           metrics:  # (Optional) List of metric data queries.
#             - label: "MyMetric"  # (Optional) Label for the time series.
#               id: "m1"  # (Required) Unique within the policy.
#               expression: "m2 / m3"  # (Optional) Metric math expression. If omitted, supply metric_stat instead.
#               return_data: true  # (Optional) Whether to return this time series. Default: true.
#               metric_stat:  # (Conditionally required) Required when not using expression.
#                 metric:
#                   namespace: "AWS/EC2"  # (Required) Metric namespace.
#                   metric_name: "CPUUtilization"  # (Required) Metric name.
#                   dimensions: []  # (Optional) Metric dimensions as name/value pairs.
#                 stat: "Average"  # (Required) Statistic, e.g., Average | Sum | Maximum | Minimum | SampleCount.
#                 period: 60  # (Required) Period in seconds.
#                 unit: "Percent"  # (Optional) Unit for the metric.
#
#       predictive_scaling:  # (Optional) Predictive scaling configuration.
#         target_value: 50.0  # (Required) Target capacity utilization.
#         metric_pair:  # (Optional) Predefined pair metric for load vs. capacity.
#           metric_type: "ALBRequestCountPerTarget"  # (Required) Predefined pair type when used.
#           resource_label: "app/my-alb/50dc6c495c0c"  # (Required for ALB metrics) Resource label for the ALB target group.
#         customized_load:  # (Optional) Customized load metric.
#           id: "load1"  # (Required)
#           label: "Load"  # (Optional)
#           expression: null  # (Optional)
#           return_data: true  # (Optional) Default: true.
#           metric_stat:  # (Optional) CloudWatch metric-stat structure (period is unused by this module).
#             metric:
#               namespace: "AWS/EC2"
#               metric_name: "CPUUtilization"
#               dimensions: []
#             stat: "Average"
#             unit: "Percent"
#         customized_capacity:  # (Optional) Customized capacity metric.
#           id: "cap1"  # (Required)
#           label: "Capacity"  # (Optional)
#           expression: null  # (Optional)
#           return_data: true  # (Optional) Default: true.
#           metric_stat:
#             metric:
#               namespace: "AWS/EC2"
#               metric_name: "CPUUtilization"
#               dimensions: []
#             stat: "Average"
#             unit: "Percent"
#         customized_scaling:  # (Optional) Customized scaling metric.
#           data_queries:  # (Optional) List of metric data queries.
#             - id: "scale1"  # (Required)
#               label: "Scaling"  # (Optional)
#               expression: null  # (Optional)
#               return_data: true  # (Optional) Default: true.
#               metric_stat:
#                 metric:
#                   namespace: "AWS/EC2"
#                   metric_name: "CPUUtilization"
#                   dimensions: []
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
#   create: true | false  # (Optional) Create IAM role and instance profile and attach to instances. Default: true.
#   path: "/service-role/"  # (Optional) Path for the IAM role and instance profile. Default: null.
#   role_description: "Role for ${name}"  # (Optional) Description for the IAM role. Default: "IAM Instance Role ${local.name}".
#   permissions_boundary: "arn:aws:iam::...:policy/..."  # (Optional) ARN of the permissions boundary policy. Default: null.
#   role_policies:  # (Optional) Map of managed policy attachments (key = logical name, value = policy ARN).
#     CWAgent: "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
#   extra_tags:  # (Optional) Extra tags to apply to IAM resources.
#     Team: "Platform"
variable "iam" {
  description = "The IAM role to use for the EC2 Instance"
  type        = any
  default     = {}
}