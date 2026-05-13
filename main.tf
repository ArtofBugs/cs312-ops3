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
# FIXME: This fails without credentials; I am already using LabInstanceProfile to create the instance, so is it still ok for credentials to exist on my local machine as an admin?

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
