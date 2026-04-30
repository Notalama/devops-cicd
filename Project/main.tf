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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# ─── S3 Backend ───────────────────────────────────────────────────────────────

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "goit-koblents-terraform-state-bucket"
  table_name  = "terraform-locks"
}

# ─── VPC ──────────────────────────────────────────────────────────────────────

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  vpc_name           = "project-vpc"
}

# ─── EKS ──────────────────────────────────────────────────────────────────────

module "eks" {
  source     = "./modules/eks"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
}

# ─── ECR ──────────────────────────────────────────────────────────────────────

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = "project-django-ecr"
  scan_on_push = true
}

# ─── EKS cluster data ─────────────────────────────────────────────────────────

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# ─── RDS PostgreSQL ───────────────────────────────────────────────────────────

module "rds_postgres" {
  source = "./modules/rds"

  identifier      = "project-postgres"
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

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = { Environment = "dev", Project = "project" }
}

# ─── Aurora PostgreSQL Cluster ────────────────────────────────────────────────

module "rds_aurora" {
  source = "./modules/rds"

  identifier      = "project-aurora"
  use_aurora      = true
  engine          = "aurora-postgresql"
  engine_version  = "15.4"
  instance_class  = "db.t3.medium"
  replica_count   = 2

  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_master_password

  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  allowed_cidr_blocks = [module.vpc.vpc_cidr_block]

  backup_retention_period = 7
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = { Environment = "dev", Project = "project" }
}

# ─── Jenkins ──────────────────────────────────────────────────────────────────

module "jenkins" {
  source = "./modules/jenkins"

  cluster_name               = module.eks.cluster_name
  kubernetes_host            = data.aws_eks_cluster.this.endpoint
  kubernetes_cluster_ca_cert = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  kubernetes_token           = data.aws_eks_cluster_auth.this.token

  ecr_repository_url = module.ecr.repository_url
  aws_region         = "us-west-2"
}

# ─── Argo CD ──────────────────────────────────────────────────────────────────

module "argo_cd" {
  source = "./modules/argo_cd"

  cluster_name               = module.eks.cluster_name
  kubernetes_host            = data.aws_eks_cluster.this.endpoint
  kubernetes_cluster_ca_cert = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  kubernetes_token           = data.aws_eks_cluster_auth.this.token

  gitops_repo_url   = "https://github.com/Notalama/devops-cicd.git"
  app_target_path   = "Project/charts/django-app"
  app_target_branch = "main"
}
