provider "aws" {
  region = "us-east-1"
}

locals {
  vpc_cidr_block = "10.0.0.0/16"
  newbits        = 4
}