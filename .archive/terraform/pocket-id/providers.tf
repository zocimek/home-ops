terraform {
  required_providers {
    pocketid = {
      source  = "trozz/pocketid"
      version = "~> 0.1.2"
    }
    sops = {
      source = "carlpett/sops"
      version = "1.3.0"
    }
    onepassword = {
      source = "1Password/onepassword"
      version = "~> 3.1.0"
    }
  }
}

# Configure the Pocket-ID Provider

provider "pocketid" {}