resource "pocketid_group" "this" {
  for_each    = { for g in var.groups : g.id => g }

  name        = each.value.id
  friendly_name = each.value.name
}

resource "pocketid_user" "this" {
  for_each = { for u in local.users : u["username"] => u }

  username   = each.value["username"]
  email      = each.value["email"]
  first_name = each.value["first_name"]
  last_name  = each.value["last_name"]
  is_admin   = lookup(each.value, "is_admin", false)
  disabled   = lookup(each.value, "disabled", false)

  groups = [
    for group_id in each.value["groups"] : pocketid_group.this[group_id].id
  ]
}

resource "pocketid_client" "this" {
  for_each = { for c in var.clients : c.name => c }

  name                 = each.value.name
  callback_urls        = each.value.callback_urls
  logout_callback_urls = lookup(each.value, "logout_callback_urls", [])
  is_public            = lookup(each.value, "is_public", false)
  pkce_enabled         = lookup(each.value, "is_public", false) # match is_public
  allowed_user_groups = [
    for group_id in concat(lookup(each.value, "allowed_user_groups", []), ["administrators"]) :
    pocketid_group.this[group_id].id
  ]
}

data "onepassword_vault" "this" {
  name = "Kubernetes"
}

resource "onepassword_item" "oidc_secrets" {
  vault    = data.onepassword_vault.this.uuid
  title    = "oauth-secrets"
  category = "password"

  dynamic "section" {
    for_each = pocketid_client.this

    content {
      label = upper(section.key)  # Section name like GITEA or VAULT

      dynamic "field" {
        for_each = {
          "${upper(section.key)}_CLIENT_ID"     = section.value.id
          "${upper(section.key)}_CLIENT_SECRET" = section.value.client_secret
        }

        content {
          label = field.key
          type  = "CONCEALED"
          value = field.value
        }
      }
    }
  }
}