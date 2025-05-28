# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"  # Change this to your preferred region
}

# Create VPC
resource "aws_vpc" "task_manager_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Task Manager VPC"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "task_manager_igw" {
  vpc_id = aws_vpc.task_manager_vpc.id

  tags = {
    Name = "Task Manager IGW"
  }
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.task_manager_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"  # Change this to match your region

  tags = {
    Name = "Task Manager Public Subnet"
  }
}

# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.task_manager_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"  # Change this to match your region

  tags = {
    Name = "Task Manager Private Subnet"
  }
}

# Create NAT Gateway
resource "aws_nat_gateway" "task_manager_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "Task Manager NAT Gateway"
  }
}

# Create Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  vpc   = true
  count = 1

  tags = {
    Name = "Task Manager NAT Gateway EIP"
  }
}

# Create route tables and associations
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.task_manager_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task_manager_igw.id
  }

  tags = {
    Name = "Task Manager Public Route Table"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.task_manager_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.task_manager_nat.id
  }

  tags = {
    Name = "Task Manager Private Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# Create API Gateway
resource "aws_api_gateway_rest_api" "task_manager_api" {
  name        = "Task Manager API"
  description = "API Gateway for Task Manager Service"
}

# Create Lambda function for Task Manager Service
resource "aws_lambda_function" "task_manager_service" {
  filename      = "task_manager_service.zip"  # You need to create this ZIP file with your Lambda code
  function_name = "task_manager_service"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"  # Change this to match your Lambda function's runtime

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Create IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "task_manager_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Create security group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "task_manager_lambda_sg"
  description = "Security group for Task Manager Lambda function"
  vpc_id      = aws_vpc.task_manager_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create MongoDB instance (EC2 for simplicity, consider using DocumentDB for production)
resource "aws_instance" "mongodb" {
  ami           = "ami-0c55b159cbfafe1f0"  # Change this to an appropriate MongoDB AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id

  tags = {
    Name = "Task Manager MongoDB"
  }
}

# Create Socket.IO Server (EC2 instance)
resource "aws_instance" "socketio_server" {
  ami           = "ami-0c55b159cbfafe1f0"  # Change this to an appropriate AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private_subnet.id

  tags = {
    Name = "Task Manager Socket.IO Server"
  }
}

# Create Email Service (Lambda function)
resource "aws_lambda_function" "email_service" {
  filename      = "email_service.zip"  # You need to create this ZIP file with your Lambda code
  function_name = "email_service"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"  # Change this to match your Lambda function's runtime

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Create Authentication Service (Lambda function)
resource "aws_lambda_function" "authentication_service" {
  filename      = "authentication_service.zip"  # You need to create this ZIP file with your Lambda code
  function_name = "authentication_service"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"  # Change this to match your Lambda function's runtime

  vpc_config {
    subnet_ids         = [aws_subnet.private_subnet.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

# Output the API Gateway URL
output "api_gateway_url" {
  value = aws_api_gateway_rest_api.task_manager_api.execution_arn
}