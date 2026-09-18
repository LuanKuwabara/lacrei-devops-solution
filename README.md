# Lacrei Saúde - DevOps Challenge

Projeto simples para executar uma API Node.js em Docker na AWS usando Terraform e GitHub Actions.

## Ambientes

| Ambiente | Endpoint |
|---|---|
| Staging | https://44.192.60.116/status |
| Production | https://3.235.84.47/status |

Os endpoints utilizam HTTPS com certificado autoassinado. Por isso, os testes com `curl` utilizam `-k`.

Os IPs são públicos e podem mudar caso as instâncias sejam recriadas.

## Arquitetura

- 1 VPC por ambiente
- 1 subnet pública por ambiente
- 1 EC2 `t2.micro` por ambiente
- Docker na EC2
- Node.js na porta local `3000`
- Nginx expondo HTTPS na porta `443`
- Amazon ECR para imagens Docker
- AWS Systems Manager para deploy sem SSH
- CloudWatch Logs para Nginx
- Terraform state em S3
- GitHub Environments separados para `staging` e `production`

Fluxo simplificado:

```text
GitHub Actions
      |
      v
Terraform -> AWS
      |
      v
Docker Build -> ECR
      |
      v
SSM -> EC2 -> Docker -> Node.js
                 |
                 v
            Nginx :443
```

## Aplicação

A aplicação responde em:

```text
GET /status
```

Resposta esperada:

```json
{"status":"ok"}
```

Exemplo:

```bash
curl -k https://IP_PUBLICO/status
```

## CI/CD

Pull Requests para `staging` e `main` executam validações:

1. Build da imagem Docker
2. Execução temporária do container
3. Teste da rota `/status`
4. `terraform fmt -check`
5. `terraform init -backend=false`
6. `terraform validate`

Push para `staging` ou `main` executa o deploy:

1. Terraform cria ou atualiza a infraestrutura
2. Imagem Docker recebe o SHA do commit como tag
3. Imagem é enviada ao ECR
4. Pipeline aguarda a EC2 ficar online no SSM
5. SSM faz o deploy do container na EC2
6. Pipeline executa smoke test no endpoint HTTPS `/status`

### Staging

```bash
git checkout staging
git pull origin staging
git add .
git commit -m "Update staging"
git push origin staging
```

Se não houver alteração e for necessário apenas disparar a pipeline:

```bash
git commit --allow-empty -m "Trigger staging deploy"
git push origin staging
```

### Production

Depois de validar `staging`:

```bash
git checkout main
git pull origin main
git merge staging
git push origin main
```

`main` utiliza automaticamente o GitHub Environment `production`.

## Secrets

Nenhuma credencial AWS é armazenada no código.

São utilizados GitHub Environments separados para `staging` e `production`, com os seguintes secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
TF_STATE_BUCKET
BUDGET_EMAIL
```

Os valores não são exibidos no repositório nem nos logs.

## Segurança

### IAM

Cada EC2 utiliza Instance Profile próprio com as policies:

```text
AmazonEC2ContainerRegistryReadOnly
AmazonSSMManagedInstanceCore
CloudWatchAgentServerPolicy
```

Isso permite:

- leitura das imagens no ECR;
- comunicação com SSM;
- envio de logs e métricas para CloudWatch.

Nenhuma credencial AWS é salva dentro da EC2.

### Security Groups

A única porta de entrada pública é:

```text
TCP 443 - HTTPS
```

Não são expostas publicamente:

```text
22 - SSH
3000 - Node.js
```

A aplicação fica disponível apenas em `127.0.0.1:3000` e é publicada pelo Nginx.

## HTTPS/TLS

O Nginx termina a conexão TLS na porta `443`.

Exemplo de validação:

```bash
curl -vk https://IP_PUBLICO/status
```

O resultado comprova:

- conexão na porta 443;
- negociação SSL/TLS;
- resposta HTTP 200;
- resposta `{"status":"ok"}`.

Foi utilizado certificado autoassinado para evitar domínio, Route 53, ACM e load balancer.

### HTTP para HTTPS

A porta `80` não é exposta pelo Security Group.

Por esse motivo, não existe redirecionamento HTTP para HTTPS. O ambiente aceita apenas HTTPS na porta `443`.

## Logs e monitoramento

O CloudWatch recebe logs do Nginx:

```text
nginx-access
nginx-error
```

Os access logs registram chamadas como:

```text
GET /status HTTP/1.1 200
```

O monitoramento básico inclui:

- CloudWatch Logs;
- status da instância EC2;
- health check `/status`;
- smoke test após o deploy.

Como evolução, pode ser criado um CloudWatch Alarm para `StatusCheckFailed` da EC2.

## Rollback

Cada imagem enviada ao ECR utiliza o SHA do commit como tag.

O rollback utiliza uma imagem anterior do ECR e faz o deploy por SSM.

Fluxo:

```text
SHA anterior
   |
   v
ECR image
   |
   v
SSM
   |
   v
EC2 -> docker pull -> substituição do container -> /status
```

Exemplo de validação após rollback:

```bash
curl -k https://44.192.60.116/status
```

O rollback em staging foi executado com sucesso utilizando uma imagem anterior armazenada no ECR.

## Branch protection

As branches recomendadas para proteção são:

```text
main
staging
```

Configuração no GitHub:

```text
Settings -> Rules -> Rulesets
```

Regras:

- Require a pull request before merging
- Require 1 approval
- Require status checks to pass
- Require branch to be up to date before merging
- Require conversation resolution before merging

O check obrigatório deve ser o job `validate`.

## Terraform state

O state é armazenado em S3 e não é versionado no Git.

Exemplo:

```bash
cd terraform/modules

terraform init -reconfigure \
  -backend-config="bucket=NOME_DO_BUCKET" \
  -backend-config="key=lacrei/terraform.tfstate" \
  -backend-config="region=us-east-1"
```

Staging e production utilizam buckets ou states separados.

## Destroy

Exemplo para staging:

```bash
terraform destroy \
  -var="environment=staging" \
  -var="aws_region=us-east-1" \
  -var="budget_email=seu-email@exemplo.com"
```

Para production, utilize o backend de production e:

```text
environment=production
```

O ECR utiliza `force_delete = true` para permitir a remoção do repositório mesmo quando houver imagens.

## Evidências

### GitHub Secrets

![GitHub Secrets](docs/evidences/01-github-secrets.png)

### Deployments staging e production

![Deployments](docs/evidences/02-deployments.png)

### Pipeline de production

![Pipeline production](docs/evidences/03-pipeline-production.png)

### Validação antes do deploy

O job `validate` executa teste da aplicação e validações Terraform antes do job `deploy`.

![Pipeline validation](docs/evidences/04-pipeline-validation.png)

### EC2

Staging:

![EC2 staging](docs/evidences/05-ec2-staging.png)

Production:

![EC2 production](docs/evidences/06-ec2-production.png)

### Endpoint `/status`

Staging:

![Status staging](docs/evidences/07-status-staging.png)

Production:

![Status production](docs/evidences/08-status-production.png)

### HTTPS/TLS

Staging:

![HTTPS staging](docs/evidences/09-https-staging.png)

Production:

![HTTPS production](docs/evidences/10-https-production.png)

### Security Groups

Staging:

![SG staging](docs/evidences/11-sg-staging.png)

Production:

![SG production](docs/evidences/12-sg-production.png)

### IAM

Staging:

![IAM staging](docs/evidences/13-iam-staging.png)

Production:

![IAM production](docs/evidences/14-iam-production.png)

### CloudWatch

Log Group de staging:

![CloudWatch staging](docs/evidences/15-cloudwatch-staging.png)

Eventos contendo `GET /status` com HTTP 200:

![CloudWatch status logs](docs/evidences/16-cloudwatch-status-logs.png)

### Rollback em staging

Rollback executado por SSM utilizando uma imagem anterior do ECR.

![Rollback staging](docs/evidences/17-rollback-staging.png)

## Erros encontrados

Durante a implementação foram encontrados alguns problemas de configuração.

### `.terraform` enviado ao Git

A pasta `.terraform` continha o provider AWS e ultrapassou o limite de tamanho do GitHub.

Correção:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
.env
```

### Terraform sem arquivos de configuração

Erro:

```text
Error: No configuration files
```

`terraform/modules` estava sendo tratado incorretamente pelo Git. Os arquivos `.tf` passaram a ser versionados diretamente e os steps passaram a utilizar:

```yaml
working-directory: terraform/modules
```

### Terraform fmt

Correção:

```bash
terraform fmt -recursive
```

### Availability Zone

A subnet foi criada inicialmente em `us-east-1e`, onde a instância apresentou indisponibilidade.

A subnet foi movida para uma AZ compatível e a instância foi mantida como `t2.micro`.

### IAM Instance Profile

A EC2 foi criada inicialmente sem Instance Profile, impedindo acesso ao ECR.

Foi adicionado:

```hcl
iam_instance_profile = aws_iam_instance_profile.ec2.name
```

### Backend S3

Foram encontrados states diferentes durante os testes. A configuração final mantém state separado para cada ambiente.

### ECR no destroy

O ECR não podia ser apagado com imagens armazenadas.

Correção:

```hcl
force_delete = true
```

### Deploy por SSM

O workflow passou a aguardar Docker e SSM estarem disponíveis e exibir stdout/stderr em caso de falha.

## Decisões técnicas

### EC2 em vez de ECS ou Kubernetes

EC2 foi escolhida para reduzir custo e complexidade.

### Sem NAT Gateway

A EC2 utiliza subnet pública para evitar o custo de NAT Gateway.

### SSM em vez de SSH

A porta 22 não é exposta. Deploy e administração são feitos por Systems Manager.

### ECR com SHA

O SHA do commit é utilizado como tag da imagem para garantir rastreabilidade e permitir rollback.

### HTTPS autoassinado

O certificado autoassinado evita dependência de domínio, ACM e load balancer.

## Limitações conhecidas

- uma EC2 por ambiente;
- sem alta disponibilidade;
- certificado TLS autoassinado;
- acesso por IP público;
- IP pode mudar após recriação;
- sem domínio DNS;
- sem load balancer;
- sem autoscaling.

## Status da implementação

| Recurso | Status | Observação |
|---|---|---|
| Staging | Implementado | EC2 AWS |
| Production | Implementado | EC2 AWS |
| Docker | Implementado | Node.js containerizado |
| `/status` | Implementado | HTTP 200 |
| Terraform | Implementado | State remoto em S3 |
| GitHub Actions | Implementado | CI/CD |
| GitHub Secrets | Implementado | Environments separados |
| ECR | Implementado | Imagens por commit SHA |
| HTTPS/TLS | Implementado | Certificado autoassinado |
| HTTP -> HTTPS | Não aplicável | Porta 80 não exposta |
| IAM | Implementado | ECR, SSM e CloudWatch |
| Security Group | Implementado | Apenas 443 de entrada |
| CloudWatch Logs | Implementado | Nginx access/error |
| Health check | Implementado | `/status` |
| Smoke test | Implementado | Pipeline pós-deploy |
| Rollback | Implementado | Imagem anterior via SHA |
| Branch protection | Dependente de configuração no GitHub | Ruleset para `main` e `staging` |
| CloudWatch Alarm | Proposto | `StatusCheckFailed` |
| DNS próprio | Não implementado | Acesso por IP |
| Certificado público | Não implementado | TLS autoassinado |
| Alta disponibilidade | Não implementado | 1 EC2 por ambiente |
