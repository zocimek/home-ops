clients = [
  {
    name                = "grafana"
    callback_urls       = ["https://grafana.pospiech.dev/login/generic_oauth"]
    is_public           = false
    allowed_user_groups = ["grafana_users", "grafana_administrators"]
  },
  {
    name                = "gitea"
    callback_urls       = ["https://gitea.pospiech.dev/user/oauth2/PocketID/callback"]
    is_public           = false
    allowed_user_groups = ["gitea_users"]
  },

  {
    name                = "immich"
    callback_urls       = ["https://photos.pospiech.dev/auth/login", "app.immich:///oauth-callback", "https://photos.pospiech.dev/user-settings"]
    is_public           = false
    allowed_user_groups = ["family"]
  },
]