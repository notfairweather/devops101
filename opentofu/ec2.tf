
# Declare the EC2 instance
resource "aws_instance" "server" {
  ami           = var.ec2_ami

  # trying to save money with spot instance
  instance_type = "t4g.nano"
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = 0.0030
    }
  }

  key_name = aws_key_pair.server_key.key_name

  subnet_id               = aws_subnet.server_subnet.id
  vpc_security_group_ids  = [
    aws_security_group.main_private_secgrp.id
  ]

  associate_public_ip_address = true

  tags = {
    Name = "logeverything_server"
  }

  depends_on = [aws_internet_gateway.main_private_igw]
}

# Upload the SSH Public Key for acces
resource "aws_key_pair" "server_key" {
  key_name = "server-key"
  public_key = var.ec2_ssh_pubkey
}



# Provide networking via VPC and subnet
resource "aws_vpc" "main_private_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "logeverything_vpc"
  }
}

resource "aws_subnet" "server_subnet" {
  vpc_id     = aws_vpc.main_private_vpc.id
  cidr_block = "10.0.1.0/24"

  availability_zone = "us-east-1a" # t4g.nano only in certain AZ
  tags = {
    Name = "logeverything_subnet"
  }
}

# Add an internet gateway for internet access
resource "aws_internet_gateway" "main_private_igw" {
  vpc_id = aws_vpc.main_private_vpc.id

  tags = {
    Name = "logeverything_igw"
  }
}

# Add a route table to use the internet gateway
resource "aws_route_table" "logeverything_public_rt" {
  vpc_id = aws_vpc.main_private_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_private_igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.main_private_igw.id
  }

  tags = {
    Name = "logeverything_public_rt"
  }
}

resource "aws_route_table_association" "logeverything_server_public_access" {
  subnet_id      = aws_subnet.server_subnet.id
  route_table_id = aws_route_table.logeverything_public_rt.id
}


# Then add access control rules
resource "aws_network_acl" "main_private_vpc_acl" {
  vpc_id = aws_vpc.main_private_vpc.id

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    to_port    = 22
    from_port  = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    to_port    = 3456
    from_port  = 0
  }

  tags = {
    Name = "logeverything_server_acl"
  }
}

resource "aws_security_group" "main_private_secgrp" {
  name        = "logeverything_secgrp"
  description = "Security group for LogEverything VMs"
  vpc_id      = aws_vpc.main_private_vpc.id

  tags = {
    Name = "logeverything_secgrp"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_inbound" {
  security_group_id = aws_security_group.main_private_secgrp.id
  cidr_ipv4         = "${var.ec2_ssh_inbound_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_taskmanager_inbound" {
  security_group_id = aws_security_group.main_private_secgrp.id
  cidr_ipv4         = "${var.ec2_ssh_inbound_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 3456
  to_port           = 3456
}

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-connect-tutorial.html
resource "aws_vpc_security_group_ingress_rule" "allow_ec2connect_inbound" {
  security_group_id = aws_security_group.main_private_secgrp.id
  cidr_ipv4         = "18.206.107.24/29" # us-east-1 region ec2 connect IPs
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.main_private_secgrp.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}




# Ouput the IP address to connect to on SSH
output "ec2_public_ip" {
  value = aws_instance.server.public_ip
}
