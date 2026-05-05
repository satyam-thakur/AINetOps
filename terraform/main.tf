# Security Group - Allow SSH access
resource "aws_security_group" "network_sg" {
  name        = "network-instance-sg"
  description = "Allow SSH access"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Change to specific IP for better security
  }

  ingress {
    from_port   = 50080
    to_port     = 50080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Change to specific IP for better security, This is for test only.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "network-instance-sg"
  }
}

# EC2 Spot Instance (activated when instance_purchase_type = "spot")
resource "aws_spot_instance_request" "network_instance_spot" {
  count = var.instance_purchase_type == "spot" ? 1 : 0

  ami                            = var.ami_id
  instance_type                  = var.instance_type
  key_name                       = var.key_name
  availability_zone              = var.availability_zone
  vpc_security_group_ids         = [aws_security_group.network_sg.id]
  spot_price                     = var.spot_max_price
  wait_for_fulfillment           = var.wait_for_fulfillment
  instance_interruption_behavior = var.interruption_behavior

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = !var.preserve_root_volume_on_termination
  }

  tags = {
    Name = var.instance_name
  }
}

# EC2 On-Demand Instance (activated when instance_purchase_type = "on-demand")
resource "aws_instance" "network_instance_ondemand" {
  count = var.instance_purchase_type == "on-demand" ? 1 : 0

  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  availability_zone      = var.availability_zone
  vpc_security_group_ids = [aws_security_group.network_sg.id]

  root_block_device {
    volume_size           = var.volume_size
    volume_type           = var.volume_type
    delete_on_termination = !var.preserve_root_volume_on_termination
  }

  tags = {
    Name = var.instance_name
  }
}

# Local abstractions for resource-agnostic instance access
locals {
  instance_id                = var.instance_purchase_type == "spot" ? aws_spot_instance_request.network_instance_spot[0].spot_instance_id : aws_instance.network_instance_ondemand[0].id
  instance_public_ip         = var.instance_purchase_type == "spot" ? aws_spot_instance_request.network_instance_spot[0].public_ip : aws_instance.network_instance_ondemand[0].public_ip
  instance_private_ip        = var.instance_purchase_type == "spot" ? aws_spot_instance_request.network_instance_spot[0].private_ip : aws_instance.network_instance_ondemand[0].private_ip
  instance_public_dns        = var.instance_purchase_type == "spot" ? aws_spot_instance_request.network_instance_spot[0].public_dns : aws_instance.network_instance_ondemand[0].public_dns
  instance_availability_zone = var.instance_purchase_type == "spot" ? aws_spot_instance_request.network_instance_spot[0].availability_zone : aws_instance.network_instance_ondemand[0].availability_zone
}

# Control instance state (running/stopped)
resource "aws_ec2_instance_state" "instance_state" {
  instance_id = local.instance_id
  state       = var.instance_state
  depends_on = [
    aws_spot_instance_request.network_instance_spot,
    aws_instance.network_instance_ondemand
  ]
}
