variable "ec2_ami" {
    type        = string
    description = "AMI for EC2"
}

variable "ec2_ssh_pubkey" {
    type        = string
    description = "SSH public key for access to EC2 instance"
}

variable "ec2_ssh_inbound_ip" {
    type        = string
    description = "IP address to allow SSH access from"
}

variable "s3_bucket_suffix" {
    type        = string
    description = "Suffix for bucket"
}
