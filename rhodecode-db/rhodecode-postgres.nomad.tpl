job "rhodecode-postgres" {
  datacenters = ["${datacenter}"]
  type = "service"
  vault {
    policies = ["forge"]
    change_mode = "restart"
  }

  group "rhodecode-postgres" {
    count = 1
    restart {
      attempts = 3
      delay = "60s"
      interval = "1h"
      mode = "fail"
    }

    constraint {
      attribute = "$\u007Bnode.class\u007D"
      value     = "data"
    }

    update {
      max_parallel      = 1
      min_healthy_time  = "30s"
      progress_deadline = "5m"
      healthy_deadline  = "2m"
    }

    network {
      port "db" { to = 5432 }
    }

    task "rhodecode-postgres" {
      driver = "docker"

      # log-shipper
      leader = true 

                template {
                        data = <<EOH
POSTGRES_DB = "rhodecode"
POSTGRES_USER = {{ with secret "forge/rhodecode/postgres" }}{{ .Data.data.postgres_user }}{{ end }}
POSTGRES_PASSWORD = {{ with secret "forge/rhodecode/postgres" }}{{ .Data.data.postgres_pass }}{{ end }}
POSTGRES_HOST_AUTH_METHOD = "md5"
EOH
                        destination = "secrets/.env"
                        change_mode = "restart"
                        env = true
                }
                config {
                        image = "${image}:${tag}"
                        ports = ["db"]
                        mount {
                                type = "volume"
                                target = "/var/lib/postgresql/data"
                                source = "rhodecode-pgdata"
                                readonly = false
                                volume_options {
                                        no_copy = false
                                        driver_config {
                                                name = "pxd"
                                                options {
                                                        io_priority = "high"
                                                        size = 25
                                                        repl = 2
                                                }
                                        }
                                }
                        }
                        mount {
                                type = "bind"
                                target = "/var/log/rhodecode"
                                source = "tmp"
                                readonly = false
                                bind_options {
                                        propagation = "rshared"
                                }
                        }
                }
      resources {
        cpu    = 600
        memory = 2048
      }
      service {
        name = "$\u007BNOMAD_JOB_NAME\u007D"
        port = "db"
        check {
          name         = "alive"
          type         = "tcp"
          interval     = "30s"
          timeout      = "5s"
          failures_before_critical = 5
          port         = "db"
        }
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
