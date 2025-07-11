module "onepassword_apple" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "apple-2-oauth"
}

module "onepassword_google" {
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "google-oauth"
}

resource "authentik_source_oauth" "apple" {
  name                = "Apple"
  slug                = "apple"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = authentik_flow.enrollment-invitation.uuid
  user_matching_mode  = "identifier"

  provider_type   = "apple"
  consumer_key    = module.onepassword_apple.fields.CLIENT_ID
  consumer_secret = module.onepassword_apple.fields.CLIENT_SECRET

  oidc_well_known_url  = "https://appleid.apple.com/.well-known/openid-configuration"
  access_token_url  = "https://appleid.apple.com/auth/token"
  authorization_url = "https://appleid.apple.com/auth/authorize"
  oidc_jwks_url     = "https://appleid.apple.com/auth/keys"
  # profile_url       = "https://openidconnect.googleapis.com/v1/userinfo"
}

resource "authentik_source_oauth" "google" {
  name                = "Google"
  slug                = "google"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = authentik_flow.enrollment-invitation.uuid
  user_matching_mode  = "email_link"

  provider_type   = "google"
  consumer_key    = module.onepassword_google.fields.CLIENT_ID
  consumer_secret = module.onepassword_google.fields.CLIENT_SECRET

  access_token_url  = "https://oauth2.googleapis.com/token"
  authorization_url = "https://accounts.google.com/o/oauth2/v2/auth"
  oidc_jwks_url     = "https://www.googleapis.com/oauth2/v3/certs"
  profile_url       = "https://openidconnect.googleapis.com/v1/userinfo"
}