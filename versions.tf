# Banco Gerenciado (RDS): restricoes de versao do Terraform e dos providers.
# Sem blocos `provider {}` aqui (ficam em providers.tf) para que
# `terraform validate` cheque apenas as constraints.
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
