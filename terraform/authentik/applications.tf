locals {
  oauth_apps = [
    "gitea",
    "grafana",
    "immich",
    "karakeep",
    "mealie",
    "open-webui",
    "opengist",
    "outline",
    "paperless",
    "qui",
  ]
}

module "onepassword_oauth" {
  for_each = toset(local.oauth_apps)

  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = each.key
}

######### Gitea #########
module "gitea" {
  source = "./modules/oidc-application"

  name   = "Gitea"
  domain = "gitea.pospiech.dev"
  group  = "Development"

  client_id     = module.onepassword_oauth["gitea"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["gitea"].fields["OIDC_CLIENT_SECRET"]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://gitea.pospiech.dev/user/oauth2/Authentik/callback"]

  auth_groups = [
    authentik_group.group["gitea_admins"].id,
    authentik_group.group["gitea_users"].id,
  ]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/gitea.png"
  meta_description = "Version control"
  meta_launch_url = "https://gitea.pospiech.dev/user/oauth2/Authentik"
}

######### GRAFANA #########
module "grafana" {
  source = "./modules/oidc-application"

  name   = "Grafana"
  domain = "grafana.pospiech.dev"
  group  = "Infrastructure"

  client_id     = module.onepassword_oauth["grafana"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["grafana"].fields["OIDC_CLIENT_SECRET"]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://grafana.pospiech.dev/login/generic_oauth"]

  auth_groups = [
    authentik_group.group["grafana_admins"].id,
    authentik_group.group["grafana_users"].id,
  ]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/grafana.png"
  meta_description = "Infrastructure monitoring"
  meta_launch_url = "https://grafana.pospiech.dev/login/generic_oauth"
}

######### IMMICH #########
module "immich" {
  source = "./modules/oidc-application"

  name   = "Immich"
  domain = "photos.pospiech.dev"
  group  = "Home"

  client_id     = module.onepassword_oauth["immich"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["immich"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["kids"].id,
    authentik_group.group["parents"].id,
    authentik_group.group["family"].id,
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://photos.pospiech.dev/auth/login", "app.immich:///oauth-callback", "https://photos.pospiech.dev/user-settings"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/immich.png"
  meta_description = "Photos management"
  meta_launch_url = "https://photos.pospiech.dev/auth/login"
}

######### KARAKEEP #########
module "karakeep" {
  source = "./modules/oidc-application"

  name   = "Karakeep"
  domain = "karakeep.pospiech.dev"
  group  = "Home"

  client_id     = module.onepassword_oauth["karakeep"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["karakeep"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["users"].id
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://karakeep.pospiech.dev/api/auth/callback/custom"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/karakeep.png"
  meta_description = "Bookmarks management & Memos"
  meta_launch_url = "https://karakeep.pospiech.dev/signin"
}

######### KARAKEEP #########
module "qui" {
  source = "./modules/oidc-application"

  name   = "Qui"
  domain = "qui.pospiech.dev"
  group  = "Download"

  client_id     = module.onepassword_oauth["qui"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["qui"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["download_admins"].id
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://qui.pospiech.dev/api/auth/oidc/callback"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/qui.png"
  meta_description = "Modern download manager"
  meta_launch_url = "https://qui.pospiech.dev/"
}

######### MEALIE #########
module "mealie" {
  source = "./modules/oidc-application"

  name   = "mealie"
  domain = "recipies.pospiech.dev"
  group  = "Home"

  client_id     = module.onepassword_oauth["mealie"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["mealie"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["users"].id,
    authentik_group.group["mealie_admins"].id
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://recipies.pospiech.dev/login", "https://recipies.pospiech.dev/login?direct=1"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/mealie.png"
  meta_description = "Recipes"
  meta_launch_url = "https://recipies.pospiech.dev/login"
}

######### OPEN-WEBUI #########
module "open-webui" {
  source = "./modules/oidc-application"

  name   = "open-webui"
  domain = "chat.pospiech.dev"
  group  = "Home"

  client_id     = module.onepassword_oauth["open-webui"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["open-webui"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["family"].id
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://chat.pospiech.dev/oauth/oidc/callback"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/open-webui.png"
  meta_description = "AI Chat"
  meta_launch_url = "https://chat.pospiech.dev/auth/login"
}

######### OpenGist #########
module "opengist" {
  source = "./modules/oidc-application"

  name   = "OpenGist"
  domain = "opengist.pospiech.dev"
  group  = "Development"

  client_id     = module.onepassword_oauth["opengist"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["opengist"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["users"].id
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://opengist.pospiech.dev/oauth/openid-connect/callback"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/opengist.png"
  meta_description = "Code snippets"
  meta_launch_url = "https://opengist.pospiech.dev/oauth/openid-connect"
}

######### OUTLINE #########
module "outline" {
  source = "./modules/oidc-application"

  name   = "Outline"
  domain = "docs.pospiech.dev"
  group  = "Home"

  client_id     = module.onepassword_oauth["outline"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["outline"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["family"].id
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://docs.pospiech.dev/auth/oidc.callback"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/outline.png"
  meta_description = "Documentation & Journaling"
  meta_launch_url = "https://docs.pospiech.dev/auth/oidc"
}

######### PAPERLESS #########
module "paperless" {
  source = "./modules/oidc-application"

  name   = "Paperless"
  domain = "documents.pospiech.dev"
  group  = "Home"

  client_id     = module.onepassword_oauth["paperless"].fields["OIDC_CLIENT_ID"]
  client_secret = module.onepassword_oauth["paperless"].fields["OIDC_CLIENT_SECRET"]

  auth_groups = [
    authentik_group.group["parents"].id,
    authentik_group.group["kids"].id,
    authentik_group.group["paperless_users"].id,
    authentik_group.group["paperless_admins"].id,
  ]

  authentication_flow = authentik_flow.authentication.uuid
  authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

  redirect_uris = ["https://documents.pospiech.dev/accounts/oidc/sso/login/callback/"]

  meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/paperless.png"
  meta_description = "Documents"
  meta_launch_url = "https://documents.pospiech.dev/accounts/oidc/sso/login/"
}

######### matrix #########
# module "matrix" {
#   source = "./modules/oidc-application"

#   name   = "Matrix"
#   domain = "opengist.pospiech.dev"
#   group  = authentik_group.group["monitoring"].name

#   client_id     = "synapse"
#   client_secret = module.onepassword_oauth.fields.OPENGIST_OAUTH_CLIENT_SECRET

#   authentication_flow = authentik_flow.authentication.uuid
#   authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid

#   redirect_uris = ["https://matrix.pospiech.dev/_synapse/client/oidc/callback"]

#   meta_icon       = "https://cdn.jsdelivr.net/gh/walkxcode/dashboard-icons/png/matrix.png"
#   meta_launch_url = "https://opengist.pospiech.dev/oauth/openid-connect"
# }
