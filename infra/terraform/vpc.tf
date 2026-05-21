# VPC, subnets, IGW, NAT gateways, and all route tables
# Follows the arch diagram: public, private, and firewall subnets across 2 AZs

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.project_name}-vpc" }
}

# Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# Public subnets (ALB + NAT gateways live here)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-${count.index == 0 ? "a" : "b"}" }
}

# Private subnets (ECS tasks + RDS)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "${var.project_name}-private-${count.index == 0 ? "a" : "b"}" }
}

# Elastic IP for NAT gateway (single NAT — cost-optimized)
resource "aws_eip" "nat" {
  count  = 1
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

# Single NAT gateway in public subnet A (cost-optimized; sacrifices AZ redundancy on egress)
resource "aws_nat_gateway" "nat" {
  count         = 1
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags       = { Name = "${var.project_name}-nat" }
  depends_on = [aws_internet_gateway.igw]
}

# --- Route tables ---

# Public subnet route tables — direct route to IGW
resource "aws_route_table" "public" {
  count  = 2
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-public-rt-${count.index == 0 ? "a" : "b"}" }
}

resource "aws_route" "public_to_igw" {
  count                  = 2
  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

# Private subnet route tables — outbound goes through NAT
resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-private-rt-${count.index == 0 ? "a" : "b"}" }
}

resource "aws_route" "private_to_nat" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
