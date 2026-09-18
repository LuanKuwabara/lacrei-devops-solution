<<<<<<< HEAD
=======
<<<<<<< HEAD
# lacrei-devops-solution
=======
>>>>>>> staging
# Lacrei Saúde - DevOps Challenge

Projeto simples para executar uma API Node.js em Docker na AWS usando Terraform e GitHub Actions.

## Arquitetura

- 1 VPC
- 1 subnet pública
<<<<<<< HEAD
- 1 EC2 `t2.micro`
=======
- 1 EC2 `t3.micro`
>>>>>>> staging
- Docker na EC2
- Nginx com HTTPS na porta 443
- Amazon ECR para as imagens Docker
- AWS Systems Manager para deploy sem SSH
<<<<<<< HEAD
- CloudWatch Logs e métricas
- Terraform state em S3
- Ambientes `staging` e `production`
=======
- CloudWatch Logs e métricas de memória/disco
- Terraform state em S3
- `staging` e `production` usando o mesmo código em contas AWS diferentes
>>>>>>> staging

A aplicação fica disponível em:

```text
https://IP_PUBLICO/status
```

<<<<<<< HEAD
O certificado é autoassinado para manter a solução simples e evitar domínio, Route 53, ALB e ACM.
=======
O certificado é autoassinado para evitar domínio, Route 53, ALB e ACM. Para testar:
>>>>>>> staging

```bash
curl -k https://IP_PUBLICO/status
```

<<<<<<< HEAD
Resposta esperada:
=======
Resposta:
>>>>>>> staging

```json
{"status":"ok"}
```

## GitHub

Crie dois GitHub Environments:

- `staging`
- `production`

<<<<<<< HEAD
Configure os seguintes secrets em cada Environment:
=======
Configure os mesmos secrets em cada Environment, usando as credenciais da respectiva conta AWS:
>>>>>>> staging

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
TF_STATE_BUCKET
BUDGET_EMAIL
```

<<<<<<< HEAD
O bucket informado em `TF_STATE_BUCKET` precisa existir antes da primeira execução da pipeline.

Exemplo para criar o bucket em `us-east-1`:

```bash
aws s3api create-bucket \
  --bucket NOME_DO_BUCKET \
  --region us-east-1
```

As credenciais de `staging` e `production` podem apontar para contas AWS diferentes usando os mesmos nomes de secrets.

## Pipeline

Pull Requests para `staging` ou `main` executam validações:

1. Build da imagem Docker
2. Teste de `GET /status`
3. `terraform fmt -check`
4. `terraform validate`

Push para `staging` ou `main` executa o deploy:

1. Terraform cria ou atualiza a infraestrutura
2. A imagem Docker recebe o SHA do commit como tag
3. A imagem é enviada ao ECR
4. GitHub Actions espera a EC2 ficar disponível no SSM
5. SSM atualiza o container na EC2
6. O workflow testa `GET /status` por HTTPS

### Deploy em staging

```bash
git checkout staging
git pull origin staging
git add .
git commit -m "Update staging"
git push origin staging
```

Se não houver alteração e for necessário apenas disparar novamente a pipeline:

```bash
git commit --allow-empty -m "Trigger staging deploy"
git push origin staging
```

Também é possível executar manualmente pelo GitHub em:

```text
Actions -> Deploy -> Run workflow -> staging
```

### Deploy em production

Depois de validar `staging`, envie as alterações para `main`:

```bash
git checkout main
git pull origin main
git merge staging
git push origin main
```

O push em `main` usa automaticamente o GitHub Environment `production`.

Também é possível executar manualmente:

```text
Actions -> Deploy -> Run workflow -> main
```

## Terraform local

Para consultar ou administrar o mesmo state utilizado pela pipeline:

```bash
cd terraform/modules

terraform init -reconfigure \
  -backend-config="bucket=NOME_DO_BUCKET" \
  -backend-config="key=lacrei/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

O `key` deve conter apenas o caminho dentro do bucket. Não utilize `s3://`.

Exemplo de plan para staging:

```bash
terraform plan \
  -var="environment=staging" \
  -var="aws_region=us-east-1" \
  -var="budget_email=seu-email@exemplo.com"
```

## Rollback

Cada imagem enviada ao ECR utiliza o SHA do commit como tag.

No GitHub:

```text
Actions -> Rollback -> Run workflow
```

Escolha o ambiente e informe o SHA de um commit que já tenha sido publicado.

O workflow baixa a imagem anterior, substitui o container atual e valida novamente `/status`.

## Destroy

Para remover a infraestrutura de staging:

```bash
cd terraform/modules

terraform init -reconfigure \
  -backend-config="bucket=NOME_DO_BUCKET" \
  -backend-config="key=lacrei/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform destroy \
  -var="environment=staging" \
  -var="aws_region=us-east-1" \
  -var="budget_email=seu-email@exemplo.com"
```

Para production, utilize o bucket/credenciais de production e altere:

```text
environment=production
```

O bucket do Terraform state deve ser removido somente depois do `terraform destroy`, caso não seja mais necessário.

## Erros encontrados

Durante a implementação foram encontrados alguns problemas simples de configuração:

### Arquivos locais enviados ao Git

A pasta `.terraform` chegou a ser adicionada ao Git e continha um provider maior que o limite do GitHub. `terraform.tfstate` também não deve ser versionado.

O `.gitignore` utilizado ficou com:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
.env
```

### Terraform sem arquivos de configuração

A pipeline retornou:

```text
Error: No configuration files
```

Os arquivos Terraform não estavam sendo rastreados corretamente e `terraform/modules` havia sido tratado como um repositório Git separado. A pasta foi normalizada e os arquivos `.tf` passaram a ser versionados diretamente.

Os steps Terraform também passaram a usar:

```yaml
working-directory: terraform/modules
```

### Formatação Terraform

`terraform fmt -check -recursive` falhou inicialmente. Os arquivos foram corrigidos com:

```bash
terraform fmt -recursive
```

### Availability Zone

A subnet foi criada inicialmente em `us-east-1e`, onde o tipo de instância escolhido apresentou indisponibilidade.

A solução foi usar uma AZ compatível e manter a instância como `t2.micro`, suficiente para o desafio e de baixo custo.

### Backend S3

Ao executar `terraform init`, o `key` foi informado inicialmente como uma URL S3 completa.

Incorreto:

```text
s3://bucket-lacrei-state/lacrei/terraform.tfstate
```

Correto:

```text
lacrei/terraform.tfstate
```

A região também precisa ser informada no backend ou em `AWS_REGION`.

### Deploy por SSM

O primeiro deploy por SSM falhou enquanto a EC2 ainda terminava sua inicialização.

O workflow foi ajustado para:

- esperar a instância aparecer como `Online` no SSM
- esperar o Docker estar instalado e ativo
- exibir `stdout` e `stderr` do comando SSM em caso de falha

## Decisões tomadas

A solução foi mantida propositalmente simples:

- EC2 em vez de ECS ou Kubernetes
- subnet pública para evitar NAT Gateway
- SSM em vez de SSH
- ECR para armazenar e versionar imagens
- SHA do commit como tag para permitir rollback
- Nginx com certificado autoassinado para HTTPS sem domínio ou ALB
- CloudWatch para logs e métricas
- Terraform state remoto em S3
- mesma base Terraform para `staging` e `production`

Não foram adicionados banco de dados, NAT Gateway, Load Balancer ou outros componentes que não são necessários para o endpoint `/status`.

## Custo

A arquitetura evita ALB, NAT Gateway, RDS e ECS. Os principais custos são EC2, IPv4 público, EBS, ECR e CloudWatch durante o período de avaliação.

## Evidências e requisitos de entrega

### Ambientes

A solução utiliza dois ambientes:

- `staging`: deploy a partir da branch `staging`
- `production`: deploy a partir da branch `main`

Cada ambiente utiliza um GitHub Environment separado, com secrets próprios.

Links dos ambientes:

- Staging: `https://<STAGING_PUBLIC_IP>/status`
- Production: `https://<PRODUCTION_PUBLIC_IP>/status`

Os IPs públicos são gerados pelo Terraform e podem ser consultados com:

```bash
terraform output -raw public_ip
=======
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
>>>>>>> staging
