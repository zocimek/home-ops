data "sops_file" "users_yaml" {
  source_file = "${path.module}/users.sops.yaml"
}