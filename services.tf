# Fase 4 (US-F4-03): credenciais e segredos por microsservico.
#
# Mesma instancia RDS (custo), bancos e usuarios separados (isolamento):
# o usuario de cada servico so recebe CONNECT no proprio banco — o acesso
# cruzado falha com "permission denied" (teste negativo no README).
#
# O CREATE DATABASE/ROLE acontece DENTRO do Postgres, que e privado na VPC:
# o Terraform (CI) nao o alcanca. Por isso o SQL roda como Job no EKS
# (k8s/db-bootstrap-job.yaml via scripts/db-bootstrap.sh), lendo daqui as
# senhas pelo Secrets Manager. Idempotente.

resource "random_password" "service" {
  for_each = var.service_databases

  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "service" {
  for_each = var.service_databases

  name                    = "${local.name_prefix}/${each.key}/database"
  description             = "Credenciais do banco proprio do servico ${each.key} (${var.environment}) - US-F4-03."
  recovery_window_in_days = 0

  tags = {
    Name    = "${local.name_prefix}-${each.key}-db-secret"
    Servico = each.key
  }
}

# Mesmo contrato de chaves do secret principal (DATABASE_URL, DB_*): o CD dos
# servicos (template do kit) le DATABASE_URL e monta o Secret k8s <svc>-db.
resource "aws_secretsmanager_secret_version" "service" {
  for_each = var.service_databases

  secret_id = aws_secretsmanager_secret.service[each.key].id

  secret_string = jsonencode({
    DATABASE_URL = "postgresql://${each.value.username}:${random_password.service[each.key].result}@${aws_db_instance.this.address}:${var.db_port}/${each.value.db_name}?schema=public"
    DB_HOST      = aws_db_instance.this.address
    DB_PORT      = tostring(var.db_port)
    DB_NAME      = each.value.db_name
    DB_USER      = each.value.username
    DB_PASSWORD  = random_password.service[each.key].result
  })
}
