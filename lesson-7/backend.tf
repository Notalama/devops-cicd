terraform {
  backend "s3" {
    bucket       = "goit-koblents-terraform-state-bucket" # Ваше ім'я бакета
    key          = "lesson-7/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
    encrypt      = true
  }
}
