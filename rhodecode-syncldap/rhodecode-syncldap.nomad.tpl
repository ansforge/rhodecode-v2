job "rhodecode-syncldap" {
  datacenters = ["${datacenter}"]
  type = "batch"
  periodic {
    cron             = "*/15 * * * * *"
    prohibit_overlap = true
  }
  vault {
    policies = ["forge"]
    change_mode = "restart"
  }
  group "rhodecode-syncldap" {
    task "rhodecode-syncldap" {
      driver = "docker"
      config {
        image = "${image}:${tag}"
      }
      template {
        data = <<EOH
LDAP_BIND_DN="{{with secret "forge/rhodecode/ldap"}}{{.Data.data.bind_dn}}{{end}}"
LDAP_BIND_PASSWORD="{{with secret "forge/rhodecode/ldap"}}{{.Data.data.bind_password}}{{end}}"
RHODECODE_AUTH_TOKEN="{{with secret "forge/rhodecode/api"}}{{.Data.data.auth_token}}{{end}}"
{{range service ("rhodecode-http") }}RHODECODE_API_URL="http://{{.Address}}:{{.Port}}/_admin/api"{{end}}
{{range service ("ldap-forge") }}LDAP_URL="ldap://{{.Address}}:389"{{end}}
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
  }
}
