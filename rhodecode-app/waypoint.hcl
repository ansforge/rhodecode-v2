project = "forge/rhodecode/rhodecode-app"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/rhodecode-v2.git"
        ref  = "var.datacenter"
	path = "rhodecode-app/"
	ignore_changes_outside_path = true
    }
}

app "rhodecode-app" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
	    disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/rhodecode-community.nomad.tpl", {
				datacenter = var.datacenter
				image = var.image
				tag = var.tag
				image2 = var.image2
				tag2 = var.tag2
				cpu = var.cpu
				memory = var.memory
				extensions_url = var.extensions_url
				
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "dc1"
}

variable "cpu" {
    type    = string
    default = "1024"
}

variable "memory" {
    type    = string
    default = "7168"
}

variable "extensions_url" {
    type    = string
    default = "http://repo.proxy-dev-forge.asip.hst.fluxus.net/artifactory/ext-tools/rhodecode/rcextensions-1.0.zip"
}

variable "image" {
    type    = string
    default = "ans/rhodecode-app"
}

variable "tag" {
    type    = string
    default = "4.26.0"
}

variable "image2" {
    type    = string
    default = "ans/rhodecode-redis"
}

variable "tag2" {
    type    = string
    default = "6.2.6"
}
