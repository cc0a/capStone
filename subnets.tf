# PUBLIC SUBNETS
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr_block, local.newbits, 0)
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(local.vpc_cidr_block, local.newbits, 1)
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = { Name = "public-b" }
}

# PRIVATE APP SUBNETS
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 2)
  availability_zone = "us-east-1a"
  tags = { Name = "private-app-a" }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 3)
  availability_zone = "us-east-1b"
  tags = { Name = "private-app-b" }
}

# PRIVATE RDS SUBNETS
resource "aws_subnet" "private_rds_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 4)
  availability_zone = "us-east-1c"
  tags = { Name = "private-rds-a" }
}

resource "aws_subnet" "private_rds_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr_block, local.newbits, 5)
  availability_zone = "us-east-1d"
  tags = { Name = "private-rds-b" }
}

# ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public_a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_a.id
}

resource "aws_route_table_association" "public_b" {
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public_b.id
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rds_a" {
  subnet_id      = aws_subnet.private_rds_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_rds_b" {
  subnet_id      = aws_subnet.private_rds_b.id
  route_table_id = aws_route_table.private.id
}
