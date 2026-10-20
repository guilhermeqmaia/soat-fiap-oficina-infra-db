# Fase 4 (US-F4-03 / RFC-0007): DynamoDB single-table do Execucao Service.
#
# Modelo (ver RFC-0007): PK/SK genericos; GSI1 = fila por status
# (GSI1PK="FILA#<status>", GSI1SK=<ts>); GSI2 = OS por mecanico
# (GSI2PK="MECANICO#<id>"). TTL (`ttl`) para os itens MSG# de deduplicacao.
# Streams NEW_AND_OLD_IMAGES = base do outbox do servico (ADR-0009).
resource "aws_dynamodb_table" "execucao" {
  count = var.dynamodb_table_name != "" ? 1 : 0

  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST" # free tier: 25 GB + 25 WCU/RCU equivalentes

  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }
  attribute {
    name = "SK"
    type = "S"
  }
  attribute {
    name = "GSI1PK"
    type = "S"
  }
  attribute {
    name = "GSI1SK"
    type = "S"
  }
  attribute {
    name = "GSI2PK"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI2"
    hash_key        = "GSI2PK"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  deletion_protection_enabled = local.deletion_protection

  tags = {
    Name    = var.dynamodb_table_name
    Servico = "execucao"
  }
}

# Acesso do Execucao Service a tabela — sem IRSA, via role dos nodes
# (mesmo modelo do stage messaging do infra-k8s).
data "aws_iam_policy_document" "dynamodb_execucao" {
  count = var.dynamodb_table_name != "" ? 1 : 0

  statement {
    sid    = "TabelaExecucao"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem", "dynamodb:DescribeTable",
      "dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams",
    ]
    resources = [
      aws_dynamodb_table.execucao[0].arn,
      "${aws_dynamodb_table.execucao[0].arn}/index/*",
      "${aws_dynamodb_table.execucao[0].arn}/stream/*",
    ]
  }
}

resource "aws_iam_policy" "dynamodb_execucao" {
  count = var.dynamodb_table_name != "" ? 1 : 0

  name        = "${local.name_prefix}-dynamodb-execucao"
  description = "Acesso do Execucao Service a tabela ${var.dynamodb_table_name} (RFC-0007)."
  policy      = data.aws_iam_policy_document.dynamodb_execucao[0].json
}

resource "aws_iam_role_policy_attachment" "dynamodb_nodes" {
  count = var.dynamodb_table_name != "" && var.node_role_name != "" ? 1 : 0

  role       = var.node_role_name
  policy_arn = aws_iam_policy.dynamodb_execucao[0].arn
}

resource "aws_ssm_parameter" "dynamodb_table" {
  count = var.dynamodb_table_name != "" ? 1 : 0

  name  = "/oficina/dynamodb/execucao/table_name"
  type  = "String"
  value = aws_dynamodb_table.execucao[0].name
}
