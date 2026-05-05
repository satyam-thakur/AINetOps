# AWS Region
aws_region = "us-west-2"

# Instance Purchase Type
# Toggle between "spot" (cost-optimized, up to 90% discount) and "on-demand" (always available)
# When spot instance is interrupted, it will STOP (preserving EBS data) rather than terminate
# Switch to "on-demand" if you need guaranteed availability for long-running OpenClaw workloads
instance_purchase_type = "spot"

# Pin instances to a specific availability zone. Set to "" to let AWS choose.
availability_zone = "us-west-2a"

# Spot Instance Configuration
# Set max price cap for budget control. Leave empty to use current spot price.
# Typical t3a.xlarge in us-west-2: ~$0.15-0.30 per hour
spot_max_price = "0.145"

# Instance Configuration
instance_type = "t3a.2xlarge"
ami_id        = "ami-065778886ef8ec7c8"
instance_name = "network-instance"

# Storage
volume_size = 120
volume_type = "gp3"

# Root EBS behavior
# Keep the volume if the instance is terminated; data survives stop/start as well
preserve_root_volume_on_termination = true

# Instance State (running or stopped)
instance_state = "running"
