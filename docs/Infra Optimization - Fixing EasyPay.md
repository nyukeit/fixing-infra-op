# Infra Optimization - Fixing EasyPay

Capstone Project for PGP DevOps

By Nyukeit

## Details & Context Statement

A popular payment application, **EasyPay** where users add money to their wallet accounts, faces an issue in its payment success rate. The timeout that occurs with the connectivity of the database has been the reason for the issue. 

While troubleshooting, it is found that the database server has several downtime instances at irregular intervals. This situation compels the company to create their own infrastructure that runs in high-availability mode (at application level).

Given that online shopping experiences continue to evolve as per customer expectations, the developers are driven to make their app more reliable, fast, and secure for improving the performance of the current system.

> Disclaimer: Despite being mentioned that there is sample code for the project to download from the portal, there is none, so we will be implementing a simple Hello World Java App instead.

### Implementation Requirements

1. Create the cluster (EC2 instances with load balancer and elastic IP in case of AWS)
2. Automate the provisioning of an EC2 instance using Ansible or Chef Puppet
3. Install Docker and Kubernetes on the cluster
4. Implement the network policies at the database pod to allow ingress traffic from the front-end application pod
5. Create a new user with permissions to create, list, get, update, and delete pods
6. Configure application on the pod
7. Take snapshot of ETCD database
8. Set criteria such that if the memory of CPU goes beyond 50%, environments automatically get scaled up and configured

### Tool Requirements

| AWS EC2                                                      | Docker                                                       | Kubernetes                                                   | Ansible                                                      | Terraform                                                    |
| ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
| <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/amazonwebservices/amazonwebservices-original.svg" style="width:60px" /> | <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/docker/docker-plain.svg" style="width:60px" /> | <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/kubernetes/kubernetes-plain.svg" style="width:60px" /> | <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/ansible/ansible-original.svg" style="width:60px" /> | <img src="https://cdn.jsdelivr.net/gh/devicons/devicon/icons/terraform/terraform-plain.svg" style="width:60px" /> |
| Deployed                                                     | Cloud                                                        | Cloud                                                        | Local                                                        | Local                                                        |

### Final Setup Architecture Diagram

The basic idea here is to make our application accessible from the internet using an ElasticIP, Elastic Load Balancer and then routing traffic to our Kubernetes Cluster. Here is a diagram from AWS that shows how this will work.

![AWS LB Routing](images/aws-lb-subnets-routing.png)

> Note: This diagram shows the flow of traffic in two different availability zones but for the sake of this project, we will be working within a single availability zone.

## Step 1 - Create AWS Resources

In this step, we will provision the various AWS resources required for the implementation of our application. These will include EC2 3-node cluster (read more here on why you need a minimum of 3 nodes for high-availability), a Load Balancer and an Elastic IP to access our application from outside.

Although the requirements are to use Ansible or Chef/Puppet to provision the AWS resources, we will use Terraform as it is the most convenient method to manage cloud infrastructure. We will use Ansible later to install Docker & Kubernetes on the cluster.

To keep things extremely simple and straightforward, we will deploy 3 **similar** EC2 instances using the count meta argument. We will output the IPs of these newly created instances and populate our Ansible hosts inventory dynamically using these.

### Step 1.1 Create Keypair in EC2 Dashboard

First, create a keypair from the AWS EC2 dashboard. While you can create this in Terraform too, they discourage this method and suggest us to create a keypair outside of Terraform. Steps to create this can be followed here.

Amazon allows us to use a single keypair for multiple EC2 instances.

### Step 1.2 Create the Terraform scripts

We distribute our TF scripts in multiple modules to keep each file readable and clear.

#### Providers

```
terraform{
required_version = ">= 1.0" 
      required_providers {
        aws = {
          source = "hashicorp/aws"
          version = "4.55.0"
        }
      }
}

provider "aws" {
	region     = "${var.region}"
	access_key = "${var.aws_access_key}"
	secret_key = "${var.aws_secret_key}"
	token = "${var.aws_token}"
}
```

#### Variables

```
variable "ami_id" {
    default = "ami-08fdec01f5df9998f" 
}
variable "vpc_id"{
    default="vpc-000c470bfeccdec26"
}
variable "key_name" {
    default = "infra_op"
}
variable "aws_access_key" {
    default = "ASIAZWKLZ6WUYO5ATKMD"
}
variable "aws_secret_key" {
default = "nxfz+qI3wChxpbLOmGKkqju7qkPVwTANwhmHiG6p"
}
variable "aws_token" {
  default = "FwoGZXIvYXdzEMX//////////wEaDLRqSQAEXms0rgSsHSK0AWZCwySYRGHIkGR2Day7ZKKEJuyCbxlbBoV4lv5uONvJa7t7j+SbqZ/fzFYrM0vWhRKGo6iSQRpIx21hXKOrLPF9sGEdVJ/ZkuYTnE80IPzYLxPiYx5pOlBgjAA3iuerNW9fK7FHCxEAT8ctaSVloMdkHMROfxOEEd36l0BKJvddzFBVidFvzRmfKuDhiji9shl2x9UMIFUQUHyilsBo0p2mK9+AJENVkq7UMw+ozLxyDwt2pSi01eyjBjIt9HT13Dw7QRLGkQxBWoMgm5jhkjGyqIAl1A8mjr/sgnqt/IoXCphkNB5m6dYC"
}
variable "region" {
    default = "us-east-1"
}

variable "ssh_user" {
  default = "ubuntu"
}

variable "subnet_id" {
  default = "subnet-07daeb670893d183d"
}

variable "igw_id" {
  default = "igw-0687d23deabeddf5b"
}
```

#### Main Terraform File

Let's create a TF script that will deploy the instances.

```
# Define Local Variables
locals {
  private_key_path = "${path.module}/${var.key_name}.pem"
}

# Network Policy for our VPC using Security Group

resource "aws_security_group" "infra_op_sg" {
  name= "infra_op_sg"
  vpc_id = "${var.vpc_id}"
  
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

# Create a Network Interface to associate our instances to our specific subnet
resource "aws_network_interface" "infra-op-ni" {
  subnet_id = "${var.subnet_id}"
  
  tags = {
    Name = "infra_op_network_interface"
  }
}

# This creates the EC2 instance
resource "aws_instance" "infra_op_ec2" {
  count = 3
  ami = "${var.ami_id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = "${aws_security_group.infra_op_sg.id}"
  key_name = "${var.key_name}"
  
  network_interface {
    network_interface_id = "${aws_network_interface.infra-op-ni}"
  }
}

# Provision an Elastic IP
resource "aws_eip" "infra_op_eip" {
  vpc = true
  network_interface = "${aws_network_interface.infra-op-ni}"
}

# Provision an Elastic Load Balancer
resource "aws_lb" "infra_op_lb" {
  name               = "infra-op-lb"
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = "${var.subnet_id}"
    allocation_id = "${aws_eip.infra_op_eip.id}"
  }
}

# Installing Docker & Kubernetes on our Instances
# Creating a local hosts file for local Ansible to use
resource "local_file" "hosts" {
  content = <<-DOC
    #  Generated by Terraform
    [master]
    ${aws_instance.infra_op_ec2[0].public_ip}
    
    [workers]
    ${aws_instance.infra_op_ec2[1].public_ip}
    ${aws_instance.infra_op_ec2[2].public_ip}

    [all:vars]
    ansible_user="${local.ssh_user}"
    ansible_ssh_private_key_path="${local.private_key_path}"
    ansible_ssh_common_args="-o StrictHostKeyChecking=no"
    DOC
  filename = "${path.module}/hosts"
}

# Using Local Exec to install apps on our instance using Local Ansible
resource "null_resource" "install_apps" {
  depends_on = [
    aws_instance.infra_op_ec2,
    local_file.hosts,
  ]
  
  provisioner "local-exec" {
    command = "ansible-playbook -i hosts playbooks/kube-deps.yaml"
  }
}

resource "null_resource" "setup_master" {
  depends_on = [
    null_resource.install_apps,
  ]
  
  provisioner "local-exec" {
    command = "ansible-playbook -i hosts playbooks/master.yaml"
  }
}

resource "null_resource" "setup_workers" {
  depends_on = [
    null_resource.setup_master,
  ]
  
  provisioner "local-exec" {
    command = "ansible-playbook -i hosts playbooks/workers.yaml"
  }
}
```

Now, ideally we would have liked to use Ansible locally to install Kubernetes on all of our new EC2 instances, but given that we have to use Docker, this will require the installation of CRI-Docker. This will complicate our playbooks and Terraform. So we will instead only install Ansible on the Master EC2 instance and use it to install the remaining apps directly from the instance.





