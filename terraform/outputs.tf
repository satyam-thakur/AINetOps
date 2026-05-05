# Security Group
output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.network_sg.id
}

# Instance Configuration
output "instance_purchase_type" {
  description = "Instance purchase type (spot or on-demand)"
  value       = var.instance_purchase_type
}

output "spot_price" {
  description = "Configured spot bid price for the current instance; null for on-demand"
  value       = var.instance_purchase_type == "spot" ? aws_spot_instance_request.network_instance_spot[0].spot_price : null
}

# Instance Information
output "instance_id" {
  description = "EC2 instance ID"
  value       = local.instance_id
}

output "instance_public_ip" {
  description = "Public IP address"
  value       = local.instance_public_ip
}

output "instance_availability_zone" {
  description = "Availability zone where the instance is running"
  value       = local.instance_availability_zone
}

output "instance_private_ip" {
  description = "Private IP address"
  value       = local.instance_private_ip
}

output "instance_state" {
  description = "Instance state"
  value       = aws_ec2_instance_state.instance_state.state
}

output "public_dns" {
  description = "Public DNS name"
  value       = local.instance_public_dns
}

# SSH Connection String
output "ssh_command" {
  description = "SSH connection command"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${local.instance_public_ip}"
}
