terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "cs312" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "cs312-vpc"
  }
}

resource "aws_subnet" "cs312_public" {
  vpc_id                  = aws_vpc.cs312.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cs312-public-subnet"
  }
}

resource "aws_internet_gateway" "cs312_igw" {
  vpc_id = aws_vpc.cs312.id

  tags = {
    Name = "cs312-igw"
  }
}

resource "aws_route_table" "cs312_public_rt" {
  vpc_id = aws_vpc.cs312.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cs312_igw.id
  }

  tags = {
    Name = "cs312-public-rt"
  }
}

resource "aws_route_table_association" "cs312_public_rta" {
  subnet_id      = aws_subnet.cs312_public.id
  route_table_id = aws_route_table.cs312_public_rt.id
}

# Security Group for the control node: SSH access from your laptop
resource "aws_security_group" "control" {
  name        = "cs312-tf-control-sg"
  description = "Control node: SSH only"
  vpc_id      = aws_vpc.cs312.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cs312-tf-control-sg"
  }
}

# Security Group for the managed node: SSH from control node only, HTTP from anywhere
resource "aws_security_group" "managed" {
  name        = "cs312-tf-managed-sg"
  description = "Managed node: SSH from control node, HTTP from anywhere"
  vpc_id      = aws_vpc.cs312.id

  ingress {
    description     = "SSH from control node"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.control.id]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cs312-tf-managed-sg"
  }
}

# Control node: you SSH into this instance from your laptop
resource "aws_instance" "control" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.control.id]
  iam_instance_profile   = "LabInstanceProfile"
  subnet_id = aws_subnet.cs312_public.id

  tags = {
    Name = "cs312-tf-control"
  }
}

# Managed node: the server that will run the application
resource "aws_instance" "managed" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.managed.id]
  iam_instance_profile   = "LabInstanceProfile"
  subnet_id = aws_subnet.cs312_public.id

  tags = {
    Name = "cs312-tf-managed"
  }
}

# ECR repository for the CI/CD pipeline in Lab 6
resource "aws_ecr_repository" "wordpress" {
  name                 = "cs312-wordpress-lab"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}
