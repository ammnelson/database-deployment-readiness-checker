terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket         = "ddrc-terraform-state-448962739436"
    key            = "ddrc/module5.tfstate"
    region         = "us-west-2"
    dynamodb_table = "ddrc-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
