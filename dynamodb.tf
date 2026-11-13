# Fase 4 (US-F4-07): tabelas DynamoDB do Execucao Service.
#
# Uma tabela por agregado (nomes = var.dynamodb_table_prefix + nome base),
# espelhando src/dynamodb/definicoes-tabelas.ts do execucao-service:
# - execucoes             PK osId          (1 item por OS, servicos/pecas embutidos)
# - servicos              PK servicoId     (catalogo)
# - produtos              PK produtoId     (catalogo + saldo quantidadeEstoque)
# - movimentacoes_estoque PK movimentacaoId (auditoria BAIXA/DEVOLUCAO/ENTRADA)
#     GSI produtoId-data-index (extrato do produto), osId-data-index (rollback da OS)
# Baixa/devolucao = TransactWriteItems (Update em produtos com ConditionExpression
# + Put em movimentacoes_estoque), feito pela aplicacao.
locals {
  dynamodb_tabelas = var.dynamodb_enabled ? {
    execucoes = {
      hash_key  = "osId"
      atributos = ["osId"]
      indices   = []
    }
    servicos = {
      hash_key  = "servicoId"
      atributos = ["servicoId"]
      indices   = []
    }
    produtos = {
      hash_key  = "produtoId"
      atributos = ["produtoId"]
      indices   = []
    }
    movimentacoes_estoque = {
      hash_key  = "movimentacaoId"
      atributos = ["movimentacaoId", "produtoId", "osId", "data"]
      indices = [
        { name = "produtoId-data-index", hash_key = "produtoId", range_key = "data" },
        { name = "osId-data-index", hash_key = "osId", range_key = "data" },
      ]
    }
  } : {}
}

resource "aws_dynamodb_table" "execucao_tabelas" {
  for_each = local.dynamodb_tabelas

  name         = "${var.dynamodb_table_prefix}${each.key}"
  billing_mode = "PAY_PER_REQUEST" # free tier: 25 GB + 25 WCU/RCU equivalentes
  hash_key     = each.value.hash_key

  dynamic "attribute" {
    for_each = each.value.atributos
    content {
      name = attribute.value
      type = "S"
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.value.indices
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = "ALL"
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = local.deletion_protection

  tags = {
    Name    = "${var.dynamodb_table_prefix}${each.key}"
    Servico = "execucao"
  }
}

# A single-table `oficina-execucao` (RFC-0007) foi substituida pelas tabelas
# acima. `removed` tira a tabela antiga do state SEM destrui-la (pode ter
# deletion protection); apague-a manualmente depois de conferir que esta vazia.
removed {
  from = aws_dynamodb_table.execucao

  lifecycle {
    destroy = false
  }
}

# Acesso do Execucao Service as tabelas — sem IRSA, via role dos nodes.
# TransactWriteItems nao e uma acao IAM: exige Put/Update/ConditionCheck por item.
data "aws_iam_policy_document" "dynamodb_execucao" {
  count = var.dynamodb_enabled ? 1 : 0

  statement {
    sid    = "TabelasExecucao"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem",
      "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem", "dynamodb:DescribeTable",
    ]
    resources = flatten([
      for t in aws_dynamodb_table.execucao_tabelas : [t.arn, "${t.arn}/index/*"]
    ])
  }
}

resource "aws_iam_policy" "dynamodb_execucao" {
  count = var.dynamodb_enabled ? 1 : 0

  name        = "${local.name_prefix}-dynamodb-execucao"
  description = "Acesso do Execucao Service as tabelas ${var.dynamodb_table_prefix}* (US-F4-07)."
  policy      = data.aws_iam_policy_document.dynamodb_execucao[0].json
}

resource "aws_iam_role_policy_attachment" "dynamodb_nodes" {
  count = var.dynamodb_enabled && var.node_role_name != "" ? 1 : 0

  role       = var.node_role_name
  policy_arn = aws_iam_policy.dynamodb_execucao[0].arn
}

# O servico le DYNAMODB_TABLE_PREFIX (k8s ConfigMap); publicado aqui para o CD.
resource "aws_ssm_parameter" "dynamodb_table_prefix" {
  count = var.dynamodb_enabled ? 1 : 0

  name  = "/oficina/dynamodb/execucao/table_prefix"
  type  = "String"
  value = var.dynamodb_table_prefix
}

# Parametro antigo (single-table) sai do state sem ser apagado.
removed {
  from = aws_ssm_parameter.dynamodb_table

  lifecycle {
    destroy = false
  }
}
