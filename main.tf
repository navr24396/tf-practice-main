terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    bucket = "porapuka"
    key = "terraform-state-file/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "porapuka"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# variables
variable "cidr_block" {}
variable "env_prefix" {}
variable "subnet_cidr_block" {}
variable "az" {}
variable "my-ip" {}
variable "instance_type" {}


# creating vpc
resource "aws_vpc" "myapp-vp" {
  cidr_block = var.cidr_block
  tags = {
    "Name" = "${var.env_prefix}-vpc"
  }
}

#creating subnets
resource "aws_subnet" "myapp-subnet-1" {
  vpc_id            = aws_vpc.myapp-vpc.id
  cidr_block        = var.subnet_cidr_block
  availability_zone = var.az
  tags = {
    "Name" = "${var.env_prefix}-subnet-1"
  }
}

#creating internet gateway

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    "Name" = "${var.env_prefix}-igw"
  }
}

# create route table

resource "aws_route_table" "myapp-rt" {
  vpc_id = aws_vpc.myapp-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-rt"
  }
}

# route_table_association
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-rt.id
}

#default route table (subnets assigned automatically)
resource "aws_default_route_table" "default-rt" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-default-rt"
  }
}

#security group
resource "aws_security_group" "myapp-sg" {
  name   = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id
  ingress {
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = local.tcp
    cidr_blocks = [var.my-ip]
  }
  ingress {
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp
    cidr_blocks = [local.anywhere]
  }
  ingress {
    from_port   = local.https_port
    to_port     = local.https_port
    protocol    = local.tcp
    cidr_blocks = [local.anywhere]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "${var.env_prefix}-myapp-sg"
  }
}

# fetching ami id
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#creating instance
resource "aws_instance" "myapp-server" {
  ami                         = data.aws_ami.latest-amazon-linux-image.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.myapp-subnet-1.id
  availability_zone           = var.az
  key_name                    = "nv"
  vpc_security_group_ids      = [aws_security_group.myapp-sg.id]
  associate_public_ip_address = true
  tags = {
    "Name" = "${var.env_prefix}-myapp-server"
  }
}

