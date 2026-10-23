variable "vpc_cidr" {
  type = string
}

locals {
  azs = ["us-west-2a", "us-west-2b"]
}

resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:Flow logs add S3/CloudWatch cost; single-host coursework VPC with locked-down SGs
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "ddrc-module5-vpc" }
}

# Strip every rule from the VPC's default SG so nothing can use it by accident
resource "aws_default_security_group" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "ddrc-module5-default-sg-locked" }
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130:Deliberately public subnets; the build host serves SSH/Jenkins to trusted IPs
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "ddrc-module5-public-${local.azs[count.index]}" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "ddrc-module5-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "ddrc-module5-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
