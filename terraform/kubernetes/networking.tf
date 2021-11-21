# Data source for availability zones
data "aws_availability_zones" "available" {
    state = "available"
}

# Private subnet 
resource "aws_subnet" "private01" {
    vpc_id = aws_vpc.main.id
    map_public_ip_on_launch = false
    cidr_block = cidrsubnet(var.vpc_cidr_block, 8, var.private_subnet01_netnum) 
    availability_zone = element(data.aws_availability_zones.available_names, 0)
    tags = {
        Name = "private-subnet01-${var.cluster_name}"
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

# Public subnet
resource "aws_subnet" "public01" {
    vpc_id = aws_vpc.main.id
    map_public_ip_on_launch = true 
    cidr_block = cidrsubnet(var.vpc_cidr_block, 8, var.public_subnet01_netnum) 
    availability_zone = element(data.aws_availability_zones.available_names, 0)
    tags = {
        Name = "public-subnet01-${var.cluster_name}"
        "kubernetes.io/cluster/${var.cluster_name}" = "shared"
        "kubernetes.io/role/elb" = "1"
    }
}

resource "aws_subnet" "utility" {
    vpc_id = aws_vpc.main.id
    map_public_ip_on_launch = true 
    cidr_block = cidrsubnet(var.vpc_cidr_block, 8, 253) 
    availability_zone = element(data.aws_availability_zones.available_names, 1)
    tags = {
        Name = "utility"
    }
}

# Route tables for public & private subnets
resource "aws_route_table" "private_rt" {
    vpc_id = aws_vpc.main
}
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main
}

# Internet gateway for public internet access
resource "aws_route_table" "igw" {
    vpc_id = aws_vpc.main
}

# Elastic IP resource for bastion access
resource "aws_route_table" "eip" {
    vpc = true
}
resource "aws_nat_gateway" "natgw" {
    allocation_id = aws_eip.eip.id
    subnet_id = aws_subnet.utility.id
}

# Create route to internet gateway - route everything
resource "aws_route" "public01_igw" {
    route_table_id = aws_route_table.public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

# Create route to NAT gateway for private route table
resource "aws_route" "natgw" {
    route_table_id = aws_route_table.private_rt.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
    depends_on = [aws_nat_gateway.natgw]
}

# Create route table associations to internet gateway
resource "aws_route_table_association" "public_rta" {
    subnet_id = aws_subnet.public01.id
    route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "utility" {
    subnet_id = aws_subnet.utility.id
    route_table_id = aws_route_table.public_rt.id
}

# Create route table associations to NAT gateway 
resource "aws_route_table_association" "private_rta" {
    subnet_id = aws_subnet.private01.id
    route_table_id = aws_route_table.private_rt.id
}