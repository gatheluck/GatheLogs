terraform {
    required_version = ">= 1.1.3"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "3.71.0"
        }
    }

    backend "s3" {
        bucket = "gathelogs-terraform-backend"
        profile = "gatheluck-admin"
        region = "ap-northeast-1"
        key = "terraform-global.tfstate"
        encrypt = true
    }
}

provider "aws" {
    profile = "gatheluck-admin"
    region = "ap-northeast-1"
}

resource "aws_s3_bucket" "gathelogs-terraform-backend" {
    bucket = "gathelogs-terraform-backend"
    
    acl = "private"
    force_destroy = true
    
    lifecycle {
        prevent_destroy = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }

    versioning {
        enabled = true
    }
}

module "gathelogs" {
    source = "./gathelogs"
}