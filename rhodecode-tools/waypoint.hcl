project = "forge/rhodecode/rhodecode-tools"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    profile = "${workspace.name}"
    data_source "git" {
        url  = "https://github.com/ansforge/rhodecode-v2.git"
        ref  = "henix_docker_platform_pfcpx"
		path = "rhodecode-tools/"
		ignore_changes_outside_path = true
    }
}

app "rhodecode-tools" {

    build {
        use "docker-ref" {
            image = var.image
            tag   = var.tag
		    # disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/rhodecode-tools.nomad.tpl", {
              datacenter = var.datacenter
              image = var.image
              tag   = var.tag
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "henix_docker_platform_pfcpx"
    # 
    env = ["NOMAD_DATACENTER"]
}

variable "nomad_namespace" {
    type = string
    default = "default"
    
    env = ["NOMAD_NAMESPACE"]
}
#

variable "image" {
    type    = string
    default = "ans/rhodecode-app"
}

variable "tag" {
    type    = string
    default = "4.26.0"
}
