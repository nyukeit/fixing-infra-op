# Define local variables

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



# This creates the EC2 instance

resource "aws_instance" "infra_op_ec2" {

  count = 3

  ami = "${var.ami_id}"

  instance_type = "t2.micro"

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.infra_op_sg.id]

  key_name = "${var.key_name}"



  connection {

    type = "ssh"

    host = self.public_ip

    user = "${var.ssh_user}"

    private_key = file(local.private_key_path)

    timeout = "4m"

  }

  # Install Ansible on Master EC2 node for further provisioning

  provisioner "remote-exec" {

    inline = [

      "sudo apt update",

      "sudo apt-add-repository ppa:ansible/ansible",

      "sudo apt install ansible -y"

    ]

  }

}
