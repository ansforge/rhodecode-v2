project = "forge/rhodecode/rhodecode-syncldap"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/rhodecode-v2.git"
        ref  = "var.datacenter"
	path = "rhodecode-syncldap/"
	ignore_changes_outside_path = true
    }
}

app "rhodecode-syncldap" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
			      disable_entrypoint = true
        }
        registry {
          use "docker" {
              image = "${var.registry_url}/${var.image}"
              tag = var.tag
              insecure = true
              username = var.registry_username
              password = var.registry_password
            }
        }
    }

    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/rhodecode-syncldap.nomad.tpl", {
              datacenter = var.datacenter
              image = var.image
              tag   = var.tag
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "dc1"
}

variable "image" {
    type    = string
    default = "ans/syncldap"
}

variable "tag" {
    type    = string
    default = "1.0.0"
}

variable "registry_url" {
  type = string
  default = ""
  env = ["REGISTRY"]
}

variable "registry_username" {
  type    = string
  default = ""
  env     = ["REGISTRY_USER"]
  # sensitive = true
}

variable "registry_password" {
  type    = string
  default = ""
  env     = ["REGISTRY_PASS"]
  # sensitive = true
}
