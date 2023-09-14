job "rhodecode-tools" {
        datacenters = ["${datacenter}"]
        type = "batch"
		periodic {
			cron             = "0 1 * * * *"
			prohibit_overlap = true
		}

        vault {
                policies = ["forge"]
                change_mode = "restart"
    }

        group "rhodecode-tools" {
                count = "1"
               # install only on "data" nodes
                constraint {
                                attribute = "$\u007Bnode.class\u007D"
                                value     = "data"
                }

                restart {
                                attempts = 3
                                delay = "60s"
                                interval = "1h"
                                mode = "fail"
                }
                task "rhodecode-index" {

                        driver = "docker"
                        template {
                                data = <<EOT
[DEFAULT]
debug = false
[app:main]
search.module = rhodecode.lib.index.whoosh
search.location = /var/opt/rhodecode_data/index
EOT
                                destination = "local/rhodecode.optimized.ini"
                        }

                        template {
                                data =<<EOT
[instance:community]
api_key = {{with secret "forge/rhodecode/api"}}{{.Data.data.auth_token}}{{end}}
api_host = {{ range service "rhodecode-http" }}http://{{ .Address }}:{{ .Port }}{{ end }}
EOT
                                destination = "local/.rhoderc"
                        }
                        template {
                                data =<<EOT
API_KEY={{with secret "forge/rhodecode/api"}}{{.Data.data.auth_token}}{{end}}
SSL_CERT_FILE="/etc/rhodecode/conf_build/ca-bundle.crt"
MAIN_INI_PATH="/local/rhodecode.optimized.ini"
EOT
                                destination="secrets/rc.env"
                                env = true
                        }
                        template {
                                data =<<EOT
/home/rhodecode/.rccontrol/community-1/profile/bin/rhodecode-index --api-host={{ range service "rhodecode-http" }}http://{{ .Address }}:{{ .Port }}{{ end }} --api-key=$API_KEY && /home/rhodecode/.rccontrol/community-1/profile/bin/rhodecode-index --optimize --api-host={{ range service "rhodecode-http" }}http://{{ .Address }}:{{ .Port }}{{ end }} --api-key=$API_KEY
EOT
                                destination="local/run.sh"
                        }
                        config {
                                image = "${image}:${tag}"
                                command = "sh"
                                args = [ "/local/run.sh" ]
                                mount {
                                        type = "bind"
                                        target = "/root/.rhoderc"
                                        source = "local/.rhoderc"
                                        readonly = false
                                        bind_options {
                                                propagation = "rshared"
                                        }
                                }
                                mount {
                                  type = "volume"
                                  target = "/var/opt/rhodecode_data"
                                  source = "rhodecode-data2"
                                  readonly = false
                                  volume_options {
                                        no_copy = false
                                        driver_config {
                                          name = "pxd"
                                          options {
                                                io_priority = "high"
                                                shared = true
                                                size = 10
                                                repl = 2
                                          }
                                        }
                                  }
                                }

                        }
                        resources {
                                        cpu = 512
                                        memory = 1024
                        }
                }
        }
}
