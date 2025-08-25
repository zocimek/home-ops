variable "name" {
  type = string
}

variable "domain" {
  type = string
}
variable "access_token_validity" {
  type    = string
  default = "weeks=8"
}
variable "refresh_token_validity" {
  type    = string
  default = "weeks=52"
}
variable "authorization_flow" {
  type = string
}
variable "authentication_flow" {
  type = string
}

variable "invalidation_flow" {
  type = string
}

variable "meta_icon" {
  type    = string
  default = null
}
variable "meta_description" {
  type    = string
  default = null
}
variable "meta_launch_url" {
  type    = string
  default = null
}
variable "open_in_new_tab" {
  type    = bool
  default = true
}
variable "group" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type      = string
  sensitive = true
}

variable "signing_key_id" {
  type    = string
  default = null
}

variable "client_type" {
  type    = string
  default = "confidential"
}
variable "redirect_uris" {
  type = list(any)
}

variable "include_claims_in_id_token" {
  type    = bool
  default = true
}

variable "issuer_mode" {
  type    = string
  default = "per_provider"
}

variable "sub_mode" {
  type    = string
  default = "hashed_user_id"
}

variable "auth_groups" {
  type = list(string)
  default = []
}

variable "additional_property_mappings" {
  type    = list(string)
  default = []
}