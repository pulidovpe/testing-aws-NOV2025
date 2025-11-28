# 2-technical-test-aws-NOV2025

Resumen
-------
Repositorio Terraform que despliega una VPC mínima y una aplicación en ECS Fargate (cluster, task, service) usando un repositorio ECR existente para las imágenes. El entorno de ejemplo está en `terraform/envs/test` y el código reutiliza los módulos `vpc` y `ecs` en `terraform/modules`.

Estructura relevante
--------------------
- `terraform/envs/test/` — configuración del entorno `test` (variables, `main.tf`, `providers.tf`, outputs).
- `terraform/modules/vpc/` — módulo para VPC, subnets y security groups.
- `terraform/modules/ecs/` — módulo para ECS (cluster, task, service, ALB, target group).
- `.github/deploy.yaml` — GitHub Actions workflow ejemplo que construye/escanea/pusha la imagen y ejecuta Terraform deploy.

Puntos importantes
------------------
- El módulo ECS referencia un repositorio ECR existente mediante `data.aws_ecr_repository`; no crea ni destruye el repositorio. Asegúrate de que el repositorio ECR indicado por `ecr_repository_name` ya exista y el usuario/rol que ejecuta Terraform tenga permisos `ecr:DescribeRepositories` y permisos para aplicar `aws_ecr_lifecycle_policy` si deseas gestionar la política de ciclo de vida.
- Health-check del ALB está configurado en `/health` (timeout e interval configurables en el módulo). La imagen debe exponer un endpoint `/health` que devuelva HTTP 200 cuando la app está lista.

Requisitos
----------
- `terraform` (compatible con la versión usada en el repo — revisa el `backend/test.hcl` o el workflow de CI).
- Credenciales AWS con permisos para crear los recursos definidos (VPC, subnets, ALB, ECS, IAM roles, CloudWatch logs, etc.).
- Si usas el workflow de GitHub Actions: rol OIDC configurado y permisos para ECR + Terraform deploy.

Quickstart local (entorno `test`)
---------------------------
1. Sitúate en el directorio del entorno:
```bash
cd terraform/envs/test
```

2. Configura credenciales AWS (ejemplo):
```bash
export AWS_ACCESS_KEY_ID=YOUR_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET
export AWS_DEFAULT_REGION=us-east-1
```

3. Revisa `variables.tf` y define variables necesarias. Hay un fichero `terraform.tfvars` de ejemplo en otros repos que puedes adaptar aquí; en este repo debes crear tu propio `terraform.tfvars` o pasar variables por `-var`.

4. Inicializa Terraform con el backend de test:
```bash
terraform init -reconfigure -backend-config=../../backend/test.hcl
```

5. Plan y apply:
```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

6. Para destruir:
```bash
terraform destroy -var-file="terraform.tfvars"
```

Variables importantes (`terraform/envs/test/variables.tf`)
--------------------------------------------------------
- `Project`, `Region`, `Environment`
- VPC: `vpc_name`, `vpc_cidr`, `availability_zones_to_use`, `create_public_subnets`, `create_private_subnets`, `nat_gateway_configuration`, `enable_https_from_world`, `enable_ssh_from_world`, `ipv6_support`, `allowed_ingress_cidr`, `force_public_subnet_name`
- ECS: `cluster_name`, `service_name`, `ecr_repository_name` (nombre del repo ECR existente), `desired_count`, `image_tag` (por defecto `latest`)

Notas sobre ECR y permisos
-------------------------
- El módulo asume que el repositorio ECR existe. Si quieres que Terraform cree el repo, modifica el módulo para usar `resource "aws_ecr_repository"` en lugar de `data`.
- Para el workflow de CI/CD (`.github/deploy.yaml`) asegúrate de que la acción `aws-actions/configure-aws-credentials` esté configurada con un rol que permita: `ecr:GetAuthorizationToken`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload` y permisos de Terraform (crear/actualizar recursos en la cuenta/region).

Notas de seguridad y operaciones
-------------------------------
- `enable_ssh_from_world` en `test` puede estar activado para pruebas rápidas; no lo dejes activo en entornos de producción.
- Revisa y adapta `terraform/backend/*.hcl` si vas a usar un backend remoto (S3 + DynamoDB) para estado compartido.
