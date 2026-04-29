terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# Підключаємо модуль S3 та DynamoDB
module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "goit-koblents-terraform-state-bucket"
  table_name  = "terraform-locks"
}

# Підключаємо модуль VPC
module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "lesson-5-vpc"
}

# Підключаємо модуль EKS
module "eks" {
  source     = "./modules/eks"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids # Використовуємо приватні підмережі для безпеки
}

# Підключаємо модуль ECR
module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "lesson-5-ecr"
  scan_on_push = true
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# Jenkins встановлюємо Helm-ом у EKS
module "jenkins" {
  source = "./modules/jenkins"

  cluster_name               = module.eks.cluster_name
  kubernetes_host            = data.aws_eks_cluster.this.endpoint
  kubernetes_cluster_ca_cert = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  kubernetes_token           = data.aws_eks_cluster_auth.this.token

  ecr_repository_url = module.ecr.repository_url
  aws_region         = "us-west-2"
}

# ─── RDS Module ───────────────────────────────────────────────────────────────
# Приклад 1: Звичайна RDS PostgreSQL instance
module "rds_postgres" {
  source = "./modules/rds"

  identifier      = "lesson-7-postgres"
  use_aurora      = false
  engine          = "postgres"
  engine_version  = "15.8"
  instance_class  = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  multi_az              = false

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # allowed_security_group_ids = [<eks_node_sg_id>]  # передайте SG node-групи EKS
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  backup_retention_period = 7
  deletion_protection     = false  # true для production
  skip_final_snapshot     = true   # false для production

  tags = { Environment = "dev", Project = "lesson-7" }
}

# Приклад 2: Aurora PostgreSQL Cluster
module "rds_aurora" {
  source = "./modules/rds"

  identifier      = "lesson-7-aurora"
  use_aurora      = true
  engine          = "aurora-postgresql"
  engine_version  = "15.4"
  instance_class  = "db.t3.medium"
  replica_count   = 2

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  # allowed_security_group_ids = [<eks_node_sg_id>]  # передайте SG node-групи EKS
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  backup_retention_period = 7
  deletion_protection     = false  # true для production
  skip_final_snapshot     = true   # false для production

  tags = { Environment = "dev", Project = "lesson-7" }
}

# Argo CD + Application для GitOps синхронізації Helm chart
module "argo_cd" {
  source = "./modules/argo_cd"

  cluster_name               = module.eks.cluster_name
  kubernetes_host            = data.aws_eks_cluster.this.endpoint
  kubernetes_cluster_ca_cert = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  kubernetes_token           = data.aws_eks_cluster_auth.this.token

  gitops_repo_url   = "https://github.com/Notalama/devops-cicd.git"
  app_target_path   = "lesson-7/charts/django-app"
  app_target_branch = "main"
}