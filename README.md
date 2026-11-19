# Terraform Docker Nginx 5 Containers และตัวอย่าง Infrastructure Drift

## เป้าหมาย

Lab นี้ใช้ Terraform Docker Provider สร้าง Nginx 5 Containers:

| Container | Host port | Container port | URL |
|---|---:|---:|---|
| www1 | 5001 | 80 | http://localhost:5001 |
| www2 | 5002 | 80 | http://localhost:5002 |
| www3 | 5003 | 80 | http://localhost:5003 |
| www4 | 5004 | 80 | http://localhost:5004 |
| www5 | 5005 | 80 | http://localhost:5005 |

Code ตัวอย่างแยกอยู่ในไฟล์ ZIP ที่ดาวน์โหลดพร้อมเอกสารนี้

## โครงสร้างไฟล์

```text
terraform-docker-nginx/
├── versions.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── check-nginx.ps1
├── .gitignore
└── README.md
```

## Code หลัก

### versions.tf

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.7.0"
    }
  }
}
```

### main.tf

```hcl
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = true
}

resource "docker_container" "nginx" {
  for_each = var.nginx_containers
  name     = each.key
  image    = docker_image.nginx.image_id
  restart  = "unless-stopped"

  ports {
    ip       = "0.0.0.0"
    internal = each.value.internal_port
    external = each.value.external_port
    protocol = "tcp"
  }

  labels { label = "managed-by"; value = "terraform" }
  labels { label = "service"; value = each.key }
  labels { label = "environment"; value = "lab" }
}
```

สำหรับ Docker Desktop บน Windows เปลี่ยน `host` เป็น:

```hcl
host = "npipe:////./pipe/docker_engine"
```

### terraform.tfvars

```hcl
nginx_image = "nginx:1.28-alpine"
nginx_containers = {
  www1 = { external_port = 5001, internal_port = 80 }
  www2 = { external_port = 5002, internal_port = 80 }
  www3 = { external_port = 5003, internal_port = 80 }
  www4 = { external_port = 5004, internal_port = 80 }
  www5 = { external_port = 5005, internal_port = 80 }
}
```

## Deploy

```powershell
docker version
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out="nginx.tfplan"
terraform apply "nginx.tfplan"
```

ตรวจสอบ:

```powershell
docker ps --filter "label=managed-by=terraform"
curl.exe -I http://localhost:5001
curl.exe -I http://localhost:5002
curl.exe -I http://localhost:5003
curl.exe -I http://localhost:5004
curl.exe -I http://localhost:5005
```

ตรวจ State:

```powershell
terraform state list
terraform state show 'docker_container.nginx["www1"]'
terraform state pull | Set-Content -Encoding utf8 terraform-state-backup.json
```

# ตัวอย่าง Drift 5 รูปแบบ

> ทดลองทีละกรณีและคืนระบบให้เรียบร้อยก่อนทำกรณีถัดไป

## 1. Stop www1

```powershell
docker stop www1
terraform plan
terraform apply
```

Terraform ควรทำให้ `www1` กลับมาทำงาน เพราะ Code กำหนด Desired State ให้ Container ทำงาน

## 2. Delete www2

```powershell
docker rm -f www2
terraform plan
terraform apply
```

Terraform จะพบว่า Resource ที่อยู่ใน State หายจากระบบจริง และวางแผนสร้าง `www2` ใหม่

## 3. เปลี่ยน Port ของ www3 เป็น 6003

```powershell
docker rm -f www3
docker run --detach --name www3 --restart unless-stopped --publish 6003:80 --label managed-by=terraform --label service=www3 --label environment=lab nginx:1.28-alpine
terraform plan
```

คืนค่าตาม Code:

```powershell
docker rm -f www3
terraform apply
curl.exe -I http://localhost:5003
```

ถ้าต้องการยอมรับ Port 6003 ให้เปลี่ยน `external_port` ของ `www3` ใน `terraform.tfvars` เป็น `6003` แล้วตรวจ Plan อย่างละเอียด เนื่องจาก Published Port มักทำให้ Container ถูก Replace

## 4. เปลี่ยน Restart Policy ของ www4

```powershell
docker update --restart=no www4
docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' www4
terraform plan
```

คืนค่าตาม Code:

```powershell
terraform apply
```

หากต้องการเก็บค่าใหม่ ให้แก้ `restart = "no"` ใน Code จากนั้นใช้:

```powershell
terraform plan -refresh-only -out="refresh-only.tfplan"
terraform apply "refresh-only.tfplan"
terraform plan
```

## 5. สร้าง www5 ใหม่ด้วย Apache httpd

```powershell
docker rm -f www5
docker run --detach --name www5 --restart unless-stopped --publish 5005:80 --label managed-by=manual --label service=www5 --label environment=lab httpd:2.4-alpine
docker inspect --format '{{.Config.Image}}' www5
terraform plan
```

คืนค่าเป็น Nginx:

```powershell
docker rm -f www5
terraform apply
docker inspect --format '{{.Config.Image}}' www5
```

Terraform ผูก Resource กับ Docker Container ID ไม่ใช่ชื่อเพียงอย่างเดียว ดังนั้นการลบและสร้างชื่อเดิมถือเป็น Object คนละตัว

# Workflow ตรวจ Drift ที่แนะนำ

## Backup State

```powershell
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
terraform state pull | Set-Content -Path "terraform-state-$Timestamp.json" -Encoding utf8
```

## ตรวจความต่างระหว่าง State เดิมกับระบบจริง

```powershell
terraform plan -refresh-only -out="refresh-only.tfplan"
terraform show "refresh-only.tfplan"
```

## ให้ระบบจริงกลับมาตรงกับ Code

```powershell
terraform plan -out="restore.tfplan"
terraform apply "restore.tfplan"
```

## ยอมรับการแก้ไขจากระบบจริง

```powershell
terraform apply "refresh-only.tfplan"
```

จากนั้นต้องแก้ `.tf` หรือ `.tfvars` ให้ตรงกับค่าที่ต้องการเก็บ และตรวจซ้ำ:

```powershell
terraform fmt -recursive
terraform validate
terraform plan
```

เป้าหมายควรเป็น:

```text
No changes. Your infrastructure matches the configuration.
```

# ลบ Lab

```powershell
terraform plan -destroy
terraform destroy
```

# เอกสารอ้างอิง

- Docker Provider: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs
- Docker container resource: https://github.com/kreuzwerker/terraform-provider-docker/blob/master/docs/resources/container.md
- Terraform refresh-only: https://developer.hashicorp.com/terraform/tutorials/state/refresh

# Terraform Docker Nginx Lab

สร้าง Nginx 5 containers (`www1`-`www5`) ที่ host ports `5001`-`5005`.

## Run

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out="nginx.tfplan"
terraform apply "nginx.tfplan"
./check-nginx.ps1
```

สำหรับ Docker Desktop บน Windows ให้แก้ `provider "docker"` ใน `main.tf` เป็น:

```hcl
host = "npipe:////./pipe/docker_engine"
```

## Drift labs

1. Stop: `docker stop www1`
2. Delete: `docker rm -f www2`
3. Replace port: ลบ `www3` แล้วสร้างใหม่ด้วย `-p 6003:80`
4. Restart policy: `docker update --restart=no www4`
5. Replace image: ลบ `www5` แล้วสร้างใหม่ด้วย `httpd:2.4-alpine`

ตรวจด้วย `terraform plan -refresh-only` และคืนค่าตาม Code ด้วย `terraform plan` ตามด้วย `terraform apply`.

## Cleanup

```powershell
terraform destroy
```
