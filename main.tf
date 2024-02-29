
# VPC
resource "aws_vpc" "zoeencloud" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "zoeencloud-vpc"
  }
}

# Public Subnet with Internet Gateway
resource "aws_subnet" "zoeencloud-public" {
  vpc_id            = aws_vpc.zoeencloud.id
  cidr_block        = var.subnet_cidr_block_public_1
  availability_zone = "ap-south-1a"

  tags = {
    Name = "zoeencloud-public-subnet"
  }
}

resource "aws_internet_gateway" "zoeencloud_igw" {
  vpc_id = aws_vpc.zoeencloud.id

  tags = {
    Name = "zoeencloud-igw"
  }
}

resource "aws_route_table" "zoeencloud_public_route_table" {
  vpc_id = aws_vpc.zoeencloud.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.zoeencloud_igw.id
  }
}

resource "aws_route_table_association" "zoeencloud_public_subnet_association" {
  subnet_id      = aws_subnet.zoeencloud-public.id
  route_table_id = aws_route_table.zoeencloud_public_route_table.id
}

# Private Subnets
resource "aws_subnet" "zoeencloud-private-1" {
  vpc_id            = aws_vpc.zoeencloud.id
  cidr_block        = var.subnet_cidr_block_1
  availability_zone = "ap-south-1b"

  tags = {
    Name = "zoeencloud-private-subnet-1"
  }
}

resource "aws_subnet" "zoeencloud-private-2" {
  vpc_id            = aws_vpc.zoeencloud.id
  cidr_block        = var.subnet_cidr_block_2
  availability_zone = "ap-south-1c"

  tags = {
    Name = "zoeencloud-private-subnet-2"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "zoeencloud_nat_gateway" {
  allocation_id = aws_eip.zoeencloud_eip.id
  subnet_id     = aws_subnet.zoeencloud-public.id

  depends_on = [
    aws_internet_gateway.zoeencloud_igw,
  ]
}

resource "aws_eip" "zoeencloud_eip" {  
}

resource "aws_route_table" "zoeencloud_private_route_table" {
  vpc_id = aws_vpc.zoeencloud.id

  depends_on = [
    aws_nat_gateway.zoeencloud_nat_gateway,
  ]
}

resource "aws_route_table_association" "zoeencloud_private_subnet_association_1" {
  subnet_id      = aws_subnet.zoeencloud-private-1.id
  route_table_id = aws_route_table.zoeencloud_private_route_table.id
}

resource "aws_route" "zoeencloud_private_route_to_nat_gateway" {
  route_table_id         = aws_route_table.zoeencloud_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.zoeencloud_nat_gateway.id
}

resource "aws_db_subnet_group" "zoeencloud-subnet-group" {
  name       = "zoeencloud-subnet-group"
  subnet_ids = [aws_subnet.zoeencloud-private-1.id, aws_subnet.zoeencloud-private-2.id]
}

resource "aws_security_group" "ec2_sg" {
  name        = "EC2_SG"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.zoeencloud.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.zoeencloud.cidr_block]  # Allow SSH from within VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "RDS_SG"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.zoeencloud.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.zoeencloud.cidr_block]  # Allow MySQL traffic from within VPC
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.zoeencloud.cidr_block]  # Allow SSH from within VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }
}

resource "aws_instance" "zoeencloudEC2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.zoeencloud-private-1.id
  security_groups = [aws_security_group.ec2_sg.id]  # Attach EC2 security group
}

resource "aws_db_instance" "zoeencloudRDS" {
  allocated_storage      = 20
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  identifier             = "zoeencloud-rds"
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = true
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.zoeencloud-subnet-group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]  # Attach RDS security group
}
