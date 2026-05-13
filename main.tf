# Add AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Set region
provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "ops3" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "ops3-vpc"
  }
}

# Create subnet
resource "aws_subnet" "ops3_public" {
  vpc_id                  = aws_vpc.ops3.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "ops3-public-subnet"
  }
}

# Create IGW
resource "aws_internet_gateway" "ops3_igw" {
  vpc_id = aws_vpc.ops3.id

  tags = {
    Name = "ops3-igw"
  }
}

# Create route table
resource "aws_route_table" "ops3_public_rt" {
  vpc_id = aws_vpc.ops3.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ops3_igw.id
  }

  tags = {
    Name = "ops3-public-rt"
  }
}

# Create route table association
resource "aws_route_table_association" "ops3_public_rta" {
  subnet_id      = aws_subnet.ops3_public.id
  route_table_id = aws_route_table.ops3_public_rt.id
}

# Security Group rule: SSH for admin access and TCP 25565 for Minecraft clients
resource "aws_security_group" "ops3_minecraft_sg" {
  name        = "op3-minecraft-sg"
  description = "SSH for admin access and TCP 25565 for Minecraft clients"
  vpc_id      = aws_vpc.ops3.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Minecraft port"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ops3-minecraft-sg"
  }
}


# Create node
resource "aws_instance" "ops3_minecraft_node" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ops3_minecraft_sg.id]
  iam_instance_profile   = "LabInstanceProfile"
  subnet_id = aws_subnet.ops3_public.id

  tags = {
    Name = "ops3-minecraft-node"
  }
}

# ECR repository for the CI/CD pipeline
resource "aws_ecr_repository" "ops3_ecr" {
  name                 = "ops3-ecr"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

# https://stackoverflow.com/a/68398082
data "aws_caller_identity" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
}

resource "null_resource" "ansible_bridge" {
  # Ensure this only runs AFTER the instance is up
  depends_on = [aws_instance.ops3_minecraft_node]

  # This block waits until SSH is actually responding
  provisioner "remote-exec" {
    inline = ["echo 'SSH is up!'"]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_key_path)
      host        = aws_instance.ops3_minecraft_node.public_ip
    }
  }

  # Now that SSH is confirmed, run Ansible locally
provisioner "local-exec" {
    command = <<EOT
      ansible-playbook -i '${aws_instance.ops3_minecraft_node.public_ip},' \
      --private-key ${var.ssh_key_path} \
      --extra-vars "aws_account_id=${local.account_id} ecr_url=${aws_ecr_repository.ops3_ecr.repository_url} s3_bucket_name=${var.s3_bucket} ecr_image_tag=${var.image_tag}" \
      playbook.yml
    EOT
  }
}
