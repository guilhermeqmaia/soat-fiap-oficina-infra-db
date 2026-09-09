# QA Plan — US-F3-04: Terraform — Banco de Dados Gerenciado (RDS)

## Summary

Valida que o Terraform deste repo provisiona um **Amazon RDS for PostgreSQL**
Multi-AZ, privado, com senha em Secrets Manager e remote state em S3, e que a
pipeline (`ci.yml`/`cd.yml`) consegue rodar `plan`/`apply` no AWS Academy
mantendo o contrato de `DATABASE_URL` esperado pela app e pelo Job de
migrations.

## Prerequisites

- Terraform >= 1.9, AWS CLI v2, `jq`.
- Credenciais do AWS Academy Learner Lab ativas (`aws sts get-caller-identity`
  responde) — região `us-east-1`.
- Bootstrap do state feito: bucket S3 versionado + tabela DynamoDB `LockID`
  (ver `docs/AWS_ACADEMY_SETUP.md` §2).
- Outputs do repo 2 (`soat-fiap-oficina-infra-k8s`): `vpc_id`, ≥ 2 subnets
  privadas em AZs distintas, security group dos nodes do EKS.
- `backend.hcl` e `terraform.tfvars` preenchidos (cópias dos `*.example`).
- Para os cenários de pipeline: repositório no GitHub com os Secrets/Variables
  da seção CI/CD do README configurados.

## Test Scenarios

### TS-01: `fmt` + `validate` limpos
- **Type:** Automated (CI) / Manual
- **Acceptance criterion:** "`terraform fmt`/`validate`/`plan` no CI"
- **Precondition:** repo clonado, nenhuma credencial necessária.
- **Steps:**
  1. `terraform fmt -check -recursive`
  2. `terraform init -backend=false`
  3. `terraform validate`
- **Expected result:** `fmt` sem diffs; `validate` retorna `Success! The
  configuration is valid.`
- **Alternative result (error):** diff de formatação ou erro de sintaxe/refs →
  corrigir antes do PR.

### TS-02: `plan` cria RDS PostgreSQL na versão compatível com Prisma
- **Type:** Manual
- **Acceptance criterion:** "provisiona RDS for PostgreSQL (versão compatível
  com as migrations Prisma)"
- **Precondition:** `backend.hcl` + `terraform.tfvars` preenchidos; credenciais ativas.
- **Steps:**
  1. `terraform init -backend-config=backend.hcl`
  2. `terraform plan -no-color | tee plan.txt`
  3. Inspecionar `plan.txt`.
- **Expected result:** plano com `aws_db_instance.this` → `engine = "postgres"`,
  `engine_version = "16"` (mesma major do `postgres:16-alpine` da Fase 2),
  `db_name = "oficina_mecanica"`, `username = "oficina"`, `port = 5432`.
- **Alternative result (error):** engine/versão diferente → migrations Prisma
  podem quebrar; ajustar `engine_version`.

### TS-03: Multi-AZ habilitado
- **Type:** Manual / Automated (assert)
- **Acceptance criterion:** "Multi-AZ habilitado (alta disponibilidade)"
- **Precondition:** apply concluído (ou plan disponível).
- **Steps:**
  1. `terraform plan` → conferir `multi_az = true` em `aws_db_instance.this`; ou
  2. pós-apply: `aws rds describe-db-instances --db-instance-identifier
     oficina-mecanica-<env> --query 'DBInstances[0].MultiAZ'`
- **Expected result:** `multi_az`/`MultiAZ` = `true`.
- **Alternative result (error):** `false` → verificar `var.multi_az` e se as
  subnets estão em AZs distintas.

### TS-04: Subnet group privado + SG restrito, sem acesso público
- **Type:** Manual
- **Acceptance criterion:** "`db_subnet_group` em subnets privadas +
  `security_group` restringindo acesso ao cluster EKS (sem exposição pública)"
- **Precondition:** apply concluído.
- **Steps:**
  1. `aws rds describe-db-instances --db-instance-identifier oficina-mecanica-<env>
     --query 'DBInstances[0].{Public:PubliclyAccessible,Subnets:DBSubnetGroup.Subnets[*].SubnetIdentifier,SGs:VpcSecurityGroups[*].VpcSecurityGroupId}'`
  2. Para cada subnet: `aws ec2 describe-route-tables --filters
     Name=association.subnet-id,Values=<subnet>` → confirmar ausência de rota
     `0.0.0.0/0` para um Internet Gateway (subnet privada).
  3. `aws ec2 describe-security-groups --group-ids <sg-do-rds>` → conferir
     `IpPermissions`: apenas tcp/5432, origem = SG(s) dos nodes do EKS / Lambda
     (ou CIDR informado), **nunca** `0.0.0.0/0`.
- **Expected result:** `PubliclyAccessible = false`; subnets sem rota para IGW;
  ingresso 5432 só das origens esperadas.
- **Alternative result (error):** `PubliclyAccessible = true` ou ingresso
  `0.0.0.0/0` → falha de segurança, bloquear.

### TS-05: Senha gerada por `random_password` e guardada no Secrets Manager
- **Type:** Manual
- **Acceptance criterion:** "Senha gerada por `random_password` e armazenada no
  AWS Secrets Manager (nunca em texto plano no state/output)"
- **Precondition:** apply concluído.
- **Steps:**
  1. `terraform output` → confirmar que **não** há `DATABASE_URL`, `password`
     nem `DB_PASSWORD` nos outputs (só `db_endpoint`, `secret_arn`, `secret_name`, etc.).
  2. `aws secretsmanager get-secret-value --secret-id oficina-mecanica-<env>/database
     --query SecretString --output text | jq 'keys'`
  3. Conferir `random_password.db` no state: `terraform state show
     random_password.db` → `result` aparece como `(sensitive value)`.
- **Expected result:** segredo existe com as 6 chaves; nenhum output expõe
  senha; `terraform output -json` não contém a senha.
- **Alternative result (error):** senha em output/log → violação; remover output.

### TS-06: Contrato de `DATABASE_URL` mantido
- **Type:** Manual
- **Acceptance criterion:** "Mantido o contrato de `DATABASE_URL` esperado pela
  app e pelo Job de migrations" + "Output com o endpoint e referência ao secret"
- **Precondition:** apply concluído.
- **Steps:**
  1. `SECRET=$(aws secretsmanager get-secret-value --secret-id
     oficina-mecanica-<env>/database --query SecretString --output text)`
  2. `echo "$SECRET" | jq -r '.DATABASE_URL'`
  3. Conferir formato: `postgresql://oficina:<senha>@<endpoint>:5432/oficina_mecanica?schema=public`
  4. Conferir chaves de conveniência: `DB_HOST`, `DB_PORT` (`"5432"`), `DB_NAME`
     (`oficina_mecanica`), `DB_USER` (`oficina`), `DB_PASSWORD`.
  5. `terraform output db_endpoint` e `terraform output secret_name` retornam valor.
- **Expected result:** `DATABASE_URL` no formato exato acima; chaves idênticas
  às do Secret `oficina-db` da Fase 2 (mapeamento 1:1 no External Secrets).
- **Alternative result (error):** nome de chave ou formato divergente → quebra
  o Job de migrations / a app; corrigir `secrets.tf`.

### TS-07: Conectividade real (migrations + app)
- **Type:** Manual
- **Acceptance criterion:** "restringindo acesso ao cluster EKS" +
  contrato consumível
- **Precondition:** apply concluído; um pod na VPC (nó do EKS) ou bastion no SG permitido.
- **Steps:**
  1. De um pod no EKS: `psql "$DATABASE_URL" -c 'select version();'`
  2. Rodar o Job de migrations do repo 4 (`prisma migrate deploy`) apontando
     para o secret sincronizado.
  3. De fora da VPC (máquina local): `nc -vz <endpoint> 5432` → deve **falhar**
     (timeout).
- **Expected result:** conexão OK de dentro da VPC; `prisma migrate deploy`
  aplica as migrations; conexão de fora da VPC falha.
- **Alternative result (error):** conexão externa funciona → SG/subnet mal
  configurados; falha de dentro → SG não inclui o SG dos nodes.

### TS-08: Backups + janelas + `deletion_protection` por ambiente
- **Type:** Manual
- **Acceptance criterion:** "Backups automáticos + janela de manutenção +
  `deletion_protection` (em prod) configurados" + "Parametrização por ambiente"
- **Precondition:** applies em `homolog` e `prod` (ou dois `plan` com
  `-var environment=`).
- **Steps:**
  1. `homolog`: conferir no plan/estado `backup_retention_period = 7`,
     `backup_window = "03:00-04:00"`, `maintenance_window = "mon:04:30-mon:05:30"`,
     `deletion_protection = false`, `skip_final_snapshot = true`.
  2. `prod` (`terraform plan -var environment=prod`): `deletion_protection = true`,
     `skip_final_snapshot = false`, `final_snapshot_identifier =
     "oficina-mecanica-prod-final-snapshot"`, `apply_immediately = false`.
  3. Pós-apply prod: `terraform destroy` deve **falhar** com
     `DeletionProtection` até `deletion_protection=false`.
- **Expected result:** valores por ambiente conforme acima; destroy bloqueado
  em prod.
- **Alternative result (error):** prod sem proteção / homolog com proteção →
  ajustar `locals.tf`.

### TS-09: Remote state em S3 + lock DynamoDB
- **Type:** Manual
- **Acceptance criterion:** "Remote state (S3 + DynamoDB lock) configurado"
- **Precondition:** bootstrap do state feito.
- **Steps:**
  1. `terraform init -backend-config=backend.hcl` → "Successfully configured
     the backend \"s3\"".
  2. Após um apply: `aws s3 ls s3://<bucket>/oficina-infra-db/` → objeto
     `<env>.tfstate` presente e versionado.
  3. Durante um `apply`, em outro terminal rodar `terraform plan` → deve
     aguardar/della com `Error acquiring the state lock` (item na tabela
     DynamoDB).
  4. Confirmar que `*.tfstate` **não** está versionado no git (`git check-ignore
     terraform.tfstate` retorna o caminho).
- **Expected result:** state no S3; lock efetivo no DynamoDB; state fora do git.
- **Alternative result (error):** state local criado (`terraform.tfstate` no
  disco) → backend não inicializou; sem lock → `TF_STATE_LOCK_TABLE`/`dynamodb_table`
  ausente.

### TS-10: Pipeline — `plan` comentado no PR
- **Type:** Automated (CI)
- **Acceptance criterion:** "`terraform ... plan` no CI"
- **Precondition:** Secrets `AWS_*` + `TF_STATE_BUCKET` e Variables `VPC_ID`,
  `DB_SUBNET_IDS`, `DB_ALLOWED_SG_IDS` configurados; credenciais do lab válidas.
- **Steps:**
  1. Abrir PR de uma branch para `homolog`.
  2. Acompanhar o workflow **CI** → jobs `validate` e `plan`.
  3. Ver o comentário automático no PR.
- **Expected result:** `validate` verde sempre; `plan` roda, e um comentário
  "`terraform plan` — banco gerenciado (RDS)" aparece no PR com a saída.
- **Alternative result (error):** sem credenciais → job `plan` é *skipped* com
  `::notice::Sem credenciais AWS/TF_STATE_BUCKET`; erro de parse de lista →
  `DB_SUBNET_IDS` não está em JSON.

### TS-11: Pipeline — `apply` automático (deploy)
- **Type:** Automated (CD)
- **Acceptance criterion:** "`apply` no deploy automático"
- **Precondition:** mesmos secrets/vars do TS-10; environments `homolog` e
  `production` criados.
- **Steps:**
  1. Merge do PR em `homolog`.
  2. Acompanhar o workflow **CD - Terraform apply** → job `apply`
     (`environment=homolog`, `key=oficina-infra-db/homolog.tfstate`).
  3. Ao fim, abrir o *Step Summary* do run.
  4. Repetir com merge em `main` → `environment=prod`.
- **Expected result:** `terraform apply -auto-approve` conclui; o *summary*
  mostra `db_endpoint`, `secret_name`, etc. (via `terraform output`); **nenhuma
  senha** no log. `homolog` e `main` usam states/keys distintos.
- **Alternative result (error):** `ExpiredToken` → renovar os 3 secrets AWS;
  `Backend initialization required` → bootstrap do bucket ausente.

### TS-12: Pipeline — `destroy` manual
- **Type:** Automated (CD, `workflow_dispatch`)
- **Acceptance criterion:** parametrização/operacional (economia no Academy)
- **Steps:**
  1. *Actions → CD - Terraform apply → Run workflow* na branch `homolog`,
     input `action = destroy`.
  2. Acompanhar o job.
- **Expected result:** `terraform destroy -auto-approve` remove a instância, o
  subnet group, o SG e o segredo (`recovery_window_in_days = 0`).
- **Alternative result (error):** em `main`/prod o destroy falha por
  `deletion_protection` — comportamento esperado; ajustar var e repetir se
  intencional.

## Edge Cases

- `subnet_ids` com apenas 1 subnet → `validation` do Terraform barra no plan
  ("ao menos 2 subnets privadas").
- `vpc_id` sem prefixo `vpc-` → `validation` barra.
- `environment` diferente de `homolog`/`prod` → `validation` barra.
- `allowed_security_group_ids = []` **e** `allowed_cidr_blocks = []` → apply
  conclui, mas o banco fica sem ingresso (inacessível) — documentado; TS-07
  detecta.
- Conta do lab sem KMS → `terraform apply -var storage_encrypted=false` (só lab).
- Segundo `destroy`/recriação com snapshot final já existente → apagar o
  snapshot antes (nome fixo).
- `DB_SUBNET_IDS` como CSV em vez de JSON → erro de parse (esperado);
  precisa ser `["subnet-a","subnet-b"]`.
- Sessão do Learner Lab expira no meio do `apply` → run falha; reexecutar após
  renovar tokens (o state fica destravado pelo fim do lock ou `force-unlock`).

## Traceability

| Acceptance Criterion | Test Scenarios |
|---|---|
| RDS for PostgreSQL (versão compatível Prisma) | TS-02 |
| Multi-AZ habilitado | TS-03 |
| `db_subnet_group` privado + SG restrito, sem exposição pública | TS-04, TS-07 |
| Senha via `random_password` no Secrets Manager (nunca em plano) | TS-05 |
| Output com endpoint + referência ao secret (consumo via K8s Secret) | TS-05, TS-06 |
| Backups + janela de manutenção + `deletion_protection` (prod) | TS-08 |
| Parametrização por ambiente (homolog/prod) | TS-08, TS-11 |
| Remote state (S3 + DynamoDB lock) | TS-09 |
| `fmt`/`validate`/`plan` no CI; `apply` no deploy | TS-01, TS-10, TS-11, TS-12 |
| README: recursos, como aplicar, diagrama, variáveis, custo | Revisão de `README.md` + `docs/AWS_ACADEMY_SETUP.md` |
| Contrato de `DATABASE_URL` mantido | TS-06 |

## Validation Checklist

- [x] Todos os critérios de aceite cobertos por ≥ 1 cenário
- [x] Edge cases documentados
- [x] Fluxos de erro documentados (coluna "Alternative result")
- [x] Instruções de setup completas (`docs/AWS_ACADEMY_SETUP.md`)

## Useful Commands

```bash
# Qualidade (sem credenciais)
terraform fmt -check -recursive
terraform init -backend=false && terraform validate

# Plan/apply (com credenciais do lab + backend.hcl)
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# Inspecionar o resultado
terraform output
aws rds describe-db-instances --db-instance-identifier oficina-mecanica-homolog \
  --query 'DBInstances[0].{MultiAZ:MultiAZ,Public:PubliclyAccessible,Status:DBInstanceStatus}'
aws secretsmanager get-secret-value --secret-id oficina-mecanica-homolog/database \
  --query SecretString --output text | jq 'keys'

# Limpeza (fim da sessão do Academy)
terraform destroy
```
