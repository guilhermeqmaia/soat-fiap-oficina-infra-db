# US-F3-04: Terraform — Banco de Dados Gerenciado (RDS)

**User Story:** Como time de plataforma, quero provisionar um banco PostgreSQL gerenciado (RDS) via Terraform, para ter consistencia, backups e alta disponibilidade sem operar o banco manualmente.

**Prioridade:** Alta
**Story Points:** 5
**Status:** To Do
**DDD Domain:** Infraestrutura
**DDD Layer:** —
**Repositorio:** 3 — `soat-fiap-oficina-infra-db`

## Contexto

Migra do Postgres in-cluster (kind, Fase 2) para **Amazon RDS for PostgreSQL**.
Repositorio dedicado, com CI/CD e deploy automatico ([f3-08](f3-08-cicd-multi-repo.md)).
Justificativa formal do banco em [f3-doc-04](f3-doc-04-justificativa-banco-er.md).

## Criterios de Aceite

- [ ] Terraform provisiona **RDS for PostgreSQL** (versao compativel com as migrations Prisma atuais)
- [ ] **Multi-AZ** habilitado (alta disponibilidade)
- [ ] `db_subnet_group` em subnets privadas + `security_group` restringindo acesso ao cluster EKS (sem exposicao publica)
- [ ] Senha gerada por `random_password` e armazenada no **AWS Secrets Manager** (nunca em texto plano no state/output)
- [ ] Output com o **endpoint** e referencia ao secret, consumidos pela aplicacao via Secret do K8s / External Secrets
- [ ] Backups automaticos + janela de manutencao + `deletion_protection` (em prod) configurados
- [ ] Parametrizacao por ambiente (homolog/prod) via workspaces ou tfvars
- [ ] **Remote state** (S3 + DynamoDB lock) configurado
- [ ] `terraform fmt`/`validate`/`plan` no CI; `apply` no deploy automatico
- [ ] README do repo: recursos criados, como aplicar, diagrama, variaveis, custo estimado
- [ ] Mantido o contrato de `DATABASE_URL` esperado pela app e pelo Job de migrations

## Notas

- O Job de migrations (`prisma migrate deploy`) continua no repo da aplicacao; este repo entrega apenas o banco + secret + endpoint.
