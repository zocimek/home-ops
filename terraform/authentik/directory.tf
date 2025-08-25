data "authentik_group" "admins" {
  name = "authentik Admins"
}


locals {
  groups = [
    "users",
    "gitea_users",
    "gitea_admins",
    "grafana_users",
    "grafana_admins",
    "paperless_admins",
    "paperless_users",
    "mealie_admins",
    "family",
    "parents",
    "kids"
  ]

  default_groups = [
    authentik_group.group["users"].id
  ]

  parents_groups = [
    authentik_group.group["family"].id,
    authentik_group.group["parents"].id,
  ]

  kids_groups = [
    authentik_group.group["family"].id,
    authentik_group.group["kids"].id,
  ]

  admin_groups = [
    data.authentik_group.admins.id,
    authentik_group.group["gitea_admins"].id,
    authentik_group.group["grafana_admins"].id,
    authentik_group.group["paperless_admins"].id,
    authentik_group.group["mealie_admins"].id,
  ]
}

resource "authentik_group" "group" {
  for_each = toset(local.groups)

  name        = each.key
  is_superuser = false
}

module "onepassword_zocimek" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "lukasz-credentials"
}

resource "authentik_user" "zocimek" {
  username = module.onepassword_zocimek.fields.username
  name     = module.onepassword_zocimek.fields.FULLNAME
  email    = module.onepassword_zocimek.fields.EMAIL
  password = module.onepassword_zocimek.fields.password
  groups = flatten(concat(
    local.default_groups,
    local.parents_groups,
    local.admin_groups
  ))
}

module "onepassword_monika" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "monika-credentials"
}

resource "authentik_user" "monika" {
  username = module.onepassword_monika.fields.username
  name     = module.onepassword_monika.fields.FULLNAME
  email    = module.onepassword_monika.fields.EMAIL
  password = module.onepassword_monika.fields.password
  groups = flatten(concat(
    local.default_groups,
    local.parents_groups
  ))
}

module "onepassword_emilia" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "emilia-credentials"
}

resource "authentik_user" "emilia" {
  username = module.onepassword_emilia.fields.username
  name     = module.onepassword_emilia.fields.FULLNAME
  email    = module.onepassword_emilia.fields.EMAIL
  password = module.onepassword_emilia.fields.password
  groups = flatten(concat(
    local.default_groups,
    local.kids_groups
  ))
}

module "onepassword_oliwier" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "oliwier-credentials"
}

resource "authentik_user" "oliwier" {
  username = module.onepassword_oliwier.fields.username
  name     = module.onepassword_oliwier.fields.FULLNAME
  email    = module.onepassword_oliwier.fields.EMAIL
  password = module.onepassword_oliwier.fields.password
  groups = flatten(concat(
    local.default_groups,
    local.kids_groups
  ))
}