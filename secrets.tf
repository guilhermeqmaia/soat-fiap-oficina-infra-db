# Banco Gerenciado (RDS): senha e segredo de conexao.
#
# Contrato de saida (chaves ESTAVEIS — ver CLAUDE.md): DATABASE_URL, DB_HOST,
# DB_PORT, DB_NAME, DB_USER, DB_PASSWORD. Mesmas chaves do Secret k8s
# `oficina-db` da Fase 2, para o External Secrets (US-F3-06) mapear 1:1 sem
# alterar os manifestos da app nem do Job de migrations.

resource "random_password" "db" {
  length  = 24
  special = false # alfanumerico: RDS proibe / @ " e espaco; evita escaping na URL
}

resource "aws_secretsmanager_secret" "db" {
  name        = local.secret_name
  description = "Credenciais de conexao do RDS PostgreSQL (${var.environment}) - US-F3-04."

  # Lab: permite recriar o secret no mesmo nome sem esperar a janela de
  # recuperacao de 7-30 dias. Em prod real, subir para >= 7.
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name_prefix}-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    DATABASE_URL = "postgresql://${var.db_username}:${random_password.db.result}@${aws_db_instance.this.address}:${var.db_port}/${var.db_name}?schema=public"
    DB_HOST      = aws_db_instance.this.address
    DB_PORT      = tostring(var.db_port)
    DB_NAME      = var.db_name
    DB_USER      = var.db_username
    DB_PASSWORD  = random_password.db.result
  })
}
