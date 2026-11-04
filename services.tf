# Fase 4 (US-F4-03): uma instancia RDS por microsservico.
#
# Decisao do time (04/11): cada servico tem a PROPRIA instancia RDS, nao so
# um banco logico na instancia compartilhada. A instancia principal
# (aws_db_instance.this, database.tf) continua sendo a do OS Service —
# identifier, db_name `oficina_mecanica`, usuario `oficina` e o secret
# principal nao mudam (contrato do CD do os-service).
#
# Isolamento por instancia: o segredo de cada servico so carrega o host da
# propria instancia e cada instancia tem o proprio security group (network.tf)
# — nao ha como conectar cruzado. Sem CREATE DATABASE/ROLE via Job no EKS:
# o RDS cria banco e usuario master no proprio apply.
#
# Custo: uma db.t3.micro a mais por servico (Multi-AZ segue var.multi_az,
# igual a principal) — ver README > "Custo estimado".

resource "random_password" "service" {
  for_each = var.service_databases

  length  = 24
  special = false # alfanumerico: RDS proibe / @ " e espaco; evita escaping na URL
}

# Mesmos parametros da instancia principal (database.tf); so mudam
# identifier, db_name, usuario, senha, security group e tags.
resource "aws_db_instance" "service" {
  for_each = var.service_databases

  identifier = "${local.name_prefix}-${each.key}"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  db_name  = each.value.db_name
  username = each.value.username
  password = random_password.service[each.key].result
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.service[each.key].id]
  publicly_accessible    = false
  multi_az               = var.multi_az
  copy_tags_to_snapshot  = true

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = local.skip_final_snapshot
  final_snapshot_identifier = local.skip_final_snapshot ? null : "${local.name_prefix}-${each.key}-final-snapshot"
  apply_immediately         = local.apply_immediately

  auto_minor_version_upgrade = true

  monitoring_interval = local.monitoring_interval
  monitoring_role_arn = local.monitoring_role_arn

  # Mesma ressalva da instancia principal: engine_version="16" resolve para a
  # ultima minor no apply; ignorar drift de minor upgrades da AWS.
  lifecycle {
    ignore_changes = [engine_version]
  }

  tags = {
    Name    = "${local.name_prefix}-${each.key}"
    Servico = each.key
  }
}

resource "aws_secretsmanager_secret" "service" {
  for_each = var.service_databases

  name                    = "${local.name_prefix}/${each.key}/database"
  description             = "Credenciais da instancia RDS propria do servico ${each.key} (${var.environment}) - US-F4-03."
  recovery_window_in_days = 0

  tags = {
    Name    = "${local.name_prefix}-${each.key}-db-secret"
    Servico = each.key
  }
}

# Mesmo contrato de chaves do secret principal (DATABASE_URL, DB_*): o CD dos
# servicos (template do kit) le DATABASE_URL e monta o Secret k8s <svc>-db.
# DB_HOST/DATABASE_URL apontam para a instancia do proprio servico.
resource "aws_secretsmanager_secret_version" "service" {
  for_each = var.service_databases

  secret_id = aws_secretsmanager_secret.service[each.key].id

  secret_string = jsonencode({
    DATABASE_URL = "postgresql://${each.value.username}:${random_password.service[each.key].result}@${aws_db_instance.service[each.key].address}:${var.db_port}/${each.value.db_name}?schema=public"
    DB_HOST      = aws_db_instance.service[each.key].address
    DB_PORT      = tostring(var.db_port)
    DB_NAME      = each.value.db_name
    DB_USER      = each.value.username
    DB_PASSWORD  = random_password.service[each.key].result
  })
}
