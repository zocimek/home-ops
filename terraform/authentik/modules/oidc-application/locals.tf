locals {
  client_secret = (
    var.client_type == "confidential" ? var.client_secret : null
  )

  allowed_redirect_uris = [
    for uri in var.redirect_uris : (
      can(uri.url) ? {
        matching_mode = lookup(uri, "matching_mode", "strict")
        url           = uri.url
        } : {
        matching_mode = "strict"
        url           = trim(uri, " ")
      }
    )
  ]
}