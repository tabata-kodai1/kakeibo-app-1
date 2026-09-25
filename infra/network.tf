# ネットワーク。EC2 はパブリックサブネット、RDS はプライベートサブネットに置く。
# NAT Gateway は置かない。課金が大きく、プライベートサブネットから外に出る通信が不要なため。

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # RDS のサブネットグループは 2 つ以上の AZ を要求する。
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "kakeibo-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "kakeibo-igw" }
}

# EC2 用。1 つで足りる。
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = true

  tags = { Name = "kakeibo-public" }
}

# RDS 用。サブネットグループの要件で 2 AZ に 1 つずつ。
resource "aws_subnet" "private" {
  count = length(local.azs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = local.azs[count.index]

  tags = { Name = "kakeibo-private-${local.azs[count.index]}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "kakeibo-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# プライベートサブネットは VPC 内のローカル経路のみ（インターネットへの経路を持たない）。

# EC2 用。接続元は allowed_cidr のみ（N-08）。
# 画面（S3）には効かないため、S3 側はバケットポリシーで同じ IP に絞る（#3）。
resource "aws_security_group" "ec2" {
  name        = "kakeibo-ec2"
  description = "Rails API (EC2). Allow only from allowed_cidr"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "kakeibo-ec2" }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_api" {
  security_group_id = aws_security_group.ec2.id
  description       = "Rails API"
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 3000
  to_port           = 3000
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "SSH (deploy.sh)"
  cidr_ipv4         = var.allowed_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# Docker イメージの取得や OS 更新のため、外向きは全て許可する。
resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# RDS 用。EC2 の SG からの MySQL 接続のみ許可する（N-10）。CIDR は指定しない。
resource "aws_security_group" "rds" {
  name        = "kakeibo-rds"
  description = "RDS MySQL. Allow only from the EC2 security group"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "kakeibo-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  description                  = "MySQL from EC2"
  referenced_security_group_id = aws_security_group.ec2.id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
}
