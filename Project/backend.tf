terraform {
  backend "s3" {
    bucket       = "goit-koblents-terraform-state-bucket"
    key          = "project/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
    encrypt      = true
  }
}
