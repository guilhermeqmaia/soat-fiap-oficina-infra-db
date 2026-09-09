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
