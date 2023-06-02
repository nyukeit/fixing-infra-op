# Output of Public IPs

output "instance_ips" {

  value = aws_instance.infra_op_ec2[*].public_ip

}
