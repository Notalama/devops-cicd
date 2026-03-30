terraform {
  backend "s3" {
    bucket         = "goit-koblents-terraform-state-bucket" # Ваше ім'я бакета
    key            = "lesson-5/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
