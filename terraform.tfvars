nginx_image = "nginx:1.28-alpine"

nginx_containers = {
  www1 = { external_port = 5001, internal_port = 80 }
  www2 = { external_port = 5002, internal_port = 80 }
  www3 = { external_port = 5003, internal_port = 80 }
  www4 = { external_port = 5004, internal_port = 80 }
  www5 = { external_port = 5005, internal_port = 80 }
}
