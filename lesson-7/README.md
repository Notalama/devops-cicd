# Lesson 8-9: Jenkins + Terraform + ECR + Helm + Argo CD

Цей проєкт реалізує повний CI/CD конвеєр для Django застосунку без ручного деплою:

1. Jenkins збирає Docker image;
2. Jenkins пушить image в Amazon ECR;
3. Jenkins оновлює `image.tag` у `values.yaml` GitOps-репозиторію;
4. Argo CD автоматично синхронізує зміни в EKS кластер.

## Що створює Terraform

- `modules/s3-backend`: S3 + lock-файл backend для Terraform state.
- `modules/vpc`: VPC, підмережі, маршрутизація.
- `modules/eks`: EKS кластер + node group.
- `modules/ecr`: ECR репозиторій для Django image.
- `modules/jenkins`: Jenkins Helm release + Kubernetes agent для Kaniko/Git.
- `modules/argo_cd`: Argo CD Helm release + Argo CD Application (GitOps).

## Як застосувати Terraform

> Перший запуск робіть локально (коли `s3-backend` ще не існує), далі мігруйте state в S3 backend.

```bash
terraform init
terraform fmt -recursive
terraform plan
terraform apply
```

Після створення S3 backend (якщо робили локально) виконайте:

```bash
terraform init -migrate-state
```

### Корисні outputs

```bash
terraform output eks_cluster_name
terraform output ecr_repository_url
terraform output jenkins_namespace
terraform output argo_cd_namespace
terraform output rds_postgres_endpoint
terraform output aurora_writer_endpoint
terraform output aurora_reader_endpoint
```

## Як перевірити Jenkins job

1. Відкрийте Jenkins:
   - `kubectl get svc -n jenkins`
   - перейдіть на `EXTERNAL-IP` сервісу.
2. Створіть Pipeline job, який використовує `lesson-7/Jenkinsfile`.
3. Додайте credentials:
   - `aws-jenkins-creds` (AWS Access Key/Secret);
   - `git-token` (username + personal access token для GitHub).
4. Встановіть у `Jenkinsfile` або через параметри job:
   - `ECR_REPOSITORY_URL`;
   - `GITOPS_REPO_URL`;
   - `GITOPS_VALUES_FILE`.
5. Запустіть job і перевірте:
   - у логах є пуш образу в ECR;
   - у GitOps repo оновився `image.tag` в `values.yaml`.

## Як побачити результат в Argo CD

1. Перевірте Argo CD сервіси:

```bash
kubectl get svc -n argocd
```

2. Отримайте admin пароль:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

3. Увійдіть в Argo CD UI (`admin` + пароль).
4. Відкрийте `Application` `django-app`:
   - статус має стати `Synced` / `Healthy`;
   - після нового Jenkins build Argo CD автоматично підтягує новий тег з Git.

## Важливо щодо вартості AWS

Після перевірки обов'язково видаляйте інфраструктуру:

```bash
terraform destroy
```

Пам'ятайте: після `terraform destroy` також видаляються S3 backend ресурси (bucket/lock), тому для наступного циклу їх доведеться створювати знову.

---

# Модуль `rds`

Універсальний модуль для розгортання реляційної бази даних на AWS.
Підтримує **звичайну RDS instance** (PostgreSQL / MySQL) та **Aurora Cluster** — вибір здійснюється прапором `use_aurora`.

## Структура модуля

```
modules/rds/
├── variables.tf   # Всі вхідні змінні
├── shared.tf      # DB Subnet Group, Security Group, Parameter Groups
├── rds.tf         # aws_db_instance (use_aurora = false)
├── aurora.tf      # aws_rds_cluster + aws_rds_cluster_instance (use_aurora = true)
└── outputs.tf     # Виводи (endpoints, IDs, SG тощо)
```

## Що створює модуль `rds`

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

## Приклади використання

### 1. Звичайна RDS — PostgreSQL

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
  multi_az              = true       # HA для production

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [module.eks.node_security_group_id]

  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false

  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}
```

### 2. Звичайна RDS — MySQL

```hcl
module "rds_mysql" {
  source = "./modules/rds"

  identifier      = "my-app-mysql"
  use_aurora      = false
  engine          = "mysql"
  engine_version  = "8.0.40"
  instance_class  = "db.t3.large"

  allocated_storage     = 50
  max_allocated_storage = 200
  storage_type          = "gp3"
  multi_az              = true

  database_name   = "appdb"
  master_username = "admin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_cidr_blocks = ["10.0.0.0/16"]
}
```

### 3. Aurora PostgreSQL Cluster

```hcl
module "rds_aurora_pg" {
  source = "./modules/rds"

  identifier      = "my-app-aurora-pg"
  use_aurora      = true
  engine          = "aurora-postgresql"
  engine_version  = "15.4"
  instance_class  = "db.r6g.large"
  replica_count   = 2               # 1 writer + 1 reader

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allowed_security_group_ids = [module.eks.node_security_group_id]

  backup_retention_period = 14
  deletion_protection     = true
  skip_final_snapshot     = false

  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}
```

### 4. Aurora MySQL Cluster

```hcl
module "rds_aurora_mysql" {
  source = "./modules/rds"

  identifier      = "my-app-aurora-mysql"
  use_aurora      = true
  engine          = "aurora-mysql"
  engine_version  = "8.0.mysql_aurora.3.06.0"
  instance_class  = "db.r6g.large"
  replica_count   = 3

  database_name   = "appdb"
  master_username = "admin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}
```

## Виводи модуля `rds`

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

## Опис змінних

### Загальні

| Змінна | Тип | За замовч. | Обов'язкова | Опис |
|---|---|---|---|---|
| `identifier` | `string` | — | ✅ | Унікальний префікс для всіх ресурсів |
| `use_aurora` | `bool` | `false` | — | `true` → Aurora Cluster, `false` → RDS Instance |
| `tags` | `map(string)` | `{}` | — | Теги для всіх ресурсів |

### Engine

| Змінна | Тип | За замовч. | Опис |
|---|---|---|---|
| `engine` | `string` | `"postgres"` | `postgres`, `mysql`, `aurora-postgresql`, `aurora-mysql` |
| `engine_version` | `string` | `"15.8"` | Версія движка |
| `parameter_group_family` | `string` | `null` | Сімейство PG (обчислюється автоматично) |

**Підтримувані комбінації `engine` / `engine_version`:**

| `use_aurora` | `engine` | `engine_version` приклад | `parameter_group_family` |
|---|---|---|---|
| `false` | `postgres` | `15.8`, `14.13` | `postgres15`, `postgres14` |
| `false` | `mysql` | `8.0.40`, `5.7.44` | `mysql8.0`, `mysql5.7` |
| `true` | `aurora-postgresql` | `15.4`, `14.9` | `aurora-postgresql15` |
| `true` | `aurora-mysql` | `8.0.mysql_aurora.3.06.0` | `aurora-mysql8.0` |

### Мережа

| Змінна | Тип | За замовч. | Опис |
|---|---|---|---|
| `vpc_id` | `string` | — | ID VPC |
| `subnet_ids` | `list(string)` | — | Мінімум 2 приватні підмережі в різних AZ |
| `port` | `number` | `null` | Порт БД (auto: 5432/3306) |
| `allowed_cidr_blocks` | `list(string)` | `[]` | CIDR, яким дозволено доступ |
| `allowed_security_group_ids` | `list(string)` | `[]` | SG-ідентифікатори з доступом |

### Ресурси

| Змінна | Тип | За замовч. | Опис |
|---|---|---|---|
| `instance_class` | `string` | `"db.t3.medium"` | Клас інстансу |
| `allocated_storage` | `number` | `20` | (RDS) Початковий розмір ГБ |
| `max_allocated_storage` | `number` | `100` | (RDS) Макс. розмір autoscaling ГБ |
| `storage_type` | `string` | `"gp3"` | (RDS) Тип EBS: gp2/gp3/io1/io2 |
| `iops` | `number` | `null` | (RDS) IOPS для io1/io2/gp3 |
| `multi_az` | `bool` | `false` | (RDS) Увімкнути Multi-AZ |
| `replica_count` | `number` | `1` | (Aurora) Кількість instances у кластері |

### Облікові дані

| Змінна | Тип | Опис |
|---|---|---|
| `database_name` | `string` | Назва початкової БД |
| `master_username` | `string` | Master username |
| `master_password` | `string` (sensitive) | Master password — передавати через `TF_VAR_db_master_password` або Secrets Manager |

### Backup та Maintenance

| Змінна | Тип | За замовч. | Опис |
|---|---|---|---|
| `backup_retention_period` | `number` | `7` | Дні зберігання backup (0 = вимкнути) |
| `preferred_backup_window` | `string` | `"03:00-04:00"` | Вікно backup (UTC) |
| `preferred_maintenance_window` | `string` | `"Mon:04:00-Mon:05:00"` | Вікно обслуговування (UTC) |
| `auto_minor_version_upgrade` | `bool` | `true` | Автооновлення мінорних версій |
| `apply_immediately` | `bool` | `false` | Негайне застосування змін |

### Шифрування та захист

| Змінна | Тип | За замовч. | Опис |
|---|---|---|---|
| `storage_encrypted` | `bool` | `true` | Шифрувати EBS/Aurora storage |
| `kms_key_id` | `string` | `null` | ARN KMS-ключа (null = aws/rds managed) |
| `deletion_protection` | `bool` | `true` | Захист від видалення |
| `skip_final_snapshot` | `bool` | `false` | Пропустити фінальний snapshot |
| `final_snapshot_identifier_prefix` | `string` | `"final"` | Префікс для назви snapshot |

## Як змінити тип БД, engine або клас інстансу

### Зміна engine та версії

```hcl
# PostgreSQL 14
engine         = "postgres"
engine_version = "14.13"
# parameter_group_family автоматично стане "postgres14"

# MySQL 8.0
engine         = "mysql"
engine_version = "8.0.40"
# parameter_group_family автоматично стане "mysql8.0"
```

> ⚠️ Зміна `engine` на існуючому ресурсі призводить до **recreate**. Плануйте наперед.

### Зміна класу інстансу

```hcl
instance_class = "db.r6g.2xlarge"
```

Для RDS — зміна відбувається під час maintenance window (або негайно якщо `apply_immediately = true`).
Для Aurora — кожен instance оновлюється по черзі без downtime.

### Перемикання між RDS та Aurora

```hcl
# Було: use_aurora = false
# Стало: use_aurora = true → Terraform знищить RDS і створить Aurora Cluster
use_aurora = true
engine     = "aurora-postgresql"  # engine також потрібно змінити!
```

> ⚠️ Міграція між RDS та Aurora потребує відновлення з snapshot або реплікації даних.
> Рекомендований шлях: зробити snapshot RDS → відновити в Aurora → переключити endpoint.

### Масштабування Aurora

```hcl
replica_count = 3  # 1 writer + 2 readers
```

### Multi-AZ для RDS

```hcl
multi_az = true  # автоматичний failover на standby в іншій AZ
```

## Безпека паролів

Не зберігайте пароль у коді. Передавайте через змінну середовища:

```bash
export TF_VAR_db_master_password="$(aws secretsmanager get-secret-value \
  --secret-id my-app/db/password --query SecretString --output text | jq -r .password)"
terraform apply
```

Або через `aws_secretsmanager_secret_version` безпосередньо в Terraform:

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "my-app/db/password"
}

module "rds" {
  master_password = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)["password"]
}
```
