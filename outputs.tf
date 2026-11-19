output "nginx_containers" {
  description = "Nginx container details"
  value = {
    for name, container in docker_container.nginx :
    name => {
      container_id = container.id
      container    = name
      host_port    = var.nginx_containers[name].external_port
      url          = "http://localhost:${var.nginx_containers[name].external_port}"
    }
  }
}

output "nginx_urls" {
  description = "Nginx test URLs"
  value = {
    for name, config in var.nginx_containers :
    name => "http://localhost:${config.external_port}"
  }
}
