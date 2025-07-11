terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
    }
  }
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

data "authentik_property_mapping_provider_scope" "scopes" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-offline_access"
  ]
}

resource "authentik_provider_oauth2" "main" {
  name                       = var.name
  client_id                  = var.client_id
  client_secret              = local.client_secret
  authorization_flow         = var.authorization_flow
  # authentication_flow        = var.authentication_flow
  invalidation_flow          = var.invalidation_flow
  signing_key                = data.authentik_certificate_key_pair.generated.id
  client_type                = var.client_type
  include_claims_in_id_token = var.include_claims_in_id_token
  issuer_mode                = var.issuer_mode
  sub_mode                   = var.sub_mode
  access_token_validity      = var.access_token_validity
  refresh_token_validity     = var.refresh_token_validity
  property_mappings          = concat(data.authentik_property_mapping_provider_scope.scopes.ids, var.additional_property_mappings)
  allowed_redirect_uris      = local.allowed_redirect_uris
}

resource "authentik_application" "main" {
  name              = var.name
  slug              = lower(var.name)
  group              = var.group
  protocol_provider = authentik_provider_oauth2.main.id
  meta_icon         = var.meta_icon
  meta_description  = var.meta_description
  meta_launch_url   = coalesce(var.meta_launch_url, "https://${var.domain}")
  open_in_new_tab   = var.open_in_new_tab
}

resource "authentik_policy_binding" "main" {
  target = authentik_application.main.uuid
  group  = var.auth_groups[count.index]
  order  = count.index
  count  = length(var.auth_groups)
}