resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
    tags = {
    ENV = terraform.workspace
  }
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "il-central-1a"
  map_public_ip_on_launch = "true"

  tags = {
    name = "public_subnet_a"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/demo-eks" = "owned"

  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "il-central-1b"
  map_public_ip_on_launch = "true"
  tags = {
    name = "public_subnet_b"
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/demo-eks" = "owned"
  }
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "il-central-1a"
  tags = {
    name = "private_subnet_a"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo-eks" = "owned"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "il-central-1b"
  tags = {
    "name" = "private_subnet_b"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/demo-eks" = "owned"
  }

}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    ENV = terraform.workspace
  }

}
resource "aws_eip" "nat_ip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ng" {
  allocation_id = aws_eip.nat_ip.id
  subnet_id     = aws_subnet.public_subnet_a.id

  tags = {
    Name = "gw NAT"
  }
}
resource "aws_route_table" "public_rt" {
  vpc_id     = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    ENV = terraform.workspace
  }
}
resource "aws_route_table" "private_rt" {
  vpc_id     = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ng.id
  }
  tags = {
    ENV = terraform.workspace
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
}
