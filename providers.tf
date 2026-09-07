# Banco Gerenciado (RDS): configuracao do provider AWS.
# AWS Academy / Learner Lab: credenciais temporarias (AWS_ACCESS_KEY_ID,
# AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN) — via `aws configure` local ou
# GitHub Actions Secrets no CI/CD. Sessao expira em ~4h: renovar antes do apply.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Fase      = "fase-3"
      Story     = "US-F3-04"
      ManagedBy = "terraform"
    }
  }
}
