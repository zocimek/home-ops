terraform {
  required_providers {
    pocketid = {
      source  = "trozz/pocketid"
      version = "~> 0.1.2"
    }
    sops = {
      source = "carlpett/sops"
      version = "1.2.1"
    }
    onepassword = {
      source = "1Password/onepassword"
      version = "~> 2.2.0"
    }
  }
}

# Configure the Pocket-ID Provider

provider "pocketid" {}