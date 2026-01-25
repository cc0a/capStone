locals {
  azs = ["us-east-1a", "us-east-1b"]
}

# PUBLIC SUBNETS
resource "aws_subnet" "public" {
  for_each = toset(local.azs)

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(local.vpc_cidr_block, 8, index(local.azs, each.value))
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${each.value}"
    Tier = "public"
  }
}

# PRIVATE APP SUBNETS
resource "aws_subnet" "private_app" {
  for_each = toset(local.azs)

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(local.vpc_cidr_block, 8, index(local.azs, each.value) + 10)

  tags = {
    Name = "private-app-${each.value}"
    Tier = "private"
  }
}

# PRIVATE RDS SUBNETS
resource "aws_subnet" "private_rds" {
  for_each = toset(local.azs)

  vpc_id            = aws_vpc.main.id
  availability_zone = each.value
  cidr_block        = cidrsubnet(local.vpc_cidr_block, 8, index(local.azs, each.value) + 20)

  tags = {
    Name = "private-rds-${each.value}"
    Tier = "private"
  }
}

# PUBLIC ROUTE TABLE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT GATEWAYS (ONE PER PUBLIC SUBNET)
resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"
}

resource "aws_nat_gateway" "nat" {
  for_each     = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = { Name = "nat-${each.key}" }
}

# PRIVATE ROUTE TABLES (ONE PER AZ)
resource "aws_route_table" "private" {
  for_each = aws_nat_gateway.nat

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = each.value.id
  }

  tags = { Name = "private-rt-${each.key}" }
}

resource "aws_route_table_association" "private_app" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "private_rds" {
  for_each       = aws_subnet.private_rds
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}