##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
# Establish this is a HUB or spoke configuration
##
# is_hub: false # (Optional) Is this a hub or spoke configuration? Default: false.
variable "is_hub" {
  description = "Is this a hub or spoke configuration?"
  type        = bool
  default     = false
}

##
# spoke_def: "001" # (Optional) Spoke ID Number, must be a 3 digit number. Default: "001".
variable "spoke_def" {
  description = "Spoke ID Number, must be a 3 digit number"
  type        = string
  default     = "001"
  validation {
    condition     = (length(var.spoke_def) == 3) && tonumber(var.spoke_def) != null
    error_message = "The spoke_def must be a 3 digit number as string."
  }
}

##
# org: # (Required) Organization details.
#   organization_name: "my-org" # (Required) Organization name.
#   organization_unit: "my-unit" # (Required) Organization unit.
#   environment_type: "prod" # (Required) Environment type.
#   environment_name: "my-env" # (Required) Environment name.
variable "org" {
  description = "Organization details"
  type = object({
    organization_name = string
    organization_unit = string
    environment_type  = string
    environment_name  = string
  })
}

##
# extra_tags: {} # (Optional) Extra tags to add to the resources. Default: {}.
variable "extra_tags" {
  description = "Extra tags to add to the resources"
  type        = map(string)
  default     = {}
}
