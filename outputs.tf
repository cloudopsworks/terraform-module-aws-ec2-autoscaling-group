##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#


output "autoscaling_group_id" {
  value = length(aws_autoscaling_group.this) > 0 ? aws_autoscaling_group.this[0].id : ""
}

output "launch_template_id" {
  value = length(aws_launch_template.this) > 0 ? aws_launch_template.this[0].id : ""
}

output "iam_role" {
  value = try(var.iam.create, true) ? {
    instance_profile = aws_iam_instance_profile.this[0].name
    role             = aws_iam_role.this[0].name
    role_arn         = aws_iam_role.this[0].arn
  } : {}
}

output "key_pair_name" {
  value = try(var.asg.key_pair.create, false) ? aws_key_pair.this[0].key_name : ""
}

output "key_pair_public_key" {
  value     = try(var.asg.key_pair.create, false) ? tls_private_key.this[0].public_key_openssh : ""
  sensitive = true
}

output "key_pair_ssh_private_key" {
  value     = try(var.asg.key_pair.create, false) ? tls_private_key.this[0].private_key_openssh : ""
  sensitive = true
}

output "security_group_id" {
  value = length(aws_security_group.this) > 0 ? aws_security_group.this[0].id : ""
}

output "security_group_name" {
  value = length(aws_security_group.this) > 0 ? aws_security_group.this[0].name : ""
}
