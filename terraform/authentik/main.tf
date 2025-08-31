terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
      version = "2025.8.0"
    }
  }
}

module "secret_authentik" {
  # Remember to export OP_CONNECT_HOST and OP_CONNECT_TOKEN
  source = "github.com/bjw-s/terraform-1password-item?ref=main"
  vault  = "Kubernetes"
  item   = "authentik"
}

provider "authentik" {
  url   = module.secret_authentik.fields["ENDPOINT_URL"]
  token = module.secret_authentik.fields["TERRAFORM_TOKEN"]
}

locals {
  cluster_domain = "pospiech.dev"
}