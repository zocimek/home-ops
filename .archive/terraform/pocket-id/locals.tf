locals {
  users = yamldecode(nonsensitive(data.sops_file.users_yaml.raw))["users"]
}