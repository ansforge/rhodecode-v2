job "rhodecode-syncldap" {
  datacenters = ["${datacenter}"]
  type = "batch"
  periodic {
    cron             = "0 * * * * *"
    prohibit_overlap = true
  }
  vault {
    policies = ["forge"]
    change_mode = "restart"
  }
  group "rhodecode-syncldap" {
    task "rhodecode-syncldap" {
      driver = "docker"

      # log-shipper
      leader = true 

      config {
        image = "${image}:${tag}"
      }
      template {
        data = <<EOH
LDAP_BIND_DN="{{with secret "forge/rhodecode/ldap"}}{{.Data.data.bind_dn}}{{end}}"
LDAP_BIND_PASSWORD="{{with secret "forge/rhodecode/ldap"}}{{.Data.data.bind_password}}{{end}}"
RHODECODE_AUTH_TOKEN="{{with secret "forge/rhodecode/api"}}{{.Data.data.auth_token}}{{end}}"
{{range service ("rhodecode-http") }}RHODECODE_API_URL="http://{{.Address}}:{{.Port}}/_admin/api"{{end}}
{{range service ("openldap-forge") }}LDAP_URL="ldap://{{.Address}}:{{.Port}}"{{end}}
        EOH
        destination = "secrets/file.env"
        change_mode = "restart"
        env         = true
      }
      resources {
        cpu    = 100
        memory = 64
      }
    }

    # log-shipper
    task "log-shipper" {
        driver = "docker"
        restart {
                interval = "3m"
                attempts = 5
                delay    = "15s"
                mode     = "delay"
        }
        meta {
            INSTANCE = "$\u007BNOMAD_ALLOC_NAME\u007D"
        }
        template {
            data = <<EOH
REDIS_HOSTS = {{ range service "PileELK-redis" }}{{ .Address }}:{{ .Port }}{{ end }}
PILE_ELK_APPLICATION = RHODECODE 
EOH
            destination = "local/file.env"
            change_mode = "restart"
            env = true
        }
        config {
            image = "ans/nomad-filebeat:8.2.3-2.0"
        }
        resources {
            cpu    = 100
            memory = 150
        }
    } #end log-shipper 

  }
}
