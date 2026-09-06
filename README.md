# soat-fiap-oficina-infra-db

Terraform do **banco de dados gerenciado** do Sistema da Oficina Mecânica
(Tech Challenge FIAP — Fase 3): **Amazon RDS for PostgreSQL** Multi-AZ, com
subnet group, security groups e segredo de conexão. Repositório **3/4** da
solução.

| # | Repositório | Conteúdo |
|---|---|---|
| 1 | [soat-fiap-oficina-auth-lambda](https://github.com/guilhermeqmaia/soat-fiap-oficina-auth-lambda) | Function serverless de autenticação por CPF |
| 2 | [soat-fiap-oficina-infra-k8s](https://github.com/guilhermeqmaia/soat-fiap-oficina-infra-k8s) | Terraform do API Gateway + cluster EKS |
| 3 | **soat-fiap-oficina-infra-db** (este) | Terraform do banco gerenciado (RDS PostgreSQL) |
| 4 | [soat-fiap-oficina-mecanica-app](https://github.com/guilhermeqmaia/soat-fiap-oficina-mecanica-app) | Aplicação NestJS + manifestos K8s + docs |

> **Status:** scaffold — a implementação é a
> [US-F3-04](docs/user-stories/f3-04-terraform-banco-gerenciado.md);
> documentação da escolha do banco e do modelo ER em
> [US-F3-DOC-04](docs/user-stories/f3-doc-04-justificativa-banco-er.md).

## Por que PostgreSQL gerenciado (RDS)

- Mantém o **mesmo dialeto e migrations** (Prisma) das Fases 1–2 — zero
  reescrita na aplicação.
- ACID para as transações do domínio (ordens de serviço, reservas de estoque).
- Multi-AZ com failover automático, backups e patches gerenciados pela AWS.
- **Justificativa formal** (comparativo com DynamoDB, MySQL, Postgres
  auto-hospedado e Aurora), **diagrama ER**, relacionamentos, constraints e
  índices: [docs/arquitetura/banco-de-dados.md](docs/arquitetura/banco-de-dados.md)
  (US-F3-DOC-04). Fonte do modelo: [docs/schema.dbml](docs/schema.dbml)
  (importável no [dbdiagram.io](https://dbdiagram.io)).

## Consumidores do banco

Dois clientes na mesma VPC (nada é acessível de fora):

| Consumidor | Uso |
|---|---|
| App NestJS no EKS (repo 4) | Prisma — CRUD completo do domínio |
| Lambda de auth por CPF (repo 1) | Consulta existência/status de cliente/usuário |

Contrato de saída: Secret com `DATABASE_URL`
(`postgresql://user:pass@host:5432/db?schema=public`) + campos de
conveniência, consumido pelos repos 1 e 4 via Secrets Manager/outputs.

## Credenciais e segredos

- **Nunca** commitar: `*.tfvars` reais, `*.tfstate` (contém a senha do banco)
  e afins estão no `.gitignore`; apenas `*.tfvars.example` é versionado.
- CI/CD usa **GitHub Actions Secrets**: `AWS_ACCESS_KEY_ID`,
  `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (AWS Academy — o token expira a
  cada sessão do lab: `gh secret set AWS_SESSION_TOKEN`).
- A senha do banco é gerada no apply e vai para o **AWS Secrets Manager** —
  nunca para o repositório.

## Como aplicar (quando implementado)

```bash
cp terraform.tfvars.example terraform.tfvars   # preencher (VPC/subnets do repo 2)
terraform init && terraform apply
```

## Qualidade

```bash
terraform fmt -check && terraform init -backend=false && terraform validate
```

## Documentação

- [docs/user-stories/](docs/user-stories/) — US-F3-04, US-F3-DOC-04
- [docs/arquitetura/banco-de-dados.md](docs/arquitetura/banco-de-dados.md) — justificativa da escolha do banco, diagrama ER, relacionamentos, consistência e índices
- [docs/schema.dbml](docs/schema.dbml) — modelo ER completo do domínio (fonte canônica do [diagrama](docs/arquitetura/er-diagram.png))
- [docs/tech-challenges/fase-3-tech-challenge.pdf](docs/tech-challenges/fase-3-tech-challenge.pdf) — enunciado
- [docs/qa-plans/](docs/qa-plans/) — planos de QA (gerados com a skill `/qa-plan`)
