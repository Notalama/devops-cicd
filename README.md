# Фінальний проєкт - Django CI/CD на AWS

Повний CI/CD конвеєр: Django → Docker → ECR → EKS → RDS, автоматизований через Jenkins + Argo CD, з моніторингом через Prometheus + Grafana.

```
Developer push → Jenkins build → Kaniko → ECR → GitOps values.yaml → Argo CD → EKS
                                                                                    ↕
                                                                                   RDS
                                                                                    ↕
                                                              Prometheus ← scrape ← pods
                                                                    ↕
                                                                 Grafana
```

---

## Демонстрація роботи стеку

### Jenkins — успішний CI build

![Jenkins](jenkins.png)

Jenkins pipeline `django-app` успішно завершив build #15: образ зібрано Kaniko, запушено в ECR з тегом `:15`, `values.yaml` в Git оновлено автоматично.

### Argo CD — GitOps деплой

![Argo CD](argo.png)

Argo CD синхронізував `django-app` з Git-репозиторію. Pod `django-app-fc58895cd-pm26h` у namespace `default` має статус **Healthy**, образ `905418284064.dkr.ecr.eu-north-1.amazonaws.com/project-django-ecr:15` запущено та готово до роботи.

### Django — застосунок доступний

![Django API](image.png)

Django REST API відповідає за публічним AWS ELB URL. Endpoint `/api/items/` повертає дані з RDS PostgreSQL: `{"items": [{"id": 1, "name": "Item One"}, {"id": 2, "name": "Item Two"}]}`.

### Prometheus — збір метрик

![Prometheus](prometheus.png)

Prometheus (Status → Target health) показує активні ServiceMonitors: `kube-prometheus-stack-apiserver` (2/2 up), `kube-prometheus-stack-coredns` (2/2 up), `kube-prometheus-stack-grafana` (1/1 up). Всі системні компоненти кластера успішно scrape-яться.

### Grafana — візуалізація метрик

![Grafana](grafana.png)

Grafana Metrics Explorer підключений до Prometheus як data source. Відображаються метрики кластера: пам'ять вузлів (`node_memory_MemAvailable_bytes:sum`), стан alerts, метрики API server та CoreDNS.

---

## Структура проєкту

```
Project/
├── main.tf                          # Підключення всіх модулів
├── backend.tf                       # S3 backend для Terraform state
├── variables.tf                     # Вхідні змінні (паролі)
├── outputs.tf                       # Виводи (endpoints, URLs)
│
├── modules/
│   ├── s3-backend/                  # S3 + DynamoDB для Terraform state
│   ├── vpc/                         # VPC, підмережі, IGW, NAT, маршрути
│   ├── eks/                         # EKS кластер + node group + EBS CSI driver
│   ├── ecr/                         # ECR репозиторій для Docker образів
│   ├── rds/                         # RDS instance або Aurora cluster
│   ├── jenkins/                     # Jenkins (Helm release в EKS)
│   ├── argo_cd/                     # Argo CD (Helm release в EKS)
│   └── monitoring/                  # Prometheus + Grafana (kube-prometheus-stack)
│       ├── monitoring.tf            # Helm release + ServiceMonitor для Django
│       ├── variables.tf
│       ├── providers.tf
│       ├── values.yaml              # Grafana dashboards, retention, storage
│       └── outputs.tf
│
├── charts/
│   └── django-app/                  # Helm chart для деплою Django
│       ├── Chart.yaml
│       ├── values.yaml              # image.tag оновлюється Jenkins'ом
│       └── templates/
│           ├── deployment.yaml      # Deployment — запускає образ через Dockerfile CMD
│           ├── service.yaml
│           ├── configmap.yaml       # DEBUG, ALLOWED_HOSTS
│           ├── secret.yaml          # DATABASE_URL, SECRET_KEY (керується окремо)
│           └── hpa.yaml
│
└── Django/                          # Вихідний код застосунку
    ├── Dockerfile                   # Multi-stage production build (gunicorn)
    ├── Jenkinsfile                  # Pipeline: Kaniko → ECR → GitOps update
    ├── docker-compose.yaml          # Локальна розробка з PostgreSQL
    └── app/
        ├── manage.py
        ├── requirements.txt
        ├── config/
        │   ├── settings.py
        │   ├── urls.py
        │   └── wsgi.py
        └── api/
            ├── views.py
            └── urls.py
```

---

## Крок 1 — Передумови

### 1.1 Локальні інструменти

```bash
aws --version           # >= 2.x
terraform version       # >= 1.7
kubectl version --client
helm version
git --version
```

### 1.2 AWS IAM — необхідні права

| Сервіс | Дії |
|---|---|
| IAM | CreateRole, AttachRolePolicy, CreateOpenIDConnectProvider |
| VPC | FullAccess |
| EKS | FullAccess |
| ECR | FullAccess |
| RDS | FullAccess |
| S3 | FullAccess |
| DynamoDB | FullAccess |
| ELB | FullAccess (для Jenkins/ArgoCD LoadBalancer) |

### 1.3 Налаштування AWS CLI

```bash
aws configure
# AWS Access Key ID:     <ваш ключ>
# AWS Secret Access Key: <ваш секрет>
# Default region name:   eu-north-1
# Default output format: json
```

Перевірка:

```bash
aws sts get-caller-identity
```

### 1.4 Встановіть паролі перед будь-яким terraform-запуском

Паролі передаються виключно через змінні середовища — ніколи не зберігайте їх у файлах.

```bash
# Відкрийте новий термінал і введіть паролі (не відображаються на екрані)
read -s TF_VAR_db_master_password   && export TF_VAR_db_master_password
read -s TF_VAR_grafana_admin_password && export TF_VAR_grafana_admin_password
```

> Ці змінні потрібно встановлювати кожного разу в новій сесії терміналу. Всі `terraform apply` та `terraform destroy` повинні виконуватися в цьому ж вікні.

---

## Крок 2 — Підготовка Terraform State (перший запуск)

> S3-бакет та DynamoDB-таблиця ще не існують — потрібен локальний перший запуск.

### 2.1 Тимчасово вимкніть S3 backend

Закоментуйте вміст `Project/backend.tf`:

```hcl
# terraform {
#   backend "s3" { ... }
# }
```

### 2.2 Ініціалізуйте та застосуйте лише модуль s3-backend

```bash
cd Project/
terraform init
terraform apply -target=module.s3_backend
```

### 2.3 Поверніть backend.tf та мігруйте state в S3

Розкоментуйте `backend.tf`, потім:

```bash
terraform init -migrate-state
# Підтвердіть перенесення: yes
```

---

## Крок 3 — Розгортання всієї інфраструктури

```bash
terraform fmt -recursive
terraform validate
terraform apply -auto-approve
```

> Орієнтовний час: 20–35 хв (EKS ~15 хв, RDS ~10 хв).

### 3.1 Налаштуйте kubectl

```bash
aws eks update-kubeconfig \
  --region eu-north-1 \
  --name $(terraform output -raw eks_cluster_name)

kubectl get nodes        # всі вузли мають бути Ready
kubectl get pods -A      # перевірте системні поди
```

### 3.2 Застосуйте ServiceMonitor окремим проходом

ServiceMonitor CRD встановлюється разом з `kube-prometheus-stack`. Якщо моніторинг застосовується одночасно з першим `terraform apply`, CRD може ще не існувати. Після успішного розгортання основного стеку виконайте:

```bash
terraform apply -target=module.monitoring -auto-approve
```

---

## Крок 4 — Виправлення після розгортання EKS

Ці кроки виконуються один раз після першого `terraform apply`.

### 4.1 Встановіть StorageClass gp2 як стандартний

EKS не завжди встановлює `gp2` як default StorageClass. Без цього Jenkins PVC не зможе забайндитись:

```bash
kubectl annotate storageclass gp2 \
  storageclass.kubernetes.io/is-default-class=true
```

### 4.2 Збільшіть IMDS hop limit на вузлах EKS

Pods всередині EKS потребують hop limit = 2 для доступу до EC2 Instance Metadata Service (IMDS). Це необхідно для автентифікації в ECR через IAM роль вузла (використовується Kaniko в Jenkins):

```bash
# Отримайте Instance IDs всіх вузлів
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region eu-north-1 \
  --filters "Name=tag:eks:cluster-name,Values=$(terraform output -raw eks_cluster_name)" \
            "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

# Встановіть hop limit = 2 на кожному вузлі
for ID in $INSTANCE_IDS; do
  aws ec2 modify-instance-metadata-options \
    --region eu-north-1 \
    --instance-id $ID \
    --http-put-response-hop-limit 2 \
    --http-endpoint enabled
  echo "Updated: $ID"
done
```

---

## Крок 5 — Налаштування Django Secret

Секрет зберігається лише в Kubernetes і **ніколи не потрапляє в Git**. Argo CD налаштований ігнорувати відмінності в полі `data` цього секрету (`RespectIgnoreDifferences=true`), тому ручне значення залишиться після синхронізацій.

### 5.1 Встановіть реальні значення секрету

```bash
# Введіть пароль БД (не відображається на екрані)
read -s TF_VAR_db_master_password && export TF_VAR_db_master_password

RDS_HOST=$(aws rds describe-db-instances \
  --region eu-north-1 \
  --query "DBInstances[?DBInstanceIdentifier=='project-postgres'].Endpoint.Address" \
  --output text)

kubectl create secret generic django-app-secret \
  --namespace default \
  --from-literal=DATABASE_URL="postgresql://dbadmin:${TF_VAR_db_master_password}@${RDS_HOST}:5432/appdb" \
  --from-literal=SECRET_KEY="$(openssl rand -base64 40)" \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 5.2 Перевірте, що секрет встановлено

```bash
kubectl get secret django-app-secret -n default \
  -o jsonpath='{.data.DATABASE_URL}' | base64 -d && echo ""
# Має показати: postgresql://dbadmin:...@project-postgres...
```

### 5.3 Виконайте міграції бази даних

```bash
POD=$(kubectl get pod -n default -l app=django-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n default $POD -- python /app/manage.py migrate --no-input
```

### 5.4 Перезапустіть Django pods

```bash
kubectl rollout restart deployment django-app -n default
kubectl rollout status deployment django-app -n default
```

---

## Крок 6 — Налаштування Jenkins

### 6.1 Отримайте URL та пароль Jenkins

```bash
kubectl get svc -n jenkins jenkins
# Скопіюйте EXTERNAL-IP, відкрийте http://<EXTERNAL-IP>:8080

kubectl get secret --namespace jenkins jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 -d && echo ""
```

Логін: `admin`, пароль — вивід команди вище.

### 6.2 Додайте Credential у Jenkins UI

Перейдіть: **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**

| ID | Тип | Значення |
|---|---|---|
| `git-token` | Username with password | GitHub username + Personal Access Token (scope: `repo`) |

> ECR автентифікація виконується автоматично через IAM роль EKS-вузла — окремі AWS credentials не потрібні.

### 6.3 Патч сервісу Jenkins для JNLP агентів

Щоб Kubernetes-агенти (Kaniko pods) могли підключатись до Jenkins controller:

```bash
kubectl patch svc jenkins -n jenkins --type='json' -p='[
  {"op":"add","path":"/spec/ports/-","value":{"name":"agent","port":50000,"targetPort":50000}}
]'
```

### 6.4 Створіть Pipeline job

1. **New Item → Pipeline → OK**
2. **Pipeline → Definition**: Pipeline script from SCM
3. **SCM**: Git → `https://github.com/<your-user>/devops-cicd.git`
4. **Credentials**: `git-token`
5. **Script Path**: `Project/Django/Jenkinsfile`
6. **Save → Build Now**

Pipeline виконує:
1. `Checkout` — клонує репозиторій
2. `Build and Push to ECR` — Kaniko збирає образ, пушить у ECR з тегом `BUILD_NUMBER`
3. `Update Helm values` — оновлює `image.tag` у `values.yaml` та пушить в Git

---

## Крок 7 — Перевірка Argo CD

### 7.1 Отримайте URL та пароль Argo CD

```bash
kubectl get svc -n argocd argocd-server
# EXTERNAL-IP → відкрийте http://<EXTERNAL-IP>  (http://, не https://)

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo ""
```

Логін: `admin`, пароль — вивід команди вище.

### 7.2 Перевірте Application

У Argo CD UI відкрийте `django-app`:
- **Sync Status**: `Synced`
- **Health**: `Healthy`
- **Image tag**: відповідає останньому `BUILD_NUMBER` Jenkins

Якщо статус `OutOfSync`, примусово синхронізуйте:

```bash
kubectl annotate application django-app -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

### 7.3 Перевірте Django API

```bash
DJANGO_URL=$(kubectl get svc django-app -n default \
  -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}')

curl ${DJANGO_URL}/healthz/
# {"status": "ok"}

curl ${DJANGO_URL}/api/items/
# {"items": [{"id": 1, "name": "Item One"}, {"id": 2, "name": "Item Two"}]}
```

---

## Крок 8 — Моніторинг: Prometheus + Grafana

### 8.1 Перевірка статусу ресурсів

```bash
kubectl get pods -n jenkins
kubectl get pods -n argocd
kubectl get pods -n monitoring
```

Всі поди мають бути `Running`. У `monitoring` очікуються:

```
pod/kube-prometheus-stack-grafana-...
pod/kube-prometheus-stack-kube-state-metrics-...
pod/kube-prometheus-stack-operator-...
pod/kube-prometheus-stack-prometheus-node-exporter-...  (по одному на кожен вузол)
pod/prometheus-kube-prometheus-stack-prometheus-0
```

### 8.2 Port-forward до Prometheus

```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090
```

Відкрийте **http://localhost:9090** → **Status → Target health**

Перевірте метрики:
- `up` — всі scrape targets мають значення `1`
- `kube_pod_status_phase` — статус подів кластера
- `container_cpu_usage_seconds_total` — CPU навантаження

### 8.3 Port-forward до Grafana

```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-grafana 3000:80
```

Відкрийте **http://localhost:3000**

- Логін: `admin`
- Пароль: значення `TF_VAR_grafana_admin_password` (яке ви встановили)

### 8.4 Grafana Dashboards

Перейдіть: **Dashboards → Browse**

| Дашборд | Grafana ID | Що показує |
|---|---|---|
| Kubernetes Cluster | 6417 | Nodes, Pods, CPU/RAM кластера |
| Node Exporter Full | 1860 | Детальні метрики вузлів |
| Kubernetes Pods | 6336 | CPU/RAM/Network по подах |
| Kubernetes Deployments | 8588 | Стан deployments |
| CoreDNS | 5926 | Метрики DNS |

Або використовуйте **Explore → Metrics** для перегляду всіх зібраних метрик.

---

## Крок 9 — Повний CI/CD цикл (перевірка)

```
1. Змініть код у Django/app/api/views.py
2. git add . && git commit -m "feat: update api" && git push origin main
3. Jenkins автоматично запускає build (або запустіть вручну: Build Now)
4. Kaniko → збирає образ → пушить у ECR з тегом BUILD_NUMBER
5. Jenkins → оновлює image.tag у Project/charts/django-app/values.yaml → git push
6. Argo CD → помічає зміну в Git → синхронізує → rolling update в EKS
7. Нова версія Django доступна за тим самим зовнішнім URL
```

---

## Корисні команди

### Terraform

```bash
terraform output -json                              # всі виводи у JSON
terraform state list                               # список ресурсів у state
terraform state show module.eks.aws_eks_cluster.this[0]
```

### Kubernetes

```bash
kubectl get pods -A                                # всі поди
kubectl get all -n jenkins                         # Jenkins ресурси
kubectl get all -n argocd                          # Argo CD ресурси
kubectl get all -n monitoring                      # Prometheus + Grafana ресурси
kubectl get all -n default                         # Django ресурси
kubectl logs -n jenkins <pod-name> -f              # логи Jenkins controller
kubectl describe pod <pod> -n <ns>                 # деталі поду
kubectl get events -n default --sort-by='.lastTimestamp'
```

### Секрет Django (оновлення)

```bash
# Оновити DATABASE_URL (після зміни пароля або endpoint)
read -s TF_VAR_db_master_password && export TF_VAR_db_master_password

kubectl create secret generic django-app-secret \
  --namespace default \
  --from-literal=DATABASE_URL="postgresql://dbadmin:${TF_VAR_db_master_password}@<RDS_HOST>:5432/appdb" \
  --from-literal=SECRET_KEY="$(openssl rand -base64 40)" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment django-app -n default
```

### Моніторинг (port-forward всіх сервісів)

```bash
# В окремих вкладках терміналу:
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
kubectl port-forward svc/argocd-server 8081:80 -n argocd
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```

### ECR

```bash
# Ручний логін (для тестування)
aws ecr get-login-password --region eu-north-1 | \
  docker login --username AWS \
  --password-stdin $(terraform output -raw ecr_repository_url | cut -d/ -f1)

# Список образів в репозиторії
aws ecr list-images \
  --repository-name $(terraform output -raw ecr_repository_url | cut -d/ -f2) \
  --region eu-north-1
```

### RDS

```bash
# Підключення до PostgreSQL через тимчасовий pod
kubectl run psql-client --rm -it --image=postgres:15-alpine \
  --env="PGPASSWORD=${TF_VAR_db_master_password}" -- \
  psql -h $(terraform output -raw rds_postgres_endpoint) \
       -U dbadmin -d appdb
```

---

## Видалення інфраструктури

```bash
# Встановіть паролі перед destroy
read -s TF_VAR_db_master_password   && export TF_VAR_db_master_password
read -s TF_VAR_grafana_admin_password && export TF_VAR_grafana_admin_password

terraform destroy
```

> Після `destroy` S3-бакет та DynamoDB-таблиця також видаляються. При наступному розгортанні починайте з Кроку 2.

---

## Усунення типових помилок

| Проблема | Вирішення |
|---|---|
| `Error: Backend S3 bucket not found` | Виконайте Крок 2 (перший запуск без backend) |
| `EKS nodes NotReady` | `kubectl describe node <name>` — перевірте taints/events |
| `Jenkins PVC Pending` | `kubectl annotate storageclass gp2 storageclass.kubernetes.io/is-default-class=true` |
| `Kaniko: Unable to locate credentials` | Збільшіть IMDS hop limit до 2 (Крок 4.2) |
| `ECR InvalidSignatureException` | Переконайтеся, що до IAM ролі вузла приєднана `AmazonEC2ContainerRegistryPowerUser` |
| Jenkins agent offline (порт 50000) | `kubectl patch svc jenkins -n jenkins` — додайте порт 50000 (Крок 6.3) |
| `Invalid option type "timestamps"` | Видаліть `timestamps()` з блоку `options` в Jenkinsfile |
| `Django: ValueError: No support for ''` | Оновіть `django-app-secret` реальним `DATABASE_URL` (Крок 5) |
| Argo CD перезаписує секрет | `RespectIgnoreDifferences=true` + `ignoreDifferences` для `/data` секрету (вже застосовано) |
| `ServiceMonitor CRD not found` | Застосуйте `terraform apply -target=module.monitoring` після першого apply |
| `Argo CD: ComparisonError` | Перевірте, чи `source.path` у Application збігається з реальним шляхом в Git |
| `RDS: timeout` | Перевірте Security Group — allowed_cidr_blocks має включати VPC CIDR |
| `git push 403` | Переконайтеся, що GitHub PAT має права `repo` (read/write) та використовується credential `git-token` |
| Grafana pod `CrashLoopBackOff` | `kubectl get pvc -n monitoring` — StorageClass `gp2` має бути default (Крок 4.1) |

---

## Модуль `rds`

Універсальний модуль для розгортання реляційної бази даних на AWS.
Підтримує **звичайну RDS instance** (PostgreSQL / MySQL) та **Aurora Cluster** — вибір здійснюється прапором `use_aurora`.

### Що створює модуль `rds`

| Ресурс | Умова |
|---|---|
| `aws_db_subnet_group` | Завжди |
| `aws_security_group` | Завжди |
| `aws_db_parameter_group` | `use_aurora = false` |
| `aws_rds_cluster_parameter_group` | `use_aurora = true` |
| `aws_db_instance` | `use_aurora = false` |
| `aws_rds_cluster` | `use_aurora = true` |
| `aws_rds_cluster_instance` × N | `use_aurora = true`, N = `replica_count` |
| `aws_iam_role` + policy | Завжди (Enhanced Monitoring) |

### Приклади використання

#### Звичайна RDS — PostgreSQL

```hcl
module "rds" {
  source = "./modules/rds"

  identifier      = "my-app-postgres"
  use_aurora      = false
  engine          = "postgres"
  engine_version  = "15.10"
  instance_class  = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  multi_az              = true

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false
}
```

#### Aurora PostgreSQL Cluster

```hcl
module "rds_aurora" {
  source = "./modules/rds"

  identifier      = "my-app-aurora"
  use_aurora      = true
  engine          = "aurora-postgresql"
  engine_version  = "15.8"
  instance_class  = "db.r6g.large"
  replica_count   = 2

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

### Виводи модуля `rds`

| Output | Опис |
|---|---|
| `db_endpoint` | Основний endpoint для підключення |
| `db_reader_endpoint` | Reader endpoint (Aurora) або той самий (RDS) |
| `db_port` | Порт БД |
| `db_name` | Назва початкової БД |
| `master_username` | Master username |
| `security_group_id` | ID Security Group |
| `db_subnet_group_name` | Назва Subnet Group |
| `parameter_group_name` | Назва Parameter Group |
| `rds_instance_id` | (RDS) ID інстансу |
| `aurora_cluster_id` | (Aurora) ID кластера |
| `aurora_instance_ids` | (Aurora) List ID усіх instances |

### Змінні модуля `rds`

| Змінна | Тип | За замовч. | Обов'язкова | Опис |
|---|---|---|---|---|
| `identifier` | `string` | — | ✅ | Унікальний префікс для всіх ресурсів |
| `use_aurora` | `bool` | `false` | — | `true` → Aurora Cluster, `false` → RDS Instance |
| `engine` | `string` | `"postgres"` | — | `postgres`, `mysql`, `aurora-postgresql`, `aurora-mysql` |
| `engine_version` | `string` | `"15.10"` | — | Версія движка |
| `instance_class` | `string` | `"db.t3.medium"` | — | Клас інстансу |
| `allocated_storage` | `number` | `20` | — | (RDS) Початковий розмір ГБ |
| `max_allocated_storage` | `number` | `100` | — | (RDS) Макс. розмір autoscaling ГБ |
| `storage_type` | `string` | `"gp3"` | — | (RDS) Тип EBS: gp2/gp3/io1/io2 |
| `multi_az` | `bool` | `false` | — | (RDS) Увімкнути Multi-AZ |
| `replica_count` | `number` | `1` | — | (Aurora) Кількість instances |
| `database_name` | `string` | — | ✅ | Назва початкової БД |
| `master_username` | `string` | — | ✅ | Master username |
| `master_password` | `string` | — | ✅ | Master password (sensitive) |
| `vpc_id` | `string` | — | ✅ | ID VPC |
| `subnet_ids` | `list(string)` | — | ✅ | Мінімум 2 підмережі в різних AZ |
| `allowed_cidr_blocks` | `list(string)` | `[]` | — | CIDR з доступом до БД |
| `allowed_security_group_ids` | `list(string)` | `[]` | — | SG з доступом до БД |
| `backup_retention_period` | `number` | `7` | — | Дні зберігання backup |
| `deletion_protection` | `bool` | `true` | — | Захист від видалення |
| `skip_final_snapshot` | `bool` | `false` | — | Пропустити фінальний snapshot |
| `storage_encrypted` | `bool` | `true` | — | Шифрувати storage |
| `kms_key_id` | `string` | `null` | — | ARN KMS-ключа |
| `tags` | `map(string)` | `{}` | — | Теги для всіх ресурсів |
