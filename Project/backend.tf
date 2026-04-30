terraform {
  backend "s3" {
    bucket       = "goit-koblents-terraform-state-bucket"
    key          = "project/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
