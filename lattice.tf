#######################
# 
#       LAMBDA
#
#######################

# Create an IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name               = "lambda_role"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}

# Create a data source for the IAM policy document for Lambda
data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "archive_file" "lambda_hello_world_file" {
  type        = "zip"
  output_path = "/tmp/lambda_hello_world.zip"
  source {
    content  = <<EOF
def lambda_handler(event, context):
    return {
        'statusCode': 200,
        'body': 'Hello, I\'m Lambda!!!'
    }
    EOF
    filename = "main.py"
  }
}

resource "aws_lambda_function" "lambda_hello_world_function" {
  function_name    = "lambda_hello_world_function"
  handler          = "main.lambda_handler"
  runtime          = "python3.8"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_hello_world_file.output_path
  source_code_hash = data.archive_file.lambda_hello_world_file.output_base64sha256
}


#######################
# 
#       EC2
#
#######################


# Create an EC2 instance with a user script that returns HTML using Alpine
resource "aws_instance" "ec2_hello_world" {
  ami                         = "ami-051f7e7f6c2f40dc1"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet_ec2.id
  associate_public_ip_address = true
  # Specify the user script in heredoc format
  user_data = <<EOF
#!/bin/bash
sudo dnf update -y
sudo dnf list | grep httpd
sudo dnf install -y httpd.x86_64
sudo systemctl start httpd.service
sudo systemctl status httpd.service
sudo systemctl enable httpd.service
echo “Hello World from $(hostname -f)” > /var/www/html/index.html
EOF
  # Associate the security group with the instance
  vpc_security_group_ids = [aws_security_group.security_group_ec2_lambda.id]
  tags = {
    name = "ec2_hello_world"
  }
}

######################
#
#  VPCs
#
#  
#   Default VPC in AWS is the client VPC that will be associated with the service network, via vpc_lattice_service_vpc_association_ec2 resource. 
#   Two services of Lambda & EC2 will be associated with the service network.
#   The service network is not a VPC itself!

#
#

resource "aws_default_vpc" "default_vpc" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_vpc" "vpc_ec2" {
  cidr_block = "10.2.0.0/16"
  tags = {
    name = "VPC EC2"
  }
}

######################
#
#  SUBNETS
#
#
#   The Lambda Service does not require it's own subnet like EC2 and Load Balancers for the target gruops
#
#

resource "aws_subnet" "subnet_ec2" {
  cidr_block = "10.2.0.0/24"
  vpc_id     = aws_vpc.vpc_ec2.id
}
#########################
# 
#    SECURITY GROUPS
#
#########################


# Create a security group that allows HTTP and HTTPS traffic from anywhere
resource "aws_security_group" "security_group_ec2_lambda" {
  name = "security_group_ec2_lambda"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.vpc_ec2.id
}

resource "aws_security_group" "security_group_default_vpc" {
  name = "security_group_service_network"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_default_vpc.default_vpc.id
}




#########################
# 
#    VPC LATTICE
#
#    Service Network -> Service -> Listener -> Target Group
#
#    Target Group is a VPC with Containers, EC2, Kubernetes, Load Balancers
#    Target Group has no VPC with Lambda
#
#    A Key Purpose of AWS Lattice is to have a consistent DNS name for services of different computing styles
#    And to have control security & monitoring consistently
#    Listeners & Rules can have weighted bias among different rules & paths 
#
#    Problems I came across was Terraform not setting up the Lambda Function in the Lambda Target Group
#    and the initialization script in the USER DATA not working as expected, resulting in endless troubleshooting
#    with the Health Check in the EC2 Target Group, until I directly accessed the instance in the private subnet
#    with a temporary internet gateway/route table entry.
#
#    VPC Lattice adds in the route tables in a route table like 167.*.*.*
#
#########################

##### VPC SERVICE NETWORK ##### 
#
#
resource "aws_vpclattice_service_network" "vpc_lattice_service_network_mark" {
  name      = "vpc-lattice-service-network-mark"
  auth_type = "NONE"
}

##### VPC LATTICE SERVICES #####
#
# 
resource "aws_vpclattice_service" "vpc_lattice_service_lambda" {
  name      = "vpc-lattice-service-lambda"
  auth_type = "NONE"
}

resource "aws_vpclattice_service" "vpc_lattice_service_ec2" {
  name      = "vpc-lattice-service-ec2"
  auth_type = "NONE"
}

##### VPC LATTICE SERVICE TO SERVICE NETWORK ASSOCIATION #####
#
#   Back End
#
#   Connects services to service network
#
#
resource "aws_vpclattice_service_network_service_association" "vpc_lattice_service_network_association_lambda" {
  service_network_identifier = aws_vpclattice_service_network.vpc_lattice_service_network_mark.id
  service_identifier         = aws_vpclattice_service.vpc_lattice_service_lambda.id
}

resource "aws_vpclattice_service_network_service_association" "vpc_lattice_service_network_association_ec2" {
  service_network_identifier = aws_vpclattice_service_network.vpc_lattice_service_network_mark.id
  service_identifier         = aws_vpclattice_service.vpc_lattice_service_ec2.id
}


##### VPC LATTICE VPC TO SERVICE NETWORK ASSOCIATION (DEFAULT VPC) #####
#
#   Client Side
#
#   Default VPC was used for my simplicity & sanity
#
#   Connects Client VPC to Service Network
#   Service Network is not a VPC itself, it's an abstraction
#
resource "aws_vpclattice_service_network_vpc_association" "vpc_lattice_service_vpc_association_ec2" {
  vpc_identifier             = aws_default_vpc.default_vpc.id
  service_network_identifier = aws_vpclattice_service_network.vpc_lattice_service_network_mark.id
  security_group_ids         = [aws_default_vpc.default_vpc.default_security_group_id]
}


##### VPC LATTICE LISTENER ##### 
#
#   Attaches Listener To Service
#
#
resource "aws_vpclattice_listener" "vpc_lattice_listener_lambda" {
  name               = "vpc-lattice-listener-lambda"
  protocol           = "HTTP"
  service_identifier = aws_vpclattice_service.vpc_lattice_service_lambda.id
  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.vpc_lattice_target_group_lambda.id
        weight                  = 100
      }
    }
  }
}

resource "aws_vpclattice_listener" "vpc_lattice_listener_ec2" {
  name               = "vpc-lattice-listener-ec2"
  protocol           = "HTTP"
  service_identifier = aws_vpclattice_service.vpc_lattice_service_ec2.id
  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.vpc_lattice_target_group_ec2.id
        weight                  = 100
      }
    }
  }
}




##### VPC LATTICE TARGET GROUP & ATTACHMENT (LAMBDA) #####
#
#   The attachment links the Lambda/EC2/EKS to the target group
# 
resource "aws_vpclattice_target_group" "vpc_lattice_target_group_lambda" {
  name = "vpc-lattice-target-group-lambda"
  type = "LAMBDA"
}

resource "aws_vpclattice_target_group" "vpc_lattice_target_group_ec2" {
  name = "vpc-lattice-target-group-ec2"
  type = "INSTANCE"
  config {
    port           = 80
    protocol       = "HTTP"
    vpc_identifier = aws_vpc.vpc_ec2.id
  }
}


##### VPC TARGET GROUPS
#
#     VPC LATTICE TARGET GROUP ATTACHMENT (Lambda) ##### 
#
#     The attachment links the Lambda/EC2/EKS to the target group  
#
resource "aws_vpclattice_target_group_attachment" "vpc_lattice_target_group_attachment_lambda" {
  target_group_identifier = aws_vpclattice_target_group.vpc_lattice_target_group_lambda.id
  target {
    id = aws_lambda_function.lambda_hello_world_function.arn
  }
}
##### VPC LATTICE TARGET GROUP ATTACHMENT (EC2) #####
#
#   The attachment links the Lambda/EC2/EKS to the target group  
# 
resource "aws_vpclattice_target_group_attachment" "vpc_lattice_target_group_attachment_ec2" {
  target_group_identifier = aws_vpclattice_target_group.vpc_lattice_target_group_ec2.id
  target {
    id   = aws_instance.ec2_hello_world.id
    port = 80
  }
}
