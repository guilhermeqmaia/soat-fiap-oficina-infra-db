# Banco Gerenciado (RDS): locals derivados.

locals {
  is_prod     = var.environment == "prod"
  name_prefix = "${var.project_name}-${var.environment}"

  # Overrides explicitos vencem; senao, default seguro por ambiente.
  deletion_protection = var.deletion_protection != null ? var.deletion_protection : local.is_prod
  skip_final_snapshot = var.skip_final_snapshot != null ? var.skip_final_snapshot : !local.is_prod
  apply_immediately   = var.apply_immediately != null ? var.apply_immediately : !local.is_prod

  # Nome fixo (nao gerado por timestamp): evita diff a cada plan. Se a
  # instancia for recriada, remova/renomeie o snapshot anterior antes do
  # proximo destroy (ver README > "Recriar a instancia").
  final_snapshot_identifier = "${local.name_prefix}-final-snapshot"

  secret_name = "${local.name_prefix}/database"

  monitoring_interval = var.enable_enhanced_monitoring ? 60 : 0
  monitoring_role_arn = var.enable_enhanced_monitoring ? var.lab_role_arn : null
}
