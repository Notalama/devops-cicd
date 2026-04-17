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
