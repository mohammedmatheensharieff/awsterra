terraform {
  backend "s3" {
    bucket         = "aws-terra-state-backend"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
  }
}
