# Створення VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = var.vpc_name }
}

# Публічні підмережі
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.vpc_name}-public-${count.index + 1}" }
}

# Приватні підмережі
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = { Name = "${var.vpc_name}-private-${count.index + 1}" }
}

# Internet Gateway (для виходу в інтернет з публічних мереж)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.vpc_name}-igw" }
}

# Elastic IP для NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.vpc_name}-nat-eip" }
}

# NAT Gateway (щоб приватні підмережі мали доступ до інтернету)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Розміщуємо в першій публічній підмережі

  tags = { Name = "${var.vpc_name}-nat" }
}
