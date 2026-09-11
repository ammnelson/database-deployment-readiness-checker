provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "ddrc-module5"
      ManagedBy = "terraform"
    }
  }
}
