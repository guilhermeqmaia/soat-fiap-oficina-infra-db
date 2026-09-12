# Banco Gerenciado (RDS): DB subnet group e security group.
# VPC / subnets / SGs do EKS chegam via variaveis (outputs do repo 2).
# Sem exposicao publica: subnets privadas + ingresso restrito.

resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds"
  description = "Acesso ao RDS PostgreSQL - apenas nodes do EKS e a Lambda de auth, dentro da VPC. Egress: allow-all default da SG."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-rds"
  }
}

# Ingresso a partir de security groups (nodes do EKS, Lambda de auth).
resource "aws_security_group_rule" "rds_ingress_sg" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = each.value
  description              = "Postgres a partir do security group ${each.value}"
}

# Ingresso a partir de CIDRs (ex.: CIDR da VPC), quando informado.
resource "aws_security_group_rule" "rds_ingress_cidr" {
  count = length(var.allowed_cidr_blocks) > 0 ? 1 : 0

  type              = "ingress"
  from_port         = var.db_port
  to_port           = var.db_port
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = var.allowed_cidr_blocks
  description       = "Postgres a partir dos CIDRs liberados"
}
