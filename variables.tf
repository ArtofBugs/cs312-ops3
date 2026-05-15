variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 26.04 in us-east-1)"
  type        = string
  default     = "ami-091138d0f0d41ff90"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "Name of the SSH key pair (must already exist in AWS)"
  type        = string
  default = "cs312-key"
}

variable "ssh_key_path" {
  description = "Path to the SSH private key"
  type        = string
  default = "~/Downloads/cs312-key.pem"
}

variable "ecr_url" {
  description = "URL of the ECR repository containing container images"
  type = string
  default = ""
}

variable "s3_bucket" {
  description = "Name of S3 bucket containing world backups"
  type = string
  default = ""
}

variable "image_tag" {
  description = "Tag of the container image to pull from ECR"
  type = string
  default = "v1.0.0"
}

variable "repo_name" {
  description = "Repository to pull from in ECR"
  type = string
  default = "ops3-minecraft"
}
