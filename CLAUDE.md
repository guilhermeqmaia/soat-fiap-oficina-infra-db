# Infra DB (RDS) — Oficina Mecânica (Tech Challenge FIAP Fase 3)

## About this repo

Repo **3/4** of the solution: Terraform for the managed database — **Amazon
RDS for PostgreSQL** (Multi-AZ), subnet group, security groups and the
connection secret. Consumed by the NestJS app on EKS (repo 4) and by the CPF
auth Lambda (repo 1), all inside the VPC provisioned by repo 2.

**Story:** implement via `docs/user-stories/f3-04-terraform-banco-gerenciado.md`
(use the `/implement-story` skill). The full ER model is in `docs/schema.dbml`.

## Non-negotiable decisions

- **PostgreSQL** — same dialect/migrations (Prisma) as Fases 1–2; the app's
  migrations job runs `prisma migrate deploy` against this instance.
- **Private only**: the DB lives in private subnets of the VPC (repo 2);
  security groups allow ingress **only** from the EKS nodes and the auth
  Lambda. Never publicly accessible.
- Output contract: `DATABASE_URL` (`postgresql://user:pass@host:5432/db?schema=public`)
  delivered via Secret (Secrets Manager) — the app's k8s manifests and the
  Lambda read it; keep the key names stable.
- DB password generated at apply time (`random_password`) → Secrets Manager.
  The tfstate contains it: never commit state (see `.gitignore`).
- **Fase 4 (US-F4-03): one RDS instance per service** (team decision,
  04/11). The main instance (`aws_db_instance.this`) stays the OS Service's —
  never change its identifier, `oficina_mecanica`, user `oficina` or the main
  secret (the os-service CD depends on that contract). Each entry of
  `var.service_databases` creates its own instance (`<prefix>-<svc>`), its own
  security group (same ingress rules as the main one) and its own secret
  (`<prefix>/<svc>/database`, same keys, `DB_HOST` = that instance). A service
  only knows its own host; there is no cross-service path. No SQL bootstrap
  Job: RDS creates db/user on apply. Cost: one extra `db.t3.micro` per
  service (Multi-AZ follows `var.multi_az`).

## AWS Academy constraints (always apply)

- Region **us-east-1**; session credentials expire (~4h) — renew before
  plan/apply.
- **Cannot create IAM roles** — use the existing `LabRole` where a role is
  required; prefer designs that need none.
- CI/CD credentials only via **GitHub Actions Secrets**
  (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`).

## Conventions

- Terraform style follows the existing stages of the solution (see repo 2):
  Portuguese comments, one file per concern (`versions.tf`, `providers.tf`,
  `variables.tf`, `locals.tf`, resources, `outputs.tf`), a filled
  `terraform.tfvars.example`, `default_tags` with Project/Fase/Story/ManagedBy.
- Validate before pushing: `terraform fmt -check && terraform init
  -backend=false && terraform validate`.
- Every implemented story gets a QA plan in `docs/qa-plans/` (skill `/qa-plan`).
- `main` is protected: work on branches + PR (solo merges use
  `gh pr merge --admin`). Draft PRs by default; ask before commit/push.
