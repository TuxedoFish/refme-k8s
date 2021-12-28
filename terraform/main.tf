# Defines the required provider "AWS"
provider "aws" {
  region = "eu-west-2"
}

# Defines a store of state for terraform in S3
terraform {
  backend "s3" {
    bucket     = "k8s-services-terraform-state"
    key        = "default.tfstate"
    region     = "eu-west-2"
  }
}

# Refers to a module within the kubernetes subfolder
module "kubernetes" {
  source         = "./kubernetes"
  vpc_cidr_block = "10.240.0.0/16"
  private_subnet01_netnum = "1"
  public_subnet01_netnum = "2"
  master_instance_type = "t3a.nano"
  worker_instance_type = "t3a.nano"
  vpc_name       = "k8s-cluster-vpc"
  region         = "eu-west-2"
}
