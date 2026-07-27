##
# (c) 2021-2026
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#


output "autoscaling_group_id" {
  description = "ID of the Auto Scaling Group when asg.create is true."
  value       = length(aws_autoscaling_group.this) > 0 ? aws_autoscaling_group.this[0].id : ""
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group when asg.create is true."
  value       = length(aws_autoscaling_group.this) > 0 ? aws_autoscaling_group.this[0].arn : ""
}

output "launch_template_id" {
  description = "ID of the Launch Template when asg.create is true."
  value       = length(aws_launch_template.this) > 0 ? aws_launch_template.this[0].id : ""
}

output "launch_template_arn" {
  description = "ARN of the Launch Template when asg.create is true."
  value       = length(aws_launch_template.this) > 0 ? aws_launch_template.this[0].arn : ""
}

output "iam_role" {
  description = "Created IAM instance profile, role name, and role ARN when iam.create is true."
  value = try(var.iam.create, true) ? {
    instance_profile = aws_iam_instance_profile.this[0].name
    role             = aws_iam_role.this[0].name
    role_arn         = aws_iam_role.this[0].arn
  } : {}
}

output "key_pair_name" {
  description = "Name of the generated AWS key pair when asg.key_pair.create is true."
  value       = try(var.asg.key_pair.create, false) ? aws_key_pair.this[0].key_name : ""
}

output "key_pair_public_key" {
  description = "Generated OpenSSH public key material when asg.key_pair.create is true."
  value       = try(var.asg.key_pair.create, false) ? tls_private_key.this[0].public_key_openssh : ""
  sensitive   = true
}

output "key_pair_ssh_private_key" {
  description = "Generated OpenSSH private key material when asg.key_pair.create is true."
  value       = try(var.asg.key_pair.create, false) ? tls_private_key.this[0].private_key_openssh : ""
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the managed security group when asg.security_group.create is true."
  value       = length(aws_security_group.this) > 0 ? aws_security_group.this[0].id : ""
}

output "security_group_name" {
  description = "Name of the managed security group when asg.security_group.create is true."
  value       = length(aws_security_group.this) > 0 ? aws_security_group.this[0].name : ""
}

output "cloudwatch_agent" {
  description = "CloudWatch Agent SSM associations, configuration parameter, managed policies, and ASG target tags."
  value = {
    enabled                         = local.cloudwatch_agent_enabled
    install_association_id          = try(aws_ssm_association.cloudwatch_agent_install[0].association_id, "")
    configure_association_id        = try(aws_ssm_association.cloudwatch_agent_configure[0].association_id, "")
    configuration_parameter_name    = try(aws_ssm_parameter.cloudwatch_agent_config[0].name, "")
    target_tag_key                  = local.cloudwatch_agent_target_tag_key
    target_tag_value                = local.cloudwatch_agent_target_tag_value
    workload_detection_enabled      = local.cloudwatch_agent_workload_detection_enabled
    attached_managed_policy_arns    = local.cloudwatch_agent_attached_managed_policy_arns
    ssm_association_target_key      = local.cloudwatch_agent_target_key
    ssm_association_target_values   = local.cloudwatch_agent_target_values
    configure_parameter_policy_name = try(aws_iam_role_policy.cloudwatch_agent_parameter[0].name, "")
  }
}
