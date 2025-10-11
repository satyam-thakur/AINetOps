### env_export
source .env

### aws cli to reboot instance
aws ec2 reboot-instances --instance-ids i-007a30f4aaa055f6d --region us-west-2

### terraform steps
terraform init
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve
terraform fmt
terraform validate
