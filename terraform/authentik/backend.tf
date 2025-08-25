terraform {
  cloud {
    organization = "zocimek"

    workspaces {
      name = "homelab-authentik"
    }
  }
}