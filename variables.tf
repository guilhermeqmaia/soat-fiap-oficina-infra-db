# Banco Gerenciado (RDS): variaveis de entrada.

variable "aws_region" {
  description = "Regiao AWS. O Learner Lab da AWS Academy opera em us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos nomes dos recursos (instancia RDS, secret, security group)."
  type        = string
  default     = "oficina-mecanica"
}

variable "environment" {
  description = "Ambiente (homolog|prod). Condiciona deletion_protection, skip_final_snapshot e apply_immediately."
  type        = string

  validation {
    condition     = contains(["homolog", "prod"], var.environment)
    error_message = "environment deve ser 'homolog' ou 'prod'."
  }
}

# --- Rede: outputs do repo 2 (soat-fiap-oficina-infra-k8s) -------------------
# Cross-repo via variaveis (tfvars / TF_VAR_*), nao terraform_remote_state:
# repos e backends distintos.

variable "vpc_id" {
  description = "VPC do cluster EKS, onde o RDS e o security group serao criados."
  type        = string

  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "vpc_id deve ser o ID de uma VPC (vpc-...)."
  }
}

variable "subnet_ids" {
  description = "Subnets PRIVADAS da VPC do EKS para o DB subnet group. Minimo 2, em AZs distintas (requisito do Multi-AZ)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Informe ao menos 2 subnets privadas (AZs distintas) para habilitar Multi-AZ."
  }
}

variable "allowed_security_group_ids" {
  description = "Security groups com ingresso liberado na porta do Postgres: nodes do EKS (repo 2) e a Lambda de auth por CPF (repo 1). Vazio => nenhum ingresso por SG (use allowed_cidr_blocks)."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "CIDRs com ingresso liberado na porta do Postgres (alternativa/complemento a allowed_security_group_ids — ex.: CIDR da VPC). Vazio => nenhum ingresso por CIDR."
  type        = list(string)
  default     = []
}

variable "lab_role_arn" {
  description = "ARN da LabRole do AWS Academy. Usado apenas quando enable_enhanced_monitoring = true (Enhanced Monitoring exige uma role). Vazio no uso normal."
  type        = string
  default     = ""
}

# --- Banco -----------------------------------------------------------------

variable "db_name" {
  description = "Nome do database Postgres. Igual as Fases 1-2 para nao quebrar o contrato do Prisma."
  type        = string
  default     = "oficina_mecanica"
}

variable "db_username" {
  description = "Usuario master da instancia RDS."
  type        = string
  default     = "oficina"
}

variable "db_port" {
  description = "Porta do Postgres."
  type        = number
  default     = 5432
}

variable "engine_version" {
  description = "Versao major do PostgreSQL (RDS resolve a ultima minor). Major 16 = mesma da Fase 2 (postgres:16-alpine) — compativel com as migrations Prisma."
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "Classe da instancia RDS. db.t3.micro cobre a carga do Tech Challenge dentro do orcamento do Learner Lab."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Armazenamento inicial (GiB), gp3."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Teto do storage autoscaling (GiB). 0 desabilita o autoscaling."
  type        = number
  default     = 100
}

variable "storage_encrypted" {
  description = "Criptografia em repouso com a chave gerenciada aws/rds. Desligue apenas se a conta do lab bloquear KMS."
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Alta disponibilidade com standby em outra AZ (requisito da US-F3-04)."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Retencao dos backups automaticos (dias). 0 desabilita backups."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Janela diaria de backup, UTC (hh24:mi-hh24:mi)."
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Janela semanal de manutencao, UTC (ddd:hh24:mi-ddd:hh24:mi) — fora da janela de backup."
  type        = string
  default     = "mon:04:30-mon:05:30"
}

variable "deletion_protection" {
  description = "Bloqueia destroy/delete da instancia. null => true em prod, false em homolog."
  type        = bool
  default     = null
}

variable "skip_final_snapshot" {
  description = "Pula o snapshot final ao destruir. null => false em prod (sempre tira snapshot), true em homolog."
  type        = bool
  default     = null
}

variable "apply_immediately" {
  description = "Aplica mudancas de configuracao na hora em vez de esperar a maintenance window. null => true em homolog, false em prod (evita failover)."
  type        = bool
  default     = null
}

variable "enable_enhanced_monitoring" {
  description = "Liga o Enhanced Monitoring do RDS. Requer lab_role_arn preenchido (a role precisa da policy AmazonRDSEnhancedMonitoringRole)."
  type        = bool
  default     = false
}
