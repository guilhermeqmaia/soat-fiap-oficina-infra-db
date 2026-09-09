# US-F3-DOC-04: Justificativa da Escolha do Banco + Modelo Relacional (Diagrama ER)

**User Story:** Como time de arquitetura, quero uma justificativa formal da escolha do banco de dados e o modelo relacional documentado com diagrama ER, para que a decisao seja rastreavel, defensavel frente as alternativas e sirva de referencia para a evolucao do schema.

**Prioridade:** Media
**Story Points:** 3
**Status:** Done
**DDD Domain:** Infraestrutura / Documentacao
**DDD Layer:** —
**Repositorio:** 3 — `soat-fiap-oficina-infra-db`

## Contexto

A [US-F3-04](f3-04-terraform-banco-gerenciado.md) provisiona o **Amazon RDS for
PostgreSQL** via Terraform (`database.tf`, `variables.tf`). O schema relacional
ja existe em [`docs/schema.dbml`](../schema.dbml) (formato dbdiagram.io).
Falta consolidar, em um unico documento, **por que** PostgreSQL gerenciado foi
escolhido frente as alternativas e **como** o modelo relacional esta
estruturado (tabelas, relacionamentos, constraints, indices).

## Criterios de Aceite

- [x] Documento `docs/arquitetura/banco-de-dados.md` com justificativa formal da
      escolha do PostgreSQL gerenciado (RDS), comparando explicitamente com
      NoSQL/DynamoDB, MySQL/MariaDB, Postgres auto-hospedado (container/EC2) e
      Aurora PostgreSQL, com argumentos referenciando `variables.tf` e
      `database.tf`
- [x] Tabela comparativa (criterios x alternativas) com o vencedor destacado
- [x] Secao de consistencia: constraints `UNIQUE`, indices unicos compostos,
      enums de dominio e transacoes do fluxo de estoque
- [x] Secao de performance: indices existentes e indices adicionais propostos
      para dashboards, cada um justificado pelo caso de uso
- [x] Diagrama ER exportado do dbdiagram.io em `docs/arquitetura/` e
      referenciado no markdown; `docs/schema.dbml` mantido como fonte canonica
- [x] Diagrama Mermaid `erDiagram` como fallback textual versionavel
- [x] Uma subsecao por relacionamento do `schema.dbml`: tabelas, FK,
      cardinalidade e regra de negocio (incluindo as referencias logicas de
      `notificacao`)
- [x] `README.md` apontando para o novo documento

## Notas

- Nenhum `.tf` e alterado por esta US; o unico artefato de schema tocado e
  `docs/schema.dbml`.
- O schema fisico (Prisma) continua no repo da aplicacao (repo 4); este
  documento descreve o modelo que aquelas migrations materializam.
