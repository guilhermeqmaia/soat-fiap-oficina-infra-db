# Banco Gerenciado (RDS): outputs.
# Nenhuma senha / DATABASE_URL em texto plano aqui — apenas endpoint e
# referencia ao secret, consumidos via Secrets Manager / External Secrets.

output "db_instance_id" {
  description = "Identificador da instancia RDS."
  value       = aws_db_instance.this.id
}

output "db_endpoint" {
  description = "Endpoint (host:port) da instancia RDS."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Host (sem porta) da instancia RDS."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Porta do Postgres."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nome do database."
  value       = var.db_name
}

output "db_security_group_id" {
  description = "Security group do RDS — referenciar ao liberar novos consumidores."
  value       = aws_security_group.rds.id
}

output "db_subnet_group_name" {
  description = "DB subnet group criado para a instancia."
  value       = aws_db_subnet_group.this.name
}

output "secret_arn" {
  description = "ARN do secret no Secrets Manager com DATABASE_URL e campos de conveniencia."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Nome do secret no Secrets Manager (chave para o External Secrets do repo 4)."
  value       = aws_secretsmanager_secret.db.name
}


# ─── Fase 4 (US-F4-03) ────────────────────────────────────────────────────────

output "service_secret_arns" {
  description = "ARN do secret (DATABASE_URL exclusiva) de cada servico — var DB_SECRET_ID no repo do servico."
  value       = { for k, s in aws_secretsmanager_secret.service : k => s.arn }
}

output "service_secret_names" {
  description = "Nome do secret de cada servico no Secrets Manager."
  value       = { for k, s in aws_secretsmanager_secret.service : k => s.name }
}

output "service_db_addresses" {
  description = "Host (sem porta) da instancia RDS propria de cada servico (svc => address)."
  value       = { for k, db in aws_db_instance.service : k => db.address }
}

output "service_db_instance_ids" {
  description = "Identificador da instancia RDS propria de cada servico (svc => id)."
  value       = { for k, db in aws_db_instance.service : k => db.id }
}

output "service_db_security_group_ids" {
  description = "Security group da instancia RDS de cada servico (svc => sg id) — referenciar ao liberar novos consumidores."
  value       = { for k, sg in aws_security_group.service : k => sg.id }
}

output "dynamodb_table_prefix" {
  description = "Prefixo das tabelas do Execucao Service (DYNAMODB_TABLE_PREFIX no repo do servico)."
  value       = var.dynamodb_enabled ? var.dynamodb_table_prefix : null
}

output "dynamodb_table_names" {
  description = "Nome de cada tabela DynamoDB do Execucao Service (base => nome completo)."
  value       = { for k, t in aws_dynamodb_table.execucao_tabelas : k => t.name }
}

output "dynamodb_table_arns" {
  description = "ARN de cada tabela DynamoDB do Execucao Service."
  value       = { for k, t in aws_dynamodb_table.execucao_tabelas : k => t.arn }
}
