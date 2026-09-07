# Banco Gerenciado (RDS): remote state (S3 + trava DynamoDB).
#
# Configuracao PARCIAL de proposito: bucket / regiao / tabela de lock variam
# por conta AWS e nao devem ser fixados no codigo. Preencha em `init`:
#
#   Local:  terraform init -backend-config=backend.hcl   (copie de backend.hcl.example)
#   CI/CD:  o workflow injeta -backend-config=... (bucket, key por ambiente,
#           region, encrypt, dynamodb_table) — ver .github/workflows/*.yml
#
# A `key` NAO fica aqui: cada ambiente tem a sua
# (`oficina-infra-db/homolog.tfstate`, `oficina-infra-db/prod.tfstate`).
#
# Bootstrap (uma unica vez, fora deste Terraform — ver docs/AWS_ACADEMY_SETUP.md):
#   - bucket S3 com versionamento habilitado
#   - tabela DynamoDB com chave de particao `LockID` (String)
terraform {
  backend "s3" {
    encrypt = true
  }
}
