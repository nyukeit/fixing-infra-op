terraform{
required_version = ">= 1.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "${var.region}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  token = "${var.aws_token}"
}

# Define Local Variables
locals {
  private_key_path = "${var.key_name}.pem"
}

resource "aws_vpc" "infra-op-vpc" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "Infra OP VPC"
  }
}

resource "aws_subnet" "infra-op-subnet" {
  vpc_id = aws_vpc.infra-op-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Infra OP Subnet"
  }
}

resource "aws_internet_gateway" "infra-op-igw" {
  vpc_id = aws_vpc.infra-op-vpc.id

  tags = {
    Name = "Infra OP IGW"
  }
}

resource "aws_route_table" "infra-op-rt" {
  vpc_id = aws_vpc.infra-op-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.infra-op-igw.id
  }

  tags = {
    Name = "Infra OP RT"
  }
}

resource "aws_route_table_association" "infra-op-rta" {
  subnet_id = aws_subnet.infra-op-subnet.id
  route_table_id = aws_route_table.infra-op-rt.id
}

resource "aws_security_group" "infra-op-sg" {
  name = "infra-op-sg"
  vpc_id = aws_vpc.infra-op-vpc.id
  
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Port for Kube API Server
  ingress {
    from_port = 6443
    to_port = 6443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port for Kubelet API
  ingress {
    from_port = 10250
    to_port = 10250
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port for Kube Controller Manager
  ingress {
    from_port = 10257
    to_port = 10257
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port for Kube Scheduler
  ingress {
    from_port = 10259
    to_port = 10259
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ports for NodePort Service
  ingress {
    from_port = 30000
    to_port = 32767
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ports for ETCD
  ingress {
    from_port = 2379
    to_port = 2380
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This will allow us to SSH into the instance for Ansible to do it's magic.
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "infra-op-ec2" {
  count = 3
  ami = "${var.ami_id}"
  instance_type = "t3.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.infra-op-sg.id]
  key_name = "${var.key_name}"
  subnet_id = aws_subnet.infra-op-subnet.id

  connection {
    type = "ssh"
    host = self.public_ip
    user = "${var.ssh_user}"
    private_key = file(local.private_key_path)
    timeout = "10m"
  }

   provisioner "remote-exec" {
    inline = ["echo 'connected!'"]
  }

}

# Installing Docker & Kubernetes on our Instances
# Creating a local hosts file for local Ansible to use
resource "local_file" "hosts" {
  content = <<-DOC
    #  Generated by Terraform
    [master]
    ${aws_instance.infra-op-ec2[0].public_ip}
    
    [workers]
    ${aws_instance.infra-op-ec2[1].public_ip}
    ${aws_instance.infra-op-ec2[2].public_ip}

    [all:vars]
    ansible_user="${var.ssh_user}"
    ansible_ssh_private_key_path="/tf-modules/${local.private_key_path}"
    ansible_ssh_common_args="-o StrictHostKeyChecking=no"
    DOC
  filename = "${path.module}/hosts"
}

# Using Local Exec to install apps on our instance using Local Ansible
resource "null_resource" "install_apps" {
  depends_on = [
    aws_instance.infra-op-ec2,
    local_file.hosts,
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts ~/fixing-infra-op/playbooks/kube-deps.yaml --private-key=~/fixing-infra-op/tf-modules/infra_op.pem"
  }
}


# Setting up the Master node
resource "null_resource" "setup_master" {
  depends_on = [
    null_resource.install_apps,
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts ~/fixing-infra-op/playbooks/master.yaml --private-key=~/fixing-infra-op/tf-modules/infra_op.pem"
  }
}

# Setting up the worker nodes
resource "null_resource" "setup_workers" {
  depends_on = [
    null_resource.setup_master,
  ]

  provisioner "local-exec" {
    command = "ansible-playbook -i hosts ~/fixing-infra-op/playbooks/workers.yaml --private-key=~/fixing-infra-op/tf-modules/infra_op.pem"
  }
}
