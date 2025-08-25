variable "groups" {
  type = list(object({
    id = string
    name = string
  }))
  default = []
  description = "List of groups to be created"
}

variable "users" {
  type = list(object({
    username   = string
    email      = string
    first_name = string
    last_name  = string
    is_admin   = optional(bool, false)
    disabled   = optional(bool, false)
    groups     = list(string) # List of group *ids* like ["devs", "ops"]
  }))
  default = []
  description = "List of users to be created"
}

variable "clients" {
  type = list(object({
    name                 = string                         # used as client_id
    callback_urls        = list(string)
    logout_callback_urls = optional(list(string))
    is_public            = optional(bool, false)
    allowed_user_groups  = optional(list(string), [])
  }))
  description = "List of OAuth clients to create"
}