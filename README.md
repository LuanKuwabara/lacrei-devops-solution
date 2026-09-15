<<<<<<< HEAD
# lacrei-devops-solution
=======
# Lacrei Saúde - DevOps Challenge

Projeto simples para executar uma API Node.js em Docker na AWS usando Terraform e GitHub Actions.

## Arquitetura

- 1 VPC
- 1 subnet pública
- 1 EC2 `t3.micro`
- Docker na EC2
- Nginx com HTTPS na porta 443
- Amazon ECR para as imagens Docker
- AWS Systems Manager para deploy sem SSH
- CloudWatch Logs e métricas de memória/disco
- Terraform state em S3
- `staging` e `production` usando o mesmo código em contas AWS diferentes

A aplicação fica disponível em:

```text
https://IP_PUBLICO/status
```

O certificado é autoassinado para evitar domínio, Route 53, ALB e ACM. Para testar:

```bash
curl -k https://IP_PUBLICO/status
```

Resposta:

```json
{"status":"ok"}
```

## GitHub

Crie dois GitHub Environments:

- `staging`
- `production`

Configure os mesmos secrets em cada Environment, usando as credenciais da respectiva conta AWS:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
TF_STATE_BUCKET
BUDGET_EMAIL
```

O bucket informado em `TF_STATE_BUCKET` precisa existir antes do primeiro workflow e deve estar na mesma conta usada pelo Environment. `BUDGET_EMAIL` recebe os avisos de 80% previsto e 100% real do orçamento mensal de US$20.

A branch `staging` faz deploy em `staging`.

A branch `main` faz deploy em `production`.

## Pipeline

Pull Request para `staging` ou `main`:

1. Build do container
2. Teste real de `GET /status` no container
3. `terraform fmt`
4. `terraform validate`

Push para `staging` ou `main`:

1. Terraform cria/atualiza a infraestrutura
2. A imagem recebe como tag o SHA do commit
3. A imagem é enviada para o ECR
4. GitHub Actions usa SSM para atualizar o container na EC2
5. O workflow testa `GET /status` por HTTPS

## Rollback

Abra o workflow `Rollback`, escolha o ambiente e informe o SHA de um commit que já tenha sido publicado.

O workflow baixa essa imagem do ECR, substitui o container atual e testa novamente `/status`.

## AWS

A credencial usada pelo GitHub precisa permitir a criação dos recursos Terraform e executar `ssm:SendCommand` e as consultas usadas pelos workflows.

A EC2 não possui porta SSH aberta. Somente HTTPS na porta 443 fica público.

## Custo

A arquitetura evita ALB, NAT Gateway, RDS e ECS. Os principais custos são a EC2, IPv4 público, armazenamento EBS, ECR e o pequeno volume de CloudWatch utilizado durante a avaliação.
>>>>>>> c78b0cf (v2.2)
