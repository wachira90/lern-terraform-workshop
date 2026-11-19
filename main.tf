provider "docker" {
  # Linux Docker Engine
  host = "unix:///var/run/docker.sock"

  # For Docker Desktop on Windows, replace the line above with:
  # host = "npipe:////./pipe/docker_engine"
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "nginx" {
  for_each = var.nginx_containers

  name  = each.key
  image = docker_image.nginx.image_id

  restart = "unless-stopped"

  ports {
    ip       = "0.0.0.0"
    internal = each.value.internal_port
    external = each.value.external_port
    protocol = "tcp"
  }

  labels {
    label = "managed-by"
    value = "terraform"
  }

  labels {
    label = "service"
    value = each.key
  }

  labels {
    label = "environment"
    value = "lab"
  }
}
