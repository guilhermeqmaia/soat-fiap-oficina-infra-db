# Rodar o `infra-db` no AWS Academy (Learner Lab)

Passo a passo para provisionar o **RDS PostgreSQL** deste repositório no AWS
Academy — manualmente e, principalmente, **pela pipeline** (`cd.yml` faz o
`terraform apply`).

O Learner Lab impõe restrições que moldam todo o setup:

| Restrição | Consequência aqui |
|---|---|
| Região fixa **us-east-1** | `aws_region` default já é `us-east-1` |
| Credenciais temporárias (expiram em ~3–4h) | Renovar `AWS_SESSION_TOKEN` a cada sessão, local e nos secrets do GitHub |
| **Não** pode criar IAM roles/users | Usa a **`LabRole`** existente; o design não exige role (Enhanced Monitoring fica off por default) |
| Sem OIDC para GitHub | CI/CD autentica com **access key + session token** |
| Orçamento limitado | `db.t3.micro`, `destroy` ao fim de cada sessão |

---

## 0. Pré-requisitos

- Repositório **2** (`soat-fiap-oficina-infra-k8s`) já aplicado — dele saem
  `vpc_id`, as **subnets privadas** e o **security group dos nodes do EKS**.
- Repositório **1** (`soat-fiap-oficina-auth-lambda`) — dele sai o security
  group da Lambda de auth (se já existir; senão pode adicionar depois).
- `terraform >= 1.9`, `aws` CLI v2 e (opcional) `gh` CLI instalados.

Anote os outputs do repo 2:

```bash
# no diretório do repo 2
terraform output -raw vpc_id
terraform output -json private_subnet_ids   # ["subnet-...","subnet-..."]
terraform output -raw eks_nodes_security_group_id
```

---

## 1. Pegar as credenciais do Learner Lab

1. No painel do AWS Academy: **Start Lab** → aguardar o círculo ficar verde.
2. Clicar em **AWS Details** → **AWS CLI: Show** → copiar o bloco
   `aws_access_key_id` / `aws_secret_access_key` / `aws_session_token`.
3. Colar em `~/.aws/credentials` (perfil `default`) **ou** exportar:

```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_DEFAULT_REGION=us-east-1

aws sts get-caller-identity   # confirma a sessão
```

> As credenciais mudam **toda vez** que o lab é reiniciado. Repita este passo
> (e o passo 5, dos secrets do GitHub) sempre que a sessão expirar.

---

## 2. Bootstrap do remote state (uma vez por conta)

O backend S3 precisa existir **antes** do primeiro `terraform init`. Crie o
bucket (com versionamento) e a tabela de lock manualmente:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="oficina-mecanica-tfstate-${ACCOUNT_ID}"
LOCK_TABLE="oficina-mecanica-tf-locks"

aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

aws dynamodb create-table \
  --table-name "$LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "TF_STATE_BUCKET=$BUCKET"
echo "TF_STATE_LOCK_TABLE=$LOCK_TABLE"
```

> A tabela DynamoDB é **opcional** — sem ela o state ainda funciona, só não
> há trava contra applies concorrentes. O repo tem `concurrency` no `cd.yml`
> como proteção adicional.

---

## 3. Aplicar localmente (opcional — bom para validar antes do CI)

```bash
cp backend.hcl.example backend.hcl
#   bucket         = "oficina-mecanica-tfstate-<ACCOUNT_ID>"
#   key            = "oficina-infra-db/homolog.tfstate"
#   region         = "us-east-1"
#   dynamodb_table = "oficina-mecanica-tf-locks"

cp terraform.tfvars.example terraform.tfvars
#   environment                = "homolog"
#   vpc_id                     = "vpc-..."            (output repo 2)
#   subnet_ids                 = ["subnet-...","subnet-..."]  (privadas, repo 2)
#   allowed_security_group_ids = ["sg-eks-nodes","sg-lambda-auth"]
#   # ou, se ainda não tiver os SGs:
#   # allowed_cidr_blocks      = ["10.0.0.0/16"]      (CIDR da VPC)

terraform init -backend-config=backend.hcl
terraform plan
terraform apply      # ~8–15 min (Multi-AZ)

terraform output db_endpoint
terraform output secret_name
```

Para destruir ao fim da sessão:

```bash
terraform destroy
```

Em `prod` o `deletion_protection` fica `true` — desligue antes:
`terraform apply -var deletion_protection=false` e depois `destroy`.

---

## 4. Configurar o GitHub para a pipeline deployar

**Settings → Secrets and variables → Actions.**

### Secrets (aba *Secrets*)

| Secret | Valor | Renovar? |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | do *AWS Details* | **a cada sessão do lab** |
| `AWS_SECRET_ACCESS_KEY` | do *AWS Details* | **a cada sessão do lab** |
| `AWS_SESSION_TOKEN` | do *AWS Details* | **a cada sessão do lab** |
| `TF_STATE_BUCKET` | `oficina-mecanica-tfstate-<ACCOUNT_ID>` | uma vez |
| `TF_STATE_LOCK_TABLE` | `oficina-mecanica-tf-locks` | uma vez (opcional) |

### Variables (aba *Variables*) — viram `TF_VAR_*`

| Variable | Valor (exemplo) | Obrigatória? |
|---|---|---|
| `VPC_ID` | `vpc-0123456789abcdef0` | **sim** |
| `DB_SUBNET_IDS` | `["subnet-0aaa","subnet-0bbb"]` (JSON!) | **sim** |
| `DB_ALLOWED_SG_IDS` | `["sg-eksnodes","sg-lambdaauth"]` (JSON!) | recomendada |
| `DB_ALLOWED_CIDRS` | `["10.0.0.0/16"]` (JSON!) | alternativa aos SGs |
| `LAB_ROLE_ARN` | `arn:aws:iam::<acct>:role/LabRole` | só p/ Enhanced Monitoring |
| `AWS_REGION` | `us-east-1` | não (default) |
| `TF_DIR` | `.` | não (autodetectado) |

> **`DB_SUBNET_IDS` / `DB_ALLOWED_SG_IDS` são listas** — o valor tem que ser
> um array **JSON válido**, senão o `terraform plan` falha ao parsear a
> variável. Ex.: `["subnet-0aaa1111","subnet-0bbb2222"]`.

### Via `gh` CLI (mais rápido para renovar os tokens)

```bash
gh secret set AWS_ACCESS_KEY_ID     --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
gh secret set AWS_SESSION_TOKEN     --body "$AWS_SESSION_TOKEN"
gh secret set TF_STATE_BUCKET       --body "oficina-mecanica-tfstate-${ACCOUNT_ID}"
gh secret set TF_STATE_LOCK_TABLE   --body "oficina-mecanica-tf-locks"

gh variable set VPC_ID            --body "vpc-0123456789abcdef0"
gh variable set DB_SUBNET_IDS     --body '["subnet-0aaa1111","subnet-0bbb2222"]'
gh variable set DB_ALLOWED_SG_IDS --body '["sg-0eksnodes","sg-0lambdaauth"]'
```

### Environments (opcional, recomendado)

O `cd.yml` referencia os environments **`homolog`** e **`production`**. Crie
os dois em **Settings → Environments**. Pode-se exigir *required reviewers*
no `production` para o apply em `main` só rodar após aprovação manual.

---

## 5. Deploy pela pipeline

| Ação | Como disparar | Resultado |
|---|---|---|
| **Homologação** | `git push` na branch `homolog` (ou merge de PR nela) | `cd.yml` → `terraform apply` com `environment=homolog`, state `oficina-infra-db/homolog.tfstate` |
| **Produção** | merge do PR em `main` | `cd.yml` → `apply` com `environment=prod`, state `oficina-infra-db/prod.tfstate` |
| **Plan só** | *Actions → CD - Terraform apply → Run workflow → action: plan* | roda `terraform plan` sem aplicar |
| **Destroy** | *Run workflow → action: destroy* na branch do ambiente | `terraform destroy -auto-approve` |
| **PR check** | abrir PR para `main`/`homolog` | `ci.yml` roda `fmt`+`validate` e comenta o `plan` no PR |

Fluxo recomendado por sessão de trabalho:

1. **Start Lab** → copiar credenciais → `gh secret set` dos 3 tokens AWS (passo 4).
2. Abrir PR → conferir o `plan` comentado.
3. Merge em `homolog` → acompanhar o run de **CD** → conferir `db_endpoint` e
   `secret_name` no *summary*.
4. (Fim da sessão) *Run workflow → destroy* em `homolog`, ou `terraform
   destroy` local.

---

## 6. Entregar o segredo para os consumidores

O apply cria o segredo **`oficina-mecanica-<env>/database`** no Secrets
Manager com as chaves `DATABASE_URL`, `DB_HOST`, `DB_PORT`, `DB_NAME`,
`DB_USER`, `DB_PASSWORD`.

- **Repo 4 (app NestJS + Job de migrations):** o External Secrets Operator
  (US-F3-06) sincroniza esse segredo para um Secret do K8s `oficina-db`. Basta
  apontar o `SecretStore`/`ExternalSecret` para `oficina-mecanica-<env>/database`.
- **Repo 1 (Lambda de auth):** referenciar o mesmo ARN/nome
  (`terraform output secret_arn`) como variável de ambiente ou via
  `secretsmanager:GetSecretValue` (a LabRole já tem permissão).

Conferir o conteúdo (cuidado: expõe a senha no terminal):

```bash
aws secretsmanager get-secret-value \
  --secret-id oficina-mecanica-homolog/database \
  --query SecretString --output text | jq
```

---

## 7. Problemas comuns

| Sintoma | Causa / correção |
|---|---|
| `InvalidClientTokenId` / `ExpiredToken` no CI | Sessão do lab expirou — refazer passo 1 e `gh secret set` dos 3 tokens |
| `Error: Backend initialization required` | Faltou `-backend-config` / bucket não existe — passo 2 |
| `cannot parse ... as list of string` | `DB_SUBNET_IDS`/`DB_ALLOWED_SG_IDS` não estão em JSON `[...]` |
| `DB subnet group ... requires at least two subnets in two AZs` | `subnet_ids` com < 2 subnets ou todas na mesma AZ |
| `InvalidParameterValue: ... KMS` no `storage_encrypted` | Conta do lab bloqueia KMS — aplicar com `storage_encrypted=false` (só lab) |
| `Cannot create ... final snapshot ... already exists` | Snapshot de um destroy anterior — `aws rds delete-db-snapshot --db-snapshot-identifier oficina-mecanica-<env>-final-snapshot` |
| Apply demora/timeout | Multi-AZ leva 8–15 min; o job não tem timeout curto, aguardar |
| App não conecta | `allowed_security_group_ids` não inclui o SG **dos nodes do EKS**; conferir `terraform output db_security_group_id` e as regras de ingresso |
