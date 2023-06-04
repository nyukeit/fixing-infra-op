# Output of Public IPs

output "instance_ips" {

  value = aws_instance.infra-op-ec2[*].public_ip

}
