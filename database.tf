# Banco Gerenciado (RDS): instancia PostgreSQL Multi-AZ.

resource "aws_db_instance" "this" {
  identifier = local.name_prefix

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_type          = "gp3"
  storage_encrypted     = var.storage_encrypted

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = var.multi_az
  copy_tags_to_snapshot  = true

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = local.skip_final_snapshot
  final_snapshot_identifier = local.skip_final_snapshot ? null : local.final_snapshot_identifier
  apply_immediately         = local.apply_immediately

  auto_minor_version_upgrade = true

  monitoring_interval = local.monitoring_interval
  monitoring_role_arn = local.monitoring_role_arn

  # AWS Academy: sem role IAM propria (apenas LabRole). Performance Insights e
  # IAM DB Authentication ficam desligados de proposito — exigiriam KMS/role
  # que o Learner Lab costuma bloquear.

  # engine_version="16" resolve para a ultima minor no apply; a AWS pode
  # aplicar minor upgrades depois. Apos o 1o apply, considere fixar a minor
  # exata (terraform show) para evitar drift.
  lifecycle {
    ignore_changes = [engine_version]
  }

  tags = {
    Name = local.name_prefix
  }
}
