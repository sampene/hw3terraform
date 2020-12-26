terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

resource "aws_instance" "example" {
  ami           = "ami-830c94e3"
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.asg_ec2_example]
  
  tags = {
  Name = "terraform-aws-ec2"
}

user_data = <<-EOF
              #!/bin/bash
              mkdir ${var.http_api_stage_name}
              echo "Hello World!" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

}

resource "aws_security_group" "asg_ec2_example" {
    name = "asg_ec2_example"
    
    ingress {
    from_port = var.server_port
    to_port = var.server_port
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
}
}

resource "aws_db_instance" "example-app" {
  allocated_storage = 10
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "7.2"
  identifier = "database"
  instance_class = "db.t2.micro"
  name = "app_db"
  username = "root"
  password = "password"
  skip_final_snapshot = true
}


resource "aws_apigatewayv2_vpc_link" "example-app" {
  name = "http-api-vpc-link"

  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids = data.aws_subnet_ids.default.ids
}

resource "aws_apigatewayv2_api" "app" {
  name = "http-api"

  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "app" {
  api_id = aws_apigatewayv2_api.app.id

  integration_type = "HTTP_PROXY"
  connection_id = aws_apigatewayv2_vpc_link.app.id
  connection_type = "VPC_LINK"
  integration_method = "GET"
  integration_uri = aws_lb_listener.app.arn
}

resource "aws_apigatewayv2_route" "app" {
  api_id = aws_apigatewayv2_api.app.id

  route_key = "$default"
  target = "integrations/${aws_apigatewayv2_integration.app.id}"
}

resource "aws_apigatewayv2_stage" "app" {
  api_id = aws_apigatewayv2_api.app.id

  name = "app"

  auto_deploy = true
}

variable "server_port" {
description = "HTTP requests port"
type = number
default = 8080
}

