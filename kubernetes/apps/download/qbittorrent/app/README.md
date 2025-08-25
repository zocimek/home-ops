# If you want to use quad9 use following in corefile

forward . tls://9.9.9.9 tls://149.112.112.112 {
        tls_servername dns.quad9.net
        policy sequential
        health_check 5s
    }