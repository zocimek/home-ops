terraform {
  cloud {
    organization = "zocimek"

    workspaces {
      name = "home-ops-pocket"
    }
  }
}