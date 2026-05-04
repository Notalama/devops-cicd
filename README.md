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

## Структура проєкту

```
Project/
├── main.tf                          # Підключення всіх модулів (включно з monitoring)
├── backend.tf                       # S3 backend для Terraform state
├── variables.tf                     # Вхідні змінні (DB пароль тощо)
├── outputs.tf                       # Виводи (endpoints, URLs)
├── Jenkinsfile                      # Pipeline для збірки (кореневий)
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
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── configmap.yaml
│           └── hpa.yaml
│
└── Django/                          # Вихідний код застосунку
    ├── Dockerfile                   # Multi-stage production build
    ├── Jenkinsfile                  # Pipeline для Django (context-aware)
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

## Крок 1 - Передумови

### 1.1 Локальні інструменти

```bash
# Перевірте наявність:
aws --version           # >= 2.x
terraform version       # >= 1.7
kubectl version --client
helm version
docker --version
git --version
```

### 1.2 AWS IAM - необхідні права

Обліковий запис (або роль), з якого запускається Terraform, повинен мати права на:

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
# Default region name:   us-west-2
# Default output format: json
```

Перевірка:

```bash
aws sts get-caller-identity
```

---

### 1.4 Встановіть обидва паролі перед будь-яким terraform-запуском

```bash
export TF_VAR_db_master_password="YourStr0ngPassword!"
export TF_VAR_grafana_admin_password="GrafanaPass123!"
```

---

## Крок 2 - Підготовка Terraform State (перший запуск)

> S3-бакет та DynamoDB-таблиця для зберігання state ще не існують - потрібен локальний перший запуск.

### 2.1 Тимчасово вимкніть S3 backend

Закоментуйте вміст `backend.tf`:

```hcl
# terraform {
#   backend "s3" { ... }
# }
```

### 2.2 Встановіть паролі через змінні середовища

```bash
export TF_VAR_db_master_password="YourStr0ngPassword!"
export TF_VAR_grafana_admin_password="GrafanaPass123!"
```

### 2.3 Ініціалізуйте та застосуйте лише модуль s3-backend

```bash
cd Project/
terraform init
terraform apply -target=module.s3_backend
```

### 2.4 Поверніть backend.tf та мігруйте state в S3

Розкоментуйте `backend.tf`, потім:

```bash
terraform init -migrate-state
# Підтвердіть перенесення: yes
```

---

## Крок 3 - Розгортання всієї інфраструктури

```bash
# Встановіть паролі (якщо нова сесія)
export TF_VAR_db_master_password="YourStr0ngPassword!"
export TF_VAR_grafana_admin_password="GrafanaPass123!"

terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

> Орієнтовний час: 20–35 хв (EKS ~15 хв, RDS ~10 хв).

### 3.1 Перевірте виводи

```bash
terraform output eks_cluster_name
terraform output ecr_repository_url
terraform output jenkins_namespace
terraform output argo_cd_namespace
terraform output rds_postgres_endpoint
terraform output aurora_writer_endpoint
terraform output monitoring_namespace
terraform output grafana_service_name
terraform output prometheus_service_name
```

### 3.2 Налаштуйте kubectl

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name $(terraform output -raw eks_cluster_name)

kubectl get nodes        # усі вузли мають бути Ready
kubectl get pods -A      # перевірте системні поди
```

---

## Крок 4 - Налаштування values.yaml для Django

Замініть `DATABASE_URL` на реальний RDS endpoint:

```bash
RDS_HOST=$(terraform output -raw rds_postgres_endpoint)
```

Відредагуйте `Project/charts/django-app/values.yaml`:

```yaml
env:
  DATABASE_URL: "postgres://dbadmin:YourStr0ngPassword!@<RDS_HOST>:5432/appdb"
  ALLOWED_HOSTS: "*"
  DEBUG: "False"

image:
  repository: <ECR_REPOSITORY_URL>  # з terraform output ecr_repository_url
  tag: "latest"
```

Збережіть та закомітьте зміни в Git - Argo CD підхопить їх автоматично.

---

## Крок 5 - Налаштування Jenkins

### 5.1 Отримайте URL та пароль Jenkins

```bash
kubectl get svc -n jenkins
# Скопіюйте EXTERNAL-IP

kubectl get secret --namespace jenkins jenkins \
  -o jsonpath="{.data.jenkins-admin-password}" | base64 -d
```

### 5.2 Додайте Credentials у Jenkins UI

Перейдіть: **Manage Jenkins → Credentials → System → Global credentials**

| ID | Тип | Значення |
|---|---|---|
| `aws-jenkins-creds` | AWS Credentials | AWS Access Key ID + Secret |
| `git-token` | Username with password | GitHub username + PAT |

> GitHub PAT потрібні права: `repo` (read/write).

### 5.3 Створіть Pipeline job

1. **New Item → Pipeline**
2. **Pipeline → Definition**: Pipeline script from SCM
3. **SCM**: Git → `https://github.com/Notalama/devops-cicd.git`
4. **Script Path**: `Project/Django/Jenkinsfile`
5. **Build Triggers**: Poll SCM або GitHub webhook

### 5.4 Встановіть ECR URL як environment variable

У **Pipeline job → Configure → Build Environment**:

```
ECR_REPOSITORY_URL = <значення з terraform output ecr_repository_url>
```

### 5.5 Запустіть перший build

**Build Now** - pipeline виконає:
1. `Checkout` - клонує репозиторій
2. `Build and Push to ECR` - Kaniko збирає образ та пушить з тегом BUILD_NUMBER
3. `Update Helm values` - оновлює `image.tag` в `values.yaml` та пушить в Git

---

## Крок 6 - Перевірка Argo CD

### 6.1 Отримайте URL та пароль Argo CD

```bash
kubectl get svc -n argocd
# EXTERNAL-IP → відкрийте в браузері

kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

Логін: `admin` + пароль вище.

### 6.2 Перевірте Application

У Argo CD UI відкрийте `django-app`:
- **Status**: `Synced` + `Healthy`
- **Images**: тег відповідає останньому BUILD_NUMBER Jenkins

Якщо статус `OutOfSync`:

```bash
argocd app sync django-app   # примусова синхронізація
```

### 6.3 Перевірте деплой Django

```bash
kubectl get pods -n django-app
kubectl get svc -n django-app

# Отримайте зовнішній IP
DJANGO_IP=$(kubectl get svc django-app -n django-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://${DJANGO_IP}/healthz/
# {"status": "ok"}

curl http://${DJANGO_IP}/api/items/
# {"items": [...]}
```

---

## Крок 7 - Моніторинг: Prometheus + Grafana

### 7.1 Перевірка статусу ресурсів у всіх namespace

```bash
kubectl get all -n jenkins
kubectl get all -n argocd
kubectl get all -n monitoring
```

Всі поди мають бути в стані `Running`. У `monitoring` очікуються:

```
pod/kube-prometheus-stack-grafana-...
pod/kube-prometheus-stack-kube-state-metrics-...
pod/kube-prometheus-stack-operator-...
pod/kube-prometheus-stack-prometheus-node-exporter-...
pod/prometheus-kube-prometheus-stack-prometheus-0
```

### 7.2 Port-forward до Grafana

```bash
kubectl port-forward svc/$(terraform output -raw grafana_service_name) \
  3000:80 -n monitoring
```

Відкрийте в браузері: **http://localhost:3000**

- Логін: `admin`
- Пароль: значення `TF_VAR_grafana_admin_password`

### 7.3 Port-forward до Prometheus

```bash
kubectl port-forward svc/$(terraform output -raw prometheus_service_name) \
  9090:9090 -n monitoring
```

Відкрийте в браузері: **http://localhost:9090**

Перевірте метрики:
- `up` - всі scrape targets мають значення `1`
- `container_cpu_usage_seconds_total` - CPU навантаження контейнерів
- `kube_pod_status_phase` - статус подів

### 7.4 Port-forward до Jenkins та Argo CD

```bash
# Jenkins
kubectl port-forward svc/jenkins 8080:8080 -n jenkins
# http://localhost:8080

# Argo CD
kubectl port-forward svc/argocd-server 8081:443 -n argocd
# https://localhost:8081  (підтвердіть self-signed cert)
```

### 7.5 Grafana Dashboards

Після входу в Grafana перейдіть: **Dashboards → Browse**

Автоматично імпортовані дашборди:

| Дашборд | Grafana ID | Що показує |
|---|---|---|
| Kubernetes Cluster | 6417 | Nodes, Pods, CPU/RAM кластера |
| Node Exporter Full | 1860 | Детальні метрики вузлів |
| Kubernetes Pods | 6336 | CPU/RAM/Network по подах |
| Kubernetes Deployments | 8588 | Стан deployments |
| CoreDNS | 5926 | Метрики DNS |

### 7.6 Додати метрики Django (опціонально)

Щоб Django публікував метрики для Prometheus, додайте у `Django/app/requirements.txt`:

```
django-prometheus==2.3.1
```

У `config/settings.py` додайте:

```python
INSTALLED_APPS = [
    ...
    "django_prometheus",
]

MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    ...
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]
```

У `config/urls.py`:

```python
urlpatterns = [
    path("", include("django_prometheus.urls")),
    ...
]
```

Після цього `/metrics` endpoint буде автоматично зібраний через `ServiceMonitor` `django-app` у namespace `monitoring`.

---

## Крок 8 - Локальна розробка Django (docker-compose)

```bash
cd Project/Django/

# Запуск з PostgreSQL у Docker
docker compose up -d

# Застосуйте міграції (при першому запуску)
docker compose exec web python manage.py migrate
docker compose exec web python manage.py createsuperuser

# Відкрийте: http://localhost:8000/healthz/
```

---

## Крок 9 - Повний CI/CD цикл (перевірка)

```
1. Змініть код у Django/app/api/views.py
2. git add . && git commit -m "feat: update api" && git push origin main
3. Jenkins автоматично запускає build (або запустіть вручну)
4. Kaniko → збирає новий образ → пушить в ECR з тегом BUILD_NUMBER
5. Jenkins → оновлює image.tag у Project/charts/django-app/values.yaml
6. Argo CD → помічає зміну в Git → синхронізує → оновлює поди в EKS
7. Нова версія застосунку доступна за зовнішнім IP
```

---

## Корисні команди

### Terraform

```bash
terraform output -json                        # всі виводи у JSON
terraform state list                          # список ресурсів у state
terraform state show module.rds_postgres.aws_db_instance.this[0]
```

### Kubernetes

```bash
kubectl get pods -A                           # всі поди
kubectl get all -n jenkins                    # Jenkins ресурси
kubectl get all -n argocd                     # Argo CD ресурси
kubectl get all -n monitoring                 # Prometheus + Grafana ресурси
kubectl logs -n jenkins <pod-name> -f         # логи Jenkins
kubectl describe pod <pod> -n <ns>            # деталі поду
kubectl get events -n django-app --sort-by='.lastTimestamp'
```

### Моніторинг

```bash
# Port-forward (всі три одночасно в окремих терміналах)
kubectl port-forward svc/jenkins 8080:8080 -n jenkins &
kubectl port-forward svc/argocd-server 8081:443 -n argocd &
kubectl port-forward svc/$(terraform output -raw grafana_service_name) 3000:80 -n monitoring &

# Prometheus targets - перевірити scrape стан
kubectl port-forward svc/$(terraform output -raw prometheus_service_name) 9090:9090 -n monitoring

# Перевірити ServiceMonitor для Django
kubectl get servicemonitor -n monitoring
kubectl describe servicemonitor django-app -n monitoring
```

### ECR

```bash
# Ручний логін та пуш (для тестування)
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS \
  --password-stdin $(terraform output -raw ecr_repository_url | cut -d/ -f1)

docker build -t django-app Project/Django/
docker tag django-app:latest $(terraform output -raw ecr_repository_url):manual
docker push $(terraform output -raw ecr_repository_url):manual
```

### RDS

```bash
# Підключення до PostgreSQL через kubectl port-forward
kubectl run psql-client --rm -it --image=postgres:15-alpine \
  --env="PGPASSWORD=YourStr0ngPassword!" -- \
  psql -h $(terraform output -raw rds_postgres_endpoint) \
       -U dbadmin -d appdb
```

---

## Видалення інфраструктури

```bash
export TF_VAR_db_master_password="YourStr0ngPassword!"
export TF_VAR_grafana_admin_password="GrafanaPass123!"
terraform destroy
```

> Після `destroy` S3-бакет та DynamoDB-таблиця також видаляються. При наступному розгортанні починайте з Кроку 2.

---

## Усунення типових помилок

| Проблема | Вирішення |
|---|---|
| `Error: Backend S3 bucket not found` | Виконайте Крок 2 (перший запуск без backend) |
| `EKS nodes NotReady` | `kubectl describe node <name>` - перевірте taints/events |
| `Kaniko: unauthorized` | Перевірте credentials `aws-jenkins-creds` у Jenkins |
| `Argo CD: ComparisonError` | Перевірте, чи `app_target_path` збігається з реальним шляхом в Git |
| `RDS: timeout` | Перевірте Security Group - `allowed_cidr_blocks` має включати VPC CIDR |
| `TF_VAR_db_master_password not set` | `export TF_VAR_db_master_password="..."` перед `terraform apply` |
| `TF_VAR_grafana_admin_password not set` | `export TF_VAR_grafana_admin_password="..."` перед `terraform apply` |
| Grafana pod `CrashLoopBackOff` | Перевірте PVC: `kubectl get pvc -n monitoring` - StorageClass `gp2` має бути доступний |
| Prometheus не scrape Django | `kubectl get servicemonitor -n monitoring` - перевірте labels на Service Django |

---

## Модуль `rds`

Універсальний модуль для розгортання реляційної бази даних на AWS.
Підтримує **звичайну RDS instance** (PostgreSQL / MySQL) та **Aurora Cluster** - вибір здійснюється прапором `use_aurora`.

### Що створює модуль `rds`

| Ресурс | Умова |
|---|---|
| `aws_db_subnet_group` | Завжди |
| `aws_security_group` | Завжди |
| `aws_db_parameter_group` | `use_aurora = false` (RDS) або Aurora instance PG |
| `aws_rds_cluster_parameter_group` | `use_aurora = true` |
| `aws_db_instance` | `use_aurora = false` |
| `aws_rds_cluster` | `use_aurora = true` |
| `aws_rds_cluster_instance` × N | `use_aurora = true`, N = `replica_count` |
| `aws_iam_role` + policy | Завжди (Enhanced Monitoring) |

### Приклади використання

#### Звичайна RDS - PostgreSQL

```hcl
module "rds" {
  source = "./modules/rds"

  identifier      = "my-app-postgres"
  use_aurora      = false
  engine          = "postgres"
  engine_version  = "15.8"
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
  engine_version  = "15.4"
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
| `db_reader_endpoint` | Reader endpoint (Aurora) або той самий endpoint (RDS) |
| `db_port` | Порт БД |
| `db_name` | Назва початкової БД |
| `master_username` | Master username |
| `security_group_id` | ID Security Group |
| `db_subnet_group_name` | Назва Subnet Group |
| `parameter_group_name` | Назва Parameter Group |
| `rds_instance_id` | (RDS) ID інстансу |
| `aurora_cluster_id` | (Aurora) ID кластера |
| `aurora_instance_ids` | (Aurora) List ID усіх instances |

### Опис змінних модуля `rds`

| Змінна | Тип | За замовч. | Обов'язкова | Опис |
|---|---|---|---|---|
| `identifier` | `string` | - | ✅ | Унікальний префікс для всіх ресурсів |
| `use_aurora` | `bool` | `false` | - | `true` → Aurora Cluster, `false` → RDS Instance |
| `engine` | `string` | `"postgres"` | - | `postgres`, `mysql`, `aurora-postgresql`, `aurora-mysql` |
| `engine_version` | `string` | `"15.8"` | - | Версія движка |
| `instance_class` | `string` | `"db.t3.medium"` | - | Клас інстансу |
| `allocated_storage` | `number` | `20` | - | (RDS) Початковий розмір ГБ |
| `max_allocated_storage` | `number` | `100` | - | (RDS) Макс. розмір autoscaling ГБ |
| `storage_type` | `string` | `"gp3"` | - | (RDS) Тип EBS: gp2/gp3/io1/io2 |
| `multi_az` | `bool` | `false` | - | (RDS) Увімкнути Multi-AZ |
| `replica_count` | `number` | `1` | - | (Aurora) Кількість instances |
| `database_name` | `string` | - | ✅ | Назва початкової БД |
| `master_username` | `string` | - | ✅ | Master username |
| `master_password` | `string` | - | ✅ | Master password (sensitive) |
| `vpc_id` | `string` | - | ✅ | ID VPC |
| `subnet_ids` | `list(string)` | - | ✅ | Мінімум 2 підмережі в різних AZ |
| `allowed_cidr_blocks` | `list(string)` | `[]` | - | CIDR з доступом до БД |
| `allowed_security_group_ids` | `list(string)` | `[]` | - | SG з доступом до БД |
| `backup_retention_period` | `number` | `7` | - | Дні зберігання backup |
| `deletion_protection` | `bool` | `true` | - | Захист від видалення |
| `skip_final_snapshot` | `bool` | `false` | - | Пропустити фінальний snapshot |
| `storage_encrypted` | `bool` | `true` | - | Шифрувати storage |
| `kms_key_id` | `string` | `null` | - | ARN KMS-ключа |
| `tags` | `map(string)` | `{}` | - | Теги для всіх ресурсів |
