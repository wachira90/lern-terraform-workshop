variable "nginx_image" {
  description = "Docker image for Nginx"
  type        = string
  default     = "nginx:1.28-alpine"
}

variable "nginx_containers" {
  description = "Nginx containers and host ports"
  type = map(object({
    external_port = number
    internal_port = number
  }))

  validation {
    condition = alltrue([
      for container in values(var.nginx_containers) :
      container.external_port >= 1024 && container.external_port <= 65535
    ])
    error_message = "external_port must be between 1024 and 65535."
  }

  validation {
    condition = length(distinct([
      for container in values(var.nginx_containers) : container.external_port
    ])) == length(var.nginx_containers)
    error_message = "Each external_port must be unique."
  }
}
