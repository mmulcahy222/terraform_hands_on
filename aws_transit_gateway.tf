# VPCS

resource "aws_vpc" "vpc_1" {
  cidr_block = "10.1.0.0/16"
  tags = {
    name = "VPC 1"
  }
}

resource "aws_vpc" "vpc_2" {
  cidr_block = "10.2.0.0/16"
  tags = {
    name = "VPC 2"
  }
}

# SUBNETS

resource "aws_subnet" "subnet_1" {
  cidr_block = "10.1.0.0/24"
  vpc_id     = aws_vpc.vpc_1.id
}

resource "aws_subnet" "subnet_2" {
  cidr_block = "10.2.0.0/24"
  vpc_id     = aws_vpc.vpc_2.id
}

# INTERNET GATEWAYS
#
# You must have an internet gateway inside of a VPC if you want to SSH into it's instance. Also make sure a network security group is in both the subnet & instance in AWS.
#
resource "aws_internet_gateway" "igw_1" {
  vpc_id = aws_vpc.vpc_1.id
}

resource "aws_internet_gateway" "igw_2" {
  vpc_id = aws_vpc.vpc_2.id
}

# ROUTE TABLES
#
# Appears that a Route Table in AWS goes into a VPC. Inside of it, it can be sent to certain subnets
# in it's VPC via the aws route_table_association resource
#


resource "aws_route_table" "route_table_1" {
  vpc_id = aws_vpc.vpc_1.id
  tags = {
    name = "route_table_1"
  }
}

resource "aws_route" "route_to_igw_1" {
  route_table_id         = aws_route_table.route_table_1.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_1.id
}

resource "aws_route" "route_to_tgw_in_vpc_1" {
  route_table_id         = aws_route_table.route_table_1.id
  destination_cidr_block = "10.0.0.0/8"
  gateway_id             = aws_ec2_transit_gateway.tgw_mark.id
  depends_on             = [aws_ec2_transit_gateway.tgw_mark]
}


resource "aws_route_table_association" "subnet_association_1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.route_table_1.id
}

resource "aws_route_table" "route_table_2" {
  vpc_id = aws_vpc.vpc_2.id
  tags = {
    name = "route_table_2"
  }
}

resource "aws_route" "route_to_igw_2" {
  route_table_id         = aws_route_table.route_table_2.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_2.id
}

resource "aws_route" "route_to_tgw_in_vpc_2" {
  route_table_id         = aws_route_table.route_table_2.id
  destination_cidr_block = "10.0.0.0/8"
  gateway_id             = aws_ec2_transit_gateway.tgw_mark.id
  depends_on             = [aws_ec2_transit_gateway.tgw_mark]
}

resource "aws_route_table_association" "subnet_association_2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.route_table_2.id
}








# NETWORK SECURITY GROUPS
# 
# in AWS, a security group is connected to the VPC
# 
# Define the first security group for VPC 1
resource "aws_security_group" "allow_ssh_group_vpc_1" {
  name        = "allow_ssh_group_vpc_1"
  description = "Allow SSH Group VPC 1"
  vpc_id      = aws_vpc.vpc_1.id

  # Define ingress rules directly within the security group
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define the second security group for VPC 2
resource "aws_security_group" "allow_ssh_group_vpc_2" {
  name        = "allow_ssh_group_vpc_2"
  description = "Allow SSH Group VPC 2"
  vpc_id      = aws_vpc.vpc_2.id

  # Define ingress rules directly within the security group
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#########################
# 
#    EC2 VIRTUAL MACHINES
#
#########################
#
# 
# ssh -i key_pair_2023.pem ec2-user@ec2-34-236-144-211.compute-1.amazonaws.com
#
# 1) Make sure there's internet gateway
# 2) Make sure there's security groups in VPC & EC2
# 3) Make sure there's a default route to the internet gateway
#
#
resource "aws_instance" "ec2_vpc_1_subnet_1" {
  ami                         = "ami-051f7e7f6c2f40dc1"
  subnet_id                   = aws_subnet.subnet_1.id
  instance_type               = "t2.micro"
  key_name                    = "key_pair_2023" # Replace with the name of your key pair in AWS
  vpc_security_group_ids      = [aws_security_group.allow_ssh_group_vpc_1.id]
  associate_public_ip_address = true
}
resource "aws_instance" "ec2_vpc_2_subnet_2" {
  ami                         = "ami-051f7e7f6c2f40dc1"
  subnet_id                   = aws_subnet.subnet_2.id
  instance_type               = "t2.micro"
  key_name                    = "key_pair_2023" # Replace with the name of your key pair in AWS
  vpc_security_group_ids      = [aws_security_group.allow_ssh_group_vpc_2.id]
  associate_public_ip_address = true
}
output "instance_public_ip" {
  value = aws_instance.ec2_vpc_1_subnet_1.public_ip
}

output "instance_public_dns" {
  value = aws_instance.ec2_vpc_1_subnet_1.public_dns
}







#
# TRANSIT GATEWAY
#
#
#
resource "aws_ec2_transit_gateway" "tgw_mark" {
  description = "Mark's Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  amazon_side_asn = 64512
  tags = {
    name = "tgw_mark"
  }
}

#
# TRANSIT GATEWAY ATTACHMENTS
#
# Attachments to other VPCs
#
#
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_1_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw_mark.id
  vpc_id             = aws_vpc.vpc_1.id
  subnet_ids         = [aws_subnet.subnet_1.id]
  tags = {
    name = "vpc_1_attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_2_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw_mark.id
  vpc_id             = aws_vpc.vpc_2.id
  subnet_ids         = [aws_subnet.subnet_2.id]
  tags = {
    name = "vpc_2_attachment"
  }
}

