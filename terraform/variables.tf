variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3a.xlarge"
}

variable "ami_id" {
  description = "AMI ID"
  type        = string
  default     = "ami-065778886ef8ec7c8"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 25
}

variable "volume_type" {
  description = "Volume type"
  type        = string
  default     = "gp3"
}

variable "preserve_root_volume_on_termination" {
  description = "Keep the root EBS volume when the instance is terminated"
  type        = bool
  default     = true
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = "network-automation-key"
}

variable "instance_state" {
  description = "Instance state (running or stopped)"
  type        = string
  default     = "running"
}

variable "instance_name" {
  description = "Instance name"
  type        = string
  default     = "network-instance"
}

variable "instance_purchase_type" {
  description = "Instance purchase type: 'spot' for cost optimization or 'on-demand' for stability"
  type        = string
  default     = "spot"
  validation {
    condition     = contains(["spot", "on-demand"], var.instance_purchase_type)
    error_message = "Must be 'spot' or 'on-demand'."
  }
}

variable "availability_zone" {
  description = "Availability zone to pin instances to (leave empty to let AWS choose)"
  type        = string
  default     = "us-west-2a"
}

variable "spot_max_price" {
  description = "Maximum price for spot instances (leave empty for on-demand price). Typical t3a.xlarge in us-west-2: ~0.25"
  type        = string
  default     = "0.25"
}

variable "wait_for_fulfillment" {
  description = "Wait for spot request to be fulfilled"
  type        = bool
  default     = true
}

variable "interruption_behavior" {
  description = "Spot instance interruption behavior: 'stop' preserves EBS volume (for long-running workloads like OpenClaw), 'terminate' cleans up"
  type        = string
  default     = "stop"
  validation {
    condition     = contains(["terminate", "stop", "hibernate"], var.interruption_behavior)
    error_message = "Must be terminate, stop, or hibernate."
  }
}
