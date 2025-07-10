  moved {
    from = authentik_group.users
    to   = authentik_group.group["users"]
  }
  
  moved {
    from = authentik_group.infrastructure
    to   = authentik_group.group["infrastructure"]
  }
  
  moved {
    from = authentik_group.monitoring
    to   = authentik_group.group["monitoring"]
  }
  
  moved {
    from = authentik_group.applications
    to   = authentik_group.group["applications"]
  }